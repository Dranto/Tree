## Distribution des planches des Flétris de Spore (R2) : sortes, rôles, nouveau dessin par son chemin.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")

const CAST := [
	{"id": "traine_vase", "nom": "Traîne-vase", "region": "spore", "role": "flaques", "r": 17.0},
	{"id": "scissipore", "nom": "Scissipore", "region": "spore", "role": "se divise", "r": 15.0},
	{"id": "sporule", "nom": "Sporule", "region": "spore", "role": "essaim", "r": 8.0},
	{"id": "lichen", "nom": "Lichen cuirassé", "region": "spore", "role": "lourd", "r": 21.0},
]


static func art_of(id: String):
	return load("res://scripts/creature_art/spore/%s.gd" % id)


## Réduction des colonnes étroites (silhouettes) pour les sortes plus longues que hautes.
static func fit(id: String) -> float:
	return 0.62 if id in ["traine_vase", "lichen"] else 1.0


static func draw_after(ci: CanvasItem, id: String, feet: Vector2, s: float, o := {}) -> void:
	var art = art_of(id)
	art.draw(ci, feet, art.HEIGHT * s, o)
	Ink.flash = 0.0
