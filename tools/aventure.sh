#!/usr/bin/env bash
# Robot d'aventure (godot/tests/aventure_test.gd) : une nouvelle partie jouée de bout en bout, les
# régions l'une après l'autre (de la plus facile à la plus dure), chaque Cœur assiégé, chaque boss
# battu, puis la finale quand le jeu en a une. Sauvegarde puis rechargement à chaque étape principale
# et à chaque région purifiée. Échoue (code 1) sur un blocage (objectif inatteignable, boss qui ne
# meurt pas, joueur coincé), une reprise qui ne retrouve pas la partie, un état incohérent ou une
# erreur de script. Journaux dans godot/autotest/aventure/ (un par passage, résumé en fin de journal).
#
# Trop long pour la CI (environ 20 à 40 minutes de calcul par passage) : à lancer à la main.
#
#   tools/aventure.sh                       # deux passages en parallèle : variante 0 et variante 1 (graine 1)
#   VARIANTES="0 1 2" tools/aventure.sh     # d'autres variantes (le N-ième build de chaque branche)
#   SEEDS="1 2" tools/aventure.sh           # d'autres graines (chaque graine × chaque variante)
#   tools/aventure.sh --jusqua=spore        # s'arrête après une région (essai rapide)
#   tools/aventure.sh --continue-on-block   # force une région bloquée pour voir la suite
#   tools/aventure.sh --ordre=ronce,vent,spore --autotest=aventure:epines   # ordre et build de départ
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEEDS=${SEEDS:-"1"}
VARIANTES=${VARIANTES:-"0 1"}
OUT="$ROOT/godot/autotest/aventure"
rm -rf "$OUT"; mkdir -p "$OUT"

"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1

extra=("$@")
has_auto=0
for a in "${extra[@]}"; do [[ "$a" == --autotest=aventure* ]] && has_auto=1; done
[[ $has_auto == 1 ]] || extra+=("--autotest=aventure")

for s in $SEEDS; do
  for v in $VARIANTES; do
    timeout 7200 "$ROOT/tools/godot.sh" --headless --fixed-fps 60 -s res://tests/aventure_test.gd -- \
      "--seed=$s" "--variante=$v" "${extra[@]}" > "$OUT/graine-$s-variante-$v.log" 2>&1 &
  done
done
wait

fail=0
for s in $SEEDS; do
  for v in $VARIANTES; do
    log="$OUT/graine-$s-variante-$v.log"
    res=$(grep '^RÉSULTAT' "$log" || echo "RÉSULTAT : pas de fin (plantage ou délai dépassé)")
    echo "=== Graine $s, variante $v : ${res#RÉSULTAT : }"
    sed -n '/^=== AVENTURE : résumé/,/^AVENTURE graine/p' "$log" | sed 's/^/    /'
    grep -E 'ÉCHEC|BLOCAGE|DÉFAUT' "$log" | sort -u | sed 's/^/    /'
    errors=$(grep -c 'SCRIPT ERROR' "$log" || true)
    if [[ "$errors" != "0" ]]; then
      echo "    $errors erreur(s) de script :"
      grep -A1 'SCRIPT ERROR' "$log" | head -20 | sed 's/^/    /'
      fail=1
    fi
    [[ "$res" == *"tout est bon"* ]] || fail=1
  done
done
exit $fail
