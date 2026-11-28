#!/usr/bin/env bash
# Banc des boss exaltés (jalon 14 R) : le robot des boss (« -- --autotest=boss ») joue chacun des sept
# boss au cycle 1 puis au cycle 2 (« -- --cycle=2 ») avec le même build de test, et le tableau donne
# l'issue, la durée, la vie restante du joueur et la dernière phase atteinte (4 = phase exaltée ; la
# Flétrissure compte l'Exaltation comme sa phase 4). Les écarts sont notés, jamais réglés.
#
#   tools/boss-exaltes.sh                    # les sept boss, cycles 1 et 2 (quelques minutes)
#   REGIONS="ronce spore" tools/boss-exaltes.sh
#   CYCLES="2" tools/boss-exaltes.sh         # seulement le cycle 2
#   JOBS=4 tools/boss-exaltes.sh             # combats en parallèle (2 par défaut)
# Journaux dans godot/autotest/boss-exaltes/. Code de sortie 1 si un combat ne se termine pas.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGIONS=${REGIONS:-"ronce spore vent seve aube racine finale"}
CYCLES=${CYCLES:-"1 2"}
JOBS=${JOBS:-2}
LIMIT=${LIMIT:-900}
OUT="$ROOT/godot/autotest/boss-exaltes"
rm -rf "$OUT"; mkdir -p "$OUT"
"$ROOT/tools/import.sh"

run() {
  local r=$1 c=$2
  XDG_DATA_HOME="$OUT/xdg-$r-$c" timeout "$LIMIT" "$ROOT/tools/godot.sh" --headless --fixed-fps 60 -- \
    --autotest=boss "--region=$r" "--cycle=$c" > "$OUT/$r-cycle$c.log" 2>&1
}
for r in $REGIONS; do
  for c in $CYCLES; do
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 1; done
    run "$r" "$c" &
  done
done
wait

fail=0
printf '%-8s %-6s %-9s %-8s %-7s %s\n' région cycle issue durée joueur "phases vues"
for r in $REGIONS; do
  for c in $CYCLES; do
    log="$OUT/$r-cycle$c.log"
    res=$(grep -E '^AUTOTEST boss : (victoire|défaite|ÉCHEC|le combat)' "$log" | tail -n 1)
    phases=$(grep -oE 'phase [0-9]+' "$log" | sort -u | tr -d '\n' | sed 's/phase /p/g')
    issue=$(echo "$res" | grep -oE 'victoire|défaite|ÉCHEC|le combat' | head -n1)
    dur=$(echo "$res" | grep -oE '[0-9]+(\.[0-9]+)? s' | head -n1)
    hp=$(echo "$res" | grep -oE 'vie du joueur [0-9]+' | grep -oE '[0-9]+')
    [ -z "$issue" ] && { issue="PAS DE FIN"; fail=1; }
    errors=$(grep -c 'SCRIPT ERROR' "$log" || true)
    [ "$errors" != "0" ] && { issue="$issue+ERR"; fail=1; }
    printf '%-8s %-6s %-9s %-8s %-7s %s\n' "$r" "$c" "$issue" "${dur:--}" "${hp:--}" "$phases"
  done
done
exit $fail
