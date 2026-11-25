#!/usr/bin/env bash
# GIF de l'Arbre de vie (jalon Éclat G) : apprendre un petit nœud, un nœud clé, oublier, poser une greffe,
# basculer de build. Un GIF par scène, à partir de tests/tree_eclat_anim.gd (sans API nouvelle : le même
# script rejoue l'« avant » sur un checkout de develop).
#   tools/eclat-arbre.sh DOSSIER_SORTIE [DOSSIER_GODOT]   (DOSSIER_GODOT : le godot/ à filmer, par défaut celui-ci)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:?dossier de sortie}"
PROJ="${2:-$ROOT/godot}"
FRAMES="$(mktemp -d)"
mkdir -p "$DEST"
[ "$PROJ" != "$ROOT/godot" ] && cp "$ROOT/godot/tests/tree_eclat_anim.gd" "$PROJ/tests/"
touch "$PROJ/tests/visual/out/.gdignore" 2>/dev/null || { mkdir -p "$PROJ/tests/visual/out"; touch "$PROJ/tests/visual/out/.gdignore"; }
export LIBGL_ALWAYS_SOFTWARE=1
( cd "$PROJ" && "$ROOT/tools/godot.sh" --headless --path "$PROJ" --import >/dev/null 2>&1 || true )
for scene in petit cle oubli greffe build; do
  ( cd "$PROJ" && xvfb-run -a -s "-screen 0 1600x900x24" \
      "${GODOT_BIN:-$HOME/.cache/godot/4.7-stable/Godot_v4.7-stable_linux.x86_64}" --path "$PROJ" --audio-driver Dummy --fixed-fps 60 \
      --resolution 1600x900 --position 0,0 -s res://tests/tree_eclat_anim.gd -- --out="$FRAMES" --scene=$scene 2>&1 | grep -E "SCRIPT ERROR" || true )
  ffmpeg -loglevel error -y -framerate 20 -i "$FRAMES/${scene}_%03d.png" \
    -vf "scale=900:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=160[p];[b][p]paletteuse=dither=sierra2_4a" \
    -loop 0 "$DEST/arbre_${scene}.gif"
done
echo "GIF dans $DEST"
