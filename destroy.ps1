# Script de destrucción (FinOps) para Windows PowerShell
$ErrorActionPreference = "Stop"

# Orden estricto INVERSO
$Modules = @("03-observability", "02-compute", "01-network")

Write-Host "[!] Iniciando Destruccion de Enterprise Cloud Landing Zone..." -ForegroundColor Red

foreach ($Module in $Modules) {
    Write-Host "=======================================================" -ForegroundColor Magenta
    Write-Host "[-] Destruyendo Modulo: $Module" -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor Magenta
    
    Set-Location -Path $Module
    
    Write-Host "[x] Ejecutando Terraform Destroy..." -ForegroundColor Red
    terraform destroy -auto-approve
    
    Set-Location -Path ..
}

Write-Host "[OK] Destruccion Completada. El S3 de Estado (00-bootstrap) se ha mantenido intacto por seguridad." -ForegroundColor Green
