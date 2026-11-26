## Faune d'Aube (tâche F) : la luciole dorée, le papillon nacré, la colombe. Petite vie des falaises ravivées, or
## et nacre de la région. Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

const FORMES := {
	"luciole": {"h": 37.0, "poses": {"vol": 4}},
	"papillon_nacre": {"h": 41.0, "poses": {"vol": 4}},
	"colombe": {"h": 44.0, "poses": {"repos": 2, "vol": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"luciole":
			V.firefly(ci, xf, sin(o.get("walk", 0.0)), V.pal("aube", 0.4), Color("ffe69a"))
		"papillon_nacre":
			Ink.ground_shadow(ci, xf, Vector2(0, 0), 12.0)
			V.butterfly(ci, xf, sin(o.get("walk", 0.0)), {"clair": Color("f8ece0"), "ombre": Color("d8b8a8"), "reflet": Color("fffaf4")}, {"clair": Color("e8d4e8"), "ombre": Color("b898c0"), "reflet": Color("ffffff")}, Art.bc("aube", "clair"))
		"colombe":
			V.bird(ci, xf, o, {"back": {"clair": Color("f4f0e8"), "ombre": Color("b8b0a0"), "reflet": Color.WHITE}, "belly": {"clair": Color("ffffff"), "ombre": Color("d8d0c0"), "reflet": Color.WHITE},
				"wing": {"clair": Color("e8e4dc"), "ombre": Color("a8a090"), "reflet": Color.WHITE}, "len": 15.0, "beak": Color("d8a850"), "legs": Color("d88878"), "mark": Color("fff6dc")})
