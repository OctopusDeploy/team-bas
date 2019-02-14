Start-Transcript -path "C:\SQLServerBootstrap.txt" -append 

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

$ErrorActionPreference = 'Stop';
 
$packageName= 'sql-server-express'
$url        = ''
$url64      = 'https://download.microsoft.com/download/E/F/2/EF23C21D-7860-4F05-88CE-39AA114B014B/SQLEXPR_x64_ENU.exe'
$checksum   = '71321559eff923066799d7fc26b6c7aedd41eee1'
$silentArgs = "/IACCEPTSQLSERVERLICENSETERMS /Q /ACTION=install /INSTANCEID=SQLEXPRESS /INSTANCENAME=SQLEXPRESS /UPDATEENABLED=FALSE"
 
$tempDir = "C:\SQLServerExpress"
 
if (![System.IO.Directory]::Exists($tempDir)) { [System.IO.Directory]::CreateDirectory($tempDir) | Out-Null }
$fileFullPath = "$tempDir\SQLEXPR.exe"

Get-FileFromServer $url64 $fileFullPath
 
Write-Host "Extracting..."
$extractPath = "$tempDir\SQLServerExpresInstall"
Start-Process "$fileFullPath" "/Q /x:`"$extractPath`"" -Wait
 
Write-Host "Installing..."
$setupPath = "$extractPath\setup.exe"

Start-Process $setupPath "/IACCEPTSQLSERVERLICENSETERMS /Q /ACTION=install /INSTANCEID=SQLEXPRESS /INSTANCENAME=SQLEXPRESS /UPDATEENABLED=FALSE"

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

$sqlRegistryPath = "HKLM:\Software\Microsoft\Microsoft SQL Server\MSSQL14.SQLEXPRESS\MSSQLServer"
$sqlRegistryLoginName = "LoginMode"

$sqlRegistryLoginValue = "2"

New-ItemProperty -Path $sqlRegistryPath -Name $sqlRegistryLoginName -Value $sqlRegistryLoginValue -PropertyType DWORD -Force

net stop MSSQL`$SQLEXPRESS /y
net start MSSQL`$SQLEXPRESS