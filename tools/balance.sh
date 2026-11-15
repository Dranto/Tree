#!/usr/bin/env bash
# Équilibrage des builds types de Ronce (godot/data/builds.json).
# Le robot joue chaque build sur plusieurs graines, puis compare les ennemis vaincus par minute.
# Échoue (code 1) si le meilleur build dépasse le moins bon de plus de 30 %.
#
#   tools/balance.sh                     # builds epines, fouet, saignement ; graines 1 2 3 ; 180 s depuis le niveau 20
#   BUILDS="fouet" SEEDS="1" TIME=60 tools/balance.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILDS=${BUILDS:-"epines fouet saignement"}
SEEDS=${SEEDS:-"1 2 3"}
TIME=${TIME:-180}
LEVEL=${LEVEL:-20}
LIMIT=${LIMIT:-0.30}
export LIBGL_ALWAYS_SOFTWARE=1

"$ROOT/tools/godot.sh" --headless --editor --quit >/dev/null 2>&1
declare -A TOTAL
for b in $BUILDS; do
  TOTAL[$b]=0
  for s in $SEEDS; do
    line=$("$ROOT/tools/godot.sh" --xvfb --fixed-fps 60 -- "--autotest=build:$b" "--build-time=$TIME" "--build-level=$LEVEL" "--seed=$s" 2>&1 | grep '^BUILD' )
    echo "$line" | sed "s/^BUILD $b :/[$b, graine $s]/"
    rate=$(echo "$line" | head -1 | sed -E 's/.* ([0-9.]+) tués\/min.*/\1/')
    [[ "$rate" =~ ^[0-9.]+$ ]] || { echo "Pas de résultat pour $b (graine $s)"; exit 2; }
    TOTAL[$b]=$(awk -v a="${TOTAL[$b]}" -v r="$rate" 'BEGIN{print a+r}')
  done
done

n=$(echo $SEEDS | wc -w)
echo
echo "| Build | Tués par minute (moyenne sur $n graines) |"
echo "| --- | --- |"
best=0; worst=999999
for b in $BUILDS; do
  avg=$(awk -v t="${TOTAL[$b]}" -v n="$n" 'BEGIN{printf "%.1f", t/n}')
  echo "| $b | $avg |"
  best=$(awk -v a="$best" -v b="$avg" 'BEGIN{print (b>a)?b:a}')
  worst=$(awk -v a="$worst" -v b="$avg" 'BEGIN{print (b<a)?b:a}')
done
gap=$(awk -v a="$best" -v b="$worst" 'BEGIN{printf "%.1f", (a/b-1)*100}')
echo
echo "Écart entre le meilleur et le moins bon build : $gap % (limite $(awk -v l="$LIMIT" 'BEGIN{print l*100}') %)"
awk -v a="$best" -v b="$worst" -v l="$LIMIT" 'BEGIN{exit (a > b*(1+l)) ? 1 : 0}'
