Param(
    [string]$octopusServerUrl,
    [string]$octopusServerApiKey,
    [string]$octopusServerThumbprint,
    [string]$environmentToDeployTo,    
    [string]$roleName,
    [string]$instanceName,
	[string]$applicationName,
	[string]$slackNotificationUrl
)

Start-Transcript -path "C:\Bootstrap.txt" -append  

Write-Output "ServerUrl: $octopusServerUrl" 
Write-Output "ApiKey: $octopusServerApiKey" 
Write-Output "Thumbprint: $octopusServerThumbprint"  
Write-Output "Environment: $environmentToDeployTo" 
Write-Output "RoleName: $roleName"
Write-Output "InstanceName: $instanceName"
Write-Output "ApplicationName: $applicationName" 
Write-Output "SlackNotificationUrl: $slackNotificationUrl"

function Get-FileFromServer 
{ 
	param ( 
	  [string]$url, 
	  [string]$saveAs 
	) 

	Write-Host "Downloading $url to $saveAs" 
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
	$downloader = new-object System.Net.WebClient 
	$downloader.DownloadFile($url, $saveAs) 
} 

$OctoTentacleService = Get-Service "OctopusDeploy Tentacle" -ErrorAction SilentlyContinue

if ($OctoTentacleService -eq $null)
{
    $tentacleListenPort = 10933 
    $tentacleHomeDirectory = "C:\Octopus" 
    $tentacleAppDirectory = "C:\Octopus\Applications" 
    $tentacleConfigFile = "C:\Octopus\Tentacle\Tentacle.config"  
    $tentacleDownloadPath = "https://octopus.com/downloads/latest/WindowsX64/OctopusTentacle" 	
	
	$tentaclePath = "C:\Tools\Octopus.Tentacle.msi" 

    Write-Output "Beginning Tentacle installation"     

	Write-Output "Downloading latest Octopus Tentacle MSI..." 

	$tentaclePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Tentacle.msi") 
	if ((test-path $tentaclePath) -ne $true) { 
	  Get-FileFromServer $tentacleDownloadPath $tentaclePath 
	} 

	Write-Output "Installing MSI" 
	$msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i Tentacle.msi /quiet" -Wait -Passthru).ExitCode 
	Write-Output "Tentacle MSI installer returned exit code $msiExitCode" 
	if ($msiExitCode -ne 0) { 
	  throw "Installation aborted" 
	} 	

    
    Write-Output "Open port $tentacleListenPort on Windows Firewall" 
    & netsh.exe firewall add portopening TCP $tentacleListenPort "Octopus Tentacle" 
    if ($lastExitCode -ne 0) { 
        throw "Installation failed when modifying firewall rules" 
    } 

    Write-Host "Getting public IP address" 
    $ipAddress = Invoke-RestMethod http://ipinfo.io/json | Select-Object -exp ip 

    $ipAddress = $ipAddress.Trim() 
    
    Write-Output "Public IP address: $ipAddress"

    Write-Output "Configuring and registering Tentacle" 

    Set-Location "${env:ProgramFiles}\Octopus Deploy\Tentacle" 
	
	$registerComputerName = "$computerName-Bootstrap-01"
	$bootstrapRoleName = "$applicationName-Bootstrap"
	
	$rolesToRegister = $roles -split "," | foreach { "--role `"Bootstrap-$($_.Trim())`"" }
	$rolesToRegister = $rolesToRegister -join " "
	$environmentsToRegister = $environmentToDeployTo -split "," | foreach { "--environment `"$($_.Trim())`"" }
	$environmentsToRegister = $environmentsToRegister -join " "
	
	$slackBody = @{
		"channel" = "#demo-env-pulse"
		"username" = "Cloud Formation PowerShell Bootstrap"
		"text" = ":woohoo: Installation of bootstrap tentacle on $registerComputerName was successful"
	}

	& .\tentacle.exe create-instance --instance "Tentacle" --config $tentacleConfigFile --console | Write-Output
	if ($lastExitCode -ne 0) { 
	 $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on create-instance for $registerComputerName."
	 Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody)
	 throw "Installation failed on create-instance" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --home $tentacleHomeDirectory --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on configure home directory for $registerComputerName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody)
	  throw "Installation failed on configure" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --app $tentacleAppDirectory --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on configure app directory for $registerComputerName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody)
	  throw "Installation failed on configure" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --port $tentacleListenPort --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on configure listen port for $registerComputerName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody)
	  throw "Installation failed on configure" 
	} 
	& .\tentacle.exe new-certificate --instance "Tentacle" --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on creating new certificate for $registerComputerName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody)
	  throw "Installation failed on creating new certificate" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --trust $octopusServerThumbprint --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on configuring octopus server thumbprint for $registerComputerName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody)
	  throw "Installation failed on configure" 
	} 	                  
	$cmd = "& .\tentacle.exe register-with --instance `"Tentacle`" --server $octopusServerUrl $rolesToRegister --role $bootstrapRoleName --role $applicationName --environment `"SpinUp`" --environment `"TearDown`" $environmentsToRegister --name $registerComputerName --publicHostName $ipAddress --apiKey $octopusApiKey --comms-style TentaclePassive --force --console"
	Invoke-Expression $cmd | Write-Host
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on registering $registerComputerName with $octopusServerUrl."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody)
	  throw "Installation failed on register-with" 
	} 				                		               
	& .\tentacle.exe service --instance "Tentacle" --install --start --console | Write-Output
	if ($lastExitCode -ne 0) { 
	   $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on install for $registerComputerName."
	   Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody)
	  throw "Installation failed on service install" 
	} 
	
	$slackBody["text"] = ":woohoo: Installation of bootstrap tentacle on $registerComputerName was successful."
	Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody)
	Write-Output "Tentacle commands complete"     
} else {
    Write-Output "Tentacle already exists"
}    


Write-Output "Bootstrap commands complete"  