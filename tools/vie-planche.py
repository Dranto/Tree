#!/usr/bin/env python3
"""Compose les planches de la faune et des formes guéries (tests/vie/planche.gd) : un PNG par région avec
légendes, en couleur, en niveaux de gris et dans un mode daltonien.
  tools/vie-planche.py <dossier des rangées> <dossier de sortie>"""
import glob, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageOps

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
FONT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "fonts", "CormorantGaramond-Herbier.ttf")
f_big, f_mid, f_small = (ImageFont.truetype(FONT, s) for s in (46, 28, 20))
BG = (31, 26, 22)
NOMS = {"commun": "Flétris communs", "ronce": "Ronce", "spore": "Spore", "vent": "Vent", "seve": "Sève", "aube": "Aube", "racine": "Racine"}


def planche(region, mode, gris=False):
    rows = sorted(glob.glob(f"{src}/{region}_gueri_*_{mode}.png")) + sorted(glob.glob(f"{src}/{region}_faune_*_{mode}.png"))
    if not rows:
        return None
    w = Image.open(rows[0]).width
    H = 130 + sum(Image.open(r).height + 4 for r in rows) + 10
    im = Image.new("RGB", (w + 230, H), BG)
    d = ImageDraw.Draw(im)
    titre = f"Formes guéries et faune : {NOMS[region]}" + (" (niveaux de gris)" if gris else "") + (f" (mode {mode})" if mode != "aucun" else "")
    d.text((20, 10), titre, font=f_big, fill=(231, 207, 140))
    d.text((20, 66), "Gauche : le Flétri sur sol flétri. Puis la forme guérie au repos, en marche, et à la taille réelle en 1080p (Flétri puis guérie) ; la faune : ses poses, puis la taille réelle.", font=f_small, fill=(200, 190, 170))
    heads = ["Flétri", "Guérie : repos", "Guérie : marche", "Taille réelle 1080p"]
    for i, h in enumerate(heads):
        d.text((230 + 250 * i + 10, 100), h, font=f_mid, fill=(240, 232, 212))
    y = 130
    for r in rows:
        nom = os.path.basename(r).split("_")[3] if "_gueri_" in r else os.path.basename(r).split("_")[3]
        genre = "forme guérie" if "_gueri_" in r else "faune"
        tile = Image.open(r).convert("RGB")
        if gris:
            tile = ImageOps.grayscale(tile).convert("RGB")
        im.paste(tile, (230, y))
        d.text((12, y + 100), nom.replace("-", " "), font=f_mid, fill=(240, 232, 212))
        d.text((12, y + 134), genre, font=f_small, fill=(170, 160, 140))
        y += tile.height + 4
    return im


for region in NOMS:
    for mode, gris, suffix in (("aucun", False, ""), ("aucun", True, "_gris"), ("deuteranopie", False, "_deuteranopie")):
        im = planche(region, mode, gris)
        if im:
            im.save(f"{out}/{region}{suffix}.png")
print("planches dans", out)
