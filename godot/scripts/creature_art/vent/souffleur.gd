## Souffleur (Vent, tireur de souffle), direction « Bestiaire d'herbier » : un tétras des steppes rongé
## par la Flétrissure. Gros oiseau ventru qui marche dans l'herbe couchée, queue en éventail d'épines
## dressée derrière lui, deux sacs d'air au jabot. Les sacs ont pris la braise : pendant l'annonce ils
## enflent et s'allument par transparence, puis il souffle tout l'air par le bec grand ouvert.
## Signe du tireur : la bouche qui s'allume.
##
## Pose : t, walk, moving, k (annonce 0 → 1), state ("windup" / "recover" = le souffle), strike
## (0 → 1 depuis le souffle, -1 : aucun), hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vent/_commun.gd")

## 100 unités en px du jeu (1600×900) : ~55 px de haut à l'écran en 1080p (queue dressée).
const HEIGHT := 52.0
const DRAWS_ELITE := true
const NECK := Vector2(18, -50)


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
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
	# Souffle : 1 au moment où il souffle, puis retombe.
	var blow := 0.0
	if strike >= 0.0:
		blow = 1.0 - Anim.ease_in(strike)
	elif state == "recover":
		blow = 1.0
	var puff := kk * (1.0 - blow)
	Ink.ground_shadow(ci, base, Vector2(0, 0), 36.0)
	# Dandinement de la marche, gonflement de l'annonce (il se cabre), coup de tête du souffle.
	var bob := -absf(sin(walk)) * 3.0 * mv + sin(t * TAU / 2.4) * 0.6
	var lean := -0.12 * puff + 0.16 * blow + 0.05 * sin(walk) * mv + 0.08 * hit
	var sq := Vector2(1.0 + 0.06 * puff + 0.08 * hit, 1.0 + 0.05 * puff - 0.1 * hit)
	var xf := base * Transform2D(lean, sq, 0.0, Vector2(0, -8)) * Transform2D(0.0, Vector2(0, 8 + bob))
	var pal := V.pal()
	var dark := V.pal("plume", "ombre", "clair")
	# Pattes emplumées (celle du fond d'abord).
	_leg(ci, base, xf * Vector2(4, -20), Vector2(8 - sin(walk) * 7.0 * mv, -maxf(-sin(walk), 0.0) * 4.0 * mv), true)
	# Queue en éventail d'épines, dressée ; s'ouvre grand pendant l'annonce, plaquée au souffle.
	var fan := 0.55 + 0.45 * puff - 0.25 * blow
	for i in 9:
		var u := (i - 4) / 4.0
		var a := -PI * 0.68 + u * 0.95 * fan + 0.05 * sin(t * 2.0 + i)
		var l := 44.0 - absf(u) * 12.0 + 6.0 * puff
		var ash := 0.8 if i == 1 or i == 6 else 0.0
		V.feather(ci, xf, Vector2(-22, -36), a, l, 7.5, dark if i % 2 else pal, 1.3, ash)
		if not Ink.mono:
			# Pointe claire (barre blanche des tétras).
			var tip := Vector2(-22, -36) + Vector2.from_angle(a) * l * 0.86
			ci.draw_circle(xf * tip, 1.6 * h / 100.0, Art.bc("vent", "duvet"))
	# Corps ventru.
	var body := Ink.lumpy(Vector2(-2, -34), 30.0, 21.0, 40, 0.03, 8.0)
	Ink.part(ci, xf, body, pal, 2.6, 1.0, 0.8)
	# Ventre sombre (tétras) et flanc écaillé.
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-2, -20), 20.0, 8.0, 24, 0.1, 6.0), Art.bc("vent", "ombre").darkened(0.25))
	if not Ink.mono:
		for row in 3:
			for c in 5:
				var p := Vector2(-22 + c * 8.0 + (4.0 if row % 2 else 0.0), -44 + row * 7.0)
				Ink.brush(ci, xf, PackedVector2Array([p, p + Vector2(3, 2.4), p + Vector2(6, 0)]), 1.2, Art.bc("vent", "plume").darkened(0.15))
	# Aile repliée sur le flanc.
	for i in 4:
		var l := 34.0 - i * 4.0
		V.feather(ci, xf, Vector2(8 - i * 3.0, -44 + i * 3.5), PI + 0.32 - i * 0.06, l, 10.0, dark if i % 2 == 0 else pal, 1.5, 0.0)
	# Plaie de la Flétrissure sur le flanc arrière.
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-22, -30), 7.5, 6.0, 18, 0.35, 5.0, 0.3), Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-26, -33), Vector2(-21, -30), Vector2(-24, -26)]), 1.5, Art.bc("braise"))
	Ink.sparks(ci, xf, Vector2(-22, -26), Vector2(0.0, 1.0), 3, t, 1.2, 0.6)
	# Patte de devant.
	_leg(ci, base, xf * Vector2(10, -20), Vector2(16 + sin(walk) * 7.0 * mv, -maxf(sin(walk), 0.0) * 4.0 * mv), false)
	# Sacs d'air du jabot : peau claire tendue, la braise brille au travers quand ils enflent.
	var sac := 5.5 + 7.5 * puff + 1.0 * sin(t * 3.0) * (1.0 - blow)
	for s: float in [-1.0, 1.0]:
		var c := Vector2(20 + 2.0 * s, -38 + 4.0 * s - puff * 2.0)
		var sk := Ink.oval(c, sac * (0.95 if s < 0 else 1.0), sac * 0.85, 20)
		var skin := {"clair": Art.bc("vent", "duvet").lerp(Art.bc("braise_coeur"), 0.45 * puff), "ombre": Art.bc("vent", "duvet").darkened(0.3).lerp(Art.bc("braise"), 0.55 * puff), "reflet": Color.WHITE}
		Ink.part(ci, xf, sk, skin, 1.4, 1.0, 1.0)
		if puff > 0.05 and not Ink.mono:
			Ink.halo(ci, xf * c, sac * 1.6 * h / 100.0, Art.bc("braise"), puff * 1.3)
			Ink.ember(ci, xf, Ink.oval(c + Vector2(1, 1), sac * 0.35, sac * 0.3, 12), puff)
	# Collerette de plumes blanches au-dessus des sacs.
	for i in 5:
		V.feather(ci, xf, Vector2(16 + i * 2.0, -44), -PI * 0.5 - 0.6 + i * 0.3, 9.0, 4.0, {"clair": Art.bc("vent", "duvet"), "ombre": Art.bc("vent", "duvet").darkened(0.3), "reflet": Color.WHITE}, 0.9)
	# Tête : suit la cible ; dressée pendant l'annonce, tendue en avant au souffle.
	var hl := clampf(la, -0.5, 0.5) * 0.6 - 0.25 * puff + 0.2 * blow
	var neck := Vector2(18, -48) + Vector2(6, 2) * blow - Vector2(2, 4) * puff
	_head(ci, xf * Transform2D(hl, Vector2.ONE, 0.0, neck), kk, puff, blow, hit, t)
	if o.get("elite", false):
		V.collar(ci, xf, Vector2(18, -46), 8.0, 5.0, -0.4)
	# Le souffle : filets de vent qui sortent du bec.
	if blow > 0.0:
		var d := Vector2.from_angle(hl * 0.6)
		V.gusts(ci, xf, neck + Vector2(22, -6), d, 5, 60.0, t, blow, 6.0)


## Patte de tétras : cuisse emplumée, tarse court, doigts d'os.
static func _leg(ci: CanvasItem, base: Transform2D, hip_w: Vector2, foot: Vector2, far: bool) -> void:
	var hip := base.affine_inverse() * hip_w
	var col := Art.bc("os").darkened(0.2 if not far else 0.45)
	var knee := hip.lerp(foot, 0.5) + Vector2(2, 0)
	Ink.brush(ci, base, PackedVector2Array([hip, knee, foot]), 5.0, Ink.encre(), 1.0, 0.6)
	Ink.brush(ci, base, PackedVector2Array([hip, knee, foot]), 3.2, col, 1.0, 0.5)
	var feath := Art.bc("vent", "plume").darkened(0.3 if far else 0.0)
	Ink.part(ci, base, Ink.lumpy(hip.lerp(knee, 0.35), 4.0, 5.0, 14, 0.2, 5.0), {"clair": feath, "ombre": feath.darkened(0.3)}, 1.0, 1.0, 0.0)
	for a: float in [-0.15, 0.35, PI - 0.2]:
		Ink.part(ci, base, Ink.thorn(foot + Vector2(0, -0.5), a, 5.5, 2.0, 0.2), {"clair": col, "ombre": col.darkened(0.3)}, 0.8, 1.0, 0.0)


## Tête du tétras (repère hx au cou) : petite tête ronde, caroncule de braise au-dessus de l'œil, bec
## court qui s'ouvre en grand au souffle (l'intérieur s'allume pendant l'annonce).
static func _head(ci: CanvasItem, hx: Transform2D, kk: float, puff: float, blow: float, hit: float, t: float) -> void:
	var skull := Ink.lumpy(Vector2(6, -6), 9.5, 8.0, 22, 0.04, 4.0)
	Ink.part(ci, hx, skull, V.pal("plume", "ombre", "clair"), 2.2, 1.0, 0.7)
	# Bec : deux mandibules, ouverture selon l'annonce et le souffle.
	var gape := 0.12 * puff + 0.7 * blow + 0.2 * hit
	var bone := {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.35), "reflet": Color.WHITE}
	var tip := Vector2(14, -6)
	if not Ink.mono and gape > 0.05:
		var inner := PackedVector2Array([tip, tip + Vector2(9, -1).rotated(-gape * 0.5), tip + Vector2(9, 1).rotated(gape * 0.5)])
		Ink.flat(ci, hx, inner, Art.bc("braise").lerp(Art.bc("braise_coeur"), puff + blow))
		Ink.halo(ci, hx * (tip + Vector2(6, 0)), 9.0 * hx.get_scale().abs().x * (0.5 + puff + blow), Art.bc("braise"), maxf(puff, blow))
	var upper := Transform2D(-gape * 0.5, tip) * PackedVector2Array([Vector2(0, -3.2), Vector2(9, -0.5), Vector2(0, 0.6)])
	var lower := Transform2D(gape * 0.5, tip) * PackedVector2Array([Vector2(0, -0.2), Vector2(8, 0.6), Vector2(0, 3.0)])
	Ink.part(ci, hx, lower, bone, 1.2, 1.0, 0.0)
	Ink.part(ci, hx, upper, bone, 1.2, 1.0, 0.5)
	# Joue blanche, caroncule de braise (le sourcil rouge des tétras), œil.
	Ink.flat(ci, hx, Ink.lumpy(Vector2(8, -1), 4.5, 3.0, 12, 0.1, 3.0), Art.bc("vent", "duvet"))
	Ink.ember(ci, hx, Ink.leaf(Vector2(3, -12.5), -0.15, 8.0, 2.8), 0.8 * puff)
	if hit > 0.4 or (kk == 0.0 and blow == 0.0 and Ink.blink(t, 0.7) > 0.0):
		Ink.brush(ci, hx, PackedVector2Array([Vector2(6, -7), Vector2(10, -7)]), 1.6, Ink.encre())
	else:
		Ink.ember(ci, hx, Ink.oval(Vector2(8, -7.5), 1.9, 1.6, 10), 0.3 + 0.7 * maxf(puff, blow))
