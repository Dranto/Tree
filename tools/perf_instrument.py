#!/usr/bin/env python3
"""Instrumente une copie du projet pour le profil du banc (tools/perf-profile.sh).

Chaque fonction _process, _physics_process et _draw (et les fonctions nommées en plus) est
renommée _prof<nom> et remplacée par une enveloppe qui mesure son temps avec Prof
(scripts/prof.gd). Le projet d'origine n'est jamais modifié.
Usage : perf_instrument.py DOSSIER_GODOT [fonction ...]
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
targets = {"_process", "_physics_process", "_draw"} | set(sys.argv[2:])
FUNC = re.compile(r"^(\t*)(static )?func (\w+)\((.*?)\)(\s*->\s*void)?:\s*$")
CLASS = re.compile(r"^(\t*)class (\w+)")

for path in sorted((root / "scripts").glob("*.gd")):
    if path.name == "prof.gd":
        continue
    out, cls, changed = [], "", False
    for line in path.read_text().split("\n"):
        m = CLASS.match(line)
        if m:
            cls = m.group(2)
        m = FUNC.match(line)
        if m and m.group(3) in targets and m.group(5) is not None:
            ind, st, name, args = m.group(1), m.group(2) or "", m.group(3), m.group(4)
            key = f"{path.stem}.{cls + '.' if ind else ''}{name}"
            names = ", ".join(a.split(":")[0].split("=")[0].strip() for a in args.split(",") if a.strip())
            out += [f"{ind}{st}func {name}({args}) -> void:",
                    f"{ind}\tvar __p := Prof.t0()",
                    f"{ind}\t_prof{name}({names})",
                    f"{ind}\tProf.add(\"{key}\", __p)",
                    "",
                    f"{ind}{st}func _prof{name}({args}) -> void:"]
            changed = True
            continue
        out.append(line)
    if changed:
        path.write_text("\n".join(out))
