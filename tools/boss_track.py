#!/usr/bin/env python3
"""Prépare une musique de boss faite à la main pour le lecteur du jeu (scripts/boss_track.gd).

    tools/boss-track.sh <fichier audio> <fiche de repères> <boss> [--qualite 6] [--raccord-ms 12]

Lit le fichier (mp3, wav, flac… : tout ce que ffmpeg sait lire), le coupe aux mesures exactes de la
fiche, et écrit dans godot/assets/music/hand/ :
  <boss>/<clip>.ogg      intro.ogg (intro + boucle_1), drop_<n>.ogg (drop_n + boucle_<n+1>), fin.ogg,
                         defaite.ogg (boucle_<n>.ogg seule quand aucun drop n'y mène) ;
  <boss>.json            tempo, mesure et sections (lu par le jeu, décrit dans data/README.md › Son).

Fiche de repères (texte, « clé: valeur », # pour les commentaires), mesures comptées à partir de 1 :
  bpm: 180
  mesure: 4/4
  debut: 0.026        # secondes : premier temps de la mesure 1
  approche: 1-8       # facultatif : joué sous l'ambiance du monde à l'approche de l'arène (le volume
  approche_boucle: 9-16 # monte avec la distance), puis approche_boucle en boucle ; à l'entrée, l'intro
                      # part à la mesure suivante (boss_track.gd › approach)
  intro: 1-16         # jouée une fois à l'arrivée (descente, invocation) ; le combat part à boucle_1
  intro_court: 9-16   # facultatif : intro des essais suivants (après une mort)
  boucle_1: 17-32     # phase 1 (tourne en boucle)
  drop_1: 45-48       # passage vers la phase 2 (une fois), puis boucle_2
  boucle_2: 49-72
  drop_2: 77-80
  boucle_3: 81-120
  fin: 121-128        # à la mort du boss
  defaite: …          # facultatif : à la mort du héros (sinon fondu d'une seconde)
  fin_fondu: 2        # facultatif : fondu de sortie sur les N dernières mesures de « fin »
  bande_caisse: 1500-5000  # facultatif : bande (Hz) d'une sorte de coups (kick, caisse, charleston)
                      # quand celle par défaut (COUPS_BANDES) entend autre chose (un 808, une claque)

    tools/boss-track.sh <fichier audio> <fiche> <boss> --coups-seuls
                     ne refait que les coups de batterie des boucles (« coups ») dans <boss>.json.

Raccords vérifiés :
  - chaque boucle se raccorde sans clic : ses dernières millisecondes sont fondues vers ce qui précède
    son début dans le morceau d'origine (le bouclage enchaîne alors comme l'original) ; le rapport donne
    le saut d'amplitude et l'écart de spectre au bouclage, avant/après, et ceux du même passage dans
    l'original (la cible) ;
  - un morceau où l'on entre en cours de musique (drop, fin, défaite) commence par un fondu de 3 ms ;
  - chaque .ogg relu fait exactement le nombre de mesures voulu et reste calé sur la source (décalage 0).
Le rapport (sauts d'amplitude avant/après) est imprimé et gardé dans le .json (« raccords »).
"""
import json
import os
import re
import subprocess
import sys

try:
    import numpy as np
except ImportError:  # pragma: no cover
    sys.exit("numpy est nécessaire : pip install numpy")

RATE = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "godot", "assets", "music", "hand")
ENTRY_FADE_MS = 3.0
SECTION_RE = re.compile(r"^(approche|approche_boucle|intro|intro_court|boucle_\d+|drop_\d+|fin|defaite)$")


def parse_fiche(path):
    keys = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if not line or ":" not in line:
                continue
            k, v = line.split(":", 1)
            keys[k.strip()] = v.strip()
    bpm = float(keys["bpm"])
    beats = int(keys.get("mesure", "4/4").split("/")[0])
    debut = float(keys.get("debut", "0"))
    sections = {}
    for k, v in keys.items():
        if SECTION_RE.match(k):
            parts = v.split("-")
            a, b = int(parts[0]), int(parts[-1])
            if b < a:
                sys.exit(f"{k} : {v} (fin avant le début)")
            sections[k] = [a, b]
    # Bandes des coups de batterie propres au morceau (facultatif, Hz) : « bande_kick: 40-80 »…
    for name in COUPS_BANDES:
        if "bande_" + name in keys:
            lo, hi = (float(v) for v in keys["bande_" + name].split("-"))
            COUPS_BANDES[name] = (lo, hi)
    for need in ("intro", "boucle_1"):
        if need not in sections:
            sys.exit(f"la fiche doit donner « {need} »")
    return bpm, beats, debut, sections, int(keys.get("fin_fondu", "0"))


def decode(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-"],
        check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def jump(a, b):
    """Saut d'amplitude entre la fin de a et le début de b (le pire des deux canaux)."""
    return float(np.max(np.abs(a[-1] - b[0])))


def spectral_gap(a, b, n=512):
    """Écart de spectre (dB) entre les n derniers échantillons de a et les n premiers de b."""
    w = np.hanning(n)
    fa = np.abs(np.fft.rfft(a[-n:].mean(1) * w)) + 1e-6
    fb = np.abs(np.fft.rfft(b[:n].mean(1) * w)) + 1e-6
    return float(np.mean(np.abs(20 * np.log10(fa / fb))))


def encode(samples, path, quality):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-i", "-",
         "-c:a", "libvorbis", "-q:a", str(quality), "-map_metadata", "-1", path],
        input=np.clip(samples, -1.0, 1.0).astype(np.float32).tobytes(), check=True)


def lag(a, b, n=RATE // 2, span=256):
    """Décalage (échantillons) qui aligne b sur a, sur les n premiers échantillons."""
    a = a[:n].mean(1)
    b = b[:n].mean(1)
    best, best_l = -1e18, 0
    for l in range(-span, span + 1):
        if l >= 0:
            c = float(np.dot(a[: n - l], b[l:n]))
        else:
            c = float(np.dot(a[-l:n], b[: n + l]))
        if c > best:
            best, best_l = c, l
    return best_l


# Coups de batterie de chaque boucle (« coups » dans le .json) : pour chaque mesure de la boucle, les
# doubles croches (0-15) où tombe un coup de grosse caisse (« kick », 30-110 Hz) ou de caisse claire
# (« caisse », 180-400 Hz) franc. Le boss final pose dessus ses ondes de choc et ses roulements
# d'épines (scripts/boss_finale.gd › SCORE). Détection : hausse d'énergie de la bande sur 30 ms à
# chaque double croche, rapportée au plus fort de la boucle ; gardée au-dessus de COUPS_SEUIL.
# Les coups discrets ont leur propre liste : « charleston » (6-10 kHz, au-dessus de COUPS_SEUIL_HAT) et
# « caisse_douce » et « kick_doux » (caisse claire ou grosse caisse entre COUPS_SEUIL_DOUX et
# COUPS_SEUIL : notes fantômes, petits coups).
COUPS_BANDES = {"kick": (30.0, 110.0), "caisse": (180.0, 400.0), "charleston": (6000.0, 10000.0)}
COUPS_SEUIL = 0.45
COUPS_SEUIL_HAT = 0.25
COUPS_SEUIL_DOUX = 0.18


def bandpass(sig, lo, hi):
    spec = np.fft.rfft(sig)
    f = np.fft.rfftfreq(len(sig), 1.0 / RATE)
    spec[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(spec, len(sig))


def coups(x, start, bars, bar):
    """Doubles croches des coups francs, mesure par mesure, d'une boucle qui commence à « start »."""
    six = bar / 16.0
    win = int(0.03 * RATE)
    s0 = max(0, start - win)
    seg = x[s0: int(start + bars * bar) + win].mean(1)
    out = {}
    for name, (lo, hi) in COUPS_BANDES.items():
        b = bandpass(seg, lo, hi)
        rise = []
        for i in range(bars * 16):
            c = int(start - s0 + i * six)
            pre, post = b[max(0, c - win):c], b[c:c + win]
            rise.append(max(0.0, float(np.sqrt((post ** 2).mean()) - np.sqrt((pre ** 2).mean() if len(pre) else 0.0))))
        top = max(rise) or 1.0
        seuil = COUPS_SEUIL_HAT if name == "charleston" else COUPS_SEUIL
        out[name] = [[j for j in range(16) if rise[m * 16 + j] / top > seuil] for m in range(bars)]
        if name == "kick":
            out["kick_doux"] = [[j for j in range(16) if COUPS_SEUIL_DOUX < rise[m * 16 + j] / top <= COUPS_SEUIL]
                                for m in range(bars)]
        if name == "caisse":
            out["caisse_douce"] = [[j for j in range(16) if COUPS_SEUIL_DOUX < rise[m * 16 + j] / top <= COUPS_SEUIL]
                                   for m in range(bars)]
    return out


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    opts = {}
    i = 0
    while i < len(argv):
        if argv[i] == "--coups-seuls":
            opts["coups-seuls"] = True
            i += 1
        elif argv[i].startswith("--"):
            opts[argv[i][2:]] = argv[i + 1]
            args.remove(argv[i + 1])
            i += 2
        else:
            i += 1
    if len(args) != 3:
        sys.exit(__doc__)
    src, fiche, boss = args
    quality = float(opts.get("qualite", "6"))
    seam_ms = float(opts.get("raccord-ms", "12"))
    out_dir = opts.get("sortie", OUT_DIR)
    bpm, beats, debut, sections, fin_fade = parse_fiche(fiche)
    x = decode(src)
    bar = beats * 60.0 / bpm * RATE
    if opts.get("coups-seuls"):
        # Seulement les coups de batterie des boucles, dans le .json déjà écrit (les .ogg ne bougent pas).
        path = os.path.join(out_dir, boss + ".json")
        with open(path, encoding="utf-8") as f:
            out = json.load(f)
        for name, (a, b) in sections.items():
            if name.startswith("boucle") and name in out["sections"]:
                out["sections"][name]["coups"] = coups(x, int(round(debut * RATE + (a - 1) * bar)), b - a + 1, bar)
                n = sum(len(m) for m in out["sections"][name]["coups"]["kick"])
                print(f"  {name} : {n} coups de grosse caisse sur {b - a + 1} mesures")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=2)
            f.write("\n")
        return
    print(f"{os.path.basename(src)} : {len(x) / RATE:.2f} s, {bpm:g} BPM, mesure de {bar / RATE:.4f} s")

    def at(m):  # premier échantillon de la mesure m
        return int(round(debut * RATE + (m - 1) * bar))

    seam_n = max(1, int(seam_ms / 1000 * RATE))
    entry_n = int(ENTRY_FADE_MS / 1000 * RATE)
    out = {"bpm": bpm, "bar_beats": beats, "debut": debut, "source": os.path.basename(src),
           "sections": {}, "clips": {}}
    audio = {}
    # 1. Chaque section, coupée aux mesures exactes, raccords préparés.
    for name, (a, b) in sections.items():
        s, e = at(a), at(b + 1)
        loop = name.startswith("boucle") or name == "approche_boucle"
        if e > len(x) and not (name in ("fin", "defaite") and e - len(x) < bar * 0.02):
            sys.exit(f"{name} : {a}-{b} dépasse la fin du fichier ({(len(x) - debut * RATE) / bar:.2f} mesures)")
        clip = np.zeros((e - s, 2), dtype=np.float32)
        part = x[s:min(e, len(x))]
        clip[: len(part)] = part
        info = {"mesures": [a, b]}
        if loop:
            info["saut_avant"] = round(jump(clip, clip), 4)
            info["spectre_avant_db"] = round(spectral_gap(clip, clip), 2)
            # Les dernières millisecondes deviennent ce qui précède le début de la boucle dans
            # l'original : en bouclant, on enchaîne comme le morceau (equal-power, sans creux).
            pre = x[s - seam_n:s] if s >= seam_n else np.zeros((seam_n, 2), np.float32)
            ramp = np.linspace(0.0, 1.0, seam_n, dtype=np.float32)[:, None]
            clip[-seam_n:] = clip[-seam_n:] * np.cos(ramp * np.pi / 2) + pre * np.sin(ramp * np.pi / 2)
            info["saut_apres"] = round(jump(clip, clip), 4)
            info["spectre_apres_db"] = round(spectral_gap(clip, clip), 2)
            # Référence : le même passage dans l'original (ce qui précède le début, puis le début).
            info["saut_naturel"] = round(jump(x[s - 1:s], x[s:s + 1]), 4) if s > 0 else 0.0
            info["spectre_naturel_db"] = round(spectral_gap(x[max(0, s - 512):s], x[s:s + 512]), 2) if s >= 512 else 0.0
            info["coups"] = coups(x, s, b - a + 1, bar)
        elif name.startswith("drop") or name in ("fin", "defaite"):
            info["saut_entree"] = round(float(np.max(np.abs(clip[0]))), 4)
            clip[:entry_n] *= np.linspace(0.0, 1.0, entry_n, dtype=np.float32)[:, None]
        if name == "fin":
            # Ce qui sonne encore après la dernière mesure (réverbération) fait partie de la fin.
            tail = x[e:]
            if len(tail):
                live = np.nonzero(np.max(np.abs(tail), axis=1) > 1e-4)[0]
                if len(live):
                    clip = np.concatenate([clip, tail[: live[-1] + 1]])
            if fin_fade > 0:
                n = min(len(clip), int(fin_fade * bar))
                clip[-n:] *= np.cos(np.linspace(0.0, 1.0, n, dtype=np.float32) * np.pi / 2)[:, None]
                info["fondu_mesures"] = fin_fade
        audio[name] = clip
        out["sections"][name] = info

    # 2. Clips joués par le jeu. Une section suivie d'une boucle (intro → boucle_1, drop_n → boucle_<n+1>)
    # partage son fichier avec elle : l'ogg boucle de lui-même sur sa fin (loop_offset), à l'échantillon
    # près. Les enchaînements « à la fin du clip » d'AudioStreamInteractive tombent, eux, sur un tampon
    # du mélangeur (jusqu'à ~20 ms trop tôt), et décaleraient la grille des mesures.
    clips = {}
    n_loop = 1
    while f"boucle_{n_loop}" in sections:
        head = "intro" if n_loop == 1 else f"drop_{n_loop - 1}"
        clips[head if head in sections else f"boucle_{n_loop}"] = (
            [head, f"boucle_{n_loop}"] if head in sections else [f"boucle_{n_loop}"])
        n_loop += 1
    if "intro_court" in sections:
        clips["intro_court"] = ["intro_court", "boucle_1"]
    if "approche_boucle" in sections:
        clips["approche"] = (["approche"] if "approche" in sections else []) + ["approche_boucle"]
    for k in ("fin", "defaite"):
        if k in sections:
            clips[k] = [k]
    for cname, parts in clips.items():
        data = np.concatenate([audio[p] for p in parts])
        path = os.path.join(out_dir, boss, cname + ".ogg")
        encode(data, path, quality)
        back = decode(path)
        # Longueur d'après l'ogg (dernière position) : c'est celle que Godot lit. Le décodeur de ffmpeg,
        # lui, perd souvent les 128 derniers échantillons ; on ne s'y fie pas pour la longueur.
        frames = int(subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=duration_ts",
             "-of", "csv=p=0", path], check=True, capture_output=True, text=True).stdout.strip())
        if frames != len(data):
            sys.exit(f"{cname} : l'ogg fait {frames} échantillons au lieu de {len(data)}")
        d = lag(data, back)
        if d != 0:
            sys.exit(f"{cname} : l'ogg relu est décalé de {d} échantillons")
        bars = [sections[p][1] - sections[p][0] + 1 for p in parts]
        loop = parts[-1].startswith("boucle") or parts[-1] == "approche_boucle"
        info = {"fichier": f"{boss}/{cname}.ogg", "sections": parts, "mesures": sum(bars),
                "boucle": loop, "echantillons": frames, "decalage_ech": d}
        if loop:
            info["boucle_depuis"] = sum(bars[:-1])
            # Raccord dans l'ogg relu : de la fin du fichier au début de la boucle.
            ls = int(round(info["boucle_depuis"] * bar))
            out["sections"][parts[-1]]["saut_ogg"] = round(jump(back[: len(data) - 128], back[ls:]), 4)
        out["clips"][cname] = info
        kb = os.path.getsize(path) / 1024
        print(f"  {cname + '.ogg':13s} {' + '.join(parts):20s} {sum(bars):3d} mesures  {len(data) / RATE:6.2f} s  {kb:5.0f} Ko")
    for name, info in out["sections"].items():
        a, b = info["mesures"]
        msg = f"    {name:9s} mesures {a:3d}-{b:3d}"
        if "saut_apres" in info:
            msg += f"  raccord de boucle : saut {info['saut_avant']:.3f} → {info['saut_apres']:.3f} " \
                   f"(original {info['saut_naturel']:.3f}), spectre {info['spectre_avant_db']:.1f} → " \
                   f"{info['spectre_apres_db']:.1f} dB (original {info['spectre_naturel_db']:.1f})"
        elif "saut_entree" in info:
            msg += f"  entrée {info['saut_entree']:.3f} → fondu {ENTRY_FADE_MS:g} ms"
        print(msg)
    with open(os.path.join(out_dir, boss + ".json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write("\n")
    total = sum(os.path.getsize(os.path.join(out_dir, boss, n + ".ogg")) for n in clips) / 1024 / 1024
    print(f"→ {os.path.relpath(os.path.join(out_dir, boss + '.json'), ROOT)} ({total:.1f} Mo d'ogg)")


if __name__ == "__main__":
    main(sys.argv[1:])
