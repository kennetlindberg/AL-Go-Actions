function InstallOrUpgradeApp {
    Param(
        [string] $instance,
        [string] $tenant,
        [string] $path
    )

    $app = Get-NAVAppInfo -Path $path
    $published = Get-NAVAppInfo -ServerInstance $instance -Name $app.Name -Publisher $app.Publisher -TenantSpecificProperties -Tenant $tenant

    # Unpublish uninstalled versions
    $published | Where-Object -Property 'IsInstalled' -EQ -Value False | ForEach-Object {
        Unpublish-NAVApp -ServerInstance $instance -Name $_.Name -Publisher $_.Publisher -Version $_.Version
    }

    $installed = $published | Where-Object -Property 'IsInstalled' -EQ -Value True -First | Select-Object -First

    Publish-NAVApp -ServerInstance $instance -Path $path    
    if ($installed) {        
        Sync-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Mode ForceSync -Force
        Start-NAVAppDataUpgrade -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
        Unpublish-NAVApp -ServerInstance $instance -Publisher $installed.Publisher -Name $installed.Name -Version $installed.Version
    } else {
        Sync-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
        Install-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
    }
    
    Publish-NAVApp -ServerInstance $instance -Path $path
    Sync-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
    Install-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force                
}
