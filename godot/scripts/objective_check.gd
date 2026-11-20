## Contrôle des objectifs de l'aventure (data/objectives.json), appelé par check_data.gd.
## Sans aucun autoload : utilisable depuis un script lancé avec « -s ».
extends RefCounted

const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")
const CONDITION_TYPES := ["nodes", "flag", "flag_count", "keystone", "counter"]
const TARGET_TYPES := ["none", "group", "heart", "arena", "seed", "finale"]
## Listes du générique remplies par le jeu (data/finale.json › credits › auto).
const CREDIT_AUTO := ["regions", "bosses"]

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
		if o.has("needs_flag") and str(o["needs_flag"]) == "":
			errors.append("objectif %s : « needs_flag » vide" % id)
	if mains == 0:
		errors.append("objectives.json : aucun objectif principal")
	var adv = data.get("adventure_ending", {})
	if not adv is Dictionary or str(adv.get("title", "")) == "":
		errors.append("objectives.json : « adventure_ending » (sub, title, body) manque")
	for reg in Regions.ids():
		if str(Regions.section(reg, "ending").get("title", "")) == "":
			errors.append("data/regions/%s.json : « ending » (sub, title, body) manque" % reg)
	return errors


## Contrôle de la finale (data/finale.json) : boss (script BossBase, trois phases, couleurs, arène),
## textes de l'épilogue et du générique.
static func validate_finale() -> Array:
	var errors: Array = []
	var w := "data/finale.json"
	var data: Dictionary = Content._load("finale")
	if data.is_empty():
		return [w + " : fichier absent ou illisible"]
	var b = data.get("boss", {})
	if not b is Dictionary:
		return [w + " : « boss » doit être un objet"]
	var path := str(b.get("script", ""))
	if not ResourceLoader.exists(path):
		errors.append("%s, boss : script introuvable « %s »" % [w, path])
	elif not "extends BossBase" in FileAccess.get_file_as_string(path):
		errors.append("%s, boss : « %s » doit étendre BossBase (scripts/boss_base.gd)" % [w, path])
	if str(b.get("name", "")) == "":
		errors.append("%s, boss : « name » manque" % w)
	if b.has("bar_color") and not Regions.color_ok(b["bar_color"]):
		errors.append("%s, boss : « bar_color » mal écrite" % w)
	var phases = b.get("phases", [])
	if not phases is Array or phases.size() != 3:
		errors.append("%s, boss : « phases » doit nommer les trois phases" % w)
	var ar = b.get("arena", {})
	if ar is Dictionary:
		if ar.has("life_color") and not Regions.color_ok(ar["life_color"]):
			errors.append("%s, boss › arena : « life_color » mal écrite" % w)
		if float(ar.get("radius_min", 0.0)) > float(ar.get("radius", 520.0)):
			errors.append("%s, boss › arena : « radius_min » plus grand que « radius »" % w)
	for k in ["opened_banner", "descent_banner"]:
		if str(data.get(k, "")) == "":
			errors.append("%s : « %s » manque" % [w, k])
	var ep = data.get("epilogue", {})
	for f in ["sub", "title", "body"]:
		if not ep is Dictionary or str(ep.get(f, "")) == "":
			errors.append("%s, epilogue : « %s » manque" % [w, f])
	var credits = data.get("credits", [])
	if not credits is Array or credits.is_empty():
		errors.append("%s : « credits » doit être une liste non vide" % w)
	else:
		for i in credits.size():
			var c = credits[i]
			if not c is Dictionary or (str(c.get("title", "")) == "" and str(c.get("head", "")) == ""):
				errors.append("%s, credits[%d] : « title » ou « head » manque" % [w, i])
			elif c.has("auto") and not str(c["auto"]) in CREDIT_AUTO:
				errors.append("%s, credits[%d] : liste automatique inconnue « %s » (%s)" % [w, i, c["auto"], ", ".join(CREDIT_AUTO)])
			elif c.has("lines") and not c["lines"] is Array:
				errors.append("%s, credits[%d] : « lines » doit être une liste" % [w, i])
	return errors
