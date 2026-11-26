## Formes guéries des Flétris d'Aube (tâche F) : la luciole à la lanterne claire, la mante de verre, le
## faucheux de cristal, la tortue-géode. Or de l'aube de la région, verre clair, lumière blanche, vert sève ;
## jamais de braise ni de fêlure. La luciole a la pose « vol ». Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

const FORMES := {
	"luciole": {"h": 46.0, "v": 54.0, "poses": {"vol": 4}},
	"miroitier": {"h": 55.0, "v": 24.0, "poses": {"repos": 2, "marche": 4}},
	"prismeur": {"h": 60.0, "v": 22.0, "poses": {"repos": 2, "marche": 4}},
	"quartz": {"h": 58.0, "v": 14.0, "poses": {"repos": 2, "marche": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"luciole": _luciole(ci, xf, o)
		"miroitier": _mante(ci, xf, o)
		"prismeur": _faucheux(ci, xf, o)
		"quartz": _tortue(ci, xf, o)


static func _glass() -> Dictionary:
	return {"clair": Art.bc("aube", "verre"), "ombre": Art.bc("aube", "verre_ombre"), "reflet": Color.WHITE}


static func _gold() -> Dictionary:
	return V.pal("aube")


## Luciole : thorax doré, lanterne claire et chaude à l'abdomen, deux paires d'ailes de verre qui battent.
static func _luciole(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var flap := sin(walk)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 12.0)
	var c := Vector2(0, -50)
	var gl := _glass()
	var up := 0.4 + 0.6 * (flap * 0.5 + 0.5)
	for k in [0, 1]:
		var base := c + Vector2(-1 + k * 5.0, -3)
		var tip := base + Vector2(-9 + k * 3.0, -24 * up)
		V.part(ci, xf, PackedVector2Array([base, base + Vector2(-5, -9 * up), tip, tip + Vector2(10, 3), base + Vector2(6, -5 * up)]), V.tint(gl, Color("b8dcd8"), 0.3), 0.9, 1.0, 0.6)
	# Lanterne : abdomen allumé d'une lumière claire, halo doux.
	var lamp := c + Vector2(-13, 8)
	Ink.halo(ci, xf * lamp, 20.0 * xf.get_scale().x, Color("fff3b0"), 1.2)
	V.part(ci, xf, Ink.oval(c + Vector2(-8, 4), 12.0, 7.0, 16, 0.5), V.tint(_gold(), Color("a06a2a"), 0.2), 1.4, 1.0, 0.6)
	V.part(ci, xf, Ink.oval(lamp, 7.5, 6.0, 14, 0.4), {"clair": Color("fff6c0"), "ombre": Color("f0c860"), "reflet": Color.WHITE}, 1.2, 1.0, 1.0)
	V.part(ci, xf, Ink.oval(c + Vector2(3, -1), 8.0, 6.5, 14), _gold(), 1.5, 1.0, 0.9)
	V.part(ci, xf, Ink.oval(c + Vector2(11, -2), 5.5, 5.0, 12), V.tint(_gold(), Color("3a2a1a"), 0.35), 1.3, 1.0, 0.5)
	V.eye(ci, xf, c + Vector2(13, -3.2), 2.6, 0.0)
	for k in [0, 1]:
		var base := c + Vector2(4 + k * 5.0, -4)
		var tip := base + Vector2(8 + k * 4.0, -22 * up)
		V.part(ci, xf, PackedVector2Array([base, base + Vector2(6, -8 * up), tip, tip + Vector2(-10, 2), base + Vector2(-5, -4 * up)]), gl, 0.9, 1.0, 0.7)
	V.stroke(ci, xf, PackedVector2Array([c + Vector2(14, -6), c + Vector2(19, -13), c + Vector2(23, -13)]), 0.9, Color("6a4a3a"))


## Mante de verre : un corps vert clair translucide à reflets d'or, pattes ravisseuses repliées, ailes jointes.
static func _mante(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 20.0)
	var body := V.tint(_glass(), Color("a8e0a0"), 0.55)
	body["reflet"] = Color("f0fff0")
	var rise := absf(sin(walk)) * 2.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, -rise)) * xf
	# Quatre pattes de marche.
	for i in 4:
		var hx := -14.0 + i * 8.0
		var f := V.foot(Vector2(hx + (6.0 if i % 2 == 0 else -2.0), 0.0), walk, i * PI * 0.5, 6.0, 5.0, mv)
		V.limb(ci, xf, Vector2(hx, -26), Vector2(hx + 6, -14), f, 2.0, body["ombre"])
	# Abdomen long sous les ailes, thorax penché vers l'avant, tête triangulaire.
	V.part(ci, x2, Ink.oval(Vector2(-14, -30), 21.0, 7.5 + 0.5 * br, 20, 0.28), body, 1.6, 1.0, 0.9)
	V.part(ci, x2, PackedVector2Array([Vector2(-32, -30), Vector2(-4, -44), Vector2(8, -42), Vector2(-6, -34), Vector2(-26, -26)]), _glass(), 1.0, 1.0, 0.8)
	V.part(ci, x2, PackedVector2Array([Vector2(-2, -30), Vector2(10, -56), Vector2(17, -54), Vector2(10, -28)]), body, 1.6, 1.0, 0.8)
	V.part(ci, x2, PackedVector2Array([Vector2(10, -56), Vector2(24, -60), Vector2(26, -64), Vector2(14, -66)]), body, 1.5, 1.0, 0.8)
	V.eye(ci, x2, Vector2(21.0, -62), 3.0, 0.0)
	V.eye(ci, x2, Vector2(15.0, -62), 2.4, 0.0)
	# Pattes ravisseuses repliées devant la poitrine.
	var arm := PackedVector2Array([Vector2(14, -50), Vector2(28, -50 + br), Vector2(31, -36), Vector2(22, -32)])
	V.stroke(ci, x2, arm, 3.2, _gold()["clair"])
	V.stroke(ci, x2, PackedVector2Array([Vector2(22, -33), Vector2(19, -40)]), 1.6, _gold()["reflet"], false)
	V.stroke(ci, x2, PackedVector2Array([Vector2(16, -66), Vector2(11, -76), Vector2(6, -80 + br)]), 0.9, body["ombre"])
	V.stroke(ci, x2, PackedVector2Array([Vector2(21, -66), Vector2(26, -75), Vector2(30, -78 + br)]), 0.9, body["ombre"])
	V.sprout(ci, x2, Vector2(-24, -34), -1.5, 7.0, V.sap(), br, 1)


## Faucheux de cristal : un corps en prisme clair dressé sur quatre pattes très longues, un cristal doré au sommet.
static func _faucheux(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 26.0)
	var gl := _glass()
	var body := Vector2(0, -52)
	var up := -absf(sin(walk)) * 3.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	# Quatre pattes : hanche près du corps, genou très haut, pied au sol.
	for i in 4:
		var side := -1.0 if i < 2 else 1.0
		var hip := body + Vector2(side * 4.0 + (i % 2) * 2.0, 6.0 + up)
		var knee := hip + Vector2(side * (22.0 + 6.0 * (i % 2)), -14.0 + 2.0 * br)
		var f := V.foot(Vector2(side * (30.0 + 6.0 * (i % 2)) + 4.0, 0.0), walk, i * PI * 0.5, 6.0, 8.0, mv)
		V.limb(ci, xf, hip, knee, f, 1.9, _gold()["ombre"] if i % 2 == 0 else _gold()["clair"])
	# Corps prisme : trois facettes de verre clair, cristal doré en haut.
	V.part(ci, x2, PackedVector2Array([body + Vector2(-9, 10), body + Vector2(-7, -10), body + Vector2(0, -16), body + Vector2(8, -10), body + Vector2(10, 10), body + Vector2(0, 14)]), gl, 1.8, 1.0, 1.0)
	V.flat(ci, x2, PackedVector2Array([body + Vector2(0, -16), body + Vector2(8, -10), body + Vector2(10, 10), body + Vector2(1, 12)]), Color(gl["ombre"], 0.5), 0.0)
	V.stroke(ci, x2, PackedVector2Array([body + Vector2(0, -15), body + Vector2(1, 12)]), 0.8, Color.WHITE, false)
	V.part(ci, x2, PackedVector2Array([body + Vector2(-5, -15), body + Vector2(-2, -31), body + Vector2(2, -37 - br), body + Vector2(6, -31), body + Vector2(5, -15)]), _gold(), 1.5, 1.0, 1.0)
	V.eye(ci, x2, body + Vector2(5.0, 2.0), 2.8, 0.0)
	V.eye(ci, x2, body + Vector2(-1.0, 3.0), 2.3, 0.0)
	V.sprout(ci, x2, body + Vector2(-4, 12), -2.2, 8.0, V.sap(), br, 1)


## Tortue-géode : carapace de roche dont la fente s'ouvre sur des aiguilles de quartz clair qui prennent la lumière.
static func _tortue(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 36.0)
	var skin := V.tint(V.pal("aube", 0.35), Color("a8b078"), 0.35)
	var shell := V.tint(V.stone(), Art.bc("aube", "clair"), 0.4)
	var rise := absf(sin(walk)) * 1.5 * mv
	var x2 := Transform2D(0.0, Vector2(0, -rise)) * xf
	# Pattes-piliers.
	for i in 4:
		var hx := -22.0 + i * 15.0
		var f := V.foot(Vector2(hx, 0.0), walk, i * PI * 0.5 + (0 if i % 2 == 0 else PI), 5.0, 4.0, mv)
		V.part(ci, xf, Ink.oval(Vector2(f.x, f.y - 6.0), 6.4, 7.0, 12), V.pal("aube", 0.5 if i < 2 else 0.0), 1.4, 1.0, 0.4)
	# Tête et cou tendus vers l'avant.
	V.part(ci, x2, Ink.oval(Vector2(34, -22 - br), 9.0, 8.0, 16), skin, 1.5, 1.0, 0.8)
	V.eye(ci, x2, Vector2(37, -24 - br), 2.8, 0.0)
	V.part(ci, x2, Ink.oval(Vector2(26, -20), 7.0, 5.0, 12), skin, 1.2, 1.0, 0.4)
	# Dôme de la carapace, plaques, puis géode ouverte sur le dessus.
	var dome := Ink.oval(Vector2(0, -26), 30.0, 22.0 + 0.8 * br, 30)
	for i in dome.size():
		dome[i].y = minf(dome[i].y, -10.0)
	V.part(ci, x2, dome, shell, 2.2, 1.0, 0.7)
	V.stroke(ci, x2, PackedVector2Array([Vector2(-18, -14), Vector2(-14, -30), Vector2(-8, -44)]), 1.1, shell["ombre"], false)
	V.stroke(ci, x2, PackedVector2Array([Vector2(16, -14), Vector2(18, -28), Vector2(14, -40)]), 1.1, shell["ombre"], false)
	V.part(ci, x2, Ink.oval(Vector2(-2, -40), 15.0, 6.0, 20), {"clair": Color("5a4a6a"), "ombre": Color("32283e"), "reflet": Color("8a7aa0")}, 1.2, 1.0, 0.3)
	for i in 6:
		var a := -PI * 0.5 - 0.9 + i * 0.36
		var l := 15.0 + 6.0 * sin(i * 1.7 + 0.5)
		V.part(ci, x2, PackedVector2Array([Vector2(-2, -40) + Vector2.from_angle(a + 1.57) * 2.4, Vector2(-2, -40) + Vector2.from_angle(a) * l, Vector2(-2, -40) + Vector2.from_angle(a - 1.57) * 2.4]), {"clair": Color("e2f6fa"), "ombre": Color("86b4c4"), "reflet": Color.WHITE}, 0.9, 1.0, 1.0)
	V.sprout(ci, x2, Vector2(-24, -34), -1.9, 8.0, V.sap(), br, 1)
