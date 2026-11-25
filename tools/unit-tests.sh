#!/usr/bin/env bash
# Tests de logique (godot/tests/*_test.gd), lancés en parallèle, chacun avec son propre dossier
# user:// (XDG_DATA_HOME) : flow_test, save_test… remplacent la sauvegarde par défaut sans gêner
# les autres ni la partie du développeur.
#
#   tools/unit-tests.sh                 # tous les tests de la liste
#   tools/unit-tests.sh flow save       # seulement ceux-là (nom sans « _test.gd »)
#   JOBS=2 tools/unit-tests.sh          # nombre de tests à la fois (par défaut : nombre de cœurs)
#
# Les robots longs (aventure_test, zone_test) n'en font pas partie : tools/aventure.sh, tools/zone.sh.
# Journaux et durées dans godot/tests/unit-out/ ; résumé Markdown dans resume.md (résumé de la CI).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/godot/tests/unit-out"
GODOT="$ROOT/tools/godot.sh"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 2)}"
LIMIT="${LIMIT:-600}"   # secondes au plus par test

# nom|options de Godot (avant -s)|arguments du test (après --)
TESTS=(
  "access|--headless|"
  "art|--headless|"
  "attack|--headless --fixed-fps 60|"
  "aube|--headless --fixed-fps 60|"
  "borders|--headless|"
  "builds|--headless|"
  "boss|--headless --fixed-fps 60|"
  "boss_eclat|--headless --fixed-fps 60|"
  "death|--headless --fixed-fps 60|"
  "deaths|--headless --fixed-fps 60|"
  "difficulty|--headless|"
  "demo|--headless --fixed-fps 60|"
  "direct_screen|--xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 --position 0,0|"
  "draw_batch|--xvfb --audio-driver Dummy|"
  "eclat_skills|--headless --fixed-fps 60|"
  "enemies|--headless|"
  "falaises|--headless --fixed-fps 60|"
  "feel|--headless|"
  "finale|--headless --fixed-fps 60|"
  "flow|--headless|"
  "foret|--headless --fixed-fps 60|"
  "i18n|--headless --fixed-fps 60|"
  "legibility|--headless|"
  "grafts|--headless --fixed-fps 60|"
  "marais|--headless --fixed-fps 60|"
  "moments|--headless|"
  "move|--xvfb --fixed-fps 60 --audio-driver Dummy|"
  "node_types|--headless|"
  "pad|--xvfb --fixed-fps 60 --audio-driver Dummy|"
  "objectives|--headless --fixed-fps 60|"
  "planner|--headless|"
  "plateaux|--headless --fixed-fps 60|"
  "racine|--headless --fixed-fps 60|"
  "region_engine|--headless --fixed-fps 60|"
  "region|--headless|"
  "region_ui|--headless --fixed-fps 60|"
  "migration|--headless|"
  "save|--headless|--new-game"
  "seve|--headless --fixed-fps 60|"
  "skills|--headless|"
  "sound|--headless|"
  "steam|--headless --fixed-fps 60|"
  "user_dir|--headless|"
  "spore|--headless --fixed-fps 60|"
  "tree_anim|--headless --fixed-fps 60|"
  "tree_originals|--headless|"
  "tree_ui|--xvfb --audio-driver Dummy --resolution 1600x900|"
  "vallee|--headless --fixed-fps 60|"
  "vent|--headless --fixed-fps 60|"
  "world_edge|--headless|"
  "world_fx|--headless --fixed-fps 60|"
  "world|--headless --fixed-fps 60|"
)

rm -rf "$OUT"
mkdir -p "$OUT"
touch "$OUT/.gdignore"
export LIBGL_ALWAYS_SOFTWARE=1
# Langue du jeu forcée (Settings.forced_locale) : les tests vérifient le texte français, quelle que soit
# la langue de la machine ou celle choisie dans les options du développeur.
export TREE_LANG="${TREE_LANG:-fr}"

if [ ! -d "$ROOT/godot/.godot" ] || [ "${IMPORT:-1}" = 1 ]; then
  "$GODOT" --headless --import >"$OUT/import.log" 2>&1 || { echo "Import en échec :"; tail -30 "$OUT/import.log"; }
fi

# Lignes d'erreur ou d'avertissement de Godot qui ne sont pas des défauts du jeu :
#  - fuites « at exit » : un test lancé par -s sort par quit() sans libérer sa scène ;
#  - V-Sync : le serveur X virtuel (xvfb) ne sait pas le régler ;
#  - « Sauvegarde refus » : save_test refuse exprès un fichier d'une version plus récente.
IGNORES='leaked|still in use at exit|Could not set V-Sync|^ +at: set_use_vsync|Sauvegarde refus'
godot_noise() {
  grep -E '^(ERROR|WARNING|USER ERROR|USER WARNING|SCRIPT ERROR):' "$1" | grep -vE "$IGNORES"
}

run_one() {
  local name="$1" opts="$2" args="$3"
  local data="$OUT/data/$name"
  mkdir -p "$data"
  local t0=$SECONDS code
  # shellcheck disable=SC2086
  XDG_DATA_HOME="$data" timeout -k 10 "$LIMIT" "$GODOT" $opts -s "res://tests/${name}_test.gd" ${args:+-- $args} \
    >"$OUT/$name.log" 2>&1
  code=$?
  # Une erreur de script fait échouer le test même si son code de sortie est 0.
  if [ "$code" -eq 0 ] && grep -q "SCRIPT ERROR" "$OUT/$name.log"; then code=99; fi
  # Toute autre erreur ou tout avertissement de Godot aussi, sauf ceux de la liste IGNORES.
  if [ "$code" -eq 0 ] && [ -n "$(godot_noise "$OUT/$name.log")" ]; then code=98; fi
  echo "$name $code $((SECONDS - t0))" >> "$OUT/resultats.txt"
  if [ "$code" -eq 0 ]; then
    echo "ok     $name ($((SECONDS - t0)) s)"
  else
    echo "ÉCHEC  $name (code $code, $((SECONDS - t0)) s) : $OUT/$name.log"
    # Les premières lignes en échec, pour lire la cause dans le journal de la CI sans l'artefact.
    grep -E "ÉCHEC|SCRIPT ERROR" "$OUT/$name.log" | head -8 | cut -c1-600 | sed 's/^/       /'
  fi
}

START=$SECONDS
running=0
for entry in "${TESTS[@]}"; do
  IFS='|' read -r name opts args <<<"$entry"
  if [ $# -gt 0 ]; then
    keep=0
    for want in "$@"; do [ "$want" = "$name" ] && keep=1; done
    [ "$keep" = 1 ] || continue
  fi
  run_one "$name" "$opts" "$args" &
  running=$((running + 1))
  if [ "$running" -ge "$JOBS" ]; then
    wait -n
    running=$((running - 1))
  fi
done
wait
TOTAL=$((SECONDS - START))

failed=$(awk '$2 != 0 {print $1}' "$OUT/resultats.txt" | sort)
{
  echo "## Tests de logique"
  echo
  echo "| Test | Résultat | Durée |"
  echo "| --- | --- | --- |"
  sort "$OUT/resultats.txt" | while read -r n c d; do
    if [ "$c" -eq 0 ]; then r="ok"; else r="**ÉCHEC** (code $c)"; fi
    echo "| $n | $r | $d s |"
  done
  echo
  echo "Durée totale : ${TOTAL} s ($JOBS à la fois)"
  for n in $failed; do
    echo
    echo "### $n"
    echo '```'
    { grep -E "ÉCHEC|SCRIPT ERROR|RÉSULTAT|ERROR" "$OUT/$n.log"; godot_noise "$OUT/$n.log"; } | sort -u | head -40
    echo '```'
  done
} > "$OUT/resume.md"

echo "Durée totale : ${TOTAL} s"
if [ -n "$failed" ]; then
  echo "ÉCHEC : $(echo $failed)"
  exit 1
fi
echo "OK : tous les tests passent."
