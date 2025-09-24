#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"
HOST_PORT=$((8000 + PR_NUMBER))

echo "[INFO] Iniciando preview para PR #${PR_NUMBER} (porta base ${HOST_PORT})"

# Garantir que não há containers anteriores
docker rm -f ${APP_NAME} 2>/dev/null || true
docker rm -f ${NGROK_NAME} 2>/dev/null || true

# Build da imagem sem cache
docker build -t ${APP_NAME}:latest .

# Tentar iniciar o app na porta base; se ocupada, tentar próximas
SELECTED_PORT=${HOST_PORT}
STARTED=0
for P in $(seq ${HOST_PORT} $((HOST_PORT+20))); do
  # Verifica se a porta está livre (ss geralmente existe em Ubuntu)
  if ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${P}$"; then
    echo "[WARN] Porta ${P} em uso, tentando a próxima..."
    continue
  fi

  # Tenta subir o container mapeando a porta
  if docker run -d --name ${APP_NAME} -p ${P}:8080 ${APP_NAME}:latest >/dev/null 2>&1; then
    SELECTED_PORT=${P}
    STARTED=1
    break
  else
    echo "[WARN] Falha ao iniciar app na porta ${P}, tentando a próxima..."
    docker rm -f ${APP_NAME} >/dev/null 2>&1 || true
  fi
done

if [ ${STARTED} -ne 1 ]; then
  echo "[ERRO] Não foi possível iniciar o container da aplicação em nenhuma porta entre ${HOST_PORT} e $((HOST_PORT+20))."
  exit 1
fi

echo "[INFO] Aplicação rodando na porta ${SELECTED_PORT}"

# Subir o container do ngrok expondo a porta efetiva no host
docker run -d --name ${NGROK_NAME} \
  -e NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN}" \
  --network host \
  ngrok/ngrok:latest http ${SELECTED_PORT}

# Confirmar que o container do ngrok subiu
if ! docker ps --format '{{.Names}}' | grep -q "^${NGROK_NAME}$"; then
  echo "[ERRO] Container do ngrok não iniciou corretamente."
  docker logs ${NGROK_NAME} || true
  exit 1
fi

# Aguardar e tentar capturar a URL até 10 vezes
URL=""
for i in {1..10}; do
  sleep 2
  URL=$(docker logs ${NGROK_NAME} 2>&1 | grep -o 'https://[0-9a-zA-Z.-]*\.ngrok-free\.app' | head -n 1 || true)
  if [ -n "$URL" ]; then
    break
  fi
  echo "[INFO] Aguardando URL do Ngrok... Tentativa $i/10"
done

if [ -z "$URL" ]; then
  echo "[ERRO] Não foi possível capturar a URL do Ngrok."
  docker logs ${NGROK_NAME} || true
  exit 1
fi

echo "[INFO] URL pública gerada: $URL"
# A ÚLTIMA linha precisa ser só a URL (o workflow captura com tail -n 1)
echo "$URL"
