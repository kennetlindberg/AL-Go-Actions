Param(
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $token,
    [Parameter(Mandatory = $true)]
    [string] $settingsJson
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$telemetryScope = $null
$bcContainerHelperPath = $null

try {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
    . (Join-Path -Path $PSScriptRoot -ChildPath "InstallOrUpgradeApp.ps1" -Resolve)

    $settings = $settingsJson | ConvertFrom-Json

    Write-Output $settings
    
    Write-Output $settingsJson

    $instance = $settings.onPremServerInstance
    if ($instance -eq '') {
        throw "Setting onPremServerInstance needs to be specified".
    }

    $tenant = $settings.onPremServerTenant
    if ($tenant -eq '') {
        $tenant = 'default'
    }

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

    #"C:\Program Files\Microsoft Dynamics 365 Business Central\200\Service\Microsoft.Dynamics.Nav.Server.exe" $BC200 /config "C:\Program Files\Microsoft Dynamics 365 Business Central\200\Service\Microsoft.Dynamics.Nav.Server.exe.config"
    $imagePath = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\MicrosoftDynamicsNavServer`$$instance" -Name 'ImagePath'
    $imagePath = $imagePath.Split('"')[1]
    $imagePath = Split-Path $imagePath -Parent
    Import-Module (Join-Path $imagePath 'Microsoft.Dynamics.Nav.Apps.Management.psd1')
    
    $appFiles = Get-ChildItem -Path $temp -Filter *.app

    $appFiles | ForEach-Object {
        $app = Get-NAVAppInfo -Path $_.FullName
        if ($app.Dependencies.Count -eq 0) {
            InstallOrUpgradeApp -Path $_.FullName -instance $instance -tenant $tenant
        }
    }

    $appFiles | ForEach-Object {
        $app = Get-NAVAppInfo -Path $_.FullName
        if ($app.Dependencies.Count -gt 0) {
            InstallOrUpgradeApp -Path $_.FullName -instance $instance -tenant $tenant
        }
    }    
}
catch {
    OutputError -message "Deploy On Premise failed.$([environment]::Newline)Error: $($_.Exception.Message)$([environment]::Newline)Stacktrace: $($_.scriptStackTrace)"
}
finally {
}
