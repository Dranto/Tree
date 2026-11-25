## Flétri (commun, mêlée), direction « Bestiaire d'herbier » : la Flétrissure pure qui a pris forme.
## Un jeune arbre mort, voûté, calciné, qui marche sur deux racines-pattes ; l'écorce brûlée se fend sur
## la braise, une croûte de cendre pâle le couvre du côté de la lumière. Deux longues griffes d'os en
## avant : il frappe au contact. Sa tête est un nœud du bois qui suit la cible.
##
## Pose : t, walk, moving, k (ramassé 0 → 1), strike (coup de griffe 0 → 1, -1 : aucun), hit, look,
## elite, region.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const U = preload("res://scripts/creature_art/commun/_outils.gd")

## 100 unités en px du jeu (1600×900) : ~50 px de haut à l'écran en 1080p.
const HEIGHT := 42.0
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
	Ink.ground_shadow(ci, base, Vector2(2, 0), 24.0)
	var kk := Anim.ease_out(k)
	var sw := 0.0 if strike < 0.0 else sin(PI * clampf(strike, 0.0, 1.0))
	# Démarche voûtée : il tangue en avant à chaque pas ; ramassé avant de frapper, projeté dans le coup.
	var bob := -absf(sin(walk)) * 4.0 * mv + sin(t * TAU / 2.6) * 0.9
	var lean := 0.1 + 0.06 * absf(sin(walk)) * mv - 0.1 * kk + 0.22 * sw - 0.12 * hit
	var sq := Vector2(1.0 + 0.1 * hit + 0.05 * kk, 1.0 - 0.12 * hit - 0.06 * kk)
	var xf := base * Transform2D(lean, sq, 0.0, Vector2(0, -26)) * Transform2D(0.0, Vector2(0, 26 + bob))
	var bark := U.char_pal()
	var far_bark := {"clair": bark["ombre"], "ombre": bark["ombre"].darkened(0.3)}
	var step := sin(walk) * 9.0 * mv
	# Patte du fond, bras du fond (sa griffe part un peu après l'autre).
	_leg(ci, base, xf * Vector2(4, -30), Vector2(10 - step, -maxf(-sin(walk), 0.0) * 5.0 * mv), far_bark)
	_arm(ci, xf, Vector2(16, -70), lerpf(-0.3, -0.05, kk) + 0.9 * sw * 0.8 - 0.18 * sin(walk) * mv, far_bark, true)
	# Le tronc voûté, bord éclaté d'échardes : cendre pâle en haut, charbon en bas.
	var trunk := PackedVector2Array([Vector2(-15, -28), Vector2(-19, -40), Vector2(-24, -46), Vector2(-20, -52), Vector2(-23, -64), Vector2(-17, -70), Vector2(-15, -80), Vector2(-6, -84), Vector2(4, -92), Vector2(12, -86), Vector2(21, -82), Vector2(20, -72), Vector2(24, -64), Vector2(17, -56), Vector2(16, -44), Vector2(11, -36), Vector2(11, -28), Vector2(-2, -24)])
	if elite:
		U.elite_rim(ci, xf, trunk, 2.6)
	Ink.part(ci, xf, trunk, U.pal(), 2.6, 1.0, 0.6)
	# Le bas calciné : charbon craquelé en écailles, la braise dans les joints (écorce brûlée).
	var low := PackedVector2Array([Vector2(-15, -28), Vector2(-19, -40), Vector2(-24, -46), Vector2(-20, -52), Vector2(-12, -50), Vector2(-4, -54), Vector2(6, -50), Vector2(12, -55), Vector2(17, -56), Vector2(16, -44), Vector2(11, -36), Vector2(11, -28), Vector2(-2, -24)])
	Ink.fill_world(ci, xf * low, bark, 0.6, 0.0)
	var glow := 0.4 + 0.6 * maxf(kk, sw)
	for c: PackedVector2Array in [
		PackedVector2Array([Vector2(-19, -45), Vector2(-12, -41), Vector2(-6, -44), Vector2(1, -40), Vector2(8, -44), Vector2(15, -47)]),
		PackedVector2Array([Vector2(-15, -33), Vector2(-9, -35), Vector2(-3, -31), Vector2(4, -34), Vector2(10, -31)]),
		PackedVector2Array([Vector2(-11, -50), Vector2(-12, -46), Vector2(-9, -41)]), PackedVector2Array([Vector2(3, -52), Vector2(0, -46), Vector2(1, -40)]),
		PackedVector2Array([Vector2(-6, -43), Vector2(-4, -38), Vector2(-7, -33)]), PackedVector2Array([Vector2(8, -43), Vector2(6, -37), Vector2(8, -32)]),
		PackedVector2Array([Vector2(-1, -31), Vector2(-3, -25)]),
	]:
		U.crack(ci, xf, c, 1.4, glow, t + c[0].x)
	# Bord de la croûte de cendre, qui s'effrite sur le charbon.
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-21, -51), Vector2(-12, -49), Vector2(-4, -53), Vector2(6, -49), Vector2(16, -55)]), 1.6, Art.bc("commun", "reflet"))
	# Veines du bois mort dans la cendre, et une grande fente de braise qui monte vers le cœur.
	for g: Array in [[Vector2(-15, -60), Vector2(-12, -76)], [Vector2(-5, -62), Vector2(-3, -80)], [Vector2(10, -64), Vector2(12, -80)]]:
		Ink.brush(ci, xf, PackedVector2Array(g), 1.3, Art.bc("commun", "ombre"))
	U.crack(ci, xf, PackedVector2Array([Vector2(4, -52), Vector2(2, -60), Vector2(6, -66), Vector2(4, -72)]), 1.6, glow, t)
	Ink.sparks(ci, xf, Vector2(4, -62), Vector2(0.2, -1.0), 2, t, 1.2, 0.4 + 0.6 * glow)
	# Deux branches mortes cassées sur le dos, d'où monte la cendre.
	Ink.part(ci, xf, PackedVector2Array([Vector2(-14, -74), Vector2(-27, -94), Vector2(-24, -98), Vector2(-20, -92), Vector2(-8, -80)]), bark, 1.8, 1.0, 0.0)
	Ink.part(ci, xf, PackedVector2Array([Vector2(-20, -62), Vector2(-34, -70), Vector2(-33, -74), Vector2(-18, -68)]), bark, 1.6, 1.0, 0.0)
	Ink.flat(ci, xf, Ink.oval(Vector2(-25.5, -96), 2.4, 1.5, 10, -0.9), Art.bc("braise"))
	U.ash(ci, xf, Vector2(-25, -98), 3, t, 2.0, 10.0)
	if elite:
		U.elite_collar(ci, xf, Vector2(8, -80), 13.0, 5.0, o.get("region", ""), t)
	# La tête : un nœud du bois qui suit la cible, deux fentes de braise, une bouche fendue.
	var ha := clampf(la, -0.6, 0.6) * 0.6 - 0.06 * kk
	var hx := xf * Transform2D(ha, Vector2(14, -84))
	var head := PackedVector2Array([Vector2(-8, -2), Vector2(-6, -10), Vector2(2, -13), Vector2(12, -11), Vector2(20, -6), Vector2(25, -1), Vector2(22, 5), Vector2(12, 8), Vector2(0, 8), Vector2(-6, 5)])
	if elite:
		U.elite_rim(ci, hx, head, 2.2)
	# Cornes de bois mort (derrière la tête), fourchues.
	for hb: Array in [[Vector2(-2, -8), -2.0, 15.0], [Vector2(6, -11), -1.55, 12.0]]:
		var r0: Vector2 = hb[0]
		var tip: Vector2 = r0 + Vector2.from_angle(hb[1]) * hb[2]
		var fork: Vector2 = r0.lerp(tip, 0.55)
		Ink.brush(ci, hx, PackedVector2Array([r0, r0.lerp(tip, 0.5) + Vector2(-2, 0), tip]), 4.8, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, hx, PackedVector2Array([r0, r0.lerp(tip, 0.5) + Vector2(-2, 0), tip]), 2.8, bark["clair"], 1.0, 0.0)
		Ink.brush(ci, hx, PackedVector2Array([fork, fork + Vector2.from_angle(hb[1] + 0.9) * 6.0]), 3.6, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, hx, PackedVector2Array([fork, fork + Vector2.from_angle(hb[1] + 0.9) * 6.0]), 1.9, bark["clair"], 1.0, 0.0)
	Ink.part(ci, hx, head, U.pal(), 2.2, 1.0, 0.8)
	Ink.flat(ci, hx, PackedVector2Array([Vector2(-6, 2), Vector2(4, 6), Vector2(18, 2), Vector2(14, 7), Vector2(0, 8)]), bark["clair"])
	var mouth := PackedVector2Array([Vector2(6, 4), Vector2(11, 5 + 2.0 * kk + 3.0 * sw), Vector2(18, 3)])
	Ink.brush(ci, hx, mouth, 2.2 + 1.6 * maxf(kk, sw), Ink.encre(), 0.6, 0.6)
	U.eyes(ci, hx, Vector2(11, -4), Vector2(18.5, -5), 7.0, 0.3 + 0.7 * maxf(kk, sw), hit, t, 0.7)
	# Patte et bras de devant.
	_leg(ci, base, xf * Vector2(-8, -30), Vector2(-8 + step, -maxf(sin(walk), 0.0) * 5.0 * mv), bark)
	_arm(ci, xf, Vector2(4, -68), lerpf(-0.1, 0.2, kk) + 1.0 * sw + 0.18 * sin(walk) * mv, bark, false)
	# Traînée du coup de griffe.
	if sw > 0.0 and not Ink.mono:
		var arc := PackedVector2Array()
		for i in 7:
			var a := -0.9 + i * 0.3
			arc.append(Vector2(8, -66) + Vector2.from_angle(a) * 42.0)
		Ink.brush(ci, xf, arc, 5.0 * sw, Color(Art.bc("braise_coeur"), 0.75 * sw))


## Racine-patte (hanche à l'écran → pied local au sol), digitigrade : genou vers l'avant.
static func _leg(ci: CanvasItem, base: Transform2D, hip_w: Vector2, foot: Vector2, col: Dictionary) -> void:
	var hip := base.affine_inverse() * hip_w
	var knee := hip.lerp(foot, 0.45) + Vector2(6, -2)
	var heel := foot + Vector2(-5, -7)
	var pts := PackedVector2Array([hip, knee, heel, foot])
	Ink.brush(ci, base, pts, 8.5, Ink.encre(), 1.0, 0.5)
	Ink.brush(ci, base, pts, 6.0, col["clair"], 1.0, 0.4)
	# Radicelles-griffes au pied.
	for s: float in [-1.0, 0.4, 1.0]:
		Ink.brush(ci, base, PackedVector2Array([foot + Vector2(0, -1), foot + Vector2(4.0 + s * 4.0, 0.5)]), 2.4, col["clair"].darkened(0.2), 1.0, 0.0)


## Bras de bois mort et sa griffe d'os, tendus vers l'avant (angle a, local) depuis l'épaule.
static func _arm(ci: CanvasItem, xf: Transform2D, shoulder: Vector2, a: float, col: Dictionary, far: bool) -> void:
	var d := Vector2.from_angle(a)
	var elbow := shoulder + Vector2(10, 12).rotated(a * 0.5)
	var wrist := elbow + d * 18.0
	var pts := PackedVector2Array([shoulder, elbow, wrist])
	Ink.brush(ci, xf, pts, 7.5, Ink.encre(), 1.0, 0.6)
	Ink.brush(ci, xf, pts, 5.0, col["clair"], 1.0, 0.5)
	var b := U.bone()
	if far:
		b = {"clair": b["ombre"], "ombre": b["ombre"].darkened(0.3)}
	for i in 3:
		var ca := a + (i - 1) * 0.32 + 0.15
		Ink.part(ci, xf, Ink.thorn(wrist, ca, 15.0 - absf(i - 1) * 4.0, 4.0, 0.35), b, 1.4, 1.0, 0.0)
