#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
CACHE_DIR="/tmp/.buildx-cache"

echo "[INFO] Removendo preview para PR #${PR_NUMBER}"

# Parar container e remover
docker rm -f ${APP_NAME} || true

# Remover imagem associada ao PR
docker rmi -f ${APP_NAME}:latest || true

# Matar ngrok correspondente
pkill -f "${NGROK_NAME}" || true

# Limpar camadas órfãs do buildx
if [ -d "${CACHE_DIR}" ]; then
  echo "[INFO] Limpando camadas órfãs do buildx..."
  docker builder prune -f || true
fi
