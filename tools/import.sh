#!/usr/bin/env bash
# Importe le projet Godot (--headless --import) avec relance automatique : sur la machine de la CI,
# l'import plante parfois à la sortie (Aborted / segmentation) alors que tout est importé ; un
# deuxième passage, qui trouve le cache prêt, réussit. Sans import le jeu se lance sans ressources.
#   tools/import.sh [journal] [copie] # 3 essais au plus ; journal : fichier de sortie (sinon /dev/null) ;
#                                     # copie : autre copie du dépôt à importer (base d'une mesure en paires,
#                                     # qui n'a pas forcément ce script)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="${1:-/dev/null}"
TARGET="${2:-$ROOT}"
for attempt in 1 2 3; do
  if "$TARGET/tools/godot.sh" --headless --import >"$LOG" 2>&1; then
    exit 0
  fi
  echo "Import du projet : échec (essai $attempt/3)"
  [ "$LOG" != /dev/null ] && tail -n 15 "$LOG"
  sleep 2
done
echo "Import du projet : échec après 3 essais"
exit 1
