#!/usr/bin/env bash
# Planches des Flétris de Sève (R4) : planche_avant_apres.png, scene_avant_apres.png (+ avant, après, zoom),
# marche_annonce.gif, apercus/<sorte>.png. Usage (depuis la racine du dépôt) :
#   godot/tests/bestiaire/seve/planches.sh [DOSSIER]   # par défaut : godot/tests/bestiaire/out/seve
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
OUT="$(realpath -m "${1:-$ROOT/godot/tests/bestiaire/out/seve}")"
mkdir -p "$OUT/apercus"
export LIBGL_ALWAYS_SOFTWARE=1
G="$ROOT/tools/godot.sh"
"$G" --headless --import >/dev/null 2>&1 || true
run() { "$G" "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" -A2 || true; }
run --xvfb --audio-driver Dummy --resolution 2560x1440 -s res://tests/bestiaire/seve/planche.gd -- "$OUT/planche_avant_apres.png"
for k in sangsue_vase crapaud libellule souche; do
  run --xvfb --audio-driver Dummy --resolution 1800x1400 -s res://tests/bestiaire/seve/apercu.gd -- "$OUT/apercus/$k.png" "$k"
done
run --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1920x1080 res://tests/bestiaire/seve/scene.tscn -- --seed=1234 --out="$OUT"
FR="$OUT/gif_images"
rm -rf "$FR"
run --xvfb --audio-driver Dummy --resolution 1270x590 -s res://tests/bestiaire/seve/gif.gd -- "$FR"
ffmpeg -loglevel error -y -framerate 24 -i "$FR/%03d.png" \
  -vf "split[a][b];[a]palettegen=max_colors=256:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a" "$OUT/marche_annonce.gif"
rm -rf "$FR"
ls -la "$OUT"
