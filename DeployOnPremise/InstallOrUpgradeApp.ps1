function InstallOrUpgradeApp {
    Param(
        [string] $instance,
        [string] $tenant,
        [string] $path
    )

    $app = Get-NAVAppInfo -Path $path
    $published = Get-NAVAppInfo -ServerInstance $instance -Name $app.Name -Publisher $app.Publisher -TenantSpecificProperties -Tenant $tenant

    $installed = $published | Where-Object -Property 'IsInstalled' -EQ -Value True | Select-Object -First

    Publish-NAVApp -ServerInstance $instance -Path $path    
    if ($installed) {        
        Sync-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Mode ForceSync -Force
        Start-NAVAppDataUpgrade -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
        Unpublish-NAVApp -ServerInstance $instance -Publisher $installed.Publisher -Name $installed.Name -Version $installed.Version
    } else {
        Sync-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
        Install-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
    }
}
