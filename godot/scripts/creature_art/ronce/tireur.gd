## Tireur d'épines (Ronce, tireur), direction « Bestiaire d'herbier » : une mûre de ronce rongée par la
## Flétrissure, montée sur trois racines-pattes, coiffée de ses sépales secs. Sa tige creuse est une
## sarbacane qui suit la cible ; pendant l'annonce, la braise monte dans la tige et l'embouchure s'allume.
##
## Pose (toutes les clés sont facultatives) :
##   t, walk (phase en radians), moving (0 → 1), k (annonce 0 → 1), strike (0 → 1 après le tir, -1 : aucun),
##   hit (coup reçu 1 → 0), look (angle de la cible, radians, écran), state ("windup" : annonce),
##   elite, region (où se trouve l'élite : couleur du collier), mono.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const O = preload("res://scripts/creature_art/ronce/_outils.gd")

## Hauteur du dessin (100 unités) en px du jeu (1600×900) : 44 px à l'écran en 1080p.
const HEIGHT := 37.0
## L'élite : collier et liseré dessinés ici (contrat moteur), collier sous les sépales.
const DRAWS_ELITE := true
const NECK := Vector2(-2, -76)


static func pal(v := "") -> Dictionary:
	return {"clair": Art.bc("ronce", "clair"), "ombre": Art.bc("ronce", "ombre"), "reflet": Art.bc("ronce", "reflet")}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var elite: bool = o.get("elite", false)
	if o.get("state", "") == "windup" and not o.has("k"):
		k = 1.0
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	Ink.ground_shadow(ci, base, Vector2(0, 0), 30.0)
	# Rebond de la marche, respiration, recul vers l'arrière pendant l'annonce, écrasement du coup reçu.
	var bob := -absf(sin(walk)) * 4.0 * mv + sin(t * TAU / 2.4) * 0.8
	var sq := Vector2(1.0 + 0.1 * hit - 0.04 * k, 1.0 - 0.12 * hit + 0.05 * k)
	var lean := -0.14 * Anim.ease_out(k) + 0.1 * hit
	if strike >= 0.0:
		lean += 0.12 * (1.0 - strike)
	var xf := base * Transform2D(lean, sq, 0.0, Vector2(0, 0)) * Transform2D(0.0, Vector2(0, bob))
	var leg_col := Art.bc("ronce", "detail").darkened(0.35)
	# Pattes : trois racines (celle du fond plus sombre), qui avancent tour à tour.
	var sw := sin(walk) * 8.0 * mv
	_leg(ci, base, xf * Vector2(1, -30), Vector2(4 - sw * 0.6, -1.5), leg_col.darkened(0.3))
	# Épines du dos (derrière le corps).
	for i in 3:
		var a := PI * (0.78 + i * 0.14)
		var b := Vector2(-2, -50) + Vector2.from_angle(a) * Vector2(25, 27)
		Ink.part(ci, xf, Ink.thorn(b, a + 0.25, 13.0 - i * 2.0, 6.0, -0.3), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 1.6, 1.0, 0.0)
	# Sarbacane : la tige creuse qui suit la cible (elle part du haut, derrière les sépales).
	var aim := clampf(la, -0.75, 0.55)
	var piv := Vector2(10, -70)
	var recoil := 0.0 if strike < 0.0 else 7.0 * (1.0 - Anim.ease_out(strike))
	_tube(ci, xf, piv, aim, recoil, k, t)
	# Corps : la mûre (drupes en relief).
	var body := Ink.lumpy(Vector2(-2, -50), 26.0, 28.0, 56, 0.05, 14.0)
	if elite:
		O.rim(ci, xf, body, 2.4)
	Ink.part(ci, xf, body, pal(), 2.4, 1.0, 0.9)
	_drupes(ci, xf, t)
	# La Flétrissure qui ronge le bas de la mûre : une plaque sombre, fendue de braise.
	var rot := Ink.lumpy(Vector2(-19, -36), 7.0, 8.0, 20, 0.35, 5.0, 0.6)
	Ink.flat(ci, xf, rot, Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-22, -41), Vector2(-18, -37), Vector2(-20, -33)]), 1.6, Art.bc("braise"))
	# Fêlures de la Flétrissure qui gagnent la mûre autour de la plaie.
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-13, -40), Vector2(-7, -44), Vector2(-4, -42)]), 1.2, Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-14, -31), Vector2(-8, -28), Vector2(-5, -30)]), 1.2, Art.bc("ronge"))
	# Patte avant (devant le corps).
	_leg(ci, base, xf * Vector2(-12, -26), Vector2(-16 + sw, -maxf(sin(walk), 0.0) * 4.0 * mv), leg_col)
	_leg(ci, base, xf * Vector2(12, -26), Vector2(16 - sw, -maxf(-sin(walk), 0.0) * 4.0 * mv), leg_col)
	if elite:
		O.collar(ci, xf, NECK, 18.0, 4.0, t, o.get("region", "ronce"))
	# Sépales secs en couronne.
	var sep := {"clair": Art.bc("ronce", "detail"), "ombre": Art.bc("ronce", "detail").darkened(0.4), "reflet": Art.bc("ronce", "detail").lightened(0.4)}
	for i in 5:
		var a := -PI * (0.92 - i * 0.21)
		var droop := 0.25 * sin(t * 2.0 + i)
		Ink.part(ci, xf, Ink.leaf(Vector2(-2, -76), a + droop * 0.15, 17.0 - absf(i - 2) * 2.0, 7.0, 0.12 if i < 2 else -0.12), sep, 1.6, 1.0, 0.4)
	# Une vrille de ronce qui se balance au-dessus des sépales, et une feuille encore verte sur la tige.
	Ink.tendril(ci, xf, Vector2(-8, -84), -PI * 0.62 + 0.12 * sin(t * 1.7), 22.0, -0.9, 1.6, Art.bc("ronce", "detail").lightened(0.1), sin(t * 2.3))
	var green := {"clair": Art.ec("racine", "clair").darkened(0.15), "ombre": Art.ec("racine", "clair").darkened(0.55), "reflet": Art.ec("racine", "clair").lightened(0.3)}
	Ink.part(ci, xf, Ink.leaf(Vector2(4, -80), -0.9 + 0.1 * sin(t * 2.0), 11.0, 6.0, 0.1), green, 1.3, 1.0, 0.5)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(4, -80), Vector2(4, -80) + Vector2.from_angle(-0.9) * 9.0]), 0.8, green["ombre"])
	# Braises qui tombent de la plaie.
	Ink.sparks(ci, xf, Vector2(-16, -31), Vector2(0.1, 1.0), 3, t, 1.3, 0.8)
	# Yeux de braise sous les sépales (celui du fond plus petit) : plissés sous le coup, clignent au repos.
	var glow := 0.25 + 0.75 * k
	if hit > 0.4 or (k == 0.0 and Ink.blink(t, 0.3) > 0.0):
		Ink.brush(ci, xf, PackedVector2Array([Vector2(8, -62), Vector2(16, -60)]), 2.4, Ink.encre())
	else:
		Ink.ember(ci, xf, Ink.leaf(Vector2(8, -61), -0.18, 9.0, 4.2), glow)
		Ink.ember(ci, xf, Ink.leaf(Vector2(18.5, -63), -0.25, 5.0, 3.0), glow)


## Une racine-patte : hanche (écran) → genou → pied (local au sol), encre puis couleur.
static func _leg(ci: CanvasItem, base: Transform2D, hip_w: Vector2, foot: Vector2, col: Color) -> void:
	var hip := base.affine_inverse() * hip_w
	var knee := hip.lerp(foot, 0.5) + Vector2(-4 if foot.x < hip.x else 4, -4)
	var pts := PackedVector2Array([hip, knee, foot])
	Ink.brush(ci, base, pts, 7.2, Ink.encre(), 1.0, 0.45)
	Ink.brush(ci, base, pts, 5.0, col, 1.0, 0.35)
	# Écorce de la tige : un reflet du côté de la lumière, deux épines.
	Ink.brush(ci, base, PackedVector2Array([hip.lerp(knee, 0.2) + Vector2(-1, 0), knee + Vector2(-1, -0.5)]), 1.2, col.lightened(0.35))
	var bone := {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}
	var side := -1.0 if foot.x < hip.x else 1.0
	Ink.part(ci, base, Ink.thorn(knee.lerp(foot, 0.35), (PI if side < 0 else 0.0) - 0.4 * side, 4.5, 2.2), bone, 0.9, 1.0, 0.0)
	Ink.part(ci, base, Ink.thorn(hip.lerp(knee, 0.55), (PI if side < 0 else 0.0) + 0.3 * side, 3.5, 1.8), bone, 0.9, 1.0, 0.0)
	# Radicelles au pied.
	for s: float in [-1.0, 1.0]:
		Ink.brush(ci, base, PackedVector2Array([foot + Vector2(0, -1), foot + Vector2(s * 5.0, 0.5)]), 2.2, col.darkened(0.2), 1.0, 0.0)


## Drupes de la mûre : petits reflets en grappe du côté de la lumière, creux sombres ailleurs.
static func _drupes(ci: CanvasItem, xf: Transform2D, _t: float) -> void:
	if Ink.mono:
		return
	for row in 6:
		for col in 6:
			var p := Vector2(-22 + col * 8.0 + (4.0 if row % 2 else 0.0), -72 + row * 7.6)
			var q := (p - Vector2(-2, -50)) / Vector2(24, 26)
			if q.length() > 0.92:
				continue
			var lit := clampf(-(q.dot(Ink.LIGHT)) * 0.9 + 0.35, 0.0, 1.0)
			var w := xf * p
			var k := xf.get_scale().abs().x
			ci.draw_circle(w + Vector2(0.6, 0.9) * k, 3.0 * k, Ink.shade(Color(Art.bc("ronce", "ombre"), 0.55)))
			ci.draw_circle(w + Vector2(-1.0, -1.2) * k, 1.4 * k, Ink.shade(Color(Art.bc("ronce", "reflet"), 0.25 + 0.6 * lit)))


## Tige-sarbacane : pivot piv, angle aim (local), recul ; la braise monte pendant l'annonce (k).
static func _tube(ci: CanvasItem, xf: Transform2D, piv: Vector2, aim: float, recoil: float, k: float, t: float) -> void:
	var d := Vector2.from_angle(aim)
	var n := d.orthogonal()
	var p0 := piv - d * recoil
	var L := 34.0 + 3.0 * k
	var tube := PackedVector2Array([p0 + n * 5.0, p0 + d * L + n * 4.2, p0 + d * (L + 4.0) + n * 6.2, p0 + d * (L + 4.0) - n * 6.2, p0 + d * L - n * 4.2, p0 - n * 5.0])
	var stem := {"clair": Art.bc("ronce", "detail").lerp(Art.bc("os"), 0.35), "ombre": Art.bc("ronce", "detail").darkened(0.35), "reflet": Art.bc("os")}
	Ink.part(ci, xf, tube, stem, 2.0, 1.0, 0.8)
	# Nœuds de la tige et petites épines.
	for i in 3:
		var q := p0 + d * (9.0 + i * 9.0)
		Ink.brush(ci, xf, PackedVector2Array([q + n * 4.6, q - n * 4.6]), 1.6, stem["ombre"].darkened(0.3))
		Ink.part(ci, xf, Ink.thorn(q + n * 4.0, aim - PI / 2.0 - 0.5, 5.0, 2.4), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 1.0, 1.0, 0.0)
	# Embouchure : le creux de la tige, braise qui s'allume pendant l'annonce.
	var mouth := p0 + d * (L + 4.0)
	Ink.flat(ci, xf, Ink.oval(mouth, 2.6, 5.4, 14, aim), Art.bc("ronge"))
	if k > 0.0 and not Ink.mono:
		var kk := Anim.ease_out(k)
		# La braise monte dans la tige : trois anneaux qui courent vers l'embouchure.
		for i in 3:
			var u := fposmod(t * 2.5 + i / 3.0, 1.0) * kk
			var q := p0 + d * (4.0 + u * L)
			Ink.flat(ci, xf, Ink.oval(q, 1.6, 3.6, 10, aim), Color(Art.bc("braise"), 0.9 * kk))
		Ink.halo(ci, xf * mouth, 12.0 * xf.get_scale().abs().x * (0.6 + 0.6 * kk), Art.bc("braise"), kk * 1.6)
		Ink.ember(ci, xf, Ink.oval(mouth, 2.0, 4.2, 12, aim), kk)
