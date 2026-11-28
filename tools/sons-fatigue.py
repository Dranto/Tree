#!/usr/bin/env python3
"""Mesure de la lassitude des bruitages, avant / après les limites de sfx.gd (lot A du jalon 14.5).

Lit les journaux écrits par Sfx avec « -- --sfx-log=<fichier> » (tools/sons-fatigue.sh) et imprime, pour chaque
journal : demandes et sons joués par seconde, raisons des sons tus, sons les plus fréquents, voix actives
(moyenne, au plus) et part des répétitions exactes (même son, même variante, même hauteur que la fois d'avant).
Avec --mix, rend aussi le mélange réel des bruitages (sans musique) en .wav puis .ogg (ffmpeg), pour l'écoute.

    tools/sons-fatigue.py avant.csv apres.csv [--mix DOSSIER] [--from 40 --to 70]
"""
import argparse
import collections
import csv
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOUNDS = os.path.join(ROOT, "godot", "assets", "sounds")
RATE = 44100


def rows_of(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter=";"))


def wav_of(name, variant, cache={}):
    key = (name, variant)
    if key not in cache:
        file = name if variant == 0 else "%s__%d" % (name, variant + 1)
        with wave.open(os.path.join(SOUNDS, file + ".wav")) as w:
            data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
            cache[key] = (data, w.getframerate())
    return cache[key]


def report(path):
    rows = rows_of(path)
    played = [r for r in rows if r["etat"] == "joue"]
    span = max(int(r["ms"]) for r in rows) / 1000.0 if rows else 1.0
    why = collections.Counter(r["etat"] for r in rows if r["etat"] != "joue")
    by_name = collections.Counter(r["son"] for r in played)
    asked = collections.Counter(r["son"] for r in rows)
    # Voix actives, échantillonnées toutes les 10 ms (durée réelle du fichier à sa hauteur).
    steps = int(span * 100) + 1
    live = np.zeros(steps)
    for r in played:
        a = int(r["ms"]) // 10
        b = min(steps, a + max(1, int(r["duree_ms"]) // 10))
        live[a:b] += 1
    # Répétition exacte : même son, même variante, hauteur à moins de 1 %, moins d'une seconde après.
    last = {}
    same = 0
    for r in played:
        t, n, p, v = int(r["ms"]), r["son"], float(r["hauteur"]), r["variante"]
        if n in last:
            lt, lp, lv = last[n]
            if t - lt < 1000 and lv == v and abs(p / lp - 1.0) < 0.01:
                same += 1
        last[n] = (t, p, v)
    gains = [float(r["gain_db"]) for r in played]
    print("== %s : %.0f s de jeu" % (os.path.basename(path), span))
    print("  demandes %.1f/s, jouées %.1f/s ; tues : %s" % (len(rows) / span, len(played) / span,
          ", ".join("%s %d" % kv for kv in why.most_common()) or "aucune"))
    print("  voix actives : moyenne %.1f, au plus %d" % (live.mean(), live.max()))
    print("  répétitions exactes (même son, même variante, même note, moins d'1 s après) : %d sur %d (%.0f %%)" % (
        same, len(played), 100.0 * same / max(1, len(played))))
    print("  gain moyen %.1f dB" % (sum(gains) / max(1, len(gains))))
    for n, k in by_name.most_common(8):
        sub = [r for r in played if r["son"] == n]
        notes = len({round(float(r["hauteur"]), 2) for r in sub})
        print("    %-16s %5.2f/s joués (%5.2f/s demandés), %2d hauteurs, gain moyen %5.1f dB" % (
            n, k / span, asked[n] / span, notes, sum(float(r["gain_db"]) for r in sub) / k))
    return rows


def mix(rows, start, end):
    out = np.zeros(int((end - start) * RATE) + RATE * 2, dtype=np.float32)
    for r in rows:
        if r["etat"] != "joue":
            continue
        t = int(r["ms"]) / 1000.0
        if t < start or t >= end:
            continue
        data, rate = wav_of(r["son"], int(r["variante"]))
        step = float(r["hauteur"]) * rate / RATE
        idx = np.arange(0, len(data) - 1, step)
        snd = np.interp(idx, np.arange(len(data)), data) * (10.0 ** (float(r["gain_db"]) / 20.0))
        a = int((t - start) * RATE)
        b = min(len(out), a + len(snd))
        out[a:b] += snd[: b - a]
    # Limiteur doux de la sortie (comme le limiteur du bus général), puis -1 dB de marge.
    out = np.tanh(out * 0.9) * 0.89
    return out


def write(path, samples):
    pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    ogg = path[:-4] + ".ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    os.remove(path)
    return ogg


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("logs", nargs="+")
    ap.add_argument("--mix")
    ap.add_argument("--from", dest="start", type=float, default=40.0)
    ap.add_argument("--to", dest="end", type=float, default=70.0)
    a = ap.parse_args()
    mixes = []
    for path in a.logs:
        rows = report(path)
        if a.mix:
            mixes.append(mix(rows, a.start, a.end))
    if a.mix and mixes:
        os.makedirs(a.mix, exist_ok=True)
        for path, m in zip(a.logs, mixes):
            print("  écoute :", write(os.path.join(a.mix, os.path.basename(path)[:-4] + ".wav"), m))
        if len(mixes) == 2:
            gap = np.zeros(RATE, dtype=np.float32)
            print("  écoute :", write(os.path.join(a.mix, "avant_puis_apres.wav"), np.concatenate([mixes[0], gap, mixes[1]])))


if __name__ == "__main__":
    main()
