#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"

echo "[INFO] Removendo preview para PR #${PR_NUMBER}"

# Se o container da aplicação existir mas estiver em estado de falha, mostrar logs antes de remover
if docker ps -a --format '{{.Names}} {{.Status}}' | grep -q "${APP_NAME}"; then
  STATUS=$(docker inspect -f '{{.State.Status}}' ${APP_NAME} || echo "desconhecido")
  if [ "$STATUS" != "running" ]; then
    echo "[WARN] Container ${APP_NAME} não está rodando (status: $STATUS). Exibindo últimos logs:"
    docker logs --tail=100 ${APP_NAME} || true
  fi
fi

# Parar e remover container da aplicação
docker rm -f ${APP_NAME} >/dev/null 2>&1 || true

# Remover imagem associada ao PR (se existir)
docker rmi -f ${APP_NAME}:latest >/dev/null 2>&1 || true

# Parar e remover container do ngrok
docker rm -f ${NGROK_NAME} >/dev/null 2>&1 || true

# Extra: limpar eventuais containers órfãos do mesmo PR
docker ps -a --format '{{.Names}}' | grep -E "${APP_NAME}|${NGROK_NAME}" | xargs -r docker rm -f || true

# Extra: limpar eventuais imagens órfãs
docker image prune -f >/dev/null 2>&1 || true

echo "[INFO] Preview do PR #${PR_NUMBER} removido com sucesso."
