## Armes de l'Esprit masqué (piste A) : une vraie arme par forme d'attaque (data/attack.json › forms),
## chacune avec son geste. Chaque modification d'attaque prise (› mods) ajoute un ornement visible
## sur l'arme ; les ornements se cumulent, comme les modifications.
##   graine       Graines           fronde de bois : il tend l'élastique, la graine part
##   echarde      Échardes          trois échardes d'os entre les doigts, lancées en éventail
##   fouet        Fouet             fouet de ronce : armé derrière la tête, claque devant
##   ronce_vive   Ronces vives      arc de ronce : il bande, une flèche-liane épineuse part
##   spore_lobee  Spores lobées     encensoir-champignon au bout d'une chaîne : balancé, il lobe une spore
##   dard         Dards fongiques   sarbacane : portée au masque, souffle, le dard part
##   lame         Lames de vent     deux faucilles de plume : il en lance une qui tournoie
##   bourrasque   Bourrasque        grand éventail de plumes : ouvert derrière, balayé devant, rafale
##   perle        Perles de sève    calice-lotus : les perles s'y rassemblent puis partent en chapelet
##   rayon        Rayon d'aube      prisme serti d'or : la lumière s'y concentre, puis un rayon
##   massue       Massue de bois    massue de racines : sur l'épaule, levée, abattue, onde au sol
##
## Animation : c["a"] de 0 à 1 parcourt une attaque (0 → 0,45 préparation, 0,45 → 0,6 coup,
## 0,6 → 1 retour) ; a < 0 : au repos. pose() donne la main ; draw() dessine l'arme et le projectile.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const K = preload("res://scripts/creature_art/heros/commun.gd")

const WOOD := Color("8a6a4a")
const WOOD_DARK := Color("5b4636")
const BONE := {"clair": Color("e6d2a8"), "ombre": Color("a8946a"), "reflet": Color.WHITE}
const FEATHER := {"clair": Color("e8f2fa"), "ombre": Color("8fb4e0"), "reflet": Color.WHITE}
const GOLD := {"clair": Color("e8c860"), "ombre": Color("8a6a24"), "reflet": Color("fff4c8")}
const CAP := {"clair": Color("a07cc0"), "ombre": Color("4a3560"), "reflet": Color("e2d0f2")}
## Formes d'attaque et modifications que ce fichier sait dessiner (vérifié contre data/attack.json
## par tests/heros_test.gd).
const FORMES := ["graine", "echarde", "fouet", "ronce_vive", "spore_lobee", "dard", "lame", "bourrasque", "perle", "rayon", "massue"]
const ORNEMENTS := ["fourche", "ricochet", "eclat", "saignement", "enracine", "trainee", "renforcee", "taille", "portee", "repetition", "volee", "poison", "saut", "bouffee", "elan", "repousse", "sangsue", "rosee", "eblouit", "refraction", "incandescence", "secousse", "aubier"]
## Arme tenue devant le corps (sinon derrière le bras).
const DEVANT := ["fouet", "massue", "bourrasque", "dard", "lame", "echarde"]


## Préparation (0 → 1), puis détente brusque (→ -0,35), puis retour à 0.
static func wind(a: float) -> float:
	if a < 0.0:
		return 0.0
	if a < 0.45:
		return smoothstep(0.0, 1.0, a / 0.45)
	if a < 0.55:
		return lerpf(1.0, -0.35, (a - 0.45) / 0.1)
	return lerpf(-0.35, 0.0, smoothstep(0.0, 1.0, (a - 0.55) / 0.45))


## Vol du projectile (0 → 1 après le coup ; -1 avant).
static func fly(a: float) -> float:
	return -1.0 if a < 0.5 else (a - 0.5) / 0.5


## Position de la main (repère de la créature) pour l'épaule `s`.
static func pose(forme: String, s: Vector2, top: float, p: float, a: float, t: float) -> Vector2:
	var w := wind(a)
	var idle := Vector2(0, sin(t * 2.0) * 0.8)
	match forme:
		"graine", "ronce_vive":
			return s + Vector2(15.0 + 2.0 * p, 3.0 - 4.0 * maxf(w, 0.0)) + idle
		"echarde", "lame":
			return s + Vector2(10.0, 8.0).rotated(-2.2 * maxf(w, 0.0) + 0.5 * minf(w, 0.0)) + idle
		"fouet":
			return s + Vector2(11.0, 8.0).rotated(-2.6 * maxf(w, 0.0) + 0.6 * minf(w, 0.0)) + idle
		"spore_lobee":
			return s + Vector2(12.0, 6.0).rotated(-0.6 * minf(w, 0.0) + 0.5 * maxf(w, 0.0)) + idle
		"dard":
			return s.lerp(Vector2(s.x + 6.0, top - 4.0), maxf(w, 0.0) if a < 0.6 else maxf(1.0 - (a - 0.6) / 0.3, 0.0)) + Vector2(10.0, 6.0) + idle
		"bourrasque":
			return s + Vector2(12.0, 6.0).rotated(-2.0 * maxf(w, 0.0) + 0.7 * minf(w, 0.0)) + idle
		"perle", "rayon":
			return s + Vector2(14.0 + 4.0 * maxf(w, 0.0), 2.0 - 6.0 * maxf(w, 0.0)) + idle
		"massue":
			return s + Vector2(6.0, 6.0).rotated(-1.9 * maxf(w, 0.0) + 1.1 * minf(w, 0.0) * -1.0) + idle
	return s + Vector2(12.0, 8.0) + idle


## Dessine l'arme tenue en `hand`. c : {acc, gl, p, t, u, a, s (épaule), top}.
## Renvoie de quoi poser les ornements ensuite (ornaments()), par-dessus le bras.
static func draw(ci: CanvasItem, xf: Transform2D, hand: Vector2, forme: String, mods: Array, c: Dictionary) -> Dictionary:
	var sz: float = (0.75 + 0.25 * float(c["p"])) * (1.25 if mods.has("taille") else 1.0)
	var reach := 1.22 if mods.has("portee") else 1.0
	# L'arme est dessinée grande (lisible à l'écran) : tout son repère est agrandi autour de la main.
	var kx := 1.6
	xf = xf * Transform2D(0.0, Vector2(kx, kx), 0.0, hand * (1.0 - kx))
	c = c.duplicate()
	c["u"] = float(c["u"]) * kx
	c["gy"] = hand.y + (-1.0 - hand.y) / kx
	var g: Dictionary
	match forme:
		"echarde": g = _echardes(ci, xf, hand, sz, reach, c)
		"fouet": g = _fouet(ci, xf, hand, sz, reach, c)
		"ronce_vive": g = _arc(ci, xf, hand, sz, reach, c)
		"spore_lobee": g = _encensoir(ci, xf, hand, sz, reach, c)
		"dard": g = _sarbacane(ci, xf, hand, sz, reach, c)
		"lame": g = _faucilles(ci, xf, hand, sz, reach, c)
		"bourrasque": g = _eventail(ci, xf, hand, sz, reach, c)
		"perle": g = _calice(ci, xf, hand, sz, reach, c)
		"rayon": g = _prisme(ci, xf, hand, sz, reach, c)
		"massue": g = _massue(ci, xf, hand, sz, reach, c)
		_: g = _fronde(ci, xf, hand, sz, reach, c)
	return {"g": g, "xf": xf, "c": c, "mods": mods}


## Ornements des modifications, dessinés après l'arme et le bras (jamais cachés par le corps).
static func ornaments(ci: CanvasItem, r: Dictionary) -> void:
	_ornements(ci, r["xf"], r["g"], r["mods"], r["c"])


static func _stick(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, w: float, col: Color) -> void:
	Ink.brush(ci, xf, pts, w + 2.2, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, pts, w, col, 1.0, 1.0)


static func _speed(ci: CanvasItem, xf: Transform2D, q: Vector2, d: Vector2, l: float, col: Color, k: float) -> void:
	if Ink.mono or k <= 0.0:
		return
	var u := xf.get_scale().abs().x
	for j in 3:
		var o := d.orthogonal() * (j - 1) * 3.0
		ci.draw_line(xf * (q + o - d * 3.0), xf * (q + o - d * (3.0 + l * (1.0 - absf(j - 1) * 0.4))), Color(col, 0.6 * k), 1.2 * u, true)


## Fronde : fourche de bois, élastique de liane, graine dans la poche.
static func _fronde(ci: CanvasItem, xf: Transform2D, h: Vector2, sz: float, reach: float, c: Dictionary) -> Dictionary:
	var a: float = c["a"]
	var w := wind(a)
	var fk := h + Vector2(0, -9.0 * sz)
	_stick(ci, xf, PackedVector2Array([h + Vector2(-1, 4) * sz, h, fk]), 3.4 * sz, WOOD)
	var l := fk + Vector2(-3.0, -7.0) * sz
	var r := fk + Vector2(4.0, -8.0) * sz
	_stick(ci, xf, PackedVector2Array([fk, fk + Vector2(-2.5, -3.5) * sz, l]), 2.6 * sz, WOOD)
	_stick(ci, xf, PackedVector2Array([fk, fk + Vector2(2.5, -4.0) * sz, r]), 2.6 * sz, WOOD)
	K.leaf(ci, xf, fk + Vector2(0, 2), -0.4, 6.0 * sz, 3.2, K.leaves("aucun"), 0.0, 0.8)
	var pouch := (l + r) * 0.5 + Vector2(-16.0 * maxf(w, 0.0) * sz + 3.0 * minf(w, 0.0), 1.0)
	Ink.brush(ci, xf, PackedVector2Array([l, pouch, r]), 1.4, Color("6fae58"), 1.0, 1.0)
	Ink.part(ci, xf, Ink.oval(pouch, 2.4, 3.0, 10), {"clair": WOOD_DARK, "ombre": Color("3f3026")}, 0.8)
	var f := fly(a)
	var seed_at := pouch if f < 0.0 else (l + r) * 0.5 + Vector2(70.0 * f * reach, -3.0 - 6.0 * sin(PI * f))
	K.seed(ci, xf * seed_at, c["u"], c["p"], c["t"], c["gl"], 3.0 * sz, 0.7)
	if f >= 0.0:
		_speed(ci, xf, seed_at, Vector2(1, 0), 14.0, c["gl"], 1.0 - f)
	return {"shaft": PackedVector2Array([h + Vector2(0, 4), fk]), "tip": seed_at, "dir": Vector2(1, 0), "base": h}


## Échardes : trois lames d'os entre les doigts, lancées en éventail.
static func _echardes(ci: CanvasItem, xf: Transform2D, h: Vector2, sz: float, reach: float, c: Dictionary) -> Dictionary:
	var a: float = c["a"]
	var w := wind(a)
	var f := fly(a)
	var base_a := -0.5 - 2.0 * maxf(w, 0.0) + 0.4 * minf(w, 0.0)
	var tip := h
	for j in 3:
		var ang := base_a + (j - 1) * 0.35
		if f >= 0.0:
			var q := h + Vector2(8.0 + 64.0 * f * reach, (j - 1) * (4.0 + 14.0 * f) - 4.0)
			Ink.part(ci, xf, Ink.thorn(q, (j - 1) * 0.15 * f, 11.0 * sz, 3.6), BONE, 1.0, 1.0, 1.0)
			_speed(ci, xf, q, Vector2(1, 0), 10.0, Color.WHITE, 1.0 - f)
			tip = q
		else:
			var q := h + Vector2.from_angle(ang) * 2.0
			Ink.part(ci, xf, Ink.thorn(q, ang, 12.0 * sz, 3.6), BONE, 1.0, 1.0, 1.0)
			Ink.brush(ci, xf, PackedVector2Array([q, q + Vector2.from_angle(ang) * 3.0]), 2.4, Art.FEUILLES_BUILD["ronce"]["accent"], 1.0, 1.0)
			tip = q + Vector2.from_angle(ang) * 12.0 * sz
	if f >= 0.0 and f < 0.6:
		# Il en tient déjà une autre.
		Ink.part(ci, xf, Ink.thorn(h, -0.6, 10.0 * sz, 3.2), BONE, 1.0, 1.0, 1.0)
	return {"shaft": PackedVector2Array([h, h + Vector2.from_angle(base_a) * 10.0]), "tip": tip, "dir": Vector2.from_angle(base_a), "base": h}


## Fouet de ronce : poignée, lanière épineuse qui suit le geste, claquement au bout.
static func _fouet(ci: CanvasItem, xf: Transform2D, h: Vector2, sz: float, reach: float, c: Dictionary) -> Dictionary:
	var a: float = c["a"]
	var t: float = c["t"]
	var w := wind(a)
	var l := (34.0 + 22.0 * float(c["p"])) * reach
	var pts := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		var rest := Vector2(4.0 * k + sin(k * 5.0 - t * 2.0) * 2.0 * k, l * 0.55 * k)
		var back := Vector2(-l * 0.7 * k, -l * 0.15 * k + l * 0.3 * k * k)
		var lash := Vector2(l * k, -l * 0.05 * k + sin(k * 9.0 - a * 30.0) * 3.0 * k)
		var q: Vector2
		if a < 0.0:
			q = rest
		elif w >= 0.0 and a < 0.45:
			q = rest.lerp(back, w)
		elif a < 0.6:
			q = back.lerp(lash, clampf((a - 0.45) / 0.08 - k * 0.6, 0.0, 1.0))
		else:
			q = lash.lerp(rest, smoothstep(0.0, 1.0, (a - 0.6) / 0.4 - k * 0.3))
		pts.append(h + q)
	Ink.brush(ci, xf, pts, 5.0 * sz, Ink.encre(), 1.0, 0.0)
	Ink.brush(ci, xf, pts, 3.0 * sz, Color("6b2a40"), 1.0, 0.0)
	for i in [2, 4, 6, 8, 10]:
		var d: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
		Ink.part(ci, xf, Ink.thorn(pts[i], d.angle() - PI * 0.55 * (1.0 if i % 4 == 2 else -1.0), 4.0 * sz, 2.0), BONE, 0.7, 1.0, 0.0)
	_stick(ci, xf, PackedVector2Array([h + Vector2(-3, 3), h + Vector2(2, -2)]), 3.6 * sz, WOOD)
	if a >= 0.47 and a < 0.62 and not Ink.mono:
		# Claquement.
		var q: Vector2 = pts[12]
		Ink.halo(ci, xf * q, 10.0 * float(c["u"]), Art.FEUILLES_BUILD["ronce"]["lueur"], 1.6)
		for j in 6:
			var d := Vector2.from_angle(j * TAU / 6.0)
			ci.draw_line(xf * (q + d * 3.0), xf * (q + d * 8.0), Color.WHITE, 1.2 * float(c["u"]), true)
	return {"shaft": PackedVector2Array([pts[0], pts[6], pts[12]]), "tip": pts[12], "dir": (pts[12] - pts[11]).normalized(), "base": h}


## Arc de ronce : il bande l'arc, la flèche-liane épineuse part en ondulant.
static func _arc(ci: CanvasItem, xf: Transform2D, h: Vector2, sz: float, reach: float, c: Dictionary) -> Dictionary:
	var a: float = c["a"]
	var w := maxf(wind(a), 0.0) if a < 0.5 else 0.0
	var bh := 16.0 * sz
	var top := h + Vector2(-3.0 - 2.0 * w, -bh)
	var bot := h + Vector2(-3.0 - 2.0 * w, bh)
	var limb := PackedVector2Array([top, h + Vector2(2.0, -bh * 0.5), h + Vector2(3.0, 0), h + Vector2(2.0, bh * 0.5), bot])
	Ink.brush(ci, xf, limb, 5.4 * sz, Ink.encre(), 0.3, 0.3)
	Ink.brush(ci, xf, limb, 3.4 * sz, Color("6b2a40"), 0.3, 0.3)
	for q: Vector2 in [limb[1], limb[3]]:
		Ink.part(ci, xf, Ink.thorn(q, 0.0, 4.0, 2.0), BONE, 0.6, 1.0, 0.0)
	K.leaf(ci, xf, top, -2.0, 6.0, 3.4, K.leaves("ronce"), 0.0, 0.8)
	var nock := h + Vector2(-2.0 - 14.0 * w * sz, 0)
	Ink.brush(ci, xf, PackedVector2Array([top, nock, bot]), 1.0, Color("f2e8d0"), 1.0, 1.0)
	var f := fly(a)
	var tail := nock if f < 0.0 else h + Vector2(70.0 * f * reach - 10.0, -2.0 * sin(PI * f))
	var head := tail + Vector2(20.0 * sz, 0)
	if a < 0.0 or (a < 0.5 and w < 0.05):
		tail = h + Vector2(-6, 0)
		head = tail + Vector2(18.0 * sz, 0)
	var arrow := PackedVector2Array()
	for i in 7:
		var k := i / 6.0
		arrow.append(tail.lerp(head, k) + Vector2(0, sin(k * 8.0 + float(c["t"]) * 12.0) * (1.6 if f >= 0.0 else 0.4)))
	Ink.brush(ci, xf, arrow, 3.2, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, arrow, 1.8, Color("6b2a40"), 1.0, 1.0)
	Ink.part(ci, xf, Ink.thorn(head, 0.0, 6.0 * sz, 3.4), BONE, 0.8, 1.0, 0.6)
	if f >= 0.0:
		_speed(ci, xf, tail, Vector2(1, 0), 12.0, Art.FEUILLES_BUILD["ronce"]["accent"], 1.0 - f)
	return {"shaft": limb, "tip": head, "dir": Vector2(1, 0), "base": bot}


## Encensoir-champignon au bout d'une chaîne : balancé, il lobe une boule de spores.
static func _encensoir(ci: CanvasItem, xf: Transform2D, h: Vector2, sz: float, reach: float, c: Dictionary) -> Dictionary:
	var a: float = c["a"]
	var t: float = c["t"]
	var w := wind(a)
	var ang := PI * 0.5 + 0.25 * sin(t * 2.2) if a < 0.0 else PI * 0.5 + 1.3 * maxf(w, 0.0) - 2.0 * minf(w, 0.0) * -1.0
	if a >= 0.45 and a < 0.6:
		ang = lerpf(PI * 0.5 + 1.3, -0.2, (a - 0.45) / 0.15)
	elif a >= 0.6:
		ang = lerpf(-0.2, PI * 0.5, smoothstep(0.0, 1.0, (a - 0.6) / 0.4))
	var cl := 14.0 * sz * reach
	var bob := h + Vector2.from_angle(ang) * cl
	var chain := PackedVector2Array()
	for i in 6:
		chain.append(h.lerp(bob, i / 5.0))
	for q in chain:
		Ink.part(ci, xf, Ink.oval(q, 1.4, 1.1, 8), GOLD, 0.6, 1.0, 0.0)
	var cap := PackedVector2Array()
	for i in 13:
		var aa := PI + PI * i / 12.0
		cap.append(bob + Vector2(cos(aa) * 8.0 * sz, sin(aa) * 6.0 * sz))
	var stem := Ink.oval(bob + Vector2(0, 4.0 * sz), 4.0 * sz, 5.0 * sz, 14)
	Ink.part(ci, xf, stem, {"clair": Color("efe2f5"), "ombre": Color("b8a4c8")}, 1.2, 1.0, 0.4)
	Ink.part(ci, xf, cap, CAP, 1.4, 1.0, 0.6)
	for q: Vector2 in [Vector2(-3, -4), Vector2(2, -5), Vector2(5, -2)]:
		Ink.flat(ci, xf, Ink.oval(bob + q * sz, 1.3, 1.1, 8), Color("efe2f5"))
	if not Ink.mono:
		Ink.halo(ci, xf * (bob + Vector2(0, 4)), 7.0 * float(c["u"]), Art.ec("poison"), 0.8 + maxf(w, 0.0))
		for j in 3:
			var k := fposmod(t * 0.6 + j * 0.33, 1.0)
			ci.draw_circle(xf * (bob + Vector2(-3.0 + j * 3.0, 8.0 + k * 6.0)), (1.0 + k) * float(c["u"]), Color(Art.ec("poison", "clair"), 0.7 * (1.0 - k)))
	var f := fly(a)
	var tip := bob
	if f >= 0.0:
		var q := bob + Vector2(60.0 * f * reach, -30.0 * sin(PI * f) + 20.0 * f)
		Ink.part(ci, xf, Ink.lumpy(q, 4.4 * sz, 4.0 * sz, 14, 0.15, 6.0, f * 5.0), {"clair": Art.ec("poison"), "ombre": Art.ec("poison", "sombre"), "reflet": Art.ec("poison", "clair")}, 1.0, 1.0, 0.6)
		if not Ink.mono:
			Ink.halo(ci, xf * q, 8.0 * float(c["u"]), Art.ec("poison"), 1.0)
		tip = q
	return {"shaft": chain, "tip": tip, "dir": Vector2(1, 0), "base": h}


## Sarbacane : tenue en biais, portée au masque, souffle : le dard fongique part.
static func _sarbacane(ci: CanvasItem, xf: Transform2D, h: Vector2, sz: float, reach: float, c: Dictionary) -> Dictionary:
	var a: float = c["a"]
	var w := wind(a)
	var aim := lerpf(0.9, 0.0, clampf(maxf(w, 0.0) * 1.4, 0.0, 1.0)) if a < 0.6 else lerpf(0.0, 0.9, smoothstep(0.0, 1.0, (a - 0.6) / 0.4))
	if a < 0.0:
		aim = 0.9
	var d := Vector2.from_angle(aim)
	var l := (26.0 + 8.0 * float(c["p"])) * reach
	var a0 := h - d * 10.0
	var b := h + d * (l - 10.0)
	_stick(ci, xf, PackedVector2Array([a0, h, b]), 3.6 * sz, Color("c9b08a"))
	for k: float in [0.2, 0.5, 0.8]:
		var q := a0.lerp(b, k)
		Ink.brush(ci, xf, PackedVector2Array([q + d.orthogonal() * 2.6, q - d.orthogonal() * 2.6]), 1.2, WOOD_DARK)
	K.leaf(ci, xf, a0.lerp(b, 0.5), aim + 1.8, 6.0, 3.0, K.leaves("spore"), 0.0, 0.8)
	var f := fly(a)
	var tip := b
	if f < 0.0:
		Ink.part(ci, xf, Ink.thorn(b - d * 2.0, aim, 5.0 * sz, 2.4), CAP, 0.7, 1.0, 0.0)
	else:
		var q := b + Vector2(80.0 * f * reach, 0)
		Ink.part(ci, xf, Ink.thorn(q, 0.0, 7.0 * sz, 2.6), CAP, 0.8, 1.0, 0.4)
		_speed(ci, xf, q, Vector2(1, 0), 14.0, Art.ec("poison", "clair"), 1.0 - f)
		if f < 0.3 and not Ink.mono:
			ci.draw_circle(xf * (b + d * 3.0), 4.0 * (1.0 + f * 3.0) * float(c["u"]), Color(Color.WHITE, 0.6 * (1.0 - f / 0.3)))
		tip = q
	return {"shaft": PackedVector2Array([a0, b]), "tip": tip, "dir": d, "base": a0}


## Faucilles de plume : deux lames en croissant ; il en lance une qui tournoie et revient.
static func _faucilles(ci: CanvasItem, xf: Transform2D, h: Vector2, sz: float, reach: float, c: Dictionary) -> Dictionary:
	var a: float = c["a"]
	var f := fly(a)
	var w := wind(a)
	var held := -0.8 - 1.6 * maxf(w, 0.0)
	_sickle(ci, xf, h, held, sz, 1.0)
	var tip := h + Vector2.from_angle(held) * 12.0 * sz
	if f >= 0.0:
		var q := h + Vector2(72.0 * sin(PI * f) * reach, -6.0 * sin(PI * f))
		_sickle(ci, xf, q, float(c["t"]) * 20.0 + f * 30.0, sz, 1.0)
		if not Ink.mono:
			var ring := Ink.oval(q, 12.0 * sz, 12.0 * sz, 24)
			ring.append(ring[0])
			ci.draw_polyline(xf * ring, Color(FEATHER["ombre"], 0.5), 1.0 * float(c["u"]), true)
		tip = q
	else:
		_sickle(ci, xf, h + Vector2(-2, 3), held + 0.6, sz * 0.9, 0.8)
	return {"shaft": PackedVector2Array([h, h + Vector2.from_angle(held) * 10.0]), "tip": tip, "dir": Vector2(1, 0), "base": h}


static func _sickle(ci: CanvasItem, xf: Transform2D, h: Vector2, ang: float, sz: float, k: float) -> void:
	var r := 11.0 * sz
	var pts := PackedVector2Array()
	for i in 13:
		var aa := ang - 0.2 + PI * 0.9 * i / 12.0
		pts.append(h + Vector2.from_angle(ang) * r * 0.2 + Vector2.from_angle(aa) * r)
	for i in range(12, -1, -1):
		var aa := ang - 0.2 + PI * 0.9 * i / 12.0
		pts.append(h + Vector2.from_angle(ang) * r * 0.45 + Vector2.from_angle(aa) * r * 0.62)
	Ink.part(ci, xf, pts, {"clair": Color(FEATHER["clair"], k), "ombre": FEATHER["ombre"], "reflet": Color.WHITE}, 1.2, 1.0, 1.0)
	for i in [3, 6, 9]:
		var aa: float = ang - 0.2 + PI * 0.9 * i / 12.0
		Ink.brush(ci, xf, PackedVector2Array([h + Vector2.from_angle(ang) * r * 0.35 + Vector2.from_angle(aa) * r * 0.7, h + Vector2.from_angle(ang) * r * 0.2 + Vector2.from_angle(aa) * r * 0.95]), 0.8, FEATHER["ombre"])
	_stick(ci, xf, PackedVector2Array([h - Vector2.from_angle(ang) * 3.0, h + Vector2.from_angle(ang) * 3.0]), 2.6, WOOD)


## Grand éventail de plumes : fermé au repos, ouvert derrière, balayé devant avec une rafale.
static func _eventail(ci: CanvasItem, xf: Transform2D, h: Vector2, sz: float, reach: float, c: Dictionary) -> Dictionary:
	var a: float = c["a"]
	var t: float = c["t"]
	var w := wind(a)
	var open := 0.25 + 0.75 * clampf(absf(w) * 1.6 + (0.0 if a < 0.0 else 0.3), 0.0, 1.0)
	var axis := -PI * 0.5 - 1.4 * maxf(w, 0.0) + 1.2 * -minf(w, 0.0) * 2.0
	if a >= 0.6:
		axis = lerpf(-PI * 0.5 + 0.84, -PI * 0.5, smoothstep(0.0, 1.0, (a - 0.6) / 0.4))
	var l := (16.0 + 6.0 * float(c["p"])) * sz * reach
	var n := 7
	for i in n:
		var aa := axis + (i - (n - 1) * 0.5) * 0.28 * open + 0.03 * sin(t * 3.0 + i)
		K.leaf(ci, xf, h, aa, l, 6.0 * sz, {"clair": FEATHER["clair"] if i % 2 == 0 else Color("c8daea"), "ombre": FEATHER["ombre"], "reflet": Color.WHITE}, 0.0, 1.0)
		Ink.flat(ci, xf, Ink.oval(h + Vector2.from_angle(aa) * l * 0.82, 1.4, 1.4, 8), Art.FEUILLES_BUILD["vent"]["accent"])
	Ink.part(ci, xf, Ink.oval(h, 2.8, 2.6, 10), GOLD, 1.0)
	var tip := h + Vector2.from_angle(axis) * l
	if a >= 0.45 and a < 1.0 and not Ink.mono:
		var k := clampf((a - 0.45) / 0.55, 0.0, 1.0)
		for j in 3:
			var r := 16.0 + 50.0 * k * reach + j * 7.0
			var arc := PackedVector2Array()
			for i in 9:
				var aa := -0.55 + 1.1 * i / 8.0
				arc.append(h + Vector2(4.0, -6.0) + Vector2.from_angle(aa) * r)
			ci.draw_polyline(xf * arc, Color(FEATHER["clair"], 0.8 * (1.0 - k)), (2.2 - j * 0.5) * float(c["u"]), true)
		tip = h + Vector2(20.0 + 50.0 * k, -6.0)
	return {"shaft": PackedVector2Array([h, tip]), "tip": tip, "dir": Vector2.from_angle(axis), "base": h}


## Calice-lotus : des perles de sève s'y rassemblent, puis partent en chapelet.
static func _calice(ci: CanvasItem, xf: Transform2D, h: Vector2, sz: float, reach: float, c: Dictionary) -> Dictionary:
	var a: float = c["a"]
	var t: float = c["t"]
	var w := maxf(wind(a), 0.0)
	var u: float = c["u"]
	var cup := h + Vector2(2, -12.0 * sz)
	for j in 5:
		var aa := -PI * 0.5 + (j - 2) * 0.5
		K.leaf(ci, xf, cup + Vector2(0, 2), aa, 9.0 * sz, 6.0, {"clair": Art.ec("seve", "clair"), "ombre": Art.ec("seve"), "reflet": Color.WHITE}, 0.0, 0.9)
	_stick(ci, xf, PackedVector2Array([h + Vector2(0, 12), h, cup + Vector2(0, 2)]), 2.6, Art.FEUILLES_BUILD["seve"]["ombre"])
	K.leaf(ci, xf, h + Vector2(0, 6), 0.6, 6.0, 3.4, K.leaves("seve"), 0.0, 0.8)
	var f := fly(a)
	var n := 3
	for i in n:
		var q: Vector2
		var ang := t * (2.0 + 3.0 * w) + i * TAU / n
		var rr := (9.0 - 6.0 * w) * sz
		q = cup + Vector2(cos(ang) * rr, -8.0 * sz + sin(ang) * rr * 0.5)
		if f >= 0.0:
			var fi := clampf(f * 1.4 - i * 0.18, 0.0, 1.0)
			if fi > 0.0:
				q = cup + Vector2(10.0 + 72.0 * fi * reach, -8.0 - sin(fi * 9.0 + i) * 3.0)
				_speed(ci, xf, q, Vector2(1, 0), 8.0, Art.ec("seve", "clair"), 1.0 - fi)
		K.seed(ci, xf * q, u, 0.0, t, c["gl"], 2.8 * sz, 0.5)
	if not Ink.mono and w > 0.0:
		Ink.halo(ci, xf * (cup + Vector2(0, -8)), 12.0 * u * w, Art.ec("seve"), 1.5 * w)
	return {"shaft": PackedVector2Array([h + Vector2(0, 12), cup]), "tip": cup + Vector2(0, -8), "dir": Vector2(0, -1), "base": h}


## Prisme serti d'or : la lumière s'y concentre, puis un rayon part droit devant.
static func _prisme(ci: CanvasItem, xf: Transform2D, h: Vector2, sz: float, reach: float, c: Dictionary) -> Dictionary:
	var a: float = c["a"]
	var t: float = c["t"]
	var u: float = c["u"]
	var w := maxf(wind(a), 0.0)
	var q := h + Vector2(4.0, -14.0 * sz)
	var tri := PackedVector2Array([q + Vector2(0, -9.0) * sz, q + Vector2(7.0, 5.0) * sz, q + Vector2(-7.0, 5.0) * sz])
	var frame := PackedVector2Array([q + Vector2(0, -12.0) * sz, q + Vector2(10.0, 7.0) * sz, q + Vector2(-10.0, 7.0) * sz])
	Ink.part(ci, xf, frame, GOLD, 1.4, 1.0, 0.6)
	Ink.part(ci, xf, tri, {"clair": Color("fffde6"), "ombre": Color("cfe4f0"), "reflet": Color.WHITE}, 0.8, 1.0, 1.0)
	_stick(ci, xf, PackedVector2Array([h + Vector2(0, 12), h, q + Vector2(0, 6) * sz]), 2.8, GOLD["ombre"])
	if not Ink.mono:
		Ink.halo(ci, xf * q, (8.0 + 12.0 * w) * u * sz, Art.ec("lumiere"), 0.8 + 1.6 * w)
		for j in 3:
			var ang := t * 3.0 + j * TAU / 3.0
			ci.draw_circle(xf * (q + Vector2.from_angle(ang) * (14.0 - 10.0 * w)), 1.2 * u, Color(Art.ec("lumiere", "clair"), 0.5 + 0.5 * w))
	var beam := 0.0
	if a >= 0.45 and a < 0.85:
		beam = 1.0 if a < 0.7 else 1.0 - (a - 0.7) / 0.15
	var tip := q
	if beam > 0.0 and not Ink.mono:
		var l := 110.0 * reach
		var e := q + Vector2(l, 0)
		var ww := (6.0 + 3.0 * sin(t * 30.0)) * sz * beam
		Ink._poly(ci, xf * PackedVector2Array([q + Vector2(0, -ww), e + Vector2(0, -ww * 1.4), e + Vector2(0, ww * 1.4), q + Vector2(0, ww)]), Color(Art.ec("lumiere"), 0.35 * beam))
		ci.draw_line(xf * q, xf * e, Color(Art.ec("lumiere", "clair"), 0.95 * beam), 3.0 * u * sz * beam, true)
		Ink.halo(ci, xf * e, 10.0 * u, Art.ec("lumiere"), beam * 1.5)
		tip = e
	return {"shaft": PackedVector2Array([h + Vector2(0, 12), q]), "tip": tip, "dir": Vector2(1, 0), "base": h}


## Massue de racines : sur l'épaule au repos, levée, abattue devant ; onde et éclats au sol.
static func _massue(ci: CanvasItem, xf: Transform2D, h: Vector2, sz: float, reach: float, c: Dictionary) -> Dictionary:
	var a: float = c["a"]
	var t: float = c["t"]
	var w := wind(a)
	var ang := -2.3
	if a >= 0.0:
		if a < 0.45:
			ang = lerpf(-2.3, -2.9, w)
		elif a < 0.55:
			ang = lerpf(-2.9, 0.95, (a - 0.45) / 0.1)
		elif a < 0.75:
			ang = 0.95
		else:
			ang = lerpf(0.95, -2.3, smoothstep(0.0, 1.0, (a - 0.75) / 0.25))
	var d := Vector2.from_angle(ang)
	var l := (16.0 + 10.0 * float(c["p"])) * reach
	var b := h + d * l
	_stick(ci, xf, PackedVector2Array([h - d * 4.0, h.lerp(b, 0.5), b]), 4.4 * sz, WOOD)
	var r := 9.0 * sz
	var head := b + d * r * 0.6
	Ink.part(ci, xf, Ink.lumpy(head, r, r * 0.85, 20, 0.14, 5.0, 0.3), {"clair": Color("a27c56"), "ombre": Color("5e4430"), "reflet": Color("d8b88a")}, 2.0, 1.0, 0.5)
	for q: Vector2 in [Vector2(-0.3, -0.4), Vector2(0.35, 0.1), Vector2(-0.2, 0.45)]:
		Ink.flat(ci, xf, Ink.oval(head + q * r, 1.8, 1.4, 8), Color("5e4430"))
	for j in 3:
		var aa := ang + (j - 1) * 0.6
		Ink.brush(ci, xf, PackedVector2Array([head + Vector2.from_angle(aa) * r * 0.8, head + Vector2.from_angle(aa) * r * 1.25]), 2.0, Art.FEUILLES_BUILD["racine"]["clair"], 1.0, 0.0)
	Ink.brush(ci, xf, PackedVector2Array([h.lerp(b, 0.2), h.lerp(b, 0.7)]), 1.4, Art.ec("racine"), 1.0, 1.0)
	if a >= 0.53 and a < 0.95 and not Ink.mono:
		var k := (a - 0.53) / 0.42
		var g := Vector2(head.x, float(c["gy"]))
		var ring := Ink.oval(g, 6.0 + 40.0 * k, (6.0 + 40.0 * k) * 0.4, 32)
		ring.append(ring[0])
		ci.draw_polyline(xf * ring, Color(Art.FEUILLES_BUILD["racine"]["accent"], 0.9 * (1.0 - k)), 2.4 * float(c["u"]), true)
		for j in 5:
			var dd := Vector2.from_angle(-PI * (0.15 + 0.7 * j / 4.0))
			var q := g + dd * (6.0 + 22.0 * k) + Vector2(0, 30.0 * k * k)
			Ink.flat(ci, xf, Ink.lumpy(q, 2.0, 1.6, 8, 0.2, 3.0, j), Color(Color("8a7a5e"), 1.0 - k))
	return {"shaft": PackedVector2Array([h - d * 4.0, b]), "tip": head, "dir": d, "base": h}


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
	if mods.has("elan"):
		var q := a.lerp(b, 0.25)
		for s: float in [-1.0, 1.0]:
			K.leaf(ci, xf, q, (b - a).angle() + PI + s * 0.9, 7.0, 3.4, {"clair": Color("e8f2fa"), "ombre": Color("8fb4e0")}, 0.0, 0.8)
	if mods.has("saut"):
		# Ressort de vrille enroulé près de la main : le bond.
		var q0 := a.lerp(b, 0.12)
		var pts := PackedVector2Array()
		for i in 13:
			var k := i / 12.0
			pts.append(q0 + Vector2(-6.0 + sin(k * TAU * 2.0) * 3.0, -6.0 * k))
		Ink.brush(ci, xf, pts, 1.6, Color("6fae58"), 1.0, 1.0)
		K.leaf(ci, xf, pts[12], -PI * 0.5, 4.0, 2.6, K.leaves("aucun"), 0.0, 0.6)
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
			var ring := Ink.oval(tip, 11.0 + j * 5.0, (11.0 + j * 5.0) * 0.45, 24, t * (0.5 + j))
			ring.append(ring[0])
			ci.draw_polyline(xf * ring, Color(acc, 0.85 - j * 0.25), 1.5 * u, true)
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
	if mods.has("refraction"):
		# Éventail de rayons colorés : la lumière décomposée.
		var cols := [Color("ff7a7a"), Color("ffd84a"), Color("7ae08a"), Color("6ab4ff"), Color("c08aff")]
		for j in cols.size():
			var ang := -0.5 + j * 0.25
			ci.draw_line(xf * (tip + Vector2.from_angle(ang) * 4.0), xf * (tip + Vector2.from_angle(ang) * 13.0), Color(cols[j], 0.9), 1.1 * u, true)
	if mods.has("eblouit"):
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
	if mods.has("secousse"):
		# Fissures au sol, sous l'arme.
		var gb: Vector2 = g["base"]
		for j in 3:
			var ang := PI * (0.1 + 0.4 * j)
			var q := Vector2(gb.x, float(c["gy"]))
			var crack := PackedVector2Array([q, q + Vector2.from_angle(ang) * Vector2(6.0, 2.4) + Vector2(1, 0), q + Vector2.from_angle(ang + 0.3) * Vector2(12.0, 4.8)])
			Ink.brush(ci, xf, crack, 1.4, Color("3a2c24"), 1.0, 0.0)
	if mods.has("repousse"):
		var base: Vector2 = g["base"]
		var k := fposmod(t * 0.8, 1.0)
		var ring := Ink.oval(Vector2(base.x, float(c["gy"])), 6.0 + 16.0 * k, (6.0 + 16.0 * k) * 0.4, 24)
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
