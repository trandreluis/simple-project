#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
HOST_PORT=$((8000 + PR_NUMBER))

# Logs sempre no stderr
>&2 echo "[INFO] Iniciando preview para PR #${PR_NUMBER} na porta ${HOST_PORT}"

# Garantir que não há containers anteriores
docker rm -f ${APP_NAME} 2>/dev/null || true
docker rm -f ${NGROK_NAME} 2>/dev/null || true

# Build da imagem sem cache
>&2 echo "[INFO] Build da imagem Docker..."
docker build -t ${APP_NAME}:latest . >&2

# Rodar o container da aplicação
>&2 echo "[INFO] Subindo container da aplicação ${APP_NAME}..."
docker run -d --name ${APP_NAME} -p ${HOST_PORT}:8080 ${APP_NAME}:latest >&2

# Rodar o container do ngrok
>&2 echo "[INFO] Subindo container do ngrok ${NGROK_NAME}..."
docker run -d --name ${NGROK_NAME} \
  -e NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN}" \
  --network host \
  ngrok/ngrok:latest http ${HOST_PORT} > /tmp/${NGROK_NAME}.log 2>&1 &

# Aguardar o ngrok iniciar
sleep 5

# Capturar a URL do ngrok
URL=$(docker logs ${NGROK_NAME} 2>&1 | grep -o 'https://[0-9a-z]*\.ngrok-free\.app' | head -n 1)

if [ -z "$URL" ]; then
  >&2 echo "[ERRO] Não foi possível capturar a URL do Ngrok. Veja os logs em /tmp/${NGROK_NAME}.log"
  exit 1
fi

>&2 echo "[INFO] URL pública gerada: $URL"
echo "$URL"   # <-- ÚNICA saída em stdout
