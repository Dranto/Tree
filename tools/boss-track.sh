#!/usr/bin/env bash
# Prépare une musique de boss faite à la main : coupe aux mesures, raccords des boucles vérifiés,
# un .ogg par section dans godot/assets/music/hand/<boss>/ et godot/assets/music/hand/<boss>.json.
#   tools/boss-track.sh <fichier audio> <fiche de repères> <boss> [--qualite 6] [--raccord-ms 12]
#   tools/boss-track.sh ~/breakcore.mp3 godot/assets/music/hand/finale.fiche.txt finale
# Format de la fiche et du .json : tools/boss_track.py et data/README.md › Son.
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/boss_track.py" "$@"
