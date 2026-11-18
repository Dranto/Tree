## Contrôle des objectifs de l'aventure (data/objectives.json), appelé par check_data.gd.
## Sans aucun autoload : utilisable depuis un script lancé avec « -s ».
extends RefCounted

const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")
const CONDITION_TYPES := ["nodes", "flag", "flag_count", "keystone", "counter"]
const TARGET_TYPES := ["none", "group", "heart", "arena", "seed"]

static func validate() -> Array:
	var errors: Array = []
	var data: Dictionary = Content._load("objectives")
	var ids := {}
	var branch_ids: Array = Content.tree().get("branches", [])
	var mains := 0
	for o in data.get("objectives", []):
		var id := str(o.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("objectives.json : identifiant vide ou en double (« %s »)" % id)
		ids[id] = true
		for k in ["title", "text"]:
			if str(o.get(k, "")) == "":
				errors.append("objectif %s : « %s » manque" % [id, k])
		if o.get("main", false):
			mains += 1
		var reg := str(o.get("region", ""))
		if reg != "" and not Regions.exists(reg):
			errors.append("objectif %s : région inconnue « %s » (data/regions/)" % [id, reg])
		var c: Dictionary = o.get("condition", {})
		var ct := str(c.get("type", ""))
		if not ct in CONDITION_TYPES:
			errors.append("objectif %s : condition inconnue « %s »" % [id, ct])
		elif ct == "keystone" and not str(c.get("branch", "")) in branch_ids:
			errors.append("objectif %s : branche inconnue « %s »" % [id, c.get("branch", "")])
		elif ct in ["flag", "counter"] and str(c.get("flag", "")) == "":
			errors.append("objectif %s : « flag » manque" % id)
		elif ct in ["flag_count", "nodes", "counter"] and int(c.get("count", 0)) < 1:
			errors.append("objectif %s : « count » doit valoir au moins 1" % id)
		elif ct == "flag_count" and str(c.get("prefix", "")) == "":
			errors.append("objectif %s : « prefix » manque" % id)
		elif ct == "flag_count" and c.get("region_only", false) and reg == "":
			errors.append("objectif %s : « region_only » demande une « region »" % id)
		var tt := str(o.get("target", {}).get("type", "none"))
		if not tt in TARGET_TYPES:
			errors.append("objectif %s : cible inconnue « %s »" % [id, tt])
		elif tt == "group" and str(o["target"].get("group", "")) == "":
			errors.append("objectif %s : « group » manque" % id)
	if mains == 0:
		errors.append("objectives.json : aucun objectif principal")
	var adv = data.get("adventure_ending", {})
	if not adv is Dictionary or str(adv.get("title", "")) == "":
		errors.append("objectives.json : « adventure_ending » (sub, title, body) manque")
	for reg in Regions.ids():
		if str(Regions.section(reg, "ending").get("title", "")) == "":
			errors.append("data/regions/%s.json : « ending » (sub, title, body) manque" % reg)
	return errors
