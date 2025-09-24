#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"

echo "[INFO] Removendo preview para PR #${PR_NUMBER}..."

# Se o container da aplicação existir mas não estiver rodando, mostrar últimos logs antes de remover
if docker ps -a --format '{{.Names}}' | grep -q "^${APP_NAME}$"; then
  STATUS=$(docker inspect -f '{{.State.Status}}' ${APP_NAME} || echo "desconhecido")
  if [ "$STATUS" != "running" ]; then
    echo "[WARN] Container ${APP_NAME} não está rodando (status: $STATUS). Exibindo últimos logs:"
    docker logs --tail=100 ${APP_NAME} || true
  fi
  echo "[INFO] Removendo container da aplicação ${APP_NAME}..."
  docker rm -f ${APP_NAME} >/dev/null 2>&1 || true
else
  echo "[INFO] Nenhum container da aplicação encontrado para ${APP_NAME}."
fi

# Remover imagem associada ao PR (se existir)
if docker images -q ${APP_NAME}:latest >/dev/null 2>&1; then
  echo "[INFO] Removendo imagem Docker ${APP_NAME}:latest..."
  docker rmi -f ${APP_NAME}:latest >/dev/null 2>&1 || true
fi

# Remover container do Ngrok (se existir)
if docker ps -a --format '{{.Names}}' | grep -q "^${NGROK_NAME}$"; then
  echo "[INFO] Removendo container do Ngrok ${NGROK_NAME}..."
  docker rm -f ${NGROK_NAME} >/dev/null 2>&1 || true
else
  echo "[INFO] Nenhum container do Ngrok encontrado para ${NGROK_NAME}."
fi

echo "[INFO] Preview para PR #${PR_NUMBER} removido com sucesso."
