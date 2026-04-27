#!/bin/bash
# Script de despliegue automatizado para entornos CI/CD o Git Bash
set -e

# Orden estricto de despliegue
MODULES=("00-bootstrap" "01-network" "02-compute" "03-observability")
# En el futuro agregarás: "04-gitops"

echo "🚀 Iniciando despliegue de Enterprise Cloud Landing Zone..."

for MODULE in "${MODULES[@]}"; do
    echo "======================================================="
    echo "📦 Procesando Módulo: $MODULE"
    echo "======================================================="
    
    cd "$MODULE"
    
    echo "🔧 Inicializando Terraform..."
    terraform init -input=false
    
    echo "📋 Generando Plan..."
    terraform plan -out=tfplan -input=false
    
    echo "🚀 Aplicando Cambios..."
    terraform apply -input=false -auto-approve tfplan
    
    cd ..
done

echo "✅ ¡Despliegue Multi-Módulo Completado!"
