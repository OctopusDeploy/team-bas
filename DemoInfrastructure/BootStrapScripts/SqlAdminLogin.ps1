Start-Transcript -path "C:\SQLServerBootstrap.txt" -append 

choco install sql-server-2017 -y

$octopusAdminDatabaseUser = "#{Global.Database.AdminUser}"
$octopusAdminDatabasePassword = "#{Global.Database.AdminPassword}"
$octopusAdminDatabaseServer = "#{Global.Database.Server}"

$connectionString = "Server=$octopusAdminDatabaseServer;Database=master;integrated security=true;"

$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = $connectionString

$command = $sqlConnection.CreateCommand()
$command.CommandType = [System.Data.CommandType]'Text'

Write-Output "Opening the connection to $octopusAdminDatabaseServer"
$sqlConnection.Open()

Write-Output "Running the if not exists then create user command on the server"
$command.CommandText = "CREATE LOGIN [$octopusAdminDatabaseUser] with Password='$octopusAdminDatabasePassword', default_database=master"            
$command.ExecuteNonQuery()

Write-Output "Granting the sysadmin role to $octopusAdminDatabaseUser"
$command.CommandText = "sp_addsrvrolemember @loginame= '$octopusAdminDatabaseUser', @rolename = 'sysadmin'"  
$command.ExecuteNonQuery()

Write-Output "Successfully created the account $octopusAdminDatabaseUser"
Write-Output "Closing the connection to $octopusAdminDatabaseServer"
$sqlConnection.Close()

# $sqlRegistryPath = "HKLM:\Software\Microsoft\Microsoft SQL Server\MSSQL14.SQLEXPRESS\MSSQLServer"
$sqlRegistryPath = "HKLM:\Software\Microsoft\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQLServer"
$sqlRegistryLoginName = "LoginMode"

$sqlRegistryLoginValue = "2"

New-ItemProperty -Path $sqlRegistryPath -Name $sqlRegistryLoginName -Value $sqlRegistryLoginValue -PropertyType DWORD -Force

# net stop MSSQL`$SQLEXPRESS /y
# net start MSSQL`$SQLEXPRESS

net stop MSSQLSERVER /y
net start MSSQLSERVER