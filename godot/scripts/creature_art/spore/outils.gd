## Outils communs aux Flétris du marais de Spore (refonte « Bestiaire d'herbier », R2) : palettes de la
## région, chapeau de champignon, vesse (boule à spores), bulles de vase, nuage de spores, collier d'élite.
##
## Famille : champignons, limaces et myxomycètes du marais, rongés par la Flétrissure. Chair mauve-gris
## (Art.bc("spore", …)), chapeaux pâles, lames ocre, vase vert-de-gris ; la braise (yeux, fentes) reste le
## signe commun de l'ennemi. Fonctions statiques, sans état ni hasard global.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")


static func flesh() -> Dictionary:
	return {"clair": Art.bc("spore", "clair"), "ombre": Art.bc("spore", "ombre"), "reflet": Art.bc("spore", "reflet")}


static func cap_pal() -> Dictionary:
	return {"clair": Art.bc("spore", "chapeau"), "ombre": Art.bc("spore", "chapeau_ombre"), "reflet": Color.WHITE.lerp(Art.bc("spore", "chapeau"), 0.4)}


static func lichen_pal() -> Dictionary:
	return {"clair": Art.bc("spore", "lichen"), "ombre": Art.bc("spore", "lichen_ombre"), "reflet": Art.bc("spore", "lichen").lightened(0.35)}


static func vase_pal() -> Dictionary:
	return {"clair": Art.bc("spore", "vase"), "ombre": Art.bc("spore", "vase").darkened(0.4), "reflet": Art.bc("spore", "vase_reflet")}


## Chapeau de champignon sur son pied : base b (local), direction a du pied, longueur l, largeur du
## chapeau w ; sway penche le chapeau ; glow allume les lames (annonce).
static func cap(ci: CanvasItem, xf: Transform2D, b: Vector2, a: float, l: float, w: float, sway := 0.0, glow := 0.0, spots := true) -> void:
	var d := Vector2.from_angle(a + sway * 0.5)
	var top := b + d * l
	var stem := PackedVector2Array([b, b.lerp(top, 0.5) + d.orthogonal() * l * 0.08 * sway, top])
	Ink.brush(ci, xf, stem, w * 0.3 + 2.0, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, stem, w * 0.3, Art.bc("spore", "chapeau").darkened(0.12), 1.0, 1.0)
	# Le chapeau : un dôme au bout du pied, incliné comme lui (aplati, vu de trois quarts).
	var rot := d.angle() + PI / 2.0
	var dome := PackedVector2Array()
	for i in 13:
		var u := PI * i / 12.0
		dome.append(Vector2(-cos(u) * w * 0.5, -sin(u) * w * 0.42))
	dome.append(Vector2(w * 0.42, w * 0.08))
	dome.append(Vector2(0, w * 0.14))
	dome.append(Vector2(-w * 0.42, w * 0.08))
	var cxf := Transform2D(rot, top)
	Ink.part(ci, xf, cxf * dome, cap_pal(), 1.6, 1.0, 0.8)
	# Lames sous le chapeau (ocre, braise pendant l'annonce).
	var gill := Art.bc("spore", "detail").lerp(Art.bc("braise"), glow)
	Ink.brush(ci, xf, cxf * PackedVector2Array([Vector2(-w * 0.4, w * 0.06), Vector2(0, w * 0.13), Vector2(w * 0.4, w * 0.06)]), 1.6, gill)
	if glow > 0.0:
		Ink.halo(ci, xf * (cxf * Vector2(0, w * 0.12)), w * 0.6 * xf.get_scale().abs().x, Art.bc("braise"), glow)
	# Taches de voile sur le dessus.
	if spots and not Ink.mono:
		for s: Vector3 in [Vector3(-0.2, -0.28, 0.07), Vector3(0.12, -0.33, 0.06), Vector3(0.28, -0.15, 0.05)]:
			Ink.flat(ci, xf, cxf * Ink.oval(Vector2(s.x * w, s.y * w), s.z * w, s.z * w * 0.7, 10), Color(Art.bc("spore", "chapeau_ombre"), 0.7))


## Vesse (boule à spores) : poire bosselée posée en c, rayons rx, ry, avec son ostiole au sommet
## (qui s'allume pendant l'annonce, glow) et des verrues. swell gonfle la boule.
static func puffball(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float, ry: float, pal: Dictionary, glow := 0.0, warts := 9, salt := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 30:
		var a := TAU * i / 30.0
		var s := Vector2(cos(a), sin(a))
		# Poire : plus large en bas, un petit col au sommet.
		var wide := 1.0 + 0.1 * maxf(s.y, 0.0) - 0.22 * pow(maxf(-s.y, 0.0), 2.0) * absf(s.x)
		var tip := -0.14 * pow(maxf(-s.y, 0.0), 12.0)
		pts.append(c + Vector2(s.x * rx * wide, s.y * ry * (1.0 - tip)))
	Ink.part(ci, xf, pts, pal, 2.2, 1.0, 0.9)
	if Ink.mono:
		return
	# Verrues : petits picots clairs du côté de la lumière, sombres ailleurs.
	for i in warts:
		var a := -PI * 0.92 + (PI * 0.84) * i / maxf(warts - 1, 1) + 0.15 * sin(i * 2.3 + salt)
		var rr := 0.55 + 0.32 * fposmod(i * 0.618 + salt, 1.0)
		var p := c + Vector2(cos(a) * rx * rr, sin(a) * ry * rr * 0.9 + ry * 0.1)
		var lit := clampf(-Vector2(cos(a), sin(a)).dot(Ink.LIGHT), 0.0, 1.0)
		var wr := 1.6 + 1.4 * fposmod(i * 0.43 + salt, 1.0)
		Ink.flat(ci, xf, Ink.lumpy(p + Vector2(0.5, 0.7), wr, wr * 0.8, 9, 0.2, 3.0, i), Color(pal["ombre"].darkened(0.35), 0.8))
		Ink.flat(ci, xf, Ink.lumpy(p, wr * 0.8, wr * 0.65, 9, 0.2, 3.0, i), pal["clair"].lerp(pal["reflet"], 0.15 + 0.55 * lit))
	# Pied plissé : rides du bas de la boule, où elle sort de la vase.
	for i in 5:
		var x := c.x + (i - 2) * rx * 0.32
		var y0 := c.y + ry * (0.95 - 0.06 * absf(i - 2))
		Ink.brush(ci, xf, PackedVector2Array([Vector2(x, y0), Vector2(x + (i - 2) * 1.5, y0 - ry * 0.32)]), 1.4, pal["ombre"].darkened(0.25))
	# Ostiole : la bouche ronde au sommet, d'où sortent les spores.
	var top := c + Vector2(rx * 0.1, -ry * 0.92)
	Ink.flat(ci, xf, Ink.oval(top, rx * 0.22, ry * 0.1, 14), Art.bc("ronge"), 1.0)
	if glow > 0.0:
		Ink.ember(ci, xf, Ink.oval(top, rx * 0.15, ry * 0.06, 12), glow)


## Nuage de spores qui s'échappe de p (local) : n bouffées qui montent et s'élargissent ; u 0 → 1
## (âge de la bouffée), k sa force.
static func spore_puff(ci: CanvasItem, xf: Transform2D, p: Vector2, u: float, k: float, n := 7, reach := 40.0) -> void:
	if Ink.mono or k <= 0.0:
		return
	var s := xf.get_scale().abs().x
	for i in n:
		var a := -PI / 2.0 + (i - (n - 1) * 0.5) * 0.5
		var q := p + Vector2.from_angle(a) * reach * u * (0.7 + 0.3 * fposmod(i * 0.37, 1.0))
		var rr := (3.0 + 9.0 * u) * s
		ci.draw_circle(xf * q, rr, Color(Art.bc("spore", "spore"), 0.35 * k * (1.0 - u * 0.7)))
		ci.draw_circle(xf * q, rr * 0.45, Color(Art.bc("spore", "spore").lightened(0.3), 0.4 * k * (1.0 - u)))


## Bulles de vase qui bouillonnent autour de c (local, au sol) : n bulles sur une ellipse rx, cycliques.
static func bubbles(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float, t: float, k: float, n := 6) -> void:
	if Ink.mono or k <= 0.0:
		return
	var s := xf.get_scale().abs().x
	for i in n:
		var u := fposmod(t * 1.8 + i * 0.37, 1.0)
		var a := TAU * i / n + 0.4
		var q := c + Vector2(cos(a) * rx, sin(a) * rx * Art.OMBRE_APLATI) - Vector2(0, u * 6.0)
		var rr := (1.5 + 3.5 * sin(PI * u)) * s * k
		var w := xf * q
		ci.draw_circle(w, rr + 0.9 * s, Ink.encre())
		ci.draw_circle(w, rr, Art.bc("spore", "vase").lerp(Art.bc("spore", "vase_reflet"), 0.3))
		ci.draw_circle(w - Vector2(rr, rr) * 0.35, rr * 0.35, Color(Art.bc("spore", "vase_reflet"), 0.9))


## Flaque de vase au sol (local), luisante : rayons rx (et rx × aplati), contour bosselé.
static func puddle(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float, a := 1.0, salt := 0.0) -> void:
	if Ink.mono or a <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in 26:
		var ang := TAU * i / 26.0
		var m := 1.0 + 0.16 * sin(ang * 5.0 + salt) + 0.08 * sin(ang * 9.0 + salt * 2.0)
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * rx * Art.OMBRE_APLATI) * m)
	var w := xf * pts
	Ink._poly(ci, w, Color(Art.bc("spore", "vase").darkened(0.25), 0.85 * a))
	var shine := Transform2D(0.0, Vector2(0.55, 0.45), 0.0, Vector2.ZERO)
	var cen := xf * (c + Vector2(-rx * 0.2, -rx * 0.08))
	var inner := PackedVector2Array()
	for q in w:
		inner.append(cen + shine.basis_xform(q - xf * c))
	Ink._poly(ci, inner, Color(Art.bc("spore", "vase_reflet"), 0.25 * a))


## Élite : liseré doré le long du dos (pts : contour local, ouvert), sous l'encre.
static func elite_rim(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array) -> void:
	if Ink.mono or pts.size() < 2:
		return
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p + Vector2(0, 2.4))
	Ink.brush(ci, xf, inner, 2.6, Art.c("or"), 0.0, 0.0)


## Collier d'élite de la région : une couronne d'amanites dorées aux points at (local).
static func elite_caps(ci: CanvasItem, xf: Transform2D, at: Array, t: float) -> void:
	if Ink.mono:
		return
	var gold := {"clair": Art.c("or"), "ombre": Art.c("or").darkened(0.45), "reflet": Art.c("or").lightened(0.5)}
	for i in at.size():
		var p: Vector2 = at[i]
		var dome := PackedVector2Array()
		for j in 9:
			var u := PI * j / 8.0
			dome.append(p + Vector2(-cos(u) * 5.0, -sin(u) * 4.2 - 2.0 + 0.6 * sin(t * 3.0 + i)))
		Ink.brush(ci, xf, PackedVector2Array([p + Vector2(0, 2), p + Vector2(0, -2)]), 2.2, Art.c("or").darkened(0.3), 1.0, 1.0)
		Ink.part(ci, xf, dome, gold, 1.0, 1.0, 0.6)
		Ink.flat(ci, xf, Ink.oval(p + Vector2(-1.2, -4.5), 0.9, 0.7, 8), Art.bc("braise"))
