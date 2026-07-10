#!/usr/bin/env bash
# Renderiza las task definitions finales (sustituye placeholders por los IDs
# reales de la cuenta/infra) y las deja en infra/ecs/task-def-*.json. Esos
# archivos SI se commitean al repo: no contienen secretos, solo ARNs/DNS/
# nombres, y son la base que usa el pipeline de CI/CD para desplegar (solo
# reemplaza el tag de imagen en cada corrida).
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.env

for var in AWS_REGION AWS_ACCOUNT_ID PROJECT EXEC_ROLE_ARN TASK_ROLE_ARN RDS_ENDPOINT DB_NAME DB_SECRET_ARN; do
  if [ -z "${!var:-}" ]; then
    echo "Falta ${var} en infra/00-config.env (correr 02-iam.sh y 03-network-alb-rds.sh primero)"
    exit 1
  fi
done

export AWS_REGION AWS_ACCOUNT_ID PROJECT EXEC_ROLE_ARN TASK_ROLE_ARN RDS_ENDPOINT DB_NAME DB_SECRET_ARN

envsubst < ecs/task-def-backend.template.json > ecs/task-def-backend.json
envsubst < ecs/task-def-frontend.template.json > ecs/task-def-frontend.json

echo "==> Generados:"
echo "  infra/ecs/task-def-backend.json"
echo "  infra/ecs/task-def-frontend.json"
echo "Revisa el diff y commitealos: git add infra/ecs/task-def-*.json"
