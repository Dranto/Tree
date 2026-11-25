#!/usr/bin/env bash
# Banc de lisibilité du « Bestiaire d'herbier » : planche avant / après et GIF (marche, annonce, frappe,
# coup reçu) de chaque sorte redessinée d'une région, puis le test de lisibilité de cette région.
#
#   tools/bestiaire.sh ronce                  # → /mnt/project-files/captures/refonte-persos/ronce/
#   tools/bestiaire.sh vent DOSSIER           # → DOSSIER (par défaut : godot/tests/bestiaire/out/<région>)
#   tools/bestiaire.sh                        # toutes les régions (commun, ronce, spore, vent, seve, aube, racine)
#
# Une sorte sans script scripts/creature_art/<région>/<id>.gd est listée, pas dessinée. Pour le test seul :
#   tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/bestiaire_test.gd
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGIONS=(commun ronce spore vent seve aube racine)
if [ $# -ge 1 ]; then REGIONS=("$1"); fi
BASE="/mnt/project-files/captures/refonte-persos"
export LIBGL_ALWAYS_SOFTWARE=1
"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
for region in "${REGIONS[@]}"; do
  if [ $# -ge 2 ]; then OUT="$(realpath -m "$2")"
  elif [ $# -eq 1 ] && [ -d "$BASE" ]; then OUT="$BASE/$region"
  else OUT="$ROOT/godot/tests/bestiaire/out/$region"; fi
  mkdir -p "$OUT"
  rm -rf "$OUT/gif_images"
  echo "== $region → $OUT"
  "$ROOT/tools/godot.sh" --xvfb --audio-driver Dummy --resolution 1600x900 -s res://tests/bestiaire/region.gd -- "$region" "$OUT" 2>&1 \
    | grep -E "SCRIPT ERROR|Parse Error|^Région|Rien à dessiner|sans script" -A2 || true
  if [ -d "$OUT/gif_images" ]; then
    ffmpeg -loglevel error -y -framerate 24 -i "$OUT/gif_images/%03d.png" \
      -vf "split[a][b];[a]palettegen=max_colors=256:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a" "$OUT/marche_annonce_${region}.gif"
    rm -rf "$OUT/gif_images"
  fi
  ls -la "$OUT"
done
echo "== Test de lisibilité"
"$ROOT/tools/godot.sh" --xvfb --audio-driver Dummy -s res://tests/bestiaire_test.gd 2>&1 | grep -E "ÉCHEC|OK :|sans script|Sortes :" || true
