#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
HOST_PORT=$((8000 + PR_NUMBER))
CACHE_DIR="/tmp/.buildx-cache"
NGROK_LOG="/tmp/${NGROK_NAME}.log"

echo "[INFO] Subindo preview para PR #${PR_NUMBER} na porta ${HOST_PORT}"

# Garantir que não existam containers antigos
docker rm -f ${APP_NAME} 2>/dev/null || true
docker rm -f ${NGROK_NAME} 2>/dev/null || true

# Garantir que existe um builder buildx com driver containerd
if ! docker buildx inspect buildx-simple >/dev/null 2>&1; then
  echo "[INFO] Criando builder buildx 'buildx-simple' com driver containerd..."
  docker buildx create --name buildx-simple --driver docker-container --use
  docker buildx inspect --bootstrap
else
  echo "[INFO] Reutilizando builder existente 'buildx-simple'"
  docker buildx use buildx-simple
fi

# Fazer build com cache
docker buildx build \
  --cache-from=type=local,src=${CACHE_DIR} \
  --cache-to=type=local,dest=${CACHE_DIR},mode=max \
  -t ${APP_NAME}:latest \
  --load .

# Subir container da aplicação
docker run -d --name ${APP_NAME} -p ${HOST_PORT}:8080 ${APP_NAME}:latest

# Subir ngrok em segundo plano
docker run -d --name ${NGROK_NAME} \
  -e NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN}" \
  --net=host \
  ngrok/ngrok:latest http ${HOST_PORT} > "${NGROK_LOG}" 2>&1

# Aguardar até que o túnel esteja pronto
echo "[INFO] Aguardando URL pública do Ngrok..."
URL=""
for i in {1..10}; do
  sleep 3
  URL=$(docker logs ${NGROK_NAME} 2>/dev/null | grep -o 'https://[a-zA-Z0-9.-]*\.ngrok-free\.app' | head -n1 || true)
  if [ -n "$URL" ]; then
    break
  fi
done

if [ -z "$URL" ]; then
  echo "[ERRO] Não foi possível capturar a URL do Ngrok. Veja os logs em ${NGROK_LOG}"
  exit 1
fi

echo "[INFO] Preview rodando:"
echo "       App:   ${APP_NAME}"
echo "       Porta: ${HOST_PORT}"
echo "       URL:   ${URL}"

# Retornar apenas a URL no stdout (para o workflow capturar)
echo "$URL"
