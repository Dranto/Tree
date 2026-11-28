#!/usr/bin/env bash
# Veille de la machine GPU (lancée toutes les 5 minutes par arborescence-gpu-veille.timer, installé par
# tools/gpu/setup.sh) : sans job GitHub en cours ni connexion SSH depuis IDLE_MINUTES (30 par
# défaut), la machine se remet elle-même en réserve (shelve) et n'est plus facturée à l'heure.
# Filet de sécurité : la CI l'éteint déjà après chaque run (workflow « Rendus GPU »).
set -uo pipefail
ENV_FILE=/etc/arborescence-gpu.env
STATE=/var/lib/arborescence-gpu/dernier-travail
mkdir -p "$(dirname "$STATE")"
# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && { set -a; . "$ENV_FILE"; set +a; }
[ -n "${OVH_CONSUMER_KEY:-}" ] || exit 0   # pas de clé : rien à faire
IDLE_MINUTES="${IDLE_MINUTES:-30}"

now=$(date +%s)
# Occupée : un job du runner tourne, ou quelqu'un est connecté en SSH.
if pgrep -f Runner.Worker >/dev/null || [ -n "$(who)" ]; then
  touch "$STATE"
  exit 0
fi
boot=$(( now - $(cut -d. -f1 /proc/uptime) ))
last=$boot
[ -f "$STATE" ] && [ "$(stat -c %Y "$STATE")" -gt "$last" ] && last=$(stat -c %Y "$STATE")
idle=$(( (now - last) / 60 ))
if [ "$idle" -ge "$IDLE_MINUTES" ]; then
  logger -t arborescence-gpu "Inoccupée depuis $idle min : remise en réserve"
  /opt/arborescence-gpu/ovh-gpu.sh stop 2>&1 | logger -t arborescence-gpu
fi
