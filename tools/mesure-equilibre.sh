#!/usr/bin/env bash
# Mesure d'équilibrage (jalon 14.5, lot B) : le robot d'aventure joue une partie complète avec la sonde
# tests/balance_probe.gd (aucune valeur de jeu n'est changée). Chaque passage a son propre dossier de
# données (XDG_DATA_HOME) : plusieurs passages peuvent tourner en même temps sans se marcher dessus.
# Les journaux restent dans godot/autotest/mesure/ ; tools/mesure-equilibre.py les met en tableaux.
#
#   tools/mesure-equilibre.sh                       # variantes 0 à 3, graine 1, en parallèle
#   VARIANTES="1 2" SEEDS="1 2" tools/mesure-equilibre.sh
#   tools/mesure-equilibre.sh --cycle=2             # arguments passés au robot (voir tools/aventure.sh)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEEDS=${SEEDS:-"1"}
VARIANTES=${VARIANTES:-"0 1 2 3"}
LIMIT=${LIMIT:-21600}
OUT="${OUT:-$ROOT/godot/autotest/mesure}"
mkdir -p "$OUT"
"$ROOT/tools/import.sh"
for s in $SEEDS; do
  for v in $VARIANTES; do
    XDG_DATA_HOME="$OUT/donnees-$s-$v" timeout "$LIMIT" "$ROOT/tools/godot.sh" --headless --fixed-fps 60 \
      -s res://tests/aventure_test.gd -- "--autotest=aventure" "--seed=$s" "--variante=$v" --continue-on-block "$@" \
      > "$OUT/graine-$s-variante-$v.log" 2>&1 &
  done
done
wait
for f in "$OUT"/graine-*.log; do
  echo "=== $(basename "$f") : $(grep '^RÉSULTAT' "$f" || echo 'pas de fin (plantage ou délai dépassé)')"
done
