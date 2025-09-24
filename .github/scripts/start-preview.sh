#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
HOST_PORT=$((8000 + PR_NUMBER))

echo "[INFO] Iniciando preview para PR #${PR_NUMBER}..."

# Remover containers antigos se existirem
docker rm -f ${APP_NAME} 2>/dev/null || true
docker rm -f ${NGROK_NAME} 2>/dev/null || true

# Construir imagem da aplicação (sem cache buildx)
echo "[INFO] Construindo imagem Docker para ${APP_NAME}..."
docker build -t ${APP_NAME}:latest .

# Rodar container da aplicação
echo "[INFO] Subindo container da aplicação na porta ${HOST_PORT}..."
docker run -d --name ${APP_NAME} -p ${HOST_PORT}:8080 ${APP_NAME}:latest

# Subir ngrok em container separado
echo "[INFO] Subindo túnel Ngrok..."
docker run -d --name ${NGROK_NAME} \
  --net=host \
  -e NGROK_AUTHTOKEN=${NGROK_AUTHTOKEN} \
  ngrok/ngrok:latest http ${HOST_PORT} \
  > /tmp/${NGROK_NAME}.log 2>&1

# Aguardar ngrok subir
sleep 5

# Capturar URL do ngrok
URL=$(docker exec ${NGROK_NAME} curl -s http://127.0.0.1:4040/api/tunnels \
  | grep -o '"public_url":"[^"]*"' \
  | head -n 1 \
  | cut -d'"' -f4)

if [ -z "$URL" ]; then
  echo "[ERRO] Não foi possível capturar a URL do Ngrok. Veja os logs em /tmp/${NGROK_NAME}.log" >&2
  exit 1
fi

echo "[INFO] Preview disponível em: $URL"
echo "$URL"
