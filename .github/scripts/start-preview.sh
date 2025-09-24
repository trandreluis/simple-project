#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
HOST_PORT=$((8000 + PR_NUMBER))

echo "[INFO] Iniciando preview para PR #${PR_NUMBER} na porta ${HOST_PORT}"

# Garantir que não há containers anteriores
docker rm -f ${APP_NAME} 2>/dev/null || true
docker rm -f ${NGROK_NAME} 2>/dev/null || true

echo "[INFO] Build da imagem Docker..."
# Build da imagem sem cache
docker build -t ${APP_NAME}:latest .

echo "[INFO] Subindo container da aplicação ${APP_NAME}..."
# Rodar o container da aplicação
docker run -d --name ${APP_NAME} -p ${HOST_PORT}:8080 ${APP_NAME}:latest

echo "[INFO] Subindo container do ngrok ${NGROK_NAME}..."
# Rodar o container do ngrok com a API exposta
docker run -d --name ${NGROK_NAME} \
  -e NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN}" \
  -p 4040:4040 \
  ngrok/ngrok:latest http ${HOST_PORT} > /tmp/${NGROK_NAME}.log 2>&1

# Aguardar o ngrok iniciar
sleep 5

# Capturar a URL pública via API local
URL=$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')

if [ -z "$URL" ] || [ "$URL" == "null" ]; then
  echo "[ERRO] Não foi possível capturar a URL do Ngrok. Veja os logs em /tmp/${NGROK_NAME}.log"
  exit 1
fi

echo "[INFO] URL pública gerada: $URL"
echo "$URL"
