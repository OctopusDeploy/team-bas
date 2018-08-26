Param(
    [string]$octopusAdminDatabaseUser,
    [string]$octopusAdminDatabasePassword    
)
Start-Transcript -path "C:\Bootstrap.txt" -append  
              
& netsh.exe firewall add portopening TCP 1433 "SQL Server" 

$octopusAdminDatabaseServer = "127.0.0.1"
$connectionString = "Server=$octopusAdminDatabaseServer;Database=master;integrated security=true;"

$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = $connectionString

$command = $sqlConnection.CreateCommand()
$command.CommandType = [System.Data.CommandType]'Text'

Write-Output "Opening the connection to $octopusAdminDatabaseServer"
$sqlConnection.Open()

Write-Output "Running the if not exists then create user command on the server"
$command.CommandText = "IF NOT EXISTS(SELECT 1 FROM sys.server_principals WHERE name = '$octopusAdminDatabaseUser')
CREATE LOGIN [$octopusAdminDatabaseUser] with Password='$octopusAdminDatabasePassword', default_database=master"            
$command.ExecuteNonQuery()

Write-Output "Granting the sysadmin role to $octopusAdminDatabaseUser"
$command.CommandText = "sp_addsrvrolemember @loginame= '$octopusAdminDatabaseUser', @rolename = 'sysadmin'"  
$command.ExecuteNonQuery()

Write-Output "Successfully created the account $octopusAdminDatabaseUser"
Write-Output "Closing the connection to $octopusAdminDatabaseServer"
$sqlConnection.Close()

$sqlRegistryPath = "HKLM:\Software\Microsoft\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQLServer"
$sqlRegistryLoginName = "LoginMode"

$sqlRegistryLoginValue = "2"

New-ItemProperty -Path $sqlRegistryPath -Name $sqlRegistryLoginName -Value $sqlRegistryLoginValue -PropertyType DWORD -Force

net stop MSSQLSERVER /y
net start MSSQLSERVER