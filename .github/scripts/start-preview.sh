#!/bin/bash
set -e

PR_NUMBER=$1
PORT=$((8000 + PR_NUMBER % 1000)) # porta única para cada PR
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
CACHE_DIR="/tmp/.buildx-cache"

# Se container já existe, remover para atualizar
docker rm -f ${APP_NAME} || true

# Garantir que o builder buildx existe
if ! docker buildx inspect buildx-simple >/dev/null 2>&1; then
  docker buildx create --use --name buildx-simple
else
  docker buildx use buildx-simple
fi

# Build imagem docker com cache e carregando no Docker local
docker buildx build \
  --cache-from=type=local,src=${CACHE_DIR} \
  --cache-to=type=local,dest=${CACHE_DIR}-new,mode=max \
  -t ${APP_NAME}:latest . \
  --load

# Atualizar cache
rm -rf ${CACHE_DIR}
mv ${CACHE_DIR}-new ${CACHE_DIR}

# Rodar container da app (captura o ID mas não imprime)
CONTAINER_ID=$(docker run -d --name ${APP_NAME} -p ${PORT}:8080 ${APP_NAME}:latest)

# Matar ngrok anterior se existir
pkill -f "${NGROK_NAME}" || true

# Rodar ngrok apontando para porta do container
nohup ngrok http ${PORT} --name ${NGROK_NAME} > /tmp/${NGROK_NAME}.log 2>&1 &

# Tentar capturar a URL do Ngrok com retries
URL=""
for i in {1..10}; do
  sleep 3
  URL=$(curl --silent http://127.0.0.1:4040/api/tunnels \
    | jq -r ".tunnels[] | select(.config.addr==\"http://localhost:${PORT}\") | .public_url")
  if [ -n "$URL" ] && [ "$URL" != "null" ]; then
    break
  fi
done

if [ -z "$URL" ] || [ "$URL" = "null" ]; then
  echo "[ERRO] Não foi possível capturar a URL do Ngrok após várias tentativas." >&2
  docker logs ${APP_NAME} || true
  tail -n 50 /tmp/${NGROK_NAME}.log || true
  exit 1
fi

# ⚠️ Importante: imprimir só a URL, sem logs extras
echo "${URL}"
