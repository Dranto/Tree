#!/usr/bin/env bash
# Lance Godot 4.3 (binaire officiel) sur le projet godot/.
# Le binaire est téléchargé une fois depuis github.com/godotengine/godot-builds puis mis en cache.
# Exemples :
#   tools/godot.sh --headless --editor --quit   # importe le projet et signale les erreurs de script
#   tools/godot.sh --headless --quit-after 300  # lance le jeu ~5 s sans fenêtre
#   tools/godot.sh --xvfb -- --autotest         # partie automatique avec captures dans godot/autotest/
set -euo pipefail
VERSION="4.3-stable"
CACHE="${GODOT_CACHE:-$HOME/.cache/godot/$VERSION}"
BIN="$CACHE/Godot_v${VERSION}_linux.x86_64"
if [ ! -x "$BIN" ]; then
  mkdir -p "$CACHE"
  curl -sSL --retry 3 -o "$CACHE/godot.zip" \
    "https://github.com/godotengine/godot-builds/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
  unzip -oq "$CACHE/godot.zip" -d "$CACHE"
  rm -f "$CACHE/godot.zip"
  chmod +x "$BIN"
fi
cd "$(dirname "$0")/../godot"
# --xvfb : lance Godot dans un écran virtuel (rendu réel sans fenêtre, utile pour les captures).
if [ "${1:-}" = "--xvfb" ]; then
  shift
  exec xvfb-run -a -s "-screen 0 3440x1440x24" "$BIN" "$@"
fi
exec "$BIN" "$@"
