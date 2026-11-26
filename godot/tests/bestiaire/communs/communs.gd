## Outils des planches des Flétris communs (refonte des personnages, R0) : la liste des sortes et leur
## nouveau dessin (scripts/creature_art/commun/<id>.gd).
extends RefCounted

const C = preload("res://tests/bestiaire/commun.gd")

## [id, nom, rôle, rayon de collision (enemies.json)]
const CAST := [
	["fletri", "Flétri", "mêlée", 14.0],
	["cendreux", "Cendreux", "petit, rapide", 10.0],
	["cracheur", "Cracheur de cendre", "tireur", 12.0],
	["gardien", "Gardien d'écorce", "soutien", 19.0],
	["boursoufle", "Boursouflé", "poche (éclate)", 17.0],
	["colosse", "Colosse", "lourd", 25.0],
]


static func art(id: String):
	return load("res://scripts/creature_art/commun/%s.gd" % id)


## Nouveau dessin, pieds en feet, à l'échelle s (1 : px du jeu en 1600×900).
static func draw_after(ci: CanvasItem, id: String, feet: Vector2, s: float, o := {}) -> void:
	if id == "heros":
		C.draw_after(ci, "heros", feet, s, o)
		return
	var a = art(id)
	a.draw(ci, feet, a.HEIGHT * s, o)
	C.Ink.flash = 0.0
