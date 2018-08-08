$octopusServerUrl = $OctopusParameters["Global.Octopus.Url"]
$octopusApiKey = $OctopusParameters["Global.Octopus.ApiKey"]
Set-Location "${env:ProgramFiles}\Octopus Deploy\Tentacle"

& .\tentacle.exe deregister-from --server $octopusServerUrl --apiKey $octopusApiKey --multiple --console | Write-Output

 $slackBody = @{
	"channel" = "#demo-env-pulse"
	"username" = "Register Additional Servers"
	"text" = ":wave: Successfully deregistered the server from $octopusServerUrl"
}
Invoke-WebRequest -Method POST -Uri https://hooks.slack.com/services/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 -Body (ConvertTo-Json -Compress -InputObject $slackBody)