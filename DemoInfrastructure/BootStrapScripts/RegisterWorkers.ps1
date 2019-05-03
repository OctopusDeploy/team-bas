function Get-MyPublicIPAddress { 
  # Get Ip Address of Machine 
  Write-Host "Getting public IP address" 
  $ipAddress = Invoke-RestMethod http://ipinfo.io/json | Select-Object -exp ip 
  return $ipAddress 
} 

$ipAddress = Get-MyPublicIPAddress 
$ipAddress = $ipAddress.Trim() 
$octopusServerUrl = "#{Global.Octopus.Url}"
$octopusApiKey = "#{Global.Octopus.ApiKey}"   
$computerName = "#{Project.AWS.InstanceName}"
$applicationName = "#{Project.Application.Name}"
$machinesToRegister = "#{Project.Machines.List}"
$workerPool = "#{Project.WorkerPool.Name}"

Write-Output "Public IP address: " + $ipAddress 

Write-Output "Configuring and registering Tentacle" 

Set-Location "${env:ProgramFiles}\Octopus Deploy\Tentacle" 

$machineList = $machinesToRegister -split ","
$previousMachineName = ""

  foreach ($machine in $machineList) {
      if ($previousMachineName -ne $machine) {
          $machineIndex = 1
      }
      else{
          $machineIndex = $machineIndex + 1
      }

      $previousMachineName = $machine

      if ($machineIndex -le 10){
          $machineIndexAsString = "0$machineIndex"
      }
      else{
          $machineIndexAsString = "$machineIndex"
      }

      $registerComputerName = "$computerName-$environment-$machine-$machineIndexAsString"
      
      Write-Host "Registering the worker $registerComputerName with the Octopus instance $octopusServerUrl with the workerpool $workerPool"
      & .\tentacle.exe register-worker --instance "Tentacle" --server $octopusServerUrl --name $registerComputerName --publicHostName $ipAddress --apiKey $octopusApiKey --workerpool $workerPool --comms-style TentaclePassive --force --console | Write-Host	
	  if ($lastExitCode -ne 0) { 
        throw "Installation failed on register-with" 
      } 	
      else{
          Write-Host "Successfully registered the machine $registerComputerName"
      }    	 	    
  }