#!/usr/bin/env bash
# Avant/après du moteur de créatures (refonte des personnages, vague 1 A) : la même scène de combat
# du vrai jeu (tests/creatures_film.gd, graine et pas fixes), filmée avec l'ancien rendu
# (« --no-sprites ») puis avec le rendu cuit.
#   tools/creatures-film.sh DOSSIER [scène,scène…]   (scènes : melee, elites ; les deux par défaut)
# Dans DOSSIER : <scène>_avant_apres.gif (côte à côte, recadré sur le combat) et
# <scène>_avant_apres.png (une image en grand, puis un zoom ×2 du centre).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$(realpath -m "${1:?dossier de sortie}")"
SCENES="${2:-melee,elites}"
mkdir -p "$DEST"
export LIBGL_ALWAYS_SOFTWARE=1
export TREE_LANG="${TREE_LANG:-fr}"
"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
for sc in ${SCENES//,/ }; do
  for mode in avant apres; do
    flag=()
    [ "$mode" = avant ] && flag=(--no-sprites)
    rm -rf "$DEST/$sc/$mode"
    mkdir -p "$DEST/$sc/$mode"
    "$ROOT/tools/godot.sh" --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 --position 0,0 \
      res://tests/creatures_film.tscn -- --seed=1234 --scene="$sc" --out="$DEST/$sc/$mode" "${flag[@]}" 2>&1 \
      | grep -E "FILM|SCRIPT ERROR" || true
  done
  ffmpeg -loglevel error -y -framerate 30 -i "$DEST/$sc/avant/%03d.png" -framerate 30 -i "$DEST/$sc/apres/%03d.png" \
    -filter_complex "[0]crop=760:520:420:190,scale=560:-1:flags=lanczos[a];[1]crop=760:520:420:190,scale=560:-1:flags=lanczos[b];[a][b]hstack,split[x][y];[x]palettegen=max_colors=192[p];[y][p]paletteuse=dither=sierra2_4a" \
    -loop 0 "$DEST/${sc}_avant_apres.gif"
  ffmpeg -loglevel error -y -i "$DEST/$sc/avant/090.png" -i "$DEST/$sc/apres/090.png" \
    -filter_complex "[0]crop=1000:620:300:140[a];[1]crop=1000:620:300:140[b];[0]crop=500:310:550:295,scale=1000:620:flags=lanczos[za];[1]crop=500:310:550:295,scale=1000:620:flags=lanczos[zb];[a][b]hstack[top];[za][zb]hstack[bot];[top][bot]vstack" \
    "$DEST/${sc}_avant_apres.png"
done
echo "Film : $DEST"
