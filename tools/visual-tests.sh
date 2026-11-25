#!/usr/bin/env bash
# Tests visuels : rejoue des parties à l'identique, capture le jeu et l'arbre de vie,
# puis compare chaque capture à son image de référence (godot/tests/visual/reference/).
#
#   tools/visual-tests.sh            # compare ; code de sortie 1 si une capture a changé
#   tools/visual-tests.sh --update   # remplace les références par les captures actuelles
#   SHARD=1/2 tools/visual-tests.sh  # seulement la 1re des 2 parts (jobs parallèles de la CI)
#   tools/visual-tests.sh --report   # refait rapport.html et resume.md depuis out/ (parts réunies)
#
# Résultats dans godot/tests/visual/out/ : captures, images des écarts (*.diff.png)
# et rapport.html (référence, capture et écarts côte à côte).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/godot/tests/visual/out"
SEED=1234
# Scénarios : « nom » ou « nom:LARGEURxHAUTEUR » (résolution de la fenêtre, 1600x900 par défaut).
# Seul le premier est joué si TEST_ONLY est défini (ex. TEST_ONLY=galerie tools/visual-tests.sh).
SCENARIOS=(depart combat galerie competences boss roncier resolution:1280x720 resolution:1920x1080 resolution:2560x1440 resolution:3440x1440 quetes:1280x720 quetes:1920x1080 quetes:2560x1440 quetes:3440x1440 charte:2560x1440 interactions heros:2560x1440 monde attaque regions marais plateaux carte5:1280x720 carte5:1920x1080 falaises vallee finale foret bord menus:1280x720 menus:3440x1440 cumul manette:1280x800 reaction)

# Durée approximative de chaque scénario (s, machine des tests du 24/11 : 444 s en tout), pour répartir les parts : chaque scénario
# va à la part la moins chargée, du plus long au plus court. Un scénario absent compte 20 s.
declare -A WEIGHT=(
  [depart]=7 [combat]=68 [galerie]=9 [competences]=8 [boss]=10 [roncier]=37 [resolution:1280x720]=8
  [resolution:1920x1080]=9 [resolution:2560x1440]=12 [resolution:3440x1440]=14 [quetes:1280x720]=6
  [quetes:1920x1080]=11 [quetes:2560x1440]=7 [quetes:3440x1440]=9 [charte:2560x1440]=5
  [interactions]=18 [heros:2560x1440]=7 [monde]=4 [attaque]=3 [regions]=17 [marais]=21
  [plateaux]=18 [carte5:1280x720]=5 [carte5:1920x1080]=5 [falaises]=19 [vallee]=22 [finale]=10
  [foret]=21 [bord]=19 [menus:1280x720]=9 [menus:3440x1440]=20 [cumul]=6 [manette:1280x800]=10 [reaction]=6
)

# SHARD=k/n : garde les scénarios de la part k sur n.
if [ -n "${SHARD:-}" ]; then
  k="${SHARD%/*}"; n="${SHARD#*/}"
  declare -a load
  for ((i = 1; i <= n; i++)); do load[$i]=0; done
  mine=()
  while read -r w entry; do
    best=1
    for ((i = 2; i <= n; i++)); do [ "${load[$i]}" -lt "${load[$best]}" ] && best=$i; done
    load[$best]=$((load[$best] + w))
    [ "$best" = "$k" ] && mine+=("$entry")
  done < <(for e in "${SCENARIOS[@]}"; do echo "${WEIGHT[$e]:-20} $e"; done | sort -k1,1nr -k2,2 -s)
  # Ordre d'origine gardé.
  keep=()
  for e in "${SCENARIOS[@]}"; do
    for m in "${mine[@]}"; do [ "$m" = "$e" ] && keep+=("$e"); done
  done
  SCENARIOS=("${keep[@]}")
  echo "Part $SHARD : ${SCENARIOS[*]} (~${load[$k]} s prévues)"
fi

EXTRA=()
REPORT_ONLY=0
if [ "${1:-}" = "--update" ]; then
  EXTRA=(--update)
elif [ "${1:-}" = "--report" ]; then
  REPORT_ONLY=1
fi

if [ "$REPORT_ONLY" = 1 ]; then
  [ -f "$OUT/results.txt" ] || { echo "Rien à réunir : $OUT/results.txt absent"; exit 1; }
  TOTAL=$(awk '{s+=$3} END{print s+0}' "$OUT/durees.txt" 2>/dev/null)
  status=$(awk '$2 != "ok" && $2 != "maj" {bad=1} END{print bad+0}' "$OUT/results.txt")
fi

if [ "$REPORT_ONLY" = 0 ]; then
rm -rf "$OUT"
mkdir -p "$OUT"
touch "$OUT/.gdignore"   # Godot n'importe pas les captures comme ressources

# Rendu logiciel (llvmpipe) partout, pour que la machine de dev et la CI donnent les mêmes pixels.
export LIBGL_ALWAYS_SOFTWARE=1
# Importe le projet (ressources, cache de scripts) avant de lancer les scénarios.
# Le journal d'import est gardé dans out/import.log : un import qui plante (vu en CI : segfault,
# polices non importées, toutes les captures avec du texte en écart) est signalé et refait une fois.
if ! "$ROOT/tools/godot.sh" --headless --import >"$OUT/import.log" 2>&1; then
  echo "Import du projet en échec (code $?), fin du journal :"
  tail -40 "$OUT/import.log"
  echo "Nouvel essai d'import."
  "$ROOT/tools/godot.sh" --headless --import >"$OUT/import2.log" 2>&1 || { echo "Import encore en échec :"; tail -40 "$OUT/import2.log"; }
fi

START=$SECONDS
status=0
for entry in "${SCENARIOS[@]}"; do
  scenario="${entry%%:*}"
  res=1600x900
  [[ "$entry" == *:* ]] && res="${entry#*:}"
  [ -n "${TEST_ONLY:-}" ] && [ "$TEST_ONLY" != "$scenario" ] && continue
  echo "== Scénario $scenario ($res)"
  t0=$SECONDS
  # --fixed-fps : chaque image avance de 1/60 s quelle que soit la vitesse de la machine.
  "$ROOT/tools/godot.sh" --xvfb --audio-driver Dummy --fixed-fps 60 --resolution "$res" --position 0,0 \
    res://tests/visual/runner.tscn -- --scenario="$scenario" --seed="$SEED" "${EXTRA[@]}" \
    2>&1 | grep -E "VISUEL|ERROR|SCRIPT ERROR" | sed 's/^/   /'
  code=${PIPESTATUS[0]}
  [ "$code" -ne 0 ] && status=1
  echo "$scenario $res $((SECONDS - t0))" >> "$OUT/durees.txt"
done
TOTAL=$((SECONDS - START))
echo "Durée totale : ${TOTAL} s"
fi

# Rapport HTML : une ligne par capture, avec la référence, la capture et les écarts.
{
  echo '<!doctype html><meta charset="utf-8"><title>Tests visuels</title>'
  echo '<style>body{font:14px sans-serif;background:#111;color:#ddd;margin:16px}'
  echo 'h2{margin:24px 0 8px}.ok{color:#7fd36b}.ko{color:#ff6b6b}'
  echo '.row{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}'
  echo 'img{width:100%;border:1px solid #333}figure{margin:0}figcaption{opacity:.7}</style>'
  echo '<h1>Tests visuels</h1>'
  while read -r name result ratio; do
    cls=ok; [ "$result" = ok ] || [ "$result" = maj ] || cls=ko
    pct=$(awk -v r="$ratio" 'BEGIN{printf "%.3f", r*100}')
    echo "<h2>$name : <span class=$cls>$result</span> ($pct % de pixels différents)</h2><div class=row>"
    echo "<figure><img src=\"../reference/$name.png\"><figcaption>Référence</figcaption></figure>"
    echo "<figure><img src=\"$name.png\"><figcaption>Capture</figcaption></figure>"
    if [ -f "$OUT/$name.diff.png" ]; then
      echo "<figure><img src=\"$name.diff.png\"><figcaption>Écarts (en rouge)</figcaption></figure>"
    fi
    echo "</div>"
  done < "$OUT/results.txt"
  echo "<h2>Contrôles sans image (textes hors écran, libellés qui se recouvrent)</h2>"
  if [ -s "$OUT/audit.txt" ]; then
    echo "<table border=1 cellpadding=4><tr><th>Statut</th><th>Défaut</th></tr>"
    while IFS='|' read -r st res screen kind rest; do
      echo "<tr><td>$st</td><td>$res $screen : $kind $rest</td></tr>"
    done < "$OUT/audit.txt"
    echo "</table>"
  else
    echo "<p class=ok>Aucun défaut.</p>"
  fi
  echo "<p>Durée totale : ${TOTAL} s</p>"
} > "$OUT/rapport.html" 2>/dev/null

# Résumé Markdown (résumé du job GitHub Actions).
{
  echo "## Tests visuels"
  echo
  echo "| Capture | Résultat | Pixels différents |"
  echo "| --- | --- | --- |"
  while read -r name result ratio; do
    echo "| $name | $result | $(awk -v r="$ratio" 'BEGIN{printf "%.3f %%", r*100}') |"
  done < "$OUT/results.txt"
  echo
  echo "### Contrôles sans image"
  if [ -s "$OUT/audit.txt" ]; then
    while IFS='|' read -r st res screen kind msg; do echo "- **$st** ($res, $screen) $msg"; done < "$OUT/audit.txt"
  else
    echo "Aucun défaut."
  fi
  echo
  echo "Durée totale : ${TOTAL} s"
} > "$OUT/resume.md" 2>/dev/null

echo
if [ "${1:-}" = "--update" ]; then
  echo "Références mises à jour dans godot/tests/visual/reference/ : vérifie-les avant de committer."
elif [ "$status" -ne 0 ]; then
  echo "ÉCHEC : des captures ont changé. Rapport : godot/tests/visual/out/rapport.html"
  echo "Si le changement est voulu : tools/visual-tests.sh --update, puis committer les références."
else
  echo "OK : toutes les captures correspondent aux références."
fi
exit "$status"
