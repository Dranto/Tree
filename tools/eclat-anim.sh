#!/usr/bin/env bash
# GIF des moments forts (jalon Éclat, tâche A) : critique lourd, mort d'élite, Cœur purifié, phase et
# mort de boss. Rejoue tests/eclat_anim.gd image par image (temps fixé, rendu logiciel).
#   tools/eclat-anim.sh [DOSSIER_SORTIE] [DOSSIER_GODOT_AVANT]
# Avec un second dossier (ex. un worktree de develop), chaque GIF montre l'avant à gauche et
# l'après à droite ; sans, l'après seul.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/godot/tests/visual/out/eclat_anim}"
BEFORE="${2:-}"
mkdir -p "$OUT"
export LIBGL_ALWAYS_SOFTWARE=1

record() { # $1 dossier du projet godot, $2 dossier des images
  local proj="$1" dest="$2"
  rm -rf "$dest"; mkdir -p "$dest"
  [ "$proj" -ef "$ROOT/godot" ] || cp "$ROOT/godot/tests/eclat_anim.gd" "$proj/tests/eclat_anim.gd"
  (cd "$proj" && "$ROOT/tools/godot.sh" --headless --path "$proj" --import >/dev/null 2>&1 || true)
  xvfb-run -a -s "-screen 0 1280x720x24" "$HOME/.cache/godot/${GODOT_VERSION:-4.7-stable}/Godot_v${GODOT_VERSION:-4.7-stable}_linux.x86_64" \
    --path "$proj" --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 --position 0,0 \
    -s res://tests/eclat_anim.gd -- --out="$dest" 2>&1 | grep -E "eclat_anim|SCRIPT ERROR" || true
}

record "$ROOT/godot" "$OUT/apres"
[ -n "$BEFORE" ] && record "$BEFORE" "$OUT/avant"

for s in critique elite coeur boss_phase boss_mort; do
  if [ -n "$BEFORE" ]; then
    ffmpeg -loglevel error -y -framerate 60 -i "$OUT/avant/$s/%03d.png" -framerate 60 -i "$OUT/apres/$s/%03d.png" \
      -filter_complex "[0]scale=520:-1:flags=lanczos[a];[1]scale=520:-1:flags=lanczos[b];[a][b]hstack,split[x][y];[x]palettegen=max_colors=128:stats_mode=diff[p];[y][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
      -loop 0 "$OUT/$s.gif"
  else
    ffmpeg -loglevel error -y -framerate 60 -i "$OUT/apres/$s/%03d.png" \
      -vf "scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=sierra2_4a" \
      -loop 0 "$OUT/$s.gif"
  fi
  echo "GIF : $OUT/$s.gif"
done
