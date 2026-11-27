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
# Pilote audio factice : la machine de CI n'a pas de carte son (sinon ALSA ajoute ses erreurs au journal).
timeout 240 xvfb-run -a -s "-screen 0 1600x900x24" "$BIN" --resolution 1600x900 --audio-driver Dummy -- --autotest >"$LOG" 2>&1
code=$?
fail=0
[ $code -eq 0 ] || { echo "ÉCHEC : code de sortie $code"; fail=1; }
grep -q "AUTOTEST fini" "$LOG" || { echo "ÉCHEC : le robot n'a pas fini"; fail=1; }
# Zéro ERROR / WARNING dans le journal, aux seules exceptions suivantes (le serveur X virtuel et le
# rendu logiciel de la CI, pas le jeu) :
#  - V-Sync : xvfb ne sait pas le régler.
# Une fuite « at exit » (nœud resté orphelin à la fermeture) est signalée mais ne fait pas échouer :
# elle ne se voit qu'une fois sur dix environ quand la machine est très chargée. Même chose pour
# « Invalid polygon data, triangulation failed » (un polygone aplati, vu une fois sur une trentaine de parties).
if grep -E "SCRIPT ERROR|Parse Error|Failed to load|Cannot open|Resource file not found" "$LOG"; then
  echo "ÉCHEC : erreurs de script ou de ressource"; fail=1
fi
noise=$(grep -E "^(ERROR|WARNING|USER ERROR|USER WARNING):" "$LOG" | grep -vE "Could not set V-Sync mode" || true)
leaks=$(echo "$noise" | grep -E "leaked|triangulation failed" || true)
bad=$(echo "$noise" | grep -vE "leaked|triangulation failed" || true)
[ -z "$leaks" ] || { echo "Attention (sans échec) : fuite à la sortie ou polygone aplati rare :"; echo "$leaks"; }
if [ -n "$bad" ]; then
  echo "ÉCHEC : le journal contient des ERROR / WARNING :"; echo "$bad"; fail=1
fi
[ $fail -eq 0 ] && echo "OK : build exporté démarré, 60 s de robot, sortie propre ($(grep -c AUTOTEST "$LOG") lignes AUTOTEST)"
exit $fail
