## Arme de l'Esprit masqué (piste A) : sa forme suit la forme d'attaque choisie (data/attack.json ›
## forms) et chaque modification d'attaque prise (› mods) y ajoute un ornement visible. Les ornements
## se cumulent, comme les modifications.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const K = preload("res://scripts/creature_art/heros/commun.gd")

const WOOD := Color("8a6a4a")
const WOOD_DARK := Color("5b4636")


## Dessine l'arme tenue en `hand` (repère de la créature). `top` : hauteur du sommet de la tête.
## c : {acc, gl, lv, t, u, p}. Renvoie rien : les ornements des modifications sont posés ici aussi.
static func draw(ci: CanvasItem, xf: Transform2D, hand: Vector2, top: float, forme: String, mods: Array, c: Dictionary) -> void:
	var p: float = c["p"]
	var t: float = c["t"]
	var reach := 1.0 + (0.22 if mods.has("portee") else 0.0)
	var big := 1.0 + (0.25 if mods.has("taille") else 0.0)
	var g: Dictionary
	match forme:
		"fouet": g = _fouet(ci, xf, hand, reach, big, c)
		"massue": g = _massue(ci, xf, hand, reach, big, c)
		"bourrasque": g = _eventail(ci, xf, hand, reach, big, c)
		"dard": g = _sarbacane(ci, xf, hand, reach, big, c)
		_: g = _baton(ci, xf, hand, top, forme, reach, big, c)
	_ornements(ci, xf, g, mods, c)


## Bâton (graine, échardes, ronces vives, spores, lames de vent, perles, rayon) : la tête change.
static func _baton(ci: CanvasItem, xf: Transform2D, hand: Vector2, top: float, forme: String, reach: float, big: float, c: Dictionary) -> Dictionary:
	var p: float = c["p"]
	var t: float = c["t"]
	var u: float = c["u"]
	var gl: Color = c["gl"]
	var h := (8.0 + 24.0 * p) * reach
	var a := Vector2(hand.x + 2.0, -2.0)
	var b := Vector2(hand.x - 1.0, top - h)
	var shaft := PackedVector2Array([a, hand, b])
	var col := WOOD
	if forme == "rayon":
		col = Color("d9c48a")
	Ink.brush(ci, xf, shaft, 5.0 * big, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, shaft, 3.0 * big, col, 1.0, 1.0)
	var tip := b + Vector2(0, -2.0 + sin(t * 2.6) * 1.0)
	match forme:
		"echarde":
			for j in 3:
				var ang := -PI * 0.5 + (j - 1) * 0.55
				Ink.part(ci, xf, Ink.thorn(b + Vector2(0, 3), ang, (9.0 + 5.0 * p) * big, 3.0, 0.1 * (j - 1)), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.9, 1.0, 0.0)
			K.seed(ci, xf * (b + Vector2(0, -1)), u, p, t, gl, 3.6 * big)
		"ronce_vive":
			_spiral(ci, xf, a.lerp(b, 0.15), b, 3, 2.2, Color("4e1a33"), true)
			for j in 5:
				var ang := -PI * 0.5 + (j - 2) * 0.6
				K.leaf(ci, xf, b, ang, (7.0 + 3.0 * p) * big, 5.0, {"clair": Color("d4485a"), "ombre": Color("7a1e30"), "reflet": Color("f2a0a8")}, 0.0, 0.9)
			K.seed(ci, xf * tip, u, p, t, gl, 3.8 * big)
		"spore_lobee":
			var cap := PackedVector2Array()
			for j in 17:
				var ang := PI + PI * j / 16.0
				cap.append(b + Vector2(cos(ang) * 11.0 * big, sin(ang) * 8.0 * big - 2.0))
			cap.append(b + Vector2(9.0 * big, 1.0))
			cap.append(b + Vector2(-9.0 * big, 1.0))
			Ink.part(ci, xf, cap, {"clair": Color("a07cc0"), "ombre": Color("4a3560"), "reflet": Color("e2d0f2")}, 1.6, 1.0, 0.6)
			for q: Vector2 in [Vector2(-4, -6), Vector2(3, -8), Vector2(6, -3)]:
				Ink.flat(ci, xf, Ink.oval(b + q * big, 1.6, 1.3, 8), Color("efe2f5"))
			K.seed(ci, xf * (b + Vector2(0, 4)), u, p, t, gl, 3.2 * big, 0.7)
			if not Ink.mono:
				for j in 4:
					var k := fposmod(t * 0.5 + j * 0.25, 1.0)
					ci.draw_circle(xf * (b + Vector2(-8.0 + j * 5.0, 4.0 + k * 12.0)), 1.2 * u, Color(Color("d6c0ff"), 0.8 * (1.0 - k)))
		"lame":
			for j in 2:
				var r := (10.0 + 6.0 * p) * big * (1.0 - j * 0.3)
				var cres := PackedVector2Array()
				for i in 13:
					var ang := -PI * 0.9 + PI * 0.8 * i / 12.0
					cres.append(b + Vector2(-2.0 + j * 6.0, -2.0) + Vector2(cos(ang), sin(ang)) * r)
				for i in range(12, -1, -1):
					var ang := -PI * 0.9 + PI * 0.8 * i / 12.0
					cres.append(b + Vector2(1.0 + j * 6.0, 1.0) + Vector2(cos(ang), sin(ang)) * r * 0.7)
				Ink.part(ci, xf, cres, {"clair": Color("e8f2fa"), "ombre": Color("8fb4e0"), "reflet": Color.WHITE}, 1.2, 1.0, 1.0)
			K.seed(ci, xf * (b + Vector2(0, 2)), u, p, t, gl, 3.4 * big, 0.6)
		"perle":
			for j in 4:
				var ang := -PI * 0.5 + (j - 1.5) * 0.7
				K.leaf(ci, xf, b, ang, (8.0 + 3.0 * p) * big, 6.0, {"clair": Art.ec("seve", "clair"), "ombre": Art.ec("seve"), "reflet": Color.WHITE}, 0.0, 0.9)
			for j in 3:
				K.seed(ci, xf * (b + Vector2(-4.0 + j * 4.0, -4.0 - (2.0 if j == 1 else 0.0))), u, p, t, gl, 2.6 * big, 0.5)
			if not Ink.mono:
				var k := fposmod(t * 0.7, 1.0)
				ci.draw_circle(xf * (b + Vector2(5, 3 + k * 18.0)), 1.6 * u, Color(Art.ec("seve", "clair"), 1.0 - k))
		"rayon":
			var cr := PackedVector2Array([b + Vector2(0, 2), b + Vector2(4.0, -6.0) * big, b + Vector2(0, -16.0) * big, b + Vector2(-4.0, -6.0) * big])
			if not Ink.mono:
				Ink.halo(ci, xf * (b + Vector2(0, -7) * big), 14.0 * u * big, Art.ec("lumiere"), 1.5)
				for j in 6:
					var ang := -PI * 0.5 + j * TAU / 6.0 + t * 0.3
					ci.draw_line(xf * (b + Vector2(0, -7) * big + Vector2.from_angle(ang) * 8.0 * big), xf * (b + Vector2(0, -7) * big + Vector2.from_angle(ang) * 14.0 * big), Color(Art.ec("lumiere", "clair"), 0.7), 1.2 * u, true)
			Ink.part(ci, xf, cr, {"clair": Color("fffde6"), "ombre": Color("d9b860"), "reflet": Color.WHITE}, 1.2, 1.0, 1.0)
			Ink.brush(ci, xf, PackedVector2Array([b + Vector2(0, 1), b + Vector2(0, -15.0) * big]), 0.8, Color("d9b860"))
		_:
			for j in 3:
				var ang := -PI * 0.5 + (j - 1) * 0.7
				Ink.brush(ci, xf, PackedVector2Array([b + Vector2(0, 4), b + Vector2.from_angle(ang) * 7.0 + Vector2(0, 2)]), 2.0, WOOD, 1.0, 0.2)
			K.seed(ci, xf * tip, u, p, t, gl, (4.6 + 1.0 * p) * big)
	return {"shaft": shaft, "tip": b, "dir": Vector2(0, -1), "base": a}


## Fouet de ronce : une poignée, puis une liane épineuse qui ondule devant lui.
static func _fouet(ci: CanvasItem, xf: Transform2D, hand: Vector2, reach: float, big: float, c: Dictionary) -> Dictionary:
	var p: float = c["p"]
	var t: float = c["t"]
	var l := (24.0 + 36.0 * p) * reach
	var pts := PackedVector2Array()
	for i in 12:
		var k := i / 11.0
		pts.append(hand + Vector2(l * 0.8 * k, -6.0 * k + sin(k * 6.0 - t * 4.0) * 6.0 * k + 26.0 * k * k))
	Ink.brush(ci, xf, pts, 5.2 * big, Ink.encre(), 1.0, 0.0)
	Ink.brush(ci, xf, pts, 3.2 * big, Color("6b2a40"), 1.0, 0.0)
	for i in [2, 4, 6, 8, 10]:
		var d: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
		Ink.part(ci, xf, Ink.thorn(pts[i], d.angle() - PI * 0.55 * (1.0 if i % 4 == 2 else -1.0), 4.0 * big, 2.0), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.7, 1.0, 0.0)
	var hd := PackedVector2Array([hand + Vector2(-4, 2), hand + Vector2(3, -1)])
	Ink.brush(ci, xf, hd, 5.0, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, hd, 3.0, WOOD, 1.0, 1.0)
	K.seed(ci, xf * (hand + Vector2(12, -20 + sin(t * 2.6))), c["u"], p, t, c["gl"], 3.6)
	return {"shaft": PackedVector2Array([pts[0], pts[5], pts[11]]), "tip": pts[11], "dir": (pts[11] - pts[10]).normalized(), "base": hand}


## Massue de bois : lourde, tenue vers le bas et l'avant, nœuds et mousse.
static func _massue(ci: CanvasItem, xf: Transform2D, hand: Vector2, reach: float, big: float, c: Dictionary) -> Dictionary:
	var p: float = c["p"]
	var l := (14.0 + 20.0 * p) * reach
	var d := Vector2.from_angle(-0.6)
	var b := hand + d * l
	var sh := PackedVector2Array([hand - d * 4.0, hand.lerp(b, 0.5), b])
	Ink.brush(ci, xf, sh, 6.0 * big, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, sh, 4.0 * big, WOOD, 1.0, 1.0)
	var r := (6.0 + 6.0 * p) * big
	Ink.part(ci, xf, Ink.lumpy(b + d * r * 0.6, r, r * 0.85, 20, 0.14, 5.0, 0.3), {"clair": Color("a27c56"), "ombre": Color("5e4430"), "reflet": Color("d8b88a")}, 2.0, 1.0, 0.5)
	for q: Vector2 in [Vector2(-0.3, -0.4), Vector2(0.35, 0.1), Vector2(-0.2, 0.45)]:
		Ink.flat(ci, xf, Ink.oval(b + d * r * 0.6 + q * r, 1.8, 1.4, 8), Color("5e4430"))
	for j in 4:
		Ink.brush(ci, xf, PackedVector2Array([b + d * r * 0.6 + Vector2(-r * 0.7 + j * r * 0.4, -r * 0.7), b + d * r * 0.6 + Vector2(-r * 0.6 + j * r * 0.4, -r * 0.95)]), 2.0, Art.FEUILLES_BUILD["racine"]["clair"], 1.0, 0.0)
	K.seed(ci, xf * (b + d * r * 0.6), c["u"], p, c["t"], c["gl"], 2.8 * big, 0.5)
	return {"shaft": sh, "tip": b + d * r * 1.4, "dir": d, "base": hand}


## Éventail de plumes (Bourrasque) : un demi-cercle de plumes tenu devant.
static func _eventail(ci: CanvasItem, xf: Transform2D, hand: Vector2, reach: float, big: float, c: Dictionary) -> Dictionary:
	var p: float = c["p"]
	var t: float = c["t"]
	var l := (10.0 + 14.0 * p) * reach * big
	var n := 5 + roundi(2.0 * p)
	for i in n:
		var ang := -PI * 0.15 - PI * 0.7 * i / (n - 1) + 0.05 * sin(t * 3.0 + i)
		K.leaf(ci, xf, hand, ang, l, 6.0 * big, {"clair": Color("e8f2fa") if i % 2 == 0 else Color("c8daea"), "ombre": Color("8fb4e0"), "reflet": Color.WHITE}, 0.0, 1.0)
	Ink.part(ci, xf, Ink.oval(hand, 3.0, 2.8, 10), {"clair": WOOD, "ombre": WOOD_DARK}, 1.0)
	K.seed(ci, xf * (hand + Vector2(-2, -l - 6)), c["u"], p, t, c["gl"], 3.4)
	return {"shaft": PackedVector2Array([hand, hand + Vector2(2, -l * 0.5), hand + Vector2(0, -l)]), "tip": hand + Vector2(4, -l), "dir": Vector2(0, -1), "base": hand}


## Sarbacane à dard fongique, tenue en biais vers l'avant.
static func _sarbacane(ci: CanvasItem, xf: Transform2D, hand: Vector2, reach: float, big: float, c: Dictionary) -> Dictionary:
	var p: float = c["p"]
	var l := (20.0 + 26.0 * p) * reach
	var d := Vector2.from_angle(-0.35)
	var a := hand - d * 8.0
	var b := hand + d * l
	var sh := PackedVector2Array([a, hand, b])
	Ink.brush(ci, xf, sh, 6.0 * big, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, sh, 4.0 * big, Color("c9b08a"), 1.0, 1.0)
	for k: float in [0.25, 0.55, 0.85]:
		Ink.brush(ci, xf, PackedVector2Array([a.lerp(b, k) + d.orthogonal() * 2.6, a.lerp(b, k) - d.orthogonal() * 2.6]), 1.2, WOOD_DARK)
	Ink.part(ci, xf, Ink.thorn(b, d.angle(), 7.0 * big, 3.0), {"clair": Color("b48ae6"), "ombre": Color("4a3560")}, 0.9, 1.0, 0.0)
	K.seed(ci, xf * (hand + Vector2(-8, -14 + sin(c["t"] * 2.6))), c["u"], p, c["t"], c["gl"], 3.4)
	return {"shaft": sh, "tip": b + d * 6.0, "dir": d, "base": a}


## Ornements des modifications d'attaque, autour de la pointe et le long du manche.
static func _ornements(ci: CanvasItem, xf: Transform2D, g: Dictionary, mods: Array, c: Dictionary) -> void:
	var t: float = c["t"]
	var u: float = c["u"]
	var acc: Color = c["acc"]
	var tip: Vector2 = g["tip"]
	var dir: Vector2 = g["dir"]
	var sh: PackedVector2Array = g["shaft"]
	var a: Vector2 = sh[0]
	var b: Vector2 = sh[sh.size() - 1]
	var nn := dir.orthogonal()
	if mods.has("enracine"):
		_spiral(ci, xf, a, a.lerp(b, 0.45), 2, 2.0, Art.ec("racine"), false)
	if mods.has("sangsue"):
		_spiral(ci, xf, a.lerp(b, 0.3), a.lerp(b, 0.8), 3, 1.6, Art.ec("saignement", "clair"), false)
	if mods.has("renforcee"):
		for k: float in [0.35, 0.65]:
			var q := a.lerp(b, k)
			var d := (b - a).normalized().orthogonal()
			Ink.brush(ci, xf, PackedVector2Array([q + d * 3.0, q - d * 3.0]), 3.2, Ink.encre(), 1.0, 1.0)
			Ink.brush(ci, xf, PackedVector2Array([q + d * 2.5, q - d * 2.5]), 1.8, Art.c("or"), 1.0, 1.0)
	if mods.has("aubier"):
		for k: float in [0.2, 0.5, 0.8]:
			var q := a.lerp(b, k)
			var d := (b - a).normalized().orthogonal()
			Ink.brush(ci, xf, PackedVector2Array([q + d * 2.0, q - d * 2.0]), 1.4, Color("e6d1a8"), 1.0, 1.0)
	if mods.has("rosee"):
		for k: float in [0.3, 0.55, 0.8]:
			Ink.part(ci, xf, Ink.oval(a.lerp(b, k) + (b - a).normalized().orthogonal() * 2.6, 1.6, 2.0, 10), {"clair": Color("e8fbff"), "ombre": Color("8fd4e6"), "reflet": Color.WHITE}, 0.7, 1.0, 1.0)
	if mods.has("elan") or mods.has("saut"):
		var q := a.lerp(b, 0.25)
		for s: float in [-1.0, 1.0]:
			K.leaf(ci, xf, q, (b - a).angle() + PI + s * 0.9, 7.0, 3.4, {"clair": Color("e8f2fa"), "ombre": Color("8fb4e0")}, 0.0, 0.8)
	if mods.has("trainee") and not Ink.mono:
		var rb := PackedVector2Array()
		for i in 7:
			var k := i / 6.0
			rb.append(b + Vector2(-14.0 * k - 4.0, 6.0 * k + sin(k * 5.0 - t * 4.0) * 3.0))
		Ink.brush(ci, xf, rb, 3.0, Color(acc, 0.85), 1.0, 0.0)
	if mods.has("fourche"):
		for s: float in [-1.0, 1.0]:
			Ink.part(ci, xf, Ink.thorn(tip - dir * 3.0 + nn * s * 3.0, (dir + nn * s * 0.6).angle(), 7.0, 2.4), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.8, 1.0, 0.0)
	if Ink.mono:
		return
	var n_orb := (3 if mods.has("volee") else 0) + (2 if mods.has("repetition") else 0)
	for i in n_orb:
		var ang := t * 2.0 + i * TAU / n_orb
		var q := tip + Vector2(cos(ang) * 11.0, sin(ang) * 5.0)
		K.seed(ci, xf * q, u, 0.0, t, c["gl"], 1.8, 0.35)
	if mods.has("ricochet"):
		for j in 2:
			var ring := Ink.oval(tip, 7.0 + j * 4.0, (7.0 + j * 4.0) * 0.4, 24, t * (0.5 + j))
			ring.append(ring[0])
			ci.draw_polyline(xf * ring, Color(acc, 0.7 - j * 0.25), 1.0 * u, true)
	if mods.has("eclat"):
		for j in 4:
			var ang := t * 1.3 + j * TAU / 4.0
			var q := tip + Vector2.from_angle(ang) * 9.0
			Ink.flat(ci, xf, Ink.thorn(q, ang, 4.0, 2.4), Color("f4ead0"), 0.6)
	if mods.has("saignement"):
		for j in 2:
			var k := fposmod(t * 0.8 + j * 0.5, 1.0)
			var q := tip + Vector2(2.0 + j * 3.0, 4.0 + k * 14.0)
			Ink.flat(ci, xf, Ink.leaf(q + Vector2(0, -3.5), PI * 0.5, 4.0, 2.6), Color(Art.ec("saignement", "clair"), 1.0 - k))
	if mods.has("poison"):
		for j in 3:
			var k := fposmod(t * 0.6 + j * 0.33, 1.0)
			var q := tip + Vector2(-4.0 + j * 4.0 + sin(t * 3.0 + j) * 2.0, -2.0 - k * 14.0)
			ci.draw_arc(xf * q, (1.4 + k * 1.6) * u, 0.0, TAU, 12, Color(Art.ec("poison", "clair"), 1.0 - k), 1.0 * u, true)
	if mods.has("incandescence"):
		Ink.halo(ci, xf * tip, 10.0 * u, Art.ec("cendre"), 1.4)
		Ink.sparks(ci, xf, tip, Vector2(0, -1), 4, t, 6.0, 1.0)
	if mods.has("eblouit") or mods.has("refraction"):
		for j in 3:
			var ang := t * 0.8 + j * 2.1
			var q := tip + Vector2.from_angle(ang) * 12.0
			var r := (2.4 + sin(t * 5.0 + j)) * u
			var w := xf * q
			ci.draw_line(w - Vector2(r, 0), w + Vector2(r, 0), Art.ec("lumiere", "clair"), 1.0 * u, true)
			ci.draw_line(w - Vector2(0, r), w + Vector2(0, r), Art.ec("lumiere", "clair"), 1.0 * u, true)
	if mods.has("bouffee"):
		for j in 3:
			ci.draw_circle(xf * (tip + Vector2(-5.0 + j * 5.0, -6.0 - (j % 2) * 3.0)), (3.0 + j % 2) * u, Color(Color("e2d0f2"), 0.55))
	if mods.has("repousse") or mods.has("secousse"):
		var base: Vector2 = g["base"]
		var k := fposmod(t * 0.8, 1.0)
		var ring := Ink.oval(Vector2(base.x, -1.0), 6.0 + 16.0 * k, (6.0 + 16.0 * k) * 0.4, 24)
		ring.append(ring[0])
		ci.draw_polyline(xf * ring, Color(acc, 0.8 * (1.0 - k)), 1.4 * u, true)


## Liane qui s'enroule autour d'un segment (épineuse ou non).
static func _spiral(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, turns: int, w: float, col: Color, thorns: bool) -> void:
	var d := (b - a)
	var nn := d.normalized().orthogonal()
	var pts := PackedVector2Array()
	var n := turns * 8
	for i in n + 1:
		var k := i / float(n)
		pts.append(a + d * k + nn * sin(k * TAU * turns) * 3.2)
	Ink.brush(ci, xf, pts, w + 1.6, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, pts, w, col, 1.0, 1.0)
	if thorns:
		for i in range(2, n, 4):
			Ink.part(ci, xf, Ink.thorn(pts[i], nn.angle() * (1.0 if i % 8 < 4 else -1.0), 3.0, 1.6), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.6, 1.0, 0.0)
