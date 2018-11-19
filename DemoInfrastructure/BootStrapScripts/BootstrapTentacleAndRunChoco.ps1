Param(    
    [string]$octopusServerThumbprint,    
    [string]$instanceName,	
	[string]$slackNotificationUrl,
	[string]$chocolateyAppList	
)

Start-Transcript -path "C:\Bootstrap.txt" -append  

Write-Output "Thumbprint: $octopusServerThumbprint"  
Write-Output "InstanceName: $instanceName"
Write-Output "SlackNotificationUrl: $slackNotificationUrl"
Write-Output "ChocolateyAppList: $chocolateyAppList"

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

if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false){
	Write-Host "Chocolatey Apps Specified, installing chocolatey and applications"
	
	Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
	
	$appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }

	foreach ($app in $appsToInstall)
	{
		Write-Host "Installing $app"
		choco install $app /y
	}
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
    Write-Output "Configuring and registering Tentacle" 

    Set-Location "${env:ProgramFiles}\Octopus Deploy\Tentacle" 	
	
	$slackBody = @{
		"channel" = "#demo-env-pulse"
		"username" = "Cloud Formation PowerShell Bootstrap"
		"text" = ":woohoo: Installation of bootstrap tentacle on $registerComputerName was successful"
	}

	& .\tentacle.exe create-instance --instance "Tentacle" --config $tentacleConfigFile --console | Write-Output
	if ($lastExitCode -ne 0) { 
	 $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on create-instance for $registerComputerName."
	 Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	 throw "Installation failed on create-instance" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --home $tentacleHomeDirectory --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on configure home directory for $registerComputerName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	  throw "Installation failed on configure" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --app $tentacleAppDirectory --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on configure app directory for $registerComputerName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	  throw "Installation failed on configure" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --port $tentacleListenPort --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on configure listen port for $registerComputerName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	  throw "Installation failed on configure" 
	} 
	& .\tentacle.exe new-certificate --instance "Tentacle" --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on creating new certificate for $registerComputerName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	  throw "Installation failed on creating new certificate" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --trust $octopusServerThumbprint --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on configuring octopus server thumbprint for $registerComputerName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	  throw "Installation failed on configure" 
	} 	                  	
	& .\tentacle.exe service --instance "Tentacle" --install --start --console | Write-Output
	if ($lastExitCode -ne 0) { 
	   $slackBody["text"] = ":sadpanda: \<!channel\> Installation failed on install for $registerComputerName."
	   Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	  throw "Installation failed on service install" 
	} 
	
	$slackBody["text"] = ":woohoo: Installation of bootstrap tentacle on $registerComputerName was successful."
	Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	Write-Output "Tentacle commands complete"     
} else {
    Write-Output "Tentacle already exists"
}    


Write-Output "Bootstrap commands complete"  