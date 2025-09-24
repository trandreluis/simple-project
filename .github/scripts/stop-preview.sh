#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"

echo "[INFO] Removendo preview para PR #${PR_NUMBER}"

# Se o container existir mas estiver em estado de falha, mostrar logs antes de remover
if docker ps -a --format '{{.Names}} {{.Status}}' | grep -q "${APP_NAME}"; then
  STATUS=$(docker inspect -f '{{.State.Status}}' ${APP_NAME} || echo "desconhecido")
  if [ "$STATUS" != "running" ]; then
    echo "[WARN] Container ${APP_NAME} não está rodando (status: $STATUS). Exibindo últimos logs:"
    docker logs --tail=100 ${APP_NAME} || true
  fi
fi

# Parar e remover container da aplicação
docker rm -f ${APP_NAME} || true

# Remover imagem associada ao PR
docker rmi -f ${APP_NAME}:latest || true

# Parar e remover container do ngrok
docker rm -f ${NGROK_NAME} || true
