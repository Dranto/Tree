#!/usr/bin/env bash
# Film des effets du jalon Éclat : rejoue de courtes scènes du vrai jeu (tests/visual/film.gd) et
# assemble un GIF par scène.
#   tools/eclat-film.sh DOSSIER [scène,scène…]   (toutes les scènes par défaut)
# Images dans DOSSIER/<scène>/NNN.png, GIF dans DOSSIER/<scène>.gif.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$(realpath -m "${1:?dossier de sortie}")"
CLIPS="${2:-}"
mkdir -p "$DEST"
export LIBGL_ALWAYS_SOFTWARE=1
"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
ARGS=(--out="$DEST")
[ -n "$CLIPS" ] && ARGS+=(--clips="$CLIPS")
"$ROOT/tools/godot.sh" --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 --position 0,0 \
  res://tests/visual/film.tscn -- --seed=1234 "${ARGS[@]}" 2>&1 | grep -E "ERROR|FILM|SCRIPT" || true
for d in "$DEST"/*/; do
  n="$(basename "$d")"
  [ -f "$d/000.png" ] || continue
  ffmpeg -loglevel error -y -framerate 30 -i "$d/%03d.png" \
    -vf "crop=800:450:400:225,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=160[p];[b][p]paletteuse=dither=sierra2_4a" \
    -loop 0 "$DEST/$n.gif"
done
echo "Film : $DEST"
