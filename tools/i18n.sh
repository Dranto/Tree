#!/usr/bin/env bash
# Traduction (jalon 12 A) : catalogues godot/locale/tree.pot, fr.po, en.po.
#
#   tools/i18n.sh                  # extrait les textes (code + données) et met les catalogues à jour
#   tools/i18n.sh --check          # échoue si un texte du code échappe à la traduction ou si les
#                                  # catalogues ne sont pas à jour (CI)
#   tools/i18n.sh --coverage       # part des textes traduits, par langue
#   tools/i18n.sh --missing en     # liste des textes sans traduction dans une langue
#   tools/i18n.sh --complete en    # échoue si un texte manque en anglais ou perd un gabarit ({0}, %s) (CI)
#   tools/i18n.sh --lint           # seulement le contrôle des textes du code
#
# Le test godot/tests/i18n_test.gd vérifie en jeu, en pseudo-langue (xx), qu'aucun texte visible ne
# reste en français et que la police a tous les glyphes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
  "") exec python3 "$ROOT/tools/i18n.py" extract ;;
  --check) exec python3 "$ROOT/tools/i18n.py" check ;;
  --coverage) exec python3 "$ROOT/tools/i18n.py" coverage ;;
  --missing) exec python3 "$ROOT/tools/i18n.py" missing "${2:-en}" ;;
  --complete) exec python3 "$ROOT/tools/i18n.py" complete "${2:-en}" ;;
  --lint) exec python3 "$ROOT/tools/i18n.py" lint ;;
  *) sed -n '2,13p' "$0"; exit 2 ;;
esac
