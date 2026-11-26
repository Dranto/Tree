## Outils communs de la faune non hostile et des formes guéries (refonte « Bestiaire d'herbier », tâche F).
## Même grammaire que les Flétris et le héros (encre fine, deux tons, lumière en haut à gauche, trois
## quarts), mais côté vivant : corps à la palette de la région, vert sève, yeux clairs, jamais de braise
## ni de cendre. Ce fichier n'est pas une sorte (aucun id de enemies.json ne s'appelle « outils »).
##
## Contrat d'un script `creature_art/<région>/vie/faune.gd` ou `gueri.gd` (cuit par world_life_vie.gd) :
##   const FORMES := {"<id>": {"h": hauteur en px du jeu pour 100 unités, "poses": {"repos": 2, "marche": 4, ...}}}
##   static func draw(ci, feet, h, o)  — o : sp (id), pose, i (image), n (nombre d'images), t, walk, moving.
## Poses : repos (respiration, t), marche (walk de 0 à 2π), vol (battement, walk), saut (0 = élan … 1 = chute).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")


## Palette d'un corps vivant : la région (Art.BESTIAIRE) ; dark 0 → 1 pour les membres du fond.
static func pal(reg: String, dark := 0.0) -> Dictionary:
	var p := {"clair": Art.bc(reg, "clair"), "ombre": Art.bc(reg, "ombre"), "reflet": Art.bc(reg, "reflet")}
	return _dark(p, dark)


static func _dark(p: Dictionary, dark: float) -> Dictionary:
	if dark <= 0.0:
		return p
	return {"clair": p["clair"].darkened(0.3 * dark), "ombre": p["ombre"].darkened(0.3 * dark), "reflet": p["clair"]}


## Une couleur de la région (clé de Art.BESTIAIRE › région).
static func rc(reg: String, key: String) -> Color:
	return Art.bc(reg, key)


## Vert sève vivant : le signe commun du « vivant ».
static func sap(dark := 0.0) -> Dictionary:
	return _dark({"clair": Art.ec("seve"), "ombre": Art.ec("seve", "sombre").lerp(Art.ec("seve"), 0.25), "reflet": Art.ec("seve", "clair")}, dark)


## Vert de feuille franc (un peu moins lumineux que la sève).
static func leafy(dark := 0.0) -> Dictionary:
	return _dark({"clair": Color("7fb04a"), "ombre": Color("3f6a28"), "reflet": Color("d2eb8a")}, dark)


## Bois vivant (écorce brune d'une pousse), terre cuite chaude, crème (ventre, dents, yeux).
static func wood(dark := 0.0) -> Dictionary:
	return _dark({"clair": Color("93694a"), "ombre": Color("523626"), "reflet": Color("c9a07a")}, dark)


static func cream(dark := 0.0) -> Dictionary:
	return _dark({"clair": Color("f1e6c8"), "ombre": Color("b09c78"), "reflet": Color("fffbea")}, dark)


## Corps de pierre vivante (mousse à part).
static func stone(dark := 0.0) -> Dictionary:
	return _dark({"clair": Color("a69584"), "ombre": Color("6a5a4c"), "reflet": Color("d8cab4")}, dark)


## Teinte d'un ton plus clair / plus foncé, en gardant les trois tons.
static func tint(p: Dictionary, c: Color, k := 0.4) -> Dictionary:
	return {"clair": p["clair"].lerp(c, k), "ombre": p["ombre"].lerp(c, k * 0.8), "reflet": p["reflet"].lerp(c, k * 0.5)}


## Forme pleine : encre fine, deux tons, reflet.
static func part(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, p: Dictionary, ink := 1.7, lit := 1.0, shine := 0.8) -> void:
	Ink.part(ci, xf, pts, p, ink, lit, shine)


## Ovale plein (centre, rayons, rotation).
static func blob(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float, ry: float, p: Dictionary, ink := 1.7, rot := 0.0, shine := 0.8) -> void:
	Ink.part(ci, xf, Ink.oval(c, rx, ry, 22, rot), p, ink, 1.0, shine)


## Œil vivant : encre, blanc cassé, pupille qui regarde look (-1 → 1), reflet ; blink 1 = fermé.
static func eye(ci: CanvasItem, xf: Transform2D, p: Vector2, r: float, blink := 0.0, look := Vector2(0.35, 0.0)) -> void:
	var s := xf.get_scale().abs().x
	var c := xf * p
	if Ink.mono:
		ci.draw_circle(c, r * s, Ink.encre())
		return
	ci.draw_circle(c, (r + 0.9) * s, Ink.encre())
	if blink > 0.5:
		ci.draw_line(c - Vector2(r * s, 0), c + Vector2(r * s, 0), Ink.encre(), 0.5 * s)
		return
	ci.draw_circle(c, r * s, Color("fff6e0"))
	ci.draw_circle(c + look * r * 0.35 * s, r * 0.62 * s, Ink.encre())
	ci.draw_circle(c + look * r * 0.35 * s + Vector2(-0.25, -0.3) * r * s, r * 0.2 * s, Color.WHITE)


## Œil plein et sombre (insecte, perle) avec son reflet.
static func bead(ci: CanvasItem, xf: Transform2D, p: Vector2, r: float, col := Color.TRANSPARENT) -> void:
	var s := xf.get_scale().abs().x
	var c := xf * p
	ci.draw_circle(c, r * s, Ink.encre() if col.a == 0.0 else col)
	if not Ink.mono:
		ci.draw_circle(c + Vector2(-0.3, -0.35) * r * s, r * 0.32 * s, Color(1, 1, 1, 0.9))


## Membre à deux segments a → b → c : trait d'encre puis couleur (pattes, bras, antennes).
static func limb(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, c: Vector2, w: float, col: Color) -> void:
	var pts := PackedVector2Array([a, a.lerp(b, 0.5), b, b.lerp(c, 0.5), c])
	Ink.brush(ci, xf, pts, w + 1.5, Ink.encre(), 0.5, 0.0)
	Ink.brush(ci, xf, pts, w, col, 0.5, 0.0)


## Trait effilé (nervure, antenne, brin) le long de pts.
static func stroke(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, w: float, col: Color, inked := true) -> void:
	if inked:
		Ink.brush(ci, xf, pts, w + 1.3, Ink.encre(), 0.3, 0.0)
	Ink.brush(ci, xf, pts, w, col, 0.3, 0.0)


## Pied qui marche : position d'une patte (hanche h, déphasage ph) pour la marche walk, avec levée lift.
static func foot(h: Vector2, walk: float, ph: float, stride: float, lift: float, mv: float) -> Vector2:
	var u := walk + ph
	return h + Vector2(sin(u) * stride * mv, -maxf(0.0, cos(u)) * lift * mv)


## Pousse de sève : tige courbe de la base b, direction a (radians), longueur l, deux feuilles, balancée.
static func sprout(ci: CanvasItem, xf: Transform2D, b: Vector2, a: float, l: float, p: Dictionary, sway := 0.0, leaves := 2) -> void:
	var tip := b + Vector2.from_angle(a + sway * 0.12) * l
	var mid := b.lerp(tip, 0.5) + Vector2.from_angle(a + 1.2) * l * 0.1 * (1.0 + sway)
	stroke(ci, xf, PackedVector2Array([b, mid, tip]), 1.6, p["ombre"])
	for i in leaves:
		var side := 1.0 if i % 2 == 0 else -1.0
		var at := b.lerp(tip, 0.45 + 0.4 * i / maxf(1.0, leaves - 1.0))
		part(ci, xf, Ink.leaf(at, a + side * (0.9 - 0.12 * i) + sway * 0.1, l * 0.5, l * 0.3, side * 0.1), p, 1.2, 1.0, 0.6)
	part(ci, xf, Ink.leaf(tip, a + sway * 0.12, l * 0.5, l * 0.3), p, 1.2, 1.0, 0.7)


## Touffe de feuilles (couronne d'un arbre, houppier) : n feuilles autour de c, sur un arc.
static func crown(ci: CanvasItem, xf: Transform2D, c: Vector2, r: float, p: Dictionary, n := 7, sway := 0.0, a0 := -PI * 0.5, arc := PI * 1.5) -> void:
	for i in n:
		var u := i / float(maxi(1, n - 1))
		var a := a0 - arc * 0.5 + arc * u + sway * 0.08 * (u - 0.5)
		part(ci, xf, Ink.leaf(c + Vector2.from_angle(a) * r * 0.25, a, r, r * 0.62), p, 1.2, 1.0, 0.6)


## Petite fleur de cinq pétales (vue de face, un peu aplatie).
static func flower(ci: CanvasItem, xf: Transform2D, c: Vector2, r: float, petal: Color, heart := Color("f7d36a")) -> void:
	for i in 5:
		var a := TAU * i / 5.0 - PI * 0.5
		var pp := {"clair": petal, "ombre": petal.darkened(0.25), "reflet": petal.lightened(0.4)}
		part(ci, xf, Ink.oval(c + Vector2(cos(a), sin(a) * 0.8) * r * 0.62, r * 0.55, r * 0.42, 12, a), pp, 0.9, 1.0, 0.5)
	blob(ci, xf, c, r * 0.32, r * 0.28, {"clair": heart, "ombre": heart.darkened(0.3), "reflet": heart.lightened(0.5)}, 0.8, 0.0, 0.4)


## Respiration : −1 → 1 sur la pose (t de la pose « repos »).
static func breath(t: float) -> float:
	return sin(t * TAU / 2.4)


## Rebond de la marche (0 → 1 deux fois par cycle).
static func bob(walk: float, mv: float) -> float:
	return absf(sin(walk)) * mv


## Forme d'un seul ton (tache, fente, détail plat), avec ou sans encre.
static func flat(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, col: Color, ink := 0.0) -> void:
	Ink.flat(ci, xf, pts, col, ink)


# ---------------------------------------------------------------- faune : gabarits communs

## Papillon vu de trois quarts, ailes qui battent (flap −1 → 1). wing : ailes de devant ; rear : ailes du fond ;
## dot : ocelles ; s : échelle (1 = 60 unités d'envergure).
static func butterfly(ci: CanvasItem, xf: Transform2D, flap: float, wing: Dictionary, rear: Dictionary, dot: Color, s := 1.0, c := Vector2(0, -50)) -> void:
	var open := 0.22 + 0.78 * (flap * 0.5 + 0.5)
	for side in [-1.0, 1.0]:
		var p := wing if side > 0 else rear
		var up := PackedVector2Array([c + Vector2(side * 2, -2) * s, c + Vector2(side * 12 * open, -22) * s, c + Vector2(side * 32 * open, -26) * s, c + Vector2(side * 36 * open, -6) * s, c + Vector2(side * 12 * open, 3) * s])
		var lo := PackedVector2Array([c + Vector2(side * 2, 2) * s, c + Vector2(side * 24 * open, 4) * s, c + Vector2(side * 20 * open, 20) * s, c + Vector2(side * 6 * open, 22) * s, c + Vector2(side * 2, 10) * s])
		part(ci, xf, lo, tint(p, Color.BLACK, 0.12), 1.2, 1.0, 0.5)
		part(ci, xf, up, p, 1.2, 1.0, 0.9)
		blob(ci, xf, c + Vector2(side * 24 * open, -14) * s, (3.4 * open + 0.5) * s, (3.0 * open + 0.5) * s, {"clair": dot, "ombre": dot.darkened(0.3), "reflet": dot.lightened(0.4)}, 0.0, 0.0, 0.3)
	part(ci, xf, Ink.oval(c + Vector2(0, 4) * s, 3.0 * s, 13.0 * s, 12), cream(), 1.2, 1.0, 0.5)
	blob(ci, xf, c + Vector2(0, -10) * s, 3.6 * s, 3.4 * s, cream(), 1.2, 0.0, 0.5)
	bead(ci, xf, c + Vector2(1.5, -10.5) * s, 1.3 * s)
	for side in [-1.0, 1.0]:
		stroke(ci, xf, PackedVector2Array([c + Vector2(side * 1, -13) * s, c + Vector2(side * 6, -21) * s, c + Vector2(side * 9, -24 + flap) * s]), 0.8, Color("5a4030"))


## Petit oiseau (fauvette, alouette, colombe, pic) : o.pose = repos (i 0 tête haute, 1 qui picore) ou vol (battement).
## spec : back, belly, wing (palettes), tail (palette), beak, legs (couleurs), len (longueur de queue), crest, mark (couleur de poitrail).
static func bird(ci: CanvasItem, xf: Transform2D, o: Dictionary, spec: Dictionary) -> void:
	var back: Dictionary = spec["back"]
	var belly: Dictionary = spec["belly"]
	var wing: Dictionary = spec.get("wing", back)
	var tail: Dictionary = spec.get("tail", back)
	var beak: Color = spec.get("beak", Color("e8c070"))
	var legs: Color = spec.get("legs", Color("b88a60"))
	var ln: float = spec.get("len", 16.0)
	var fl: bool = o.get("pose", "repos") == "vol"
	var t: float = o.get("t", 0.0)
	var br := breath(t)
	if not fl:
		var peck: bool = int(o.get("i", 0)) == 1
		Ink.ground_shadow(ci, xf, Vector2(0, 0), 18.0)
		for k in 2:
			stroke(ci, xf, PackedVector2Array([Vector2(-2 + k * 7.0, -14), Vector2(-2 + k * 7.0, -7), Vector2(-3 + k * 7.0 + 2.0, 0)]), 1.7, legs)
		part(ci, xf, PackedVector2Array([Vector2(-12, -26), Vector2(-12 - ln, -22 - (0 if peck else 4)), Vector2(-14 - ln, -16), Vector2(-10, -15)]), tail, 1.4, 1.0, 0.4)
		part(ci, xf, Ink.oval(Vector2(0, -25), 17.0, 12.0 + 0.5 * br, 22, -0.18 if not peck else -0.38), back, 1.9, 1.0, 0.8)
		var hd := Vector2(14, -35) if not peck else Vector2(20, -21)
		part(ci, xf, Ink.oval(Vector2(5, -21), 11.0, 8.0, 16, -0.1), belly, 1.2, 1.0, 0.5)
		if spec.has("mark"):
			blob(ci, xf, Vector2(8, -25) + (hd - Vector2(14, -35)) * 0.3, 8.0, 6.5, {"clair": spec["mark"], "ombre": spec["mark"].darkened(0.3), "reflet": spec["mark"].lightened(0.4)}, 0.0, 0.0, 0.4)
		part(ci, xf, Ink.oval(Vector2(-6, -27), 11.0, 6.0, 16, 0.25), wing, 1.2, 1.0, 0.4)
		part(ci, xf, Ink.oval(hd, 8.0, 7.6, 16), back, 1.6, 1.0, 0.8)
		if spec.get("crest", false):
			part(ci, xf, PackedVector2Array([hd + Vector2(-3, -6), hd + Vector2(-9, -13), hd + Vector2(0, -8)]), back, 1.0, 1.0, 0.3)
		var bt := hd + (Vector2(8, 0.5) if not peck else Vector2(6, 6))
		part(ci, xf, PackedVector2Array([hd + Vector2(5, -2.5), bt + Vector2(spec.get("beak_len", 3.0), 0), hd + Vector2(5, 2.0)]), {"clair": beak, "ombre": beak.darkened(0.3)}, 0.9, 1.0, 0.2)
		eye(ci, xf, hd + Vector2(2.2, -1.2), 2.2, 0.0)
	else:
		var u: float = o.get("walk", 0.0)
		var flap := sin(u)
		Ink.ground_shadow(ci, xf, Vector2(0, 0), 14.0)
		var c := Vector2(0, -48)
		# Aile du fond, queue, corps, aile de devant (feuilles en amande qui montent et descendent avec le battement).
		var wl: float = spec.get("wing_len", 26.0)
		part(ci, xf, Ink.leaf(c + Vector2(3, -2), PI + flap * 1.0 + 0.3, wl * 0.9, wl * 0.42), tint(wing, Color.BLACK, 0.25), 1.2, 1.0, 0.4)
		part(ci, xf, PackedVector2Array([c + Vector2(-10, 0), c + Vector2(-12 - ln, -2 + 3 * flap), c + Vector2(-14 - ln, 4 + 3 * flap), c + Vector2(-9, 5)]), tail, 1.3, 1.0, 0.4)
		part(ci, xf, Ink.oval(c, 15.0, 8.5, 20, -0.1), back, 1.8, 1.0, 0.8)
		part(ci, xf, Ink.oval(c + Vector2(2, 3), 11.0, 5.0, 14), belly, 1.0, 1.0, 0.5)
		part(ci, xf, Ink.oval(c + Vector2(14, -3), 7.0, 6.4, 14), back, 1.4, 1.0, 0.8)
		part(ci, xf, PackedVector2Array([c + Vector2(19, -4.5), c + Vector2(25, -2.5), c + Vector2(19, -0.5)]), {"clair": beak, "ombre": beak.darkened(0.3)}, 0.8, 1.0, 0.2)
		eye(ci, xf, c + Vector2(16.5, -4.2), 2.0, 0.0)
		part(ci, xf, Ink.leaf(c + Vector2(1, -1), PI + flap * 1.0 - 0.15, wl, wl * 0.46), wing, 1.3, 1.0, 0.7)


## Luciole : thorax sombre, lanterne claire et chaude (halo doux), ailes de gaze qui battent.
static func firefly(ci: CanvasItem, xf: Transform2D, flap: float, body: Dictionary, lamp: Color, s := 1.0, c := Vector2(0, -44)) -> void:
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 8.0 * s)
	var up := 0.35 + 0.65 * (flap * 0.5 + 0.5)
	var lp := c + Vector2(-9, 5) * s
	Ink.halo(ci, xf * lp, 17.0 * s * xf.get_scale().x, lamp, 1.1)
	for k in [0, 1]:
		var base := c + Vector2(k * 4.0, -3) * s
		var tip := base + Vector2(-6 + k * 3.0, -19 * up) * s
		part(ci, xf, PackedVector2Array([base, base + Vector2(-4, -7 * up) * s, tip, tip + Vector2(8, 2) * s, base + Vector2(5, -4 * up) * s]), {"clair": Color(1, 1, 1, 0.8), "ombre": Color(0.8, 0.9, 0.9, 0.7), "reflet": Color.WHITE}, 0.7, 1.0, 0.5)
	part(ci, xf, Ink.oval(c + Vector2(-4, 3) * s, 9.0 * s, 5.2 * s, 14, 0.4), body, 1.2, 1.0, 0.5)
	part(ci, xf, Ink.oval(lp, 5.6 * s, 4.6 * s, 12, 0.4), {"clair": Color.WHITE.lerp(lamp, 0.35), "ombre": lamp, "reflet": Color.WHITE}, 0.9, 1.0, 1.0)
	part(ci, xf, Ink.oval(c + Vector2(4, -1) * s, 6.0 * s, 5.0 * s, 12), body, 1.3, 1.0, 0.6)
	bead(ci, xf, c + Vector2(9, -2) * s, 1.6 * s)
	stroke(ci, xf, PackedVector2Array([c + Vector2(9, -5) * s, c + Vector2(13, -10) * s, c + Vector2(16, -10) * s]), 0.7, Color("4a3a30"))


## Grenouille assise (repos : respiration) ou en saut (lift 0 → 1 : élan, puis jambes tendues en l'air).
static func frog(ci: CanvasItem, xf: Transform2D, o: Dictionary, skin: Dictionary, belly: Dictionary, spot := Color.TRANSPARENT) -> void:
	var lift: float = o.get("lift", 0.0)
	var br := breath(o.get("t", 0.0))
	var air: bool = o.get("pose", "repos") == "saut"
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 22.0 * (1.0 - 0.3 * lift))
	var x2 := Transform2D(0.0, Vector2(0, -26.0 * lift if air else 0.0)) * xf
	var far := _dark(skin, 0.6)
	if air:
		limb(ci, x2, Vector2(-14, -12), Vector2(-30, -10 + 8 * lift), Vector2(-42, -2 + 14 * lift), 4.0, far["clair"])
		limb(ci, x2, Vector2(16, -10), Vector2(30, -4 - 4 * lift), Vector2(40, -8 + 4 * lift), 3.2, far["clair"])
	else:
		part(ci, x2, Ink.oval(Vector2(-12, -11), 13.0, 9.0, 16, -0.2), far, 1.4, 1.0, 0.4)
	var body := Ink.oval(Vector2(-2, -25 - 2 * lift), 25.0 + 6 * lift, 17.0 + 0.8 * br - 3 * lift, 28, -0.05 - 0.2 * lift)
	var head := Ink.oval(Vector2(18, -22 - 3 * lift), 14.0, 10.0, 22, -0.15 - 0.2 * lift)
	var sh := Geometry2D.merge_polygons(body, head)
	var shape: PackedVector2Array = sh[0] if not sh.is_empty() else body
	for i in shape.size():
		shape[i].y = minf(shape[i].y, -5.0)
	part(ci, x2, shape, skin, 1.9, 1.0, 0.9)
	blob(ci, x2, Vector2(13, -10), 14.0, 4.6 + br, belly, 0.0, 0.0, 0.3)
	if spot.a > 0.0:
		for q in [Vector2(-14, -34), Vector2(-4, -39), Vector2(6, -34), Vector2(-9, -28)]:
			blob(ci, x2, q, 2.6, 2.1, {"clair": spot, "ombre": spot.darkened(0.3), "reflet": spot.lightened(0.4)}, 0.0, 0.0, 0.3)
	for xx in [14.0, 23.0]:
		blob(ci, x2, Vector2(xx, -33 - 3 * lift), 4.8, 4.4, skin, 1.3, 0.0, 0.4)
		eye(ci, x2, Vector2(xx + 0.5, -33.5 - 3 * lift), 3.3, 0.0)
	stroke(ci, x2, PackedVector2Array([Vector2(12, -18), Vector2(23, -16.5), Vector2(31, -20)]), 1.0, skin["ombre"], false)
	if not air:
		limb(ci, x2, Vector2(16, -9), Vector2(22, -4), Vector2(26, 0), 3.6, skin["clair"])
