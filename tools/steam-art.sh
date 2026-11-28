#!/usr/bin/env bash
# Visuels de la page Steam (jalon 12 H), tous tirés du vrai jeu et dessinés par le code :
#   1. godot/tools/steam/vitrine.tscn met en scène le jeu en milieu de partie et prend
#      l'illustration 3840x2160 (sans interface), les portraits des boss (icônes des succès)
#      et les 8 captures 1920x1080 de la page ;
#      (et, rejouée avec « -- --cycle=2 » puis 3, la Flétrissure fanée des succès CYCLE_2/CYCLE_3) ;
#   2. godot/tools/steam/steam_art.tscn en tire les capsules, le logo, l'icône et les succès.
# Le nom du jeu vient de project.godot (Loc.game_name) : relancer ce script après un changement de nom.
#   tools/steam-art.sh [fr en]           (langues, « fr en » par défaut)
#   SHOTS=a,b tools/steam-art.sh fr      (seulement ces captures ; « SHOTS=- » : aucune)
#   DEMO=1 tools/steam-art.sh [fr en]    (captures de la page de la démo, Ronce seule)
# Sorties : steam/art/<langue>/ (capsules, logo, icône, succes/) et steam/captures/<langue>/ ;
# avec DEMO=1, seulement steam/captures-demo/<langue>/ (capsules et succès : ceux du jeu complet).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LANGS=("$@")
[ $# -eq 0 ] && LANGS=(fr en)
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export LIBGL_ALWAYS_SOFTWARE=1
"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
run() {   # run RESOLUTION args…
  local res="$1"; shift
  xvfb-run -a -s "-screen 0 ${res}x24" "$ROOT/tools/godot.sh" --audio-driver Dummy --fixed-fps 60 \
    --resolution "$res" --position 0,0 "$@" 2>&1 | grep -E "VITRINE|CAPSULE|SCRIPT ERROR|^ERROR" | grep -v "leaked at exit" || true
}
if [ "${DEMO:-0}" = 1 ]; then
  for lang in "${LANGS[@]}"; do
    echo "== démo $lang"
    mkdir -p "$ROOT/steam/captures-demo/$lang"
    args=(--out="$ROOT/steam/captures-demo/$lang" --demo)
    [ -n "${SHOTS:-}" ] && args+=(--shots="$SHOTS")
    TREE_LANG="$lang" run 1920x1080 res://tools/steam/vitrine.tscn -- "${args[@]}"
  done
  echo "Captures de la démo : $ROOT/steam/captures-demo"
  exit 0
fi
# L'illustration et les portraits ne dépendent pas de la langue (aucun texte).
run 3840x2160 res://tools/steam/vitrine.tscn -- --shots=illustration,succes --out="$WORK"
[ -f "$WORK/illustration.png" ] || { echo "Illustration absente"; exit 1; }
# Succès du New Game+ (CYCLE_2, CYCLE_3) : la Flétrissure dans le monde fané de ce cycle.
for n in 2 3; do
  run 3840x2160 res://tools/steam/vitrine.tscn -- --shots=succes_cycle --out="$WORK" --cycle=$n
  [ -f "$WORK/succes_CYCLE_$n.png" ] || { echo "Portrait du succès CYCLE_$n absent"; exit 1; }
done
for lang in "${LANGS[@]}"; do
  echo "== $lang"
  if [ "${SHOTS:-}" != "-" ]; then
    mkdir -p "$ROOT/steam/captures/$lang"
    args=(--out="$ROOT/steam/captures/$lang")
    [ -n "${SHOTS:-}" ] && args+=(--shots="$SHOTS")
    TREE_LANG="$lang" run 1920x1080 res://tools/steam/vitrine.tscn -- "${args[@]}"
  fi
  run 1600x900 res://tools/steam/steam_art.tscn -- --illustration="$WORK/illustration.png" \
    --out="$ROOT/steam/art/$lang" --lang="$lang"
done
echo "Visuels : $ROOT/steam/art, $ROOT/steam/captures"
