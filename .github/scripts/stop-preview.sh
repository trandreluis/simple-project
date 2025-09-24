#!/bin/bash
set -e

PR_NUMBER=$1
APP_NAME="simple-project-pr${PR_NUMBER}"
NGROK_NAME="ngrok-pr${PR_NUMBER}"

echo "[INFO] Removendo preview para PR #${PR_NUMBER}"

# Parar container e remover
docker rm -f ${APP_NAME} || true

# Matar ngrok correspondente
pkill -f "${NGROK_NAME}" || true
