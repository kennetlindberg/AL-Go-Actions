$app = Get-NAVAppInfo -Path 'C:\dev\al\bank-pro\bank-pro-einvoicing\Consilia Solutions_Bank Pro e-Invoicing_4.7.0.0.app'

Write-Host "Publishing $($app.Name)"

if ($app.Dependencies.Count -gt 0) {
  $app.Dependencies | ForEach-Object {
    Write-Host "Publishing dependency $($_.Name)"
  }
}
