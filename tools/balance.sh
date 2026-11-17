#!/usr/bin/env bash
# Équilibrage des builds types de Ronce (godot/data/builds.json).
#
# Mode « builds » (par défaut) : le robot joue chaque build au niveau 20 sur plusieurs graines,
# puis compare les ennemis vaincus par minute. Échoue (code 1) si le meilleur build dépasse le
# moins bon de plus de 30 %.
#
#   tools/balance.sh                     # builds epines, fouet, saignement ; graines 1 2 3 ; 180 s au niveau 20
#   BUILDS="fouet" SEEDS="1" TIME=60 tools/balance.sh
#
# Mode « partie complète » (--run) : le robot part du niveau 1 avec chaque build et joue jusqu'au
# niveau 25 (ou TIME secondes, 4200 par défaut), en avançant dans la région de Ronce. Affiche la
# courbe (niveau, menace, temps pour tuer un Flétri, dégâts reçus, morts, minute par minute) et
# échoue si un niveau prend plus de deux fois la durée visée (data/difficulty.json), si un build
# meurt plus de trois fois avant le niveau 20 ou ne l'atteint pas, ou si les builds atteignent le
# niveau 20 avec plus de 30 % d'écart. Les journaux restent dans godot/autotest/balance-run/.
#
#   tools/balance.sh --run
#   BUILDS="fouet" SEEDS="2" tools/balance.sh --run
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILDS=${BUILDS:-"epines fouet saignement"}
LIMIT=${LIMIT:-0.30}
MODE=build
[[ "${1:-}" == "--run" ]] && MODE=run

"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1

if [[ $MODE == run ]]; then
  SEEDS=${SEEDS:-"1"}
  TIME=${TIME:-4200}
  OUT="$ROOT/godot/autotest/balance-run"
  rm -rf "$OUT"; mkdir -p "$OUT"
  for b in $BUILDS; do
    for s in $SEEDS; do
      "$ROOT/tools/godot.sh" --headless --fixed-fps 60 -- "--autotest=run:$b" "--build-time=$TIME" "--seed=$s" > "$OUT/$b.$s.log" 2>&1 &
    done
  done
  wait
  fail=0
  declare -A T20
  for b in $BUILDS; do
    for s in $SEEDS; do
      log="$OUT/$b.$s.log"
      end=$(grep '^RUNEND' "$log")
      [[ -n "$end" ]] || { echo "Pas de résultat pour $b (graine $s), voir $log"; exit 2; }
      echo
      echo "### $b, graine $s"
      echo
      echo "| Minute | Niveau | Menace | Flétri tué en (s) | Dégâts reçus | Vie max | Morts |"
      echo "| --- | --- | --- | --- | --- | --- | --- |"
      grep '^RUN ' "$log" | awk '{
        for (i = 3; i <= NF; i++) { split($i, kv, "="); v[kv[1]] = kv[2] }
        printf "| %s | %s | %s | %s | %s | %s | %s |\n", v["min"], v["niveau"], v["menace"], (v["ttk"] < 0 ? "–" : v["ttk"]), v["degats"], v["vie_max"], v["morts"]
      }'
      echo
      echo "$end" | sed "s/^RUNEND $b /Fin : /"
      # Durée de chaque niveau comparée à la cible (RUNLEVEL build niveau durée total cible).
      walls=$(grep '^RUNLEVEL' "$log" | awk '$3 < 25 && $4 > 2 * $6 { printf "niveau %d en %.0f s (cible %.0f s) ; ", $3, $4, $6 }')
      if [[ -n "$walls" ]]; then echo "MUR : $walls"; fail=1; fi
      t20=$(grep '^RUNLEVEL' "$log" | awk '$3 == 19 { print $5 }')
      if [[ -z "$t20" ]]; then echo "ÉCHEC : niveau 20 pas atteint"; fail=1; t20=0; fi
      d20=$(echo "$end" | sed -E 's/.*morts_avant_20=([0-9]+).*/\1/')
      if (( d20 > 3 )); then echo "ÉCHEC : $d20 morts avant le niveau 20 (limite 3)"; fail=1; fi
      T20[$b]=$(awk -v a="${T20[$b]:-0}" -v t="$t20" 'BEGIN{print a+t}')
    done
  done
  n=$(echo $SEEDS | wc -w)
  echo
  echo "| Build | Niveau 20 atteint en (min, moyenne sur $n graines) |"
  echo "| --- | --- |"
  best=0; worst=999999
  for b in $BUILDS; do
    avg=$(awk -v t="${T20[$b]}" -v n="$n" 'BEGIN{printf "%.1f", t/n/60}')
    echo "| $b | $avg |"
    best=$(awk -v a="$best" -v b="$avg" 'BEGIN{print (b>a)?b:a}')
    worst=$(awk -v a="$worst" -v b="$avg" 'BEGIN{print (b<a)?b:a}')
  done
  if awk -v b="$worst" 'BEGIN{exit (b > 0) ? 0 : 1}'; then
    gap=$(awk -v a="$best" -v b="$worst" 'BEGIN{printf "%.1f", (a/b-1)*100}')
    echo
    echo "Écart entre le build le plus lent et le plus rapide : $gap % (limite $(awk -v l="$LIMIT" 'BEGIN{print l*100}') %)"
    awk -v a="$best" -v b="$worst" -v l="$LIMIT" 'BEGIN{exit (a > b*(1+l)) ? 1 : 0}' || fail=1
  fi
  if (( fail )); then echo; echo "Équilibrage : ÉCHEC"; else echo; echo "Équilibrage : OK"; fi
  exit $fail
fi

SEEDS=${SEEDS:-"1 2 3"}
TIME=${TIME:-180}
LEVEL=${LEVEL:-20}
# Sans affichage (la logique est à pas fixe, donc identique) et toutes les parties en parallèle :
# une partie de 180 s se joue en moins d'une minute.
TMP=$(mktemp -d)
for b in $BUILDS; do
  for s in $SEEDS; do
    "$ROOT/tools/godot.sh" --headless --fixed-fps 60 -- "--autotest=build:$b" "--build-time=$TIME" "--build-level=$LEVEL" "--seed=$s" > "$TMP/$b.$s.log" 2>&1 &
  done
done
wait
declare -A TOTAL
for b in $BUILDS; do
  TOTAL[$b]=0
  for s in $SEEDS; do
    line=$(grep '^BUILD' "$TMP/$b.$s.log")
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
