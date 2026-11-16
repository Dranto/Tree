## Contenu du jeu, lu une seule fois dans les fichiers de res://data/.
## Tout ce qui décrit l'arbre (statistiques, branches, nœuds clés, compétences) vit dans ces
## fichiers : ajouter ou modifier un effet ne demande pas de toucher au code.
## Le format est décrit dans res://data/README.md.
extends RefCounted

const DIR := "res://data/"
const OPS := ["add", "inc", "more", "flat"]
## Opérations d'un effet « skill_mod » (mutation d'un réglage de compétence).
const SKILL_OPS := ["add", "inc", "more", "set"]
## Types de nœuds qu'une grappe écrite à la main peut contenir (voir skill_tree.gd).
const CLUSTER_TYPES := ["small", "notable", "keystone", "skill", "mutation", "mastery", "graft", "withered"]
## Moments du jeu auxquels un effet peut réagir (champ « on »).
## bleed_tick : à-coup de saignement ; root : ennemi enraciné ; melee_hit : coup au corps à corps.
## hurt : le joueur est touché (« base » = dégâts du coup) ; dash : le joueur esquive.
const EVENTS := ["kill", "crit", "lethal_hit", "bleed_tick", "root", "melee_hit", "hurt", "dash"]
## Actions disponibles (champ « do ») et leurs paramètres obligatoires.
## Elles sont implémentées dans effect_actions.gd.
const ACTIONS := {
	"reduce_cooldown": ["target", "value"],
	"spread_poison": ["radius", "duration"],
	"explode": ["radius", "factor"],
	"survive": ["hp"],
	"apply_status": ["status", "value", "duration"],
	"heal": ["value"],
	"burst": ["radius", "factor"],
	"status_area": ["status", "value", "duration", "radius"],
}
## Sources possibles d'une greffe (champ « sources » de grafts.json).
const GRAFT_SOURCES := ["autel", "boss", "secret", "elite", "quete"]

static var _cache: Dictionary = {}


static func tree() -> Dictionary:
	return _load("tree")


static func stats() -> Dictionary:
	return _load("stats")


static func skills() -> Dictionary:
	return _load("skills")


static func conditions() -> Dictionary:
	return _load("conditions")


## Greffes : objets à insérer dans un emplacement de greffe de l'arbre.
## Les clés qui commencent par « _ » (commentaires) sont écartées.
static func grafts() -> Dictionary:
	if not _cache.has("#grafts"):
		var out := {}
		var raw := _load("grafts")
		for id in raw:
			if not str(id).begins_with("_"):
				out[id] = raw[id]
		_cache["#grafts"] = out
	return _cache["#grafts"]


## Points et greffes du monde : boss, Cœurs, autels et secrets (data/rewards.json).
static func rewards() -> Dictionary:
	return _load("rewards")


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
	for name in ["tree", "stats", "skills", "conditions", "grafts", "rewards"]:
		if _load(name).is_empty():
			errors.append("%s.json est absent, vide ou illisible" % name)
	var t := tree()
	_check_effects(t.get("root", {}).get("effects", []), "tree.json, graine", errors)
	for gid in grafts():
		var g = grafts()[gid]
		var gw := "grafts.json, greffe « %s »" % gid
		if not (g is Dictionary and g.get("name", "") != ""):
			errors.append(gw + " : « name » est obligatoire")
			continue
		if not (g.get("effects") is Array) or g["effects"].is_empty():
			errors.append(gw + " : aucun effet")
		_check_effects(g.get("effects", []), gw, errors)
		for src in g.get("sources", []):
			if not src in GRAFT_SOURCES:
				errors.append("%s : source inconnue « %s » (attendu : %s)" % [gw, src, ", ".join(GRAFT_SOURCES)])
	_check_rewards(errors)
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
		_check_resonance(b.get("resonance", []), where, errors)
		_check_clusters(b.get("clusters", []), where, seen_keys, errors)
	return errors


## Résonance de branche : paliers croissants, chacun avec des effets.
static func _check_resonance(list, where: String, errors: PackedStringArray) -> void:
	if not list is Array:
		errors.append(where + " : « resonance » doit être une liste")
		return
	var last := 0
	for tier in list:
		if not (tier is Dictionary and (tier.get("count") is float or tier.get("count") is int) and int(tier["count"]) > last):
			errors.append(where + " : chaque palier de « resonance » demande un « count » entier, croissant")
			continue
		last = int(tier["count"])
		var tw := "%s, résonance à %d nœuds" % [where, last]
		if not (tier.get("effects") is Array) or tier["effects"].is_empty():
			errors.append(tw + " : aucun effet")
		_check_effects(tier.get("effects", []), tw, errors)


## Grappes écrites à la main : identifiants uniques, liens existants, champs propres à chaque type,
## et aucun nœud isolé (chaque nœud doit rejoindre une entrée par les liens de la grappe).
static func _check_clusters(list, where: String, seen_keys: Dictionary, errors: PackedStringArray) -> void:
	if not list is Array:
		errors.append(where + " : « clusters » doit être une liste")
		return
	var seen := {}
	for c in list:
		if not c is Dictionary:
			errors.append(where + " : une grappe doit être un objet")
			continue
		var cid := str(c.get("id", ""))
		var cw := "%s, grappe « %s »" % [where, cid]
		if cid == "" or cid.contains(":") or cid.contains(","):
			errors.append(cw + " : « id » obligatoire, sans « : » ni virgule")
		if seen.has(cid):
			errors.append(cw + " : identifiant de grappe déjà utilisé dans cette branche")
		seen[cid] = true
		if str(c.get("name", "")) == "":
			errors.append(cw + " : « name » est obligatoire")
		if not (c.get("ring") is float or c.get("ring") is int) or float(c["ring"]) < 1.0:
			errors.append(cw + " : « ring » doit être un nombre d'au moins 1")
		if not (c.get("angle") is float or c.get("angle") is int):
			errors.append(cw + " : « angle » doit être un nombre (fraction du secteur de la branche)")
		var nodes = c.get("nodes")
		if not (nodes is Array) or nodes.is_empty():
			errors.append(cw + " : « nodes » doit contenir au moins un nœud")
			continue
		var ids := {}
		for cn in nodes:
			if not cn is Dictionary:
				errors.append(cw + " : un nœud doit être un objet")
				continue
			var nid := str(cn.get("id", ""))
			if nid == "" or nid.contains(":") or nid.contains(","):
				errors.append("%s : chaque nœud demande un « id », sans « : » ni virgule" % cw)
			if ids.has(nid):
				errors.append("%s : identifiant de nœud « %s » utilisé deux fois" % [cw, nid])
			ids[nid] = cn
		var links := {}
		for nid in ids:
			links[nid] = []
		for nid in ids:
			var cn: Dictionary = ids[nid]
			_check_cluster_node(cn, "%s, nœud « %s »" % [cw, nid], seen_keys, where, errors)
			if cn.has("links") and not cn["links"] is Array:
				errors.append("%s, nœud « %s » : « links » doit être une liste" % [cw, nid])
				continue
			for l in cn.get("links", []):
				if not ids.has(str(l)) or str(l) == nid:
					errors.append("%s, nœud « %s » : lien vers un nœud inconnu « %s »" % [cw, nid, l])
				else:
					links[nid].append(str(l))
					links[str(l)].append(nid)
		var entry = c.get("entry")
		if not (entry is Array) or entry.is_empty():
			errors.append(cw + " : « entry » doit lister au moins un nœud relié au reste de l'arbre")
			continue
		var reached := {}
		var stack: Array = []
		for e in entry:
			if not ids.has(str(e)):
				errors.append("%s : entrée inconnue « %s »" % [cw, e])
			elif not reached.has(str(e)):
				reached[str(e)] = true
				stack.append(str(e))
		while stack.size() > 0:
			for m in links[stack.pop_back()]:
				if not reached.has(m):
					reached[m] = true
					stack.append(m)
		for nid in ids:
			if not reached.has(nid):
				errors.append("%s : le nœud « %s » est isolé (aucun lien ne le rattache à une entrée)" % [cw, nid])
		if c.has("complete"):
			var complete = c["complete"]
			if not (complete is Dictionary and complete.get("effects") is Array and not complete["effects"].is_empty()):
				errors.append(cw + " : « complete » demande une liste « effects » non vide")
			else:
				_check_effects(complete["effects"], cw + ", grappe complète", errors)


static func _check_cluster_node(cn: Dictionary, where: String, seen_keys: Dictionary, file: String, errors: PackedStringArray) -> void:
	var kind := str(cn.get("type", ""))
	if not kind in CLUSTER_TYPES:
		errors.append("%s : type inconnu « %s » (attendu : %s)" % [where, kind, ", ".join(CLUSTER_TYPES)])
		return
	var at = cn.get("at")
	if not (at is Array and at.size() == 2 and (at[0] is float or at[0] is int) and (at[1] is float or at[1] is int)):
		errors.append(where + " : « at » doit être [x, y] en unités d'anneau")
	var effects = cn.get("effects", [])
	_check_effects(effects, where, errors)
	var has_effects: bool = effects is Array and not effects.is_empty()
	if kind in ["small", "notable", "withered"] and not has_effects:
		errors.append(where + " : aucun effet")
	if kind in ["notable", "keystone", "mastery", "withered"] and str(cn.get("name", "")) == "":
		errors.append(where + " : « name » est obligatoire pour ce type")
	match kind:
		"keystone":
			var key := str(cn.get("key", ""))
			if key == "":
				errors.append(where + " : un nœud clé demande une « key »")
			elif seen_keys.has(key):
				errors.append("%s : clé « %s » déjà utilisée dans %s" % [where, key, seen_keys[key]])
			seen_keys[key] = file
			if not has_effects and str(cn.get("desc", "")) == "":
				errors.append(where + " : aucun effet")
		"skill":
			var gives := str(cn.get("skill", ""))
			if effects is Array:
				for e in effects:
					if e is Dictionary and e.has("skill"):
						gives = str(e["skill"])
			if gives == "":
				errors.append(where + " : un nœud de compétence demande « skill » (ou un effet {\"skill\": …})")
			elif not skills().has(gives):
				errors.append("%s : compétence inconnue « %s »" % [where, gives])
		"mutation":
			if not skills().has(str(cn.get("mutates", ""))):
				errors.append("%s : « mutates » doit nommer une compétence de skills.json (« %s » inconnue)" % [where, cn.get("mutates", "")])
			_check_choices(cn.get("choices"), 2, 3, where, errors)
		"mastery":
			_check_choices(cn.get("choices"), 3, 3, where, errors)
		"withered":
			if str(cn.get("requires_flag", "")) == "":
				errors.append(where + " : un nœud flétri demande « requires_flag »")
		"graft":
			if has_effects:
				errors.append(where + " : un emplacement de greffe ne porte pas d'effet (c'est la greffe qui en donne)")
	if kind != "mutation" and kind != "mastery" and cn.has("choices"):
		errors.append(where + " : « choices » n'existe que pour les types mutation et mastery")
	if cn.has("excludes") and not cn["excludes"] is Array:
		errors.append(where + " : « excludes » doit être une liste")


static func _check_choices(list, at_least: int, at_most: int, where: String, errors: PackedStringArray) -> void:
	if not (list is Array) or list.size() < at_least or list.size() > at_most:
		var want := str(at_least) if at_least == at_most else "%d ou %d" % [at_least, at_most]
		errors.append("%s : « choices » doit proposer %s choix" % [where, want])
		return
	var seen := {}
	for i in list.size():
		var ch = list[i]
		if not (ch is Dictionary and str(ch.get("name", "")) != ""):
			errors.append("%s : chaque choix demande un « name »" % where)
			continue
		var cid := str(ch.get("id", i))
		if seen.has(cid):
			errors.append("%s : identifiant de choix « %s » utilisé deux fois" % [where, cid])
		seen[cid] = true
		var cw := "%s, choix « %s »" % [where, ch["name"]]
		if not (ch.get("effects") is Array) or ch["effects"].is_empty():
			errors.append(cw + " : aucun effet")
		_check_effects(ch.get("effects", []), cw, errors)


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
		elif e.has("skill_mod"):
			var target = skills().get(e["skill_mod"])
			var op: String = str(e.get("op", ""))
			if not target is Dictionary:
				errors.append("%s : « skill_mod » vise une compétence inconnue « %s »" % [where, e["skill_mod"]])
			elif op != "set" and not (target.get(e.get("param", "")) is float or target.get(e.get("param", "")) is int):
				errors.append("%s : « %s » n'est pas un réglage numérique de la compétence « %s »" % [where, e.get("param", ""), e["skill_mod"]])
			if str(e.get("param", "")) == "":
				errors.append("%s : « skill_mod » demande un « param »" % where)
			if not op in SKILL_OPS:
				errors.append("%s : opération inconnue « %s » pour « skill_mod » (attendu : %s)" % [where, op, ", ".join(SKILL_OPS)])
			if op != "set" and not (e.get("value") is float or e.get("value") is int):
				errors.append("%s : « value » doit être un nombre pour « skill_mod »" % where)
			if not e.has("value"):
				errors.append("%s : « skill_mod » demande une « value »" % where)
			if e.get("text", "") == "" and not e.get("hidden", false):
				errors.append("%s : un effet « skill_mod » doit avoir un « text » affiché au joueur (ou « hidden »)" % where)
			if e.has("if"):
				errors.append("%s : un effet « skill_mod » n'accepte pas de condition" % where)
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
			errors.append("%s : effet sans « stat », « skill », « skill_mod » ni « on »" % where)
		if e.has("if"):
			var cond = e["if"]
			if not (cond is Dictionary and conditions().has(cond.get("state", ""))):
				errors.append("%s : condition inconnue dans « if » (voir conditions.json)" % where)
	for name in stats():
		var def: Dictionary = stats()[name]
		if def.get("max") is String and not stats().has(def["max"]):
			errors.append("stats.json, %s : plafond inconnu « %s »" % [name, def["max"]])


## rewards.json : chaque greffe nommée existe, chaque autel et secret a un identifiant unique,
## une région connue et une position dans le secteur.
static func _check_rewards(errors: PackedStringArray) -> void:
	var r := rewards()
	var regions: Array = tree().get("branches", [])
	for kind in ["boss", "coeur"]:
		var per = r.get(kind, {})
		if not per is Dictionary:
			errors.append("rewards.json : « %s » doit être un objet par région" % kind)
			continue
		for reg in per:
			var where := "rewards.json, %s « %s »" % [kind, reg]
			if not reg in regions:
				errors.append(where + " : région inconnue")
			if int(per[reg].get("points", 0)) < 0:
				errors.append(where + " : « points » ne peut pas être négatif")
			var g := str(per[reg].get("graft", ""))
			if g != "" and not grafts().has(g):
				errors.append("%s : greffe inconnue « %s »" % [where, g])
	var seen := {}
	for kind in ["altars", "secrets"]:
		var list = r.get(kind, [])
		if not list is Array:
			errors.append("rewards.json : « %s » doit être une liste" % kind)
			continue
		for a in list:
			var where: String = "rewards.json, %s « %s »" % [kind, a.get("id", "?")]
			var key: String = kind + ":" + str(a.get("id", ""))
			if str(a.get("id", "")) == "" or seen.has(key):
				errors.append(where + " : « id » manquant ou en double")
			seen[key] = true
			if not str(a.get("region", "")) in regions:
				errors.append(where + " : région inconnue")
			if not (a.get("dist") is float or a.get("dist") is int) or absf(float(a.get("side", 0.0))) > 1.0:
				errors.append(where + " : « dist » (pixels) et « side » (-1 à 1) sont obligatoires")
			var g := str(a.get("graft", ""))
			if g != "" and not grafts().has(g):
				errors.append("%s : greffe inconnue « %s »" % [where, g])
