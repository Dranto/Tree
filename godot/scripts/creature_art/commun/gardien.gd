## Gardien d'écorce (commun, soutien), direction « Bestiaire d'herbier » : un vieil arbre mort, droit et
## haut, qui veille sur les autres Flétris. Il porte devant lui un grand écu d'écorce en croissant, gravé
## d'un nœud de racine ; au-dessus de sa tête, une couronne de braises tourne lentement (le halo du
## soutien : tant qu'il est là, les Flétris autour de lui encaissent moins). Il ne charge pas.
##
## Pose : t, walk, moving, hit, look, elite, region.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const U = preload("res://scripts/creature_art/commun/_outils.gd")

## 100 unités en px du jeu (1600×900) : ~62 px de haut à l'écran en 1080p.
const HEIGHT := 52.0
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
	Ink.ground_shadow(ci, base, Vector2(4, 0), 30.0)
	var sw := 0.0 if strike < 0.0 else sin(PI * clampf(strike, 0.0, 1.0))
	# Pas lents et raides ; sous un coup, il se cale derrière son écu.
	var bob := -absf(sin(walk)) * 2.5 * mv + sin(t * TAU / 3.2) * 0.6
	var sq := Vector2(1.0 + 0.06 * hit, 1.0 - 0.07 * hit)
	var xf := base * Transform2D(0.03 * sin(walk) * mv - 0.06 * hit + 0.08 * sw, sq, 0.0, Vector2(0, -2)) * Transform2D(0.0, Vector2(0, bob))
	var bark := U.char_pal()
	var far_bark := {"clair": bark["ombre"], "ombre": bark["ombre"].darkened(0.3)}
	var ash := U.pal()
	# Halo du soutien : une couronne de braises qui tourne au-dessus de lui (derrière, puis devant).
	_crown(ci, xf, t, true)
	# Racines-pieds (celle du fond plus sombre).
	var step := sin(walk) * 6.0 * mv
	Ink.part(ci, base, _foot(Vector2(10 - step, -maxf(-sin(walk), 0.0) * 4.0 * mv)), far_bark, 2.0, 1.0, 0.0)
	Ink.part(ci, base, _foot(Vector2(-8 + step, -maxf(sin(walk), 0.0) * 4.0 * mv)), bark, 2.0, 1.0, 0.2)
	# Le tronc, haut et droit, deux branches mortes en couronne.
	for br: Array in [[Vector2(-8, -86), Vector2(-22, -100), Vector2(-26, -98)], [Vector2(4, -88), Vector2(10, -100), Vector2(16, -104)]]:
		var pts := PackedVector2Array(br)
		Ink.brush(ci, xf, pts, 6.4, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, xf, pts, 4.0, bark["clair"], 1.0, 0.0)
	var trunk := PackedVector2Array([Vector2(-14, -12), Vector2(-18, -30), Vector2(-15, -50), Vector2(-17, -70), Vector2(-12, -86), Vector2(-2, -92), Vector2(10, -88), Vector2(16, -74), Vector2(14, -52), Vector2(16, -30), Vector2(12, -12), Vector2(-2, -8)])
	if elite:
		U.elite_rim(ci, xf, trunk, 2.6)
	Ink.part(ci, xf, trunk, ash, 2.6, 1.0, 0.6)
	# Écorce en plaques de charbon, du bas vers le haut, la braise dans les joints.
	var low := PackedVector2Array([Vector2(-14, -12), Vector2(-18, -30), Vector2(-16, -44), Vector2(-6, -40), Vector2(4, -45), Vector2(15, -40), Vector2(16, -30), Vector2(12, -12), Vector2(-2, -8)])
	Ink.fill_world(ci, xf * low, bark, 0.5, 0.0)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-16, -44), Vector2(-6, -40), Vector2(4, -45), Vector2(15, -40)]), 1.6, Art.bc("commun", "reflet"))
	for c: PackedVector2Array in [PackedVector2Array([Vector2(-14, -30), Vector2(-6, -27), Vector2(3, -31), Vector2(12, -28)]), PackedVector2Array([Vector2(-6, -40), Vector2(-8, -33), Vector2(-5, -27)]), PackedVector2Array([Vector2(4, -30), Vector2(6, -22), Vector2(3, -14)])]:
		U.crack(ci, xf, c, 1.3, 0.5, t + c[0].x)
	for g: Array in [[Vector2(-10, -54), Vector2(-12, -80)], [Vector2(-2, -52), Vector2(0, -84)], [Vector2(8, -56), Vector2(10, -78)]]:
		Ink.brush(ci, xf, PackedVector2Array(g), 1.3, Art.bc("commun", "ombre"))
	# Masque de bois : un nœud creusé, deux fentes de braise qui suivent la cible.
	var ha := clampf(la, -0.5, 0.5) * 0.5
	var hx := xf * Transform2D(ha, Vector2(2, -76))
	Ink.part(ci, hx, Ink.lumpy(Vector2(4, 0), 10.0, 8.0, 18, 0.08, 4.0), {"clair": Art.bc("ronge").lightened(0.1), "ombre": Art.bc("ronge")}, 1.2, 0.5, 0.0)
	U.eyes(ci, hx, Vector2(6, -1), Vector2(12, -2), 6.0, 0.35 + 0.5 * sw, hit, t, 3.1)
	if elite:
		U.elite_collar(ci, xf, Vector2(0, -66), 16.0, 4.5, o.get("region", ""), t)
	# L'écu d'écorce, tenu devant lui (il se lève un peu quand il est frappé).
	var sh := xf * Transform2D(0.08 - 0.1 * hit, Vector2(16, -40 - 4.0 * hit))
	_shield(ci, sh, t, hit)
	# Bras de devant, la main posée sur le bord de l'écu.
	var arm := PackedVector2Array([Vector2(-10, -64), Vector2(-12, -50), Vector2(0, -44)])
	Ink.brush(ci, xf, arm, 7.0, Ink.encre(), 1.0, 0.6)
	Ink.brush(ci, xf, arm, 4.6, bark["clair"], 1.0, 0.5)
	Ink.part(ci, xf, Ink.lumpy(Vector2(1, -44), 4.5, 4.0, 12, 0.15, 3.0), bark, 1.4, 1.0, 0.0)
	_crown(ci, xf, t, false)


## Pied-racine : une souche évasée au sol (centre p, local).
static func _foot(p: Vector2) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(-6, -16), p + Vector2(6, -16), p + Vector2(8, -6), p + Vector2(13, -1), p + Vector2(4, 1), p + Vector2(-5, 1), p + Vector2(-12, -1), p + Vector2(-8, -6)])


## Écu en croissant (repère de l'écu : centre en 0, convexe vers l'avant), gravé d'un nœud de racine.
static func _shield(ci: CanvasItem, xf: Transform2D, t: float, hit: float) -> void:
	# Un écu ovale d'écorce, vu de trois quarts, un peu pointu en bas.
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var p := Vector2(cos(a) * 17.0, sin(a) * 32.0)
		if p.y > 0.0:
			p.x *= 1.0 - 0.35 * (p.y / 32.0)
		pts.append(p)
	var wood := {"clair": Art.bc("os").lerp(Art.bc("commun", "clair"), 0.55), "ombre": Art.bc("commun", "ombre").lerp(Art.bc("commun", "clair"), 0.3), "reflet": Art.bc("commun", "reflet")}
	Ink.part(ci, xf, pts, wood, 2.8, 1.0, 0.8)
	# Cernes du bois, bord de charbon, nœud gravé de braise.
	for j in 3:
		var arc := PackedVector2Array()
		for i in 7:
			var a := -0.9 + i * 1.8 / 6.0
			arc.append(Vector2(-2 - j * 2.0, 0) + Vector2(cos(a) * (12.0 - j * 3.0), sin(a) * (26.0 - j * 6.0)))
		Ink.brush(ci, xf, arc, 1.2, Art.bc("commun", "ombre"))
	var rim := PackedVector2Array()
	for i in 15:
		var a := -PI * 0.55 + i * PI * 1.1 / 14.0
		var p := Vector2(cos(a) * 15.0, sin(a) * 30.0)
		if p.y > 0.0:
			p.x *= 1.0 - 0.35 * (p.y / 32.0)
		rim.append(p)
	Ink.brush(ci, xf, rim, 3.4, Art.bc("commun", "charbon"), 0.0, 0.0)
	var knot := PackedVector2Array([Vector2(1, -14), Vector2(-1, -4), Vector2(2, 4), Vector2(-1, 14)])
	U.crack(ci, xf, knot, 1.8, 0.5 + 0.5 * hit, t)
	U.crack(ci, xf, PackedVector2Array([Vector2(-1, -4), Vector2(-7, -8)]), 1.3, 0.5 + 0.5 * hit, t + 1.0)
	U.crack(ci, xf, PackedVector2Array([Vector2(2, 4), Vector2(8, 9)]), 1.3, 0.5 + 0.5 * hit, t + 2.0)


## Couronne de braises du soutien : six braises sur une ellipse au-dessus de la tête, qui tournent ;
## back : celles de derrière (avant le corps), sinon celles de devant.
static func _crown(ci: CanvasItem, xf: Transform2D, t: float, back: bool) -> void:
	if Ink.mono:
		return
	var c := Vector2(0, -108)
	if back:
		Ink.halo(ci, xf * c, 20.0 * xf.get_scale().abs().x, Art.bc("braise"), 0.5)
	for i in 6:
		var a := t * 0.9 + i * TAU / 6.0
		var behind := sin(a) < 0.0
		if behind != back:
			continue
		var q := c + Vector2(cos(a) * 18.0, sin(a) * 5.0)
		var s := 2.0 + 0.6 * sin(a)
		Ink.ember(ci, xf, Ink.leaf(q + Vector2(0, s), -PI / 2.0, s * 2.6, s * 1.4), 0.5 + 0.3 * sin(t * 4.0 + i))
