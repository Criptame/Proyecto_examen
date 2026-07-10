#!/usr/bin/env bash
# Habilita auto scaling (target tracking por CPU) en el servicio backend,
# para demostrar el beneficio de ECS frente a un despliegue manual en EC2:
# el numero de tareas sube/baja solo segun la carga real.
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.env

RESOURCE_ID="service/${PROJECT}-cluster/${PROJECT}-backend-svc"

aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id "${RESOURCE_ID}" \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 3 \
  --region "${AWS_REGION}"

aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id "${RESOURCE_ID}" \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name "${PROJECT}-backend-cpu-target-tracking" \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 60.0,
    "PredefinedMetricSpecification": { "PredefinedMetricType": "ECSServiceAverageCPUUtilization" },
    "ScaleInCooldown": 60,
    "ScaleOutCooldown": 60
  }' \
  --region "${AWS_REGION}"

echo "==> Auto scaling configurado: backend entre 1 y 3 tareas, target 60% CPU."
