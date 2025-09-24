#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project"
CONTAINER_NAME="${APP_NAME}-pr${PR_NUMBER}"
HOST_PORT=$((8000 + PR_NUMBER))
CACHE_DIR="/tmp/.buildx-cache"

echo "[INFO] Removendo preview para PR #${PR_NUMBER} (porta ${HOST_PORT})..."

# Se container existir, mostrar logs se falhou antes de remover
if docker ps -a --format '{{.Names}} {{.Status}}' | grep -q "${CONTAINER_NAME}"; then
  STATUS=$(docker inspect -f '{{.State.Status}}' ${CONTAINER_NAME} || echo "desconhecido")
  if [ "$STATUS" != "running" ]; then
    echo "[WARN] Container ${CONTAINER_NAME} não está rodando (status: $STATUS). Últimos logs:"
    docker logs --tail=100 ${CONTAINER_NAME} || true
  fi
fi

# Remover container
docker rm -f ${CONTAINER_NAME} || true

# Remover imagem associada
docker rmi -f ${CONTAINER_NAME}:latest || true

# Encerrar ngrok do PR específico
pkill -f "ngrok http ${HOST_PORT}" || true

# Limpar cache do buildx
if [ -d "${CACHE_DIR}" ]; then
  echo "[INFO] Limpando camadas órfãs do buildx..."
  docker builder prune -f || true
fi

echo "[INFO] Preview do PR #${PR_NUMBER} encerrado com sucesso."
