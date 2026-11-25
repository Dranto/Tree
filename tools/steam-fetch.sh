#!/usr/bin/env bash
# Télécharge GodotSteam (GDExtension) dans godot/addons/godotsteam, hors du dépôt (.gitignore).
# Steam reste facultatif : sans ce dossier, le jeu, les tests et la CI tournent exactement pareil
# (autoload SteamBridge inactif). À lancer avant d'exporter un build destiné à Steam.
#
#   tools/steam-fetch.sh            # version épinglée ci-dessous
#   tools/steam-fetch.sh --remove   # enlève la bibliothèque (retour au jeu sans Steam)
#
# GODOTSTEAM_VERSION : version de GodotSteam GDExtension compatible avec Godot 4.7 (une GDExtension
# marche avec les versions de Godot égales ou plus récentes que sa « compatibility_minimum »).
# GODOTSTEAM_URL : adresse de l'archive, si le nom des fichiers de la page des versions change
# (https://github.com/GodotSteam/GodotSteam/releases, archive « GDExtension plugin »).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/godot/addons/godotsteam"
VERSION="${GODOTSTEAM_VERSION:-4.17}"
URL="${GODOTSTEAM_URL:-https://github.com/GodotSteam/GodotSteam/releases/download/v${VERSION}-gde/godotsteam-${VERSION}-gdextension-plugin-4.4.zip}"
CACHE="${GODOTSTEAM_CACHE:-$HOME/.cache/godotsteam/$VERSION}"

if [ "${1:-}" = "--remove" ]; then
  rm -rf "$DEST"
  echo "GodotSteam enlevé : le jeu tourne sans Steam."
  exit 0
fi

mkdir -p "$CACHE"
ZIP="$CACHE/godotsteam.zip"
if [ ! -s "$ZIP" ]; then
  echo "Téléchargement de GodotSteam $VERSION : $URL"
  curl -fL --retry 3 -o "$ZIP.part" "$URL"
  mv "$ZIP.part" "$ZIP"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q "$ZIP" -d "$TMP"
SRC="$(find "$TMP" -type d -path '*addons/godotsteam' | head -1)"
if [ -z "$SRC" ]; then
  echo "Archive inattendue : pas de dossier addons/godotsteam dedans." >&2
  exit 1
fi
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
cp -r "$SRC" "$DEST"
echo "GodotSteam $VERSION posé dans godot/addons/godotsteam."
echo "Lancer Steam, puis le jeu : la sortie doit afficher « Steam : actif » (App ID de test 480)."
