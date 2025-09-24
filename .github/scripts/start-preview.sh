#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
HOST_PORT=$((8000 + PR_NUMBER))
API_PORT=$((4040 + PR_NUMBER))

echo "[INFO] Iniciando preview para PR #${PR_NUMBER} na porta ${HOST_PORT}"

# Garantir que não há containers anteriores
docker rm -f ${APP_NAME} 2>/dev/null || true
docker rm -f ${NGROK_NAME} 2>/dev/null || true

# Build da imagem sem cache
echo "[INFO] Build da imagem Docker..."
docker build -t ${APP_NAME}:latest .

# Rodar o container da aplicação
echo "[INFO] Subindo container da aplicação ${APP_NAME}..."
docker run -d --name ${APP_NAME} -p ${HOST_PORT}:8080 ${APP_NAME}:latest

# Rodar o container do ngrok expondo API na porta 4040+PR_NUMBER
echo "[INFO] Subindo container do ngrok ${NGROK_NAME}..."
docker run -d --name ${NGROK_NAME} \
  -e NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN}" \
  -p ${API_PORT}:4040 \
  ngrok/ngrok:latest http host.docker.internal:${HOST_PORT} > /tmp/${NGROK_NAME}.log 2>&1

# Aguardar o ngrok iniciar e capturar a URL pela API
echo "[INFO] Aguardando ngrok inicializar na porta ${API_PORT}..."
for i in {1..10}; do
  sleep 2
  URL=$(curl -s http://127.0.0.1:${API_PORT}/api/tunnels | grep -o 'https://[0-9a-z]*\.ngrok-free\.app' | head -n 1 || true)
  if [ -n "$URL" ]; then
    break
  fi
done

if [ -z "$URL" ]; then
  echo "[ERRO] Não foi possível capturar a URL do Ngrok. Veja os logs em /tmp/${NGROK_NAME}.log"
  exit 1
fi

echo "[INFO] URL pública gerada: $URL"
echo "$URL"
