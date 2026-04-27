# ☁️ Enterprise Cloud Landing Zone

![Terraform](https://img.shields.io/badge/terraform-1.6.0+-623CE4?style=for-the-badge&logo=terraform)
![AWS](https://img.shields.io/badge/AWS-Amazon_Web_Services-FF9900?style=for-the-badge&logo=amazonaws)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![Grafana](https://img.shields.io/badge/grafana-%23F46800.svg?style=for-the-badge&logo=grafana&logoColor=white)

Este repositorio contiene la definición de **Infraestructura como Código (IaC)** para una *Landing Zone* empresarial en AWS. Fue diseñada utilizando principios de alta disponibilidad (HA), seguridad por defecto, inmutabilidad y automatización GitOps.

---

## 🏛️ Arquitectura Modular

La infraestructura está construida utilizando un enfoque de **Blast Radius Isolation**. En lugar de un gran monolito donde un error destruye toda la plataforma, el código está separado en 4 módulos independientes con estados aislados:

### 📦 Módulo 00: Bootstrap (`00-bootstrap`)
- Base de la integridad del proyecto.
- Crea el S3 Bucket versionado y encriptado.
- Crea la tabla DynamoDB para *State Locking* de Terraform.

### 🌐 Módulo 01: Core Network (`01-network`)
- VPC Multi-AZ (`/16`) lista para el crecimiento.
- Subredes Públicas (ALB, Bastion) y Subredes Privadas (Workloads EC2/ECS/RDS).
- Enrutamiento: Internet Gateway y NAT Gateway para tráfico de salida seguro.

### ⚙️ Módulo 02: Cómputo Inmutable (`02-compute`)
- Patrón de arquitectura: *Application Load Balancer* (Público) → *Auto Scaling Group* (Privado).
- Resolutor dinámico para la última versión de **Amazon Linux 2023**.
- Inyección automatizada de aplicaciones vía archivos externos `user_data.sh`.
- Security Groups configurados bajo el Principio de Menor Privilegio (Las EC2 solo aceptan tráfico del ALB).

### 📊 Módulo 03: Observabilidad NOC (`03-observability`)
- Nodo de operaciones de red (NOC) corriendo **Grafana OSS**.
- Detección dinámica de IP pública: El puerto 3000 de Grafana *solo* se abre a la IP del administrador que despliega el stack.
- Zero-Trust: La instancia usa un `IAM Instance Profile` con acceso de solo lectura a CloudWatch, sin necesitar credenciales estáticas.

---

## 🚀 Despliegue GitOps (CI/CD)

El ciclo de vida completo está automatizado mediante GitHub Actions. Todo cambio subido a la rama `main` iniciará una reconciliación de la infraestructura.

### Requisitos Previos (GitHub)
Para que el pipeline funcione, debes agregar los siguientes *Repository Secrets* en GitHub (`Settings` > `Secrets and variables` > `Actions`):

| Nombre del Secreto | Descripción |
|---|---|
| `AWS_ACCESS_KEY_ID` | Tu Key ID de usuario IAM con permisos administrativos. |
| `AWS_SECRET_ACCESS_KEY` | Tu Secret Key correspondiente. |

### Flujos Soportados:
1. **Apply Automático:** Se lanza en cada `push` a la rama `main`.
2. **Apply / Destroy Manual (FinOps):** Puedes lanzar un despliegue o una destrucción total desde la pestaña de *Actions* usando el gatillo `workflow_dispatch`. La destrucción elimina de forma ordenada: Módulo 3 -> 2 -> 1, ahorrando costos de AWS cuando no está en uso.

---

## 💻 Despliegue Manual (Local)

Si estás desarrollando y necesitas probar cambios localmente antes de hacer push, utiliza nuestros orquestadores locales para superar el problema de las dependencias cruzadas en Terraform:

### En Windows (PowerShell)
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process # Solo si están bloqueados
.\deploy.ps1
```

### En Linux / Mac (Git Bash / ZSH)
```bash
chmod +x deploy.sh
./deploy.sh
```

Ambos scripts recorrerán cada módulo de forma secuencial haciendo `terraform init`, `plan` y `apply -auto-approve`.

---

## 🧹 FinOps: Limpieza Total (Zero Cost)
Para evitar cargos en tu cuenta de AWS cuando no uses la plataforma, el código fue modificado intencionalmente (`force_destroy = true`) para permitir una destrucción segura de arriba hacia abajo (desde el Módulo 03 hasta el Módulo 00).

```powershell
# 1. Destruir cargas de trabajo (Red, Cómputo y Observabilidad)
.\destroy.ps1

# 2. Borrar los cimientos (Bucket S3 y tabla DynamoDB)
cd 00-bootstrap
terraform destroy -auto-approve
```

---

## 🛠️ Estándares Aplicados
- **Variables Validadas:** Bloques `validation` estrictos en las variables de CIDRs y nombres.
- **For_Each sobre Count:** Uso de mapas con claves estables (`for_each`) para la creación de subredes, evitando fallos de índice frágiles en los estados.
- **Data Sources Dinámicos:** Evitamos IDs duros de AMIs e IPs para evitar la deuda técnica.
- **Comentarios Nivel Experto:** Documentación enfocada en restricciones de nube y decisiones de diseño arquitectónico.

---
*Mantenido por Cristian-Meza | Enterprise-Stack-2026*
