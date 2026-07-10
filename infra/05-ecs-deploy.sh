#!/usr/bin/env bash
# Crea el cluster ECS Fargate (con Container Insights para metricas), registra
# las task definitions renderizadas y crea los servicios conectados al ALB.
# Requiere haber corrido antes: 01-ecr.sh, 02-iam.sh, 03-network-alb-rds.sh,
# 04-render-taskdefs.sh, y haber publicado al menos una imagen en cada
# repositorio ECR (la primera vez puede hacerse a mano con docker push, o
# disparando el workflow de GitHub Actions con workflow_dispatch).
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.env

echo "==> Cluster ECS (${PROJECT}-cluster) con Container Insights"
aws ecs create-cluster \
  --cluster-name "${PROJECT}-cluster" \
  --settings name=containerInsights,value=enabled \
  --region "${AWS_REGION}" || echo "  (ya existe, se omite)"

echo "==> Registrando task definitions"
BACKEND_TD_ARN=$(aws ecs register-task-definition \
  --cli-input-json file://ecs/task-def-backend.json \
  --region "${AWS_REGION}" --query 'taskDefinition.taskDefinitionArn' --output text)
FRONTEND_TD_ARN=$(aws ecs register-task-definition \
  --cli-input-json file://ecs/task-def-frontend.json \
  --region "${AWS_REGION}" --query 'taskDefinition.taskDefinitionArn' --output text)
echo "BACKEND_TD_ARN=${BACKEND_TD_ARN}"
echo "FRONTEND_TD_ARN=${FRONTEND_TD_ARN}"

echo "==> Servicio backend (desired-count=1, awsvpc con IP publica para ECR/CloudWatch)"
aws ecs create-service \
  --cluster "${PROJECT}-cluster" \
  --service-name "${PROJECT}-backend-svc" \
  --task-definition "${BACKEND_TD_ARN}" \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_ID_A},${SUBNET_ID_B}],securityGroups=[${BACKEND_SG_ID}],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=${BACKEND_TG_ARN},containerName=backend,containerPort=3000" \
  --health-check-grace-period-seconds 60 \
  --region "${AWS_REGION}" || echo "  (ya existe, usa 'aws ecs update-service' para actualizar)"

echo "==> Servicio frontend"
aws ecs create-service \
  --cluster "${PROJECT}-cluster" \
  --service-name "${PROJECT}-frontend-svc" \
  --task-definition "${FRONTEND_TD_ARN}" \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_ID_A},${SUBNET_ID_B}],securityGroups=[${FRONTEND_SG_ID}],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=${FRONTEND_TG_ARN},containerName=frontend,containerPort=80" \
  --health-check-grace-period-seconds 60 \
  --region "${AWS_REGION}" || echo "  (ya existe, usa 'aws ecs update-service' para actualizar)"

cat <<EOF

==> Despliegue inicial lanzado. Verifica el estado con:
aws ecs describe-services --cluster ${PROJECT}-cluster --services ${PROJECT}-backend-svc ${PROJECT}-frontend-svc --region ${AWS_REGION}

App publica (dale 1-2 minutos a que los health checks del ALB pasen a "healthy"):
http://${ALB_DNS}
EOF
