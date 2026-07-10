#!/usr/bin/env bash
# Crea los repositorios ECR (frontend y backend) con escaneo de vulnerabilidades
# al hacer push y una lifecycle policy que conserva solo las ultimas 10 imagenes.
set -euo pipefail
source "$(dirname "$0")/00-config.env"

for svc in frontend backend; do
  repo="${PROJECT}-${svc}"
  echo "==> Creando repositorio ECR ${repo}"
  aws ecr create-repository \
    --repository-name "${repo}" \
    --region "${AWS_REGION}" \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability IMMUTABLE \
    || echo "  (ya existe, se omite)"

  aws ecr put-lifecycle-policy \
    --repository-name "${repo}" \
    --region "${AWS_REGION}" \
    --lifecycle-policy-text '{
      "rules": [{
        "rulePriority": 1,
        "description": "Conservar solo las ultimas 10 imagenes",
        "selection": { "tagStatus": "any", "countType": "imageCountMoreThan", "countNumber": 10 },
        "action": { "type": "expire" }
      }]
    }'
done

echo "==> Repositorios ECR listos:"
echo "  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-frontend"
echo "  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-backend"
