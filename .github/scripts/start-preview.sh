#!/bin/bash
set -e

PR_NUMBER=$1
PORT=$((8000 + PR_NUMBER % 1000)) # porta única para cada PR
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
CACHE_DIR="/tmp/.buildx-cache"

echo "[INFO] Iniciando preview para PR #${PR_NUMBER} na porta ${PORT}"

# Se container já existe, remover para atualizar
docker rm -f ${APP_NAME} || true

# Garantir que o builder buildx existe
docker buildx create --use --name buildx-simple || docker buildx use buildx-simple

# Build imagem docker com cache
docker buildx build \
  --cache-from=type=local,src=${CACHE_DIR} \
  --cache-to=type=local,dest=${CACHE_DIR}-new,mode=max \
  -t ${APP_NAME}:latest .

# Atualizar cache
rm -rf ${CACHE_DIR}
mv ${CACHE_DIR}-new ${CACHE_DIR}

# Rodar container da app
docker run -d --name ${APP_NAME} -p ${PORT}:8080 ${APP_NAME}:latest

# Matar ngrok anterior se existir
pkill -f "${NGROK_NAME}" || true

# Rodar ngrok apontando para porta do container
nohup ngrok http ${PORT} --name ${NGROK_NAME} > /tmp/${NGROK_NAME}.log 2>&1 &

# Esperar ngrok subir e pegar URL
sleep 5
URL=$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r ".tunnels[] | select(.config.addr==\"http://localhost:${PORT}\") | .public_url")

echo "[INFO] Preview URL: ${URL}"
echo "${URL}"
