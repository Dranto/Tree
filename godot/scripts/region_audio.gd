## Son et ambiance d'une région : musique (réglages de synth.gd), particules de l'ambiance (ambience.gd)
## et sons du boss. Les réglages viennent de la section « audio » du fichier de la région
## (data/regions/<id>.json), à défaut de data/audio.json › regions › <id>. Une région sans réglages garde
## la musique et les particules de Ronce (le monde).
##
## Logique pure (aucun nœud) : lue par music.gd, ambience.gd, boss_base.gd, gen_sounds.gd et check_data.gd.
extends RefCounted

const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")
const Synth = preload("res://scripts/synth.gd")

const MusicSynth = preload("res://scripts/music_synth.gd")

## Couches musicales d'une région : fichier « <région>_<couche>.wav » → section de réglages.
const LAYERS := MusicSynth.LAYERS
const MUSIC_DIR := "res://assets/music/"
## Nappes d'ambiance sonore : « <région>_mort.wav » (terre morte) et « <région>_vif.wav » (terre vivante).
const BED_STATES := {"mort": "dead", "vif": "alive"}
const BED_DIR := "res://assets/ambience/"
## Sons du boss reconnus (clé de « boss » → moment du combat).
## « exalte » : entrée dans la phase exaltée (cycle 2 et après, point d'accroche « boss_exalte »).
const BOSS_KEYS := ["eveil", "phase", "mort", "exalte"]
## Moments qu'un boss peut ne pas avoir (la Flétrissure n'est pas encore exaltée : son de phase à la place).
const BOSS_OPTIONAL := ["exalte"]
## Toniques d'un morceau de boss fait à la main (« hand_track » : gamme sur laquelle les bruitages s'accordent).
const HAND_TONICS := ["do", "do#", "ré", "mib", "mi", "fa", "fa#", "sol", "lab", "la", "sib", "si"]
const SHAPES := ["dot", "glow", "streak", "drop", "chip", "feather"]


## Réglages d'une région ({} sans réglages) : la section « audio » de son fichier, sinon l'entrée de data/audio.json.
static func of(id: String) -> Dictionary:
	var own = Regions.def(id).get("audio", null)
	if own is Dictionary:
		return own
	var shared = Content._load("audio").get("regions", {}).get(id, {})
	return shared if shared is Dictionary else {}


## Régions qui ont une musique propre (celles qui existent, dans l'ordre du monde).
static func music_regions() -> Array:
	return Regions.ids().filter(func(id): return music_style(id).size() > 0)


## Réglages de musique d'une région ({} : celle du monde).
static func music_style(id: String) -> Dictionary:
	var m = of(id).get("music", {})
	return m if m is Dictionary else {}


## Couches que la musique d'une région écrit (toutes par défaut ; « layers » pour n'en garder que certaines).
static func music_layers(style: Dictionary) -> Array:
	var l = style.get("layers", null)
	return l if l is Array else LAYERS.keys()


## Fichier d'une couche de la musique d'une région ("" : le monde).
static func music_path(id: String, layer: String) -> String:
	return MUSIC_DIR + (layer if id == "" else "%s_%s" % [id, layer]) + ".wav"


## Réglages de musique de toutes les régions de data/audio.json et des fichiers de régions : id -> réglages.
## C'est ce que lit gen_sounds.gd, pour que les pistes existent avant même que la région soit jouable.
static func all_music_styles() -> Dictionary:
	var out := {}
	for id in Content._load("audio").get("regions", {}):
		var m = of(str(id)).get("music", {})
		if m is Dictionary and m.size() > 0:
			out[str(id)] = m
	for id in Regions.ids():
		if music_style(id).size() > 0:
			out[id] = music_style(id)
	return out


## Nappes d'ambiance sonore d'une région ({} : celles du monde).
static func bed(id: String) -> Dictionary:
	var b = of(id).get("bed", {})
	return b if b is Dictionary else {}


static func bed_path(id: String, state: String) -> String:
	return BED_DIR + (state if id == "" else "%s_%s" % [id, state]) + ".wav"


static func all_beds() -> Dictionary:
	var out := {}
	for id in Content._load("audio").get("regions", {}):
		if bed(str(id)).size() > 0:
			out[str(id)] = bed(str(id))
	for id in Regions.ids():
		if bed(id).size() > 0:
			out[id] = bed(id)
	return out


## Particules d'ambiance de la région ({} : celles du monde).
static func ambience(id: String) -> Dictionary:
	var a = of(id).get("ambience", {})
	return a if a is Dictionary else {}


## Son d'un moment du combat de boss (« eveil », « phase », « mort »), "" s'il n'y en a pas.
static func boss_sound(id: String, key: String) -> String:
	var b = of(id).get("boss", {})
	return str(b.get(key, "")) if b is Dictionary else ""


## Erreurs dans les réglages de son et d'ambiance (liste vide si tout va bien) : réglages connus, motifs,
## percussions, sons des boss, formes et couleurs des particules.
static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var entries := {}
	for id in Content._load("audio").get("regions", {}):
		entries[str(id)] = "data/audio.json › %s" % id
	for id in Regions.ids():
		if Regions.def(id).get("audio") is Dictionary:
			entries[id] = "%s › audio" % Regions.def(id).get("_path", id)
	for id in entries:
		var w: String = entries[id]
		var a := of(id)
		var m = a.get("music", {})
		if not m is Dictionary:
			errors.append("%s, music : doit être un objet" % w)
			m = {}
		_check_music(errors, w, m)
		var b = a.get("bed", {})
		if not b is Dictionary:
			errors.append("%s, bed : doit être un objet" % w)
		else:
			_check_bed(errors, w, b)
		var amb: Dictionary = a.get("ambience", {}) if a.get("ambience", {}) is Dictionary else {}
		for state in ["dead", "alive"]:
			if not amb.has(state):
				continue
			var p = amb[state]
			if not p is Dictionary:
				errors.append("%s, ambience › %s : doit être un objet" % [w, state])
				continue
			if not str(p.get("shape", "dot")) in SHAPES:
				errors.append("%s, ambience › %s : forme inconnue « %s » (%s)" % [w, state, p.get("shape"), ", ".join(SHAPES)])
			if p.has("alt") and not str(p["alt"]) in SHAPES:
				errors.append("%s, ambience › %s : forme « alt » inconnue « %s » (%s)" % [w, state, p.get("alt"), ", ".join(SHAPES)])
			if p.has("color") and not Regions.color_ok(p["color"]):
				errors.append("%s, ambience › %s : « color » mal écrite" % [w, state])
		var ht = a.get("hand_track", null)
		if ht != null and (not ht is Dictionary or not HAND_TONICS.has(str(ht.get("tonique", ""))) \
				or not MusicSynth.SCALES.has(str(ht.get("mode", "eolien")))):
			errors.append("%s, hand_track : {\"tonique\": %s, \"mode\": %s}" % [w, "/".join(HAND_TONICS), "/".join(MusicSynth.SCALES.keys())])
		var bs = a.get("boss", {})
		if bs is Dictionary:
			for k in bs:
				if not k in BOSS_KEYS:
					errors.append("%s, boss : moment inconnu « %s » (%s)" % [w, k, ", ".join(BOSS_KEYS)])
				elif not Synth.SOUNDS.has(str(bs[k])):
					errors.append("%s, boss › %s : son inconnu « %s » (synth.gd › SOUNDS)" % [w, k, bs[k]])
	return errors


static func _check_music(errors: PackedStringArray, w: String, m: Dictionary) -> void:
	for k in m:
		if not k in ["seed", "roots", "roots_b", "key", "qualities", "layers"] and not k in MusicSynth.DEFAULTS:
			errors.append("%s, music : réglage inconnu « %s »" % [w, k])
	if m.has("roots") and (not m["roots"] is Array or m["roots"].size() != 4):
		errors.append("%s, music : « roots » doit avoir quatre fondamentales" % w)
	if m.has("roots_b") and (not m["roots_b"] is Array or m["roots_b"].size() != 4):
		errors.append("%s, music : « roots_b » (seconde moitié de la boucle) doit avoir quatre fondamentales" % w)
	if m.has("qualities"):
		var q = m["qualities"]
		if not q is Array or q.size() != MusicSynth.CHORDS or q.any(func(x): return not MusicSynth.QUALITIES.has(str(x))):
			errors.append("%s, music : « qualities » : huit couleurs d'accord parmi %s" % [w, ", ".join(MusicSynth.QUALITIES.keys())])
	if m.has("key") and not (m["key"] is float or m["key"] is int):
		errors.append("%s, music : « key » (transposition en demi-tons) doit être un nombre" % w)
	if m.has("mode") and not MusicSynth.SCALES.has(str(m["mode"])):
		errors.append("%s, music : gamme « mode » inconnue « %s » (%s)" % [w, m["mode"], ", ".join(MusicSynth.SCALES.keys())])
	if m.has("layers"):
		if not m["layers"] is Array or m["layers"].is_empty():
			errors.append("%s, music › layers : une liste de couches" % w)
		else:
			for l in m["layers"]:
				if not LAYERS.has(str(l)):
					errors.append("%s, music › layers : couche inconnue « %s » (%s)" % [w, l, ", ".join(LAYERS.keys())])
	for sec in MusicSynth.DEFAULTS:
		if sec in ["seed", "roots", "roots_b", "key", "qualities", "mode"] or not m.has(sec):
			continue
		var st = m[sec]
		if not st is Dictionary:
			errors.append("%s, music › %s : doit être un objet" % [w, sec])
			continue
		var base: Dictionary = MusicSynth.DEFAULTS[sec]
		var where := "%s, music › %s" % [w, sec]
		for k in st:
			if not base.has(k):
				errors.append("%s : réglage inconnu « %s »" % [where, k])
			elif base[k] is float and not (st[k] is float or st[k] is int):
				errors.append("%s : « %s » doit être un nombre" % [where, k])
		if st.has("chord") and (not st["chord"] is Array or st["chord"].is_empty()):
			errors.append("%s : « chord » doit être une liste de demi-tons" % where)
		if st.has("pattern") and (not st["pattern"] is Array or st["pattern"].is_empty() or st["pattern"].size() > 24):
			errors.append("%s : « pattern » doit avoir de 1 à 24 notes (réparties sur 3 s)" % where)
		if st.has("pattern_b") and (not st["pattern_b"] is Array or st["pattern_b"].size() > 24):
			errors.append("%s : « pattern_b » doit avoir de 0 à 24 notes (vide : « pattern » à l'envers)" % where)
		if st.has("pad_tone") and not str(st["pad_tone"]) in MusicSynth.PAD_TONES:
			errors.append("%s : timbre de nappe inconnu « %s » (%s)" % [where, st["pad_tone"], ", ".join(MusicSynth.PAD_TONES)])
		if st.has("arp") and not str(st["arp"]) in MusicSynth.ARPS:
			errors.append("%s : arpège inconnu « %s » (%s)" % [where, st["arp"], ", ".join(MusicSynth.ARPS)])
		if st.has("kit") and not str(st["kit"]) in MusicSynth.KITS:
			errors.append("%s : percussions inconnues « %s » (%s)" % [where, st["kit"], ", ".join(MusicSynth.KITS)])
		if st.has("vowel") and not MusicSynth.VOWELS.has(str(st["vowel"])):
			errors.append("%s : voyelle inconnue « %s »" % [where, st["vowel"]])
		for tk in ["lead_tone", "counter_tone"]:
			if st.has(tk) and not str(st[tk]) in MusicSynth.TONES:
				errors.append("%s : « %s » inconnu « %s » (%s)" % [where, tk, st[tk], ", ".join(MusicSynth.TONES)])
		for part in ["kick", "snare", "hat", "tom"]:
			if st.has(part):
				var pat := str(st[part])
				var ok := pat.is_empty() or (16 % pat.length() == 0 if pat.length() <= 16 else false)
				for ch in pat:
					ok = ok and ch in ["x", "o", "."]
				if not ok:
					errors.append("%s › %s : 1, 2, 4, 8 ou 16 cases parmi « x », « o », « . »" % [where, part])
		if st.has("bass"):
			var bass = st["bass"]
			if not bass is Array or bass.is_empty() or bass.size() > 16:
				errors.append("%s › bass : de 1 à 16 notes (demi-tons, ou null pour un silence)" % where)
		for mk in ["motif", "motif_b"]:
			if not st.has(mk):
				continue
			var mo = st[mk]
			if not mo is Array:
				errors.append("%s › motif : une liste de notes [croche, note de l'accord, durée]" % where)
			else:
				for note in mo:
					if not note is Array or note.size() < 3 or note.size() > 4 or int(note[0]) < 0 or int(note[0]) > 31 or float(note[2]) <= 0.0:
						errors.append("%s › motif : note mal écrite %s ([croche 0 à 31, note de l'accord, durée en croches, altération])" % [where, note])
						break


static func _check_bed(errors: PackedStringArray, w: String, b: Dictionary) -> void:
	for k in b:
		if not k in ["seed", "dead", "alive"]:
			errors.append("%s, bed : réglage inconnu « %s » (seed, dead, alive)" % [w, k])
	for state in ["dead", "alive"]:
		if not b.has(state):
			continue
		var st = b[state]
		if not st is Dictionary:
			errors.append("%s, bed › %s : doit être un objet" % [w, state])
			continue
		for k in st:
			if not MusicSynth.BED_DEFAULTS[state].has(k):
				errors.append("%s, bed › %s : réglage inconnu « %s »" % [w, state, k])
		for ev in st.get("events", []):
			if not ev is Dictionary or not str(ev.get("kind", "")) in MusicSynth.BED_EVENTS:
				errors.append("%s, bed › %s › events : sorte inconnue %s (%s)" % [w, state, ev, ", ".join(MusicSynth.BED_EVENTS)])
