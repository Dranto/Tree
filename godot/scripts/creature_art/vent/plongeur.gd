## Piqueur (Vent, chargeur), direction « Bestiaire d'herbier » : un faucon des plateaux rongé par la
## Flétrissure. Plumage d'ardoise, poitrail de cendre rayé, moustache sombre de faucon, bec crochu d'os ;
## la cendre mange le bout de ses rémiges et une plaie de braise lui ouvre le dos. Il vole : le corps
## plane au-dessus de son ombre. Signe du chargeur : le bec en avant, et le piqué, ailes repliées.
##
## Pose : t, walk, moving, k (annonce 0 → 1), state ("" / "windup" / "charge" / "recover"), hit, look,
## elite. Annonce : il se dresse, ailes levées et tremblantes, bec ouvert, les yeux et la plaie
## s'allument. Charge : le piqué, ailes plaquées, corps tendu vers la cible, filets de vent derrière.
## Recover : il rouvre les ailes en battant fort et reprend de la hauteur.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vent/_commun.gd")

## 100 unités en px du jeu (1600×900) : ~50 px de haut à l'écran en 1080p (ailes levées).
const HEIGHT := 46.0

## Hauteur du vol (unités locales) : en ronde, au plus bas du piqué.
const ALT := 46.0
const ALT_DIVE := 22.0
## Le moteur laisse la sorte dessiner son collier d'élite (au cou).
const DRAWS_ELITE := true
const NECK := Vector2(20, -52)


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var k: float = o.get("k", 0.0)
	var state: String = o.get("state", "")
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	var kk := Anim.ease_out(k)
	var dive := 1.0 if state == "charge" else 0.0
	var rec := 1.0 if state == "recover" else 0.0
	if state == "" and k > 0.0:
		state = "windup"
	# Vol : léger roulis, plus bas pendant le piqué.
	var alt := lerpf(ALT, ALT_DIVE, dive) + 2.5 * sin(t * 4.5) * (1.0 - dive) - 6.0 * rec
	Ink.ground_shadow(ci, base, Vector2(2, 0), lerpf(26.0, 34.0, dive))
	# Inclinaison du corps : vers la cible pendant l'annonce et le piqué (tête en bas si la cible est
	# en dessous), cabré au rattrapage.
	var aim := clampf(la, -0.7, 0.9)
	var tilt := -0.2 + lerpf(0.0, aim * 0.6 - 0.15, kk) * (1.0 - dive) + aim * dive - 0.35 * rec + 0.12 * hit
	var stretch := Vector2(1.0 + 0.22 * dive + 0.08 * hit, 1.0 - 0.14 * dive - 0.1 * hit)
	var shake := sin(t * 60.0) * 0.9 * kk * (1.0 - dive)
	var xf := base * Transform2D(0.0, Vector2(shake, -alt)) * Transform2D(tilt, stretch, 0.0, Vector2.ZERO)
	# Battement : ronde (régulier), annonce (ailes hautes qui frémissent), piqué (repliées), rattrapage (fort).
	var flap := 0.3 + 0.7 * sin(t * 8.0)
	if state == "windup":
		flap = lerpf(flap, 1.3 + 0.07 * sin(t * 42.0), kk)
	elif rec > 0.0:
		flap = 0.2 + sin(t * 15.0) * 0.9
	var fold := dive
	var plume := V.pal("plume", "ombre", "clair")
	var far_pal := {"clair": Art.bc("vent", "ombre"), "ombre": Art.bc("vent", "ombre").darkened(0.35), "reflet": Art.bc("vent", "plume")}
	# Filets de vent derrière le piqué.
	if dive > 0.0:
		V.gusts(ci, xf, Vector2(-30, -2), Vector2(-1, 0), 5, 46.0, t, 1.0, 6.0)
	# Aile du fond (plus sombre, raccourcie par la perspective).
	_wing(ci, xf, Vector2(4, -10), flap, fold, 0.72, far_pal, 0.0)
	# Queue en éventail (s'ouvre pendant l'annonce, se ferme dans le piqué).
	var spread := 0.22 + 0.25 * kk - 0.18 * dive
	for i in 5:
		var a := PI - 0.05 + (i - 2) * spread * 0.5 + 0.08 * sin(t * 3.0 + i)
		V.feather(ci, xf, Vector2(-24, 0), a, 28.0 - absf(i - 2) * 3.0, 7.0, plume, 1.3, 0.7 if i == 4 else 0.0)
	# Pattes : serres repliées sous le ventre, tendues en avant dans le piqué.
	_talons(ci, xf, Vector2(-2, 10), dive, kk, t)
	# Corps : goutte du faucon, dos d'ardoise.
	var body := PackedVector2Array([Vector2(26, -9), Vector2(16, -14), Vector2(0, -14), Vector2(-16, -10), Vector2(-30, -2), Vector2(-24, 4), Vector2(-6, 10), Vector2(12, 10), Vector2(24, 3)])
	Ink.part(ci, xf, body, V.pal(), 2.4, 1.0, 0.8)
	# Poitrail de cendre rayé.
	var chest := PackedVector2Array([Vector2(24, 2), Vector2(14, -2), Vector2(2, 4), Vector2(-8, 10), Vector2(4, 13), Vector2(14, 11)])
	Ink.part(ci, xf, chest, {"clair": Art.bc("vent", "duvet"), "ombre": Art.bc("vent", "duvet").darkened(0.25), "reflet": Color.WHITE}, 0.0, 1.0, 0.4)
	for i in 4:
		var x := 18.0 - i * 5.5
		Ink.brush(ci, xf, PackedVector2Array([Vector2(x + 1.5, 2.5 + i * 1.6), Vector2(x - 1.5, 5.5 + i * 1.8)]), 1.4, Art.bc("vent", "ombre"))
	# La plaie de la Flétrissure sur le dos : cendre et braise.
	var wound := Ink.lumpy(Vector2(-6, -13), 9.0, 4.5, 20, 0.35, 5.0, 0.4)
	Ink.flat(ci, xf, wound, Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-12, -13), Vector2(-7, -15), Vector2(-3, -12), Vector2(2, -14)]), 1.4 + 0.8 * kk, Art.bc("braise"))
	if not Ink.mono and kk > 0.0:
		Ink.halo(ci, xf * Vector2(-5, -13), 10.0 * h / 100.0, Art.bc("braise"), kk)
	Ink.sparks(ci, xf, Vector2(-8, -12), Vector2(-0.6, 0.6), 3, t, 1.2, 0.7)
	# Tête : elle suit la cible (un peu plus que le corps).
	var hl := clampf(aim - tilt * 0.6, -0.5, 0.5) * (1.0 - dive)
	var head := Vector2(24, -12)
	var hx := xf * Transform2D(hl, Vector2.ONE, 0.0, head)
	_head(ci, hx, kk, hit, t, state, dive)
	# Collier d'élite.
	if o.get("elite", false):
		V.collar(ci, xf, Vector2(20, -6), 7.0, 6.0, -0.9)
	# Aile de devant, par-dessus le corps.
	_wing(ci, xf, Vector2(-2, -12), flap, fold, 1.0, V.pal("clair", "plume", "reflet"), 1.0)


## Aile (repère du corps) : épaule sh, battement flap (-1 basse → 1 haute), repli fold (0 ouverte → 1
## plaquée le long du dos), raccourci persp (aile du fond), ash : cendre au bout des rémiges.
static func _wing(ci: CanvasItem, xf: Transform2D, sh: Vector2, flap: float, fold: float, persp: float, col: Dictionary, ash: float) -> void:
	# flap 1 : aile levée vers l'arrière ; -1 : abaissée vers l'arrière ; 1,3 : dressée.
	var a_open := PI + 0.24 + 1.02 * flap
	var a := lerpf(a_open, PI + 0.1, fold)
	var span := lerpf(62.0, 44.0, fold) * lerpf(persp, 1.0, fold * 0.5)
	var d := Vector2.from_angle(a)
	var n := d.orthogonal()
	if d.y > 0.25:
		n = -n  # aile basse : le bord de fuite reste vers l'arrière
	var wd := lerpf(0.78, 0.5, fold)
	# Bord d'attaque puis bord de fuite découpé en rémiges (doigts du faucon).
	var shape := [Vector2(0, -0.1), Vector2(0.3, -0.16), Vector2(0.58, -0.13), Vector2(0.84, -0.06), Vector2(1.0, 0.02),
		Vector2(0.95, 0.11), Vector2(0.9, 0.06), Vector2(0.86, 0.19), Vector2(0.8, 0.11), Vector2(0.74, 0.25),
		Vector2(0.67, 0.16), Vector2(0.6, 0.29), Vector2(0.46, 0.27), Vector2(0.3, 0.32), Vector2(0.12, 0.28), Vector2(0, 0.14)]
	var pts := PackedVector2Array()
	for q: Vector2 in shape:
		pts.append(sh + d * span * q.x + n * span * q.y * wd)
	Ink.part(ci, xf, pts, col, 2.0, 1.0, 0.6)
	if Ink.mono:
		return
	# Couvertures : deux rangs de plumes, rémiges striées.
	for i in 3:
		var u := 0.25 + i * 0.18
		Ink.brush(ci, xf, PackedVector2Array([sh + d * span * u + n * span * 0.05 * wd, sh + d * span * (u + 0.1) + n * span * 0.2 * wd]), 1.2, col["ombre"].darkened(0.3))
	Ink.brush(ci, xf, PackedVector2Array([sh + d * span * 0.1 + n * span * 0.12 * wd, sh + d * span * 0.62 + n * span * 0.08 * wd]), 1.5, col["reflet"].lerp(col["clair"], 0.5))
	# Cendre au bout des rémiges : la Flétrissure les ronge.
	if ash > 0.0:
		for j in 3:
			var q: Vector2 = shape[5 + j * 2]
			var tip := sh + d * span * q.x + n * span * q.y * wd
			Ink.flat(ci, xf, Ink.lumpy(tip, 3.2, 2.4, 10, 0.4, 3.0, j), Art.bc("ronge"))
			ci.draw_circle(xf * (tip + n * 1.5), 0.9 * xf.get_scale().abs().x, Art.bc("braise"))


## Tête de faucon (repère hx, centre au cou) : calotte d'ardoise, moustache sombre, bec crochu d'os,
## œil de braise. Bec ouvert pendant l'annonce (cri), serré dans le piqué.
static func _head(ci: CanvasItem, hx: Transform2D, kk: float, hit: float, t: float, state: String, dive: float) -> void:
	var skull := PackedVector2Array([Vector2(-4, 0), Vector2(-3, -9), Vector2(3, -14), Vector2(10, -13), Vector2(13, -8), Vector2(12, -2), Vector2(6, 3), Vector2(0, 4)])
	Ink.part(ci, hx, skull, V.pal(), 2.2, 1.0, 0.8)
	# Joue claire et moustache sombre du faucon.
	Ink.flat(ci, hx, Ink.lumpy(Vector2(6, -2), 5.5, 4.0, 14, 0.1, 3.0), Art.bc("vent", "duvet"))
	Ink.brush(ci, hx, PackedVector2Array([Vector2(5, -6), Vector2(3, 0), Vector2(1, 4)]), 3.0, Art.bc("vent", "ombre").darkened(0.25), 1.0, 0.0)
	# Bec : mandibule supérieure crochue, inférieure qui s'ouvre.
	var gape := 0.42 * kk * (1.0 if state == "windup" else 0.0) + 0.25 * hit
	var bone := {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.35), "reflet": Color.WHITE}
	var low := Transform2D(gape, Vector2(11, -3)) * PackedVector2Array([Vector2(0, 0), Vector2(8, 0.5), Vector2(5, 2.5), Vector2(0, 2.6)])
	Ink.part(ci, hx, low, bone, 1.2, 1.0, 0.0)
	if gape > 0.05 and not Ink.mono:
		Ink.flat(ci, hx, PackedVector2Array([Vector2(11, -3), Vector2(19, -4), Vector2(11, -3) + Vector2(7, 0.5).rotated(gape)]), Art.bc("braise").darkened(0.2))
	var up := PackedVector2Array([Vector2(10, -8), Vector2(17, -7.5), Vector2(21, -4), Vector2(20.5, -0.5), Vector2(18.5, -2.6), Vector2(13, -2.2), Vector2(10, -3)])
	Ink.part(ci, hx, up, bone, 1.4, 1.0, 0.6)
	Ink.brush(ci, hx, PackedVector2Array([Vector2(11, -6.5), Vector2(13, -7.2)]), 1.6, Art.bc("os").darkened(0.5))
	# Œil de braise (fermé sous le coup, cligne au repos), arcade sombre au-dessus.
	Ink.brush(ci, hx, PackedVector2Array([Vector2(2, -10.5), Vector2(7, -11.5), Vector2(11, -9.5)]), 2.4, Ink.encre())
	var glow := 0.3 + 0.7 * maxf(kk, dive)
	if hit > 0.4 or (kk == 0.0 and dive == 0.0 and Ink.blink(t, 1.1) > 0.0):
		Ink.brush(ci, hx, PackedVector2Array([Vector2(3.5, -8), Vector2(9, -8)]), 1.8, Ink.encre())
	else:
		Ink.ember(ci, hx, Ink.leaf(Vector2(4.0, -8.5), -0.15, 5.4, 2.8), glow * 0.8)


## Serres : deux pattes d'os sous le ventre ; tendues vers l'avant pour le piqué.
static func _talons(ci: CanvasItem, xf: Transform2D, hip: Vector2, dive: float, kk: float, t: float) -> void:
	var col := Art.bc("os").darkened(0.15)
	for s: float in [-1.0, 1.0]:
		var reach := Vector2(4.0 + 3.0 * s, 9.0).lerp(Vector2(20.0 + 3.0 * s, 4.0), dive).lerp(Vector2(10.0, 8.0), kk * 0.5)
		var p0 := hip + Vector2(3.0 * s, 0)
		var p1 := p0 + reach
		var c := col.darkened(0.25 if s < 0.0 else 0.0)
		Ink.brush(ci, xf, PackedVector2Array([p0, p0.lerp(p1, 0.5) + Vector2(-1, 1), p1]), 4.4, Ink.encre(), 1.0, 0.6)
		Ink.brush(ci, xf, PackedVector2Array([p0, p0.lerp(p1, 0.5) + Vector2(-1, 1), p1]), 2.8, c, 1.0, 0.5)
		var open := 0.4 + 0.6 * dive + 0.2 * sin(t * 3.0) * (1.0 - dive)
		for j in 3:
			var a := 0.4 + (j - 1) * 0.6 * open
			Ink.part(ci, xf, Ink.thorn(p1, a, 5.0, 1.8, 0.3), {"clair": c.lightened(0.2), "ombre": c.darkened(0.3)}, 0.8, 1.0, 0.0)
