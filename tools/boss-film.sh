#!/usr/bin/env bash
# Film des boss du jalon Éclat (tests/visual/boss_film.gd) : arrivée, phase et mort de chaque boss,
# un GIF par boss. Avec une seconde copie du dépôt (worktree d'une version antérieure), GIF avant/après
# côte à côte (le script de film y est copié le temps du tournage).
#   tools/boss-film.sh DOSSIER [ronce,spore,…] [AUTRE_DEPOT]
# Images dans DOSSIER/{apres,avant}/<boss>/NNN.png, GIF dans DOSSIER/<boss>.gif.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$(realpath -m "${1:?dossier de sortie}")"
BOSSES="${2:-ronce,spore,vent,seve,aube,racine,finale}"
OTHER="${3:-}"
export LIBGL_ALWAYS_SOFTWARE=1

film() { # $1 dépôt, $2 sous-dossier
  local repo="$1" out="$DEST/$2"
  mkdir -p "$out"
  if [ "$repo" != "$ROOT" ]; then
    cp "$ROOT/godot/tests/visual/boss_film.gd" "$ROOT/godot/tests/visual/boss_film.tscn" "$repo/godot/tests/visual/"
  fi
  "$repo/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
  XDG_DATA_HOME="$(mktemp -d)" "$repo/tools/godot.sh" --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 2400x1350 --position 0,0 \
    res://tests/visual/boss_film.tscn -- --bosses="$BOSSES" --out="$out" 2>&1 | grep -E "SCRIPT ERROR|FILM" || true
}

film "$ROOT" apres
[ -n "$OTHER" ] && film "$(realpath "$OTHER")" avant
for b in ${BOSSES//,/ }; do
  a="$DEST/apres/$b"
  [ -f "$a/000.png" ] || continue
  if [ -n "$OTHER" ] && [ -f "$DEST/avant/$b/000.png" ]; then
    ffmpeg -loglevel error -y -framerate 30 -i "$DEST/avant/$b/%03d.png" -framerate 30 -i "$a/%03d.png" \
      -filter_complex "[0]scale=560:-1:flags=lanczos[l];[1]scale=560:-1:flags=lanczos[r];[l][r]hstack,split[a][b];[a]palettegen=max_colors=160[p];[b][p]paletteuse=dither=sierra2_4a" \
      -loop 0 "$DEST/$b.gif"
  else
    ffmpeg -loglevel error -y -framerate 30 -i "$a/%03d.png" \
      -vf "scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=160[p];[b][p]paletteuse=dither=sierra2_4a" \
      -loop 0 "$DEST/$b.gif"
  fi
done
echo "Film : $DEST"
