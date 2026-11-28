#!/usr/bin/env bash
# Film du combat contre la Mère-Ronce sur son morceau (tests/visual/ronce_musique_film.gd) : approche,
# charge, drop, les phases, mort ; Movie Maker de Godot (image et son calés), puis un .mp4 léger.
#   tools/ronce-film.sh DOSSIER [LARGEURxHAUTEUR] [CYCLE]   (CYCLE 2 : avec la phase exaltée)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$(realpath -m "${1:?dossier de sortie}")"
RES="${2:-1600x900}"
CYCLE="${3:-1}"
NAME="mere_ronce_musique$([ "$CYCLE" = 1 ] || echo "_cycle$CYCLE")"
mkdir -p "$DEST"
export LIBGL_ALWAYS_SOFTWARE=1
"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
"$ROOT/tools/godot.sh" --xvfb --resolution "$RES" --position 0,0 --fixed-fps 30 \
  --write-movie "$DEST/${NAME}_brut.avi" res://tests/visual/ronce_musique_film.tscn -- --movie-fps=30 --cycle="$CYCLE" 2>&1 \
  | grep --line-buffered -E "ERROR|FILM|SCRIPT" | grep --line-buffered -v "…" | tee "$DEST/${NAME}_reperes.txt" || true
ffmpeg -loglevel error -y -i "$DEST/${NAME}_brut.avi" -c:v libx264 -crf 26 -preset medium -pix_fmt yuv420p \
  -c:a aac -b:a 192k "$DEST/$NAME.mp4"
rm -f "$DEST/${NAME}_brut.avi"
echo "Film : $DEST/$NAME.mp4"
