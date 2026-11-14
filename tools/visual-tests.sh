#!/usr/bin/env bash
# Tests visuels : rejoue des parties à l'identique, capture le jeu et l'arbre de vie,
# puis compare chaque capture à son image de référence (godot/tests/visual/reference/).
#
#   tools/visual-tests.sh            # compare ; code de sortie 1 si une capture a changé
#   tools/visual-tests.sh --update   # remplace les références par les captures actuelles
#
# Résultats dans godot/tests/visual/out/ : captures, images des écarts (*.diff.png)
# et rapport.html (référence, capture et écarts côte à côte).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/godot/tests/visual/out"
SEED=1234
# Scénarios : « nom » ou « nom:LARGEURxHAUTEUR » (résolution de la fenêtre, 1600x900 par défaut).
# Seul le premier est joué si TEST_ONLY est défini (ex. TEST_ONLY=galerie tools/visual-tests.sh).
SCENARIOS=(depart combat galerie resolution:1280x720 resolution:1920x1080 resolution:2560x1440 resolution:3440x1440)

EXTRA=()
if [ "${1:-}" = "--update" ]; then
  EXTRA=(--update)
fi

rm -rf "$OUT"
mkdir -p "$OUT"
touch "$OUT/.gdignore"   # Godot n'importe pas les captures comme ressources

# Rendu logiciel (llvmpipe) partout, pour que la machine de dev et la CI donnent les mêmes pixels.
export LIBGL_ALWAYS_SOFTWARE=1
# Importe le projet (ressources, cache de scripts) avant de lancer les scénarios.
"$ROOT/tools/godot.sh" --headless --editor --quit >/dev/null 2>&1

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
