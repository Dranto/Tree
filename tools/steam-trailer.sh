#!/usr/bin/env bash
# Bande-annonce de la page Steam (jalon 12 H) : chaque plan est joué en direct par le vrai jeu
# (godot/tools/steam/vitrine.gd, --clip=NOM) et filmé par le Movie Maker de Godot, puis
# tools/steam-montage.py les monte avec ffmpeg (fondus, musique du jeu, bruitages des plans).
# Pas de voix ni de texte à lire : le nom du jeu au début, une ligne à la fin.
#   tools/steam-trailer.sh [--demo] [--lang=fr|en] [--out=DOSSIER]
# Sorties (lourdes, hors dépôt) : DOSSIER/bande-annonce[-demo]-<langue>.mp4 et .gif (court, pour la page).
# DOSSIER par défaut : /mnt/project-files/steam s'il existe, sinon steam/out.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO=0
LANG_CODE=fr
OUT=""
for a in "$@"; do
  case "$a" in
    --demo) DEMO=1 ;;
    --lang=*) LANG_CODE="${a#--lang=}" ;;
    --out=*) OUT="${a#--out=}" ;;
  esac
done
[ -z "$OUT" ] && { [ -d /mnt/project-files ] && OUT=/mnt/project-files/steam || OUT="$ROOT/steam/out"; }
mkdir -p "$OUT"
VITRINE_ARGS=()
if [ "$DEMO" = 1 ]; then
  # La démo elle-même (Demo.active) : l'arbre sous la ronce hors de Ronce, le monde fermé.
  VITRINE_ARGS=(--demo)
  CLIPS=(titre eveil combat arbre coeur boss fin_demo)
  NAME="bande-annonce-demo-$LANG_CODE"
else
  CLIPS=(titre eveil combat arbre coeur boss spore vent aube finale fin)
  NAME="bande-annonce-$LANG_CODE"
fi
WORK="${WORK:-$(mktemp -d)}"
mkdir -p "$WORK"
# Le Movie Maker filme à la taille de la fenêtre du projet (1600x900) : override.cfg, le temps des
# plans, la porte à 1920x1080 et monte la qualité des images (MJPEG).
OVERRIDE="$ROOT/godot/override.cfg"
[ -e "$OVERRIDE" ] && { echo "godot/override.cfg existe déjà : le retirer d'abord"; exit 1; }
cat > "$OVERRIDE" <<'CFG'
[display]
window/size/window_width_override=1920
window/size/window_height_override=1080
[editor]
movie_writer/mjpeg_quality=0.95
CFG
trap 'rm -f "$OVERRIDE"' EXIT
export LIBGL_ALWAYS_SOFTWARE=1
"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
: > "$WORK/plans.txt"
for c in "${CLIPS[@]}"; do
  if [ ! -s "$WORK/$c.avi" ] || [ -z "${REUSE:-}" ]; then
    echo "== Plan $c"
    TREE_LANG="$LANG_CODE" xvfb-run -a -s "-screen 0 1920x1080x24" "$ROOT/tools/godot.sh" --fixed-fps 30 \
      --resolution 1920x1080 --position 0,0 --write-movie "$WORK/$c.avi" \
      res://tools/steam/vitrine.tscn -- --clip="$c" "${VITRINE_ARGS[@]}" > "$WORK/$c.log" 2>&1 || true
    grep -E "SCRIPT ERROR" "$WORK/$c.log" | head -5 || true
  fi
  start=$(grep -oE "VITRINE debut [0-9]+" "$WORK/$c.log" | tail -1 | awk '{print $3}')
  [ -n "$start" ] || { echo "Plan $c : début introuvable (voir $WORK/$c.log)"; exit 1; }
  echo "$c $start" >> "$WORK/plans.txt"
done
python3 "$ROOT/tools/steam-montage.py" "$WORK" "$ROOT/godot/assets/music" "$OUT/$NAME"
echo "Bande-annonce : $OUT/$NAME.mp4"
