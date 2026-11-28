#!/usr/bin/env bash
# Exporte le jeu (Godot 4.7) : modèles d'export téléchargés une fois puis mis en cache, comme tools/godot.sh.
#   tools/export.sh windows          # build/windows/Arborescence.exe
#   tools/export.sh linux            # build/linux/Arborescence.x86_64
#   tools/export.sh windows-demo     # build/windows-demo/Arborescence-demo.exe (fonctionnalité « demo »)
#   tools/export.sh linux-demo       # build/linux-demo/Arborescence-demo.x86_64
#   tools/export.sh all              # les quatre
#   tools/export.sh --icon           # régénère l'icône (PNG, ICO) et l'écran de démarrage (godot/assets/icon/)
#   tools/export.sh --templates      # installe seulement les modèles
set -euo pipefail
VERSION="${GODOT_VERSION:-4.7-stable}"
TPL_VERSION="${VERSION/-/.}"                       # 4.7-stable -> 4.7.stable
TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$TPL_VERSION"
CACHE="${GODOT_CACHE:-$HOME/.cache/godot/$VERSION}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/tools/godot.sh"

install_templates() {
  [ -f "$TPL_DIR/linux_release.x86_64" ] && [ -f "$TPL_DIR/windows_release_x86_64.exe" ] && return 0
  mkdir -p "$TPL_DIR" "$CACHE"
  local tpz="$CACHE/export_templates.tpz"
  if [ ! -f "$tpz" ]; then
    echo "Téléchargement des modèles d'export $VERSION (environ 1,2 Go, une seule fois)…"
    curl -sSL --retry 3 -o "$tpz.part" \
      "https://github.com/godotengine/godot-builds/releases/download/${VERSION}/Godot_v${VERSION}_export_templates.tpz"
    mv "$tpz.part" "$tpz"
  fi
  # Seuls les modèles x86_64 de Windows et de Linux sont utiles : le reste reste dans l'archive.
  unzip -oqj "$tpz" "templates/version.txt" "templates/linux_release.x86_64" "templates/linux_debug.x86_64" \
    "templates/windows_release_x86_64.exe" "templates/windows_debug_x86_64.exe" \
    "templates/windows_release_x86_64_console.exe" "templates/windows_debug_x86_64_console.exe" -d "$TPL_DIR"
  rm -f "$tpz"   # libère 1,2 Go ; les modèles utiles restent installés
}

export_one() {
  local key="$1" preset
  case "$key" in
    windows) preset="Windows" ;;
    linux) preset="Linux" ;;
    windows-demo) preset="Windows démo" ;;
    linux-demo) preset="Linux démo" ;;
    *) echo "Preset inconnu : $key (windows, linux, windows-demo, linux-demo, all)" >&2; exit 2 ;;
  esac
  local path
  path="$(sed -n "/^name=\"$preset\"\$/,/^export_path=/{s/^export_path=\"\(.*\)\"/\1/p}" "$ROOT/godot/export_presets.cfg")"
  mkdir -p "$(dirname "$ROOT/godot/$path")"
  # Importe d'abord (ressources, scripts), puis exporte en version release.
  "$GODOT" --headless --import >/dev/null 2>&1 || true
  "$GODOT" --headless --export-release "$preset" "$path"
  ls -la "$ROOT/godot/$path"
}

case "${1:-}" in
  --icon) exec "$GODOT" --xvfb -s res://tools/gen_icon.gd ;;
  --templates) install_templates ;;
  all) install_templates; for k in windows linux windows-demo linux-demo; do export_one "$k"; done ;;
  "") sed -n 2,11p "$0"; exit 2 ;;
  *) install_templates; export_one "$1" ;;
esac
