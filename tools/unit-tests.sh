#!/usr/bin/env bash
# Tests de logique (godot/tests/*_test.gd), lancés en parallèle, chacun avec son propre dossier
# user:// (XDG_DATA_HOME) : flow_test, save_test… remplacent la sauvegarde par défaut sans gêner
# les autres ni la partie du développeur.
#
#   tools/unit-tests.sh                 # tous les tests de la liste
#   tools/unit-tests.sh flow save       # seulement ceux-là (nom sans « _test.gd »)
#   JOBS=2 tools/unit-tests.sh          # nombre de tests à la fois (par défaut : nombre de cœurs)
#   SHARD=1/2 tools/unit-tests.sh       # seulement la 1re des 2 parts (jobs parallèles de la CI)
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
  "air|--headless|"
  "art|--headless|"
  "attack|--headless --fixed-fps 60|"
  "aube|--headless --fixed-fps 60|"
  "borders|--headless|"
  "builds|--headless|"
  "boss|--headless --fixed-fps 60|"
  "boss@seve_cycle2|--headless --fixed-fps 60|--region=seve --cycle=2"
  "boss@aube_cycle2|--headless --fixed-fps 60|--region=aube --cycle=2"
  "boss@racine_cycle2|--headless --fixed-fps 60|--region=racine --cycle=2"
  "boss_eclat|--headless --fixed-fps 60|"
  "boss_track|--headless|"
  "death|--headless --fixed-fps 60|"
  "deaths|--headless --fixed-fps 60|"
  "difficulty|--headless|"
  "demo|--headless --fixed-fps 60|"
  "direct_screen|--xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 --position 0,0|"
  "draw_batch|--xvfb --audio-driver Dummy|"
  "bestiaire|--xvfb --audio-driver Dummy|"
  "heros|--xvfb --audio-driver Dummy|"
  "seve_bestiaire|--xvfb --audio-driver Dummy|"
  "boss_dessin|--xvfb --audio-driver Dummy|"
  "boss_cuisson|--xvfb --audio-driver Dummy|"
  "sprite_bake|--xvfb --audio-driver Dummy|"
  "remains_sprite|--xvfb --audio-driver Dummy --fixed-fps 60|--sprites=3"
  "paysages_proto|--xvfb --audio-driver Dummy|"
  "lieux|--xvfb --audio-driver Dummy --fixed-fps 60|"
  "preparation|--xvfb --audio-driver Dummy --fixed-fps 60|"
  "arenes|--xvfb --audio-driver Dummy --fixed-fps 60|"
  "world_life|--xvfb --audio-driver Dummy --fixed-fps 60|"
  "decor|--xvfb --audio-driver Dummy --fixed-fps 60|"
  "frontieres|--xvfb --audio-driver Dummy --fixed-fps 60|"
  "paysages|--xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 --position 0,0|"
  "eclat_skills|--headless --fixed-fps 60|"
  "enemies|--headless|"
  "falaises|--headless --fixed-fps 60|"
  "feel|--headless|"
  "finale|--headless --fixed-fps 60|"
  "finale_creux|--xvfb --audio-driver Dummy --fixed-fps 60|"
  "flow|--headless|"
  "foret|--headless --fixed-fps 60|"
  "i18n|--headless --fixed-fps 60|"
  "legibility|--headless|"
  "grafts|--headless --fixed-fps 60|"
  "marais|--headless --fixed-fps 60|"
  "moments|--headless --fixed-fps 60|"
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
  "rumble|--headless|"
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

# Durée approximative de chaque test (s, CI du 26/11 : 1 150 s en tout, 4 à la fois). Sert à répartir
# les parts (SHARD) et à lancer les plus longs d'abord : un long test lancé en dernier allongeait la
# durée totale. Un test absent compte 10 s.
declare -A WEIGHT=(
  [move]=121 [paysages]=89 [attack]=74 [finale]=74 [sound]=63 [heros]=56 [world_life]=51
  [boss_eclat]=45 [pad]=34 [remains_sprite]=27 [boss_track]=26 [direct_screen]=26 [eclat_skills]=24
  [decor]=23 [seve]=21 [plateaux]=18 [enemies]=17 [vent]=17 [foret]=16 [demo]=15 [falaises]=15
  [flow]=15 [region]=15 [vallee]=15 [sprite_bake]=14 [racine]=14 [tree_ui]=14 [skills]=13
  [world_fx]=12 [boss]=11 [bestiaire]=11 [i18n]=11 [moments]=11 [aube]=10 [death]=10 [grafts]=10
  [marais]=10 [access]=9 [deaths]=9 [migration]=9 [spore]=9 [tree_anim]=9 [difficulty]=7 [feel]=8
  [objectives]=8 [region_engine]=8 [region_ui]=8 [save]=8 [steam]=8 [world]=6 [planner]=5
  [seve_bestiaire]=5 [boss_dessin]=4 [paysages_proto]=4 [art]=3 [air]=3 [borders]=3 [builds]=3 [draw_batch]=3
  [node_types]=3 [tree_originals]=3 [user_dir]=3 [legibility]=2 [rumble]=2 [world_edge]=2
)
# Du plus long au plus court (ordre de lancement).
mapfile -t TESTS < <(for e in "${TESTS[@]}"; do echo "${WEIGHT[${e%%|*}]:-10}	$e"; done | sort -t$'\t' -k1,1nr -k2,2 -s | cut -f2-)

# SHARD=k/n : chaque test va à la part la moins chargée, du plus long au plus court.
if [ -n "${SHARD:-}" ]; then
  k="${SHARD%/*}"; n="${SHARD#*/}"
  declare -a load
  for ((i = 1; i <= n; i++)); do load[$i]=0; done
  mine=()
  for e in "${TESTS[@]}"; do
    best=1
    for ((i = 2; i <= n; i++)); do [ "${load[$i]}" -lt "${load[$best]}" ] && best=$i; done
    load[$best]=$((load[$best] + ${WEIGHT[${e%%|*}]:-10}))
    [ "$best" = "$k" ] && mine+=("$e")
  done
  TESTS=("${mine[@]}")
  echo "Part $SHARD : ${#TESTS[@]} tests (~${load[$k]} s de tests, $JOBS à la fois)"
fi

rm -rf "$OUT"
mkdir -p "$OUT"
touch "$OUT/.gdignore"
export LIBGL_ALWAYS_SOFTWARE=1
# Langue du jeu forcée (Settings.forced_locale) : les tests vérifient le texte français, quelle que soit
# la langue de la machine ou celle choisie dans les options du développeur.
export TREE_LANG="${TREE_LANG:-fr}"

if [ ! -d "$ROOT/godot/.godot" ] || [ "${IMPORT:-1}" = 1 ]; then
  "$ROOT/tools/import.sh" "$OUT/import.log" || echo "Import en échec : les tests peuvent échouer faute de ressources."
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
  # « test@variante » : le même fichier de test avec d'autres arguments (journal à part).
  local file="${name%%@*}"
  local data="$OUT/data/$name"
  mkdir -p "$data"
  local t0=$SECONDS code
  # shellcheck disable=SC2086
  XDG_DATA_HOME="$data" timeout -k 10 "$LIMIT" "$GODOT" $opts -s "res://tests/${file}_test.gd" ${args:+-- $args} \
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
  echo "## Tests de logique${SHARD:+ (part $SHARD)}"
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
