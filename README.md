# EFT DevOps — ISY1101 (Introducción a Herramientas DevOps)

Gestor de tareas de 3 capas (frontend + backend + base de datos relacional) usado como caso práctico
para automatizar el ciclo de integración y entrega continua (CI/CD) con GitHub Actions, contenedores
Docker y despliegue en AWS ECS (Fargate).

## Arquitectura

```
[ Browser ] → [ Frontend: React + Nginx ] → [ Backend: Node/Express API ] → [ PostgreSQL ]
```

- **Frontend**: React (Vite), build estático servido por Nginx. Consume la API vía `VITE_API_URL`.
- **Backend**: Node.js + Express, expone `/health` y CRUD REST en `/api/tasks`, se conecta a Postgres
  con el driver `pg`.
- **Base de datos**: PostgreSQL.
  - En **desarrollo local** corre como contenedor (`docker-compose.yml`), con `db/init.sql` como
    schema inicial.
  - En **producción** se usa **Amazon RDS PostgreSQL** en vez de un contenedor (persistencia, backups
    automáticos y parches gestionados por AWS; ver `docs/informe.docx` para el detalle de la decisión).

Diagrama completo de arquitectura (local + AWS): [`docs/architecture.png`](docs/architecture.png).

## Estructura del repositorio

```
backend/          API REST (Express + pg)
frontend/         SPA (React + Vite), Dockerfile multi-stage con runtime Nginx
db/init.sql       Schema inicial de PostgreSQL
docker-compose.yml Orquestación local de los 3 servicios
.github/workflows/ Pipeline CI/CD (build → test → push a ECR → deploy a ECS)
infra/            Scripts y guía para provisionar la infraestructura AWS (ECR, ECS, RDS, IAM, SGs)
docs/             Informe, diagrama de arquitectura y guion del video de defensa
```

## Cómo levantar el entorno local

Requisitos: Docker y Docker Compose.

```bash
cp .env.example .env        # ajustar credenciales si se desea
docker compose up --build
```

- Frontend: http://localhost:5173
- Backend:  http://localhost:3000/health
- Postgres: expuesto solo dentro de la red interna `internal` del compose (no se publica al host)

Para bajar el entorno: `docker compose down` (agregar `-v` para borrar también el volumen de datos).

## Variables de entorno

| Variable        | Descripción                                  | Dónde se usa           |
|-----------------|-----------------------------------------------|-------------------------|
| `PGUSER`        | Usuario de PostgreSQL                          | `db`, `backend`         |
| `PGPASSWORD`    | Password de PostgreSQL                         | `db`, `backend`         |
| `PGDATABASE`    | Nombre de la base de datos                     | `db`, `backend`         |
| `VITE_API_URL`  | URL pública del backend (build-time, frontend) | `frontend` (build arg)  |

En producción, `PGPASSWORD` y la cadena de conexión se gestionan con **AWS Secrets Manager** y se
inyectan en la task definition de ECS; nunca se commitean al repositorio.

## Pipeline CI/CD

Definido en [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml):

1. **build-and-test**: instala dependencias, corre pruebas/lint y construye las imágenes Docker.
2. **push**: autentica contra Amazon ECR y publica las imágenes de `frontend` y `backend` con dos tags
   (`latest` y el SHA del commit) para trazabilidad.
3. **deploy**: registra una nueva revisión de la task definition de ECS y actualiza el servicio,
   esperando a que quede estable.

Se dispara en cada push a `main` y también admite ejecución manual (`workflow_dispatch`) para demos.

Configuración requerida en GitHub (**Settings → Secrets and variables → Actions**):

| Tipo     | Nombre                                            | Origen                                    |
|----------|----------------------------------------------------|--------------------------------------------|
| Secret   | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`        | `infra/02-iam.sh` (usuario `*-github-actions`), o tu sesión de AWS Academy |
| Secret   | `AWS_SESSION_TOKEN`                                 | Solo si usas AWS Academy Learner Lab (credenciales temporales, expiran ~4h) |
| Variable | `AWS_REGION`                                        | `infra/00-config.env`                      |
| Variable | `ECR_BACKEND_REPO`, `ECR_FRONTEND_REPO`             | `<PROJECT>-backend` / `<PROJECT>-frontend` |
| Variable | `ECS_CLUSTER`, `ECS_SERVICE_BACKEND`, `ECS_SERVICE_FRONTEND` | `infra/05-ecs-deploy.sh`         |
| Variable | `ALB_DNS`                                            | salida de `infra/03-network-alb-rds.sh`    |

> Si usas AWS Academy, revisa la sección dedicada en [`infra/README.md`](infra/README.md).

## Infraestructura AWS

Ver [`infra/README.md`](infra/README.md) para el detalle paso a paso (VPC/Security Groups, ECR, ECS
Fargate, RDS, IAM, Secrets Manager, CloudWatch) y los scripts de creación/teardown.

## Informe y video

- Informe técnico (Word): `docs/informe.docx`.
- Guion y checklist de la presentación/defensa: `docs/guion-video.md`.
