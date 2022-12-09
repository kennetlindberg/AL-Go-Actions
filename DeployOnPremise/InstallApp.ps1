function InstallOrUpgradeApp {
    Param(
        [string] $instance
        [string] $tenant
        [string] $path
    )
    $app = Get-NAVAppInfo -Path $path
    
    $installed = Get-NAVAppInfo -Name $app.Name -Publisher $app.Publisher -TenantSpecificProperties -Tenant $tenant
    $installed | Where-Object -Property 'IsInstalled' -EQ -Value False {
        
    }
    
    if ($installed -gt 1) {
        
    }
    
    Publish-NAVApp -ServerInstance $instance -Path $path
    Sync-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force
    Install-NAVApp -ServerInstance $instance -Publisher $app.Publisher -Name $app.Name -Version $app.Version -Force                
}
