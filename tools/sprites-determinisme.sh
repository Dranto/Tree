#!/usr/bin/env bash
# Le rendu des Flétris (images cuites ou dessin direct) ne change rien au jeu : un combat robotisé à
# graine fixe et pas fixe (--fixed-fps 60) donne la même empreinte de l'état du jeu (positions, vies,
# tués) avec « --no-sprites » et avec le rendu cuit.
#
#   tools/sprites-determinisme.sh [secondes] [sortes]   # par défaut 20 s, sortes dessinées et anciennes mêlées
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TIME="${1:-20}"
KINDS="${2:-tireur,scarabee,menhir,fletri,chargeur,mandragore,crapaud,planeur}"
export LIBGL_ALWAYS_SOFTWARE=1
run() {
  "$ROOT/tools/godot.sh" --xvfb --audio-driver Dummy --fixed-fps 60 -- --benchmark --seed=1234 --bench-time="$TIME" --bench-kinds="$KINDS" "$@" 2>&1 \
    | grep -E "BENCHMARK empreinte|SCRIPT ERROR" | head -5
}
a="$(run --no-sprites)"
b="$(run)"
echo "dessin direct : $a"
echo "rendu cuit    : $b"
if [ -n "$a" ] && [ "$a" = "$b" ] && ! grep -q "SCRIPT ERROR" <<< "$a$b"; then
  echo "OK : même état du jeu."
  exit 0
fi
echo "ÉCHEC : l'état du jeu dépend du rendu."
exit 1
