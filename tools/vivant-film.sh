#!/usr/bin/env bash
# GIF du monde vivant (refonte du monde, vague 1 V) : joue chaque scène sous xvfb, image par image
# (tests/vivant_film.gd), sur la base (BASE_DIR, une copie de develop) et sur cette branche, puis
# assemble « avant | après » côte à côte (ffmpeg). La scène « vivant » (tout à la suite) n'est faite que
# sur la branche : c'est le GIF « monde vivant ».
#   BASE_DIR=/chemin/de/develop tools/vivant-film.sh [scène…]   (par défaut : toutes)
#   Sortie : godot/tests/visual/out/vivant/<scène>.gif
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_DIR="${BASE_DIR:?BASE_DIR : copie de develop}"
OUT="$ROOT/godot/tests/visual/out/vivant"
SCENES=("$@")
[ ${#SCENES[@]} -eq 0 ] && SCENES=(buisson charge coup faune marais vivant)
mkdir -p "$OUT"; touch "$ROOT/godot/tests/visual/out/.gdignore"
export LIBGL_ALWAYS_SOFTWARE=1
cp "$ROOT/godot/tests/vivant_film.gd" "$BASE_DIR/godot/tests/vivant_film.gd"
[ -d "$BASE_DIR/godot/.godot" ] || "$BASE_DIR/tools/godot.sh" --headless --import >/dev/null 2>&1
[ -d "$ROOT/godot/.godot" ] || "$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1
shoot() {  # dépôt scène sortie
  rm -rf "$3"; mkdir -p "$3"
  XDG_DATA_HOME="$3.data" timeout -s KILL 400 "$1/tools/godot.sh" --xvfb --fixed-fps 60 --resolution 1600x900 --audio-driver Dummy \
    -s res://tests/vivant_film.gd -- --scene="$2" --out="$3" 2>&1 | grep -E "SCRIPT ERROR|images dans" || true
}
# Gros plan sur le héros (la moitié de l'écran, au centre).
CROP="crop=800:450:400:225"
for s in "${SCENES[@]}"; do
  if [ "$s" = vivant ]; then
    shoot "$ROOT" "$s" "$OUT/$s.apres"
    ffmpeg -loglevel error -y -framerate 20 -i "$OUT/$s.apres/%03d.png" \
      -filter_complex "[0:v]${CROP},scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=160[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
      -loop 0 "$OUT/monde_vivant.gif"
    echo "GIF : $OUT/monde_vivant.gif ($(du -h "$OUT/monde_vivant.gif" | cut -f1))"
    continue
  fi
  shoot "$BASE_DIR" "$s" "$OUT/$s.avant" &
  shoot "$ROOT" "$s" "$OUT/$s.apres"
  wait
  ffmpeg -loglevel error -y -framerate 20 -i "$OUT/$s.avant/%03d.png" -framerate 20 -i "$OUT/$s.apres/%03d.png" \
    -filter_complex "[0:v]${CROP}[l];[1:v]${CROP}[r];[l][r]hstack=inputs=2,scale=1200:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=160[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    -loop 0 "$OUT/${s}_avant_apres.gif"
  echo "GIF : $OUT/${s}_avant_apres.gif ($(du -h "$OUT/${s}_avant_apres.gif" | cut -f1))"
done
