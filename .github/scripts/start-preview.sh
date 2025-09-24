#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
HOST_PORT=$((8000 + PR_NUMBER))
CACHE_DIR="/tmp/.buildx-cache"
LOG_FILE="/tmp/${NGROK_NAME}.log"

echo "[INFO] Iniciando preview para PR #${PR_NUMBER} na porta ${HOST_PORT}"

# Build da imagem
docker buildx build --load \
  --cache-to=type=local,dest=${CACHE_DIR} \
  --cache-from=type=local,src=${CACHE_DIR} \
  -t ${APP_NAME}:latest .

# Subir container da aplicação
docker run -d --name ${APP_NAME} -p ${HOST_PORT}:8080 ${APP_NAME}:latest

# Garantir que o container subiu
sleep 5
if ! docker ps --format '{{.Names}}' | grep -q "^${APP_NAME}$"; then
  echo "[ERRO] Falha ao iniciar container ${APP_NAME}" >&2
  exit 1
fi

# Subir container do Ngrok
echo "[INFO] Iniciando ngrok..."
docker run -d --name ${NGROK_NAME} \
  -e NGROK_AUTHTOKEN=${NGROK_AUTHTOKEN} \
  -v /tmp/ngrok-${PR_NUMBER}:/tmp \
  ngrok/ngrok:latest http host.docker.internal:${HOST_PORT} > "${LOG_FILE}" 2>&1

sleep 5

# Pegar URL do Ngrok
URL=$(docker logs ${NGROK_NAME} 2>&1 | grep -o "https://[0-9a-z]*\.ngrok-free\.app" | head -n 1)

if [ -z "$URL" ]; then
  echo "[ERRO] Não foi possível capturar a URL do Ngrok. Veja os logs em ${LOG_FILE}" >&2
  exit 1
fi

echo "[INFO] Preview disponível em: ${URL}"
echo "${URL}"
