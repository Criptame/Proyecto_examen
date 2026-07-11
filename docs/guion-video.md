# Guion de grabación — Presentación y defensa (EFT ISY1101)

Guion definitivo, sincronizado con `docs/presentacion.pptx` (10 diapositivas) y con el estado real
del proyecto ya desplegado. Duración objetivo: **10 a 13 minutos**. Cada bloque dice: qué diapositiva
mostrar, qué decir (idea, no para leer palabra por palabra — que suene natural), y a qué pantalla
cambiar y qué señalar ahí.

**Datos reales de tu proyecto** (para no tener que buscarlos en vivo):
- Repo: `https://github.com/Criptame/Proyecto_examen`
- App en producción: `http://eft-devops-alb-1572070739.us-east-1.elb.amazonaws.com`
- Cluster ECS: `eft-devops-cluster` · Servicios: `eft-devops-backend-svc`, `eft-devops-frontend-svc`
- RDS: `eft-devops-db` (PostgreSQL)

## Antes de grabar: dejar todo abierto en pestañas (evita tiempos muertos)

1. **`docs/presentacion.pptx`** abierto en PowerPoint, en modo presentación, en un monitor/ventana.
2. **Navegador** con estas pestañas ya cargadas:
   - `http://eft-devops-alb-1572070739.us-east-1.elb.amazonaws.com` (la app en producción)
   - `https://github.com/Criptame/Proyecto_examen` (repo)
   - `https://github.com/Criptame/Proyecto_examen/blob/main/.github/workflows/ci-cd.yml`
   - Consola AWS: ECS (cluster `eft-devops-cluster`), RDS (`eft-devops-db`), EC2 → Security Groups
3. **Editor** (VS Code) con `backend/Dockerfile`, `frontend/Dockerfile`, `docker-compose.yml` abiertos.
4. **Terminal** con `docker compose up --build` ya corrido una vez (para no esperar el build en vivo).

> ⚠️ El pipeline de GitHub Actions tiene ahora mismo una corrida en rojo (falla al resolver la acción
> `aquasecurity/trivy-action@0.24.0`, un tag que no existe). Si no lo arreglas antes de grabar, **no
> muestres una corrida en vivo fallando** — muestra el archivo `.github/workflows/ci-cd.yml` y explica
> los 3 jobs conceptualmente (ver bloque 5). Si prefieres arreglarlo antes de grabar, es cambiar esa
> versión por una que exista (por ejemplo `@0.24.1` o `@master`) en el workflow.

---

## Bloque 0 — Diapositiva 1 (Portada) · 20-30 s

*Dejas la diapositiva de portada en pantalla mientras hablas.*

> "Hola, soy Guillermo Santander. Esta es la defensa de mi proyecto de la Evaluación Final Transversal
> de Introducción a Herramientas DevOps: automaticé el ciclo completo de integración y entrega continua
> de una plataforma web de tres capas, desplegada en AWS."

## Bloque 1 — Diapositiva 2 (El proyecto) · 45-60 s

- Lee en voz alta las 4 ideas clave de la slide (contenedores, pipeline, infraestructura real, seguridad).
- Señala el diagrama de 3 capas de la derecha: "Frontend en React, Backend en Node/Express, base de
  datos PostgreSQL — se comunican por HTTP y TCP dentro de una red interna."

## Bloque 2 — Diapositiva 3 (Arquitectura) · 1-1.5 min

- Explica el diagrama completo: entorno local (docker-compose) a la izquierda, GitHub en el medio,
  AWS Cloud a la derecha.
- Menciona las 3 cajas de abajo: un solo ALB con enrutamiento por path (evita CORS), RDS sin IP pública.

## Bloque 3 — Diapositiva 4 (Contenedores) + demo local · 2-2.5 min

- Repasa la slide: build multietapa, imágenes alpine, usuario no-root, healthchecks.
- **Cambia a VS Code**: muestra `backend/Dockerfile` (señala las etapas `deps` y `runtime`), luego
  `frontend/Dockerfile` (build con Node, runtime con nginx), luego `docker-compose.yml` (red interna,
  `condition: service_healthy`).
- **Demo en vivo**: cambia a la terminal, muestra que el stack está corriendo (`docker compose ps`),
  abre `http://localhost:5173` en el navegador, agrega una tarea nueva — "esto confirma que el CRUD
  funciona contra la base de datos local".

## Bloque 4 — Diapositiva 5 (Pipeline CI/CD) · 2-2.5 min

- Repasa los 3 pasos de la slide (Build & Test, Push a ECR, Deploy a ECS).
- **Cambia al navegador**, pestaña del archivo `.github/workflows/ci-cd.yml` en GitHub: desplázate
  por los 3 jobs mientras explicas qué hace cada uno (usa las mismas palabras de la slide).
- Señala la sección de secretos: "las credenciales de AWS viven en GitHub Secrets, nunca en el código".
- *(Si ya arreglaste el bug de Trivy antes de grabar)*: cambia a la pestaña **Actions** y muestra una
  corrida en verde, entra a los logs del job `push` para mostrar la publicación real en ECR.

## Bloque 5 — Diapositiva 6 (Infraestructura AWS) · 2-2.5 min

- Repasa la lista de la slide (VPC sin NAT, ALB, ECS Fargate, RDS sin IP pública, auto scaling).
- **Cambia a la consola de AWS**:
  - ECS → cluster `eft-devops-cluster` → muestra los 2 servicios corriendo y sus tareas activas.
  - RDS → `eft-devops-db` → muestra el estado "Disponible".
  - EC2 → Security Groups → `eft-devops-rds-sg` → muestra que solo acepta tráfico desde el Security
    Group del backend (sin abrir nada a Internet).

## Bloque 6 — Diapositiva 7 (Seguridad) · 1-1.5 min

- Repasa las 6 tarjetas (mínimo privilegio, secretos gestionados, red segmentada, imágenes
  minimalistas, tags inmutables, TLS a la base de datos) — no hace falta volver a cambiar de pantalla,
  esta slide se sostiene sola si ya mostraste el Security Group en el bloque anterior.

## Bloque 7 — Diapositiva 8 (Evidencia) + demo en la nube · 1.5-2 min

- **Cambia al navegador**, pestaña de la app en producción: `http://eft-devops-alb-1572070739.us-east-1.elb.amazonaws.com`.
  Agrega una tarea nueva ahí — "esto ya no es local, está escribiendo en RDS a través del backend en Fargate".
- Cambia a la pestaña del repositorio en GitHub, muestra que es público y el historial de commits.

## Bloque 8 — Diapositiva 9 (Desafíos reales) · 1.5-2 min

*Esta es la slide más fuerte para la nota — cuenta la historia con confianza, no como un error sino
como evidencia de que probaste en un entorno real:*

> "Durante el despliegue real encontré dos problemas que no aparecían en local. El primero: el backend
> fallaba en bucle porque RDS exige conexión cifrada por defecto y mi driver no la tenía activada — lo
> vi en los logs de CloudWatch, y lo arreglé activando SSL condicionalmente, solo quedaba encendido en
> AWS, no en local. El segundo: el frontend decía 'sin conexión' porque el Load Balancer solo enruta
> `/api/*` al backend, y el chequeo de salud pegaba directo a `/health`, que caía en el nginx del
> frontend en vez del backend. Lo corregí exponiendo también `/api/health` en el backend y apuntando
> el frontend ahí. Ambos se corrigieron y redesplegaron sin bajar el servicio."

## Bloque 9 — Diapositiva 10 (Conclusiones) · 30-40 s

> "En resumen: automaticé todo el camino de un commit a producción, sin pasos manuales, sobre una
> arquitectura pensada en costo y seguridad, y la validé funcionando de verdad en una cuenta real de
> AWS. Gracias — quedo atento a las preguntas."

---

## Preguntas frecuentes de defensa técnica (prepara tu propia respuesta, no leas esto en voz alta)

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
- **¿Cómo encontraste los dos bugs de producción?** Revisando los logs de CloudWatch del backend
  (`/ecs/eft-devops-backend`), que mostraban el error exacto de Postgres y, en el segundo caso,
  probando el endpoint manualmente con curl a través del ALB.
- **¿Qué se haría distinto en un entorno real de producción?** HTTPS con certificado ACM en el ALB,
  autenticación del pipeline por OIDC en vez de access keys de larga duración, y pruebas de integración
  automatizadas antes del deploy.
- **¿Cómo se asegura la trazabilidad entre un commit y lo desplegado?** El tag de imagen en ECR es el
  SHA del commit (los repositorios tienen tags inmutables, no se usa "latest"); el job de deploy usa
  siempre ese tag exacto.
