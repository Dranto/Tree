#!/usr/bin/env bash
# Animation de l'Arbre de vie (ouverture, invitations, survol, éclosions, sève, braises, pollen).
#   tools/arbre-anim.sh [SORTIE.gif]   (par défaut godot/tests/visual/out/arbre_anim.gif)
# Rejoue l'arbre image par image (temps fixe, rendu logiciel) puis assemble un GIF en boucle avec ffmpeg.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/godot/tests/visual/out"
GIF="${1:-$OUT/arbre_anim.gif}"
mkdir -p "$OUT"; touch "$OUT/.gdignore"
rm -rf "$OUT/arbre_anim"
export LIBGL_ALWAYS_SOFTWARE=1
"$ROOT/tools/godot.sh" --headless --editor --quit >/dev/null 2>&1
"$ROOT/tools/godot.sh" --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 --position 0,0 \
  -s res://tests/tree_anim.gd 2>&1 | grep -E "SCRIPT ERROR" || true
ffmpeg -loglevel error -y -framerate 20 -i "$OUT/arbre_anim/%03d.png" \
  -vf "scale=1200:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=sierra2_4a" \
  -loop 0 "$GIF"
echo "Animation : $GIF"
