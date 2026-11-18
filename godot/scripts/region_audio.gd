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

## Une couche musicale (dark / bright) d'une région : « <région>_sombre » et « <région>_lumineux ».
const LAYERS := {"sombre": "dark", "lumineux": "bright"}
const MUSIC_DIR := "res://assets/music/"
## Sons du boss reconnus (clé de « boss » → moment du combat).
const BOSS_KEYS := ["eveil", "phase", "mort"]
const SHAPES := ["dot", "glow", "streak"]


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


## Fichier d'une couche de la musique d'une région ("sombre" ou "lumineux").
static func music_path(id: String, layer: String) -> String:
	return MUSIC_DIR + ("%s_%s.wav" % [id, layer])


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


## Particules d'ambiance de la région ({} : celles du monde).
static func ambience(id: String) -> Dictionary:
	var a = of(id).get("ambience", {})
	return a if a is Dictionary else {}


## Son d'un moment du combat de boss (« eveil », « phase », « mort »), "" s'il n'y en a pas.
static func boss_sound(id: String, key: String) -> String:
	var b = of(id).get("boss", {})
	return str(b.get(key, "")) if b is Dictionary else ""


## Erreurs dans les réglages de son et d'ambiance (liste vide si tout va bien) : sons connus, musique
## qui boucle, formes et couleurs des particules.
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
		for layer in ["dark", "bright"]:
			var st = m.get(layer, {}) if m is Dictionary else {}
			if not st is Dictionary:
				errors.append("%s, music › %s : doit être un objet" % [w, layer])
				continue
			var base: Dictionary = Synth.DEFAULT_DARK if layer == "dark" else Synth.DEFAULT_BRIGHT
			for k in st:
				if not base.has(k):
					errors.append("%s, music › %s : réglage inconnu « %s »" % [w, layer, k])
			var chord = st.get("chord", base["chord"])
			if not chord is Array or chord.is_empty():
				errors.append("%s, music › %s : « chord » doit être une liste de demi-tons" % [w, layer])
			if layer == "dark":
				# La boucle dure 12 s : le vent doit y faire un nombre entier de cycles, sinon elle claque.
				var period := float(st.get("wind_period", base["wind_period"]))
				if period <= 0.0 or absf(12.0 / period - roundf(12.0 / period)) > 0.001:
					errors.append("%s, music › dark : « wind_period » (%s) doit diviser 12 s" % [w, period])
			else:
				var pat = st.get("pattern", base["pattern"])
				if not pat is Array or pat.is_empty() or pat.size() > 24:
					errors.append("%s, music › bright : « pattern » doit avoir de 1 à 24 notes (réparties sur 3 s)" % w)
		if m is Dictionary and m.has("roots") and (not m["roots"] is Array or m["roots"].size() != 4):
			errors.append("%s, music : « roots » doit avoir quatre fondamentales" % w)
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
			if p.has("color") and not Regions.color_ok(p["color"]):
				errors.append("%s, ambience › %s : « color » mal écrite" % [w, state])
		var b = a.get("boss", {})
		if b is Dictionary:
			for k in b:
				if not k in BOSS_KEYS:
					errors.append("%s, boss : moment inconnu « %s » (%s)" % [w, k, ", ".join(BOSS_KEYS)])
				elif not Synth.SOUNDS.has(str(b[k])):
					errors.append("%s, boss › %s : son inconnu « %s » (synth.gd › SOUNDS)" % [w, k, b[k]])
	return errors

