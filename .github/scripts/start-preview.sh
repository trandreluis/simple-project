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

# Verificar se token do Ngrok está configurado
if [ -z "$NGROK_AUTHTOKEN" ]; then
  echo "[ERRO] NGROK_AUTHTOKEN não definido. Configure como secret no GitHub."
  exit 1
fi

# Subir ngrok em container separado
echo "[INFO] Subindo container do ngrok..."
docker run -d --name ${NGROK_NAME} --network host \
  -e NGROK_AUTHTOKEN=${NGROK_AUTHTOKEN} \
  ngrok/ngrok:latest http ${HOST_PORT} > "${LOG_FILE}" 2>&1

# Debug inicial
echo "[DEBUG] Verificando se o container do ngrok subiu..."
docker ps -a | grep ${NGROK_NAME} || echo "[ERRO] Container ngrok não encontrado"

# Aguardar até 30s pelo ngrok
NGROK_URL=""
for i in {1..30}; do
  NGROK_URL=$(docker logs ${NGROK_NAME} 2>&1 | grep -oE "https://[0-9a-z]+\.ngrok-free\.app" | head -n 1 || true)
  if [ -n "$NGROK_URL" ]; then
    break
  fi
  echo "[INFO] Aguardando ngrok subir... (${i}s)"
  sleep 1
done

if [ -z "$NGROK_URL" ]; then
  echo "[ERRO] Não foi possível capturar a URL do Ngrok após 30s."
  echo "[DEBUG] Logs do container do ngrok:"
  docker logs ${NGROK_NAME} || true
  exit 1
fi

echo "[INFO] URL pública: $NGROK_URL"
# A URL do ngrok será a última linha da saída (mantendo compatibilidade com o workflow)
echo "$NGROK_URL"
