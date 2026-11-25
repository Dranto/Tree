#!/usr/bin/env bash
# Importe le projet Godot (--headless --import) avec relance automatique : sur la machine de la CI,
# l'import plante parfois à la sortie (Aborted / segmentation) alors que tout est importé ; un
# deuxième passage, qui trouve le cache prêt, réussit. Sans import le jeu se lance sans ressources.
#   tools/import.sh [journal]        # 3 essais au plus ; journal : fichier de sortie (sinon /dev/null)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="${1:-/dev/null}"
for attempt in 1 2 3; do
  if "$ROOT/tools/godot.sh" --headless --import >"$LOG" 2>&1; then
    exit 0
  fi
  echo "Import du projet : échec (essai $attempt/3)"
  [ "$LOG" != /dev/null ] && tail -n 15 "$LOG"
  sleep 2
done
echo "Import du projet : échec après 3 essais"
exit 1
