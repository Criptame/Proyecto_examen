#!/usr/bin/env bash
# Crea los roles de ECS (ejecucion y de tarea) y el usuario IAM dedicado que
# usara GitHub Actions para desplegar, con permisos acotados (principio de
# minimo privilegio: solo ECR de este proyecto + ECS + PassRole de los 2 roles).
#
# Compatible con AWS Academy Learner Lab: si detecta que no se pueden crear
# roles/usuarios IAM (respuesta AccessDenied, tipico de Academy), usa el rol
# ya existente "LabRole" para ambos roles de ECS y omite la creacion del
# usuario dedicado, indicando que hay que usar las credenciales temporales
# de la propia sesion del Lab (ver mensaje final).
export MSYS_NO_PATHCONV=1
set -uo pipefail
cd "$(dirname "$0")"
source ./00-config.env

ACADEMY_MODE=false

echo "==> Rol de ejecucion de tareas ECS (${PROJECT}-ecsTaskExecutionRole)"
CREATE_OUT=$(aws iam create-role \
  --role-name "${PROJECT}-ecsTaskExecutionRole" \
  --assume-role-policy-document file://iam/ecs-tasks-trust-policy.json 2>&1)
CREATE_STATUS=$?

if [ $CREATE_STATUS -ne 0 ] && echo "${CREATE_OUT}" | grep -qi "AccessDenied"; then
  ACADEMY_MODE=true
  echo "  Permiso denegado creando roles IAM -> se asume AWS Academy Learner Lab."
elif [ $CREATE_STATUS -ne 0 ] && echo "${CREATE_OUT}" | grep -qi "EntityAlreadyExists"; then
  echo "  (ya existe, se omite)"
elif [ $CREATE_STATUS -ne 0 ]; then
  echo "${CREATE_OUT}"
fi

if [ "${ACADEMY_MODE}" = true ]; then
  echo "==> Usando el rol existente 'LabRole' de AWS Academy para ejecucion y tarea"
  EXEC_ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)
  TASK_ROLE_ARN="${EXEC_ROLE_ARN}"
  echo "  (LabRole ya trae permisos amplios; normalmente no hace falta agregarle nada mas)"
else
  aws iam attach-role-policy \
    --role-name "${PROJECT}-ecsTaskExecutionRole" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

  echo "==> Rol de tarea (${PROJECT}-ecsTaskRole) - sin permisos extra por ahora"
  aws iam create-role \
    --role-name "${PROJECT}-ecsTaskRole" \
    --assume-role-policy-document file://iam/ecs-tasks-trust-policy.json \
    || echo "  (ya existe, se omite)"

  EXEC_ROLE_ARN=$(aws iam get-role --role-name "${PROJECT}-ecsTaskExecutionRole" --query 'Role.Arn' --output text)
  TASK_ROLE_ARN=$(aws iam get-role --role-name "${PROJECT}-ecsTaskRole" --query 'Role.Arn' --output text)

  # Requiere que DB_SECRET_ARN ya este seteado (ver 03-network-alb-rds.sh)
  if [ -n "${DB_SECRET_ARN:-}" ]; then
    echo "==> Dando permiso al rol de ejecucion para leer el secreto de la BD"
    export DB_SECRET_ARN
    envsubst < iam/execution-role-secrets-policy.template.json > /tmp/exec-role-secrets-policy.json
    aws iam put-role-policy \
      --role-name "${PROJECT}-ecsTaskExecutionRole" \
      --policy-name "${PROJECT}-read-db-secret" \
      --policy-document file:///tmp/exec-role-secrets-policy.json
  else
    echo "AVISO: DB_SECRET_ARN vacio; correr 03-network-alb-rds.sh primero y volver a ejecutar este paso."
  fi
fi

echo "EXEC_ROLE_ARN=${EXEC_ROLE_ARN}"
echo "TASK_ROLE_ARN=${TASK_ROLE_ARN}"

if [ "${ACADEMY_MODE}" = false ]; then
  echo "==> Usuario IAM dedicado para GitHub Actions (${PROJECT}-github-actions)"
  aws iam create-user --user-name "${PROJECT}-github-actions" || echo "  (ya existe, se omite)"

  export AWS_REGION AWS_ACCOUNT_ID PROJECT EXEC_ROLE_ARN TASK_ROLE_ARN
  envsubst < iam/github-actions-deploy-policy.template.json > /tmp/github-actions-deploy-policy.json
  aws iam put-user-policy \
    --user-name "${PROJECT}-github-actions" \
    --policy-name "${PROJECT}-deploy-policy" \
    --policy-document file:///tmp/github-actions-deploy-policy.json
fi

cat <<EOF

==> Roles listos. Guarda estos valores en infra/00-config.env:
EXEC_ROLE_ARN=${EXEC_ROLE_ARN}
TASK_ROLE_ARN=${TASK_ROLE_ARN}

EOF

if [ "${ACADEMY_MODE}" = true ]; then
cat <<EOF
==> Modo AWS Academy: no se crea un usuario IAM dedicado (esta cuenta no
    permite crear usuarios/roles IAM). Para GitHub Actions, usa las
    credenciales TEMPORALES de tu propia sesion del Learner Lab:
    AWS Details -> AWS CLI -> copia access_key_id, secret_access_key y
    session_token, y pegalos TU MISMO (nunca en este chat) como GitHub
    Secrets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN.

    OJO: esas credenciales expiran junto con la sesion del Lab (unas 4
    horas). Antes de grabar el video o de volver a correr el pipeline en
    una sesion nueva, actualiza esos 3 secrets con los valores vigentes.
EOF
else
cat <<EOF
==> Para generar las credenciales de GitHub Actions (hazlo TU en tu propia
    terminal, no lo pegues nunca en un chat/IA), ejecuta:
    aws iam create-access-key --user-name ${PROJECT}-github-actions
    Copia AccessKeyId y SecretAccessKey directo a GitHub Secrets
    (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY) y no los guardes en ningun
    archivo del repo.
EOF
fi
