Param(    
	[string]$octopusServerUrl,	
	[string]$octopusServerThumbprint,    
	[string]$octopusApiKey,
	[string]$roles,
	[string]$environments,
	[string]$chocolateyAppList	
)

Start-Transcript -path "C:\Bootstrap.txt" -append  

Write-Output "OctopusServerUrl: $octopusServerUrl"  
Write-Output "Thumbprint: $octopusServerThumbprint"  
Write-Output "Roles: $roles" 
Write-Output "Environments: $environments" 
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

function Get-MyPublicIPAddress { 
	# Get Ip Address of Machine 
	Write-Host "Getting public IP address" 
	$ipAddress = Invoke-RestMethod http://ipinfo.io/json | Select-Object -exp ip 
	return $ipAddress 
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

	Set-Location "${env:ProgramFiles}\Octopus Deploy\Tentacle" 
	
	Write-Output "Creating the octopus instance"
	& .\tentacle.exe create-instance --instance "Tentacle" --config $tentacleConfigFile --console | Write-Output
	if ($lastExitCode -ne 0) { 
	 $errorMessage = $error[0].Exception.Message	 
	 throw "Installation failed on create-instance: $errorMessage" 
	} 
	
	Write-Output "Configuring the home directory"
	& .\tentacle.exe configure --instance "Tentacle" --home $tentacleHomeDirectory --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on configure: $errorMessage" 
	} 
	
	Write-Output "Configuring the app directory"
	& .\tentacle.exe configure --instance "Tentacle" --app $tentacleAppDirectory --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on configure: $errorMessage" 
	} 
	
	Write-Output "Configuring the listening port"
	& .\tentacle.exe configure --instance "Tentacle" --port $tentacleListenPort --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on configure: $errorMessage" 
	} 
	
	Write-Output "Creating a certificate for the tentacle"
	& .\tentacle.exe new-certificate --instance "Tentacle" --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on creating new certificate: $errorMessage" 
	} 
	
	Write-Output "Trusting the certificate $octopusServerThumbprint"
	& .\tentacle.exe configure --instance "Tentacle" --trust $octopusServerThumbprint --console | Write-Output
	if ($lastExitCode -ne 0) { 
	  $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on configure: $errorMessage" 
	}
	
	Write-Output "Registering the tentacle with the octopus server"
    $ipAddress = Get-MyPublicIPAddress 
	$ipAddress = $ipAddress.Trim()
	Write-Output "IP address is: $ipAddress"
	
	$baseArgs = @("register-with","--instance=Tentacle","--publicHostName=$ipAddress", "--server=$octopusServerUrl", "--apiKey=$octopusApiKey","--comms-style=TentaclePassive")
	
	$roleList = $roles -split ","
	foreach ($role in $roleList) {
		$baseArgs += "--role=$role"
	}

	$envList = $environments -split ","
	foreach ($env in $envList) {
		$baseArgs += "--environment=$env"
	}

	$baseArgs += "--console"

	& .\Tentacle.exe $baseArgs 

	if ($lastExitCode -ne 0) { 
	  $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on configure: $errorMessage" 
	}
	Write-Output "Finally, installing the tentacle"
	& .\tentacle.exe service --instance "Tentacle" --install --start --console | Write-Output
	if ($lastExitCode -ne 0) { 
	   $errorMessage = $error[0].Exception.Message	 
	  throw "Installation failed on service install: $errorMessage" 
	} 
	
	Write-Output "Tentacle commands complete"     
} else {
    Write-Output "Tentacle already exists"
}    

if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false){	
	try{
		choco config get cacheLocation
	}catch{
		Write-Output "Chocolatey not detected, trying to install now"
		iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
	}
	
	Write-Host "Chocolatey Apps Specified, installing chocolatey and applications"	
	
	$appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }

	foreach ($app in $appsToInstall)
	{
		Write-Host "Installing $app"
		& choco install $app /y | Write-Output
	}
}

Write-Output "Bootstrap commands complete"  