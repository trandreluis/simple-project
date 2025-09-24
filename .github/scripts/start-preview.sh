#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
HOST_PORT=$((8000 + PR_NUMBER))
CACHE_DIR="/tmp/.buildx-cache"
LOG_FILE="/tmp/${APP_NAME}.log"

echo "[INFO] Iniciando preview para PR #${PR_NUMBER}"

# Construir imagem
docker buildx build \
  --cache-to=type=local,dest=${CACHE_DIR},mode=max \
  --cache-from=type=local,src=${CACHE_DIR} \
  -t ${APP_NAME}:latest \
  --load .

# Rodar container da aplicação
docker run -d --name ${APP_NAME} -p ${HOST_PORT}:8080 ${APP_NAME}:latest

# Subir ngrok em container separado
docker run -d --name ${NGROK_NAME} --network host \
  -e NGROK_AUTHTOKEN=${NGROK_AUTHTOKEN} \
  ngrok/ngrok:latest http ${HOST_PORT} > "${LOG_FILE}" 2>&1 || true

# Aguardar ngrok subir e pegar URL
sleep 5
NGROK_URL=$(docker logs ${NGROK_NAME} 2>&1 | grep -oE "https://[0-9a-z]+\.ngrok-free\.app" | head -n 1)

if [ -z "$NGROK_URL" ]; then
  echo "[ERRO] Não foi possível capturar a URL do Ngrok"
  exit 1
fi

echo "[INFO] URL pública: $NGROK_URL"
echo "$NGROK_URL"
