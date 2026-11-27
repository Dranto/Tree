#!/usr/bin/env bash
# Pose GodotSteam (GDExtension) dans godot/addons/godotsteam, hors du dépôt (.gitignore).
# Steam reste facultatif : sans ce dossier, le jeu, les tests et la CI tournent exactement pareil
# (autoload SteamBridge inactif). La CI (workflow « Builds ») le lance avant chaque export : les
# builds Windows et Linux embarquent donc GodotSteam et steam_api.
#
#   tools/steam-fetch.sh            # version épinglée ci-dessous (archive vérifiée par SHA-256)
#   tools/steam-fetch.sh --latest   # prend l'archive la plus récente (affiche l'URL et le SHA-256 à épingler)
#   tools/steam-fetch.sh --list     # liste les archives GDExtension publiées (pour changer de version)
#   tools/steam-fetch.sh --remove   # enlève la bibliothèque (retour au jeu sans Steam)
#
# GodotSteam a quitté GitHub pour Codeberg (https://codeberg.org/godotsteam/godotsteam/releases).
# Pour changer de version : --list, puis mettre à jour URL et SHA256 ci-dessous (sha256sum de l'archive).
# Une GDExtension marche avec les versions de Godot égales ou plus récentes que sa
# « compatibility_minimum » (godotsteam.gdextension) : Godot 4.7 accepte une version faite pour 4.4+.
#
# Variables : GODOTSTEAM_URL, GODOTSTEAM_SHA256 (archive à prendre à la place), GODOTSTEAM_CACHE.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/godot/addons/godotsteam"
URL="${GODOTSTEAM_URL:-}"
SHA256="${GODOTSTEAM_SHA256:-}"
CACHE="${GODOTSTEAM_CACHE:-$HOME/.cache/godotsteam}"

list_assets() {
  # Codeberg (Gitea) puis GitHub (anciennes versions) : « nom adresse », la plus récente d'abord.
  curl -fsSL --retry 3 "https://codeberg.org/api/v1/repos/godotsteam/godotsteam/releases?limit=50" 2>/dev/null \
    | python3 -c 'import json,sys
for r in json.load(sys.stdin):
    for a in r.get("assets", []):
        print(r["tag_name"], a["name"], a["browser_download_url"])' || true
  curl -fsSL --retry 3 "https://api.github.com/repos/GodotSteam/GodotSteam/releases?per_page=50" 2>/dev/null \
    | python3 -c 'import json,sys
for r in json.load(sys.stdin):
    for a in r.get("assets", []):
        print(r["tag_name"], a["name"], a["browser_download_url"])' || true
}

case "${1:-}" in
  --remove)
    rm -rf "$DEST"
    echo "GodotSteam enlevé : le jeu tourne sans Steam."
    exit 0 ;;
  --list)
    list_assets | grep -i "gdextension" || { echo "Aucune archive GDExtension trouvée (réseau ?)." >&2; exit 1; }
    exit 0 ;;
  --latest)
    URL="$(list_assets | grep -i "gdextension" | grep -i "plugin" | grep -i "\.zip" | head -1 | awk '{print $3}')"
    SHA256=""
    [ -n "$URL" ] || { echo "Aucune archive GDExtension trouvée (réseau ?)." >&2; exit 1; } ;;
esac

if [ -z "$URL" ]; then
  echo "Aucune version épinglée : archives disponibles :" >&2
  list_assets | grep -i "gdextension" >&2 || true
  echo "Choisir une archive (GODOTSTEAM_URL=…) ou épingler URL et SHA256 dans $0." >&2
  exit 1
fi

mkdir -p "$CACHE"
ZIP="$CACHE/$(basename "$URL")"
if [ ! -s "$ZIP" ]; then
  echo "Téléchargement de GodotSteam : $URL"
  curl -fL --retry 3 -o "$ZIP.part" "$URL"
  mv "$ZIP.part" "$ZIP"
fi
got="$(sha256sum "$ZIP" | cut -d' ' -f1)"
if [ -n "$SHA256" ] && [ "$got" != "$SHA256" ]; then
  echo "Archive GodotSteam inattendue : SHA-256 $got au lieu de $SHA256." >&2
  rm -f "$ZIP"
  exit 1
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q "$ZIP" -d "$TMP"
SRC="$(find "$TMP" -type d -path '*addons/godotsteam' | head -1)"
if [ -z "$SRC" ]; then
  echo "Archive inattendue : pas de dossier addons/godotsteam dedans." >&2
  find "$TMP" -maxdepth 3 >&2
  exit 1
fi
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
cp -r "$SRC" "$DEST"
echo "GodotSteam posé dans godot/addons/godotsteam ($(basename "$URL"), SHA-256 $got)."
grep -E "compatibility_minimum|^(windows|linux)\.(release|template_release)" "$DEST"/*.gdextension 2>/dev/null || true
echo "Lancer Steam, puis le jeu : la sortie doit afficher « Steam : actif (App ID 480) »."
