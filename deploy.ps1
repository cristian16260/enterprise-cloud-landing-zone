# Script de despliegue automatizado para Windows PowerShell
$ErrorActionPreference = "Stop"

# Orden estricto de despliegue
$Modules = @("00-bootstrap", "01-network", "02-compute")
# En el futuro agregaras: "03-observability", "04-gitops"

Write-Host "[*] Iniciando despliegue de Enterprise Cloud Landing Zone..." -ForegroundColor Cyan

foreach ($Module in $Modules) {
    Write-Host "=======================================================" -ForegroundColor Magenta
    Write-Host "[>] Procesando Modulo: $Module" -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor Magenta
    
    Set-Location -Path $Module
    
    Write-Host "[-] Inicializando Terraform..." -ForegroundColor Cyan
    terraform init -input=false
    
    Write-Host "[-] Generando Plan..." -ForegroundColor Cyan
    terraform plan -out=tfplan -input=false
    
    Write-Host "[-] Aplicando Cambios..." -ForegroundColor Green
    terraform apply -input=false -auto-approve tfplan
    
    Set-Location -Path ..
}

Write-Host "[OK] Despliegue Multi-Modulo Completado!" -ForegroundColor Green
