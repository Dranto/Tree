## Faune de Vent (tâche F) : l'alouette, le martinet, le lièvre des plateaux. Petite vie des steppes ravivées,
## plumes sable et ciel de la région. Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

const FORMES := {
	"alouette": {"h": 39.0, "poses": {"repos": 2, "vol": 4}},
	"martinet": {"h": 41.0, "poses": {"vol": 4}},
	"lievre": {"h": 46.0, "poses": {"repos": 2, "marche": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"alouette":
			V.bird(ci, xf, o, {"back": {"clair": Color("b09a6a"), "ombre": Color("65563a"), "reflet": Color("e0cfa0")}, "belly": {"clair": Color("f0e8d4"), "ombre": Color("b8ac90"), "reflet": Color.WHITE},
				"wing": {"clair": Color("a89060"), "ombre": Color("5a4a30"), "reflet": Color("d8c898")}, "crest": true, "len": 13.0, "mark": Color("d8c8a0"), "beak": Color("8a7a5a")})
		"martinet": _martinet(ci, xf, o)
		"lievre": _lievre(ci, xf, o)


## Martinet : un croissant sombre aux longues ailes en faux, queue fourchue, gorge claire ; il ne se pose jamais.
static func _martinet(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var flap := sin(o.get("walk", 0.0))
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 12.0)
	var c := Vector2(0, -50)
	var pl := {"clair": Art.bc("vent", "plume").darkened(0.15), "ombre": Art.bc("vent", "plume").darkened(0.5), "reflet": Art.bc("vent", "aile")}
	V.part(ci, xf, Ink.leaf(c + Vector2(2, -1), PI + flap * 1.0 + 0.3, 36.0, 8.0, 0.12), V.tint(pl, Color.BLACK, 0.2), 1.1, 1.0, 0.3)
	V.part(ci, xf, PackedVector2Array([c + Vector2(-12, 1), c + Vector2(-27, -3), c + Vector2(-23, 3), c + Vector2(-28, 8), c + Vector2(-11, 4)]), pl, 1.1, 1.0, 0.3)
	V.part(ci, xf, Ink.oval(c, 14.0, 5.5, 18, -0.05), pl, 1.6, 1.0, 0.7)
	V.blob(ci, xf, c + Vector2(10, 2), 4.5, 2.6, V.cream(), 0.0, 0.0, 0.3)
	V.part(ci, xf, Ink.oval(c + Vector2(13, -1), 5.0, 4.6, 12), pl, 1.2, 1.0, 0.6)
	V.eye(ci, xf, c + Vector2(15, -2), 1.6, 0.0)
	V.part(ci, xf, Ink.leaf(c + Vector2(0, -1), PI + flap * 1.0 - 0.15, 38.0, 8.5, 0.12), pl, 1.3, 1.0, 0.7)


## Lièvre des plateaux : pelage sable, grandes oreilles à pointe sombre, cuisses puissantes, queue claire ; il bondit en courant.
static func _lievre(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 26.0)
	var fur := {"clair": Color("c9a272"), "ombre": Color("7a5a38"), "reflet": Color("ecd0a0")}
	var far := V.tint(fur, Color.BLACK, 0.25)
	var bound := absf(sin(walk)) * 8.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, -bound)) * xf
	var ext := sin(walk) * mv
	V.limb(ci, xf, Vector2(-14, -16), Vector2(-20 - 8 * ext, -6), Vector2(-24 - 12 * ext, 0), 3.8, far["clair"])
	V.limb(ci, xf, Vector2(14, -16), Vector2(22 + 6 * ext, -6), Vector2(26 + 10 * ext, 0), 3.0, far["clair"])
	V.blob(ci, x2, Vector2(-26, -26), 6.0, 6.0, V.cream(), 1.2, 0.0, 0.4)
	V.part(ci, x2, Ink.oval(Vector2(-4, -26), 26.0, 14.0 + 0.8 * br, 24, -0.12), fur, 2.0, 1.0, 0.8)
	V.part(ci, x2, Ink.oval(Vector2(-16, -22), 13.0, 11.0, 18), fur, 1.4, 1.0, 0.5)
	V.part(ci, x2, Ink.oval(Vector2(1, -17), 15.0, 6.0, 14), V.cream(), 0.0, 1.0, 0.3)
	# Tête, oreilles à pointe sombre, œil.
	V.part(ci, x2, PackedVector2Array([Vector2(18, -38), Vector2(8, -66 + 2 * br), Vector2(14, -67 + 2 * br), Vector2(24, -42)]), far, 1.3, 1.0, 0.5)
	V.part(ci, x2, PackedVector2Array([Vector2(22, -38), Vector2(18, -64 + 2 * br), Vector2(24, -64 + 2 * br), Vector2(30, -38)]), fur, 1.3, 1.0, 0.7)
	V.flat(ci, x2, PackedVector2Array([Vector2(18, -64 + 2 * br), Vector2(24, -64 + 2 * br), Vector2(23, -58), Vector2(19, -58)]), Color("3a2a1a"), 0.0)
	V.part(ci, x2, Ink.oval(Vector2(26, -33), 11.0, 8.0, 16, 0.15), fur, 1.6, 1.0, 0.8)
	V.part(ci, x2, Ink.oval(Vector2(35, -31), 5.0, 4.0, 10), V.cream(), 1.0, 1.0, 0.3)
	V.blob(ci, x2, Vector2(39, -32), 1.7, 1.5, {"clair": Color("5a3a3a"), "ombre": Color("2a1a1a"), "reflet": Color("8a6a6a")}, 0.0, 0.0, 0.0)
	V.eye(ci, x2, Vector2(29, -36), 2.6, 0.0)
	V.limb(ci, x2, Vector2(18, -18), Vector2(24, -10), Vector2(30 + 2 * ext, 0), 3.0, fur["clair"])
