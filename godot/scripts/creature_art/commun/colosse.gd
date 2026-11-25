## Colosse (commun, lourd), direction « Bestiaire d'herbier » : une souche géante calcinée qui s'est levée.
## Large et ancrée : un tronc court et massif, des épaules de bois noir d'où partent des branches mortes,
## deux bras très longs aux poings de nœuds qui touchent presque le sol. La tête est un creux dans le
## bois, où brillent deux petits yeux de braise ; une grande fente rougeoie dans la poitrine.
## Il frappe au contact : il abat ses deux poings.
##
## Pose : t, walk, moving, k, strike (0 → 1, -1 : aucun), hit, look, elite, region.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const U = preload("res://scripts/creature_art/commun/_outils.gd")

## 100 unités en px du jeu (1600×900) : ~86 px de haut à l'écran en 1080p.
const HEIGHT := 72.0
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
	Ink.ground_shadow(ci, base, Vector2(4, 0), 44.0)
	var kk := Anim.ease_out(k)
	var slam := 0.0 if strike < 0.0 else 1.0 - clampf(strike, 0.0, 1.0)
	var up := maxf(kk, 0.0) * (1.0 - slam)
	# Onde de choc au sol quand les poings tombent.
	if slam > 0.0 and not Ink.mono:
		var u := 1.0 - slam
		var ring := Ink.oval(Vector2(34, 0), 18.0 + 40.0 * u, (18.0 + 40.0 * u) * Art.OMBRE_APLATI, 32)
		ring.append(ring[0])
		ci.draw_polyline(base * ring, Color(Art.bc("braise"), 0.8 * slam), 3.0 * h / 100.0, true)
	# Démarche : il roule d'une épaule à l'autre, lourdement.
	var roll := sin(walk) * 0.06 * mv
	var bob := -absf(sin(walk)) * 3.0 * mv + sin(t * TAU / 3.0) * 0.8
	var sq := Vector2(1.0 + 0.06 * hit + 0.05 * slam, 1.0 - 0.07 * hit - 0.06 * slam + 0.03 * up)
	var xf := base * Transform2D(roll - 0.06 * up + 0.08 * slam + 0.04 * hit, sq, 0.0, Vector2(0, -6)) * Transform2D(0.0, Vector2(0, bob - 4.0 * up))
	var bark := U.char_pal()
	var far_bark := {"clair": bark["ombre"], "ombre": bark["ombre"].darkened(0.3), "reflet": bark["clair"]}
	var ash := U.pal()
	var lift_l := maxf(sin(walk), 0.0) * 5.0 * mv
	var lift_r := maxf(-sin(walk), 0.0) * 5.0 * mv
	# Poings : au sol à la marche, levés au-dessus de la tête pendant l'annonce, écrasés à la frappe.
	var swing := sin(walk) * 6.0 * mv
	var fist_far := Vector2(44 - swing, -14).lerp(Vector2(30, -112), up).lerp(Vector2(52, -10), slam)
	var fist_near := Vector2(-2 + swing, -12).lerp(Vector2(10, -116), up).lerp(Vector2(40, -8), slam)
	_arm(ci, xf, Vector2(24, -70), fist_far, far_bark, 15.0)
	# Jambes courtes : deux racines en souche.
	Ink.part(ci, base, _stump_leg(Vector2(14, -lift_r)), far_bark, 2.4, 1.0, 0.0)
	Ink.part(ci, base, _stump_leg(Vector2(-12, -lift_l)), bark, 2.4, 1.0, 0.3)
	# Le tronc : une souche large, plus large aux épaules, bord éclaté.
	var trunk := PackedVector2Array([Vector2(-30, -14), Vector2(-36, -34), Vector2(-34, -56), Vector2(-40, -70), Vector2(-30, -84), Vector2(-12, -90), Vector2(6, -88), Vector2(26, -86), Vector2(38, -74), Vector2(34, -58), Vector2(30, -36), Vector2(24, -14), Vector2(0, -10)])
	if elite:
		U.elite_rim(ci, xf, trunk, 3.2)
	Ink.part(ci, xf, trunk, ash, 3.2, 1.0, 0.6)
	# Le bas calciné : charbon craquelé, la braise dans les joints (comme le Flétri).
	var low := PackedVector2Array([Vector2(-30, -14), Vector2(-36, -34), Vector2(-35, -46), Vector2(-24, -42), Vector2(-12, -46), Vector2(0, -41), Vector2(12, -46), Vector2(24, -42), Vector2(32, -46), Vector2(30, -36), Vector2(24, -14), Vector2(0, -10)])
	Ink.fill_world(ci, xf * low, bark, 0.6, 0.0)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-35, -46), Vector2(-24, -42), Vector2(-12, -46), Vector2(0, -41), Vector2(12, -46), Vector2(24, -42), Vector2(32, -46)]), 2.0, Art.bc("commun", "reflet"))
	for c: PackedVector2Array in [
		PackedVector2Array([Vector2(-32, -30), Vector2(-22, -27), Vector2(-12, -31), Vector2(-2, -27), Vector2(10, -31), Vector2(22, -27), Vector2(29, -30)]),
		PackedVector2Array([Vector2(-22, -42), Vector2(-24, -34), Vector2(-21, -27)]), PackedVector2Array([Vector2(12, -45), Vector2(9, -37), Vector2(11, -30)]),
		PackedVector2Array([Vector2(-14, -28), Vector2(-12, -20), Vector2(-15, -13)]), PackedVector2Array([Vector2(6, -27), Vector2(4, -19), Vector2(7, -12)]),
	]:
		U.crack(ci, xf, c, 2.0, 0.5 + 0.5 * maxf(up, slam), t + c[0].x)
	# Écorce en long, fendue de braise : une grande fente dans la poitrine (elle s'ouvre avant le coup).
	for g: Array in [[Vector2(-30, -52), Vector2(-28, -76)], [Vector2(-18, -50), Vector2(-16, -80)], [Vector2(18, -50), Vector2(20, -78)], [Vector2(28, -54), Vector2(30, -74)]]:
		Ink.brush(ci, xf, PackedVector2Array(g), 1.6, Art.bc("commun", "ombre"))
	var glow := 0.45 + 0.55 * maxf(up, slam)
	var chest := PackedVector2Array([Vector2(4, -74), Vector2(-2, -64), Vector2(4, -54), Vector2(0, -44)])
	U.crack(ci, xf, chest, 2.6 + 1.6 * up, glow, t)
	U.crack(ci, xf, PackedVector2Array([Vector2(-2, -64), Vector2(-12, -58), Vector2(-20, -60)]), 1.6, glow, t + 1.0)
	U.crack(ci, xf, PackedVector2Array([Vector2(4, -54), Vector2(14, -50), Vector2(20, -52)]), 1.6, glow, t + 2.0)
	if not Ink.mono and up > 0.0:
		Ink.halo(ci, xf * Vector2(2, -58), 30.0 * h / 100.0, Art.bc("braise"), up)
	# Branches mortes cassées sur les épaules, cendre qui monte.
	Ink.part(ci, xf, PackedVector2Array([Vector2(-30, -80), Vector2(-46, -104), Vector2(-42, -107), Vector2(-36, -100), Vector2(-34, -112), Vector2(-30, -110), Vector2(-30, -98), Vector2(-20, -86)]), bark, 2.0, 1.0, 0.0)
	Ink.part(ci, xf, PackedVector2Array([Vector2(16, -86), Vector2(22, -104), Vector2(26, -103), Vector2(24, -88)]), bark, 1.8, 1.0, 0.0)
	Ink.flat(ci, xf, Ink.oval(Vector2(-32, -111), 2.2, 1.4, 10, -0.3), Art.bc("braise"))
	U.ash(ci, xf, Vector2(-32, -112), 4, t, 2.6, 16.0)
	# La tête : un creux sombre entre les épaules, qui se tourne un peu vers la cible.
	var ha := clampf(la, -0.5, 0.5) * 0.5
	var hx := xf * Transform2D(ha, Vector2(12, -74))
	var hollow := Ink.lumpy(Vector2(4, 0), 13.0, 9.0, 20, 0.1, 5.0)
	Ink.part(ci, hx, hollow, {"clair": Art.bc("ronge"), "ombre": Art.bc("ronge").darkened(0.4)}, 1.2, 0.4, 0.0)
	# Arcade de bois au-dessus des yeux.
	Ink.brush(ci, hx, PackedVector2Array([Vector2(-10, -7), Vector2(4, -10), Vector2(18, -6)]), 4.0, bark["clair"], 0.6, 0.6)
	U.eyes(ci, hx, Vector2(5, -1), Vector2(13, -2), 6.0, 0.3 + 0.7 * maxf(up, slam), hit, t, 2.2)
	if elite:
		U.elite_collar(ci, xf, Vector2(6, -76), 26.0, 7.0, o.get("region", ""), t)
	_arm(ci, xf, Vector2(-20, -72), fist_near, bark, 17.0)


## Jambe-souche : une racine trapue qui s'évase au sol (pied en p, local).
static func _stump_leg(p: Vector2) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(-9, -26), p + Vector2(9, -26), p + Vector2(11, -8), p + Vector2(16, -1), p + Vector2(6, 1), p + Vector2(0, -2), p + Vector2(-8, 1), p + Vector2(-16, -1), p + Vector2(-11, -8)])


## Bras de bois noir (épaule → poing), long et noueux, et son poing de nœuds aux jointures d'os.
static func _arm(ci: CanvasItem, xf: Transform2D, shoulder: Vector2, fist: Vector2, col: Dictionary, r: float) -> void:
	var elbow := shoulder.lerp(fist, 0.5) + (fist - shoulder).orthogonal().normalized() * -9.0
	var pts := PackedVector2Array([shoulder, elbow, fist])
	Ink.brush(ci, xf, pts, 17.0, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, pts, 13.0, col["clair"], 1.0, 1.0)
	Ink.brush(ci, xf, PackedVector2Array([shoulder.lerp(elbow, 0.2) + Vector2(-3, -2), elbow + Vector2(-3, -2)]), 2.4, col["clair"].lightened(0.25))
	U.crack(ci, xf, PackedVector2Array([elbow + Vector2(-2, -4), elbow + Vector2(2, 4)]), 1.2, 0.5)
	Ink.part(ci, xf, Ink.lumpy(fist, r, r * 0.85, 22, 0.14, 5.0, 0.4), col, 2.6, 1.0, 0.4)
	for j in 3:
		var q := fist + Vector2(r * 0.55, -r * 0.45 + j * r * 0.42)
		Ink.part(ci, xf, Ink.thorn(q, -0.3 + j * 0.3, 6.0, 4.0), U.bone(), 1.0, 1.0, 0.0)
