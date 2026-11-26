#!/usr/bin/env bash
# GIF avant/après des arènes de boss (refonte du monde, vague 3 A) : joue chaque scène sous xvfb, image par image
# (godot/tests/paysages/arenes_film.gd), sur la base (BASE_DIR, une copie de develop) et sur cette branche,
# puis assemble « avant | après » côte à côte (ffmpeg).
#   BASE_DIR=/chemin/de/develop tools/arenes-film.sh [scène…]   (par défaut : toutes)
#   Sortie : godot/tests/visual/out/arenes/<scène>.gif
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_DIR="${BASE_DIR:?BASE_DIR : copie de develop}"
OUT="$ROOT/godot/tests/visual/out/arenes"
SCENES=("$@")
[ ${#SCENES[@]} -eq 0 ] && SCENES=(ronce spore)
mkdir -p "$OUT"; touch "$ROOT/godot/tests/visual/out/.gdignore"
export LIBGL_ALWAYS_SOFTWARE=1
mkdir -p "$BASE_DIR/godot/tests/paysages"
cp "$ROOT/godot/tests/paysages/arenes_film.gd" "$BASE_DIR/godot/tests/paysages/arenes_film.gd"
[ -d "$BASE_DIR/godot/.godot" ] || "$BASE_DIR/tools/godot.sh" --headless --import >/dev/null 2>&1
[ -d "$ROOT/godot/.godot" ] || "$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1
shoot() {  # dépôt scène sortie
  rm -rf "$3"; mkdir -p "$3"
  XDG_DATA_HOME="$3.data" timeout -s KILL 600 "$1/tools/godot.sh" --xvfb --fixed-fps 60 --resolution 960x540 --audio-driver Dummy \
    -s res://tests/paysages/arenes_film.gd -- --scene="$2" --out="$3" 2>&1 | grep -E "SCRIPT ERROR|images dans" || true
}
for s in "${SCENES[@]}"; do
  shoot "$BASE_DIR" "$s" "$OUT/$s.avant" &
  shoot "$ROOT" "$s" "$OUT/$s.apres"
  wait
  ffmpeg -loglevel error -y -framerate 20 -i "$OUT/$s.avant/%03d.png" -framerate 20 -i "$OUT/$s.apres/%03d.png" \
    -filter_complex "[0:v]crop=800:480:80:30[l];[1:v]crop=800:480:80:30[r];[l][r]hstack=inputs=2,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    -loop 0 "$OUT/$s.gif"
  echo "GIF : $OUT/$s.gif ($(du -h "$OUT/$s.gif" | cut -f1))"
done
