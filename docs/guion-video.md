# Guion y checklist — Presentación y defensa (EFT ISY1101)

Duración objetivo: **10 a 15 minutos**. Grabar con OBS Studio, Xbox Game Bar (`Win+G`) o Zoom en
grabación local. Se recomienda grabar en una sola toma siguiendo este orden; si algo falla, cortar y
retomar desde el inicio de esa sección (no hace falta repetir todo).

Antes de grabar, tener abiertas y listas estas pestañas/terminales (evita tiempos muertos buscando):

1. Terminal en la raíz del repo con `docker compose up --build` ya probado (para no esperar builds en vivo).
2. VS Code (o editor) con `backend/Dockerfile`, `frontend/Dockerfile`, `docker-compose.yml` y
   `.github/workflows/ci-cd.yml` abiertos en pestañas.
3. GitHub: página del repositorio (Code, branches, historial de commits) y la pestaña **Actions** con
   la última corrida exitosa del pipeline abierta.
4. AWS Consola: Amazon ECR (repos con las imágenes y sus tags), ECS (cluster, servicios, tareas),
   EC2 → Load Balancers (target groups en estado "healthy"), CloudWatch (logs y dashboard).
5. El navegador apuntando a `http://<ALB_DNS>` (la app funcionando en la nube).

---

## 0. Apertura (30-45 s)

> "Hola, somos [nombres]. Esta es la defensa de nuestro proyecto de la EFT de Introducción a
> Herramientas DevOps: un sistema de gestión de tareas con frontend en React, backend en Node/Express
> y base de datos PostgreSQL, con todo el ciclo de integración y despliegue automatizado con GitHub
> Actions hacia AWS."

## 1. Repositorio (1 min) — checklist: URL, ramas, commits

- Mostrar la URL del repositorio (pantalla completa, que se lea).
- Abrir el historial de commits: señalar que están agrupados por etapa lógica (scaffold de la app,
  contenerización, pipeline CI/CD, infraestructura AWS, documentación) con mensajes descriptivos.
- Mencionar brevemente la estructura de carpetas (`backend/`, `frontend/`, `infra/`, `.github/workflows/`).

## 2. Contenedores (2.5-3 min) — checklist: Dockerfile, docker-compose

- Abrir `backend/Dockerfile`: explicar las dos etapas (`deps` instala dependencias, `runtime` copia
  solo lo necesario), la imagen base `node:20-alpine` (minimalista) y el usuario no-root.
- Abrir `frontend/Dockerfile`: explicar que compila con Node y sirve con `nginx:alpine`, y el
  `build-arg VITE_API_URL` que fija en tiempo de build a qué backend apunta el frontend.
- Mostrar `docker-compose.yml`: la red interna, el healthcheck de la base de datos y la dependencia
  `condition: service_healthy` antes de levantar el backend.
- **Demo en vivo**: en la terminal, `docker compose up --build` (o mostrar que ya está corriendo) y
  abrir `http://localhost:5173` en el navegador — agregar una tarea nueva para mostrar que el CRUD
  funciona end-to-end contra la base de datos local.

## 3. Pipeline de CI/CD (3-3.5 min) — checklist: workflow, secretos, ECR, logs

- Abrir `.github/workflows/ci-cd.yml` y recorrer los 3 jobs en voz alta:
  - `build-and-test`: instala dependencias, corre las pruebas unitarias del backend, compila el
    frontend, construye ambas imágenes y las escanea con Trivy.
  - `push`: se autentica en ECR con credenciales guardadas como *GitHub Secret* (mostrar la sección
    Settings → Secrets and variables, **sin revelar los valores**) y publica las imágenes con dos tags
    (SHA del commit y `latest`).
  - `deploy`: actualiza las task definitions de ECS y espera a que el despliegue quede estable.
- Cambiar a la pestaña **Actions** de GitHub: mostrar una corrida completa en verde, entrar a los logs
  de al menos un job (por ejemplo `push`) para que se vea la publicación real en ECR.
- Cambiar a la consola de AWS → ECR: mostrar los repositorios `eft-devops-frontend` y
  `eft-devops-backend` con las imágenes y sus tags (destacar el tag por SHA que coincide con el commit
  recién mostrado en GitHub).

## 4. Despliegue y orquestación en AWS (3.5-4 min) — checklist: endpoints activos, clúster, arquitectura

- Abrir el navegador en `http://<ALB_DNS>` y mostrar la app funcionando **en la nube** (agregar una
  tarea para demostrar que también escribe en RDS).
- Consola AWS → ECS: mostrar el cluster `eft-devops-cluster`, los 2 servicios corriendo (frontend y
  backend) y sus tareas activas.
- Mostrar la configuración de auto scaling del servicio backend (Application Auto Scaling, target
  60% CPU, 1 a 3 tareas) y explicar en qué se traduce: si sube la carga, ECS agrega tareas solo.
- EC2 → Load Balancers → Target Groups: mostrar los targets en estado "healthy".
- Explicar con el diagrama de arquitectura (`docs/architecture.png`) cómo interactúan los servicios:
  ALB enruta por path (`/` al frontend, `/api/*` al backend), el backend habla con RDS por el puerto
  5432 solo desde su Security Group, y los Secrets/credenciales viven en Secrets Manager, no en el código.
- CloudWatch: mostrar el dashboard con métricas (CPU/memoria de los servicios, requests del ALB) y los
  grupos de logs `/ecs/eft-devops-backend` y `/ecs/eft-devops-frontend`.

## 5. Cierre (30 s)

> "Con esto automatizamos todo el ciclo: cada push a main prueba, construye, publica y despliega solo,
> sobre una infraestructura con buenas prácticas de seguridad y con capacidad de escalar sin
> intervención manual. Quedamos atentos a las preguntas."

---

## Preguntas frecuentes de defensa técnica (preparar respuesta propia, no leer)

- **¿Por qué RDS y no un contenedor de Postgres en producción?** Persistencia fuera del ciclo de vida
  de las tareas, backups automáticos y parches gestionados por AWS; el enunciado solo exige contenedor
  para BD en el entorno *local*.
- **¿Por qué un solo ALB con enrutamiento por path y no dos Load Balancers?** Da un único origen (evita
  problemas de CORS) y una URL estable, con menor costo que mantener dos ALBs.
- **¿Cómo se gestionan los secretos?** GitHub Secrets para las credenciales de despliegue (AWS), AWS
  Secrets Manager para las credenciales de la base de datos; ninguna vive en el repositorio ni en las
  imágenes.
- **¿Qué pasa si una tarea de ECS falla?** El healthcheck del contenedor y el target group del ALB la
  detectan como "unhealthy" y ECS la reemplaza automáticamente (mínimo privilegio + auto-recuperación).
- **¿Por qué Fargate y no EC2?** No hay servidores que parchear/escalar manualmente; se paga por tarea
  en ejecución y el auto scaling ajusta la cantidad de tareas según CPU.
- **¿Qué se haría distinto en un entorno real de producción?** HTTPS con certificado ACM en el ALB,
  autenticación del pipeline por OIDC en vez de access keys de larga duración, y pruebas de integración
  automatizadas antes del deploy.
- **¿Cómo se asegura la trazabilidad entre un commit y lo desplegado?** El tag de imagen en ECR es el
  SHA del commit; el job de deploy usa ese tag exacto, no "latest".
