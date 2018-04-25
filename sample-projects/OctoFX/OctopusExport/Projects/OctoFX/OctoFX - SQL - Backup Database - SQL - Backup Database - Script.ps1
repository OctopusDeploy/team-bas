$ServerName = $OctopusParameters['Server']
$DatabaseName = $OctopusParameters['Database']
$BackupDirectory = $OctopusParameters['BackupDirectory']
$CompressionOption = [int]$OctopusParameters['Compression']
$Devices = [int]$OctopusParameters['Devices']
$Stamp = $OctopusParameters['Stamp']
$SqlLogin = $OctopusParameters['SqlLogin']
$SqlPassword = $OctopusParameters['SqlPassword']
$ConnectionTimeout = $OctopusParameters['ConnectionTimeout']
$Incremental = [boolean]::Parse($OctopusParameters['Incremental'])
$CopyOnly = [boolean]::Parse($OctopusParameters['CopyOnly'])

$ErrorActionPreference = "Stop"

function ConnectToDatabase()
{
    param($server, $SqlLogin, $SqlPassword)
        
    $server.ConnectionContext.StatementTimeout = $ConnectionTimeout
     
    if ($SqlLogin -ne $null) {

        if ($SqlPassword -eq $null) {
            throw "SQL Password must be specified when using SQL authentication."
        }
    
        $server.ConnectionContext.LoginSecure = $false
        $server.ConnectionContext.Login = $SqlLogin
        $server.ConnectionContext.Password = $SqlPassword
    
        Write-Host "Connecting to server using SQL authentication as $SqlLogin."
        $server = New-Object Microsoft.SqlServer.Management.Smo.Server $server.ConnectionContext
    }
    else {
        Write-Host "Connecting to server using Windows authentication."
    }

    try {
        $server.ConnectionContext.Connect()
    } catch {
        Write-Error "An error occurred connecting to the database server!`r`n$($_.Exception.ToString())"
    }
}

function AddPercentHandler {
    param($smoBackupRestore, $action)

    $percentEventHandler = [Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] { Write-Host $dbName $action $_.Percent "%" }
    $completedEventHandler = [Microsoft.SqlServer.Management.Common.ServerMessageEventHandler] { Write-Host $_.Error.Message}
        
    $smoBackupRestore.add_PercentComplete($percentEventHandler)
    $smoBackupRestore.add_Complete($completedEventHandler)
    $smoBackupRestore.PercentCompleteNotification=10
}

function CreatDevice {
    param($smoBackupRestore, $directory, $name)

    $devicePath = Join-Path $directory ($name)
    $smoBackupRestore.Devices.AddDevice($devicePath, "File")    
    return $devicePath
}

function CreateDevices {
    param($smoBackupRestore, $devices, $directory, $dbName, $incremental)
        
    $targetPaths = New-Object System.Collections.Generic.List[System.String]
	
	$extension = ".bak"
	
	if ($Incremental -eq $true){
		$extension = ".trn"
	}
    
    if ($devices -eq 1){
        $deviceName = $dbName + "_" + $timestamp + $extension
        $targetPath = CreatDevice $smoBackupRestore $directory $deviceName
        $targetPaths.Add($targetPath)
    } else {
        for ($i=1; $i -le $devices; $i++){
            $deviceName = $dbName + "_" + $timestamp + "_" + $i + $extension
            $targetPath = CreatDevice $smoBackupRestore $directory $deviceName
            $targetPaths.Add($targetPath)
        }
    }
    return $targetPaths
}

function BackupDatabase {
    param($dbName, $devices, $compressionOption, $incremental, $copyonly)  
    
    $smoBackup = New-Object Microsoft.SqlServer.Management.Smo.Backup
    $targetPaths = CreateDevices $smoBackup $devices $BackupDirectory $dbName $incremental

    Write-Host "Attempting to backup database $ServerName.$dbName to:"
    $targetPaths
    Write-Host ""

	if ($incremental -eq $true){
		$smoBackup.Action = "Log";            
		$smoBackup.BackupSetDescription = "Log backup of " + $dbName                  
		$smoBackup.LogTruncation = "Truncate"
	} else {
		$smoBackup.Action = "Database"
		$smoBackup.BackupSetDescription = "Full Backup of " + $dbName
	}
	
	$smoBackup.BackupSetName = $dbName + " Backup"	
	$smoBackup.MediaDescription = "Disk"
	$smoBackup.CompressionOption = $compressionOption
	$smoBackup.CopyOnly = $copyonly
	$smoBackup.Initialize = $true
	$smoBackup.Database = $dbName;
    
    try {
        AddPercentHandler $smoBackup "backed up"
        $smoBackup.SqlBackup($server)
    } catch {
        Write-Error "An error occurred backing up the database!`r`n$($_.Exception.ToString())"
    }
 
    Write-Host "Backup completed successfully."
}

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null
 
$server = New-Object Microsoft.SqlServer.Management.Smo.Server $ServerName

ConnectToDatabase $server $SqlLogin $SqlPassword

$database = $server.Databases | Where-Object { $_.Name -eq $DatabaseName }
$timestamp = if(-not [string]::IsNullOrEmpty($Stamp)) { $Stamp } else { Get-Date -format yyyy-MM-dd-HHmmss }

if (-not (Test-Path $BackupDirectory)) {
    Write-Host "Creating output directory `"$BackupDirectory`"."
    New-Item $BackupDirectory -ItemType Directory | Out-Null
}

if ($database -eq $null) {
    Write-Error "Database $DatabaseName does not exist on $ServerName"
}

if ($Incremental -eq $true) {

	if ($database.RecoveryModel -eq 3) {
		write-error "$DatabaseName has Recovery Model set to Simple. Log backup cannot be run."
	}
	
	if ($database.LastBackupDate -eq "1/1/0001 12:00 AM") {
		write-error "$DatabaseName has no Full backups. Log backup cannot be run."
	}
}

BackupDatabase $DatabaseName $Devices $CompressionOption $Incremental $CopyOnly