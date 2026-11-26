## Formes guéries des Flétris de Racine (tâche F) : le termite ouvrier, la mandragore feuillue, le scarabée
## rhinocéros, le tertre moussu. Brun roux de terre et de bois de la région, chair de racine, vert sève ;
## jamais de braise ni de cendre. Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

const FORMES := {
	"termite": {"h": 41.0, "v": 44.0, "poses": {"repos": 2, "marche": 4}},
	"mandragore": {"h": 60.0, "v": 30.0, "poses": {"repos": 2, "marche": 4}},
	"scarabee": {"h": 53.0, "v": 36.0, "poses": {"repos": 2, "marche": 4}},
	"tertre": {"h": 55.0, "v": 14.0, "poses": {"repos": 2, "marche": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"termite": _termite(ci, xf, o)
		"mandragore": _mandragore(ci, xf, o)
		"scarabee": _scarabee(ci, xf, o)
		"tertre": _tertre(ci, xf, o)


static func _chair() -> Dictionary:
	return {"clair": Art.bc("racine", "chair"), "ombre": Art.bc("racine", "chair_ombre"), "reflet": Color("ffe6c8")}


static func _bois() -> Dictionary:
	return {"clair": Art.bc("racine", "bois"), "ombre": Art.bc("racine", "bois_ombre"), "reflet": Color("c9a07a")}


## Termite ouvrier : abdomen pâle annelé, tête de bois claire, mandibules rondes, six pattes qui trottent.
static func _termite(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 24.0)
	var rise := absf(sin(walk)) * 1.6 * mv
	var x2 := Transform2D(0.0, Vector2(0, -rise)) * xf
	for i in 3:
		var hx := -8.0 + i * 10.0
		var f := V.foot(Vector2(hx + 3.0, 0.0), walk, i * 2.0 + PI, 5.0, 4.0, mv)
		V.limb(ci, xf, Vector2(hx, -14), Vector2(hx + 5, -8), f, 2.0, V.pal("racine", 1.0)["ombre"])
	var ab := V.tint(V.cream(), Color("e8c898"), 0.4)
	V.part(ci, x2, Ink.oval(Vector2(-14, -20), 17.0, 11.5 + 0.7 * br, 22), ab, 1.6, 1.0, 0.8)
	for i in 4:
		V.stroke(ci, x2, PackedVector2Array([Vector2(-24 + i * 6.0, -29), Vector2(-23 + i * 6.0, -20), Vector2(-24 + i * 6.0, -12)]), 0.9, ab["ombre"], false)
	V.part(ci, x2, Ink.oval(Vector2(6, -20), 8.0, 8.0, 14), ab, 1.5, 1.0, 0.7)
	V.part(ci, x2, Ink.oval(Vector2(19, -20), 9.5, 8.5, 16), V.pal("racine"), 1.6, 1.0, 0.9)
	V.eye(ci, x2, Vector2(22, -22.5), 2.8, 0.0)
	V.part(ci, x2, PackedVector2Array([Vector2(25, -16), Vector2(33, -14), Vector2(30, -10), Vector2(24, -12)]), V.cream(), 1.0, 1.0, 0.4)
	V.stroke(ci, x2, PackedVector2Array([Vector2(22, -28), Vector2(28, -35), Vector2(33, -34 + br)]), 0.9, Color("6a4a30"))
	V.sprout(ci, x2, Vector2(-14, -30), -1.6, 7.0, V.sap(), br, 1)


## Mandragore : une racine ridée aux deux « jambes », un bouquet de feuilles vertes, deux yeux ronds.
static func _mandragore(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	var sw := sin(walk) * mv + 0.5 * br
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 20.0)
	var ch := _chair()
	var up := -absf(sin(walk)) * 3.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	for i in 2:
		var f := V.foot(Vector2(i * 10.0 - 4.0, 0.0), walk, i * PI, 6.0, 5.0, mv)
		V.limb(ci, xf, Vector2(i * 9.0 - 4.0, -22 + up), Vector2(i * 9.0 - 3.0 + (f.x - (i * 10.0 - 4.0)) * 0.3, -10), f, 5.0, ch["ombre"] if i == 0 else ch["clair"])
	V.limb(ci, x2, Vector2(-9, -42), Vector2(-20, -36 + 3 * sw), Vector2(-24, -27 + 5 * sw), 3.6, ch["ombre"])
	V.part(ci, x2, PackedVector2Array([Vector2(-13, -24), Vector2(-14, -42), Vector2(-8, -56), Vector2(0, -58 - br), Vector2(10, -54), Vector2(15, -40), Vector2(12, -24), Vector2(0, -20)]), ch, 2.0, 1.0, 0.8)
	for i in 4:
		V.stroke(ci, x2, PackedVector2Array([Vector2(-10, -26 - i * 7.0), Vector2(0, -24 - i * 7.0 - (i % 2)), Vector2(10, -27 - i * 7.0)]), 0.9, ch["ombre"], false)
	V.eye(ci, x2, Vector2(3.5, -44), 3.6, 0.0)
	V.eye(ci, x2, Vector2(10.5, -42), 3.0, 0.0)
	V.stroke(ci, x2, PackedVector2Array([Vector2(4, -35), Vector2(7.5, -33), Vector2(10.5, -35)]), 1.0, ch["ombre"], false)
	V.limb(ci, x2, Vector2(11, -40), Vector2(21, -35 - 3 * sw), Vector2(25, -44 - 5 * sw), 3.6, ch["clair"])
	V.sprout(ci, x2, Vector2(25, -44 - 5 * sw), -1.0, 8.0, V.sap(), sw, 1)
	V.crown(ci, x2, Vector2(0, -58), 24.0, V.leafy(0.4), 6, sw, -PI * 0.5, PI * 1.15)
	V.crown(ci, x2, Vector2(0, -59), 20.0, V.leafy(), 6, sw, -PI * 0.5, PI * 0.95)


## Scarabée rhinocéros : élytres d'écorce brun-roux luisants, grande corne claire, six pattes.
static func _scarabee(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 30.0)
	var shell := V.pal("racine")
	var far := V.pal("racine", 1.0)
	var rise := absf(sin(walk)) * 2.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, -rise)) * xf
	for i in 3:
		var hx := -14.0 + i * 12.0
		var f := V.foot(Vector2(hx + 4.0, 0.0), walk, i * 2.0 + PI, 6.0, 5.0, mv)
		V.limb(ci, xf, Vector2(hx, -16), Vector2(hx + 8, -8), f, 2.4, far["ombre"])
	V.part(ci, x2, Ink.oval(Vector2(-7, -23), 26.0, 17.0 + 0.7 * br, 28), shell, 2.0, 1.0, 1.0)
	V.stroke(ci, x2, PackedVector2Array([Vector2(-7, -40), Vector2(-7, -22), Vector2(-7, -7)]), 1.0, shell["ombre"], false)
	for i in 3:
		V.stroke(ci, x2, PackedVector2Array([Vector2(-26 + i * 6.0, -30), Vector2(-24 + i * 6.0, -18)]), 0.8, shell["reflet"], false)
	V.part(ci, x2, Ink.oval(Vector2(22, -24), 11.0, 10.0, 18), V.pal("racine", 0.2), 1.8, 1.0, 0.6)
	V.part(ci, x2, Ink.oval(Vector2(33, -24), 8.0, 7.0, 16), shell, 1.6, 1.0, 0.8)
	V.part(ci, x2, PackedVector2Array([Vector2(35, -29), Vector2(47, -45 + br), Vector2(50, -48), Vector2(46, -38), Vector2(40, -27)]), V.cream(), 1.4, 1.0, 0.8)
	V.eye(ci, x2, Vector2(32.5, -27), 2.5, 0.0)
	for i in 3:
		var hx := -10.0 + i * 12.0
		var f := V.foot(Vector2(hx + 4.0, 0.0), walk, i * 2.0, 6.0, 5.0, mv)
		V.limb(ci, x2, Vector2(hx, -14), Vector2(hx + 8, -8), Vector2(f.x, f.y + rise), 2.8, shell["clair"])
	V.sprout(ci, x2, Vector2(-14, -39), -1.4, 8.0, V.sap(), br, 1)


## Tertre moussu : une masse de roche brune coiffée de mousse et d'un jeune chêne, deux poings de pierre, deux yeux calmes.
static func _tertre(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	var sw := sin(walk) * mv + 0.4 * br
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 38.0)
	var st := V.tint(V.stone(), Color("b08a5e"), 0.35)
	var up := -absf(sin(walk)) * 2.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	for i in 2:
		var f := V.foot(Vector2(i * 20.0 - 12.0, 0.0), walk, i * PI, 5.0, 4.0, mv)
		V.part(ci, xf, Ink.oval(Vector2(f.x, f.y - 6.0), 10.0, 6.5, 14), V.tint(st, Color("000000"), 0.1 + 0.2 * (1 - i)), 1.5, 1.0, 0.3)
	V.limb(ci, x2, Vector2(-26, -34), Vector2(-40, -26 + 3 * br), Vector2(-39, -9), 8.0, V.wood(1.0)["clair"])
	V.part(ci, x2, Ink.lumpy(Vector2(-39, -9), 8.5, 7.5, 14, 0.15, 5.0), V.tint(st, Color("000000"), 0.2), 1.6, 1.0, 0.4)
	V.part(ci, x2, Ink.lumpy(Vector2(0, -34), 33.0, 28.0 + 1.0 * br, 34, 0.08, 7.0), st, 2.2, 1.0, 0.7)
	for q in [PackedVector2Array([Vector2(-18, -22), Vector2(-6, -40), Vector2(-12, -52)]), PackedVector2Array([Vector2(14, -18), Vector2(22, -34)])]:
		V.stroke(ci, x2, q, 1.1, st["ombre"], false)
	var mos := V.leafy()
	V.part(ci, x2, Ink.lumpy(Vector2(-2, -58), 26.0, 8.0, 22, 0.14, 6.0), mos, 1.6, 1.0, 0.7)
	V.part(ci, x2, Ink.lumpy(Vector2(-27, -36), 6.0, 11.0, 14, 0.2, 5.0), mos, 1.3, 1.0, 0.5)
	# Jeune chêne sur le dos : tronc fin et petit houppier.
	V.stroke(ci, x2, PackedVector2Array([Vector2(-8, -60), Vector2(-9 + sw, -72), Vector2(-8 + sw * 1.5, -80)]), 3.0, V.wood()["clair"])
	V.crown(ci, x2, Vector2(-8 + sw * 1.5, -80), 17.0, V.leafy(0.4), 5, sw, -PI * 0.5, PI * 1.1)
	V.crown(ci, x2, Vector2(-8 + sw * 1.5, -81), 14.0, V.leafy(), 5, sw, -PI * 0.5, PI * 0.9)
	V.eye(ci, x2, Vector2(12, -38), 3.8, 0.0, Vector2(0.2, 0.3))
	V.eye(ci, x2, Vector2(21, -36), 3.2, 0.0, Vector2(0.2, 0.3))
	V.limb(ci, x2, Vector2(26, -34), Vector2(40, -24 - 3 * br), Vector2(41, -9), 8.5, V.wood()["clair"])
	V.part(ci, x2, Ink.lumpy(Vector2(41, -9), 9.0, 8.0, 14, 0.15, 5.0), st, 1.7, 1.0, 0.5)
	V.sprout(ci, x2, Vector2(46, -14), -0.9, 8.0, V.sap(), br, 1)
