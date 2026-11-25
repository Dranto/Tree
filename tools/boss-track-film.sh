#!/usr/bin/env bash
# Film du combat contre la Flétrissure avec sa musique faite à la main (tests/visual/boss_track_film.gd) :
# Movie Maker de Godot (image et son calés), puis un .mp4 léger.
#   tools/boss-track-film.sh DOSSIER [LARGEURxHAUTEUR]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$(realpath -m "${1:?dossier de sortie}")"
RES="${2:-1600x900}"
mkdir -p "$DEST"
export LIBGL_ALWAYS_SOFTWARE=1
"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
"$ROOT/tools/godot.sh" --xvfb --resolution "$RES" --position 0,0 --fixed-fps 30 \
  --write-movie "$DEST/flétrissure_brut.avi" res://tests/visual/boss_track_film.tscn -- --movie-fps=30 2>&1 \
  | grep -E "ERROR|FILM|SCRIPT" | grep -v "…" | tee "$DEST/reperes.txt" || true
ffmpeg -loglevel error -y -i "$DEST/flétrissure_brut.avi" -c:v libx264 -crf 26 -preset medium -pix_fmt yuv420p \
  -c:a aac -b:a 192k "$DEST/fletrissure_musique.mp4"
rm -f "$DEST/flétrissure_brut.avi"
echo "Film : $DEST/fletrissure_musique.mp4"
