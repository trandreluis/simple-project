#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
CACHE_DIR="/tmp/.buildx-cache"
NGROK_LOG="/tmp/${NGROK_NAME}.log"

echo "[INFO] Iniciando preview para PR #${PR_NUMBER}"

# Garantir que containers antigos não causem conflito
docker rm -f ${APP_NAME} || true
docker rm -f ${NGROK_NAME} || true

# Build da imagem
docker build \
  --cache-from=type=local,src=${CACHE_DIR} \
  --cache-to=type=local,dest=${CACHE_DIR},mode=max \
  -t ${APP_NAME}:latest .

# Subir app container
docker run -d --name ${APP_NAME} -p 0:8080 ${APP_NAME}:latest

# Pegar porta real mapeada
HOST_PORT=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' ${APP_NAME})
echo "[INFO] Aplicação rodando em porta local ${HOST_PORT}"

# Iniciar Ngrok em container separado e logar no arquivo
docker run -d \
  --name ${NGROK_NAME} \
  --network=container:${APP_NAME} \
  -e NGROK_AUTHTOKEN=${NGROK_AUTHTOKEN} \
  ngrok/ngrok:latest http 8080 --log=stdout > "${NGROK_LOG}" 2>&1

# Esperar até capturar a URL
for i in {1..15}; do
  URL=$(grep -o 'https://[0-9a-zA-Z.-]*\.ngrok-free\.app' "${NGROK_LOG}" | head -n1 || true)
  if [ -n "$URL" ]; then
    echo "[INFO] Ngrok URL capturada: $URL"
    echo "$URL"
    exit 0
  fi
  echo "[INFO] Aguardando URL do Ngrok... Tentativa $i/15"
  sleep 2
done

echo "[ERRO] Não foi possível capturar a URL do Ngrok. Veja os logs em ${NGROK_LOG}"
exit 1
