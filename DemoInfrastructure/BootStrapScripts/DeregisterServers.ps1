$octopusServerUrl = $OctopusParameters["Global.Octopus.Url"]
$octopusApiKey = $OctopusParameters["Global.Octopus.ApiKey"]
$serverName = "#{Project.AWS.InstanceName}"
Set-Location "${env:ProgramFiles}\Octopus Deploy\Tentacle"

& .\tentacle.exe deregister-from --server $octopusServerUrl --apiKey $octopusApiKey --multiple --console | Write-Output