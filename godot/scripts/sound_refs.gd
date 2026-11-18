## Vérifie que chaque son nommé dans les données existe (synth.gd › SOUNDS) : compétences
## (skills.json › « sound »), formes et modificateurs d'attaque (attack.json › « sound »), sortes d'ennemis
## (enemies.json › « sound_hit », « sound_crit », « sound_death »). Un son inconnu serait ignoré sans bruit en jeu.
## Logique pure : lue par check_data.gd.
extends RefCounted

const Content = preload("res://scripts/content.gd")
const Synth = preload("res://scripts/synth.gd")

const ENEMY_KEYS := ["sound_hit", "sound_crit", "sound_death"]


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var skills: Dictionary = Content._load("skills")
	for id in skills:
		if skills[id] is Dictionary:
			_check(errors, "skills.json, %s" % id, skills[id], "sound")
	var attack: Dictionary = Content._load("attack")
	for part in ["forms", "mods"]:
		var d = attack.get(part, {})
		if d is Dictionary:
			for id in d:
				if d[id] is Dictionary:
					_check(errors, "attack.json › %s, %s" % [part, id], d[id], "sound")
	for k in Content._load("enemies").get("kinds", []):
		for key in ENEMY_KEYS:
			_check(errors, "enemies.json, %s" % k.get("id", "?"), k, key)
	return errors


static func _check(errors: PackedStringArray, where: String, d: Dictionary, key: String) -> void:
	if d.has(key) and not Synth.SOUNDS.has(str(d[key])):
		errors.append("%s : son inconnu « %s » dans « %s » (synth.gd › SOUNDS)" % [where, d[key], key])
