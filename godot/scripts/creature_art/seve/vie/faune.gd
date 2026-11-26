## Faune de Sève (tâche F) : la grenouille verte, la libellule, le triton des sources. Petite vie de la vallée
## ravivée, vert de mare de la région, orange de ventre, vert sève. Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")
const G = preload("res://scripts/creature_art/seve/vie/gueri.gd")

const FORMES := {
	"grenouille": {"h": 37.0, "poses": {"repos": 2, "saut": 2}},
	"libellule": {"h": 41.0, "poses": {"vol": 4}},
	"triton": {"h": 30.0, "poses": {"repos": 2, "marche": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"grenouille": V.frog(ci, xf, o, V.pal("seve"), V.cream(), Color("2e6a3a"))
		"libellule": G._libellule(ci, xf, o)
		"triton": _triton(ci, xf, o)


## Triton crêté : dos brun-vert, ventre orange vif, longue queue aplatie, crête dentelée, quatre petites pattes.
static func _triton(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(o.get("t", 0.0))
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 32.0)
	var skin := V.tint(V.pal("seve", 0.5), Color("6a5a3a"), 0.4)
	var orange := {"clair": Color("f09a3a"), "ombre": Color("c0641a"), "reflet": Color("ffd08a")}
	for i in 2:
		var hx := -4.0 + i * 24.0
		var f := V.foot(Vector2(hx + 3.0, 0.0), walk, i * PI, 5.0, 4.0, mv)
		V.limb(ci, xf, Vector2(hx, -10), Vector2(hx + 4, -5), f, 3.0, skin["ombre"])
	var pts := PackedVector2Array()
	var low := PackedVector2Array()
	for i in 20:
		var u := i / 19.0
		var x := 40.0 - 80.0 * u
		var wave := sin(walk - u * 7.0) * 3.0 * mv * u
		var th := (9.0 if u < 0.4 else lerpf(9.0, 2.5, (u - 0.4) / 0.6)) + 0.5 * br * (1.0 - u)
		pts.append(Vector2(x, -10.0 - th * 0.55 + wave))
		low.append(Vector2(x, -10.0 + th * 0.55 + wave))
	low.reverse()
	pts.append_array(low)
	V.part(ci, xf, pts, skin, 1.8, 1.0, 0.8)
	V.blob(ci, xf, Vector2(2, -7), 24.0, 3.2, orange, 0.0, 0.0, 0.5)
	for q in [Vector2(-10, -17), Vector2(6, -17), Vector2(18, -16)]:
		V.blob(ci, xf, q, 2.2, 1.8, {"clair": Color("1f3a24"), "ombre": Color("0e2014"), "reflet": Color("3a6a44")}, 0.0, 0.0, 0.0)
	V.part(ci, xf, Ink.oval(Vector2(38, -12), 9.0, 7.5, 14), skin, 1.5, 1.0, 0.8)
	V.eye(ci, xf, Vector2(41, -15), 2.4, 0.0)
	V.sprout(ci, xf, Vector2(-8, -20), -1.6, 6.0, V.sap(), br, 0)
