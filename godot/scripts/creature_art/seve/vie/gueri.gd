## Formes guéries des Flétris de Sève (tâche F) : la sangsue lustrée, la grenouille verte, la libellule aux
## ailes claires, le jeune saule. Vert de mare de la région, vase ocre, vert sève ; jamais de braise.
## La libellule a la pose « vol » : elle voltige au lieu de marcher. Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

const FORMES := {
	"sangsue_vase": {"h": 48.0, "v": 22.0, "poses": {"repos": 2, "marche": 4}},
	"crapaud": {"h": 55.0, "v": 30.0, "poses": {"repos": 2, "marche": 4}},
	"libellule": {"h": 53.0, "v": 70.0, "poses": {"vol": 4}},
	"souche": {"h": 60.0, "v": 20.0, "poses": {"repos": 2, "marche": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"sangsue_vase": _sangsue(ci, xf, o)
		"crapaud": _grenouille(ci, xf, o)
		"libellule": _libellule(ci, xf, o)
		"souche": _saule(ci, xf, o)


## Sangsue lustrée : olive luisante, bande orange sur le dos, ventouse tendue en avant, petits yeux clairs.
static func _sangsue(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 30.0)
	var body := V.pal("seve", 0.0)
	var vase := {"clair": Art.bc("seve", "vase").lightened(0.2), "ombre": Art.bc("seve", "vase").darkened(0.2), "reflet": Art.bc("seve", "detail")}
	var n := 9
	var segs: Array = []
	for i in n:
		var u := float(i) / (n - 1)
		var wave := sin(walk - u * 5.5) * mv
		segs.append(Vector2(-36.0 + 66.0 * u, -11.0 - 7.0 * maxf(wave, 0.0) - 5.0 * sin(u * PI) - 1.2 * br * sin(u * PI)))
	for i in n:
		var u := float(i) / (n - 1)
		var r := 6.0 + 7.0 * sin(PI * (0.12 + 0.82 * u))
		V.blob(ci, xf, segs[i], r, r * 0.9, body if i % 2 == 0 else V.tint(body, Color("a6e08a"), 0.2), 1.5, 0.0, 0.9)
		V.blob(ci, xf, segs[i] + Vector2(0, -r * 0.55), r * 0.55, r * 0.22, {"clair": Color("e8a64a"), "ombre": Color("b8742a"), "reflet": Color("ffd890")}, 0.0, 0.0, 0.4)
	var hd: Vector2 = segs[n - 1] + Vector2(7, 2)
	V.part(ci, xf, Ink.oval(hd, 8.0, 7.0, 14), vase, 1.5, 1.0, 0.6)
	V.part(ci, xf, Ink.oval(hd + Vector2(4.5, 1.0), 3.2, 4.4, 10), V.cream(), 1.0, 1.0, 0.3)
	for k in 3:
		V.bead(ci, xf, hd + Vector2(-1.0 + k * 2.4, -4.6), 1.1, Color("fff6e0"))
	V.sprout(ci, xf, segs[3] + Vector2(0, -10), -1.5, 8.0, V.sap(), br, 1)


## Grenouille verte : lisse et luisante, gorge crème qui respire, gros yeux dorés, cuisses repliées.
static func _grenouille(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 26.0)
	var skin := V.pal("seve")
	var far := V.pal("seve", 1.0)
	var hop := absf(sin(walk)) * 8.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, -hop)) * xf
	V.limb(ci, xf, Vector2(18, -10), Vector2(26 + 5 * sin(walk) * mv, -4), Vector2(30 + 6 * sin(walk) * mv, 0), 4.8, far["clair"])
	V.part(ci, x2, Ink.oval(Vector2(-14, -12), 14.0, 10.0, 18, -0.2), far, 1.5, 1.0, 0.5)
	var back := Ink.oval(Vector2(-3, -27), 27.0, 19.0 + 1.0 * br, 30, -0.05)
	var head := Ink.oval(Vector2(19, -24), 15.0, 11.0, 24, -0.15)
	var sh := Geometry2D.merge_polygons(back, head)
	var body: PackedVector2Array = sh[0] if not sh.is_empty() else back
	for i in body.size():
		body[i].y = minf(body[i].y, -5.0)
	V.part(ci, x2, body, skin, 2.0, 1.0, 0.9)
	V.blob(ci, x2, Vector2(14, -10), 15.0, 5.0 + 1.2 * br, V.cream(), 0.0, 0.0, 0.3)
	V.stroke(ci, x2, PackedVector2Array([Vector2(-14, -40), Vector2(-2, -44), Vector2(10, -38)]), 1.4, skin["reflet"], false)
	for xx in [15.0, 25.0]:
		V.blob(ci, x2, Vector2(xx, -35), 5.3, 4.8, skin, 1.4, 0.0, 0.4)
		V.eye(ci, x2, Vector2(xx + 0.5, -35.5), 3.6, 0.0)
	V.stroke(ci, x2, PackedVector2Array([Vector2(13, -19), Vector2(25, -17), Vector2(33, -21)]), 1.1, skin["ombre"], false)
	V.limb(ci, x2, Vector2(18, -10), Vector2(24, -4), Vector2(28 + 3 * sin(walk + PI) * mv, 0), 4.0, skin["clair"])
	V.sprout(ci, x2, Vector2(-8, -44), -1.4, 10.0, V.sap(), br, 2)


## Libellule : corps bleu-vert irisé, deux paires d'ailes claires nervurées qui battent, grands yeux.
static func _libellule(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var flap := sin(walk)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 14.0)
	var c := Vector2(0, -48)
	var glass := {"clair": Color("d8f4ec"), "ombre": Color("7ab8a8"), "reflet": Color.WHITE}
	var lift := 0.45 + 0.55 * (flap * 0.5 + 0.5)
	var bodyp := V.pal("seve")
	# Ailes du fond (côté loin), puis abdomen et thorax, puis ailes de devant.
	for k in [0, 1]:
		var base := c + Vector2(-2.0 + k * 7.0, -3.0)
		var tip := base + Vector2(-8.0 + k * 3.0, -26.0 * lift - 4.0 * k)
		var wing := PackedVector2Array([base, base + Vector2(-5, -10 * lift), tip, tip + Vector2(11, 2), base + Vector2(8, -6 * lift)])
		V.part(ci, xf, wing, V.tint(glass, Color("98c8b8"), 0.3), 1.0, 1.0, 0.6)
	V.part(ci, xf, PackedVector2Array([c + Vector2(-5, -3), c + Vector2(-44, 2 + 2 * flap), c + Vector2(-45, 5 + 2 * flap), c + Vector2(-5, 4)]), bodyp, 1.4, 1.0, 0.8)
	V.part(ci, xf, Ink.oval(c + Vector2(2, 0), 9.0, 7.5, 16), V.tint(bodyp, Color("2aa6a0"), 0.3), 1.5, 1.0, 0.9)
	V.part(ci, xf, Ink.oval(c + Vector2(12, -1), 7.0, 6.5, 16), bodyp, 1.4, 1.0, 0.8)
	V.eye(ci, xf, c + Vector2(14.5, -2.5), 3.8, 0.0, Vector2(0.4, 0.2))
	for k in [0, 1]:
		var base := c + Vector2(1.0 + k * 7.0, -3.0)
		var tip := base + Vector2(10.0 + k * 4.0, -24.0 * lift - 3.0 * k)
		var wing := PackedVector2Array([base, base + Vector2(6, -9 * lift), tip, tip + Vector2(-12, 2), base + Vector2(-6, -5 * lift)])
		V.part(ci, xf, wing, glass, 1.0, 1.0, 0.7)
		V.stroke(ci, xf, PackedVector2Array([base, base.lerp(tip, 0.5), tip]), 0.7, glass["ombre"], false)
	V.sprout(ci, xf, c + Vector2(-8, -6), -1.9, 6.0, V.sap(), flap, 0)


## Jeune saule : une souche coiffée de rejets verts qui retombent, des chatons, deux racines pour marcher.
static func _saule(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	var sw := sin(walk) * mv + 0.5 * br
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 24.0)
	var wd := V.tint(V.wood(), Color("a8985a"), 0.3)
	var up := -absf(sin(walk)) * 2.5 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	for i in 2:
		var f := V.foot(Vector2(i * 14.0 - 9.0, 0.0), walk, i * PI, 6.0, 4.0, mv)
		V.limb(ci, xf, Vector2(i * 12.0 - 8.0, -16 + up), Vector2(i * 12.0 - 8.0 + (f.x - (i * 14.0 - 9.0)) * 0.3, -8), f, 5.0, V.wood(1.0)["clair"])
	V.part(ci, x2, PackedVector2Array([Vector2(-18, -12), Vector2(-20, -40), Vector2(-14, -58), Vector2(0, -62 - br), Vector2(14, -56), Vector2(20, -38), Vector2(18, -12), Vector2(0, -8)]), wd, 2.0, 1.0, 0.7)
	V.part(ci, x2, Ink.oval(Vector2(0, -60), 14.0, 4.5, 20), {"clair": Color("d9c58a"), "ombre": Color("a08a54"), "reflet": Color("f6ecc4")}, 1.2, 1.0, 0.5)
	# Cernes sur le dessus, rejets de saule qui retombent avec leurs feuilles longues.
	for i in 7:
		var x := -12.0 + i * 4.2
		var pts := PackedVector2Array([Vector2(x, -62), Vector2(x + (i - 3) * 2.4 + sw * 2.0, -78), Vector2(x + (i - 3) * 5.0 + sw * 3.0, -64), Vector2(x + (i - 3) * 6.0 + sw * 4.0, -44 + (i % 2) * 6.0)])
		V.stroke(ci, x2, pts, 1.7, V.leafy()["ombre"], true)
		V.part(ci, x2, Ink.leaf(Vector2(x + (i - 3) * 4.4, -62), -PI * 0.5 + (i - 3) * 0.5, 22.0, 5.0, (i - 3) * 0.05), V.leafy(0.0) if i % 2 == 0 else V.sap(), 0.9, 1.0, 0.6)
	# Visage dans le tronc.
	V.eye(ci, x2, Vector2(5.0, -34), 3.4, 0.0)
	V.eye(ci, x2, Vector2(12.0, -32), 2.9, 0.0)
	V.blob(ci, x2, Vector2(-12, -45), 3.0, 4.6, V.cream(), 0.9, 0.0, 0.3)
