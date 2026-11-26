## Outils des planches des Flétris de Ronce (refonte des personnages, tâche R1) : la distribution de la
## région, et les outils communs des planches (sol, dessin « avant » et « après »).
extends RefCounted

const Base = preload("res://tests/bestiaire/commun.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")

const S1080 := Base.S1080

## Sortes de Ronce : id de enemies.json, nom, rôle, rayon de collision (inchangé).
const CAST := [
	{"id": "tireur", "nom": "Tireur d'épines", "region": "ronce", "role": "tireur", "r": 13.0},
	{"id": "chargeur", "nom": "Chargeur", "region": "ronce", "role": "chargeur", "r": 18.0},
	{"id": "nid", "nom": "Nid de ronces", "region": "ronce", "role": "soutien (nid)", "r": 26.0},
	{"id": "rejeton", "nom": "Rejeton", "region": "ronce", "role": "essaim", "r": 8.0},
]


static func art_of(id: String):
	if id == "heros":
		return Esprit
	return load("res://scripts/creature_art/ronce/%s.gd" % id)


static func ground_colors(region: String) -> Array:
	return Base.ground_colors(region)


static func draw_ground(ci: CanvasItem, rect: Rect2, region: String, seed := 7) -> void:
	Base.draw_ground(ci, rect, region, seed)


static func draw_before(ci: CanvasItem, id: String, r: float, pos: Vector2, s: float, o := {}, face := Vector2(1, 0.3).normalized()) -> void:
	Base.draw_before(ci, id, r, pos, s, o, face)


static func draw_after(ci: CanvasItem, id: String, feet: Vector2, s: float, o := {}) -> void:
	var art = art_of(id)
	art.draw(ci, feet, art.HEIGHT * s, o)
	Ink.flash = 0.0
