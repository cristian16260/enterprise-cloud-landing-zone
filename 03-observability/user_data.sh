#!/bin/bash
# Script de instalacion para Grafana OSS en Amazon Linux 2023
# Se inyecta automaticamente via User Data al boot.

# 1. Actualizar el sistema e instalar librerias requeridas
yum update -y
yum install -y nano wget

# 2. Agregar el repositorio oficial de Grafana
cat <<EOF | tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# 3. Instalar Grafana
yum install -y grafana

# 4. Iniciar y habilitar el servicio para que resista reinicios del EC2
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

# Nota: Grafana tardara unos 30-60 segundos en estar disponible en el puerto 3000
