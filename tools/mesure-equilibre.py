#!/usr/bin/env python3
"""Met en tableaux les lignes MESURE* des journaux de tools/mesure-equilibre.sh (jalon 14.5, lot B).

    tools/mesure-equilibre.py godot/autotest/mesure/graine-*.log > rapport.md

Aucune valeur de jeu n'est changée : ce script ne fait que lire des journaux.
"""
import re
import statistics
import sys
from collections import defaultdict

KV = re.compile(r"(\w+)=(\S+)")


def parse(path):
    seg, boss, lvl = [], [], []
    name = path.split("/")[-1]
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if not line.startswith("MESURE"):
                continue
            kind = line.split()[0]
            d = {k: v for k, v in KV.findall(line)}
            (boss if kind == "MESUREBOSS" else lvl if kind == "MESURENIVEAU" else seg).append(d)
    return name, seg, boss, lvl


def num(d, k):
    v = d.get(k, "-1")
    try:
        return float(v)
    except ValueError:
        return -1.0


def fmt(v, nd=1, unit=""):
    return "–" if v < 0 else f"{v:.{nd}f}{unit}"


def med(vals):
    vals = [v for v in vals if v >= 0]
    return statistics.median(vals) if vals else -1.0


def main(paths):
    runs = [parse(p) for p in paths]
    print("# Mesure d'équilibrage — robot d'aventure\n")
    print("Passages : " + ", ".join(f"`{n}`" for n, *_ in runs) + "\n")
    print("## Par région et par passage\n")
    print("| Passage | Région | Build | Durée (s) | Niveau | Morts | Vie perdue / min (part de la vie max) | Part commun / élite / boss / distance | Chemin (px/s) | Contact / fuite / libre | TTK commun méd. (s) | Élites tuées / vues | TTK élite méd. / p90 (s) |")
    print("|" + " --- |" * 13)
    for name, seg, _, _ in runs:
        v = re.search(r"variante-(\d+)", name)
        tag = "v" + (v.group(1) if v else "?")
        for d in seg:
            print("| {} | {} | {} | {:.0f} | {} | {:.0f} | {} ({}) | {} / {} / {} / {} | {} | {} / {} / {} | {} | {:.0f} / {:.0f} | {} / {} |".format(
                tag, d["region"], d["build"], num(d, "temps"), d["niveau"], num(d, "morts"),
                fmt(num(d, "vie_perdue_par_min"), 0), fmt(num(d, "vie_max_par_min") * 100, 0, " %"),
                fmt(num(d, "part_commun") * 100, 0, " %"), fmt(num(d, "part_elite") * 100, 0, " %"),
                fmt(num(d, "part_boss") * 100, 0, " %"), fmt(num(d, "part_distance") * 100, 0, " %"),
                fmt(num(d, "chemin_px_s"), 0),
                fmt(num(d, "part_contact") * 100, 0, " %"), fmt(num(d, "part_fuite") * 100, 0, " %"), fmt(num(d, "part_libre") * 100, 0, " %"),
                fmt(num(d, "ttk_commun_med"), 2), num(d, "elites_tuees"), num(d, "elites_vues"),
                fmt(num(d, "ttk_elite_med"), 1), fmt(num(d, "ttk_elite_p90"), 1)))
    print("\n## Combats de boss\n")
    print("| Passage | Région | Niveau | Durée du combat (s) | Vie perdue | Morts |")
    print("| --- | --- | --- | --- | --- | --- |")
    for name, _, boss, _ in runs:
        v = re.search(r"variante-(\d+)", name)
        for b in boss:
            print("| v{} | {} | {} | {} | {} | {} |".format(v.group(1) if v else "?", b["region"], b["niveau"], b["duree"], b["vie_perdue"], b["morts"]))
    # Moyennes par région sur tous les passages.
    by = defaultdict(list)
    for _, seg, _, _ in runs:
        for d in seg:
            by[d["region"]].append(d)
    print("\n## Moyennes par région (tous passages)\n")
    print("| Région | Passages | Morts (moy.) | Vie perdue / min (part de la vie max) | Part boss | Fuite | Contact | TTK élite méd. (s) | Combat de boss méd. (s) |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    bosses = defaultdict(list)
    for _, _, boss, _ in runs:
        for b in boss:
            bosses[b["region"]].append(float(b["duree"]))
    for r, ds in by.items():
        print("| {} | {} | {:.1f} | {} | {} | {} | {} | {} | {} |".format(
            r, len(ds), statistics.mean(num(d, "morts") for d in ds),
            fmt(statistics.mean(num(d, "vie_max_par_min") for d in ds) * 100, 0, " %"),
            fmt(statistics.mean(num(d, "part_boss") for d in ds) * 100, 0, " %"),
            fmt(statistics.mean(num(d, "part_fuite") for d in ds) * 100, 0, " %"),
            fmt(statistics.mean(num(d, "part_contact") for d in ds) * 100, 0, " %"),
            fmt(med([num(d, "ttk_elite_med") for d in ds]), 1),
            fmt(med(bosses[r]), 0)))
    print("\n## Niveau et points d'arbre au fil de l'aventure\n")
    print("Passage ; à chaque palier de 5 niveaux : niveau, points gagnés au total (niveaux + points hors niveau), dont hors niveau (boss, Cœur, autel, secret, quête), nœuds appris, menace d'un ennemi à mi-profondeur.\n")
    print("| Passage | Temps (s) | Région | Niveau | Points gagnés | dont hors niveau | Nœuds appris | Menace |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for name, _, _, lvl in runs:
        v = re.search(r"variante-(\d+)", name)
        last = None
        for l in lvl:
            n = int(l["niveau"])
            last = l
            if n % 5 == 0 or n == 1:
                print("| v{} | {} | {} | {} | {} | {} | {} | {} |".format(v.group(1) if v else "?", l["t"], l["region"], n, l["points_gagnes"], l["points_hors_niveau"], l["noeuds"], l["menace"]))
        if last is not None and int(last["niveau"]) % 5 != 0:
            l = last
            print("| v{} | {} | {} | {} | {} | {} | {} | {} |".format(v.group(1) if v else "?", l["t"], l["region"], l["niveau"], l["points_gagnes"], l["points_hors_niveau"], l["noeuds"], l["menace"]))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
