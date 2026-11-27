#!/usr/bin/env bash
# Profil du banc de jeu : temps passé dans chaque _process, _physics_process et _draw.
# Copie le projet dans un dossier temporaire, l'instrumente (tools/perf_instrument.py), puis lance
# le banc avec --profile. Le projet d'origine n'est pas touché.
#   tools/perf-profile.sh                       # banc complet (30 s)
#   tools/perf-profile.sh --bench-time=10       # options du banc (voir docs/performances.md)
#   FUNCS="_separate _rebuild_grid" tools/perf-profile.sh   # mesure aussi ces fonctions
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tools"
cp "$ROOT/tools/godot.sh" "$TMP/tools/"
cp -r "$ROOT/godot" "$TMP/godot"
rm -rf "$TMP/godot/autotest" "$TMP/godot/tests/visual/out"
# shellcheck disable=SC2086
python3 "$ROOT/tools/perf_instrument.py" "$TMP/godot" ${FUNCS:-}
"$TMP/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
"$TMP/tools/godot.sh" --xvfb -- --benchmark --profile "$@" 2>&1 | grep -E "BENCHMARK|PROFIL|PIC|A-COUP|PRÉPARATION|SCRIPT ERROR"
