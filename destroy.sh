#!/bin/bash
# Script de destrucción (FinOps) para Linux/Mac
set -e

# Orden estricto INVERSO
MODULES=("03-observability" "02-compute" "01-network")

echo "🔥 Iniciando Destrucción Total..."

for MODULE in "${MODULES[@]}"; do
    echo "======================================================="
    echo "📦 Destruyendo Módulo: $MODULE"
    echo "======================================================="
    
    cd "$MODULE"
    terraform destroy -auto-approve -input=false
    cd ..
done

echo "✅ ¡Destrucción Completada!"
