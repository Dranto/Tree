## Faune de Ronce (tâche F) : la piéride, la fauvette, la coccinelle. Petite vie des roncières ravivées, à la
## palette de la région (rose de ronce, rouge de baie, vert sève). Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

const FORMES := {
	"pieride": {"h": 39.0, "poses": {"vol": 4}},
	"fauvette": {"h": 39.0, "poses": {"repos": 2, "vol": 4}},
	"coccinelle": {"h": 23.0, "poses": {"repos": 2, "marche": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"pieride":
			Ink.ground_shadow(ci, xf, Vector2(0, 0), 12.0)
			V.butterfly(ci, xf, sin(o.get("walk", 0.0)), {"clair": Color("fff2f4"), "ombre": Color("e8b0be"), "reflet": Color.WHITE}, {"clair": Color("f6dce2"), "ombre": Color("c890a0"), "reflet": Color.WHITE}, Color("3a2a2a"))
		"fauvette":
			V.bird(ci, xf, o, {"back": {"clair": Color("a08060"), "ombre": Color("5a4636"), "reflet": Color("d8bc98")}, "belly": {"clair": Color("f1e6d0"), "ombre": Color("b8a888"), "reflet": Color.WHITE},
				"mark": Art.bc("ronce", "clair").lerp(Color("e8742a"), 0.45), "len": 12.0, "beak": Color("5a4a3a")})
		"coccinelle": _coccinelle(ci, xf, o)


## Coccinelle : un dôme de la rouge de la région, sept points, une petite tête, six pattes.
static func _coccinelle(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(o.get("t", 0.0))
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 26.0)
	var red := V.pal("ronce")
	for i in 3:
		var hx := -14.0 + i * 14.0
		var f := V.foot(Vector2(hx + 3.0, 0.0), walk, i * 2.1, 6.0, 6.0, mv)
		V.limb(ci, xf, Vector2(hx, -14), Vector2(hx + 6, -7), f, 2.8, Color("2a1a1a"))
	var dome := Ink.oval(Vector2(-4, -22), 30.0, 22.0 + 1.0 * br, 26)
	for i in dome.size():
		dome[i].y = minf(dome[i].y, -8.0)
	V.part(ci, xf, dome, red, 2.2, 1.0, 1.0)
	V.stroke(ci, xf, PackedVector2Array([Vector2(-4, -43), Vector2(-4, -24), Vector2(-4, -8)]), 1.4, Color("1a1010"), false)
	for q in [Vector2(-18, -22), Vector2(10, -22), Vector2(-14, -34), Vector2(6, -36), Vector2(-2, -14)]:
		V.blob(ci, xf, q, 4.4, 4.0, {"clair": Color("2a1a1e"), "ombre": Color("120a0c"), "reflet": Color("5a4a50")}, 0.0, 0.0, 0.4)
	V.part(ci, xf, Ink.oval(Vector2(28, -17), 9.0, 8.0, 14), {"clair": Color("2a1a1e"), "ombre": Color("120a0c"), "reflet": Color("6a5a60")}, 1.3, 1.0, 0.4)
	V.blob(ci, xf, Vector2(31, -19), 3.0, 3.6, V.cream(), 0.0, 0.0, 0.0)
	V.sprout(ci, xf, Vector2(-14, -40), -1.6, 7.0, V.sap(), br, 0)
