#!/usr/bin/env python3
"""Régénère godot/tests/fixtures/saves/sauvegarde_v1.json … v9.json (test de migration, migration_test.gd).

Chaque fichier reprend le FORMAT que le jeu écrivait à cette version (voir l'historique de
godot/scripts/save_game.gd), avec un contenu reconnaissable. Les fichiers sont versionnés dans le dépôt :
ne relancer ce script que pour ajouter une version. Le test connaît le contenu attendu de chacun.
"""
import base64, json, os, struct, zlib

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "tests", "fixtures", "saves")


def png_gray(w, h, fn):
    raw = b"".join(b"\x00" + bytes(fn(x, y) for x in range(w)) for y in range(h))
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


# Carte de vie : une tache claire au centre d'une carte 50 × 50 (le jeu la redimensionne).
LIFE = base64.b64encode(png_gray(50, 50, lambda x, y: 220 if (x - 25) ** 2 + (y - 25) ** 2 < 150 else 0)).decode()
FLOWERS = [[10.0, 20.0, "ff0000", 1.2, 5], [-40.5, 66.0, "f2c75a", 0.9, 6], [300.0, -120.0, "7ac0ff", 1.0, 4]]
PLAYER = {"x": 321.0, "y": -654.0, "hp": 55.0}
CLOUD = ["spore:1:0", "c:spore:graines:a4", "key:cloud"]


def base(version, level, flags, allocated):
    return {
        "format": "seve-save", "version": version, "saved_at": 1763000000 + version,
        "game": {"level": level, "xp": 12.5 * version, "points": version, "kills": 100 * version, "flags": flags},
        "tree": {"allocated": allocated},
        "world": {"elapsed": 600.0 * version, "player": dict(PLAYER), "life_map": LIFE, "flowers": FLOWERS},
    }


def make():
    out = {}
    # v1 (format d'origine) : nœuds par uid, pas de choix ni de greffes ; « ronce:3:3 » n'existe plus.
    out[1] = base(1, 6, {"rencontre_gardien": True, "ronce_boss_vaincu": True, "fin_ronce_vue": True},
                  ["ronce:1:1", "ronce:2:2", "ronce:3:3", "ronce:99:0"])
    # v2 : choix (maîtrises) et greffes posées sur des emplacements de l'arbre.
    d = base(2, 9, {"rencontre_gardien": True, "ronce_boss_vaincu": True, "ronce_coeur_purifie": True, "fin_ronce_vue": True, "obj_boss": True},
             ["ronce:1:1", "ronce:2:2"] + CLOUD)
    d["tree"].update({"choices": {"ronce:4:3": "fouet_sanglant", "vent:6:3": "ruee_lourde"},
                      "grafts": {"ronce:4:2": "greffe_ecorce", "spore:3:0": "greffe_sillage", "ronce:5:5": "greffe_ecorce"}})
    out[2] = d
    # v3 : inventaire, greffes tombées au sol, points du boss et du Cœur.
    d = base(3, 12, {"ronce_boss_vaincu": True, "ronce_coeur_purifie": True, "points_ronce_boss": True, "points_ronce_coeur": True, "fin_ronce_vue": True, "fin_aventure_vue": True},
             ["ronce:1:1", "ronce:2:2"] + CLOUD)
    d["tree"].update({"choices": {"ronce:4:3": "fouet_lourd"}, "grafts": {"ronce:4:2": "greffe_ecorce"},
                      "inventory": ["greffe_ecorce", "greffe_mere", "greffe_inconnue"]})
    d["world"]["ground_grafts"] = [[100.0, 200.0, "greffe_tracante"], [-300.0, 80.0, "greffe_vorace"]]
    out[3] = d
    # v4 (plusieurs régions) : « <région>_fin_vue ».
    d = base(4, 20, {"ronce_boss_vaincu": True, "ronce_coeur_purifie": True, "ronce_fin_vue": True, "spore_boss_vaincu": True, "spore_coeur_purifie": True, "fin_aventure_vue": True},  # ancienne fin vue
             ["ronce:1:1", "ronce:2:2"] + CLOUD)
    d["tree"].update({"choices": {"ronce:4:3": "fouet_sanglant"}, "grafts": {"ronce:4:2": "greffe_ecorce", "spore:3:0": "greffe_sillage"},
                      "inventory": ["greffe_ecorce", "greffe_sillage"]})
    d["world"]["ground_grafts"] = [[100.0, 200.0, "greffe_tracante"]]
    out[4] = d
    # v5 (finale) : « fin_aventure_vue » veut dire « épilogue vu » ; ici la finale est vaincue : l'épilogue vu reste vu.
    d = base(5, 40, {"ronce_boss_vaincu": True, "ronce_coeur_purifie": True, "spore_boss_vaincu": True, "spore_coeur_purifie": True, "fin_aventure_vue": True, "finale_vaincue": True},
             ["ronce:1:1", "ronce:2:2"] + CLOUD)
    d["tree"].update({"choices": {"ronce:4:3": "fouet_sanglant"}, "grafts": {"ronce:4:2": "greffe_ecorce"}, "inventory": ["greffe_ecorce", "greffe_mere"]})
    d["world"]["ground_grafts"] = []
    out[5] = d
    # v6 (trois Cœurs par région) : un drapeau par Cœur.
    d = base(6, 55, {"ronce_boss_vaincu": True, "ronce_coeur1_purifie": True, "ronce_coeur2_purifie": True, "ronce_coeur3_purifie": True, "ronce_coeur_purifie": True,
                     "points_ronce_coeur": True, "spore_coeur1_purifie": True, "finale_vaincue": True, "fin_aventure_vue": True},
             ["ronce:1:1", "ronce:2:2"] + CLOUD)
    d["tree"].update({"choices": {"ronce:4:3": "fouet_lourd"}, "grafts": {"ronce:4:2": "greffe_ecorce", "spore:3:0": "greffe_sillage", "ronce:5:5": "greffe_mere"},
                      "inventory": ["greffe_ecorce", "greffe_sillage", "greffe_mere"]})
    d["world"]["ground_grafts"] = [[-50.0, -60.0, "greffe_vorace"]]
    out[6] = d
    # v7 (couronne de greffes) : plus de « grafts » dans l'arbre.
    d = base(7, 70, {"ronce_boss_vaincu": True, "ronce_coeur1_purifie": True, "ronce_coeur2_purifie": True, "ronce_coeur3_purifie": True, "ronce_coeur_purifie": True,
                     "spore_boss_vaincu": True, "spore_coeur1_purifie": True, "spore_coeur2_purifie": True, "spore_coeur3_purifie": True, "spore_coeur_purifie": True,
                     "finale_vaincue": True, "fin_aventure_vue": True, "plan_arbre": "ronce:4:3"},
             ["ronce:1:1", "ronce:2:2", "c:ronce-spore:dard:d1"] + CLOUD)
    d["tree"].update({"choices": {"ronce:4:3": "fouet_sanglant"}, "inventory": ["greffe_ecorce", "greffe_sillage", "greffe_mere"],
                      "crown": ["greffe_ecorce", "greffe_sillage", "", "greffe_mere"]})
    d["world"]["ground_grafts"] = [[10.0, 10.0, "greffe_tracante"]]
    out[7] = d
    # v8 (builds multiples) : trois emplacements, le premier actif.
    d = base(8, 80, dict(d["game"]["flags"]), ["ronce:1:1", "ronce:2:2", "c:ronce-spore:dard:d1"] + CLOUD)
    d["game"]["flags"]["plan_arbre"] = "ronce:4:3"
    d["tree"].update({"choices": {}, "inventory": ["greffe_ecorce", "greffe_sillage", "greffe_mere"], "crown": ["greffe_ecorce", "", "", ""],
                      "active_build": 1,
                      "builds": [{"name": "Épines", "allocated": ["ronce:1:1"], "choices": {}, "crown": ["greffe_mere", "", "", ""], "plan": "ronce:4:3"},
                                 {"allocated": ["ronce:1:1", "ronce:2:2", "c:ronce-spore:dard:d1"] + CLOUD, "choices": {}, "crown": ["greffe_ecorce", "", "", ""], "plan": "ronce:4:3"},
                                 {}]})
    d["world"]["ground_grafts"] = [[10.0, 10.0, "greffe_tracante"]]
    out[8] = d
    # v9 (New Game+) : deuxième cycle, couronne gardée du premier ; Cœurs et boss remis à zéro.
    d = base(9, 85, {"plan_arbre": "ronce:4:3", "tuto_deplacement": True, "couronne_vue": 6, "ronce_coeur1_purifie": True},
             ["ronce:1:1", "ronce:2:2", "c:ronce-spore:dard:d1"] + CLOUD)
    d["game"].update({"cycle": 2, "crown_kept": 6})
    d["tree"].update({"choices": {}, "inventory": ["greffe_ecorce", "greffe_sillage", "greffe_mere"],
                      "crown": ["greffe_ecorce", "greffe_sillage", "", "", "", "greffe_mere"], "active_build": 0,
                      "builds": [{"allocated": ["ronce:1:1", "ronce:2:2", "c:ronce-spore:dard:d1"] + CLOUD, "choices": {},
                                  "crown": ["greffe_ecorce", "greffe_sillage", "", "", "", "greffe_mere"], "plan": "ronce:4:3"}, {}, {}]})
    d["world"]["ground_grafts"] = []
    out[9] = d
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for v, d in make().items():
        with open(os.path.join(OUT, "sauvegarde_v%d.json" % v), "w") as f:
            json.dump(d, f, indent="\t", ensure_ascii=False, sort_keys=True)
            f.write("\n")
    print("ok")
