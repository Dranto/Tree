#!/usr/bin/env bash
# Lassitude des bruitages : le robot joue un build (Aube + Vent par défaut) deux fois sur la même graine, sans les
# limites de sfx.gd (« avant », -- --sfx-calm=0) puis avec, et compare les journaux de Sfx (tools/sons-fatigue.py) :
# sons demandés et joués par seconde, voix actives, répétitions exactes. Rend aussi le mélange des bruitages
# (sans musique) d'un extrait de 30 s en .ogg, pour l'écoute.
#
#   tools/sons-fatigue.sh                       # build rayon+lames, 120 s au niveau 20, graine 1
#   BUILD=rayon+tornade SEED=2 TIME=180 tools/sons-fatigue.sh
#   OUT=/tmp/sons tools/sons-fatigue.sh         # dossier de sortie (défaut : godot/autotest/sons-fatigue)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD=${BUILD:-rayon+lames}
SEED=${SEED:-1}
TIME=${TIME:-120}
OUT=${OUT:-$ROOT/godot/autotest/sons-fatigue}
mkdir -p "$OUT"
"$ROOT/tools/import.sh"
for m in avant apres; do
  extra=()
  [ "$m" = avant ] && extra=(--sfx-calm=0)
  timeout 1500 "$ROOT/tools/godot.sh" --headless --fixed-fps 60 -- "--autotest=build:$BUILD" "--build-time=$TIME" \
    "--seed=$SEED" "--sfx-log=$OUT/$m.csv" "${extra[@]}" > "$OUT/$m.log" 2>&1 &
done
wait
grep -h '^BUILD' "$OUT/avant.log" "$OUT/apres.log" || true
python3 "$ROOT/tools/sons-fatigue.py" "$OUT/avant.csv" "$OUT/apres.csv" --mix "$OUT"
