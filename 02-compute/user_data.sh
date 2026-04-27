#!/bin/bash
# Script inyectado en las instancias EC2 al momento del boot (User Data).
# Se ejecuta como usuario 'root' automáticamente.

# 1. Actualizar el sistema e instalar Nginx
yum update -y
yum install -y nginx

# 2. Iniciar y habilitar Nginx (para que persista ante reboots)
systemctl start nginx
systemctl enable nginx

# 3. Crear archivo HTML personalizado
cat > /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Enterprise Landing Zone</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background-color: #0f172a; color: white; }
        .box { padding: 40px; border-radius: 10px; background-color: #1e293b; display: inline-block; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
        h1 { color: #38bdf8; }
        .footer { margin-top: 20px; font-size: 14px; color: #94a3b8; }
    </style>
</head>
<body>
    <div class="box">
        <h1>Servidor Inmutable - Stack 2026</h1>
        <p>El trafico esta fluyendo exitosamente desde el ALB (Subred Publica)<br>hacia este nodo EC2 oculto en la Subred Privada.</p>
        <div class="footer">Infraestructura como Codigo - Despliegue Automatizado</div>
    </div>
</body>
</html>
EOF

# 4. Asegurar permisos correctos
chmod 644 /usr/share/nginx/html/index.html

# 5. Forzar reinicio de servicio por si acaso
systemctl restart nginx
