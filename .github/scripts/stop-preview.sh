#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
CACHE_DIR="/tmp/.buildx-cache"

echo "[INFO] Removendo preview para PR #${PR_NUMBER}"

# Se o container do app existir mas não estiver rodando, mostrar logs antes de remover
if docker ps -a --format '{{.Names}} {{.Status}}' | grep -q "${APP_NAME}"; then
  STATUS=$(docker inspect -f '{{.State.Status}}' ${APP_NAME} || echo "desconhecido")
  if [ "$STATUS" != "running" ]; then
    echo "[WARN] Container ${APP_NAME} não está rodando (status: $STATUS). Exibindo últimos logs:"
    docker logs --tail=100 ${APP_NAME} || true
  fi
fi

# Parar e remover container da aplicação
docker rm -f ${APP_NAME} || true

# Parar e remover container do Ngrok
docker rm -f ${NGROK_NAME} || true

# Remover imagem associada ao PR
docker rmi -f ${APP_NAME}:latest || true

# Limpar camadas órfãs do buildx
if [ -d "${CACHE_DIR}" ]; then
  echo "[INFO] Limpando camadas órfãs do buildx..."
  docker builder prune -f || true
fi
