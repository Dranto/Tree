#!/usr/bin/env bash
# GIF des événements du monde (refonte du monde, vague 2 E) : joue chaque scène sous xvfb, image par image
# (tests/evenements_film.gd), sur la base (BASE_DIR, une copie de develop) et sur cette branche, puis
# assemble « avant | après » l'un au-dessus de l'autre (ffmpeg).
#   BASE_DIR=/chemin/de/develop [REGION=ronce] tools/evenements-film.sh [scène…]   (par défaut : toutes)
#   Scènes : coeur, sanctuaire, autel, niveau, elite.
#   Sortie : godot/tests/visual/out/evenements/<scène>_avant_apres.gif (ou OUT=dossier)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_DIR="${BASE_DIR:?BASE_DIR : copie de develop}"
REGION="${REGION:-ronce}"
OUT="${OUT:-$ROOT/godot/tests/visual/out/evenements}"
SCENES=("$@")
[ ${#SCENES[@]} -eq 0 ] && SCENES=(coeur sanctuaire autel niveau elite)
mkdir -p "$OUT"; mkdir -p "$ROOT/godot/tests/visual/out"; touch "$ROOT/godot/tests/visual/out/.gdignore"
export LIBGL_ALWAYS_SOFTWARE=1
cp "$ROOT/godot/tests/evenements_film.gd" "$BASE_DIR/godot/tests/evenements_film.gd"
[ -d "$BASE_DIR/godot/.godot" ] || "$BASE_DIR/tools/godot.sh" --headless --import >/dev/null 2>&1
[ -d "$ROOT/godot/.godot" ] || "$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1
shoot() {  # dépôt scène sortie
  rm -rf "$3" "$3.data"; mkdir -p "$3"
  XDG_DATA_HOME="$3.data" timeout -s KILL 600 "$1/tools/godot.sh" --xvfb --fixed-fps 60 --resolution 1600x900 --audio-driver Dummy \
    -s res://tests/evenements_film.gd -- --scene="$2" --region="$REGION" --out="$3" 2>&1 | grep -E "SCRIPT ERROR|SHADER ERROR|images dans" || true
}
for s in "${SCENES[@]}"; do
  # Le Cœur : tout l'écran (la vague va loin) ; les autres : gros plan autour du héros.
  CROP="crop=1200:675:200:112"
  [ "$s" = coeur ] && CROP="crop=1600:900:0:0"
  shoot "$BASE_DIR" "$s" "$OUT/$s.avant" &
  shoot "$ROOT" "$s" "$OUT/$s.apres"
  wait
  ffmpeg -loglevel error -y -framerate 20 -i "$OUT/$s.avant/%03d.png" -framerate 20 -i "$OUT/$s.apres/%03d.png" \
    -filter_complex "[0:v]${CROP},scale=720:-2:flags=lanczos[l];[1:v]${CROP},scale=720:-2:flags=lanczos[r];[l][r]hstack=inputs=2,split[a][b];[a]palettegen=max_colors=160[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    -loop 0 "$OUT/${REGION}_${s}_avant_apres.gif"
  echo "GIF : $OUT/${REGION}_${s}_avant_apres.gif ($(du -h "$OUT/${REGION}_${s}_avant_apres.gif" | cut -f1))"
done
