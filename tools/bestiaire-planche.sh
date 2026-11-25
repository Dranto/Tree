#!/usr/bin/env bash
# Planche de direction du « Bestiaire d'herbier » (refonte des personnages, vague 0) :
#   planche_avant_apres.png (2560×1440), heros_evolution.png (2560×1440), scene_avant_apres.png (+ scene_avant, scene_apres, scene_zoom),
#   marche_annonce.gif. Rien n'est comparé : c'est une planche à regarder.
#
#   tools/bestiaire-planche.sh [DOSSIER]   # par défaut : godot/tests/bestiaire/out/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(realpath -m "${1:-$ROOT/godot/tests/bestiaire/out}")"
mkdir -p "$OUT"
export LIBGL_ALWAYS_SOFTWARE=1
"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
run() { "$ROOT/tools/godot.sh" "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" -A2 || true; }
echo "== Planche"
run --xvfb --audio-driver Dummy --resolution 2560x1440 -s res://tests/bestiaire/planche.gd -- "$OUT/planche_avant_apres.png"
echo "== Évolution du héros"
run --xvfb --audio-driver Dummy --resolution 2560x1440 -s res://tests/bestiaire/heros.gd -- "$OUT/heros_evolution.png"
echo "== Scène de combat"
run --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1920x1080 res://tests/bestiaire/scene.tscn -- --seed=1234 --out="$OUT"
echo "== GIF"
FR="$OUT/gif_images"
rm -rf "$FR"
run --xvfb --audio-driver Dummy --resolution 1270x590 -s res://tests/bestiaire/gif.gd -- "$FR"
ffmpeg -loglevel error -y -framerate 24 -i "$FR/%03d.png" \
  -vf "split[a][b];[a]palettegen=max_colors=256:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a" "$OUT/marche_annonce.gif"
ls -la "$OUT"
