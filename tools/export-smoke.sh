#!/usr/bin/env bash
# Lance un build Linux exporté sous xvfb : démarrage, 60 s de robot (--autotest), sortie propre.
# Échoue sur un code de sortie non nul, sur une erreur de script, ou si le robot ne va pas au bout.
#   tools/export-smoke.sh [build/linux/Seve.x86_64]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${1:-$ROOT/build/linux/Seve.x86_64}"
LOG="$(dirname "$BIN")/smoke.log"
# Dossier utilisateur isolé (XDG_DATA_HOME), comme tools/unit-tests.sh : ne touche pas à la partie du développeur.
export XDG_DATA_HOME="$(mktemp -d)"
timeout 240 xvfb-run -a -s "-screen 0 1600x900x24" "$BIN" --resolution 1600x900 -- --autotest >"$LOG" 2>&1
code=$?
fail=0
[ $code -eq 0 ] || { echo "ÉCHEC : code de sortie $code"; fail=1; }
grep -q "AUTOTEST fini" "$LOG" || { echo "ÉCHEC : le robot n'a pas fini"; fail=1; }
# Erreurs attendues (pilote audio absent sur la CI, texture de rendu logiciel, fuites à la sortie).
if grep -E "SCRIPT ERROR|Parse Error|Failed to load|Cannot open|Resource file not found" "$LOG"; then
  echo "ÉCHEC : erreurs de script ou de ressource"; fail=1
fi
grep -E "^ERROR" "$LOG" | grep -vE "status < 0|rp_texture|leaked at exit" && { echo "ÉCHEC : erreurs inattendues"; fail=1; }
[ $fail -eq 0 ] && echo "OK : build exporté démarré, 60 s de robot, sortie propre ($(grep -c AUTOTEST "$LOG") lignes AUTOTEST)"
exit $fail
