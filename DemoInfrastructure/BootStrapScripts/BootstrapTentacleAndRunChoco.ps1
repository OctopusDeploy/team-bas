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

Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
& choco install octopusdeploy.tentacle /y | Write-Output

if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false){
	Write-Host "Chocolatey Apps Specified, installing chocolatey and applications"	
	
	$appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }

	foreach ($app in $appsToInstall)
	{
		Write-Host "Installing $app"
		& choco install $app /y | Write-Output
	}
}

$tentacleListenPort = 10933 
$tentacleHomeDirectory = "C:\Octopus" 
$tentacleAppDirectory = "C:\Octopus\Applications" 
$tentacleConfigFile = "C:\Octopus\Tentacle\Tentacle.config"     

If ((test-path $tentacleConfigFile) -eq $false)
{ 	
    Write-Output "Beginning Tentacle installation"     	
    
    Write-Output "Open port $tentacleListenPort on Windows Firewall" 
    & netsh.exe firewall add portopening TCP $tentacleListenPort "Octopus Tentacle" 
    if ($lastExitCode -ne 0) { 
        throw "Installation failed when modifying firewall rules" 
    } 

    Write-Output "Configuring and registering Tentacle" 

    Set-Location "${env:ProgramFiles}\Octopus Deploy\Tentacle" 	
	
	$slackBody = @{
		"channel" = "#demo-env-pulse"
		"username" = "Cloud Formation PowerShell Bootstrap"
		"text" = ":woohoo: Installation of bootstrap tentacle on $instanceName was successful"
	}

	& .\tentacle.exe create-instance --instance "Tentacle" --config $tentacleConfigFile --console | Write-Output
	if ($lastExitCode -ne 0) { 
	 $slackBody["text"] = ":sadpanda: Installation failed on create-instance for $instanceName."
	 Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	 $errorMessage = $error[0].Exception.Message	 
	 throw "Installation failed on create-instance: $errorMessage" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --home $tentacleHomeDirectory --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: Installation failed on configure home directory for $instanceName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	  $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on configure: $errorMessage" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --app $tentacleAppDirectory --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: Installation failed on configure app directory for $instanceName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	  $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on configure: $errorMessage" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --port $tentacleListenPort --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda: Installation failed on configure listen port for $instanceName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	  $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on configure: $errorMessage" 
	} 
	& .\tentacle.exe new-certificate --instance "Tentacle" --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda:  Installation failed on creating new certificate for $instanceName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	  $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on creating new certificate: $errorMessage" 
	} 
	& .\tentacle.exe configure --instance "Tentacle" --trust $octopusServerThumbprint --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $slackBody["text"] = ":sadpanda:  Installation failed on configuring octopus server thumbprint for $instanceName."
	  Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	  $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on configure: $errorMessage" 
	} 	                  	
	& .\tentacle.exe service --instance "Tentacle" --install --start --console | Write-Output
	if ($lastExitCode -ne 0) { 
	   $slackBody["text"] = ":sadpanda:  Installation failed on install for $instanceName."
	   Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	   $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on service install: $errorMessage" 
	} 
	
	$slackBody["text"] = ":woohoo: Installation of bootstrap tentacle on $instanceName was successful."
	Invoke-WebRequest -Method POST -Uri $slackNotificationUrl -Body (ConvertTo-Json -Compress -InputObject $slackBody) -UseBasicParsing
	Write-Output "Tentacle commands complete"     
} else {
    Write-Output "Tentacle already exists"
}    


Write-Output "Bootstrap commands complete"  