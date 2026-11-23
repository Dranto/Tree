#!/usr/bin/env python3
"""Fabrique la police du jeu (godot/assets/fonts/CormorantGaramond-Herbier.ttf) à partir de
Cormorant Garamond variable (licence OFL, sans nom de police réservé).

Cormorant a un très petit œil (hauteur des minuscules) : à taille égale, ses textes sont 20 %
plus étroits et nettement moins lisibles que l'ancienne police (Inter). On agrandit donc tous les
glyphes de 20 % en réduisant unitsPerEm (1000 -> 833) : les mises en page gardent à peu près les
mêmes largeurs et les petits textes du HUD restent lisibles. Rien d'autre n'est modifié.

  pip install fonttools
  tools/font-herbier.py chemin/vers/CormorantGaramond[wght].ttf
Source : https://github.com/google/fonts/tree/main/ofl/cormorantgaramond
"""
import sys
from pathlib import Path
from fontTools.ttLib import TTFont

SCALE = 1.2
src = sys.argv[1]
dst = Path(__file__).resolve().parent.parent / "godot/assets/fonts/CormorantGaramond-Herbier.ttf"
f = TTFont(src)
f["head"].unitsPerEm = round(f["head"].unitsPerEm / SCALE)
for rec in f["name"].names:
    if rec.nameID in (1, 4, 16):
        rec.string = str(rec.toUnicode()).replace("Cormorant Garamond", "Cormorant Garamond Herbier")
    elif rec.nameID == 6:
        rec.string = str(rec.toUnicode()).replace("CormorantGaramond", "CormorantGaramondHerbier")
f.save(dst)
print("écrit", dst, "unitsPerEm", f["head"].unitsPerEm)
