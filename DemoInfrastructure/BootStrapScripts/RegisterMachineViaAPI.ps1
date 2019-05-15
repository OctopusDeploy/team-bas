$OctopusAPIKey = $OctopusParameters["Global.Octopus.ApiKey"]
$IpAddress = $OctopusParameters["Project.VM.IPAddress"]
$VmName = $OctopusParameters["Project.Target.Name"]
$OctopusUrl = $OctopusParameters["Global.Octopus.Url"]
$Roles = $OctopusParameters["Project.Roles.List"]
$Environment = $OctopusParameters["Octopus.Environment.Id"]
$Tenants = $OctopusParameters["Project.Tenants.List"]
$SpaceId = $OctopusParameters["Octopus.Space.Id"]

$header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$header.Add("X-Octopus-ApiKey", $OctopusAPIKey)

$discoverUrl = "$OctopusUrl/api/$SpaceId/machines/discover?host=$IpAddress&port=10933&type=TentaclePassive"
Write-Host "Discovering the target $discoverUrl"
$discoverResponse = Invoke-RestMethod $discoverUrl -Headers $header 
Write-Host "ProjectResponse: $discoverResponse"

$workerThumbprint = $discoverResponse.EndPoint.Thumbprint
Write-Host "Thumbprint = $workerThumbprint"

$tenantList = $Tenants -split ","
$tenantIdList = @()

foreach($tenant in $tenantList)
{
    $tenantEscaped = $tenant.Replace(" ", "%20")
    $tenantUrl = "$OctopusUrl/api/$SpaceId/tenants?name=$tenantEscaped"
    $tenantResponse = Invoke-RestMethod $tenantUrl -Headers $header 

    $tenantId = $tenantResponse.Items[0].Id
    $tenantIdList += $tenantId
}

$roleList = $Roles -split ","

$rawRequest = @{
	Id = $null;
    MachinePolicyId = "MachinePolicies-1";
    Name = $VmName;
	IsDisabled = $false;
	HealthStatus = "Unknown";
	HasLatestCalamari = $true;
	StatusSummary = $null;
	IsInProcess = $true;
	Endpoint = @{
    	Id = $null;
		CommunicationStyle = "TentaclePassive";
		Links = $null;
		Uri = "https://$IpAddress`:10933";
		Thumbprint = "$workerThumbprint";
		ProxyId = $null
    };
	Links = $null;
	TenantedDeploymentParticipation = "TenantedOrUntenanted";
	Roles = $roleList;
	EnvironmentIds = @("$Environment");
	TenantIds = $tenantIdList;
	TenantTags = @()}

$jsonRequest = $rawRequest | ConvertTo-Json

Write-Host "Sending in the request $jsonRequest"

$machineUrl = "$OctopusUrl/api/$SpaceId/machines"
Write-Host "Creating the machine"
$machineResponse = Invoke-RestMethod $machineUrl -Headers $header -Method POST -Body $jsonRequest

Write-Host "Worker's response: $machineResponse"