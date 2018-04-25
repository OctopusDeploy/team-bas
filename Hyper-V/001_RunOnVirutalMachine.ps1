$VirtualMachineName = "Windows 10 dev environment"

$VM = Get-VM $VirtualMachineName
$VMState = $VM.State
Write-Host "Current Status Is $VMState"

if ($VMState -eq "Off")
{
    Start-VM $VirtualMachineName
}

While ($VMState -ne "Running")
{
    Sleep 2
    $VMState = $VM.State
    Write-Host "New Status is $VMState"
}

$OctoCred = Get-Credential

Invoke-Command -VMName $VirtualMachineName -Credential $OctoCred -ScriptBlock {
    Dism /Online /Enable-Feature /FeatureName:IIS-ASPNET /All
    Dism /Online /Enable-Feature /FeatureName:IIS-ASPNET45 /All
    Dism /Online /Enable-Feature /FeatureName:IIS-CertProvider /All
    Dism /Online /Enable-Feature /FeatureName:IIS-HttpRedirect /All
    Dism /Online /Enable-Feature /FeatureName:IIS-BasicAuthentication /All
    Dism /Online /Enable-Feature /FeatureName:IIS-WebSockets /All
    Dism /Online /Enable-Feature /FeatureName:IIS-ApplicationInit /All
    Dism /Online /Enable-Feature /FeatureName:IIS-CustomLogging /All
    Dism /Online /Enable-Feature /FeatureName:IIS-ManagementService /All
    Dism /Online /Enable-Feature /FeatureName:WCF-Services45 /All
    Dism /Online /Enable-Feature /FeatureName:WCF-HTTP-Activation45 /All
    Dism /Online /Enable-Feature /FeatureName:IIS-WindowsAuthentication /All
    Dism /online /enable-feature /featurename:NetFX3 /All

    Write-Host "Installing 7-zip"
    choco install 7zip -y

    Write-Host "Installing NuGet Command Line"
    choco install nuget.commandline -y

    Write-Host "Installing Git"
    choco install git -y

    Write-Host "Installing .NET Targeting pack 4.5.2"
    choco install netfx-4.5.2-devpack -y

    Write-Host "Installing .NET Targeting Pack 4.6.2"
    choco install netfx-4.6.2-devpack -y

    Write-Host "Installing .NET Targeting Pack 4.7.1"
    choco install netfx-4.7.1-devpack -y

    Write-Host "Installing Postman"
    choco install postman -y

    Write-Host "Installing .NET Core"
    choco install dotnetcore-sdk -y

    Write-Host "Installing Notepad++"
    choco install notepadplusplus -y

    Write-Host "Installing SQL Management Studio"
    choco install sql-server-management-studio -y

    Write-Host "Installing Visual Studio Code"
    choco install visualstudiocode -y

    Write-Host "Installing Octopus Server"
    choco install octopusdeploy -y

    Write-Host "Installing Octopus Tentacle"
    choco install octopusdeploy.tentacle -y

    Write-Host "Installing Octopus Tools"
    choco install octopustools -y

    Write-Host "Installing SQL Server Express Warning, this will restart the box"
    choco install sql-server-express -y

    $sqlServerConnectionString = "Server=(local)\SQLEXPRESS;Database=master;Integrated Security=True"

    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = $sqlServerConnectionString
    
    #Write-Host $commandText
    $command = $sqlConnection.CreateCommand()
    $command.CommandType = [System.Data.CommandType]'Text'
    
    $sqlConnection.Open()
    $command.CommandText = "IF NOT EXISTS (select Name from sys.databases where Name = 'OctoFX_Development')
        create database OctoFX_Development"
    $command.ExecuteNonQuery()

    $command.CommandText = "IF NOT EXISTS (select Name from sys.databases where Name = 'OctoFX_Test')
        create database OctoFX_Test"            
    $command.ExecuteNonQuery()

    $command.CommandText = "IF NOT EXISTS (select Name from sys.databases where Name = 'OctoFX_Production')
        create database OctoFX_Production"            
    $command.ExecuteNonQuery()

    $command.CommandText = "IF NOT EXISTS(SELECT 1 FROM sys.server_principals WHERE name = 'NT AUTHORITY\NETWORK SERVICE')
	CREATE LOGIN [NT AUTHORITY\NETWORK SERVICE] FROM WINDOWS WITH DEFAULT_DATABASE=[master]"            
    $command.ExecuteNonQuery()

    $command.CommandText = "ALTER SERVER ROLE [sysadmin] ADD MEMBER [NT AUTHORITY\NETWORK SERVICE]"            
    $command.ExecuteNonQuery()

    $sqlConnection.Close()

    $OctoService = Get-Service "OctopusDeploy" -ErrorAction SilentlyContinue
    $OctoServerInstallLoc = $env:ProgramFiles + "\Octopus Deploy\Octopus\Octopus.Server.exe"
    $OctopusUserName = "OctopusDemo"
    $OctopusPassword = "OctopusDemo01!"
    $OctopusServer = "http://localhost:8081/"

    if ($OctoService -eq $null)
    {
        Write-Host "Octopus Service Not Found, Starting Setup"

        & $OctoServerInstallLoc create-instance --instance "OctopusServer" --config "C:\Octopus\OctopusServer.config"
        & $OctoServerInstallLoc database --instance "OctopusServer" --connectionString "Data Source=(local)\SQLEXPRESS;Initial Catalog=OctopusDeploy;Integrated Security=True" --create --grant "NT AUTHORITY\SYSTEM"
        & $OctoServerInstallLoc configure --instance "OctopusServer" --upgradeCheck "True" --upgradeCheckWithStatistics "True" --webForceSSL "False" --webListenPrefixes $OctopusServer --commsListenPort "10943" --serverNodeName $env:computername --usernamePasswordIsEnabled "True" 
        & $OctoServerInstallLoc service --instance "OctopusServer" --stop
        & $OctoServerInstallLoc admin --instance "OctopusServer" --username $OctopusUserName --email "OctopusDemo@Octopus.com" --password $OctopusPassword
        & $OctoServerInstallLoc service --instance "OctopusServer" --install --reconfigure --start
    }
    else
    {
        Write-Host "Octopus Service Found, Skipping Setup"
    }

    $thumbPrint = & $OctoServerInstallLoc show-thumbprint --instance "OctopusServer"

    octo create-environment --name "Development" --server $OctopusServer --user $OctopusUserName --pass $OctopusPassword --ignoreIfExists
    octo create-environment --name "Test" --server $OctopusServer --user $OctopusUserName --pass $OctopusPassword --ignoreIfExists
    octo create-environment --name "Production" --server $OctopusServer --user $OctopusUserName --pass $OctopusPassword --ignoreIfExists

    $OctoTentacleService = Get-Service "OctopusDeploy Tentacle" -ErrorAction SilentlyContinue

    if ($OctoTentacleService -eq $null)
    {
        Write-Host "Unable to find tentacle, starting setup"
        $OctoTentacleInstallLoc = $env:ProgramFiles + "\Octopus Deploy\Tentacle\Tentacle.exe"

        & $OctoTentacleInstallLoc create-instance --instance "Tentacle" --config "C:\Octopus\Tentacle.config"
        & $OctoTentacleInstallLoc new-certificate --instance "Tentacle" --if-blank
        & $OctoTentacleInstallLoc configure --instance "Tentacle" --reset-trust
        & $OctoTentacleInstallLoc configure --instance "Tentacle" --app "C:\Octopus\Applications" --port "10933" --noListen "False"
        & $OctoTentacleInstallLoc configure --instance "Tentacle" --trust $thumbPrint
        & "netsh" advfirewall firewall add rule "name=Octopus Deploy Tentacle" dir=in action=allow protocol=TCP localport=10933
        & $OctoTentacleInstallLoc register-with --instance "Tentacle" --server "http://localhost:8081/" --username $OctopusUserName --password $OctopusPassword --role "octofx-app" --role "octofx-web" --environment "Development" --environment "Test" --environment "Production" --comms-style TentaclePassive --console
        & $OctoTentacleInstallLoc service --instance "Tentacle" --install --stop --start
    }
    else
    {
        Write-Host "Tentacle Found Skipping Setup"
    }

}