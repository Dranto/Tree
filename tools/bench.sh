#!/usr/bin/env bash
# Garde-fou de performance : lance le banc de jeu (120 Flétris, 30 s, rendu logiciel) et échoue
# si le temps moyen par image dépasse le budget de plus de TOLERANCE (marge pour la variance de
# la machine). Voir docs/performances.md.
#   tools/bench.sh                  # budget par défaut
#   BUDGET_MS=20 tools/bench.sh     # autre budget
#   RUNS=3 tools/bench.sh           # garde la meilleure de 3 mesures (machines bruyantes)
#   SCENE=coeur tools/bench.sh      # banc des pics : siège du Cœur (aussi : boss)
#   P99_MS=33 tools/bench.sh        # budget du 99e centile (pics), vide : pas vérifié
#   SCENE=finale tools/bench.sh     # banc de la finale : arène sous la graine et colosse
#   REGIONS=six tools/bench.sh      # monde à six régions : ajoute les régions factices de tests/regions/
#                                   # (aujourd'hui Racine) à celles de data/regions/ ; une vraie région l'emporte
#                                   # (« cinq » : ancien nom, même banc)
#   BASE_DIR=../base tools/bench.sh # mesure en paires : alterne le banc de la base (une autre copie du
#                                   # dépôt, ex. develop) et celui-ci. Échoue seulement si ce banc dépasse
#                                   # la limite ET la base de plus de REGRESSION (8 % par défaut) : la
#                                   # vitesse de la machine de la CI varie de ±15 % d'un job à l'autre.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Budget du temps moyen par image (ms) sur la machine de référence, et marge tolérée.
BUDGET_MS="${BUDGET_MS:-26}"
TOLERANCE="${TOLERANCE:-0.15}"
RUNS="${RUNS:-1}"
SCENE="${SCENE:-}"
P99_MS="${P99_MS:-}"
REGIONS="${REGIONS:-}"
BASE_DIR="${BASE_DIR:-}"
REGRESSION="${REGRESSION:-0.08}"
SCENE_ARG=()
# La finale est le banc du boss, joué sous la graine (--region=finale).
if [ "$SCENE" = "finale" ]; then
  SCENE_ARG=(--bench-scene=boss --region=finale)
elif [ -n "$SCENE" ]; then
  SCENE_ARG=(--bench-scene="$SCENE")
fi
[ -n "$REGIONS" ] && SCENE_ARG+=(--regions=res://tests/regions/)
# Suffixe des fichiers de résultat.
TAG="${SCENE:+_$SCENE}${REGIONS:+_six}"
OUT="$ROOT/godot/autotest/bench"
mkdir -p "$OUT"
export LIBGL_ALWAYS_SOFTWARE=1
# L'import plante parfois sur la machine de la CI (segmentation, fréquent depuis le 20/11) : le
# jeu se lance alors sans ses ressources importées (polices nulles, erreurs de script). On réessaie.
for attempt in 1 2 3; do
  if "$ROOT/tools/godot.sh" --headless --import > "$OUT/import.log" 2>&1; then
    break
  fi
  echo "Import du projet : échec (essai $attempt), fin du journal :"
  tail -n 15 "$OUT/import.log"
done
if [ -n "$BASE_DIR" ]; then
  BASE_DIR="$(cd "$BASE_DIR" && pwd)"
  "$BASE_DIR/tools/godot.sh" --headless --import > "$OUT/import_base.log" 2>&1 || \
    "$BASE_DIR/tools/godot.sh" --headless --import > "$OUT/import_base.log" 2>&1 || true
fi
best=""
best_p99=""
base_best=""
for i in $(seq 1 "$RUNS"); do
  if [ -n "$BASE_DIR" ]; then
    "$BASE_DIR/tools/godot.sh" --xvfb --audio-driver Dummy -- --benchmark "${SCENE_ARG[@]}" 2>&1 | grep -E "BENCHMARK|SCRIPT ERROR" > "$OUT/banc${TAG}_base_$i.txt"
    bavg=$(sed -nE 's/.*moyen ([0-9.]+) ms.*/\1/p' "$OUT/banc${TAG}_base_$i.txt")
    echo "Base, mesure $i : ${bavg:-sans résultat} ms"
    if [ -n "$bavg" ] && { [ -z "$base_best" ] || awk -v a="$bavg" -v b="$base_best" 'BEGIN{exit !(a < b)}'; }; then base_best="$bavg"; fi
  fi
  "$ROOT/tools/godot.sh" --xvfb --audio-driver Dummy -- --benchmark "${SCENE_ARG[@]}" 2>&1 | grep -E "BENCHMARK|SCRIPT ERROR" > "$OUT/banc${TAG}_$i.txt"
  cat "$OUT/banc${TAG}_$i.txt"
  if grep -q "SCRIPT ERROR" "$OUT/banc${TAG}_$i.txt"; then
    echo "Erreur de script pendant le banc"
    exit 1
  fi
  avg=$(sed -nE 's/.*moyen ([0-9.]+) ms.*/\1/p' "$OUT/banc${TAG}_$i.txt")
  [ -z "$avg" ] && { echo "Banc sans résultat"; exit 1; }
  p99=$(sed -nE 's/.*99e centile ([0-9.]+) ms.*/\1/p' "$OUT/banc${TAG}_$i.txt")
  if [ -z "$best" ] || awk -v a="$avg" -v b="$best" 'BEGIN{exit !(a < b)}'; then best="$avg"; fi
  if [ -z "$best_p99" ] || awk -v a="$p99" -v b="$best_p99" 'BEGIN{exit !(a < b)}'; then best_p99="$p99"; fi
done
limit=$(awk -v b="$BUDGET_MS" -v t="$TOLERANCE" 'BEGIN{printf "%.2f", b * (1 + t)}')
echo "Temps moyen par image : ${best} ms (budget ${BUDGET_MS} ms, limite ${limit} ms)"
if awk -v a="$best" -v l="$limit" 'BEGIN{exit !(a > l)}'; then
  if [ -n "$base_best" ]; then
    blimit=$(awk -v b="$base_best" -v r="$REGRESSION" 'BEGIN{printf "%.2f", b * (1 + r)}')
    echo "Base mesurée sur la même machine : ${base_best} ms (au-delà de ${blimit} ms : régression)"
    if awk -v a="$best" -v l="$blimit" 'BEGIN{exit !(a > l)}'; then
      echo "ÉCHEC : le jeu dépasse son budget et ralentit par rapport à la base (voir docs/performances.md)"
      exit 1
    fi
    echo "AVERTISSEMENT : au-dessus de la limite, mais pas plus lent que la base sur cette machine (machine lente)"
    echo "OK : pas de régression"
    exit 0
  else
    echo "ÉCHEC : le jeu dépasse son budget de temps par image (voir docs/performances.md)"
    exit 1
  fi
elif [ -n "$base_best" ]; then
  echo "Base mesurée sur la même machine : ${base_best} ms"
fi
if [ -n "$P99_MS" ]; then
  plimit=$(awk -v b="$P99_MS" -v t="$TOLERANCE" 'BEGIN{printf "%.2f", b * (1 + t)}')
  echo "99e centile : ${best_p99} ms (budget ${P99_MS} ms, limite ${plimit} ms)"
  if awk -v a="$best_p99" -v l="$plimit" 'BEGIN{exit !(a > l)}'; then
    echo "ÉCHEC : les pics dépassent leur budget (voir docs/performances.md)"
    exit 1
  fi
fi
echo "OK : dans le budget"
