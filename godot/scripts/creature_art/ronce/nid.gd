## Nid de ronces (Ronce, soutien), direction « Bestiaire d'herbier » : une galle de rosier (bédégar)
## rongée par la Flétrissure, tenue debout par des tiges de ronce arquées plantées dans le sol. La poche
## de la galle, chevelue, couve les Rejetons : le signe du soutien (vertical, poche, halo).
## Annonce (windup, k 0 → 1) : la poche enfle et palpite, ses fentes de braise s'ouvrent, le halo monte ;
##   au bout, la poche se fend en haut et une larve pointe la tête (la naissance du Rejeton).
## Ancré : il ne marche pas ; au repos, il respire et ses tiges se balancent.
##
## Pose : t, k (annonce 0 → 1), state (""/windup), hit, elite, region, mono.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const O = preload("res://scripts/creature_art/ronce/_outils.gd")

## 100 unités en px du jeu (1600×900) : ~72 px de haut à l'écran en 1080p (soutien ≥ 56).
const HEIGHT := 60.0
## L'élite : collier et liseré dessinés ici (contrat moteur), collier à la taille de la poche.
const DRAWS_ELITE := true
const NECK := Vector2(0, -26)

## Tiges arquées : pied gauche, pied droit, hauteur de l'arche, devant (true) ou derrière.
const CANES := [
	[Vector2(-54, -2), Vector2(10, -4), 86.0, false],
	[Vector2(-20, -2), Vector2(52, -2), 106.0, false],
	[Vector2(-48, -1), Vector2(46, 0), 24.0, true],
	[Vector2(38, 0), Vector2(30, -70), 14.0, true],
]


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var k: float = o.get("k", 0.0)
	var state: String = o.get("state", "")
	var hit: float = o.get("hit", 0.0)
	var elite: bool = o.get("elite", false)
	if state != "windup":
		k = 0.0
	Ink.flash = hit
	var base := Ink.frame(feet, h, false)
	Ink.ground_shadow(ci, base, Vector2(0, 0), 56.0)
	var kk := Anim.ease_out(k)
	# Palpitation de la poche : de plus en plus vite pendant l'annonce.
	var beat := sin(t * TAU / 2.4) * 0.02 + kk * (0.06 + 0.04 * sin(t * (8.0 + 14.0 * kk)))
	var sq := Vector2(1.0 + 0.08 * hit + beat * 0.6, 1.0 - 0.1 * hit + beat)
	var xf := base * Transform2D(0.0, sq, 0.0, Vector2.ZERO)
	# Halo de braise derrière la poche : monte avec l'annonce (signe du soutien).
	Ink.halo(ci, xf * Vector2(0, -50), 46.0 * h / 100.0 * (0.7 + 0.5 * kk), Art.bc("braise"), 0.35 + 1.4 * kk)
	# Radicelles au pied.
	for i in 7:
		var x := -44.0 + i * 15.0
		Ink.brush(ci, base, PackedVector2Array([Vector2(x, -3), Vector2(x + 6.0 * sin(i * 1.7), 2.0), Vector2(x + 11.0 * sin(i * 1.7), 4.0)]), 2.6, Art.bc("ronce", "detail").darkened(0.45), 1.0, 0.0)
	# Tiges du fond.
	for c in CANES:
		if not c[3]:
			_cane(ci, base, c, t, 0.35, kk)
	# La poche (galle) : contour chevelu, deux tons, plus pâle en haut.
	var pod := Ink.lumpy(Vector2(0, -48), 33.0, 36.0, 60, 0.05, 18.0)
	if elite:
		O.rim(ci, xf, pod, 2.8)
	# Fibres de la galle (le bédégar est chevelu) : mèches autour de la poche, derrière elle.
	for i in 22:
		var a := TAU * i / 22.0 + 0.1
		var p := Vector2(0, -48) + Vector2(cos(a) * 32.0, sin(a) * 35.0)
		var d := Vector2.from_angle(a + 0.5 * sin(t * 1.5 + i))
		var col := Art.bc("ronce", "clair") if i % 3 else Art.bc("ronce", "reflet").darkened(0.15)
		Ink.brush(ci, xf, PackedVector2Array([p - d * 2.0, p + d * 7.0, p + d * 11.0 + d.orthogonal() * 3.0]), 3.6, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, xf, PackedVector2Array([p - d * 2.0, p + d * 7.0, p + d * 11.0 + d.orthogonal() * 3.0]), 2.0, col, 1.0, 0.0)
	Ink.part(ci, xf, pod, O.pal(), 2.8, 1.0, 0.9)
	# Drupes sur la poche, comme la mûre.
	if not Ink.mono:
		var sk := xf.get_scale().abs().x
		for row in 6:
			for col in 6:
				var p := Vector2(-24 + col * 9.6 + (4.8 if row % 2 else 0.0), -70 + row * 9.4)
				var q := (p - Vector2(0, -46)) / Vector2(26, 29)
				if q.length() > 0.9:
					continue
				var lit := clampf(-(q.dot(Ink.LIGHT)) * 0.9 + 0.35, 0.0, 1.0)
				ci.draw_circle(xf * (p + Vector2(0.7, 1.0)), 3.4 * sk, Ink.shade(Color(Art.bc("ronce", "ombre"), 0.45)))
				ci.draw_circle(xf * (p + Vector2(-1.1, -1.3)), 1.6 * sk, Ink.shade(Color(Art.bc("ronce", "reflet"), 0.2 + 0.55 * lit)))
	# La Flétrissure ronge le bas de la poche : plaque sombre.
	Ink.flat(ci, xf, Ink.lumpy(Vector2(14, -26), 13.0, 9.0, 22, 0.35, 6.0, 0.8), Art.bc("ronge"))
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-16, -22), 7.0, 5.0, 14, 0.3, 5.0, 0.2), Art.bc("ronge"))
	# Fentes de braise : elles s'ouvrent pendant l'annonce (encre, puis braise de plus en plus large).
	var slits := [
		[Vector2(-26, -50), Vector2(-21, -42), Vector2(-24, -33)],
		[Vector2(20, -70), Vector2(25, -61), Vector2(21, -52), Vector2(26, -44)],
		[Vector2(-4, -40), Vector2(2, -36), Vector2(9, -38)],
	]
	for s in slits:
		var pts := PackedVector2Array(s)
		Ink.brush(ci, xf, pts, 4.0 + 3.0 * kk, Ink.encre())
		if not Ink.mono:
			Ink.brush(ci, xf, pts, 1.6 + 3.0 * kk, Art.bc("braise").lerp(Art.bc("braise_coeur"), kk * 0.8))
	# Yeux de braise de la poche : deux fentes qui couvent (le nid regarde).
	O.eye(ci, xf, Vector2(-12, -58), -0.1, 11.0, 5.0, 0.4 + 0.6 * kk, hit, t, kk, 0.4)
	O.eye(ci, xf, Vector2(7, -60), -0.2, 8.0, 4.0, 0.4 + 0.6 * kk, hit, t, kk, 0.4)
	# Naissance : en fin d'annonce, la poche se fend en haut et une larve pointe la tête.
	if k > 0.6:
		var u := smoothstep(0.6, 1.0, k)
		var top := Vector2(2, -82)
		Ink.flat(ci, xf, Ink.oval(top, 9.0 * u + 1.0, 4.0 * u + 1.0, 16), Art.bc("ronge"), 2.0)
		if not Ink.mono:
			Ink.halo(ci, xf * top, 16.0 * h / 100.0 * u, Art.bc("braise_coeur"), 1.5 * u)
		var head := Ink.oval(top + Vector2(0, -7.0 * u), 6.5, 6.0, 16)
		Ink.part(ci, xf, head, O.pal(0.12), 1.8 * u, 1.0, 0.6)
		Ink.ember(ci, xf, Ink.leaf(top + Vector2(0, -8.0 * u), -0.1, 4.0, 2.4), u)
	# Sépales secs au sommet de la poche.
	for i in 5:
		var a := -PI * (0.86 - i * 0.18)
		Ink.part(ci, xf, Ink.leaf(Vector2(2, -82), a + 0.1 * sin(t * 1.8 + i) - 0.15 * kk * signf(cos(a)), 16.0 - absf(i - 2) * 2.0, 6.5, 0.12 if i < 2 else -0.12), O.stem(), 1.6, 1.0, 0.4)
	if elite:
		O.collar(ci, xf, NECK, 32.0, 9.0, t, o.get("region", "ronce"))
	# Braises qui s'échappent des fentes.
	Ink.sparks(ci, xf, Vector2(10, -62), Vector2(0.2, -1.0), 3, t * 0.7, 1.4, 0.5 + kk)
	# Tiges du devant.
	for c in CANES:
		if c[3]:
			_cane(ci, base, c, t, 0.0, kk)


## Une tige de ronce arquée (repère du sol) : encre, tige, épines d'os, une feuille encore verte.
## dark : assombrit les tiges du fond. kk : les tiges se tendent (resserrent l'arche) pendant l'annonce.
static func _cane(ci: CanvasItem, base: Transform2D, c: Array, t: float, dark: float, kk: float) -> void:
	var a: Vector2 = c[0]
	var b: Vector2 = c[1]
	var hh: float = c[2] * (1.0 + 0.04 * kk)
	var pts := PackedVector2Array()
	var sway := sin(t * 1.3 + a.x * 0.1) * 2.0
	for i in 9:
		var u := i / 8.0
		var p := a.lerp(b, u)
		p.y -= hh * sin(PI * u) + sway * sin(PI * u)
		p.x += (u - 0.5) * -6.0 * kk
		pts.append(p)
	var col := Art.bc("ronce", "detail").lerp(Art.bc("ronce", "ombre"), 0.35).darkened(dark)
	Ink.brush(ci, base, pts, 9.0, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, base, pts, 6.0, col, 1.0, 1.0)
	Ink.brush(ci, base, pts.slice(1, 6), 1.4, col.lightened(0.35))
	var bone := O.bone()
	if dark > 0.0:
		bone = {"clair": Art.bc("os").darkened(dark * 0.6), "ombre": Art.bc("os").darkened(0.3 + dark * 0.6)}
	for i in range(1, 8):
		var p := pts[i]
		var d := (pts[i + 1] - pts[i - 1]).normalized()
		var side := 1.0 if i % 2 else -1.0
		Ink.part(ci, base, Ink.thorn(p + d.orthogonal() * side * 2.5, d.angle() + side * (PI * 0.5) - 0.5 * side, 8.0, 3.6, -0.2 * side), bone, 1.0, 1.0, 0.0)
	if dark == 0.0:
		var green := {"clair": Art.ec("racine", "clair").darkened(0.15), "ombre": Art.ec("racine", "clair").darkened(0.55), "reflet": Art.ec("racine", "clair").lightened(0.3)}
		var q := pts[2]
		Ink.part(ci, base, Ink.leaf(q, -PI * 0.5 - 0.9 + 0.12 * sin(t * 2.0 + a.x), 12.0, 6.0, 0.12), green, 1.2, 1.0, 0.5)
