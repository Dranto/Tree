## Formes guéries des Flétris communs (tâche F) : ce que la Flétrissure avait pris. Un jeune arbre qui marche
## sur ses racines, une crosse de fougère, une vieille souche moussue, un crapaud, un bouleau, un bolet.
## Corps de bois vivant et de feuilles, vert sève ; jamais de braise ni de cendre. Trois quarts, encre fine.
## Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

## h : px du jeu pour 100 unités ; v : vitesse de marche (px/s).
const FORMES := {
	"fletri": {"h": 48.0, "v": 34.0, "poses": {"repos": 2, "marche": 4}},
	"cendreux": {"h": 54.0, "v": 52.0, "poses": {"repos": 2, "marche": 4}},
	"colosse": {"h": 62.0, "v": 20.0, "poses": {"repos": 2, "marche": 4}},
	"cracheur": {"h": 55.0, "v": 26.0, "poses": {"repos": 2, "marche": 4}},
	"gardien": {"h": 60.0, "v": 24.0, "poses": {"repos": 2, "marche": 4}},
	"boursoufle": {"h": 43.0, "v": 32.0, "poses": {"repos": 2, "marche": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"fletri": _fletri(ci, xf, o)
		"cendreux": _cendreux(ci, xf, o)
		"colosse": _colosse(ci, xf, o)
		"cracheur": _cracheur(ci, xf, o)
		"gardien": _gardien(ci, xf, o)
		"boursoufle": _boursoufle(ci, xf, o)


static func _legs(ci: CanvasItem, xf: Transform2D, hips: Array, walk: float, mv: float, stride: float, lift: float, w: float, col: Color, ph0 := 0.0) -> void:
	for i in hips.size():
		var hp: Vector2 = hips[i]
		var f := V.foot(Vector2(hp.x + 2.0, 0.0), walk, ph0 + i * PI, stride, lift, mv)
		V.limb(ci, xf, hp, Vector2(hp.x + (f.x - hp.x) * 0.5 + 3.0, hp.y * 0.5), f, w, col)


## Jeune chêne : un tronc vif, deux racines-jambes, des feuilles à la place des flammes.
static func _fletri(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	var sw := sin(walk) * mv + 0.4 * br
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 20.0)
	var wd := V.wood()
	var far := V.wood(1.0)
	var up := -absf(sin(walk)) * 3.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	_legs(ci, xf, [Vector2(-5, -24 + up), Vector2(8, -24 + up)], walk, mv, 8.0, 5.0, 4.5, wd["ombre"])
	# Branche-bras du fond, puis tronc, puis bras de devant.
	V.limb(ci, x2, Vector2(-8, -48), Vector2(-20, -54 - 3 * sw), Vector2(-24, -64 - 4 * sw), 3.2, far["clair"])
	V.part(ci, x2, Ink.lumpy(Vector2(0, -42), 14.0, 22.0 + 0.8 * br, 26, 0.05, 7.0), wd, 2.0, 1.0, 0.8)
	# Cernes, nœud-œil et visage de jeune arbre : deux yeux clairs, regard devant.
	V.stroke(ci, x2, PackedVector2Array([Vector2(-5, -30), Vector2(-3, -40), Vector2(-5, -50)]), 1.0, wd["ombre"], false)
	V.eye(ci, x2, Vector2(5.5, -49), 3.6, 0.0)
	V.eye(ci, x2, Vector2(12.0, -47), 3.0, 0.0)
	V.stroke(ci, x2, PackedVector2Array([Vector2(7, -41), Vector2(10, -39.5), Vector2(13, -41)]), 1.1, wd["ombre"], false)
	V.limb(ci, x2, Vector2(10, -42), Vector2(21, -38 + 3 * sw), Vector2(25, -48 + 5 * sw), 3.4, wd["clair"])
	V.sprout(ci, x2, Vector2(25, -48 + 5 * sw), -1.0, 9.0, V.sap(), sw, 2)
	# Houppier.
	V.crown(ci, x2, Vector2(1, -62), 26.0, V.leafy(0.5), 6, sw, -PI * 0.5, PI * 1.15)
	V.crown(ci, x2, Vector2(1, -63), 22.0, V.leafy(), 7, sw, -PI * 0.5, PI * 1.0)
	V.sprout(ci, x2, Vector2(-1, -74), -1.7, 12.0, V.sap(), -sw, 2)


## Crosse de fougère : la spirale d'une jeune fronde, deux pattes de brindille, un œil au cœur de la crosse.
static func _cendreux(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 14.0)
	var lf := V.leafy()
	var up := -absf(sin(walk)) * 4.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	_legs(ci, xf, [Vector2(-3, -24 + up), Vector2(5, -24 + up)], walk, mv, 8.0, 6.0, 2.6, V.wood()["clair"])
	# Tige qui monte et s'enroule vers l'avant.
	var stem := PackedVector2Array()
	var p := Vector2(-3, -22)
	var a := -PI * 0.5 + 0.35
	for i in 20:
		var u := i / 19.0
		stem.append(p)
		a += (0.02 + 0.30 * u * u * u) * (1.0 + 0.05 * br) - 0.01
		p += Vector2.from_angle(a) * (3.4 - 1.5 * u)
	V.stroke(ci, x2, stem, 6.6, lf["ombre"])
	V.stroke(ci, x2, stem, 4.4, lf["clair"], false)
	# Pennes (petites folioles) le long de la tige.
	for i in 5:
		var u := 0.12 + 0.13 * i
		var q: Vector2 = stem[int(u * 19)]
		var d := (stem[mini(int(u * 19) + 1, 19)] - q).normalized()
		for side in [-1.0, 1.0]:
			V.part(ci, x2, Ink.leaf(q, d.angle() + side * 1.25, 9.0 - 1.2 * i, 4.4, side * 0.1), lf, 1.0, 1.0, 0.6)
	var c: Vector2 = stem[19]
	V.eye(ci, x2, c + Vector2(1.0, 3.0), 3.4, 0.0)
	V.sprout(ci, x2, stem[13], -2.5, 7.0, V.sap(), br, 1)


## Vieille souche moussue : un trône de bois, un tapis de mousse, un jeune plant sur le dessus, deux bras de racines.
static func _colosse(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 34.0)
	var wd := V.wood()
	var sap := V.sap()
	var mos := V.leafy()
	var up := -absf(sin(walk)) * 2.5 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	_legs(ci, xf, [Vector2(-14, -16 + up), Vector2(14, -16 + up)], walk, mv, 6.0, 4.0, 8.0, V.wood(1.0)["ombre"])
	# Bras du fond.
	V.limb(ci, x2, Vector2(-26, -42), Vector2(-40, -26 + 4 * br), Vector2(-38, -8), 8.0, V.wood(1.0)["clair"])
	V.part(ci, x2, Ink.lumpy(Vector2(-37, -9), 8.0, 7.0, 14, 0.12, 5.0), V.wood(0.6), 1.6, 1.0, 0.5)
	# Tronc large, haut tronqué.
	var body := PackedVector2Array([Vector2(-30, -14), Vector2(-33, -44), Vector2(-24, -68), Vector2(0, -74 - 1.0 * br), Vector2(24, -68), Vector2(33, -44), Vector2(30, -14), Vector2(0, -10)])
	V.part(ci, x2, body, wd, 2.2, 1.0, 0.7)
	# Fibres du bois, lignes de l'écorce.
	for i in 4:
		var x := -20.0 + i * 13.0
		V.stroke(ci, x2, PackedVector2Array([Vector2(x, -18), Vector2(x + 2, -40), Vector2(x - 1, -62)]), 1.1, wd["ombre"], false)
	# Tapis de mousse sur le dessus et sur l'épaule, plant de chêne et petite fleur.
	V.part(ci, x2, Ink.lumpy(Vector2(-2, -72), 28.0, 9.0, 24, 0.12, 6.0), mos, 1.8, 1.0, 0.8)
	V.part(ci, x2, Ink.lumpy(Vector2(-24, -50), 9.0, 12.0, 14, 0.15, 5.0), mos, 1.4, 1.0, 0.6)
	V.sprout(ci, x2, Vector2(2, -78), -1.45, 22.0, sap, 0.5 * br + sin(walk) * mv * 0.5, 4)
	V.flower(ci, x2, Vector2(-14, -80), 4.4, Color("fff0e6"))
	# Visage : deux yeux de lueur douce dans un creux de l'écorce.
	V.blob(ci, x2, Vector2(14, -46), 11.0, 9.0, {"clair": wd["ombre"], "ombre": Color("2e1c14"), "reflet": wd["ombre"]}, 0.0, 0.0, 0.0)
	V.eye(ci, x2, Vector2(10.5, -47), 3.6, 0.0)
	V.eye(ci, x2, Vector2(19.0, -46), 3.0, 0.0)
	# Bras de devant.
	V.limb(ci, x2, Vector2(26, -42), Vector2(40, -28 - 4 * br), Vector2(41, -9), 8.5, wd["clair"])
	V.part(ci, x2, Ink.lumpy(Vector2(41, -9), 8.5, 7.5, 14, 0.12, 5.0), wd, 1.8, 1.0, 0.6)
	V.sprout(ci, x2, Vector2(45, -14), -0.9, 9.0, sap, br, 1)


## Crapaud : brun-olive, verruqueux, la gorge crème qui respire, des yeux dorés au sommet de la tête.
static func _cracheur(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 26.0)
	var skin := V.tint(V.wood(), Color("8aa05a"), 0.55)
	var far := V.tint(V.wood(1.0), Color("8aa05a"), 0.4)
	var hop := absf(sin(walk)) * 7.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, -hop)) * xf
	# Pattes du fond, puis cuisses repliées.
	V.limb(ci, xf, Vector2(18, -10), Vector2(26 + 4 * sin(walk) * mv, -4), Vector2(29 + 5 * sin(walk) * mv, 0), 5.0, far["clair"])
	V.part(ci, x2, Ink.oval(Vector2(-13, -12), 14.0, 10.0, 18, -0.2), far, 1.6, 1.0, 0.5)
	# Corps bossu, tête large et plate d'un seul tenant.
	var back := Ink.lumpy(Vector2(-4, -26), 28.0, 20.0 + 1.2 * br, 34, 0.04, 9.0)
	var head := Ink.oval(Vector2(18, -22), 15.0, 11.0, 24, -0.1)
	var sh := Geometry2D.merge_polygons(back, head)
	var body: PackedVector2Array = sh[0] if not sh.is_empty() else back
	for i in body.size():
		body[i].y = minf(body[i].y, -5.0)
	V.part(ci, x2, body, skin, 2.2, 1.0, 0.7)
	# Ventre et gorge crème.
	V.blob(ci, x2, Vector2(14, -10), 15.0, 5.0 + 1.0 * br, V.cream(), 0.0, 0.0, 0.3)
	# Verrues.
	for q in [Vector2(-18, -36), Vector2(-8, -41), Vector2(2, -37), Vector2(-14, -27), Vector2(-1, -29)]:
		V.blob(ci, x2, q, 2.6, 2.0, V.tint(skin, Color("d9c27a"), 0.3), 0.9, 0.0, 0.4)
	# Yeux dorés saillants, bouche en trait.
	for xx in [15.0, 25.0]:
		V.blob(ci, x2, Vector2(xx, -33), 5.0, 4.4, skin, 1.4, 0.0, 0.3)
		V.eye(ci, x2, Vector2(xx + 0.5, -33.5), 3.4, 0.0)
	V.stroke(ci, x2, PackedVector2Array([Vector2(12, -17), Vector2(24, -15.5), Vector2(32, -19)]), 1.1, skin["ombre"], false)
	# Patte de devant, feuille de printemps sur le dos.
	V.limb(ci, x2, Vector2(18, -10), Vector2(24, -4), Vector2(28 + 3 * sin(walk + PI) * mv, 0), 4.2, skin["clair"])
	V.sprout(ci, x2, Vector2(-6, -44), -1.3, 12.0, V.sap(), br, 2)


## Vieux bouleau : un tronc clair rayé de noir, des racines pour marcher, un houppier léger qui bruisse.
static func _gardien(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	var sw := sin(walk) * mv + 0.4 * br
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 22.0)
	var bark := {"clair": Color("e9e2d2"), "ombre": Color("a59d8a"), "reflet": Color("fffaf0")}
	var up := -absf(sin(walk)) * 2.5 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	_legs(ci, xf, [Vector2(-5, -22 + up), Vector2(7, -22 + up)], walk, mv, 7.0, 4.0, 4.4, V.wood()["ombre"])
	V.limb(ci, x2, Vector2(-5, -58), Vector2(-17, -64 - 3 * sw), Vector2(-24, -78 - 4 * sw), 2.8, bark["ombre"])
	V.part(ci, x2, PackedVector2Array([Vector2(-10, -20), Vector2(-9, -50), Vector2(-6, -76), Vector2(6, -76), Vector2(10, -50), Vector2(10, -20), Vector2(0, -16)]), bark, 2.0, 1.0, 0.8)
	# Marques noires du bouleau.
	for i in 5:
		var y := -28.0 - i * 10.0
		V.stroke(ci, x2, PackedVector2Array([Vector2(-7 + (i % 2) * 2, y), Vector2(-1 + (i % 3) * 2, y - 1.5), Vector2(5, y + 0.5)]), 1.6, Color("3b332d"), false)
	V.eye(ci, x2, Vector2(2.5, -60), 3.3, 0.0)
	V.eye(ci, x2, Vector2(8.5, -59), 2.8, 0.0)
	V.limb(ci, x2, Vector2(8, -46), Vector2(17, -44 + 2 * sw), Vector2(21, -54 + 4 * sw), 3.0, bark["ombre"])
	V.sprout(ci, x2, Vector2(21, -54 + 4 * sw), -1.1, 8.0, V.sap(), sw, 2)
	V.crown(ci, x2, Vector2(0, -76), 26.0, V.leafy(0.5), 6, sw, -PI * 0.5, PI * 1.15)
	V.crown(ci, x2, Vector2(0, -77), 22.0, {"clair": Color("a6cf5a"), "ombre": Color("5f8a2e"), "reflet": Color("e0f2a0")}, 7, sw, -PI * 0.5, PI * 1.0)


## Bolet : un chapeau châtain à pois crème sur un pied épais, de petites pattes de racine, deux yeux curieux.
static func _boursoufle(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 24.0)
	var cap := {"clair": Color("cf7d44"), "ombre": Color("8a4a26"), "reflet": Color("f3b98a")}
	var stalk := V.cream()
	var hop := absf(sin(walk)) * 4.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, -hop)) * xf
	_legs(ci, xf, [Vector2(-8, -12 - hop), Vector2(7, -12 - hop)], walk, mv, 6.0, 5.0, 3.6, V.wood()["clair"])
	V.part(ci, x2, PackedVector2Array([Vector2(-11, -12), Vector2(-9, -34), Vector2(9, -34), Vector2(11, -12), Vector2(0, -8)]), stalk, 1.8, 1.0, 0.6)
	# Lamelles sous le chapeau.
	V.flat(ci, x2, Ink.oval(Vector2(1, -40), 30.0, 5.5, 22), V.cream()["ombre"], 1.0)
	# Chapeau et pois.
	var dome := Ink.oval(Vector2(0, -46 - 0.8 * br), 33.0, 22.0 + 0.8 * br, 30)
	for i in dome.size():
		dome[i].y = minf(dome[i].y, -40.0)
	V.part(ci, x2, dome, cap, 2.2, 1.0, 0.8)
	for q in [Vector2(-14, -54), Vector2(2, -61), Vector2(16, -53), Vector2(-3, -49), Vector2(22, -46), Vector2(-24, -46)]:
		V.blob(ci, x2, q, 3.6, 2.8, V.cream(), 0.9, 0.0, 0.4)
	V.eye(ci, x2, Vector2(2, -25), 3.4, 0.0)
	V.eye(ci, x2, Vector2(9, -24), 2.9, 0.0)
	V.sprout(ci, x2, Vector2(-14, -64), -1.9, 10.0, V.sap(), br, 2)
