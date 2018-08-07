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
$environment = "#{Octopus.Environment.Name}"
$applicationName = "#{Project.Application.Name}"
$machinesToRegister = "#{Project.Machines.List}"
$tenants = "#{Project.Tenants.List}"		  

Write-Output "Public IP address: " + $ipAddress 

Write-Output "Configuring and registering Tentacle" 

Set-Location "${env:ProgramFiles}\Octopus Deploy\Tentacle" 

$tenantList = $tenants -split ","
$machineList = $machinesToRegister -split ","
$previousMachineName = ""

foreach ($tenant in $tenantList){
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

      $registerComputerName = "$computerName-$environment-$tenant-$machine-$machineIndexAsString"
      $applicationRoleName = "$applicationName-$machine"

      Write-Host "Registering the machine name $registerComputerName with the Octopus instance $octopusServerUrl with the role $applicationRoleName for the environment $environment"
      & .\tentacle.exe register-with --instance "Tentacle" --server $octopusServerUrl --role $applicationName --role $applicationRoleName --environment $environment --tenant $tenant --name $registerComputerName --publicHostName $ipAddress --apiKey $octopusApiKey --comms-style TentaclePassive --force --console | Write-Host	
      if ($lastExitCode -ne 0) { 
        throw "Installation failed on register-with" 
      } 	
      else{
          Write-Host "Successfully registered the machine $registerComputerName"
      }    
  }
}

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
      $applicationRoleName = "$applicationName-$machine"

      Write-Host "Registering the machine name $registerComputerName with the Octopus instance $octopusServerUrl with the role $applicationRoleName for the environment $environment"
      & .\tentacle.exe register-with --instance "Tentacle" --server $octopusServerUrl --role $applicationName --role $applicationRoleName --environment $environment --name $registerComputerName --publicHostName $ipAddress --apiKey $octopusApiKey --comms-style TentaclePassive --force --console | Write-Host	
      if ($lastExitCode -ne 0) { 
        throw "Installation failed on register-with" 
      } 	
      else{
          Write-Host "Successfully registered the machine $registerComputerName"
      }    
  }