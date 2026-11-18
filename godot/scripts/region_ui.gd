## Ce que la carte, le journal et le suivi d'objectif disent d'une région : sa couleur, son nom et son
## avancement. Tout vient de data/regions/<id>.json et des drapeaux de la partie (Game.flags), donc
## une région ajoutée par ses fichiers apparaît d'elle-même. Aucun nœud.
extends RefCounted

const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")


## Couleur de la région : celle de sa branche dans l'Arbre de vie.
static func tint(id: String) -> Color:
	var bi: int = Content.tree().get("branches", []).find(Regions.branch_of(id))
	return Game.tree.branch_color(bi) if bi >= 0 else Color(Regions.def(id).get("color", "#9ab09a"))


## Nom court (« map_name » : Roncier) et nom complet (« name » : Région de Ronce).
static func short_name(id: String) -> String:
	return str(Regions.def(id).get("map_name", id.capitalize()))


static func full_name(id: String) -> String:
	return str(Regions.def(id).get("name", short_name(id)))


## Avancement : {sanctuaires: [ravivés, total], autels: [trouvés, total], secrets: [trouvés, total],
## coeur: purifié ?, boss: vaincu ?}.
static func progress(id: String, flags: Dictionary = Game.flags) -> Dictionary:
	var d := Regions.def(id)
	var out := {}
	for pair in [["sanctuaires", "sanctuaries", "sanctuaire_"], ["autels", "altars", "autel_"], ["secrets", "secrets", "secret_"]]:
		var total := 0
		var done := 0
		for spot in d.get(pair[1], []):
			total += 1
			if bool(flags.get(pair[2] + str(spot.get("id", "")), false)):
				done += 1
		out[pair[0]] = [done, total]
	out["coeur"] = bool(flags.get(Regions.heart_flag(id), false))
	out["boss"] = bool(flags.get(Regions.boss_flag(id), false))
	return out


## Une ligne d'avancement : « 1 / 4 sanctuaires · 0 / 4 autels ».
static func summary(id: String, flags: Dictionary = Game.flags) -> String:
	var p := progress(id, flags)
	var parts: Array = []
	for k in ["sanctuaires", "autels"]:
		if p[k][1] > 0:
			parts.append("%d / %d %s" % [p[k][0], p[k][1], k])
	return " · ".join(parts)


## Où en est la région : « Boss vaincu », « Cœur purifié », ou "" tant que rien n'est fait.
static func state(id: String, flags: Dictionary = Game.flags) -> String:
	var p := progress(id, flags)
	if p["boss"]:
		return "région purifiée"
	if p["coeur"]:
		return "Cœur purifié"
	return ""
