# Infraestructura AWS — EFT DevOps (ISY1101)

Scripts para provisionar (y luego destruir) la infraestructura del proyecto en AWS: ECR, ECS Fargate,
Application Load Balancer, RDS PostgreSQL, IAM, Secrets Manager y un dashboard de CloudWatch.

## Arquitectura de despliegue

```
Internet
   │
   ▼
[ ALB :80 ]  (Security Group: 80 desde 0.0.0.0/0)
   ├── default            → Target Group frontend (:80)  → ECS Fargate "frontend" (Nginx + React)
   └── path /api/*         → Target Group backend  (:3000) → ECS Fargate "backend"  (Node/Express)
                                                                     │
                                                                     ▼
                                                    RDS PostgreSQL (sin IP publica,
                                                    solo acepta trafico del SG del backend)
```

- Un solo ALB con enrutamiento por path evita problemas de CORS (todo bajo el mismo origen) y da una
  URL pública estable aunque las tareas Fargate cambien de IP en cada despliegue.
- Se usa la **VPC por defecto** (sin NAT Gateway) para minimizar costo/complejidad: las tareas Fargate
  reciben IP pública solo para poder hacer `pull` desde ECR y enviar logs/métricas, pero quedan
  protegidas por Security Groups restrictivos, no por estar en una subred privada. RDS nunca tiene IP
  pública.
- Base de datos en **RDS** (no en un contenedor) para producción: backups automáticos, parches
  gestionados por AWS y persistencia fuera del ciclo de vida de las tareas.

## Requisitos previos

- AWS CLI v2 instalado y configurado (`aws configure`) con un usuario/rol que tenga permisos de
  administración para crear estos recursos (los scripts NO configuran tus credenciales; usa las tuyas).
- `envsubst` disponible (viene con `gettext`; en Git Bash/WSL/Linux/macOS ya está).
- Haber creado el repositorio de GitHub y tener claro el nombre exacto del proyecto (`eft-devops` por
  defecto, configurable en `00-config.env`).

**Nunca pegues tus credenciales de AWS en un chat, IA o issue.** Todos los pasos que generan
credenciales (IAM access key) se ejecutan en tu propia terminal.

### Si usas AWS Academy (Learner Lab)

Los scripts detectan automáticamente esta situación en `02-iam.sh`, pero conviene saberlo de antemano:

- **No se pueden crear roles ni usuarios IAM.** `02-iam.sh` detecta el `AccessDenied` y usa el rol ya
  existente `LabRole` tanto para el "execution role" como para el "task role" de ECS (ese rol ya trae
  permisos amplios, así que normalmente no hace falta agregarle nada).
- **No hay un usuario IAM dedicado para GitHub Actions.** En su lugar, usa las credenciales
  *temporales* de tu propia sesión del Lab: en el panel del Learner Lab, botón **AWS Details → AWS CLI**,
  copia `aws_access_key_id`, `aws_secret_access_key` y `aws_session_token`, y pégalos tú mismo (nunca
  en un chat) como GitHub Secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN`.
- **Esas credenciales expiran junto con la sesión del Lab** (típicamente ~4 horas, o al reiniciarla).
  Actualiza los 3 secrets en GitHub antes de volver a correr el pipeline o de grabar el video si ha
  pasado tiempo desde la última vez que iniciaste el Lab.
- El Lab normalmente fuerza una región fija (revisa cuál es la tuya) y tiene un presupuesto acotado:
  la arquitectura de este proyecto (sin NAT Gateway, RDS `db.t3.micro`, 1-3 tareas Fargate pequeñas)
  está pensada para mantenerse dentro de ese margen durante una sesión de trabajo/grabación.

## Orden de ejecución

```bash
cd infra
cp 00-config.env.example 00-config.env
# editar 00-config.env: AWS_REGION, PROJECT, DB_PASSWORD (una password real y segura)

source 00-config.env
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
# agregar AWS_ACCOUNT_ID a 00-config.env

./01-ecr.sh                 # repos de imagenes
./02-iam.sh                 # roles ECS + usuario IAM para GitHub Actions (correr de nuevo tras 03)
./03-network-alb-rds.sh     # SGs, ALB, target groups, RDS (tarda varios minutos por RDS)
./02-iam.sh                 # segunda pasada: ahora si existe DB_SECRET_ARN, agrega el permiso de leerlo
./04-render-taskdefs.sh     # genera infra/ecs/task-def-*.json (se commitean al repo)
```

En este punto:
1. Sube (`git add/commit/push`) los `task-def-*.json` generados.
2. Configura los **GitHub Secrets** del repo (ver `.github/workflows/ci-cd.yml`):
   - Cuenta normal: credenciales del usuario IAM creado en `02-iam.sh`
     (`aws iam create-access-key --user-name <PROJECT>-github-actions`, ejecutado por ti).
   - AWS Academy: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN` de tu sesión del
     Learner Lab (ver sección de arriba).
   - En ambos casos, agrega también las **GitHub Variables** (cluster, servicios, repos ECR, ALB DNS).
3. Dispara el pipeline (push a `main` o `workflow_dispatch`) para que construya y publique las
   primeras imágenes en ECR — **antes** de crear los servicios ECS, porque `create-service` necesita
   que la imagen ya exista en el repositorio.

```bash
./05-ecs-deploy.sh          # cluster + servicios ECS conectados al ALB
./06-autoscaling.sh         # auto scaling del backend (1-3 tareas, 60% CPU)
./07-observability.sh       # dashboard de CloudWatch
```

Verifica accediendo a `http://$ALB_DNS` (impreso por `03-network-alb-rds.sh`).

## Alternativa: consola de AWS

Todo lo anterior puede hacerse igual desde la consola web de AWS (ECR, ECS, EC2 > Load Balancers,
RDS, IAM, Secrets Manager, CloudWatch) siguiendo el mismo orden y los mismos nombres/valores — útil
si prefieres mostrarlo paso a paso durante la grabación del video en vez de correr los scripts.

## Teardown (apagar todo para no seguir pagando)

```bash
cd infra
./teardown.sh
```

Pide confirmación explícita antes de borrar nada. Revisa igual la consola de Billing de AWS después
de correrlo.
