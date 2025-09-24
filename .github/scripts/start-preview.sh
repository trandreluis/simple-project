#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
CACHE_DIR="/tmp/.buildx-cache"

echo "[INFO] Iniciando preview para PR #${PR_NUMBER}"

# Construir a imagem
docker buildx build \
  --cache-to=type=local,dest=${CACHE_DIR} \
  --cache-from=type=local,src=${CACHE_DIR} \
  -t ${APP_NAME}:latest \
  . --load

# Calcular porta baseada no número do PR
HOST_PORT=$((8000 + PR_NUMBER))

# Subir container da aplicação
docker run -d --rm \
  --name ${APP_NAME} \
  -p ${HOST_PORT}:8080 \
  ${APP_NAME}:latest

echo "[INFO] Aplicação rodando em porta local ${HOST_PORT}"

# Subir túnel ngrok no mesmo namespace de rede do container
docker run -d \
  --name ${NGROK_NAME} \
  --network=container:${APP_NAME} \
  -e NGROK_AUTHTOKEN=${NGROK_AUTHTOKEN} \
  ngrok/ngrok:latest http 8080 > /tmp/${NGROK_NAME}.cid

# Tentar capturar a URL do túnel
for i in {1..10}; do
  URL=$(docker logs ${NGROK_NAME} 2>&1 | grep -o 'https://[0-9a-zA-Z.-]*\.ngrok-free\.app' | head -n1 || true)
  if [ -n "$URL" ]; then
    echo "[INFO] Ngrok URL capturada: $URL"
    echo "$URL"
    exit 0
  fi
  echo "[INFO] Aguardando URL do Ngrok... Tentativa $i/10"
  sleep 2
done

echo "[ERRO] Não foi possível capturar a URL do Ngrok. Veja os logs em /tmp/${NGROK_NAME}.log"
docker logs ${NGROK_NAME} &> /tmp/${NGROK_NAME}.log
exit 1
