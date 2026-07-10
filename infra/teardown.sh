#!/usr/bin/env bash
# Elimina TODO lo creado por los scripts 01-07, en orden inverso, para dejar
# de pagar despues de grabar el video y rendir el examen. Pide confirmacion
# antes de borrar nada. No falla si algo ya no existe (idempotente).
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.env

echo "Esto va a BORRAR de forma permanente los recursos de AWS del proyecto '${PROJECT}'"
echo "(ECS services/cluster, ALB, target groups, RDS, secreto, roles/usuario IAM, ECR, security groups)."
read -r -p "Escribe 'borrar' para confirmar: " CONFIRM
if [ "${CONFIRM}" != "borrar" ]; then
  echo "Cancelado."
  exit 1
fi

echo "==> Auto scaling"
aws application-autoscaling deregister-scalable-target \
  --service-namespace ecs --resource-id "service/${PROJECT}-cluster/${PROJECT}-backend-svc" \
  --scalable-dimension ecs:service:DesiredCount --region "${AWS_REGION}" 2>/dev/null || true

echo "==> Servicios y cluster ECS"
for svc in backend frontend; do
  aws ecs update-service --cluster "${PROJECT}-cluster" --service "${PROJECT}-${svc}-svc" --desired-count 0 --region "${AWS_REGION}" 2>/dev/null || true
  aws ecs delete-service --cluster "${PROJECT}-cluster" --service "${PROJECT}-${svc}-svc" --force --region "${AWS_REGION}" 2>/dev/null || true
done
aws ecs delete-cluster --cluster "${PROJECT}-cluster" --region "${AWS_REGION}" 2>/dev/null || true

echo "==> Listener, reglas y target groups del ALB"
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "${ALB_ARN}" --region "${AWS_REGION}" --query 'Listeners[0].ListenerArn' --output text 2>/dev/null || true)
if [ -n "${LISTENER_ARN}" ] && [ "${LISTENER_ARN}" != "None" ]; then
  aws elbv2 delete-listener --listener-arn "${LISTENER_ARN}" --region "${AWS_REGION}" 2>/dev/null || true
fi
aws elbv2 delete-load-balancer --load-balancer-arn "${ALB_ARN}" --region "${AWS_REGION}" 2>/dev/null || true
echo "  esperando a que el ALB termine de eliminarse antes de borrar los target groups..."
sleep 20
aws elbv2 delete-target-group --target-group-arn "${FRONTEND_TG_ARN}" --region "${AWS_REGION}" 2>/dev/null || true
aws elbv2 delete-target-group --target-group-arn "${BACKEND_TG_ARN}" --region "${AWS_REGION}" 2>/dev/null || true

echo "==> RDS"
aws rds delete-db-instance --db-instance-identifier "${PROJECT}-db" --skip-final-snapshot --region "${AWS_REGION}" 2>/dev/null || true
aws rds wait db-instance-deleted --db-instance-identifier "${PROJECT}-db" --region "${AWS_REGION}" 2>/dev/null || true
aws rds delete-db-subnet-group --db-subnet-group-name "${PROJECT}-db-subnet-group" --region "${AWS_REGION}" 2>/dev/null || true
aws secretsmanager delete-secret --secret-id "${PROJECT}/db-credentials" --force-delete-without-recovery --region "${AWS_REGION}" 2>/dev/null || true

echo "==> Security Groups"
for sg in "${FRONTEND_SG_ID}" "${BACKEND_SG_ID}" "${RDS_SG_ID}" "${ALB_SG_ID}"; do
  aws ec2 delete-security-group --group-id "${sg}" --region "${AWS_REGION}" 2>/dev/null || true
done

echo "==> IAM (roles y usuario)"
aws iam delete-role-policy --role-name "${PROJECT}-ecsTaskExecutionRole" --policy-name "${PROJECT}-read-db-secret" 2>/dev/null || true
aws iam detach-role-policy --role-name "${PROJECT}-ecsTaskExecutionRole" --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || true
aws iam delete-role --role-name "${PROJECT}-ecsTaskExecutionRole" 2>/dev/null || true
aws iam delete-role --role-name "${PROJECT}-ecsTaskRole" 2>/dev/null || true
aws iam delete-user-policy --user-name "${PROJECT}-github-actions" --policy-name "${PROJECT}-deploy-policy" 2>/dev/null || true
for key in $(aws iam list-access-keys --user-name "${PROJECT}-github-actions" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null || true); do
  aws iam delete-access-key --user-name "${PROJECT}-github-actions" --access-key-id "${key}" 2>/dev/null || true
done
aws iam delete-user --user-name "${PROJECT}-github-actions" 2>/dev/null || true

echo "==> Repositorios ECR (incluye las imagenes)"
aws ecr delete-repository --repository-name "${PROJECT}-frontend" --force --region "${AWS_REGION}" 2>/dev/null || true
aws ecr delete-repository --repository-name "${PROJECT}-backend" --force --region "${AWS_REGION}" 2>/dev/null || true

echo "==> CloudWatch dashboard y log groups"
aws cloudwatch delete-dashboards --dashboard-names "${PROJECT}-dashboard" --region "${AWS_REGION}" 2>/dev/null || true
aws logs delete-log-group --log-group-name "/ecs/${PROJECT}-backend" --region "${AWS_REGION}" 2>/dev/null || true
aws logs delete-log-group --log-group-name "/ecs/${PROJECT}-frontend" --region "${AWS_REGION}" 2>/dev/null || true

echo "==> Listo. Revisa la consola de AWS (Billing / cada servicio) para confirmar que no quedo nada activo."
