Param(
    [string]$octopusServerUrl,
    [string]$octopusServerApiKey,
    [string]$octopusServerThumbprint,
    [string]$environmentToDeployTo,    
    [string]$roleName,
    [string]$instanceName,
    [string]$fileShareKey,
    [string]$fileShareName
)

Start-Transcript -path "C:\Bootstrap.txt" -append  

Write-Output "ServerUrl: $octopusServerUrl" 
Write-Output "ApiKey: $octopusServerApiKey" 
Write-Output "Thumbprint: $octopusServerThumbprint"  
Write-Output "Environment: $environmentToDeployTo" 
Write-Output "RoleName: $roleName"
Write-Output "InstanceName: $instanceName" 
Write-Output "File Share Key: $fileShareKey"
Write-Output "File Share Name: $fileShareName"

if ((test-path "I:\") -eq $false)
{
    & netsh.exe firewall add portopening TCP "445" "Azure Storage" 
    cmdkey /add:$fileShareName.file.core.windows.net /user:Azure\$fileShareName /pass:$fileShareKey

    $acctKey = ConvertTo-SecureString -String $fileShareKey -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\$fileShareName", $acctKey
    New-PSDrive -Name I -PSProvider FileSystem -Root "\\$fileShareName.file.core.windows.net\installer" -Credential $credential -Persist
}

if ((test-path "C:\Program Files (x86)\Red Gate\DLM Automation 2\RedGate.DLMAutomation.exe") -eq $false)
{
    Write-Output "Installing Redgate" 
    $msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList '/i "I:\DLMAutomation\DLM Automation_2.1.2.1946_x86.msi" /quiet TRANSFORMS="I:\DLMAutomation\DLM Automation_2.1.2.1946_x86.mst" ADDLOCAL=ALL' -Wait -Passthru).ExitCode 
    Write-Output "Redgate MSI installer returned exit code $msiExitCode" 
    if ($msiExitCode -ne 0 -and $msiExitCode -ne 3010) { 
        throw "Installation aborted" 
    }    
} else {
    Write-Host "Redgate already installed - skipping"
}
              
$OctoTentacleService = Get-Service "OctopusDeploy Tentacle" -ErrorAction SilentlyContinue

if ($OctoTentacleService -eq $null)
{
    $tentacleListenPort = 10933 
    $tentacleHomeDirectory = "C:\Octopus" 
    $tentacleAppDirectory = "C:\Octopus\Applications" 
    $tentacleConfigFile = "C:\Octopus\Tentacle\Tentacle.config"    

    Write-Output "Beginning Tentacle installation"     

    Write-Output "Installing MSI" 
    $msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i I:\Octopus.Tentacle.msi /quiet" -Wait -Passthru).ExitCode 
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

    & .\tentacle.exe create-instance --instance "Tentacle" --config $tentacleConfigFile --console | Write-Output
    & .\tentacle.exe configure --instance "Tentacle" --home $tentacleHomeDirectory --console | Write-Output
    & .\tentacle.exe configure --instance "Tentacle" --app $tentacleAppDirectory --console | Write-Output
    & .\tentacle.exe configure --instance "Tentacle" --port $tentacleListenPort --console | Write-Output
    & .\tentacle.exe new-certificate --instance "Tentacle" --console | Write-Output
    & .\tentacle.exe configure --instance "Tentacle" --trust $octopusServerThumbprint --console | Write-Output
    & .\tentacle.exe register-with --instance "Tentacle" --server $octopusServerUrl --role $roleName --environment $environmentToDeployTo --environment "TearDown" --name $instanceName --publicHostName $ipAddress --apiKey $octopusServerApiKey --comms-style TentaclePassive --force --console | Write-Output
    & .\tentacle.exe service --instance "Tentacle" --install --start --console | Write-Output       
} else {
    Write-Output "Tentacle already exists"
}    


Write-Output "Bootstrap commands complete"  