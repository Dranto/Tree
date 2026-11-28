#!/usr/bin/env bash
# Vérifie la machine GPU (docs/gpu-ovh.md) : la carte, l'OpenGL de VirtualGL, puis une même scène
# filmée deux fois, sur la carte et en rendu logiciel, pour comparer la vitesse et l'image.
#   tools/gpu/verifier.sh [scène]      # « fouet » par défaut (une scène de tools/eclat-film.sh)
# Sortie : durées des deux tournages, ressemblance des images (SSIM, 1 = identiques), images dans
# /tmp/verif-gpu/{gpu,cpu}/ pour les regarder.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLIP="${1:-fouet}"
OUT=/tmp/verif-gpu
export PATH="$ROOT/tools/gpu/bin:$PATH"
ok=1

echo "== Carte"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader || { echo "ÉCHEC : pas de pilote NVIDIA"; exit 1; }

echo "== OpenGL par VirtualGL dans un écran virtuel"
card=""
for c in /sys/class/drm/card[0-9]*; do
  case "$c" in *-*) continue ;; esac
  [ "$(cat "$c/device/vendor" 2>/dev/null)" = "0x10de" ] && { card="/dev/dri/$(basename "$c")"; break; }
done
[ -n "$card" ] || { echo "ÉCHEC : aucune carte NVIDIA dans /dev/dri (groupes video et render ?)"; exit 1; }
renderer=$(xvfb-run -a glxinfo -B 2>/dev/null | grep -E "OpenGL renderer|OpenGL core profile version" || true)
echo "$renderer"
echo "$renderer" | grep -qi nvidia || { echo "ÉCHEC : l'OpenGL n'est pas celui de la carte"; ok=0; }

echo "== Godot sur la carte"
"$ROOT/tools/import.sh"
banner=$(timeout 180 "$ROOT/tools/godot.sh" --xvfb --audio-driver Dummy --quit-after 30 2>&1 | grep -E "OpenGL API|Vulkan" | head -2 || true)
echo "$banner"
echo "$banner" | grep -qi nvidia || { echo "ÉCHEC : Godot ne dessine pas sur la carte"; ok=0; }

echo "== Même scène ($CLIP) : carte puis rendu logiciel"
rm -rf "$OUT"; mkdir -p "$OUT"
t0=$(date +%s); "$ROOT/tools/eclat-film.sh" "$OUT/gpu" "$CLIP" >/dev/null; t1=$(date +%s)
GODOT_GPU=0 "$ROOT/tools/eclat-film.sh" "$OUT/cpu" "$CLIP" >/dev/null; t2=$(date +%s)
echo "Carte : $((t1 - t0)) s ; rendu logiciel : $((t2 - t1)) s"
n=0; low=0
for f in "$OUT/gpu/$CLIP"/*.png; do
  g="$OUT/cpu/$CLIP/$(basename "$f")"
  [ -f "$g" ] || continue
  s=$(ffmpeg -hide_banner -i "$f" -i "$g" -lavfi ssim -f null - 2>&1 | sed -nE 's/.*All:([0-9.]+).*/\1/p')
  n=$((n + 1))
  awk -v s="${s:-0}" 'BEGIN{exit !(s < 0.97)}' && { low=$((low + 1)); echo "  $(basename "$f") : SSIM $s"; }
done
echo "$n images comparées, $low sous 0,97 de ressemblance"
[ "$n" -gt 0 ] || { echo "ÉCHEC : aucune image filmée"; ok=0; }
[ "$low" -eq 0 ] || echo "À regarder : $OUT/gpu/$CLIP et $OUT/cpu/$CLIP (la carte lisse un peu autrement, c'est normal ; une image noire ne l'est pas)"
[ "$ok" = 1 ] && echo "OK : la machine GPU rend le jeu sur la carte" || exit 1
