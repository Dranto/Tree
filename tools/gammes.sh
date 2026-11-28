#!/usr/bin/env bash
# Inventaire des gammes : gamme et accords de chaque zone, morceaux de boss faits à la main, bruitages qui
# ont des notes et leur transposition par zone, notes des nappes d'ambiance (harmony.gd).
#   tools/gammes.sh
set -euo pipefail
cd "$(dirname "$0")"
exec timeout 300 ./godot.sh --headless -s res://tools/gammes.gd
