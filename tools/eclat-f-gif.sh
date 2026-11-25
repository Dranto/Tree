#!/usr/bin/env bash
# GIF avant/après du jalon Éclat, tâche F (un monde qui réagit) : joue chaque scène sous xvfb, image par
# image (tests/eclat_f_gif.gd), sur la base (BASE_DIR, une copie de develop) et sur cette branche,
# puis assemble « avant | après » côte à côte (ffmpeg).
#   BASE_DIR=/chemin/de/develop tools/eclat-f-gif.sh [scène…]   (par défaut : toutes)
#   Sortie : godot/tests/visual/out/eclat-f/<scène>.gif
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_DIR="${BASE_DIR:?BASE_DIR : copie de develop}"
OUT="$ROOT/godot/tests/visual/out/eclat-f"
SCENES=("$@")
[ ${#SCENES[@]} -eq 0 ] && SCENES=(herbe combat repos niveau greffe sanctuaire)
mkdir -p "$OUT"; touch "$ROOT/godot/tests/visual/out/.gdignore"
export LIBGL_ALWAYS_SOFTWARE=1
cp "$ROOT/godot/tests/eclat_f_gif.gd" "$BASE_DIR/godot/tests/eclat_f_gif.gd"
[ -d "$BASE_DIR/godot/.godot" ] || "$BASE_DIR/tools/godot.sh" --headless --import >/dev/null 2>&1
[ -d "$ROOT/godot/.godot" ] || "$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1
shoot() {  # dépôt scène sortie
  rm -rf "$3"; mkdir -p "$3"
  XDG_DATA_HOME="$3.data" "$1/tools/godot.sh" --xvfb --fixed-fps 60 --resolution 960x540 --audio-driver Dummy \
    -s res://tests/eclat_f_gif.gd -- --scene="$2" --out="$3" 2>&1 | grep -E "SCRIPT ERROR|images dans" || true
}
for s in "${SCENES[@]}"; do
  shoot "$BASE_DIR" "$s" "$OUT/$s.avant" &
  shoot "$ROOT" "$s" "$OUT/$s.apres"
  wait
  fps=20; [ "$s" = repos ] && fps=10
  # Gros plan sur le héros (sauf la marche et le sanctuaire, qui ont besoin de place).
  crop="crop=400:225:280:157,"; case "$s" in herbe|sanctuaire) crop="";; esac
  ffmpeg -loglevel error -y -framerate $fps -i "$OUT/$s.avant/%03d.png" -framerate $fps -i "$OUT/$s.apres/%03d.png" \
    -filter_complex "[0:v]${crop}null[l];[1:v]${crop}null[r];[l][r]hstack=inputs=2,scale=1100:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    -loop 0 "$OUT/$s.gif"
  echo "GIF : $OUT/$s.gif ($(du -h "$OUT/$s.gif" | cut -f1))"
done
