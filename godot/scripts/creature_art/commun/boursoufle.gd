## Boursouflé (commun, poche), direction « Bestiaire d'herbier » : une galle d'écorce morte, gonflée
## jusqu'à éclater, qui trottine sur quatre pattes de brindille. Sa peau de cendre est tendue, crevée de
## pustules de spores violettes qui s'allument tour à tour ; à sa mort, la poche éclate (annonce au sol).
## Il respire en enflant ; plus il est blessé, plus il gonfle (pose hit).
##
## Pose : t, walk, moving, strike, hit, look, elite, region.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const U = preload("res://scripts/creature_art/commun/_outils.gd")

## 100 unités en px du jeu (1600×900) : ~58 px de haut à l'écran en 1080p.
const HEIGHT := 48.0
const DRAWS_ELITE := true


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var strike: float = o.get("strike", -1.0)
	var elite: bool = o.get("elite", false)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	Ink.ground_shadow(ci, base, Vector2(0, 0), 34.0)
	var sw := 0.0 if strike < 0.0 else sin(PI * clampf(strike, 0.0, 1.0))
	# Respiration : la poche enfle et se dégonfle ; un coup la fait gonfler d'un coup.
	var swell := 1.0 + 0.05 * sin(t * TAU / 1.4) + 0.12 * hit + 0.06 * sw
	var bob := -absf(sin(walk * 1.6)) * 3.0 * mv
	var wob := 0.05 * sin(walk * 1.6) * mv
	var xf := base * Transform2D(wob, Vector2.ONE, 0.0, Vector2(0, bob))
	var bark := U.char_pal()
	var far_bark := {"clair": bark["ombre"], "ombre": bark["ombre"].darkened(0.3)}
	# Pattes : quatre brindilles qui trottinent (celles du fond d'abord).
	for i in 4:
		var far := i < 2
		var x := (-16.0 if i % 2 == 0 else 14.0) + (6.0 if far else 0.0)
		var ph := walk * 1.6 + i * PI * 0.5
		var hip := xf * Vector2(x, -22)
		var foot := Vector2(x + sin(ph) * 6.0 * mv, -maxf(cos(ph), 0.0) * 4.0 * mv)
		var hp := base.affine_inverse() * hip
		var knee := hp.lerp(foot, 0.5) + Vector2(4 if x > 0 else -4, -2)
		var col: Color = (far_bark if far else bark)["clair"]
		var pts := PackedVector2Array([hp, knee, foot])
		Ink.brush(ci, base, pts, 6.4, Ink.encre(), 1.0, 0.4)
		Ink.brush(ci, base, pts, 4.0, col, 1.0, 0.3)
	# La poche : une boule bosselée, gonflée.
	var cen := Vector2(0, -52)
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var bump := 0.0
		for j in 7:
			var d := absf(wrapf(a - (j * TAU / 7.0 + 0.4), -PI, PI))
			bump = maxf(bump, 0.1 * maxf(0.0, 1.0 - d / 0.38))
		pts.append(cen + Vector2(cos(a) * 34.0, sin(a) * 31.0) * swell * (1.0 + bump))
	if elite:
		U.elite_rim(ci, xf, pts, 2.6)
	Ink.part(ci, xf, pts, U.pal(), 2.6, 1.0, 0.8)
	# Écorce brûlée qui tient encore le bas de la poche, et les vergetures de la peau tendue.
	var low := PackedVector2Array()
	for i in 21:
		var a := PI * 0.05 + i * PI * 0.9 / 20.0
		low.append(cen + Vector2(cos(a) * 34.0, sin(a) * 31.0) * swell * 1.02)
	low.append(cen + Vector2(-24, 14) * swell)
	low.append(cen + Vector2(-10, 8) * swell)
	low.append(cen + Vector2(4, 12) * swell)
	low.append(cen + Vector2(18, 7) * swell)
	low.reverse()
	for poly in Geometry2D.intersect_polygons(xf * pts, xf * low):
		Ink.fill_world(ci, poly, bark, 0.4, 0.0)
	U.crack(ci, xf, PackedVector2Array([cen + Vector2(-26, 16) * swell, cen + Vector2(-12, 12) * swell, cen + Vector2(2, 15) * swell, cen + Vector2(18, 10) * swell]), 1.4, 0.4, t)
	for s: Array in [[Vector2(-20, -18), Vector2(-8, -26)], [Vector2(6, -28), Vector2(16, -20)], [Vector2(-28, -2), Vector2(-24, -14)]]:
		Ink.brush(ci, xf, PackedVector2Array([cen + s[0] * swell, cen + s[1] * swell]), 1.2, Art.bc("commun", "ombre"))
	# Pustules de spores, qui s'allument tour à tour (signe de la poche qui éclatera).
	if not Ink.mono:
		var spore := Art.ec("poison")
		for j in 6:
			var p: Vector2 = [Vector2(-18, -14), Vector2(-2, -22), Vector2(14, -10), Vector2(-26, 2), Vector2(-8, -4), Vector2(22, 4)][j]
			var q := cen + p * swell
			var g := 0.5 + 0.5 * sin(t * 4.0 + j * 1.7)
			var r := (4.2 if j % 2 == 0 else 3.2) * (1.0 + 0.15 * g)
			Ink.part(ci, xf, Ink.oval(q, r, r * 0.9, 12), {"clair": spore.lightened(0.1), "ombre": spore.darkened(0.35), "reflet": Art.ec("poison", "clair")}, 1.2, 1.0, 0.6)
			Ink.flat(ci, xf, Ink.oval(q + Vector2(-0.4, -0.6), r * 0.45, r * 0.4, 8), Color(Art.ec("poison", "clair"), 0.4 + 0.6 * g))
		# Bulles de spores qui s'échappent.
		for i in 2:
			var u := fposmod(t * 0.7 + i * 0.5, 1.0)
			var q := xf * (cen + Vector2(-8 + i * 18 + sin(t * 2.0 + i * 3.0) * 6.0, -30 - 30.0 * u))
			ci.draw_arc(q, (2.0 + 2.6 * u) * xf.get_scale().abs().x, 0.0, TAU, 12, Color(Art.ec("poison", "clair"), 0.8 * (1.0 - u)), 1.2 * xf.get_scale().abs().x, true)
	if elite:
		U.elite_collar(ci, xf, cen + Vector2(18, 0), 10.0, 14.0, o.get("region", ""), t)
	# Petite tête enfoncée devant, en bas de la poche : deux yeux de braise, une bouche qui bave.
	var ha := clampf(la, -0.5, 0.5) * 0.4
	var hx := xf * Transform2D(ha, cen + Vector2(26, 14) * swell)
	Ink.part(ci, hx, Ink.lumpy(Vector2(2, 0), 12.0, 9.0, 18, 0.08, 4.0), bark, 2.0, 1.0, 0.4)
	U.eyes(ci, hx, Vector2(4, -3), Vector2(10, -4), 6.0, 0.3 + 0.6 * sw, hit, t, 4.4)
	Ink.brush(ci, hx, PackedVector2Array([Vector2(2, 4), Vector2(7, 5 + 2.0 * sw), Vector2(12, 3)]), 1.8, Ink.encre())
	if not Ink.mono:
		var u := fposmod(t * 0.6, 1.0)
		Ink.flat(ci, hx, Ink.oval(Vector2(8, 6 + 6.0 * u), 1.4, 1.4 + 2.0 * u, 8), Color(Art.ec("poison", "clair"), 0.8 * (1.0 - u)))
