## Faune de Racine (tâche F) : le pic, l'écureuil, la luciole des sous-bois. Petite vie de la forêt ravivée, bruns
## de la région, crête rouge, vert sève. Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

const FORMES := {
	"pic": {"h": 41.0, "poses": {"repos": 2, "vol": 4}},
	"ecureuil": {"h": 41.0, "poses": {"repos": 2, "marche": 4}},
	"luciole": {"h": 37.0, "poses": {"vol": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"pic":
			V.bird(ci, xf, o, {"back": {"clair": Color("3a3a3e"), "ombre": Color("1a1a1e"), "reflet": Color("7a7a82")}, "belly": {"clair": Color("e8dcc4"), "ombre": Color("a8987a"), "reflet": Color.WHITE},
				"wing": {"clair": Color("46464c"), "ombre": Color("1e1e22"), "reflet": Color("fff6e0")}, "mark": Color("d9432e"), "len": 14.0, "beak": Color("6a6a70"), "beak_len": 7.0})
		"ecureuil": _ecureuil(ci, xf, o)
		"luciole":
			V.firefly(ci, xf, sin(o.get("walk", 0.0)), V.pal("racine", 0.6), Color("ffd890"))


## Écureuil roux : queue en panache dressée, joues claires, oreilles à pinceaux, une noisette entre les pattes.
static func _ecureuil(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 24.0)
	var fur := {"clair": Color("c4683a"), "ombre": Color("78341c"), "reflet": Color("eca070")}
	var far := V.tint(fur, Color.BLACK, 0.25)
	var bound := absf(sin(walk)) * 7.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, -bound)) * xf
	var ext := sin(walk) * mv
	# Queue en panache qui monte derrière le dos.
	var tail := PackedVector2Array()
	var tail_l := PackedVector2Array()
	for i in 14:
		var u := i / 13.0
		var c := Vector2(-18.0 - 12.0 * sin(u * 2.4) + 3.0 * ext, -22.0 - 56.0 * u)
		var w := 7.0 + 9.0 * sin(PI * minf(u * 1.15, 1.0)) + br * 0.6
		tail.append(c + Vector2(-w * 0.6, 0))
		tail_l.append(c + Vector2(w * 0.6 + 2.0, 0))
	tail_l.reverse()
	tail.append_array(tail_l)
	V.part(ci, x2, tail, far, 1.8, 1.0, 0.6)
	V.stroke(ci, x2, PackedVector2Array([Vector2(-22, -30), Vector2(-27, -50), Vector2(-24, -70)]), 1.0, fur["reflet"], false)
	V.limb(ci, xf, Vector2(-8, -16), Vector2(-16 - 6 * ext, -7), Vector2(-20 - 9 * ext, 0), 3.4, far["clair"])
	V.part(ci, x2, Ink.oval(Vector2(-2, -28), 14.0, 17.0 + 0.7 * br, 22, 0.2), fur, 2.0, 1.0, 0.8)
	V.part(ci, x2, Ink.oval(Vector2(6, -24), 8.0, 11.0, 16, 0.2), V.cream(), 0.0, 1.0, 0.3)
	# Tête ronde, oreilles à pinceaux, œil, museau, noisette.
	V.part(ci, x2, PackedVector2Array([Vector2(8, -46), Vector2(8, -58), Vector2(13, -49)]), far, 1.1, 1.0, 0.4)
	V.part(ci, x2, PackedVector2Array([Vector2(15, -46), Vector2(17, -58), Vector2(21, -47)]), fur, 1.1, 1.0, 0.5)
	V.part(ci, x2, Ink.oval(Vector2(15, -40), 10.0, 9.0, 16), fur, 1.7, 1.0, 0.8)
	V.part(ci, x2, Ink.oval(Vector2(21, -37), 6.0, 5.0, 12), V.cream(), 1.0, 1.0, 0.3)
	V.blob(ci, x2, Vector2(26, -39), 1.8, 1.6, {"clair": Color("3a2a2a"), "ombre": Color("1a1010"), "reflet": Color("7a6a6a")}, 0.0, 0.0, 0.0)
	V.eye(ci, x2, Vector2(19, -42), 2.6, 0.0)
	V.blob(ci, x2, Vector2(17, -25), 4.2, 3.6, {"clair": Color("c9a066"), "ombre": Color("7a5a30"), "reflet": Color("ecd29a")}, 1.0, 0.0, 0.6)
	V.limb(ci, x2, Vector2(10, -22), Vector2(16, -16), Vector2(18 + 3 * ext, -10), 3.0, fur["clair"])
	V.limb(ci, xf, Vector2(8, -14), Vector2(12 + 5 * ext, -6), Vector2(16 + 8 * ext, 0), 3.0, fur["clair"])
