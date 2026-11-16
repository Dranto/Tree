#!/usr/bin/env bash
# Animation de la planche de détail de la charte graphique (personnages et objets qui bougent).
#   tools/charte-anim.sh [SORTIE.gif]   (par défaut godot/tests/visual/out/charte_details.gif)
# Rejoue la planche image par image (temps fixé, rendu logiciel) puis assemble un GIF en boucle avec ffmpeg.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/godot/tests/visual/out"
GIF="${1:-$OUT/charte_details.gif}"
mkdir -p "$OUT"; touch "$OUT/.gdignore"
rm -rf "$OUT/charte_anim"
export LIBGL_ALWAYS_SOFTWARE=1
"$ROOT/tools/godot.sh" --headless --editor --quit >/dev/null 2>&1
"$ROOT/tools/godot.sh" --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 2560x1440 --position 0,0 \
  res://tests/visual/runner.tscn -- --scenario=charte --seed=1234 --charte-anim 2>&1 | grep -E "ERROR" || true
ffmpeg -loglevel error -y -framerate 20 -i "$OUT/charte_anim/%03d.png" \
  -vf "scale=1600:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=sierra2_4a" \
  -loop 0 "$GIF"
echo "Animation : $GIF"
