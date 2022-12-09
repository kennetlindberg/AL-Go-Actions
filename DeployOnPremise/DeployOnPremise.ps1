Param(
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $token,
    [Parameter(HelpMessage = "ServerInstance to install apps to", Mandatory = $true)]
    [string] $instance,
    [Parameter(HelpMessage = "Tenant to install apps to", Mandatory = $false)]
    [string] $tenant = 'default'
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$telemetryScope = $null
$bcContainerHelperPath = $null

try {
    .InstallOrUpgradeApp.ps1

    $headers = @{
        Authorization="Bearer $token"
    }
    $base = "$($ENV:GITHUB_API_URL)/repos/$($ENV:GITHUB_REPOSITORY)"

    # Get Workflow Id
    $result = Invoke-RestMethod -Uri "$base/actions/workflows" -Headers $headers
    $workflow = $result.workflows | Where-Object 'name' -EQ -Value ' CI/CD'

    # Get Workflow Run Id
    $date = (Get-Date).AddDays(-2).ToString('yyyy-MM-dd')
    $result = Invoke-RestMethod -Uri "$base/actions/workflows/$($workflow.id)/runs?status=success&created=>$date&branch=main" -Headers $headers
    if ($result.total_count -eq 0) {
        throw "Could not find a suitable workflow run to get artifacts from."
    }
    $run = $result.workflow_runs | Sort-Object -Property 'created_at' -Descending | Select-Object -First 1

    # Get Workflow Run Artifacts
    $result = Invoke-RestMethod -Uri "$base/actions/runs/$($run.id)/artifacts" -Headers $headers
    if ($result.total_count -eq 0) {
        throw "There were no artifacts in the workflow run."
    }
    $artifact = $result.artifacts | Where-Object -Property 'name' -Like -Value '*-Apps-*'

    # Get Artifact Zip File
    $temp = $ENV:RUNNER_TEMP
    $path = "$temp/$($artifact.Name).zip"
    Invoke-RestMethod -Uri "$base/actions/artifacts/$($artifact.Id)/zip" -Headers $headers -OutFile $path

    Expand-Archive -Path $path -DestinationPath $temp -Force

    $instance = 'test'
    Import-Module "C:\Program Files\Microsoft Dynamics 365 Business Central\190\Service\Microsoft.Dynamics.Nav.Apps.Management.psd1"

    $appFiles = Get-ChildItem -Path $temp -Filter *.app

    $appFiles | ForEach-Object {
        $app = Get-NAVAppInfo -Path $_.FullName
        if ($app.Dependencies.Count -eq 0) {
            InstallOrUpgradeApp -Path $appFiles.FullName -instance 'default' -tenant 'default'
        }
    }

    $appFiles | ForEach-Object {
        $app = Get-NAVAppInfo -Path $_.FullName
        if ($app.Dependencies.Count -gt 0) {
            InstallOrUpgradeApp -Path $appFiles.FullName -instance 'default' -tenant 'default'
        }
    }    
}
catch {
    OutputError -message "Deploy On Premise failed.$([environment]::Newline)Error: $($_.Exception.Message)$([environment]::Newline)Stacktrace: $($_.scriptStackTrace)"
}
finally {
    # CleanupAfterBcContainerHelper -bcContainerHelperPath $bcContainerHelperPath
}
