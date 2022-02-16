<#
.SYNOPSIS
    Toggle the approval and installation of a specific KB across all agents using the API and no 3rd party libraries.

.REQUIREMENTS
    - You will need an API key from Tactical RMM which should be passed as parameters (DO NOT hard code in script).  Do not run this on each agent (see notes).  

.NOTES
    - This script is designed to run on a single computer.  Ideally, it should be run on the Tactical RMM server or other trusted device.
    - This script cycles through each agent toggling the approval and installation of a specific kb.  Tactical will do the installation when it's ready.

.PARAMETERS
    - $ApiKeyTactical   - Tactical API Key
    - $ApiUrlTactical   - Tactical API Url
    - $Kb               - Microsoft Kb number to install
   
.EXAMPLE
    - KB_Approve_Install.ps1 -ApiKeyTactical 1234567 -ApiUrlTactical api.yourdomain.com  -Kb "KB123456789"
		
.VERSION
	- v1.0 Initial Release by https://github.com/bc24fl/tacticalrmm-scripts/
#>

param(
    [string] $ApiKeyTactical,
    [string] $ApiUrlTactical,
    [string] $Kb
)

if ([string]::IsNullOrEmpty($ApiKeyTactical)) {
    throw "ApiKeyTactical must be defined. Use -ApiKeyTactical <value> to pass it."
}

if ([string]::IsNullOrEmpty($ApiUrlTactical)) {
    throw "ApiUrlTactical must be defined. Use -ApiUrlTactical <value> to pass it."
}

if ([string]::IsNullOrEmpty($Kb)) {
    throw "Kb must be defined. Use -Kb <value> to pass it."
}

$headers= @{
    'X-API-KEY' = $ApiKeyTactical
}

# Get all agents
try {
    $agentsResult = Invoke-RestMethod -Method 'Get' -Uri "https://$ApiUrlTactical/agents" -Headers $headers -ContentType "application/json"
}
catch {
    throw "Error invoking get all agents on Tactical RMM with error: $($PSItem.ToString())"
}

foreach ($agents in $agentsResult) {

    $agentId        = $agents.agent_id
    $agentHostname  = $agents.hostname
    $agentStatus    = $agents.status

    # Get agent updates
    try {
        $agentUpdateResult = Invoke-RestMethod -Method 'Get' -Uri "https://$ApiUrlTactical/winupdate/$agentId/" -Headers $headers -ContentType "application/json"
    }
    catch {
        Write-Error "Error invoking winupdate on agent $agentHostname - $agentId with error: $($PSItem.ToString())"
    }

    foreach ($update in $agentUpdateResult){
        $updateId       = $update.id 
        $updateKb       = $update.kb 
        $updateAction   = $update.action

        if ($Kb -eq $updateKb -And $updateAction -eq "nothing"){
            Write-Host "KB $updateKB is available for installation on agent $agentHostname"

            # Set Approve KB
            $body = @{
                "action"   = "approve"
            }
            try {
                $updateApproveKb = Invoke-RestMethod -Method 'Put' -Uri "https://$ApiUrlTactical/winupdate/$updateId/" -Body ($body|ConvertTo-Json) -Headers $headers -ContentType "application/json"
                Write-Host "Agent $agentHostname toggling approval of $updateKB"
            }
            catch {
                Write-Error "Error invoking Approve KB on agent $agentHostname - $agentId with error: $($PSItem.ToString())"
            }

            # Set Install KB
            $body = @{}
            try {
                $updateInstallKb = Invoke-RestMethod -Method 'Post' -Uri "https://$ApiUrlTactical/winupdate/$agentId/install/" -Body ($body|ConvertTo-Json) -Headers $headers -ContentType "application/json"
                Write-Host "Agent $agentHostname toggling installation of $updateKB"  
            }
            catch {
                Write-Error "Error invoking Install KB on agent $agentHostname - $agentId with error: $($PSItem.ToString())"
            }
        }
    } 
} 
