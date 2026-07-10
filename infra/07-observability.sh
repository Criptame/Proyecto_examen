#!/usr/bin/env bash
# Dashboard de CloudWatch con las metricas basicas pedidas por la pauta:
# CPU/memoria de los servicios ECS y latencia/requests del ALB.
# Los logs de aplicacion ya llegan a CloudWatch Logs via el driver "awslogs"
# configurado en las task definitions (grupos /ecs/${PROJECT}-backend y
# /ecs/${PROJECT}-frontend), y Container Insights ya quedo habilitado al
# crear el cluster en 05-ecs-deploy.sh.
export MSYS_NO_PATHCONV=1
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.env

ALB_NAME_SUFFIX=$(echo "${ALB_ARN}" | sed -E 's#.*loadbalancer/##')

BODY=$(cat <<EOF
{
  "widgets": [
    {
      "type": "metric", "x": 0, "y": 0, "width": 12, "height": 6,
      "properties": {
        "title": "ECS CPU/Memoria - backend",
        "metrics": [
          [ "AWS/ECS", "CPUUtilization", "ClusterName", "${PROJECT}-cluster", "ServiceName", "${PROJECT}-backend-svc" ],
          [ ".", "MemoryUtilization", ".", ".", ".", "." ]
        ],
        "period": 60, "stat": "Average", "region": "${AWS_REGION}"
      }
    },
    {
      "type": "metric", "x": 12, "y": 0, "width": 12, "height": 6,
      "properties": {
        "title": "ALB - Requests y latencia",
        "metrics": [
          [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${ALB_NAME_SUFFIX}" ],
          [ ".", "TargetResponseTime", ".", ".", { "yAxis": "right" } ]
        ],
        "period": 60, "stat": "Sum", "region": "${AWS_REGION}"
      }
    }
  ]
}
EOF
)

aws cloudwatch put-dashboard \
  --dashboard-name "${PROJECT}-dashboard" \
  --dashboard-body "${BODY}" \
  --region "${AWS_REGION}"

echo "==> Dashboard creado: https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:name=${PROJECT}-dashboard"
