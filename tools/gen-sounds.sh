#!/usr/bin/env bash
# Régénère les sons et la musique (godot/assets/sounds, godot/assets/music) depuis godot/scripts/synth.gd.
set -euo pipefail
exec "$(dirname "$0")/godot.sh" --headless -s res://scripts/gen_sounds.gd
