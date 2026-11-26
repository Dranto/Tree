## Faune de Spore (tâche F) : la luciole des marais, la rainette, l'escargot. Petite vie du marais ravivé, à la
## palette de la région (mauve, ocre de lamelle, cyan-vert sève). Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

const FORMES := {
	"luciole": {"h": 37.0, "poses": {"vol": 4}},
	"rainette": {"h": 32.0, "poses": {"repos": 2, "saut": 2}},
	"escargot": {"h": 32.0, "poses": {"repos": 2, "marche": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"luciole":
			V.firefly(ci, xf, sin(o.get("walk", 0.0)), {"clair": Color("5a4a7a"), "ombre": Color("2e2444"), "reflet": Color("9a8ac0")}, Color("b8fff0"))
		"rainette":
			V.frog(ci, xf, o, {"clair": Color("c8b4f0"), "ombre": Color("7a5aa8"), "reflet": Color("f1e8ff")}, V.cream(), Color("7a5aa8"))
		"escargot": _escargot(ci, xf, o)


## Escargot : une coquille en spirale ocre et mauve, un pied luisant, deux cornes oculaires.
static func _escargot(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(o.get("t", 0.0))
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 30.0)
	var foot := V.tint(V.cream(), Color("d8c0f0"), 0.4)
	var pts := PackedVector2Array()
	var low := PackedVector2Array()
	for i in 14:
		var u := i / 13.0
		var wave := sin(walk - u * 5.0) * 1.2 * mv
		pts.append(Vector2(-34.0 + 76.0 * u, -(10.0 * sin(PI * pow(u, 0.6)) + 4.0 + 8.0 * smoothstep(0.75, 1.0, u)) - wave))
		low.append(Vector2(-34.0 + 76.0 * u, -1.5 + wave * 0.4))
	low.reverse()
	pts.append_array(low)
	V.part(ci, xf, pts, foot, 1.8, 1.0, 0.8)
	# Cornes oculaires.
	for k in [0, 1]:
		var base := Vector2(38 + 3 * k, -16)
		var tip := base + Vector2(5 + 2 * k, -15 + 1.5 * br)
		V.stroke(ci, xf, PackedVector2Array([base, base.lerp(tip, 0.5) + Vector2(-1, 0), tip]), 2.0, foot["ombre"])
		V.eye(ci, xf, tip + Vector2(0, -1), 2.6, 0.0)
	# Coquille en spirale.
	var shell := {"clair": Art.bc("spore", "detail"), "ombre": Color("8a5a2a"), "reflet": Color("f6dca0")}
	V.part(ci, xf, Ink.oval(Vector2(-6, -28 - 0.6 * br), 21.0, 20.0, 24), shell, 2.0, 1.0, 0.9)
	var sp := PackedVector2Array()
	for i in 26:
		var a := i * 0.5
		var r := 2.0 + i * 0.58
		sp.append(Vector2(-4.0 + cos(a) * r * 0.95, -27.0 + sin(a) * r * 0.95))
	V.stroke(ci, xf, sp, 1.5, Color("8a5a2a"), false)
	V.stroke(ci, xf, sp, 0.7, Color("e8c880"), false)
	V.sprout(ci, xf, Vector2(-14, -46), -1.6, 6.0, V.sap(), br, 0)
