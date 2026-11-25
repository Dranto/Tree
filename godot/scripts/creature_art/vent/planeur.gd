## Planeur de cendre (Vent, tireur), direction « Bestiaire d'herbier » : une grande phalène à queues des
## plateaux (comme l'actias), ailes d'un bleu de cendre pâle, deux longues traînes qui ondulent derrière
## elle. La Flétrissure a brûlé le bord de ses ailes ; ses ocelles sont devenues des yeux de braise.
## Elle plane au-dessus de son ombre ; en vol haut (état « vol »), elle monte hors d'atteinte, un anneau
## de vent tourne sous elle. Signe du tireur : pendant l'annonce, les ocelles s'allument et les écailles
## se hérissent au bord des ailes ; au tir, les ailes claquent et deux plumes de cendre partent.
##
## Pose : t, k (annonce 0 → 1), state ("" / "windup" / "vol"), strike (0 → 1 après le tir, -1 : aucun),
## hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vent/_commun.gd")

## 100 unités en px du jeu (1600×900) : ~50 px d'envergure à l'écran en 1080p.
const HEIGHT := 50.0
const DRAWS_ELITE := true
const NECK := Vector2(8, -42)
## Le vol haut est une pose propre du comportement (glider.gd), cuite en boucle (contrat du moteur).
const CUSTOM := {"state:vol": 6}

## Altitude du corps (unités locales) : au repos, en vol haut.
const ALT := 40.0
const ALT_HIGH := 66.0


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var k: float = o.get("k", 0.0)
	var state: String = o.get("state", "")
	var strike: float = o.get("strike", -1.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	var kk := Anim.ease_out(k)
	var high := 1.0 if state == "vol" else 0.0
	var snap := 0.0 if strike < 0.0 else 1.0 - Anim.ease_out(strike)
	var alt := lerpf(ALT, ALT_HIGH, high) + 3.0 * sin(t * 2.2)
	Ink.ground_shadow(ci, base, Vector2(0, 0), lerpf(24.0, 16.0, high))
	# Anneau de vent sous elle en vol haut.
	if high > 0.0 and not Ink.mono:
		for i in 2:
			var a0 := t * 3.0 + i * PI
			var arc := PackedVector2Array()
			for j in 9:
				var a := a0 + j * 0.2
				arc.append(Vector2(cos(a) * 26.0, -alt * 0.45 + sin(a) * 7.0))
			Ink.brush(ci, base, arc, 2.6, Color(Art.bc("vent", "reflet"), 0.7))
	# Battement : lent en plané, rapide en vol haut ; ailes dressées vers l'avant à l'annonce, claquées au tir.
	var flap := 0.18 * sin(t * 3.4) * (1.0 - kk)
	if high > 0.0:
		flap = 0.45 * sin(t * 11.0)
	flap += 0.35 * kk - 0.7 * snap
	var tilt := clampf(la, -0.5, 0.5) * 0.3 + 0.1 * hit
	var sq := Vector2(1.0 + 0.08 * hit, 1.0 - 0.08 * hit)
	var xf := base * Transform2D(0.0, Vector2(0, -alt)) * Transform2D(tilt, sq, 0.0, Vector2.ZERO)
	var far := {"clair": Art.bc("vent", "clair").darkened(0.15), "ombre": Art.bc("vent", "ombre"), "reflet": Art.bc("vent", "aile")}
	var near := {"clair": Art.bc("vent", "aile"), "ombre": Art.bc("vent", "clair"), "reflet": Art.bc("vent", "reflet")}
	var glow := 0.25 + 0.75 * maxf(kk, snap)
	# Traînes : deux longs rubans des ailes postérieures, qui ondulent (celle du fond d'abord).
	_tail(ci, xf, Vector2(-6, 6), t, 0.0, far, high)
	# Ailes du fond (plus sombres, raccourcies).
	_hind(ci, xf, Vector2(-2, 0), flap * 0.8 + 0.25, Vector2(0.7, 0.85), far, glow, false)
	_fore(ci, xf, Vector2(0, -4), flap * 0.8 + 0.3, Vector2(0.7, 0.85), far, glow, false, kk)
	# Corps : abdomen annelé, thorax velu, tête et antennes plumeuses.
	var abd := Ink.oval(Vector2(-6, 12), 5.0, 13.0, 20, 0.45)
	Ink.part(ci, xf, abd, {"clair": Art.bc("vent", "duvet"), "ombre": Art.bc("vent", "plume"), "reflet": Color.WHITE}, 1.6, 1.0, 0.5)
	for i in 3:
		var y := 6.0 + i * 5.5
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-10 + i * -1.6, y + 2), Vector2(-3 + i * -2.2, y - 1)]), 1.0, Art.bc("vent", "plume"))
	Ink.part(ci, xf, Ink.lumpy(Vector2(2, -2), 7.5, 8.0, 22, 0.12, 9.0), {"clair": Art.bc("vent", "duvet"), "ombre": Art.bc("vent", "clair"), "reflet": Color.WHITE}, 1.8, 1.0, 0.6)
	var hd := Vector2(9, -6)
	Ink.part(ci, xf, Ink.oval(hd, 4.5, 4.0, 14), V.pal("plume", "ombre", "clair"), 1.4, 1.0, 0.4)
	for s: float in [-1.0, 1.0]:
		_antenna(ci, xf, hd + Vector2(1, -3), -1.2 + 0.25 * s + 0.15 * kk + 0.05 * sin(t * 2.0 + s), t, s < 0.0)
	if hit > 0.4:
		Ink.brush(ci, xf, PackedVector2Array([Vector2(10, -6.5), Vector2(13, -6)]), 1.4, Ink.encre())
	else:
		Ink.ember(ci, xf, Ink.oval(Vector2(11.5, -6), 1.7, 1.5, 10), 0.3 + 0.7 * kk)
	if o.get("elite", false):
		V.collar(ci, xf, Vector2(5, -1), 6.0, 4.0, -0.5)
	# Ailes de devant, par-dessus le corps.
	_tail(ci, xf, Vector2(-8, 8), t, 1.3, near, high)
	_hind(ci, xf, Vector2(-4, 2), flap, Vector2.ONE, near, glow, true)
	_fore(ci, xf, Vector2(-2, -3), flap, Vector2.ONE, near, glow, true, kk)
	# Les plumes de cendre qui partent au tir (deux, en éventail vers la cible).
	if snap > 0.0 and not Ink.mono:
		var u := 1.0 - snap
		for s: float in [-1.0, 1.0]:
			var a := clampf(la, -0.6, 0.6) + 0.18 * s
			var p := Vector2(14, -4) + Vector2.from_angle(a) * (8.0 + 40.0 * u)
			V.feather(ci, xf, p, a + PI, 11.0, 4.0, {"clair": Art.bc("vent", "plume"), "ombre": Art.bc("ronge"), "reflet": Art.bc("vent", "clair")}, 1.0, 0.8)
	# Écailles qui se hérissent et s'allument au bord des ailes pendant l'annonce.
	Ink.sparks(ci, xf, Vector2(-26, -40), Vector2(0.4, -0.6), 4, t, 1.3, kk)
	Ink.sparks(ci, xf, Vector2(-14, -6), Vector2(-0.3, 1.0), 2, t, 1.1, 0.5)


## Aile antérieure (repère du corps) : épaule sh, rotation flap, raccourci sc, ocelle de braise.
static func _fore(ci: CanvasItem, xf: Transform2D, sh: Vector2, flap: float, sc: Vector2, col: Dictionary, glow: float, front: bool, kk: float) -> void:
	var wx := xf * Transform2D(flap - 0.5, sc, 0.0, sh)
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(-2, -12), Vector2(-8, -28), Vector2(-18, -44), Vector2(-28, -52),
		Vector2(-36, -51), Vector2(-39, -45), Vector2(-36, -34), Vector2(-30, -22), Vector2(-20, -10), Vector2(-10, -2)])
	Ink.part(ci, wx, pts, col, 2.0, 1.0, 0.7)
	if Ink.mono:
		return
	# Nervures.
	for v: Vector2 in [Vector2(-26, -48), Vector2(-34, -40), Vector2(-28, -24)]:
		Ink.brush(ci, wx, PackedVector2Array([Vector2(-2, -3), v * 0.5 + Vector2(-1, -2), v]), 0.9, col["ombre"].darkened(0.25))
	# Bord d'attaque sombre (comme l'actias), bout brûlé par la cendre.
	Ink.brush(ci, wx, PackedVector2Array([Vector2(-1, -4), Vector2(-8, -28), Vector2(-20, -45), Vector2(-30, -51)]), 2.6, Art.bc("vent", "plume"), 1.0, 0.0)
	Ink.flat(ci, wx, Ink.lumpy(Vector2(-36, -49), 4.0, 3.5, 12, 0.5, 4.0), Art.bc("ronge"))
	ci.draw_circle(wx * Vector2(-33.5, -47), 0.9 * wx.get_scale().abs().x, Art.bc("braise"))
	_ocelle(ci, wx, Vector2(-22, -30), 4.2, glow if front else glow * 0.6)
	# Écailles hérissées au bord de fuite (annonce).
	if kk > 0.0:
		for i in 4:
			var q := Vector2(-36, -40).lerp(Vector2(-14, -6), i / 3.0)
			Ink.brush(ci, wx, PackedVector2Array([q, q + Vector2(-4, 2) * kk]), 1.4, Art.bc("braise"))


## Aile postérieure arrondie (la traîne part de son bord).
static func _hind(ci: CanvasItem, xf: Transform2D, sh: Vector2, flap: float, sc: Vector2, col: Dictionary, glow: float, front: bool) -> void:
	var wx := xf * Transform2D(flap * 0.6 - 0.15, sc, 0.0, sh)
	var pts := Ink.lumpy(Vector2(-16, 6), 16.0, 11.0, 24, 0.05, 3.0)
	Ink.part(ci, wx, pts, col, 1.8, 1.0, 0.5)
	if Ink.mono:
		return
	Ink.brush(ci, wx, PackedVector2Array([Vector2(-2, 1), Vector2(-14, 4), Vector2(-28, 8)]), 0.9, col["ombre"].darkened(0.2))
	_ocelle(ci, wx, Vector2(-16, 6), 3.4, glow if front else glow * 0.6)


## Traîne : ruban effilé qui ondule, terminé par une palette (repère du corps).
static func _tail(ci: CanvasItem, xf: Transform2D, from: Vector2, t: float, ph: float, col: Dictionary, high: float) -> void:
	var pts := PackedVector2Array()
	var sp := 5.0 + 6.0 * high
	for i in 8:
		var u := i / 7.0
		pts.append(from + Vector2(-26.0 * u - 8.0 * u * u, 30.0 * u) + Vector2(0, 0).lerp(Vector2(4.0, -2.0), u) * sin(t * sp + u * 4.0 + ph))
	Ink.brush(ci, xf, pts, 7.0, Ink.encre(), 1.0, 0.3)
	Ink.brush(ci, xf, pts, 4.6, col["clair"], 1.0, 0.25)
	var end := pts[pts.size() - 1]
	Ink.part(ci, xf, Ink.leaf(end + Vector2(2, -3), PI * 0.62, 12.0, 6.0), {"clair": col["clair"], "ombre": col["ombre"], "reflet": col["reflet"]}, 1.2, 1.0, 0.3)
	Ink.brush(ci, xf, PackedVector2Array([end + Vector2(-1, 1), end + Vector2(-3, 6)]), 1.6, Art.bc("ronge"))


## Ocelle : anneau d'encre, braise qui s'allume, pupille sombre (l'œil de la Flétrissure).
static func _ocelle(ci: CanvasItem, wx: Transform2D, c: Vector2, r: float, glow: float) -> void:
	Ink.flat(ci, wx, Ink.oval(c, r + 1.2, r + 0.9, 16), Art.bc("vent", "plume").darkened(0.3))
	Ink.ember(ci, wx, Ink.oval(c, r, r * 0.8, 16), glow)
	Ink.flat(ci, wx, Ink.oval(c + Vector2(0.6, 0.3), r * 0.38, r * 0.34, 10), Art.bc("ronge"))


## Antenne plumeuse (pectinée) : une tige qui se courbe, des barbes de chaque côté.
static func _antenna(ci: CanvasItem, xf: Transform2D, b: Vector2, a: float, t: float, far: bool) -> void:
	var col := Art.bc("vent", "detail").darkened(0.35 if far else 0.0)
	var pts := PackedVector2Array()
	for i in 6:
		var u := i / 5.0
		pts.append(b + Vector2.from_angle(a + 0.7 * u * u) * 18.0 * u)
	Ink.brush(ci, xf, pts, 2.6, Ink.encre(), 1.0, 0.0)
	Ink.brush(ci, xf, pts, 1.3, col, 1.0, 0.0)
	for i in range(1, 5):
		var p := pts[i]
		var d := (pts[i + 1] - pts[i - 1]).normalized()
		for s: float in [-1.0, 1.0]:
			Ink.brush(ci, xf, PackedVector2Array([p, p + (d.orthogonal() * s * 3.4 + d * 1.6) * (1.0 - i * 0.12)]), 1.0, col)
