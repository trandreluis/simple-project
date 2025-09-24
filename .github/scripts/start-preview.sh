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

# Build da imagem sem cache
docker build -t ${APP_NAME}:latest .

# Rodar o container da aplicação
docker run -d --name ${APP_NAME} -p ${HOST_PORT}:8080 ${APP_NAME}:latest

# Rodar o container do ngrok
docker run -d --name ${NGROK_NAME} \
  -e NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN}" \
  --network host \
  ngrok/ngrok:latest http ${HOST_PORT} > /tmp/${NGROK_NAME}.log 2>&1

# Confirmar que o container subiu
if ! docker ps --format '{{.Names}}' | grep -q "${NGROK_NAME}"; then
  echo "[ERRO] Container do ngrok não iniciou corretamente."
  docker logs ${NGROK_NAME} || true
  exit 1
fi

# Aguardar e tentar capturar a URL até 5 vezes
URL=""
for i in {1..5}; do
  sleep 3
  URL=$(docker logs ${NGROK_NAME} 2>&1 | grep -o 'https://[0-9a-z]*\.ngrok-free\.app' | head -n 1)
  if [ -n "$URL" ]; then
    break
  fi
done

if [ -z "$URL" ]; then
  echo "[ERRO] Não foi possível capturar a URL do Ngrok. Veja os logs em /tmp/${NGROK_NAME}.log"
  docker logs ${NGROK_NAME} || true
  exit 1
fi

echo "[INFO] URL pública gerada: $URL"
echo "$URL"
