#!/usr/bin/env bash
# Planche de direction des « Paysages d'herbier » (refonte du monde, vague 0, tâche W) : le Roncier et le
# Marais en quatre états (avant/après × flétri/ravivé), l'après en niveaux de gris, la taille réelle en
# 1080p et sur Steam Deck, les lieux (Cœurs, sanctuaires) et le GIF du bord de vie qui avance.
# « Avant » : la vraie partie (tests/paysages/scene.tscn). « Après » : scripts/world_art/ dessiné seul
# aux mêmes positions (tests/paysages/rendu.gd), sans interface. Rien n'est comparé : c'est une planche.
#
#   tools/paysages-planche.sh [DOSSIER]   # par défaut : godot/tests/paysages/out/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(realpath -m "${1:-$ROOT/godot/tests/paysages/out}")"
mkdir -p "$OUT"
export LIBGL_ALWAYS_SOFTWARE=1
"$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
run() { "$ROOT/tools/godot.sh" "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" -A2 || true; }
for reg in ronce spore; do
  echo "== Avant ($reg, vrai jeu)"
  run --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1920x1080 res://tests/paysages/scene.tscn -- --region=$reg --out="$OUT"
done
echo "== Avant (Roncier, Steam Deck)"
run --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1280x800 res://tests/paysages/scene.tscn -- --region=ronce --out="$OUT" --prefix=deck_
R="--xvfb --audio-driver Dummy -s res://tests/paysages/rendu.gd --"
for reg in ronce spore; do
  for e in fletri ravive; do
    echo "== Après ($reg, $e)"
    run $R --region=$reg --etat=$e --real="$OUT/cadre_$reg.json" --out="$OUT/${reg}_apres_$e.png" &
  done
done
for e in fletri ravive; do
  run $R --region=ronce --etat=$e --size=1280x800 --real="$OUT/deck_cadre_ronce.json" --out="$OUT/deck_ronce_apres_$e.png" &
done
wait
echo "== Planches"
run --xvfb --audio-driver Dummy -s res://tests/paysages/planche.gd -- "$OUT"
echo "== GIF du bord de vie"
FR="$OUT/gif_images"
rm -rf "$FR"
run $R --region=ronce --gif=84 --size=960x540 --real="$OUT/cadre_ronce.json" --out="$FR"
ffmpeg -loglevel error -y -framerate 24 -i "$FR/%03d.png" \
  -vf "split[a][b];[a]palettegen=max_colors=256:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a" "$OUT/bord_de_vie.gif"
ls -la "$OUT"
