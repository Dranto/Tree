## Cracheur de cendre (commun, tireur), direction « Bestiaire d'herbier » : un four de charbon qui
## marche. Un corps voûté de crapaud, croûté de cendre, sur quatre pattes de bois brûlé ; deux cheminées
## fument sur le dos. Son long museau en entonnoir suit la cible : pendant l'annonce, la gorge enfle de
## braises et l'embouchure s'allume ; au tir, il recule et crache un nuage de cendre.
##
## Pose : t, walk, moving, k (annonce 0 → 1), state, strike (0 → 1 après le tir, -1 : aucun), hit,
## look, elite, region.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const U = preload("res://scripts/creature_art/commun/_outils.gd")

## 100 unités en px du jeu (1600×900) : ~48 px de haut à l'écran en 1080p.
const HEIGHT := 40.0
const DRAWS_ELITE := true


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var elite: bool = o.get("elite", false)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	Ink.ground_shadow(ci, base, Vector2(0, 0), 34.0)
	var kk := Anim.ease_out(k)
	var shot := 0.0 if strike < 0.0 else 1.0 - clampf(strike, 0.0, 1.0)
	var bob := -absf(sin(walk * 1.4)) * 3.0 * mv + sin(t * TAU / 2.2) * 0.8
	# Annonce : il s'accroupit, gorge gonflée ; tir : recul vers l'arrière.
	var sq := Vector2(1.0 + 0.08 * hit + 0.06 * kk, 1.0 - 0.1 * hit - 0.07 * kk + 0.05 * shot)
	var xf := base * Transform2D(-0.05 * kk + 0.06 * hit - 0.05 * shot, sq, 0.0, Vector2(-9.0 * shot, 0)) * Transform2D(0.0, Vector2(0, bob))
	var bark := U.char_pal()
	var far_bark := {"clair": bark["ombre"], "ombre": bark["ombre"].darkened(0.3)}
	# Pattes du fond.
	for i in 2:
		var ph := walk * 1.4 + (PI if i == 1 else 0.0)
		_leg(ci, base, xf * Vector2(-18 + i * 30, -24), Vector2(-16 + i * 30 + sin(ph) * 6.0 * mv, -maxf(cos(ph), 0.0) * 4.0 * mv), far_bark)
	# Cheminées sur le dos (derrière le corps), leur fumée de cendre.
	for c: Vector2 in [Vector2(-26, -58), Vector2(-10, -68)]:
		var top := c + Vector2(-4, -20)
		Ink.part(ci, xf, PackedVector2Array([c + Vector2(-6, 4), top + Vector2(-5, 0), top + Vector2(5, 0), c + Vector2(6, 4)]), bark, 1.8, 1.0, 0.0)
		Ink.flat(ci, xf, Ink.oval(top, 5.0, 2.0, 12), Art.bc("ronge"))
		if not Ink.mono:
			Ink.flat(ci, xf, Ink.oval(top, 3.2, 1.2, 10), Color(Art.bc("braise"), 0.5 + 0.5 * kk))
			for j in 3:
				var u := fposmod(t * 0.7 + j / 3.0 + c.x * 0.01, 1.0)
				var q := xf * (top + Vector2(-6.0 * u + 2.0 * sin(t * 3.0 + j), -4.0 - 26.0 * u))
				ci.draw_circle(q, (3.0 + 5.0 * u) * h / 100.0, Color(Art.bc("commun", "clair"), 0.45 * (1.0 - u) * (1.0 + kk)))
	# Corps voûté : un dos de crapaud, la gorge en dessous.
	var body := PackedVector2Array([Vector2(-34, -24), Vector2(-38, -40), Vector2(-32, -58), Vector2(-16, -70), Vector2(2, -72), Vector2(16, -64), Vector2(22, -50), Vector2(24, -34), Vector2(14, -20), Vector2(-18, -18)])
	if elite:
		U.elite_rim(ci, xf, body, 2.6)
	Ink.part(ci, xf, body, U.pal(), 2.6, 1.0, 0.6)
	# Ventre de charbon craquelé.
	var belly := PackedVector2Array([Vector2(-34, -24), Vector2(-36, -34), Vector2(-24, -32), Vector2(-10, -36), Vector2(6, -32), Vector2(20, -36), Vector2(24, -34), Vector2(14, -20), Vector2(-18, -18)])
	Ink.fill_world(ci, xf * belly, bark, 0.5, 0.0)
	U.crack(ci, xf, PackedVector2Array([Vector2(-26, -28), Vector2(-16, -25), Vector2(-6, -29), Vector2(4, -25), Vector2(12, -28)]), 1.4, 0.5 + 0.5 * kk, t)
	# Pustules de cendre sur le dos (crapaud) et une grande fente de braise.
	for p: Vector3 in [Vector3(-24, -52, 3.4), Vector3(-12, -60, 2.8), Vector3(-2, -52, 2.4), Vector3(-20, -42, 2.2)]:
		Ink.part(ci, xf, Ink.oval(Vector2(p.x, p.y), p.z, p.z * 0.8, 10), {"clair": Art.bc("commun", "clair").lerp(Art.bc("commun", "ombre"), 0.3), "ombre": Art.bc("commun", "ombre"), "reflet": Art.bc("commun", "reflet")}, 1.0, 1.0, 0.8)
	U.crack(ci, xf, PackedVector2Array([Vector2(-30, -44), Vector2(-22, -48), Vector2(-14, -46), Vector2(-6, -40)]), 1.5, 0.4 + 0.6 * kk, t + 1.0)
	# Gorge gonflée de braises : elle enfle pendant l'annonce.
	var throat_r := 7.0 + 7.0 * kk
	var throat := Ink.oval(Vector2(14, -32), throat_r, throat_r * 0.85, 18)
	Ink.part(ci, xf, throat, {"clair": Art.bc("commun", "ombre").lerp(Art.bc("braise"), 0.25 * kk), "ombre": Art.bc("ronge")}, 1.6, 0.6, 0.0)
	if not Ink.mono:
		Ink.flat(ci, xf, Ink.oval(Vector2(14, -32), throat_r * 0.6, throat_r * 0.5, 14), Color(Art.bc("braise"), 0.25 + 0.7 * kk))
		for j in 3:
			var q := Vector2(14, -32) + Vector2.from_angle(t * 4.0 + j * TAU / 3.0) * throat_r * 0.4
			Ink.flat(ci, xf, Ink.oval(q, 1.4, 1.2, 8), Color(Art.bc("braise_coeur"), 0.4 + 0.6 * kk))
	if elite:
		U.elite_collar(ci, xf, Vector2(8, -56), 13.0, 4.5, o.get("region", ""), t)
	# Yeux de braise sur le haut du crâne.
	U.eyes(ci, xf, Vector2(10, -62), Vector2(17, -62), 6.5, 0.3 + 0.7 * kk, hit, t, 0.4)
	# Museau en entonnoir, qui suit la cible ; l'embouchure s'allume pendant l'annonce.
	var aim := clampf(la, -0.6, 0.5)
	_funnel(ci, xf, Vector2(18, -48), aim, kk, shot, t)
	# Pattes de devant.
	for i in 2:
		var ph := walk * 1.4 + (0.0 if i == 1 else PI)
		_leg(ci, base, xf * Vector2(-24 + i * 32, -22), Vector2(-24 + i * 32 + sin(ph) * 6.0 * mv, -maxf(cos(ph), 0.0) * 4.0 * mv), bark)


## Patte courte de bois brûlé, coude en arrière, trois doigts.
static func _leg(ci: CanvasItem, base: Transform2D, hip_w: Vector2, foot: Vector2, col: Dictionary) -> void:
	var hip := base.affine_inverse() * hip_w
	var knee := hip.lerp(foot, 0.5) + Vector2(-5, -1)
	var pts := PackedVector2Array([hip, knee, foot])
	Ink.brush(ci, base, pts, 9.0, Ink.encre(), 1.0, 0.6)
	Ink.brush(ci, base, pts, 6.4, col["clair"], 1.0, 0.5)
	for s: float in [-1.0, 0.2, 1.2]:
		Ink.brush(ci, base, PackedVector2Array([foot + Vector2(0, -1), foot + Vector2(3.0 + s * 4.0, 0.6)]), 2.6, col["clair"].darkened(0.15), 1.0, 0.0)


## Entonnoir de charbon (de piv, angle aim) : bagues de braise qui montent pendant l'annonce, nuage au tir.
static func _funnel(ci: CanvasItem, xf: Transform2D, piv: Vector2, aim: float, kk: float, shot: float, t: float) -> void:
	var d := Vector2.from_angle(aim)
	var n := d.orthogonal()
	var L := 26.0 + 2.0 * kk - 4.0 * shot
	# Une trompe de charbon qui s'évase en pavillon (bord de cendre), un peu relevée au bout.
	var up := -n * 2.0
	var pts := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		pts.append(piv + d * L * u + up * u * u + n * (5.5 + 5.5 * pow(u, 3.0)))
	for i in range(8, -1, -1):
		var u := i / 8.0
		pts.append(piv + d * L * u + up * u * u - n * (5.5 + 5.5 * pow(u, 3.0)))
	Ink.part(ci, xf, pts, U.char_pal(), 2.2, 1.0, 0.5)
	Ink.brush(ci, xf, PackedVector2Array([piv + d * 4.0 + n * 3.0, piv + d * L * 0.7 + n * 4.0]), 1.4, Art.bc("commun", "clair"))
	U.crack(ci, xf, PackedVector2Array([piv + d * 6.0 - n * 2.0, piv + d * 14.0 - n * 1.0, piv + d * 18.0 - n * 3.0]), 1.0, 0.4 + 0.6 * kk, t)
	Ink.part(ci, xf, Ink.oval(piv + d * L + up, 3.4, 11.0, 18, aim), U.pal(), 1.6, 1.0, 0.0)
	var mouth := piv + d * (L + 0.5) + up
	Ink.flat(ci, xf, Ink.oval(mouth, 2.0, 7.5, 16, aim), Art.bc("ronge"))
	if Ink.mono:
		return
	if kk > 0.0:
		for i in 3:
			var u := fposmod(t * 2.2 + i / 3.0, 1.0) * kk
			Ink.flat(ci, xf, Ink.oval(piv + d * (2.0 + u * L), 1.8, 5.0, 10, aim), Color(Art.bc("braise"), 0.9 * kk))
		Ink.halo(ci, xf * mouth, 14.0 * xf.get_scale().abs().x * (0.6 + 0.6 * kk), Art.bc("braise"), kk * 1.6)
		Ink.ember(ci, xf, Ink.oval(mouth, 2.2, 6.0, 12, aim), kk)
	# Nuage de cendre craché.
	if shot > 0.0:
		for i in 5:
			var u := 1.0 - shot
			var q := mouth + d * (6.0 + 30.0 * u) + n * (i - 2) * 5.0 * (0.4 + u)
			ci.draw_circle(xf * q, (4.0 + 6.0 * u) * xf.get_scale().abs().x, Color(Art.bc("commun", "clair").lerp(Art.bc("braise"), 0.4 * shot), 0.7 * shot))
