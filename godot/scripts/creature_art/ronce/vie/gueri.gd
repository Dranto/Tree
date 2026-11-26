## Formes guéries des Flétris de Ronce (tâche F) : la mûre, le charançon, le bédégar devenu églantier, la
## chenille de tenthrède, tels qu'ils étaient avant la Flétrissure. Cramoisi de la région (Art.BESTIAIRE ›
## ronce), feuilles vert sève, jamais de braise. Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

const FORMES := {
	"tireur": {"h": 43.0, "v": 30.0, "poses": {"repos": 2, "marche": 4}},
	"chargeur": {"h": 53.0, "v": 44.0, "poses": {"repos": 2, "marche": 4}},
	"nid": {"h": 55.0, "v": 20.0, "poses": {"repos": 2, "marche": 4}},
	"rejeton": {"h": 38.0, "v": 26.0, "poses": {"repos": 2, "marche": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"tireur": _tireur(ci, xf, o)
		"chargeur": _chargeur(ci, xf, o)
		"nid": _nid(ci, xf, o)
		"rejeton": _rejeton(ci, xf, o)


## Mûre sur trois racines-pattes : une grappe de drupes luisantes, une collerette de sépales verts, deux yeux.
static func _tireur(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 18.0)
	var berry := V.pal("ronce")
	var up := -absf(sin(walk)) * 4.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	for i in 3:
		var hx := -9.0 + i * 9.0
		var f := V.foot(Vector2(hx + 2.0, 0.0), walk, i * 2.1, 7.0, 6.0, mv)
		V.limb(ci, xf, Vector2(hx, -26 + up), Vector2(hx + 3 + (f.x - hx) * 0.4, -12), f, 3.0, V.wood()["ombre"] if i == 0 else V.wood()["clair"])
	# Corps : grappe de drupes (un ovale de fond, des petites billes en rangs).
	V.part(ci, x2, Ink.oval(Vector2(0, -44), 20.0, 21.0 + 0.8 * br, 26), V.pal("ronce", 0.4), 2.0, 1.0, 0.6)
	var n := 0
	for row in 5:
		var y := -57.0 + row * 8.2
		var half := 16.0 * sin(PI * (0.22 + row * 0.14))
		var cnt := 2 + (row % 2) + int(row * 0.5)
		for k in cnt:
			var x := -half + (2.0 * half) * (k + 0.5) / cnt
			V.blob(ci, x2, Vector2(x, y), 4.8, 4.4, berry, 1.0, 0.0, 1.0)
			n += 1
	# Visage : deux yeux entre les drupes, regard devant.
	V.eye(ci, x2, Vector2(6.0, -45), 3.6, 0.0)
	V.eye(ci, x2, Vector2(13.0, -43), 3.0, 0.0)
	# Sépales et jeune tige de feuilles au sommet.
	for i in 5:
		var a := -PI * 0.5 - 1.2 + i * 0.6
		V.part(ci, x2, Ink.leaf(Vector2(0, -64), a, 13.0, 5.5, 0.05 * (i - 2)), V.leafy(0.2), 1.0, 1.0, 0.6)
	V.sprout(ci, x2, Vector2(1, -66), -1.65, 14.0, V.sap(), br * 0.6, 2)


## Charançon des ronces : élytres de mûre rayés, long rostre en lance, six pattes fines, antennes coudées.
static func _chargeur(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 28.0)
	var shell := V.pal("ronce")
	var far := V.pal("ronce", 1.0)
	var rise := absf(sin(walk)) * 2.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, -rise)) * xf
	# Pattes du fond, puis du devant.
	for i in 3:
		var hx := -12.0 + i * 12.0
		var f := V.foot(Vector2(hx + 4.0, 0.0), walk, i * 2.0 + PI, 6.0, 5.0, mv)
		V.limb(ci, xf, Vector2(hx, -16), Vector2(hx + 7, -9), f, 2.4, far["ombre"])
	# Élytres bombés, thorax, tête et rostre.
	V.part(ci, x2, Ink.oval(Vector2(-6, -24), 25.0, 17.0 + 0.7 * br, 28), shell, 2.0, 1.0, 0.9)
	for i in 5:
		var x := -22.0 + i * 8.5
		V.stroke(ci, x2, PackedVector2Array([Vector2(x, -38.0 + absf(i - 2) * 1.5), Vector2(x + 1.5, -24), Vector2(x - 0.5, -10)]), 1.1, shell["ombre"], false)
	V.part(ci, x2, Ink.oval(Vector2(22, -25), 11.0, 10.0, 18), V.pal("ronce", 0.2), 1.8, 1.0, 0.6)
	V.part(ci, x2, Ink.oval(Vector2(32, -23), 7.0, 6.5, 16), shell, 1.6, 1.0, 0.6)
	V.stroke(ci, x2, PackedVector2Array([Vector2(36, -22), Vector2(46, -17), Vector2(55, -12)]), 3.2, V.wood()["ombre"])
	V.stroke(ci, x2, PackedVector2Array([Vector2(36, -22), Vector2(46, -17), Vector2(55, -12)]), 1.8, V.wood()["clair"], false)
	V.bead(ci, x2, Vector2(33, -26), 2.3)
	V.stroke(ci, x2, PackedVector2Array([Vector2(35, -29), Vector2(41, -37 + 2 * br), Vector2(48, -37)]), 0.9, V.wood()["ombre"])
	# Pattes de devant.
	for i in 3:
		var hx := -10.0 + i * 12.0
		var f := V.foot(Vector2(hx + 4.0, 0.0), walk, i * 2.0, 6.0, 5.0, mv)
		V.limb(ci, x2, Vector2(hx, -14), Vector2(hx + 8, -8), Vector2(f.x, f.y + rise), 2.8, shell["clair"])
	V.sprout(ci, x2, Vector2(-2, -41), -1.4, 9.0, V.sap(), br, 1)


## Églantier : une touffe de feuilles et de fleurs roses, des cynorhodons rouges, trois tiges arquées pour marcher.
static func _nid(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	var sw := sin(walk) * mv + 0.5 * br
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 26.0)
	var stem := V.wood(0.0)
	for i in 3:
		var hx := -14.0 + i * 14.0
		var f := V.foot(Vector2(hx + (i - 1) * 5.0, 0.0), walk, i * 2.1, 6.0, 5.0, mv)
		V.stroke(ci, xf, PackedVector2Array([Vector2(hx * 0.4, -34), Vector2(hx * 0.9 + (i - 1) * 6.0, -20), f]), 3.0, stem["ombre"] if i != 1 else stem["clair"])
		V.part(ci, xf, Ink.thorn(Vector2(hx * 0.7, -24), -1.2 + i * 0.5, 5.0, 2.6), V.cream(), 0.9, 1.0, 0.2)
	var up := -absf(sin(walk)) * 3.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	# Masse de feuillage de deux tons, puis feuilles de devant.
	V.part(ci, x2, Ink.lumpy(Vector2(0, -52), 27.0, 22.0 + br, 26, 0.12, 8.0), V.leafy(0.6), 2.0, 1.0, 0.4)
	V.crown(ci, x2, Vector2(-8, -52), 22.0, V.leafy(0.3), 7, sw, -PI, PI * 1.8)
	V.crown(ci, x2, Vector2(6, -50), 22.0, V.leafy(), 7, sw, 0.0, PI * 1.7)
	# Fleurs roses et cynorhodons.
	V.flower(ci, x2, Vector2(-14, -64), 6.0, Color("f4a3b4"))
	V.flower(ci, x2, Vector2(12, -70), 5.5, Color("ffd0da"))
	for q in [Vector2(-20, -44), Vector2(21, -53), Vector2(2, -37)]:
		V.blob(ci, x2, q, 4.6, 5.6, V.pal("ronce"), 1.2, 0.0, 1.0)
		V.sprout(ci, x2, q + Vector2(0, -4), -1.6, 3.0, V.leafy(), 0.0, 0)
	V.eye(ci, x2, Vector2(7.0, -50), 3.8, 0.0)
	V.eye(ci, x2, Vector2(15.0, -48), 3.2, 0.0)
	V.sprout(ci, x2, Vector2(-2, -70), -1.55, 13.0, V.sap(), sw, 2)


## Chenille de tenthrède : un corps annelé vert tendre barré de cramoisi, ondulant, deux yeux ronds.
static func _rejeton(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 28.0)
	var green := V.tint(V.leafy(), Color("c8e070"), 0.25)
	var crim := V.pal("ronce")
	var n := 7
	var segs: Array = []
	for i in n:
		var u := float(i) / (n - 1)
		var wave := sin(walk * 1.0 - u * 5.0) * mv
		segs.append(Vector2(-34.0 + 56.0 * u, -13.0 - 6.0 * maxf(wave, 0.0) - 1.2 * br * sin(u * PI) - 5.0 * sin(u * PI) * 0.6))
	# Pattes minuscules, puis anneaux de la queue vers la tête.
	for i in range(1, n):
		V.stroke(ci, xf, PackedVector2Array([segs[i] + Vector2(0, 3), segs[i] + Vector2(1.5, 8), Vector2(segs[i].x + 2.5, 0)]), 1.8, V.wood()["ombre"])
	for i in n:
		var u := float(i) / (n - 1)
		var r := 8.0 + 4.0 * sin(PI * minf(u * 1.3, 1.0))
		V.blob(ci, xf, segs[i], r, r * 0.95, green if i % 2 == 0 else V.tint(green, Color("e8f0a0"), 0.2), 1.5, 0.0, 0.8)
		V.blob(ci, xf, segs[i] + Vector2(1, -r * 0.55), 2.2, 2.0, crim, 0.0, 0.0, 0.0)
	# Tête : plus claire, avec deux yeux ronds.
	var hd: Vector2 = segs[n - 1] + Vector2(7, 1)
	V.blob(ci, xf, hd, 10.0, 10.0, V.pal("ronce", 0.0), 1.6, 0.0, 0.9)
	V.eye(ci, xf, hd + Vector2(3.5, -2.0), 3.3, 0.0)
	V.eye(ci, xf, hd + Vector2(-1.5, -3.0), 2.7, 0.0)
	V.sprout(ci, xf, segs[2] + Vector2(0, -12), -1.5, 8.0, V.sap(), br, 1)
