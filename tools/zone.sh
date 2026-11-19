#!/usr/bin/env bash
# Robot « zone complète » (godot/tests/zone_test.gd) : une nouvelle partie jouée jusqu'à la
# Mère-Ronce et la fin de la tranche, avec sauvegardes, reprises et morts en route, sur plusieurs
# graines en parallèle, sans affichage. Échoue (code 1) si une graine échoue, bloque ou affiche
# une erreur de script. Journaux dans godot/autotest/zone/.
#
#   tools/zone.sh               # graines 1 à 5, région de Ronce
#   SEEDS="3" tools/zone.sh
#   tools/zone.sh --region=spore   # une autre région (data/regions/<id>.json), jouée de la même façon
#   ZONE_BUILD=aurore tools/zone.sh --region=aube   # un autre build de builds.json
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEEDS=${SEEDS:-"1 2 3 4 5"}
OUT="$ROOT/godot/autotest/zone"
rm -rf "$OUT"; mkdir -p "$OUT"

"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1

for s in $SEEDS; do
  timeout 1800 "$ROOT/tools/godot.sh" --headless --fixed-fps 60 -s res://tests/zone_test.gd -- "--seed=$s" "$@" > "$OUT/graine-$s.log" 2>&1 &
done
wait

fail=0
for s in $SEEDS; do
  log="$OUT/graine-$s.log"
  res=$(grep '^RÉSULTAT' "$log" || echo "RÉSULTAT : pas de fin (plantage ou délai dépassé)")
  bilan=$(grep '^ZONE graine .* de jeu' "$log" || true)
  errors=$(grep -c 'SCRIPT ERROR' "$log" || true)
  echo "Graine $s : ${res#RÉSULTAT : }${bilan:+ ; ${bilan#ZONE graine $s : }}"
  grep -E 'ÉCHEC|DÉFAUT' "$log" | sed 's/^/    /'
  if [[ "$errors" != "0" ]]; then
    echo "    $errors erreur(s) de script :"
    grep -A1 'SCRIPT ERROR' "$log" | head -20 | sed 's/^/    /'
    fail=1
  fi
  [[ "$res" == *"tout est bon"* ]] || fail=1
done
exit $fail
