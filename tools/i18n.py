#!/usr/bin/env python3
"""Catalogues de traduction du jeu (jalon 12 A) : godot/locale/tree.pot, fr.po, en.po.

La langue source est le français : chaque msgid est le texte français. Deux sources :
  - le code (godot/scripts/**/*.gd) : littéraux passés à tr()/tr_n()/Loc.t()/Loc.tn()/Loc.key(),
    posés directement dans un Control (text =, tooltip_text =, add_item(…)) ou sur une ligne
    marquée « # i18n » ;
  - les données (godot/data/**/*.json) : champs de texte (name, text, desc…), lus tels quels, sans
    réécrire les JSON ; chaque nombre devient {0}, {1}… (même règle que Loc.template), si bien
    qu'un chiffre réglé dans un JSON garde sa traduction.

Utilisation (voir tools/i18n.sh) :
  i18n.py extract           met à jour tree.pot, fr.po (identique à la source) et les autres .po
                            (traductions gardées, nouveaux textes vides, textes disparus en #~)
  i18n.py check             échoue si un texte français du code échappe à la traduction ou si les
                            catalogues ne sont pas à jour
  i18n.py coverage          part des textes traduits par langue
  i18n.py missing <lang>    textes sans traduction dans <lang>
  i18n.py lint              seulement le contrôle des littéraux du code
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, "godot")
LOCALE_DIR = os.path.join(GODOT, "locale")
LANGS = ["fr", "en"]
SOURCE = "fr"
PLURAL_FORMS = {"fr": "nplurals=2; plural=(n > 1);", "en": "nplurals=2; plural=(n != 1);"}

# --- Code -------------------------------------------------------------------------------------

# Appels qui traduisent leur premier argument (et le second pour un pluriel).
TR_CALLS = {"tr", "atr", "Loc.t", "Loc.key", "Loc.tn", "tr_n", "atr_n", "Loc.tc"}
PLURAL_CALLS = {"Loc.tn", "tr_n", "atr_n"}
# Méthodes de Control qui affichent (et traduisent elles-mêmes) un texte littéral.
SINK_CALLS = {"add_item", "add_check_item", "add_radio_check_item", "set_item_text", "add_tab", "set_tab_title",
              "add_separator"}
SINK_PROPS = {"text", "tooltip_text", "placeholder_text"}
# Appels dont les textes ne sont jamais montrés au joueur (journal, erreurs des données).
IGNORE_CALLS = {"push_error", "push_warning", "print", "printerr", "prints", "printt", "print_rich",
                "print_debug", "assert", "errors.append", "err.append", "error.append", "_err", "_fail",
                "fail", "warnings.append", "OS.get_environment", "OS.has_feature", "load", "preload",
                "has_node", "get_node", "get_node_or_null", "find_child", "InputMap.add_action",
                "InputMap.has_action", "Input.is_action_pressed", "Input.is_action_just_pressed",
                "is_action_pressed", "is_action_just_pressed", "is_action_released", "Color", "Color.html",
                "set_meta", "get_meta", "has_meta", "emit_signal", "connect", "call", "call_deferred",
                "has_method", "Engine.get_singleton", "ProjectSettings.get_setting", "add_to_group",
                "is_in_group", "get_nodes_in_group", "Time.get_datetime_string_from_system", "RegEx.create_from_string"}
# Fonctions de contrôle des données : messages pour le développeur.
IGNORE_FUNC_RE = re.compile(r"^_?(check|validate|verify)")
# Scripts jamais montrés au joueur (robots, outils, mesures).
DEV_FILES = {"scripts/check_data.gd", "scripts/build_bot.gd", "scripts/zone_bot.gd", "scripts/prof.gd",
             "scripts/gen_sounds.gd", "scripts/ui_audit.gd", "scripts/sound_refs.gd", "scripts/objective_check.gd"}

LETTERS = "A-Za-zÀ-ÖØ-öø-ÿŒœ"


def french_like(s):
    """Vrai si le littéral ressemble à un texte affiché (et non à un identifiant)."""
    if s.startswith(("res://", "user://", "uid://", "http")):
        return False
    if not re.search(f"[{LETTERS}]{{2,}}", s):
        return False
    if re.fullmatch(r"[a-z0-9_./:%\-+*<>=\[\]{}()|,]*", s):  # identifiant, chemin, motif
        return False
    if re.fullmatch(r"[A-Za-z0-9_]+", s) and not re.search("[À-ÿ]", s) and (s.isupper() or "_" in s):
        return False
    if re.fullmatch(r"#?[0-9a-fA-F]{6,8}", s) or re.fullmatch(r"#[a-z_]+", s):
        return False
    if "shader_type" in s or "render_mode" in s:
        return False
    if re.fullmatch(r"[A-Z][A-Za-z0-9]*(/[A-Za-z0-9_]+)*", s) and not re.search("[À-ÿ]", s) and s in GODOT_WORDS:
        return False
    return True


# Noms de classes, de bus, de thèmes : jamais traduits.
GODOT_WORDS = {"Label", "Button", "CheckBox", "OptionButton", "PopupMenu", "PanelContainer", "Panel",
               "HSlider", "LineEdit", "Master", "TooltipPanel",
               "TooltipLabel", "ScrollContainer", "VBoxContainer", "HBoxContainer", "RichTextLabel",
               "Node2D", "Control", "Window", "ItemList", "TabBar", "ProgressBar", "VScrollBar", "HScrollBar", "Game", "Sfx", "Settings",
               "SaveGame", "Flow", "Music", "Objectives", "UiAudit", "Regions", "Steam"}

TOKEN_RE = re.compile(r'''
    (?P<comment>\#[^\n]*)
  | (?P<str>(?:[&^r])?(?:"""(?:\\.|[^\\])*?"""|'\'\''(?:\\.|[^\\])*?'\'\''|"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'))
  | (?P<ident>[A-Za-z_][A-Za-z0-9_]*(?:\s*\.\s*[A-Za-z_][A-Za-z0-9_]*)*)
  | (?P<num>\d[\d_]*(?:\.\d+)?(?:e[+-]?\d+)?)
  | (?P<nl>\n)
  | (?P<op>==|!=|<=|>=|\+=|-=|\*=|/=|%=|:=|->|\*\*|[-+*/%<>=!&|^~:,.;()\[\]{}@$])
  | (?P<ws>[ \t\r\\]+)
''', re.VERBOSE | re.DOTALL)


def unquote(lit):
    if lit[0] in "&^":
        lit = lit[1:]
    raw = lit[0] == "r"
    if raw:
        lit = lit[1:]
    if lit.startswith(('"""', "'''")):
        body = lit[3:-3]
    else:
        body = lit[1:-1]
    if raw:
        return body
    out = []
    i = 0
    while i < len(body):
        c = body[i]
        if c == "\\" and i + 1 < len(body):
            n = body[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\", "r": "\r"}.get(n, "\\" + n))
            i += 2
            if n == "u":
                out[-1] = chr(int(body[i:i + 4], 16))
                i += 4
            continue
        out.append(c)
        i += 1
    return "".join(out)


def scan_gd(path):
    """Littéraux d'un script : liste de (ligne, texte, rôle, détail) ; rôle = msgid | plural | ignore | escape."""
    rel = os.path.relpath(path, GODOT).replace(os.sep, "/")
    src = open(path, encoding="utf-8").read()
    lines = src.split("\n")
    # Marque de chaque ligne : « # i18n » (textes à traduire plus loin), « # i18n: non » (jamais
    # affichés) ; « (début) » … « (fin) » pour un bloc de lignes.
    mark_of = []
    block = ""
    for ln in lines:
        cm = re.search(r"#\s*i18n(:\s*non)?\b\s*(\((début|fin)\))?", ln)
        here = block
        if cm:
            kind = "non" if cm.group(1) else "oui"
            if cm.group(3) == "début":
                block = kind
                here = kind
            elif cm.group(3) == "fin":
                block = ""
                here = kind
            else:
                here = kind
        mark_of.append(here)
    # Fonction englobante de chaque ligne.
    func_of = []
    cur = ""
    for ln in lines:
        m = re.match(r"\s*(?:static\s+)?func\s+([A-Za-z_0-9]+)", ln)
        if m:
            cur = m.group(1)
        elif re.match(r"[A-Za-z@]", ln) and not ln.startswith(("func", "static")):
            cur = ""  # code au niveau du fichier (const, var…)
        func_of.append(cur)
    toks = []
    for m in TOKEN_RE.finditer(src):
        kind = m.lastgroup
        if kind == "ws":
            continue
        line = src.count("\n", 0, m.start()) + 1
        toks.append((kind, m.group(), line))
    out = []
    stack = []  # (callee, type d'ouverture)
    prev = []
    for idx, (kind, text, line) in enumerate(toks):
        if kind == "op" and text in "([{":
            callee = ""
            if text == "(" and prev and prev[-1][0] == "ident":
                callee = re.sub(r"\s+", "", prev[-1][1])
            stack.append((callee, text, len(out)))
        elif kind == "op" and text in ")]}":
            if stack:
                stack.pop()
        elif kind == "str":
            value = unquote(text)
            if text[0] in "&^":
                prev.append((kind, text, line))
                continue
            comment = mark_of[line - 1]
            nxt = toks[idx + 1] if idx + 1 < len(toks) else ("nl", "\n", line)
            prv = prev[-1] if prev else ("nl", "\n", line)
            whole_arg = prv[1] in ("(", ",") and nxt[1] in (")", ",")
            callee = stack[-1][0] if stack and stack[-1][1] == "(" else ""
            enclosing = [c for c, _t, _i in stack]
            role = None
            if callee == "Loc.tc" and whole_arg and prv[1] == ",":
                role = "context"
            elif callee in TR_CALLS and whole_arg and value.strip() not in ("", "%s", "%d"):
                # Passé explicitement à tr() : extrait même sans lettres (« %d %% »).
                role = "plural" if (callee in PLURAL_CALLS and prv[1] == ",") else "msgid"
            elif not french_like(value):
                role = "skip"
            elif comment == "non" or rel in DEV_FILES or IGNORE_FUNC_RE.match(func_of[line - 1]) \
                    or any(c in IGNORE_CALLS for c in enclosing):
                role = "ignore"
            elif callee in TR_CALLS and whole_arg:
                role = "plural" if (callee in PLURAL_CALLS and prv[1] == ",") else "msgid"
            elif callee in TR_CALLS and not whole_arg:
                role = "escape"  # tr("…" % x) ou tr("a" + "b") : traduire avant de composer
            elif callee in SINK_CALLS and whole_arg:
                role = "msgid"
            elif comment == "oui":
                role = "msgid"
            elif prv[1] in ("=", ":=") and nxt[0] in ("nl", "comment") or (nxt[1] == ";"):
                # Affectation directe à une propriété de texte d'un Control.
                j = len(prev) - 2
                target = prev[j][1] if j >= 0 else ""
                prop = re.sub(r"\s+", "", target).split(".")[-1]
                role = "msgid" if prop in SINK_PROPS else "escape"
            else:
                role = "escape"
            if role != "skip":
                out.append((line, value, role, func_of[line - 1]))
        prev.append((kind, text, line))
        if len(prev) > 4:
            prev.pop(0)
    # Pluriels : rattache le second argument au premier.
    return rel, out


def code_entries():
    """{msgid: {"refs": set, "plural": str|None}} et liste des textes qui échappent."""
    entries = {}
    escapes = []
    for path in sorted(glob.glob(os.path.join(GODOT, "scripts", "**", "*.gd"), recursive=True)):
        rel, lits = scan_gd(path)
        last = None
        for line, value, role, func in lits:
            if role == "msgid":
                e = entries.setdefault(value, {"refs": set(), "plural": None})
                e["refs"].add(f"{rel}:{line}")
                last = value
                last_line = line
            elif role == "plural" and last is not None:
                entries[last]["plural"] = value
            elif role == "context" and last is not None:
                # msgctxt : clé « contexte\x04msgid » (convention gettext).
                ref = f"{rel}:{last_line}"
                entries[last]["refs"].discard(ref)
                if not entries[last]["refs"]:
                    del entries[last]
                entries.setdefault(value + "\x04" + last, {"refs": set(), "plural": None})["refs"].add(ref)
                last = None
            elif role == "escape":
                escapes.append(f"{rel}:{line}: « {value} »" + (f" (dans {func})" if func else ""))
    return entries, escapes


# --- Données ----------------------------------------------------------------------------------

# Champs de texte affichés au joueur. Pas encore affichés (à ajouter le jour où ils le seront) :
# « theme » des grappes, « place » et « blurb » ; objectives.json (titres pour les robots et les tests).
DATA_TEXT_KEYS = {"name", "text", "names", "desc", "title", "label", "short", "phases",
                  "requires_text", "head", "map_name", "lines"}
DATA_SKIP_FILES = {"builds.json", "audio.json", "feel.json", "objectives.json"}
NUM_RE = re.compile(r"(?<![^\W\d_])(?<![\d{])\d+(?:,\d+)?(?![^\W\d_])(?![\d}])")


def template(s):
    """Même règle que Loc.template : chaque nombre devient {0}, {1}…"""
    n = [0]

    def rep(_m):
        r = "{%d}" % n[0]
        n[0] += 1
        return r
    return NUM_RE.sub(rep, s)


def data_entries():
    entries = {}

    def add(s, ref):
        if not isinstance(s, str) or not re.search(f"[{LETTERS}]", s):
            return
        tpl = template(s)
        e = entries.setdefault(tpl, {"refs": set(), "plural": None})
        e["refs"].add(ref)

    def walk(o, path, rel):
        if isinstance(o, dict):
            label = o.get("id") or o.get("key")
            for k, v in o.items():
                if k.startswith("_"):
                    continue
                sub = path + [str(label) if label and k != "id" and not path[-1:] == [str(label)] else None, k]
                sub = [p for p in sub if p]
                if k in DATA_TEXT_KEYS:
                    if isinstance(v, str):
                        add(v, f"{rel} › {' › '.join(sub)}")
                    elif isinstance(v, list):
                        for item in v:
                            if isinstance(item, str):
                                add(item, f"{rel} › {' › '.join(sub)}")
                            elif isinstance(item, list):
                                for w in item:
                                    add(w, f"{rel} › {' › '.join(sub)}")
                            else:
                                walk(item, sub, rel)
                    else:
                        walk(v, sub, rel)
                else:
                    walk(v, sub, rel)
        elif isinstance(o, list):
            for v in o:
                walk(v, path, rel)

    for path in sorted(glob.glob(os.path.join(GODOT, "data", "**", "*.json"), recursive=True)):
        rel = os.path.relpath(path, GODOT).replace(os.sep, "/")
        if os.path.basename(path) in DATA_SKIP_FILES:
            continue
        walk(json.load(open(path, encoding="utf-8")), [], rel)
    return entries


# --- Fichiers .po -----------------------------------------------------------------------------

def po_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def po_unescape(s):
    return re.sub(r'\\(.)', lambda m: {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(m.group(1), m.group(1)), s)


def po_string(key, s):
    if "\n" in s and len(s) > 1:
        parts = s.split("\n")
        chunks = [p + "\n" for p in parts[:-1]] + ([parts[-1]] if parts[-1] else [])
        return f'{key} ""\n' + "\n".join(f'"{po_escape(c)}"' for c in chunks) + "\n"
    return f'{key} "{po_escape(s)}"\n'


def read_po(path):
    """{msgid: {"str": [..], "plural": str|None}} (entrées actives) et en-tête."""
    out = {}
    if not os.path.exists(path):
        return out
    cur = None
    field = None
    entries = []
    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if line.startswith("#~") or line.startswith("#"):
            continue
        m = re.match(r'(msgctxt|msgid|msgid_plural|msgstr|msgstr\[(\d+)\])\s+"(.*)"$', line)
        if m:
            if m.group(1) == "msgctxt":
                cur = {"msgid": "", "ctx": po_unescape(m.group(3)), "plural": None, "str": {}}
                entries.append(cur)
                field = "msgctxt"
                continue
            if m.group(1) == "msgid" and not (cur is not None and cur.get("ctx") is not None and cur["msgid"] == "" and not cur["str"]):
                cur = {"msgid": "", "ctx": None, "plural": None, "str": {}}
                entries.append(cur)
            field = m.group(1)
            val = po_unescape(m.group(3))
            if field == "msgid":
                cur["msgid"] = val
            elif field == "msgid_plural":
                cur["plural"] = val
            elif field == "msgstr":
                cur["str"][0] = val
            else:
                cur["str"][int(m.group(2))] = val
                field = f"msgstr[{m.group(2)}]"
            continue
        m = re.match(r'"(.*)"$', line)
        if m and cur is not None:
            val = po_unescape(m.group(1))
            if field == "msgid":
                cur["msgid"] += val
            elif field == "msgid_plural":
                cur["plural"] += val
            elif field == "msgstr":
                cur["str"][0] = cur["str"].get(0, "") + val
            elif field and field.startswith("msgstr["):
                k = int(field[7:-1])
                cur["str"][k] = cur["str"].get(k, "") + val
    for e in entries:
        if e["msgid"] == "":
            continue
        key = (e["ctx"] + "\x04" + e["msgid"]) if e.get("ctx") is not None else e["msgid"]
        out[key] = {"str": [e["str"].get(i, "") for i in range(max(e["str"].keys(), default=0) + 1)],
                           "plural": e["plural"]}
    return out


def header(lang):
    h = 'msgid ""\nmsgstr ""\n'
    h += '"Project-Id-Version: Tree\\n"\n"MIME-Version: 1.0\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n'
    h += '"Content-Transfer-Encoding: 8bit\\n"\n'
    if lang:
        h += f'"Language: {lang}\\n"\n"Plural-Forms: {PLURAL_FORMS.get(lang, PLURAL_FORMS["en"])}\\n"\n'
    return h + "\n"


def project_entries():
    """Nom du jeu (project.godot › application/config/name), dans le contexte « nom du jeu »."""
    out = {}
    m = re.search(r'^config/name="(.*)"$', open(os.path.join(GODOT, "project.godot"), encoding="utf-8").read(), re.M)
    if m:
        out["nom du jeu\x04" + m.group(1)] = {"refs": {"project.godot › application/config/name"}, "plural": None}
    return out


def all_entries():
    code, escapes = code_entries()
    data = data_entries()
    merged = {}
    for src in (code, data, project_entries()):
        for k, v in src.items():
            e = merged.setdefault(k, {"refs": set(), "plural": None})
            e["refs"] |= v["refs"]
            e["plural"] = e["plural"] or v["plural"]
    return merged, escapes


def render(entries, lang, old):
    out = [header(lang)]
    for msgid in sorted(entries, key=lambda k: (sorted(entries[k]["refs"])[0], k)):
        e = entries[msgid]
        refs = sorted(e["refs"])
        for r in refs[:6]:
            out.append(f"#. {r}\n")
        if len(refs) > 6:
            out.append(f"#. … et {len(refs) - 6} autres\n")
        if "{0}" in msgid:
            out.append("#. {0}, {1}… : nombres du texte d'origine, remis au format de la langue.\n")
        if "\x04" in msgid:
            ctx, msgid_only = msgid.split("\x04", 1)
            out.append(po_string("msgctxt", ctx))
            out.append(po_string("msgid", msgid_only))
        else:
            out.append(po_string("msgid", msgid))
        if e["plural"]:
            out.append(po_string("msgid_plural", e["plural"]))
            if lang == SOURCE:
                strs = [msgid, e["plural"]]
            elif lang:
                strs = old.get(msgid, {}).get("str", ["", ""])
                strs = (strs + ["", ""])[:2]
            else:
                strs = ["", ""]
            for i, s in enumerate(strs):
                out.append(po_string(f"msgstr[{i}]", s))
        else:
            if lang == SOURCE:
                s = msgid.split("\x04", 1)[-1]
            elif lang:
                s = (old.get(msgid, {}).get("str") or [""])[0]
            else:
                s = ""
            out.append(po_string("msgstr", s))
        out.append("\n")
    # Textes disparus : gardés en commentaire (une traduction peut resservir).
    if lang and lang != SOURCE:
        for msgid, o in sorted(old.items()):
            if msgid in entries or not any(o["str"]):
                continue
            out.append("".join("#~ " + ln + "\n" for ln in po_string("msgid", msgid).rstrip("\n").split("\n")))
            out.append("".join("#~ " + ln + "\n" for ln in po_string("msgstr", o["str"][0]).rstrip("\n").split("\n")))
            out.append("\n")
    return "".join(out)


def expected_files():
    entries, escapes = all_entries()
    files = {os.path.join(LOCALE_DIR, "tree.pot"): render(entries, "", {})}
    for lang in LANGS:
        path = os.path.join(LOCALE_DIR, f"{lang}.po")
        files[path] = render(entries, lang, read_po(path))
    return entries, escapes, files


def cmd_extract():
    entries, escapes, files = expected_files()
    os.makedirs(LOCALE_DIR, exist_ok=True)
    for path, text in files.items():
        old = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
        if old != text:
            open(path, "w", encoding="utf-8").write(text)
            print("écrit", os.path.relpath(path, ROOT))
    print(f"{len(entries)} textes ({sum(1 for e in entries.values() if any(r.startswith('scripts/') for r in e['refs']))} du code)")
    if escapes:
        print(f"{len(escapes)} textes du code échappent à la traduction (tools/i18n.sh --lint)")
    return 0


def cmd_lint(quiet=False):
    _entries, escapes = code_entries()
    for e in escapes:
        print(e)
    if escapes:
        print(f"\n{len(escapes)} texte(s) français du code échappent à la traduction : tr(\"…\") / Loc.t, texte posé "
              "directement dans un Control, Loc.key(\"…\"), ou « # i18n: non » s'il n'est jamais affiché.")
        return 1
    if not quiet:
        print("Aucun texte du code n'échappe à la traduction.")
    return 0


def cmd_check():
    status = cmd_lint(quiet=True)
    _entries, _escapes, files = expected_files()
    stale = [p for p, t in files.items() if not os.path.exists(p) or open(p, encoding="utf-8").read() != t]
    for p in stale:
        print("catalogue pas à jour :", os.path.relpath(p, ROOT))
    if stale:
        print("Lancer tools/i18n.sh puis committer godot/locale/.")
        status = 1
    if status == 0:
        print("Catalogues à jour ; aucun texte du code n'échappe à la traduction.")
    return status


def coverage():
    entries, _ = all_entries()
    out = {}
    for lang in LANGS:
        po = read_po(os.path.join(LOCALE_DIR, f"{lang}.po"))
        done = [k for k in entries if any(po.get(k, {}).get("str", []))]
        out[lang] = (len(done), len(entries), [k for k in entries if k not in done])
    return out


def cmd_coverage():
    for lang, (done, total, _m) in coverage().items():
        print(f"{lang} : {done} / {total} textes traduits ({100.0 * done / max(total, 1):.1f} %)")
    return 0


def cmd_missing(lang):
    _d, _t, missing = coverage()[lang]
    entries, _ = all_entries()
    for k in missing:
        print(f"{sorted(entries[k]['refs'])[0]} : {k!r}")
    print(f"{len(missing)} texte(s) sans traduction en {lang}")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:] or ["extract"]
    if args[0] == "extract":
        sys.exit(cmd_extract())
    if args[0] == "check":
        sys.exit(cmd_check())
    if args[0] == "lint":
        sys.exit(cmd_lint())
    if args[0] == "coverage":
        sys.exit(cmd_coverage())
    if args[0] == "missing":
        sys.exit(cmd_missing(args[1] if len(args) > 1 else "en"))
    print(__doc__)
    sys.exit(2)
