#!/usr/bin/env python3
"""Page d'écoute des sons : inventaire + .ogg + page HTML, prêts à publier en Artifact.

Une ligne par élément sonore (bruitage et ses variantes, couche de musique, nappe d'ambiance,
événement d'ambiance seul, nappe sans ses événements), jouable seule, avec QUAND le jeu la joue.
Ne touche à aucun fichier du jeu : tout est écrit dans le dossier de sortie.

    tools/ecoute.py [dossier_de_sortie]        (défaut : ecoute-sortie/ à la racine du dépôt)

Produit : index.html (tools/ecoute-page.html), inventaire.json, sons.ogg (tous les .ogg bout à bout, découpés par
la page d'après off/len) et audio/**/*.ogg (les mêmes, un par fichier).
Prérequis : python3, ffmpeg, et tools/godot.sh pour rendre les événements d'ambiance
(godot/tools/ecoute_events.gd). Sans Godot, ces lignes sont simplement absentes.

Un son ajouté dans synth.gd apparaît tout seul (« à décrire » tant qu'il n'a pas de texte dans QUAND).
Les textes « quand » ci-dessous sont écrits à la main d'après les appels du jeu ; l'outil vérifie
seul quels sons sont réellement appelés (colonne « non utilisé »).
"""
import concurrent.futures
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, "godot")
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, "ecoute-sortie")

REGIONS = {
    "ronce": "Ronce", "spore": "Spore", "vent": "Vent", "seve": "Sève", "aube": "Aube", "racine": "Racine",
    "finale": "Finale", "generique": "Générique", "monde": "Tout le jeu",
}
BOSSES = {
    "ronce": "la Mère-Ronce", "spore": "l'Amanite-Mère", "vent": "le Harfang de cendre", "seve": "le Saule exsangue",
    "aube": "la Phalène de verre", "racine": "l'Ancien pétrifié", "finale": "la Flétrissure",
}
FAMILLES = ["combat", "competences", "heros", "monde", "interface", "boss", "musique", "ambiance"]

# --- Textes « quand » des bruitages : (famille, région, quand, précision) -----------------------------------
QUAND = {
    # Combat
    "tir": ("combat", "monde", "Un tir de l'attaque automatique, pour les formes à projectile qui n'ont pas de son à elles : Graines, Échardes, Ronces vives, Spores lobées, Dards fongiques, Lames de vent.", "Son le plus entendu du jeu : un tir toutes les fractions de seconde."),
    "impact": ("combat", "monde", "Un coup touche un ennemi (coup normal). C'est aussi le son de secours d'un son de région qui manquerait.", "Un ennemi qui a son propre son de coup (Termite, Mandragore, Scarabée, Tertre) ne joue pas celui-ci."),
    "impact_lourd": ("combat", "monde", "", "Prévu pour les gros coups. Aucun code ne l'appelle encore."),
    "critique": ("combat", "monde", "Un coup critique touche un ennemi.", "Le Scarabée perce-écorce a le sien (racine_scarabee_crit)."),
    "mort": ("combat", "monde", "Un ennemi ordinaire meurt.", "Termite, Mandragore, Scarabée et Tertre ont leur propre son de mort."),
    "mort_elite": ("combat", "monde", "Une élite meurt (gerbe d'essences).", "Baisse un instant la musique (duck)."),
    "degats": ("heros", "monde", "Le héros prend un coup.", ""),
    "etourdi": ("heros", "monde", "Le héros est étourdi (anneau doré à l'écran) après une punition.", ""),
    "chute": ("heros", "monde", "Le héros tombe, puis renaît au sanctuaire.", "Long, grave ; baisse la musique."),
    "esquive": ("heros", "monde", "Le héros fait une esquive (glissade).", "Joué par le héros lui-même, jamais par un ennemi."),
    # Compétences de Ronce et du socle
    "nova": ("competences", "ronce", "Compétence Couronne d'épines lancée.", "Refait le 25/11 : Une couronne d'épines qui jaillit en cercle (crépitement d'épines qui s'ouvre), un coup de violoncelles graves et un pizz de contrebasse. Aussi le son de secours de Bouclier d'écorce (Racine) sur son onde."),
    "nuage": ("combat", "ronce", "Un nuage de spores éclate : explosion d'un Boursouflé, ou nuage de l'Amanite-Mère.", ""),
    "floraison": ("competences", "seve", "Compétence Floraison lancée ; aussi quand le héros entre dans un sanctuaire (il s'allume).", "Refait le 25/11 : La fleur s'ouvre en arpège de kalimba, un souffle de chœur et un froissement de pétales. Secours de la Fontaine de sève."),
    "fouet": ("competences", "ronce", "Compétence Fouet de ronce lancée ; aussi l'attaque de base « Fouet » (corps à corps).", "Refait le 25/11 : La tige fend l'air (souffle qui monte) puis claque sec au bout, avec un pizz grave."),
    "racines": ("competences", "ronce", "Compétence Racines voraces lancée.", "Refait le 25/11 : La terre gronde, le bois craque en remontant, des racines grincent. Secours des sons de Racine (écorce, ancrage, pieux)."),
    "volee": ("competences", "ronce", "Compétence Volée d'épines lancée.", "Refait le 25/11 : Une salve d'épines qui sifflent en partant, l'arc de ronce qui vibre."),
    "saignee": ("competences", "ronce", "Compétence Saignée lancée.", "Refait le 25/11 : Un violoncelle qui gémit au demi-ton, un battement sourd, la sève aspirée. Secours de Liane buveuse."),
    "annonce": ("boss", "monde", "Un boss annonce une attaque : le coup va partir (marque au sol).", "Joué par chaque boss à chaque attaque annoncée. Refait le 25/11 : c'est maintenant le son grave de l'ancienne « annonce_boss »."),
    "annonce_boss": ("boss", "monde", "", "Prévu pour une annonce plus grave de boss. Aucun code ne l'appelle encore."),
    "noeud": ("interface", "monde", "Un nœud de l'arbre est pris (point dépensé), ou une greffe est posée dans l'arbre.", ""),
    "niveau": ("heros", "monde", "Le héros monte d'un niveau, ou termine un objectif.", ""),
    "coeur": ("monde", "monde", "Un Cœur est purifié (région libérée) ; à l'autel ; au dernier Cœur, la fin du monde reverdi.", "Baisse la musique."),
    "ramasse": ("monde", "monde", "Le héros ramasse une essence (sève, expérience).", "Plus aigu à chaque ramassage enchaîné (jusqu'à 10 de suite)."),
    "greffe": ("monde", "monde", "Le héros ramasse une greffe tombée au sol.", ""),
    "seve": ("monde", "monde", "Le héros retrouve la sève qu'il avait perdue en tombant.", ""),
    "clic": ("interface", "monde", "Un bouton est cliqué (menus, options, arbre).", ""),
    "survol": ("interface", "monde", "Un bouton ou un nœud est survolé, ou le curseur se déplace dans l'arbre à la manette.", ""),
    # Spore
    "spore_eclat": ("competences", "spore", "Compétence Vesse-de-loup : la vesse éclate.", "Refait le 25/11 : La vesse crève (pouf mou), un nuage qui s'étale, des bulles. Joué à l'endroit de l'éclatement."),
    "spore_nuage": ("competences", "spore", "Compétence Nuage de spores lancée.", "Refait le 25/11 : Un souffle mou qui gonfle, des bulles qui montent, un marimba mouillé en écho."),
    "spore_propage": ("competences", "spore", "Compétence Essaim lancée (le poison se propage).", "Refait le 25/11 : Un bourdonnement grave d'insectes mous qui s'envolent, quelques notes de marimba."),
    "spore_piege": ("competences", "spore", "Compétence Vesse-de-loup : la vesse est posée.", "Refait le 25/11 : Un champignon mou qui s'enfonce dans la terre, glouglou."),
    "spore_toxine": ("competences", "spore", "Compétence Éclosion lancée.", "Refait le 25/11 : Une poche de toxine qui fermente et éclate en bulles, marimba qui descend (phrygien)."),
    "spore_flaque": ("competences", "spore", "", "Prévu (flaque toxique). Aucun code ne l'appelle encore."),
    "spore_division": ("competences", "spore", "", "Prévu (division de spores). Aucun code ne l'appelle encore."),
    # Vent
    "vent_lame": ("competences", "vent", "", "Prévu (lame de vent). Aucun code ne l'appelle encore."),
    "vent_rafale": ("competences", "vent", "", "Prévu (rafale). Aucun code ne l'appelle encore."),
    "vent_tornade": ("competences", "vent", "Compétence Tornade lancée.", "Refait le 25/11 : Un tourbillon (souffle qui tourne), la flûte qui monte et retombe, des herbes arrachées."),
    "vent_ruee": ("competences", "vent", "Compétence Ruée lancée.", "Refait le 25/11 : Le héros fend l'air (souffle qui passe), un battement de plumes."),
    "vent_appel": ("competences", "vent", "Compétence Appel d'air lancée.", "Refait le 25/11 : L'air est aspiré vers le héros (souffle qui gonfle à l'envers), la flûte souffle une quinte."),
    "vent_plongeon": ("combat", "vent", "", "Prévu (plongeon du Piqueur). Aucun code ne l'appelle encore."),
    "vent_repousse": ("combat", "vent", "", "Prévu (repousse). Aucun code ne l'appelle encore."),
    # Sève
    "seve_goutte": ("combat", "seve", "Un tir de l'attaque de base Perles de sève.", ""),
    "seve_pousse": ("competences", "seve", "", "Prévu (pousse). Aucun code ne l'appelle encore."),
    "seve_soin": ("competences", "seve", "Compétence Cocon de sève lancée (le cocon soigne).", "Refait le 25/11 : La sève s'enroule autour du héros (cor chaud), des gouttes de kalimba, un glouglou."),
    "seve_source": ("competences", "seve", "Compétence Fontaine de sève lancée.", "Refait le 25/11 : Une source qui jaillit, des gouttes en arpège, un orgue de bois."),
    "seve_eclosion": ("competences", "seve", "Compétence Cocon de sève : le cocon éclôt.", "Refait le 25/11 : Le cocon s'ouvre comme une fleur : un éclat mou, un accord de kalimba et de cor."),
    "seve_lien": ("competences", "seve", "Compétence Liane buveuse lancée.", "Refait le 25/11 : Une liane qui se tend comme un élastique, le bois qui grince, la sève qui coule."),
    # Racine
    "racine_ecorce": ("competences", "racine", "Compétence Bouclier d'écorce lancée.", "Refait le 25/11 : L'écorce se referme autour du héros : craquements de bois, un coup sourd, un violoncelle."),
    "racine_ancrage": ("competences", "racine", "Compétence Ancrage lancée.", "Refait le 25/11 : Le héros s'ancre : une pierre qui tombe lourdement, la terre qui gronde, du gravier."),
    "racine_pieux": ("competences", "racine", "Compétence Pieux lancée.", "Refait le 25/11 : Trois pieux de bois qui percent la terre l'un après l'autre."),
    "racine_massue": ("combat", "racine", "Un coup de l'attaque de base Massue de bois.", ""),
    "racine_termite_hit": ("combat", "racine", "Un Termite de cendre est touché.", ""),
    "racine_termite_death": ("combat", "racine", "Un Termite de cendre meurt.", ""),
    "racine_mandragore_hit": ("combat", "racine", "Une Mandragore est touchée.", ""),
    "racine_mandragore_death": ("combat", "racine", "Une Mandragore meurt.", ""),
    "racine_mandragore_jaillit": ("combat", "racine", "Une Mandragore jaillit du sol sous le héros.", ""),
    "racine_scarabee_hit": ("combat", "racine", "Un Scarabée perce-écorce est touché.", ""),
    "racine_scarabee_crit": ("combat", "racine", "Un Scarabée perce-écorce reçoit un coup critique.", ""),
    "racine_scarabee_death": ("combat", "racine", "Un Scarabée perce-écorce meurt.", ""),
    "racine_tertre_hit": ("combat", "racine", "Un Tertre de pierre est touché.", ""),
    "racine_tertre_death": ("combat", "racine", "Un Tertre de pierre meurt.", ""),
    "racine_tertre_frappe": ("combat", "racine", "Un Tertre de pierre frappe le sol.", ""),
    # Aube
    "aube_rayon": ("combat", "aube", "Un tir de l'attaque de base Rayon d'aube.", ""),
    "aube_eclat": ("competences", "aube", "", "Prévu (éclat). Aucun code ne l'appelle encore."),
    "aube_halo": ("competences", "aube", "", "Prévu (halo). Aucun code ne l'appelle encore."),
    "aube_levant": ("competences", "aube", "Compétence Lance d'aube lancée.", "Refait le 25/11 : La lumière se charge (verre qui monte), la lance part (souffle) et frappe (cloche)."),
    "aube_cloche": ("competences", "aube", "Compétence Prisme lancée.", "Refait le 25/11 : Un éclat de lumière tiré par le prisme : une lame de verre qui tinte."),
    "aube_nova": ("competences", "aube", "Compétence Aurore lancée.", "Refait le 25/11 : L'aube éclate autour du héros : un accord de verres qui s'ouvre, des cloches, un grave."),
}
BOSS_MOMENT = {
    "eveil": "Le combat contre {b} commence (le boss s'éveille dans son arène).",
    "phase": "{B} change de phase (à 66 % puis 33 % de sa vie).",
    "mort": "{B} est vaincu.",
}
for _r, _b in BOSSES.items():
    for _k, _t in BOSS_MOMENT.items():
        QUAND["%s_boss_%s" % (_r, _k)] = ("boss", _r, _t.format(b=_b, B=_b[0].upper() + _b[1:]), "Baisse la musique." if _k != "phase" else "")

LAYER_QUAND = {
    "sombre": "Exploration en terre flétrie : plein volume quand la vie du sol sous le héros est inférieure à 15 %. Entre 15 % et 60 %, fondu vers « lumineux ».",
    "lumineux": "Exploration en terre vivante : plein volume quand la vie du sol dépasse 60 %. Entre 15 % et 60 %, fondu depuis « sombre ».",
    "combat": "Des Flétris sont à moins de 560 px du héros (une élite compte pour 3) : la couche monte jusqu'à plein volume à 6 Flétris, et reste 4 s après le dernier. Les couches d'exploration baissent de 35 % au maximum.",
    "coeur": "Le siège d'un Cœur : le héros est à moins de 1,3 fois le rayon de la zone du Cœur assiégé. Les couches d'exploration baissent de moitié.",
    "boss": "Combat de boss (le héros est dans l'arène). C'est la seule couche entendue : tout le reste est coupé en fondu.",
}
SPECIAL_LAYER = {
    ("generique", "lumineux"): "La fin jouée dans le monde (le générique) : Music.set_mood(1.0, « generique »), la seule couche de cette « région ».",
}
EVENT_DESC = {
    "bird": ("Gazouillis d'oiseau : 2 à 5 petits glissés aigus.", "alive"),
    "cricket": ("Grillon : six petits crissements aigus.", "alive"),
    "drip": ("Goutte d'eau : un « plic » qui descend.", "any"),
    "bubble": ("Bulle de vase : un « bloup » qui monte.", "any"),
    "creak": ("Bois qui grince : grave, hésitant, 0,4 à 0,8 s.", "dead"),
    "chime": ("Carillon : une cloche claire, longue de 2 s.", "any"),
    "rustle": ("Froissement de feuilles ou d'herbes sèches.", "any"),
    "knock": ("Coup sourd sur du bois.", "any"),
    "frog": ("Coassement : trois coups graves.", "any"),
}
ETAT = {"mort": "terre flétrie", "vif": "terre vivante"}
ADJ = {"mort": "flétrie", "vif": "vivante"}

# --- Lecture du code ------------------------------------------------------------------------------------------


TONS = {"flute": "flûte", "clarinet": "clarinette", "horn": "cor", "brass": "cuivres graves", "horns": "pupitre de cors", "cello": "violoncelle", "glass": "harmonica de verre",
        "pizz": "contrebasse et violoncelles pizzicato", "harp": "harpe", "marimba": "marimba", "kalimba": "kalimba", "glock": "glockenspiel", "piano": "piano feutré"}
KITS = {"frame": "tambours sur cadre", "taiko": "taikos", "wood": "tambours de bois", "metal": "grosse caisse et petits gongs", "water": "percussions d'eau"}


def _instruments(reg, layer):
    """Nouveaux instruments de la couche (refonte du 25/11), d'après data/audio.json et music_synth.gd › DEFAULTS."""
    a = json.load(open(os.path.join(GODOT, "data", "audio.json")))["regions"].get(reg, {}).get("music", {})
    d = {"bright": {"arp": "pizz", "lead_tone": "cello", "counter_tone": "horn"}, "boss": {"lead_tone": "horns", "counter_tone": "cello", "kit": "taiko"}, "combat": {"kit": "frame"}}
    sec = {"sombre": "dark", "lumineux": "bright", "combat": "combat", "coeur": "heart", "boss": "boss"}[layer]
    st = dict(d.get(sec, {}))
    st.update(a.get(sec, {}))
    br = dict(d["bright"]); br.update(a.get("bright", {}))
    PADS = {"saw": "nappe de cordes douces", "reed": "nappe d'anches", "air": "nappe de flûtes", "organ": "orgue de bois", "glass": "nappe de verres", "bow": "section de cordes"}
    pad = PADS[a.get("dark", {}).get("pad_tone", "saw")]
    arp, lead, cnt = TONS[br["arp"]], TONS[br["lead_tone"]], TONS[br["counter_tone"]]
    osti = "cordes en spiccato" if br["arp"] == "pizz" else arp
    if layer == "sombre":
        t = "%s, bourdon, cloche grave, notes éparses (%s) ; en B, %s" % (pad, arp, "des violoncelles montent" if a.get("dark", {}).get("pad_tone", "saw") in ["saw", "bow"] else "la contre-voix (%s) tient l'accord" % cnt)
    elif layer == "lumineux":
        t = "arpège : %s ; mélodie : %s ; en B, la mélodie varie et une contre-voix (%s) l'harmonise, cordes" % (arp, lead, cnt)
    elif layer == "combat":
        t = "%s, contrebasse, ostinato (%s) ; en B, toms, accords (%s) et roulement" % (KITS[st["kit"]], osti, cnt)
    elif layer == "coeur":
        t = "chœur, battement de cœur, %s ; en B, cordes et la mélodie du thème (%s)" % (lead, arp)
    else:
        t = "%s fournis, ostinato (%s), accords de cuivres graves, chœur, gong ; mélodie : %s ; contre-voix en B : %s" % (KITS[st["kit"]], osti, TONS[st["lead_tone"]], TONS[st["counter_tone"]])
    return "Boucle de 24 s (thème A puis variation B). Instruments : " + t + "."


def read(path):
    with open(os.path.join(GODOT, path), encoding="utf-8") as f:
        return f.read()


def parse_sounds():
    """Nom, variantes, crête, duck de chaque son de synth.gd › SOUNDS."""
    src = read("scripts/synth.gd")
    body = src[src.index("const SOUNDS := {"):src.index("## Noms de fichiers d'un son")]
    out = []
    for m in re.finditer(r'^\t"([a-z_0-9]+)": \{(.*)$', body, re.M):
        head = m.group(2)
        g = lambda k, d: float(re.search(r'"%s": ([0-9.]+)' % k, head).group(1)) if re.search(r'"%s": ([0-9.]+)' % k, head) else d
        out.append({"name": m.group(1), "variants": int(g("variants", 1)), "peak": g("peak", 0.6), "duck": g("duck", 0.0)})
    return out


CALL = re.compile(r'([Ss]fx\.play\(|\bs\.play\(|_sfx\(|\.sound\(|\bsnd\b|"sound[a-z_]*"|"sfx")')
SKIP_FILES = ("synth.gd", "gen_sounds.gd", "check_data.gd", "sound_refs.gd", "sfx.gd", "music.gd", "region_audio.gd")


def find_refs(names):
    """Appels réels de chaque son : lignes des scripts ou des données qui le nomment dans un appel de son."""
    refs = {n: [] for n in names}
    files = [f for f in glob.glob(os.path.join(GODOT, "scripts", "**", "*.gd"), recursive=True)
             if os.path.basename(f) not in SKIP_FILES]
    files += glob.glob(os.path.join(GODOT, "data", "**", "*.json"), recursive=True)
    pats = {n: re.compile(r'"%s"' % re.escape(n)) for n in names}
    for f in sorted(files):
        rel = os.path.relpath(f, GODOT)
        is_json = f.endswith(".json")
        with open(f, encoding="utf-8", errors="ignore") as fh:
            for i, line in enumerate(fh, 1):
                if '"' not in line:
                    continue
                if is_json:
                    if not re.search(r'"(sound[a-z_]*|sfx|eveil|phase|mort)"\s*:\s*"[a-z_0-9]+"', line):
                        continue
                elif line.lstrip().startswith("#") or not CALL.search(line):
                    continue
                for n, p in pats.items():
                    if p.search(line) and not (is_json and re.search(r'"(eveil|phase|mort)"\s*:\s*"%s"' % n, line) is None and re.search(r'"(eveil|phase|mort)"\s*:', line)):
                        refs[n].append("%s:%d" % (rel, i))
    return refs


def unknown_sound_refs(names):
    """Sons nommés dans les données mais absents de SOUNDS (jamais joués : le jeu les ignore sans bruit)."""
    known = set(names)
    out = []
    for f in sorted(glob.glob(os.path.join(GODOT, "data", "**", "*.json"), recursive=True)):
        with open(f, encoding="utf-8") as fh:
            for i, line in enumerate(fh, 1):
                m = re.search(r'"(sound[a-z_]*|sfx)"\s*:\s*"([a-z_0-9]+)"', line)
                if m and m.group(2) not in known:
                    out.append("%s:%d (« %s » : %s)" % (os.path.relpath(f, GODOT), i, m.group(1), m.group(2)))
    return out


def wav_seconds(path):
    try:
        with wave.open(path) as w:
            return round(w.getnframes() / w.getframerate(), 2)
    except Exception:
        return 0.0


def music_const(name, default):
    m = re.search(r"const %s := ([0-9.]+)" % name, read("scripts/music.gd"))
    return float(m.group(1)) if m else default


# --- Conversion ------------------------------------------------------------------------------------------------


def to_ogg(jobs):
    def run(job):
        src, dst = job
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-c:a", "libvorbis", "-q:a", "3", dst])
        return r.returncode
    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
        bad = [j for j, rc in zip(jobs, ex.map(run, jobs)) if rc != 0]
    if bad:
        sys.exit("ffmpeg a échoué sur : " + ", ".join(b[0] for b in bad))


def render_events(tmp):
    os.makedirs(tmp, exist_ok=True)
    script = os.path.join(ROOT, "tools", "godot.sh")
    if not os.path.isdir(os.path.join(GODOT, ".godot")):
        subprocess.run([script, "--headless", "--import"], capture_output=True, timeout=900)
    try:
        r = subprocess.run([script, "--headless", "-s", "res://tools/ecoute_events.gd", "--", tmp], capture_output=True, text=True, timeout=600)
        if "ECOUTE" not in r.stdout:
            print("Événements d'ambiance non rendus :", r.stdout[-300:], r.stderr[-300:], file=sys.stderr)
    except Exception as e:  # Godot absent : la page se passe de ces lignes
        print("Événements d'ambiance non rendus :", e, file=sys.stderr)
    return tmp


# --- Inventaire ------------------------------------------------------------------------------------------------


def build():
    audio = json.load(open(os.path.join(GODOT, "data", "audio.json"), encoding="utf-8"))["regions"]
    sounds = parse_sounds()
    names = [s["name"] for s in sounds]
    refs = find_refs(names)
    items, jobs = [], []
    tmp = os.path.join(OUT, "_tmp")

    def add(item, wav):
        ogg = "audio/%s/%s.ogg" % (item["kind"], item["file"])
        item["audio"] = ogg
        item["duree"] = wav_seconds(wav)
        jobs.append((wav, os.path.join(OUT, ogg)))
        items.append(item)

    # Bruitages
    for s in sounds:
        n = s["name"]
        fam, reg, quand, prec = QUAND.get(n, ("monde", "monde", "", "À décrire : ce son n'a pas encore de texte dans tools/ecoute.py."))
        used = bool(refs[n])
        files = [n] + ["%s__%d" % (n, v) for v in range(2, s["variants"] + 1)]
        for vi, fn in enumerate(files):
            add({
                "id": "sfx-" + fn, "kind": "sfx", "name": n, "file": fn, "famille": fam, "region": reg,
                "titre": n if vi == 0 else "%s (variante %d)" % (n, vi + 1),
                "variante": "%d/%d" % (vi + 1, len(files)) if len(files) > 1 else "",
                "quand": quand or "Aucun code du jeu n'appelle ce son.",
                "precision": prec, "utilise": used, "refs": refs[n], "boucle": False,
                "fichier": "assets/sounds/%s.wav" % fn, "crete": s["peak"], "duck": s["duck"],
                "groupe": n,
            }, os.path.join(GODOT, "assets", "sounds", fn + ".wav"))

    # Musique : une ligne par fichier .wav de assets/music
    layers = {"sombre": "Exploration, terre flétrie", "lumineux": "Exploration, terre vivante", "combat": "Combat",
              "coeur": "Siège d'un Cœur", "boss": "Boss"}
    for f in sorted(glob.glob(os.path.join(GODOT, "assets", "music", "*.wav"))):
        base = os.path.basename(f)[:-4]
        m = re.match(r"(?:([a-z]+)_)?(sombre|lumineux|combat|coeur|boss)$", base)
        if not m:
            continue
        reg = m.group(1) or "ronce"
        layer = m.group(2)
        style = audio.get(reg, {}).get("_doc", "")
        quand = SPECIAL_LAYER.get((reg, layer), LAYER_QUAND[layer])
        add({
            "id": "mus-" + base, "kind": "mus", "name": base, "file": base, "famille": "musique", "region": reg,
            "titre": "%s · %s" % (REGIONS[reg] if m.group(1) else "Ronce (le monde)", layers[layer]),
            "variante": "", "quand": quand,
            "precision": ("Ronce n'a pas de préfixe : ces cinq couches sont aussi la musique de tout lieu hors région. " if not m.group(1) else "")
                         + _instruments(reg, layer),
            "utilise": True, "refs": ["scripts/music.gd", "scripts/main.gd:443"], "boucle": True, "couche": layer,
            "fichier": "assets/music/%s.wav" % base, "groupe": reg,
        }, f)

    # Ambiance : nappes complètes
    def bed_text(reg, state):
        bed = audio.get(reg, {}).get("bed", {})
        sec = bed.get("dead" if state == "mort" else "alive", {})
        ev = ", ".join("%s (%s par boucle de 12 s)" % (e["kind"], round(e.get("rate", 0.2) * 12)) for e in sec.get("events", []))
        base = [k for k in ("wind", "stream", "waves", "rumble") if sec.get(k, 0) > 0]
        lab = {"wind": "vent", "stream": "ruisseau", "waves": "vagues", "rumble": "grondement"}
        return ", ".join(lab[k] for k in base), ev

    for f in sorted(glob.glob(os.path.join(GODOT, "assets", "ambience", "*.wav"))):
        base = os.path.basename(f)[:-4]
        m = re.match(r"(?:([a-z]+)_)?(mort|vif)$", base)
        reg = m.group(1) or "ronce"
        state = m.group(2)
        cont, ev = bed_text(reg, state)
        add({
            "id": "amb-" + base, "kind": "amb", "name": base, "file": base, "famille": "ambiance", "region": reg,
            "titre": "%s · nappe %s" % (REGIONS[reg] if m.group(1) else "Ronce (le monde)", ETAT[state]),
            "variante": "",
            "quand": "Sous les pas du héros dans la région {r}, quand la terre est {e} : plein volume {v}, fondu entre les deux de 15 % à 60 % de vie du sol. Baisse de 45 % pendant un combat de boss.".format(
                r=REGIONS[reg], e=ADJ[state], v="en dessous de 15 % de vie" if state == "mort" else "au-dessus de 60 % de vie"),
            "precision": "Contient : %s. Événements mélangés dedans : %s." % (cont or "rien de continu", ev or "aucun"),
            "utilise": True, "refs": ["scripts/music.gd"], "boucle": True,
            "fichier": "assets/ambience/%s.wav" % base, "groupe": reg,
        }, f)

    # Événements d'ambiance seuls et nappes continues sans événements (rendus par Godot)
    ev_dir = render_events(os.path.join(OUT, "_tmp"))
    uses = {}
    defaults = {"dead": [("creak", 0.15, 0.35)], "alive": [("bird", 0.45, 0.4), ("cricket", 0.15, 0.2), ("rustle", 0.25, 0.25)]}
    for st, lst in defaults.items():
        for k, r, v in lst:
            uses.setdefault(k, []).append("Ronce, %s" % ("terre flétrie" if st == "dead" else "terre vivante"))
    for reg, d in audio.items():
        for st in ("dead", "alive"):
            for e in d.get("bed", {}).get(st, {}).get("events", []):
                uses.setdefault(e["kind"], []).append("%s, %s" % (REGIONS[reg], "terre flétrie" if st == "dead" else "terre vivante"))
    for kind, (desc, _) in EVENT_DESC.items():
        where = uses.get(kind, [])
        for t in (1, 2, 3):
            f = os.path.join(ev_dir, "ev_%s_%d.wav" % (kind, t))
            if not os.path.exists(f):
                continue
            add({
                "id": "evt-%s_%d" % (kind, t), "kind": "evt", "name": "bed.events › %s" % kind, "file": "%s_%d" % (kind, t), "famille": "ambiance",
                "region": "monde", "titre": "%s (tirage %d)" % (kind, t), "variante": "%d/3" % t,
                "quand": "Se produit au hasard dans les nappes d'ambiance : " + ("; ".join(where) if where else "aucune région ne l'utilise") + ". " + desc,
                "precision": "Rendu seul, normalisé fort pour l'écoute ; dans le jeu il est noyé dans la nappe, bien plus bas.",
                "utilise": bool(where), "refs": ["scripts/music_synth.gd › _event"], "boucle": False,
                "fichier": "(rendu par godot/tools/ecoute_events.gd)", "groupe": "evt-" + kind,
            }, f)
    for f in sorted(glob.glob(os.path.join(ev_dir, "fond_*.wav"))):
        base = os.path.basename(f)[:-4]
        m = re.match(r"fond_([a-z]+)_(mort|vif)$", base)
        reg, state = m.group(1), m.group(2)
        cont, _ = bed_text(reg, state)
        add({
            "id": "fond-%s_%s" % (reg, state), "kind": "fond", "name": base, "file": "%s_%s" % (reg, state), "famille": "ambiance", "region": reg,
            "titre": "%s · fond continu %s" % (REGIONS[reg], ETAT[state]), "variante": "",
            "quand": "La même nappe que ci-dessus, sans ses événements : seulement %s." % (cont or "rien de continu"),
            "precision": "Rendu par godot/tools/ecoute_events.gd pour entendre le fond seul.",
            "utilise": True, "refs": ["scripts/music_synth.gd › render_bed"], "boucle": True,
            "fichier": "(rendu par godot/tools/ecoute_events.gd)", "groupe": reg,
        }, f)

    to_ogg(jobs)
    shutil.rmtree(os.path.join(OUT, "_tmp"), ignore_errors=True)
    # Tous les .ogg dans un seul fichier (sons.ogg) : un seul envoi pour la page, qui les découpe (off, len).
    off = 0
    with open(os.path.join(OUT, "sons.ogg"), "wb") as bin_out:
        for it in items:
            data = open(os.path.join(OUT, it["audio"]), "rb").read()
            it["off"], it["len"] = off, len(data)
            bin_out.write(data)
            off += len(data)

    # Données du mélange réel (music.gd)
    regs_music = sorted({it["region"] for it in items if it["kind"] == "mus"})
    mix = {
        "bed_boss": music_const("BED_BOSS", 0.55),
        "regions": [{"id": r, "nom": REGIONS[r] if r != "ronce" else "Ronce (le monde)",
                     "couches": sorted({it["couche"] for it in items if it["kind"] == "mus" and it["region"] == r}),
                     "nappes": sorted({it["id"] for it in items if it["kind"] == "amb" and it["region"] == r})} for r in regs_music if r != "generique"],
    }
    inv = {
        "genere": subprocess.run(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip(),
        "familles": FAMILLES,
        "regions": REGIONS,
        "items": items,
        "melange": mix,
        "anomalies": unknown_sound_refs(names),
    }
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "inventaire.json"), "w", encoding="utf-8") as f:
        json.dump(inv, f, ensure_ascii=False, indent=1)
    shutil.copy(os.path.join(ROOT, "tools", "ecoute-page.html"), os.path.join(OUT, "index.html"))
    n = {k: sum(1 for it in items if it["kind"] == k) for k in ("sfx", "mus", "amb", "evt", "fond")}
    sfx_unused = sorted({it["name"] for it in items if it["kind"] == "sfx" and not it["utilise"]})
    print("Écoute : %d lignes %s ; %d bruitages jamais appelés : %s" % (len(items), n, len(sfx_unused), ", ".join(sfx_unused)))
    for a in inv["anomalies"]:
        print("Anomalie : son inconnu dans les données :", a)
    print("Sortie :", OUT)


if __name__ == "__main__":
    build()
