#!/usr/bin/env bash
# Red (Security Groups), Application Load Balancer con enrutamiento por path
# (/api/* -> backend, resto -> frontend) y base de datos RDS PostgreSQL.
# Usa la VPC por defecto para evitar costos/complejidad de NAT Gateway: las
# tareas Fargate reciben IP publica solo para salir a ECR/CloudWatch/Secrets
# Manager, y quedan protegidas por Security Groups restrictivos (no por estar
# en subred privada). RDS no tiene IP publica.
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.env

if [ -z "${VPC_ID}" ]; then
  VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text --region "${AWS_REGION}")
  echo "VPC_ID detectada: ${VPC_ID}"
fi

if [ -z "${SUBNET_ID_A}" ] || [ -z "${SUBNET_ID_B}" ]; then
  read -r SUBNET_ID_A SUBNET_ID_B <<< "$(aws ec2 describe-subnets \
    --filters Name=vpc-id,Values="${VPC_ID}" \
    --query 'Subnets[0:2].SubnetId' --output text --region "${AWS_REGION}")"
  echo "Subredes detectadas: ${SUBNET_ID_A} ${SUBNET_ID_B}"
fi

echo "==> Security Groups"
ALB_SG_ID=$(aws ec2 create-security-group --group-name "${PROJECT}-alb-sg" \
  --description "ALB publico ${PROJECT}" --vpc-id "${VPC_ID}" --region "${AWS_REGION}" \
  --query 'GroupId' --output text 2>/dev/null || \
  aws ec2 describe-security-groups --filters Name=group-name,Values="${PROJECT}-alb-sg" Name=vpc-id,Values="${VPC_ID}" \
  --query 'SecurityGroups[0].GroupId' --output text --region "${AWS_REGION}")

FRONTEND_SG_ID=$(aws ec2 create-security-group --group-name "${PROJECT}-frontend-sg" \
  --description "Servicio frontend ${PROJECT}" --vpc-id "${VPC_ID}" --region "${AWS_REGION}" \
  --query 'GroupId' --output text 2>/dev/null || \
  aws ec2 describe-security-groups --filters Name=group-name,Values="${PROJECT}-frontend-sg" Name=vpc-id,Values="${VPC_ID}" \
  --query 'SecurityGroups[0].GroupId' --output text --region "${AWS_REGION}")

BACKEND_SG_ID=$(aws ec2 create-security-group --group-name "${PROJECT}-backend-sg" \
  --description "Servicio backend ${PROJECT}" --vpc-id "${VPC_ID}" --region "${AWS_REGION}" \
  --query 'GroupId' --output text 2>/dev/null || \
  aws ec2 describe-security-groups --filters Name=group-name,Values="${PROJECT}-backend-sg" Name=vpc-id,Values="${VPC_ID}" \
  --query 'SecurityGroups[0].GroupId' --output text --region "${AWS_REGION}")

RDS_SG_ID=$(aws ec2 create-security-group --group-name "${PROJECT}-rds-sg" \
  --description "RDS PostgreSQL ${PROJECT}" --vpc-id "${VPC_ID}" --region "${AWS_REGION}" \
  --query 'GroupId' --output text 2>/dev/null || \
  aws ec2 describe-security-groups --filters Name=group-name,Values="${PROJECT}-rds-sg" Name=vpc-id,Values="${VPC_ID}" \
  --query 'SecurityGroups[0].GroupId' --output text --region "${AWS_REGION}")

# Reglas minimas (idempotentes: ignoran error si ya existen)
aws ec2 authorize-security-group-ingress --group-id "${ALB_SG_ID}" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "${AWS_REGION}" 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "${FRONTEND_SG_ID}" --protocol tcp --port 80 --source-group "${ALB_SG_ID}" --region "${AWS_REGION}" 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "${BACKEND_SG_ID}" --protocol tcp --port 3000 --source-group "${ALB_SG_ID}" --region "${AWS_REGION}" 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "${RDS_SG_ID}" --protocol tcp --port 5432 --source-group "${BACKEND_SG_ID}" --region "${AWS_REGION}" 2>/dev/null || true

echo "ALB_SG_ID=${ALB_SG_ID}"
echo "FRONTEND_SG_ID=${FRONTEND_SG_ID}"
echo "BACKEND_SG_ID=${BACKEND_SG_ID}"
echo "RDS_SG_ID=${RDS_SG_ID}"

echo "==> Application Load Balancer"
ALB_ARN=$(aws elbv2 create-load-balancer --name "${PROJECT}-alb" \
  --subnets "${SUBNET_ID_A}" "${SUBNET_ID_B}" --security-groups "${ALB_SG_ID}" \
  --type application --scheme internet-facing --region "${AWS_REGION}" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "${ALB_ARN}" --region "${AWS_REGION}" \
  --query 'LoadBalancers[0].DNSName' --output text)
echo "ALB_ARN=${ALB_ARN}"
echo "ALB_DNS=${ALB_DNS}"

echo "==> Target Groups (target-type=ip, requerido por Fargate awsvpc)"
FRONTEND_TG_ARN=$(aws elbv2 create-target-group --name "${PROJECT}-frontend-tg" \
  --protocol HTTP --port 80 --vpc-id "${VPC_ID}" --target-type ip \
  --health-check-path /health --region "${AWS_REGION}" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
BACKEND_TG_ARN=$(aws elbv2 create-target-group --name "${PROJECT}-backend-tg" \
  --protocol HTTP --port 3000 --vpc-id "${VPC_ID}" --target-type ip \
  --health-check-path /health --region "${AWS_REGION}" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
echo "FRONTEND_TG_ARN=${FRONTEND_TG_ARN}"
echo "BACKEND_TG_ARN=${BACKEND_TG_ARN}"

echo "==> Listener :80 (default -> frontend) + regla /api/* -> backend"
LISTENER_ARN=$(aws elbv2 create-listener --load-balancer-arn "${ALB_ARN}" \
  --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn="${FRONTEND_TG_ARN}" \
  --region "${AWS_REGION}" --query 'Listeners[0].ListenerArn' --output text)
aws elbv2 create-rule --listener-arn "${LISTENER_ARN}" --priority 10 \
  --conditions Field=path-pattern,Values='/api/*' \
  --actions Type=forward,TargetGroupArn="${BACKEND_TG_ARN}" \
  --region "${AWS_REGION}"

echo "==> Subnet group + instancia RDS PostgreSQL (db.t3.micro, single-AZ)"
aws rds create-db-subnet-group \
  --db-subnet-group-name "${PROJECT}-db-subnet-group" \
  --db-subnet-group-description "Subredes para RDS de ${PROJECT}" \
  --subnet-ids "${SUBNET_ID_A}" "${SUBNET_ID_B}" \
  --region "${AWS_REGION}" 2>/dev/null || echo "  (subnet group ya existe)"

aws rds create-db-instance \
  --db-instance-identifier "${PROJECT}-db" \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16 \
  --allocated-storage 20 \
  --db-name "${DB_NAME}" \
  --master-username "${DB_USERNAME}" \
  --master-user-password "${DB_PASSWORD}" \
  --vpc-security-group-ids "${RDS_SG_ID}" \
  --db-subnet-group-name "${PROJECT}-db-subnet-group" \
  --no-publicly-accessible \
  --no-multi-az \
  --backup-retention-period 1 \
  --region "${AWS_REGION}" \
  || echo "  (instancia ya existe)"

echo "==> Esperando a que RDS quede disponible (puede tardar varios minutos)..."
aws rds wait db-instance-available --db-instance-identifier "${PROJECT}-db" --region "${AWS_REGION}"
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "${PROJECT}-db" --region "${AWS_REGION}" \
  --query 'DBInstances[0].Endpoint.Address' --output text)
echo "RDS_ENDPOINT=${RDS_ENDPOINT}"

echo "==> Secreto en AWS Secrets Manager con las credenciales de la BD"
DB_SECRET_ARN=$(aws secretsmanager create-secret \
  --name "${PROJECT}/db-credentials" \
  --secret-string "{\"username\":\"${DB_USERNAME}\",\"password\":\"${DB_PASSWORD}\"}" \
  --region "${AWS_REGION}" --query 'ARN' --output text 2>/dev/null || \
  aws secretsmanager describe-secret --secret-id "${PROJECT}/db-credentials" --region "${AWS_REGION}" --query 'ARN' --output text)
echo "DB_SECRET_ARN=${DB_SECRET_ARN}"

cat <<EOF

==> Guarda estos valores en infra/00-config.env antes de continuar con 02-iam.sh y 04-render-taskdefs.sh:
VPC_ID=${VPC_ID}
SUBNET_ID_A=${SUBNET_ID_A}
SUBNET_ID_B=${SUBNET_ID_B}
ALB_SG_ID=${ALB_SG_ID}
FRONTEND_SG_ID=${FRONTEND_SG_ID}
BACKEND_SG_ID=${BACKEND_SG_ID}
RDS_SG_ID=${RDS_SG_ID}
ALB_ARN=${ALB_ARN}
ALB_DNS=${ALB_DNS}
FRONTEND_TG_ARN=${FRONTEND_TG_ARN}
BACKEND_TG_ARN=${BACKEND_TG_ARN}
RDS_ENDPOINT=${RDS_ENDPOINT}
DB_SECRET_ARN=${DB_SECRET_ARN}

URL publica de la app (guardala tambien, se usa como VITE_API_URL=http://\${ALB_DNS}):
http://${ALB_DNS}
EOF
