#!/usr/bin/env python3
"""Montage de la bande-annonce Steam (jalon 12 H), appelé par tools/steam-trailer.sh.

    steam-montage.py TRAVAIL MUSIQUE SORTIE

TRAVAIL/plans.txt : « plan image_de_début » dans l'ordre ; TRAVAIL/<plan>.avi : plans filmés par
le Movie Maker de Godot (30 i/s). Chaque plan est coupé à sa durée (vitrine.gd › CLIPS), les plans
s'enchaînent en fondu, la musique est faite des pistes du jeu (assets/music, boucles de 12 s) et
les bruitages des plans passent dessous. Écrit SORTIE.mp4 (H.264 + AAC) et SORTIE.gif (5 s, 480 px, pour la description de la page).
"""
import os
import re
import subprocess
import sys

FPS = 30
FADE = 0.5
# Durées : les mêmes que vitrine.gd › CLIPS (lues dans le script pour ne pas les recopier).
VITRINE = os.path.join(os.path.dirname(__file__), "..", "godot", "tools", "steam", "vitrine.gd")
# Musique de chaque plan : pistes du jeu mêlées (sans préfixe : Ronce).
MUSIC = {
    "titre": ["lumineux"],
    "eveil": ["sombre"],
    "combat": ["sombre", "combat"],
    "arbre": ["lumineux"],
    "coeur": ["coeur", "combat"],
    "boss": ["boss"],
    "spore": ["spore_boss"],
    "vent": ["vent_boss"],
    "aube": ["aube_boss"],
    # La Flétrissure joue son morceau fait à la main (assets/music/hand), comme en jeu.
    "finale": ["hand/finale/drop_1.ogg"],
    "fin": ["generique_lumineux"],
    "fin_demo": ["generique_lumineux"],
}
# Plan d'où vient le GIF de la page, et son départ (s).
GIF = ("combat", 3.0, 5.0)


def durations():
    text = open(VITRINE, encoding="utf-8").read()
    block = re.search(r"const CLIPS := \{(.*?)\}", text, re.S).group(1)
    return {k: float(v) for k, v in re.findall(r'"(\w+)": ([\d.]+)', block)}


def ff(*args):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *args], check=True)


def main():
    work, music_dir, out = sys.argv[1:4]
    dur = durations()
    plans = [l.split() for l in open(os.path.join(work, "plans.txt")) if l.strip()]
    parts = []
    for name, start in plans:
        d = dur[name]
        t0 = int(start) / FPS
        v = os.path.join(work, f"{name}.mov")
        # Image et son du plan, coupés à sa durée ; un silence si le plan n'a pas de son.
        ff("-ss", f"{t0:.3f}", "-i", os.path.join(work, f"{name}.avi"), "-f", "lavfi", "-t", str(d),
           "-i", "anullsrc=r=44100:cl=stereo", "-t", f"{d:.3f}",
           "-filter_complex", "[0:a]aresample=44100,aformat=channel_layouts=stereo[a0];[a0][1:a]amix=inputs=2:duration=longest:normalize=0[a]",
           "-map", "0:v", "-map", "[a]", "-r", str(FPS), "-c:v", "libx264", "-crf", "16", "-preset", "medium",
           "-pix_fmt", "yuv420p", "-c:a", "pcm_s16le", v)
        # Musique du plan : ses pistes en boucle, mêlées, à la durée du plan.
        m = os.path.join(work, f"{name}_musique.wav")
        stems = MUSIC.get(name, ["lumineux"])
        ins = []
        for s in stems:
            path = os.path.join(music_dir, s if "." in s else f"{s}.wav")
            ins += ["-stream_loop", "-1", "-i", path]
        mix = "".join(f"[{i}:a]" for i in range(len(stems)))
        ff(*ins, "-t", f"{d:.3f}", "-filter_complex",
           f"{mix}amix=inputs={len(stems)}:normalize=0,aresample=44100,aformat=channel_layouts=stereo[m]",
           "-map", "[m]", m)
        parts.append((name, d, v, m))

    # Enchaînement : fondu enchaîné de FADE s entre les plans (image, bruitages, musique).
    inputs, vf, af, mf = [], [], [], []
    for i, (_, _, v, m) in enumerate(parts):
        inputs += ["-i", v]
    for i, (_, _, v, m) in enumerate(parts):
        inputs += ["-i", m]
    n = len(parts)
    offset = 0.0
    vlast, alast, mlast = "[0:v]", "[0:a]", f"[{n}:a]"
    for i in range(1, n):
        offset += parts[i - 1][1] - FADE
        vf.append(f"{vlast}[{i}:v]xfade=transition=fade:duration={FADE}:offset={offset:.3f}[v{i}]")
        af.append(f"{alast}[{i}:a]acrossfade=d={FADE}[a{i}]")
        mf.append(f"{mlast}[{n + i}:a]acrossfade=d={FADE}[m{i}]")
        vlast, alast, mlast = f"[v{i}]", f"[a{i}]", f"[m{i}]"
    total = offset + parts[-1][1]
    graph = vf + af + mf + [
        f"{vlast}fade=t=in:d=0.8,fade=t=out:st={total - 1.2:.3f}:d=1.2[vo]",
        f"{alast}volume=0.55[sfx]",
        f"{mlast}volume=0.9[mus]",
        f"[mus][sfx]amix=inputs=2:normalize=0,afade=t=in:d=0.8,afade=t=out:st={total - 1.5:.3f}:d=1.5,"
        "loudnorm=I=-16:TP=-1.5:LRA=11[ao]",
    ]
    ff(*inputs, "-filter_complex", ";".join(graph), "-map", "[vo]", "-map", "[ao]", "-r", str(FPS),
       "-c:v", "libx264", "-crf", "20", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
       "-c:a", "aac", "-b:a", "192k", out + ".mp4")
    print(f"MONTAGE {out}.mp4 : {total:.1f} s, {n} plans")

    # GIF de la page : quelques secondes du combat, 640 px, palette propre.
    name, t0, d = GIF
    for p in parts:
        if p[0] == name:
            ff("-ss", str(t0), "-t", str(d), "-i", p[2], "-vf",
               "fps=15,crop=1440:810:240:135,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
               "-loop", "0", out + ".gif")
            print(f"MONTAGE {out}.gif")


if __name__ == "__main__":
    main()
