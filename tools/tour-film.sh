#!/usr/bin/env bash
# GIF avant/après de la traversée du monde (refonte du monde, vague 3 I) : un tour autour de la graine à
# travers les six régions et leurs frontières (godot/tests/paysages/tour_film.gd), joué sur la base
# (BASE_DIR, ex. develop d'avant la refonte) et sur cette branche, puis « avant » au-dessus d'« après ».
#   BASE_DIR=/chemin/de/la/base tools/tour-film.sh [fletri|ravive…]   (par défaut : les deux)
#   Sortie : godot/tests/visual/out/tour/<scène>.mp4 (film) et <scène>.gif (aperçu réduit)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_DIR="${BASE_DIR:?BASE_DIR : copie de la base}"
OUT="$ROOT/godot/tests/visual/out/tour"
SCENES=("$@")
[ ${#SCENES[@]} -eq 0 ] && SCENES=(fletri ravive)
mkdir -p "$OUT"; touch "$ROOT/godot/tests/visual/out/.gdignore"
export LIBGL_ALWAYS_SOFTWARE=1
# Textes du jeu en français, quelle que soit la langue de la machine.
export TREE_LANG="${TREE_LANG:-fr}"
mkdir -p "$BASE_DIR/godot/tests/paysages"
cp "$ROOT/godot/tests/paysages/tour_film.gd" "$BASE_DIR/godot/tests/paysages/tour_film.gd"
[ -d "$BASE_DIR/godot/.godot" ] || "$BASE_DIR/tools/godot.sh" --headless --import >/dev/null 2>&1
[ -d "$ROOT/godot/.godot" ] || "$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1
shoot() {  # dépôt scène sortie
  rm -rf "$3"; mkdir -p "$3"
  XDG_DATA_HOME="$3.data" timeout -s KILL 1800 "$1/tools/godot.sh" --xvfb --fixed-fps 60 --resolution 960x540 --audio-driver Dummy \
    -s res://tests/paysages/tour_film.gd -- --scene="$2" --out="$3" 2>&1 | grep -E "SCRIPT ERROR|images dans" || true
}
for s in "${SCENES[@]}"; do
  shoot "$BASE_DIR" "$s" "$OUT/$s.avant" &
  shoot "$ROOT" "$s" "$OUT/$s.apres"
  wait
  ffmpeg -loglevel error -y -framerate 20 -i "$OUT/$s.avant/%03d.png" -framerate 20 -i "$OUT/$s.apres/%03d.png" \
    -filter_complex "[0:v][1:v]vstack=inputs=2,fps=10,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    -loop 0 "$OUT/$s.gif"
  ffmpeg -loglevel error -y -framerate 20 -i "$OUT/$s.avant/%03d.png" -framerate 20 -i "$OUT/$s.apres/%03d.png" \
    -filter_complex "[0:v][1:v]vstack=inputs=2" -c:v libx264 -pix_fmt yuv420p -crf 23 "$OUT/$s.mp4"
  echo "Film : $OUT/$s.gif ($(du -h "$OUT/$s.gif" | cut -f1)), $OUT/$s.mp4 ($(du -h "$OUT/$s.mp4" | cut -f1))"
done
