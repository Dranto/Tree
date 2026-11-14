## Contenu du jeu, lu une seule fois dans les fichiers de res://data/.
## Tout ce qui décrit l'arbre (statistiques, branches, nœuds clés, compétences) vit dans ces
## fichiers : ajouter ou modifier un effet ne demande pas de toucher au code.
## Le format est décrit dans res://data/README.md.
extends RefCounted

const DIR := "res://data/"
const OPS := ["add", "inc", "more", "flat"]
## Moments du jeu auxquels un effet peut réagir (champ « on »).
const EVENTS := ["kill", "crit", "lethal_hit"]
## Actions disponibles (champ « do ») et leurs paramètres obligatoires.
## Elles sont implémentées dans effect_actions.gd.
const ACTIONS := {
	"reduce_cooldown": ["target", "value"],
	"spread_poison": ["radius", "duration"],
	"explode": ["radius", "factor"],
	"survive": ["hp"],
}

static var _cache: Dictionary = {}


static func tree() -> Dictionary:
	return _load("tree")


static func stats() -> Dictionary:
	return _load("stats")


static func skills() -> Dictionary:
	return _load("skills")


static func conditions() -> Dictionary:
	return _load("conditions")


## Branches dans l'ordre de tree.json (cet ordre fixe leur place autour de la graine).
static func branches() -> Array:
	if not _cache.has("#branches"):
		var list: Array = []
		for id in tree().get("branches", []):
			var b: Dictionary = _load("branches/" + str(id))
			if not b.is_empty():
				list.append(b)
		_cache["#branches"] = list
	return _cache["#branches"]


static func _load(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".json"
	var data = null
	if FileAccess.file_exists(path):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK:
			data = json.data
		else:
			push_error("%s, ligne %d : %s" % [path, json.get_error_line(), json.get_error_message()])
	else:
		push_error("Fichier de données introuvable : " + path)
	if not data is Dictionary:
		data = {}
	_cache[name] = data
	return data


## Relit les données et renvoie la liste des erreurs (vide si tout est cohérent).
static func validate(keystones_per_branch := -1) -> PackedStringArray:
	_cache = {}
	var errors := PackedStringArray()
	for name in ["tree", "stats", "skills", "conditions"]:
		if _load(name).is_empty():
			errors.append("%s.json est absent, vide ou illisible" % name)
	var t := tree()
	_check_effects(t.get("root", {}).get("effects", []), "tree.json, graine", errors)
	var seen_keys := {}
	var ids: Array = t.get("branches", [])
	if ids.is_empty():
		errors.append("tree.json : aucune branche")
	for id in ids:
		var where := "branches/%s.json" % id
		var b: Dictionary = _load("branches/" + str(id))
		if b.is_empty():
			errors.append(where + " est absent, vide ou illisible")
			continue
		for field in ["id", "name", "color", "small", "notable", "keystones"]:
			if not b.has(field):
				errors.append("%s : champ « %s » manquant" % [where, field])
		if b.get("id", "") != id:
			errors.append("%s : « id » devrait valoir « %s »" % [where, id])
		var small: Array = b.get("small", [])
		if small.is_empty():
			errors.append(where + " : « small » doit contenir au moins un effet")
		for e in small:
			if not (e is Dictionary and e.has("stat")):
				errors.append(where + " : les petits nœuds n'acceptent que des effets de statistique")
		_check_effects(small, where + ", small", errors)
		var notable: Dictionary = b.get("notable", {})
		_check_effects(notable.get("effects", []), where + ", notable", errors)
		var names: Array = notable.get("names", [])
		if names.size() != 2 or names[0].is_empty() or names[1].is_empty():
			errors.append(where + " : « notable.names » doit contenir deux listes de mots non vides")
		var keystones: Array = b.get("keystones", [])
		if keystones_per_branch >= 0 and keystones.size() != keystones_per_branch:
			errors.append("%s : %d nœuds clés attendus, %d trouvés" % [where, keystones_per_branch, keystones.size()])
		for ks in keystones:
			var key: String = ks.get("key", "")
			var kw := "%s, nœud clé « %s »" % [where, key]
			if key == "" or ks.get("name", "") == "":
				errors.append(kw + " : « key » et « name » sont obligatoires")
			if seen_keys.has(key):
				errors.append(kw + " : clé déjà utilisée dans " + seen_keys[key])
			seen_keys[key] = where
			if ks.get("effects", []).is_empty() and ks.get("desc", "") == "":
				errors.append(kw + " : aucun effet")
			_check_effects(ks.get("effects", []), kw, errors)
	return errors


static func _check_effects(list, where: String, errors: PackedStringArray) -> void:
	if not list is Array:
		errors.append(where + " : « effects » doit être une liste")
		return
	for e in list:
		if not e is Dictionary:
			errors.append(where + " : un effet doit être un objet")
			continue
		if e.has("stat"):
			var def = stats().get(e["stat"])
			if def == null:
				errors.append("%s : statistique inconnue « %s »" % [where, e["stat"]])
			if not e.get("op", "") in OPS:
				errors.append("%s : opération inconnue « %s » (attendu : %s)" % [where, e.get("op", ""), ", ".join(OPS)])
			if not (e.get("value") is float or e.get("value") is int):
				errors.append("%s : « value » doit être un nombre pour « %s »" % [where, e["stat"]])
		elif e.has("skill"):
			if not skills().has(e["skill"]):
				errors.append("%s : compétence inconnue « %s »" % [where, e["skill"]])
		elif e.has("on"):
			if not e["on"] in EVENTS:
				errors.append("%s : évènement inconnu « %s » (attendu : %s)" % [where, e["on"], ", ".join(EVENTS)])
			var action: String = e.get("do", "")
			if not ACTIONS.has(action):
				errors.append("%s : action inconnue « %s » (attendu : %s)" % [where, action, ", ".join(ACTIONS.keys())])
			else:
				for p in ACTIONS[action]:
					if not e.has(p):
						errors.append("%s : l'action « %s » demande le paramètre « %s »" % [where, action, p])
			if e.get("text", "") == "":
				errors.append("%s : un effet déclenché doit avoir un « text » affiché au joueur" % where)
		else:
			errors.append("%s : effet sans « stat », « skill » ni « on »" % where)
		if e.has("if"):
			var cond = e["if"]
			if not (cond is Dictionary and conditions().has(cond.get("state", ""))):
				errors.append("%s : condition inconnue dans « if » (voir conditions.json)" % where)
	for name in stats():
		var def: Dictionary = stats()[name]
		if def.get("max") is String and not stats().has(def["max"]):
			errors.append("stats.json, %s : plafond inconnu « %s »" % [name, def["max"]])
