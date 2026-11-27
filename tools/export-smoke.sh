#!/usr/bin/env bash
# Lance un build Linux exporté sous xvfb : démarrage, 60 s de robot (--autotest), sortie propre.
# Échoue sur un code de sortie non nul, sur une erreur de script, ou si le robot ne va pas au bout.
#   tools/export-smoke.sh [build/linux/Seve.x86_64]
# Avec GodotSteam à côté du binaire, vérifie d'abord qu'il se charge (-- --steam-probe) ;
# STEAM_REQUIRED=1 (CI) exige sa présence.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${1:-$ROOT/build/linux/Seve.x86_64}"
LOG="$(dirname "$BIN")/smoke.log"
DIR="$(dirname "$BIN")"
fail=0
# Build avec GodotSteam (tools/steam-fetch.sh) : la bibliothèque doit se charger et offrir toutes les
# fonctions dont SteamBridge se sert. Sans client Steam (CI), Steam refuse l'initialisation : normal.
if ls "$DIR" | grep -qi godotsteam; then
  probe="$(XDG_DATA_HOME="$(mktemp -d)" timeout 60 "$BIN" --headless -- --steam-probe 2>&1)"
  echo "$probe" | grep -E "STEAM-PROBE|^Steam" || true
  if ! echo "$probe" | grep -q "STEAM-PROBE bibliotheque=oui"; then
    echo "ÉCHEC : GodotSteam est à côté du build mais ne se charge pas"; echo "$probe" | tail -20; fail=1
  elif ! echo "$probe" | grep -q "fonctions manquantes : aucune"; then
    echo "ÉCHEC : version de GodotSteam incompatible avec SteamBridge"; fail=1
  fi
elif [ "${STEAM_REQUIRED:-0}" = 1 ]; then
  echo "ÉCHEC : GodotSteam absent du build ($DIR)"; ls -la "$DIR"; fail=1
fi
# Dossier utilisateur isolé (XDG_DATA_HOME), comme tools/unit-tests.sh : ne touche pas à la partie du développeur.
export XDG_DATA_HOME="$(mktemp -d)"
# Pilote audio factice : la machine de CI n'a pas de carte son (sinon ALSA ajoute ses erreurs au journal).
timeout 240 xvfb-run -a -s "-screen 0 1600x900x24" "$BIN" --resolution 1600x900 --audio-driver Dummy -- --autotest >"$LOG" 2>&1
code=$?
[ $code -eq 0 ] || { echo "ÉCHEC : code de sortie $code"; fail=1; }
grep -q "AUTOTEST fini" "$LOG" || { echo "ÉCHEC : le robot n'a pas fini"; fail=1; }
# Zéro ERROR / WARNING dans le journal, aux seules exceptions suivantes (le serveur X virtuel et le
# rendu logiciel de la CI, pas le jeu) :
#  - V-Sync : xvfb ne sait pas le régler.
# Une fuite « at exit » (nœud resté orphelin à la fermeture) est signalée mais ne fait pas échouer :
# elle ne se voit qu'une fois sur dix environ quand la machine est très chargée. Même chose pour
# « Invalid polygon data, triangulation failed » (un polygone aplati, vu une fois sur une trentaine de parties).
# Lignes de Steam exclues : sans client Steam (CI), l'API dit « Failed to load module steamclient.so ».
if grep -vE "^Steam :|^\[S_API\]" "$LOG" | grep -E "SCRIPT ERROR|Parse Error|Failed to load|Cannot open|Resource file not found" "$LOG"; then
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
