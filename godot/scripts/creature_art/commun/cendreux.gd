## Cendreux (commun, petit et rapide), direction « Bestiaire d'herbier » : une flammèche de cendre
## qui court sur deux pattes de brindille calcinée. Tête ronde, traîne de langues qui flottent vers
## l'arrière (plus longues quand il court), cœur de braise qui palpite à travers la cendre.
## Il frappe au contact : il se jette en avant, la flamme s'ouvre.
##
## Pose : t, walk, moving, k, strike (0 → 1, -1 : aucun), hit, look, elite, region.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const U = preload("res://scripts/creature_art/commun/_outils.gd")

## 100 unités en px du jeu (1600×900) : ~44 px de haut à l'écran en 1080p.
const HEIGHT := 37.0
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
	Ink.ground_shadow(ci, base, Vector2(0, 0), 20.0)
	var kk := Anim.ease_out(k)
	var sw := 0.0 if strike < 0.0 else sin(PI * clampf(strike, 0.0, 1.0))
	# Course : petits bonds rapides, penché en avant ; il flotte un peu au repos.
	var hop := -absf(sin(walk)) * 9.0 * mv - (1.0 - mv) * (2.0 + 1.5 * sin(t * TAU / 1.2))
	var lean := 0.28 * mv + 0.3 * sw - 0.12 * kk - 0.15 * hit
	var sq := Vector2(1.0 + 0.14 * hit + 0.1 * kk, 1.0 - 0.14 * hit - 0.1 * kk + 0.06 * absf(cos(walk)) * mv)
	var xf := base * Transform2D(lean, sq, 0.0, Vector2(0, -34)) * Transform2D(0.0, Vector2(6.0 * sw, 34 + hop))
	var bark := U.char_pal()
	# Pattes de brindille calcinée (la course les fait tourner vite).
	for i in 2:
		var ph := walk + PI * i
		var hip := xf * Vector2(-2 + i * 6, -22)
		var foot := Vector2(-2 + i * 6 + sin(ph) * 12.0 * mv, -maxf(cos(ph), 0.0) * 7.0 * mv)
		var hp := base.affine_inverse() * hip
		var knee := hp.lerp(foot, 0.5) + Vector2(6, -3)
		var col: Color = bark["clair"] if i == 1 else bark["ombre"]
		var pts := PackedVector2Array([hp, knee, foot])
		Ink.brush(ci, base, pts, 6.0, Ink.encre(), 1.0, 0.4)
		Ink.brush(ci, base, pts, 3.6, col, 1.0, 0.3)
		Ink.brush(ci, base, PackedVector2Array([foot, foot + Vector2(6, 0.5)]), 2.4, col, 1.0, 0.0)
	# Langues de la flamme : elles flottent vers l'arrière et haut, plus longues dans la course.
	var stretch := 1.0 + 0.5 * mv + 0.4 * sw
	var C0 := Vector2(4, -40)
	# Une flamme de cendre : tête ronde devant, une grande pointe qui monte et deux langues à l'arrière,
	# couchées par la course ; les pointes vacillent.
	var shear := 0.08 + 0.32 * mv * stretch
	var f1 := Vector2(2.5 * sin(t * 9.0), 1.5 * sin(t * 7.0))
	var f2 := Vector2(3.0 * sin(t * 11.0 + 1.0), 2.0 * sin(t * 8.0 + 2.0))
	var f3 := Vector2(2.0 * sin(t * 10.0 + 2.0), 2.0 * sin(t * 9.0 + 1.0))
	var ctrl := PackedVector2Array([
		Vector2(20, -62), Vector2(25, -44), Vector2(20, -28), Vector2(6, -20), Vector2(-10, -22), Vector2(-19, -32),
		Vector2(-42, -42) + f3, Vector2(-22, -50), Vector2(-38, -76) + f2, Vector2(-14, -66), Vector2(-8, -100) + f1, Vector2(6, -74),
	])
	var flame := _smooth(ctrl, 3)
	for i in flame.size():
		flame[i].x -= maxf(0.0, C0.y - flame[i].y) * shear
	if elite:
		U.elite_rim(ci, xf, flame, 2.4)
	Ink.part(ci, xf, flame, U.pal(), 2.4, 1.0, 0.7)
	# Les pointes s'éteignent : la cendre fonce vers le haut et l'arrière.
	if not Ink.mono:
		var w := xf * flame
		var cut := xf * PackedVector2Array([Vector2(-80, -58), Vector2(-4, -70), Vector2(30, -120), Vector2(-80, -140)])
		for poly in Geometry2D.intersect_polygons(w, cut):
			Ink.fill_world(ci, poly, {"clair": Art.bc("commun", "ombre").lerp(Art.bc("commun", "clair"), 0.35), "ombre": Art.bc("commun", "ombre")}, 0.6, 0.0)
	# Cœur de braise qui palpite à travers la cendre.
	if not Ink.mono:
		var pulse := 0.5 + 0.5 * sin(t * 7.0)
		var g := 0.5 + 0.5 * maxf(kk, sw)
		Ink.halo(ci, xf * Vector2(0, -38), 18.0 * xf.get_scale().abs().x, Art.bc("braise"), 0.8 + 0.6 * g)
		Ink.flat(ci, xf, Ink.lumpy(Vector2(0, -38), 7.0 + 1.2 * pulse, 8.0 + 1.2 * pulse, 16, 0.25, 4.0, t * 3.0), Color(Art.bc("braise"), 0.75))
		Ink.flat(ci, xf, Ink.oval(Vector2(0, -38), 3.5, 4.2, 12), Art.bc("braise_coeur").lerp(Color.WHITE, 0.3 * g))
	if elite:
		U.elite_collar(ci, xf, Vector2(6, -24), 14.0, 4.0, o.get("region", ""), t)
	# Visage : deux yeux de braise qui suivent la cible, la bouche s'ouvre dans le coup.
	var ha := clampf(la, -0.6, 0.6)
	var face := Vector2(12, -46) + Vector2(cos(ha), sin(ha)) * 3.0
	if sw > 0.0 or kk > 0.0:
		Ink.flat(ci, xf, Ink.oval(face + Vector2(6, 10), 4.0, 1.5 + 4.0 * maxf(sw, kk * 0.5), 12), Art.bc("ronge"))
	U.eyes(ci, xf, face, face + Vector2(10, -1), 9.0, 0.35 + 0.65 * maxf(kk, sw), hit, t, 1.4)
	# Braises qui se détachent de la traîne.
	Ink.sparks(ci, xf, Vector2(-18, -80), Vector2(-0.8, -0.6), 3, t * 1.6, 1.6, 0.9)
	U.ash(ci, xf, Vector2(-14, -94), 2, t, 1.8, 8.0)


## Lissage de Chaikin d'un contour fermé (n passes).
static func _smooth(p: PackedVector2Array, n: int) -> PackedVector2Array:
	for _i in n:
		var q := PackedVector2Array()
		for j in p.size():
			var a := p[j]
			var b := p[(j + 1) % p.size()]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	return p
