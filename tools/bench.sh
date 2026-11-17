#!/usr/bin/env bash
# Garde-fou de performance : lance le banc de jeu (120 Flétris, 30 s, rendu logiciel) et échoue
# si le temps moyen par image dépasse le budget de plus de TOLERANCE (marge pour la variance de
# la machine). Voir docs/performances.md.
#   tools/bench.sh                  # budget par défaut
#   BUDGET_MS=20 tools/bench.sh     # autre budget
#   RUNS=3 tools/bench.sh           # garde la meilleure de 3 mesures (machines bruyantes)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Budget du temps moyen par image (ms) sur la machine de référence, et marge tolérée.
BUDGET_MS="${BUDGET_MS:-25}"
TOLERANCE="${TOLERANCE:-0.15}"
RUNS="${RUNS:-1}"
OUT="$ROOT/godot/autotest/bench"
mkdir -p "$OUT"
export LIBGL_ALWAYS_SOFTWARE=1
"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
best=""
for i in $(seq 1 "$RUNS"); do
  "$ROOT/tools/godot.sh" --xvfb --audio-driver Dummy -- --benchmark 2>&1 | grep -E "BENCHMARK|SCRIPT ERROR" > "$OUT/banc_$i.txt"
  cat "$OUT/banc_$i.txt"
  if grep -q "SCRIPT ERROR" "$OUT/banc_$i.txt"; then
    echo "Erreur de script pendant le banc"
    exit 1
  fi
  avg=$(sed -nE 's/.*moyen ([0-9.]+) ms.*/\1/p' "$OUT/banc_$i.txt")
  [ -z "$avg" ] && { echo "Banc sans résultat"; exit 1; }
  if [ -z "$best" ] || awk -v a="$avg" -v b="$best" 'BEGIN{exit !(a < b)}'; then best="$avg"; fi
done
limit=$(awk -v b="$BUDGET_MS" -v t="$TOLERANCE" 'BEGIN{printf "%.2f", b * (1 + t)}')
echo "Temps moyen par image : ${best} ms (budget ${BUDGET_MS} ms, limite ${limit} ms)"
if awk -v a="$best" -v l="$limit" 'BEGIN{exit !(a > l)}'; then
  echo "ÉCHEC : le jeu dépasse son budget de temps par image (voir docs/performances.md)"
  exit 1
fi
echo "OK : dans le budget"
