function InstallOrUpgradeApp {
    Param(
        [string] $instance,
        [string] $tenant,
        [string] $path
    )

    $app = Get-NAVAppInfo -Path $path

    Write-Host "Install Or Upgrade $($app.Name)"

    $published = Get-NAVAppInfo -ServerInstance $instance -Name $app.Name -Publisher $app.Publisher -TenantSpecificProperties -Tenant $tenant
    $installed = $published | Where-Object -Property 'IsInstalled' -EQ -Value True | Select-Object -First 1

    Publish-NAVApp -ServerInstance $instance -Path $path    
    if ($installed) {        
        if ($app.version -gt [System.Version]$installed.Version) {
            Write-Host "Upgrading $($app.Name) from $($installed.Version) to $($app.Version)"

            Sync-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Mode ForceSync -Force
            Start-NAVAppDataUpgrade -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
            Unpublish-NAVApp -ServerInstance $instance -Publisher $installed.Publisher -Name $installed.Name -Version $installed.Version
        } else {
            Write-Host "Same or newer version ($($installed.Version)) is already installed"
        }
    } else {
        Write-Host "Installing $($app.Name) ($($app.Version))"
        Sync-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
        Install-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
    }
}
