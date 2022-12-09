Param(
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $token
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$telemetryScope = $null
$bcContainerHelperPath = $null

try {
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

    Expand-Archive -Path $path -DestinationPath $temp

    $instance = 'test'
    Import-Module "C:\Program Files\Microsoft Dynamics 365 Business Central\190\Service\Microsoft.Dynamics.Nav.Apps.Management.psd1"

    $appFiles = Get-ChildItem -Path $temp -Filter *.app
    
    $appFiles | ForEach-Object {
        $app = Get-NAVAppInfo -Path $_.FullName
        
        if ($app.Dependencies.Count -eq 0) {
            Publish-NAVApp -ServerInstance $instance -Path $_.FullName
            Sync-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
            Install-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force            
        }
    }

    Write-Host "Publishing $($app.Name)"

    if ($app.Dependencies.Count -gt 0) {
    $app.Dependencies | ForEach-Object {
      Write-Host "Publishing dependency $($_.Name)"
    }
}
catch {
    OutputError -message "Deploy action failed.$([environment]::Newline)Error: $($_.Exception.Message)$([environment]::Newline)Stacktrace: $($_.scriptStackTrace)"
    TrackException -telemetryScope $telemetryScope -errorRecord $_
}
finally {
    CleanupAfterBcContainerHelper -bcContainerHelperPath $bcContainerHelperPath
}
