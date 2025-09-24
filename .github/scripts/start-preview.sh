#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project"
CONTAINER_NAME="${APP_NAME}-pr${PR_NUMBER}"
HOST_PORT=$((8000 + PR_NUMBER))

echo "[INFO] Iniciando preview para PR #${PR_NUMBER} na porta ${HOST_PORT}..."

# Build da imagem
docker build -t "${CONTAINER_NAME}:latest" .

# Remove container antigo se existir
if [ "$(docker ps -aq -f name=${CONTAINER_NAME})" ]; then
  docker rm -f "${CONTAINER_NAME}" || true
fi

# Sobe o container com porta exclusiva
docker run -d --name "${CONTAINER_NAME}" -p ${HOST_PORT}:8080 "${CONTAINER_NAME}:latest"

# Inicia Ngrok com log dedicado para o PR
ngrok http ${HOST_PORT} > "ngrok-${PR_NUMBER}.log" 2>&1 &
sleep 5

# Captura URL do Ngrok
NGROK_URL=$(curl --silent --max-time 10 http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')

if [[ -z "$NGROK_URL" || "$NGROK_URL" == "null" ]]; then
  echo "Erro: não foi possível obter a URL do Ngrok" >&2
  exit 1
fi

echo "[INFO] Preview disponível em: $NGROK_URL"
# Só imprime a URL para o workflow capturar
echo "$NGROK_URL"
