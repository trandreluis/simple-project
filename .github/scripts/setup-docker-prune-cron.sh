#!/bin/bash
set -e

CRON_CMD="0 3 * * 0 docker system prune -af --volumes > /var/log/docker-prune.log 2>&1"

echo "[INFO] Configurando limpeza semanal do Docker via cron..."

# Verifica se já existe a regra no cron do root
if sudo crontab -l 2>/dev/null | grep -q "docker system prune -af --volumes"; then
  echo "[INFO] Já existe uma regra de prune configurada no cron. Nada a fazer."
else
  # Adiciona a regra ao cron do root
  (sudo crontab -l 2>/dev/null; echo "$CRON_CMD") | sudo crontab -
  echo "[INFO] Cron configurado: limpeza semanal todo domingo às 03h."
fi

echo "[INFO] Você pode verificar o log em /var/log/docker-prune.log"
