## Souche gorgée (Sève, soutien), direction « Bestiaire d'herbier » : une souche de saule coupée,
## gorgée de la sève de la vallée, qui marche sur ses racines. Vertical et ancré : le tronc, le sommet
## coupé aux cernes, une écharde dressée. Signe du soutien : des poches de sève (loupes gonflées) sur
## les flancs et une flaque de sève au sommet. Visage taillé dans une fente de l'écorce, yeux de
## braise. La Flétrissure ronge le pied.
## Annonce (le soin, « windup ») : elle se gonfle, les poches et la flaque s'allument en vert, la sève
## monte en gouttes (jamais de rouge : ce n'est pas un coup). Frappe (« strike », le soin rendu) : les
## poches se vident en une gerbe de gouttes.
##
## Pose : t, walk, moving, k (0 → 1), state (""/windup), strike (0 → 1, -1 : aucune), hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const S = preload("res://scripts/creature_art/seve/_seve.gd")

## 100 unités en px du jeu (1600×900) : ~74 px de haut à l'écran en 1080p.
const HEIGHT := 62.0
## Collier et liseré d'élite dessinés ici (pose « elite »).
const DRAWS_ELITE := true


static func bark() -> Dictionary:
	var c := Art.bc("seve", "clair").lerp(Art.bc("seve", "vase"), 0.35)
	return {"clair": c, "ombre": Art.bc("seve", "ombre").lerp(Art.bc("seve", "vase"), 0.4).darkened(0.15), "reflet": Art.bc("seve", "reflet").lerp(Art.bc("os"), 0.3)}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var state: String = o.get("state", "")
	var strike: float = o.get("strike", -1.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var elite: bool = o.get("elite", false)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	var prev_mono := Ink.mono
	if o.has("mono"):
		Ink.mono = bool(o["mono"])
	Ink.flash = hit
	var kk := Anim.ease_out(k) if state == "windup" or (state == "" and k > 0.0) else 0.0
	var rel := 0.0 if strike < 0.0 else 1.0 - strike
	var breath := sin(t * TAU / 2.4)
	# Plein : gonflée pendant l'annonce, vidée juste après le soin.
	var full := clampf(0.35 + 0.08 * breath + 0.65 * kk - 0.5 * rel, 0.0, 1.0)
	var base := Ink.frame(feet, h, flip)
	Ink.ground_shadow(ci, base, Vector2(0, 0), 46.0)
	var rock := sin(walk) * 0.04 * mv
	var sq := Vector2(1.0 + 0.05 * kk + 0.06 * hit - 0.03 * rel, 1.0 + 0.05 * kk - 0.08 * hit + 0.02 * rel)
	var xf := base * Transform2D(rock + 0.05 * hit, sq, 0.0, Vector2(0, -absf(sin(walk)) * 2.5 * mv))
	var bp := bark()
	var far := {"clair": bp["ombre"], "ombre": bp["ombre"].darkened(0.3), "reflet": bp["clair"]}
	# Racines du fond.
	for i in 2:
		var ph := walk + i * PI
		var lift := maxf(0.0, sin(ph)) * 6.0 * mv
		var hip := Vector2(-10 + i * 22.0, -14)
		_root(ci, xf, base, hip, Vector2(-30 + i * 58.0 + cos(ph) * 5.0 * mv, -3.0 - lift), far, 8.0)
	# Tronc : un peu évasé au pied, flancs bosselés.
	var trunk := PackedVector2Array([
		Vector2(-36, -6), Vector2(-31, -22), Vector2(-28, -44), Vector2(-30, -62), Vector2(-27, -80),
		Vector2(27, -80), Vector2(29, -60), Vector2(26, -40), Vector2(30, -20), Vector2(37, -6), Vector2(0, -2)])
	Ink.part(ci, xf, trunk, bp, 3.0, 1.0, 0.5)
	# Flanc dans l'ombre (le côté droit, loin de la lumière).
	Ink.flat(ci, xf, PackedVector2Array([Vector2(14, -80), Vector2(27, -80), Vector2(29, -60), Vector2(26, -40), Vector2(30, -20), Vector2(37, -6), Vector2(18, -4), Vector2(16, -40)]), Color(bp["ombre"], 0.75))
	# Écorce : sillons verticaux ondulés.
	for i in 6:
		var x := -24.0 + i * 9.0
		var sway := 2.0 * sin(i * 1.7)
		Ink.brush(ci, xf, PackedVector2Array([Vector2(x, -76), Vector2(x + sway, -54), Vector2(x - sway * 0.5, -30), Vector2(x + sway * 0.8 + (i - 2.5) * 1.6, -8)]), 1.6, bp["ombre"].darkened(0.35))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-26, -74), Vector2(-27, -46), Vector2(-25, -20)]), 1.4, bp["reflet"])
	# Mousse en plaques sur l'épaule éclairée, champignons en console sur le flanc.
	var moss := Art.ec("racine", "clair").darkened(0.35).lerp(Art.bc("seve", "clair"), 0.3)
	for q: Vector3 in [Vector3(-22, -70, 7), Vector3(-14, -76, 5), Vector3(-26, -54, 4.5)]:
		Ink.flat(ci, xf, Ink.lumpy(Vector2(q.x, q.y), q.z, q.z * 0.6, 16, 0.4, 6.0, q.x), moss, 0.8)
	var shelf := {"clair": Art.bc("os").darkened(0.08), "ombre": Art.bc("seve", "detail").darkened(0.25), "reflet": Color.WHITE}
	for q: Vector3 in [Vector3(24, -50, 9), Vector3(27, -42, 6.5)]:
		var c := Vector2(q.x, q.y)
		var half := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			half.append(c + Vector2(cos(a) * q.z, sin(a) * q.z * 0.45))
		half.append(c + Vector2(q.z * 0.8, 1.2))
		half.append(c + Vector2(-q.z * 0.8, 1.2))
		Ink.part(ci, xf, half, shelf, 1.2, 1.0, 0.6)
		Ink.brush(ci, xf, PackedVector2Array([c + Vector2(-q.z * 0.6, -q.z * 0.18), c + Vector2(q.z * 0.6, -q.z * 0.18)]), 0.7, shelf["ombre"])
	# Poches de sève : loupes gonflées sur les flancs, ternes au repos, vives pendant le soin.
	var glow := clampf(kk + 0.25 * rel, 0.0, 1.0)
	for q: Vector3 in [Vector3(-14, -30, 8.5), Vector3(10, -58, 6.5), Vector3(14, -22, 5.5)]:
		_pocket(ci, xf, Vector2(q.x, q.y), q.z * (0.85 + 0.3 * full), glow, t)
	# Veines de sève qui montent vers le sommet pendant le soin.
	if glow > 0.0 and not Ink.mono:
		for v: PackedVector2Array in [PackedVector2Array([Vector2(-14, -38), Vector2(-10, -52), Vector2(-14, -66), Vector2(-8, -78)]), PackedVector2Array([Vector2(10, -64), Vector2(6, -72), Vector2(8, -79)])]:
			Ink.brush(ci, xf, v, 2.2 * glow, Color(S.sap(), 0.9 * glow), 1.0, 0.0)
	# La Flétrissure ronge le pied : écorce noircie, fentes de braise, cendre qui tombe.
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-22, -14), 10.0, 11.0, 26, 0.5, 3.0, 0.3), Art.bc("ronge"))
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-12, -6), 5.0, 4.0, 16, 0.4, 3.0, 1.3), Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-24, -6), Vector2(-21, -13), Vector2(-24, -19), Vector2(-20, -25)]), 1.6, Art.bc("braise"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-21, -13), Vector2(-15, -11)]), 1.1, Art.bc("braise"))
	Ink.sparks(ci, xf, Vector2(-20, -24), Vector2(0.1, -1.0), 2, t, 1.2, 0.6)
	# Visage dans une fente de l'écorce : arcade lourde, yeux de braise qui suivent la cible, bouche fendue.
	var gaze := clampf(la, -0.6, 0.6) * 3.0
	Ink.flat(ci, xf, Ink.lumpy(Vector2(1, -55), 16.0, 6.5, 22, 0.2, 4.0), Color(bp["ombre"].darkened(0.45), 0.7))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-16, -61), Vector2(-4, -64), Vector2(8, -63), Vector2(19, -59)]), 3.6, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-15, -63), Vector2(-3, -66), Vector2(9, -65)]), 1.4, bp["reflet"])
	var eg := 0.3 + 0.5 * kk
	if hit > 0.4 or (kk == 0.0 and Ink.blink(t, 0.7) > 0.0):
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-10, -54), Vector2(-2, -54)]), 2.2, Ink.encre())
		Ink.brush(ci, xf, PackedVector2Array([Vector2(6, -54), Vector2(13, -54)]), 1.8, Ink.encre())
	else:
		Ink.ember(ci, xf, Ink.leaf(Vector2(-11 + gaze, -55), -0.1, 9.0, 4.0), eg)
		Ink.ember(ci, xf, Ink.leaf(Vector2(5 + gaze, -56), -0.18, 7.5, 3.4), eg)
	var mouth := PackedVector2Array([Vector2(-9, -43), Vector2(-3, -40), Vector2(3, -42), Vector2(8, -39), Vector2(12, -42)])
	Ink.brush(ci, xf, mouth, 3.2, Ink.encre())
	Ink.brush(ci, xf, PackedVector2Array([mouth[1], mouth[2], mouth[3]]), 1.1, Color(Art.bc("braise"), 0.45 + 0.4 * kk))
	# Sommet coupé : cernes, écharde dressée, flaque de sève qui s'allume.
	var topc := Vector2(0, -80)
	var top := Ink.oval(topc, 27.5, 9.0, 32)
	Ink.part(ci, xf, top, {"clair": Art.bc("seve", "detail"), "ombre": Art.bc("seve", "detail").darkened(0.3), "reflet": Art.bc("os")}, 1.8, 1.0, 0.4)
	for i in 3:
		var rr := 21.0 - i * 6.0
		var ring := Ink.oval(topc + Vector2(1.5, 0.5), rr, rr * 0.33, 24)
		ring.append(ring[0])
		if not Ink.mono:
			ci.draw_polyline(xf * ring, Art.bc("seve", "detail").darkened(0.35), 0.9 * xf.get_scale().abs().x, true)
	var pool := Ink.lumpy(topc + Vector2(2, 0.6), 9.0 + 3.0 * full, 3.0 + 1.0 * full, 18, 0.15, 4.0)
	var pc := Art.bc("seve", "ombre").lerp(S.sap(), 0.25 + 0.75 * glow)
	Ink.flat(ci, xf, pool, pc, 0.8)
	if not Ink.mono:
		ci.draw_circle(xf * (topc + Vector2(-2, -0.4)), 1.4 * xf.get_scale().abs().x, Color(1, 1, 1, 0.5 + 0.4 * glow))
	S.sap_glow(ci, xf, topc + Vector2(0, -6), 34.0, glow)
	var splinter := PackedVector2Array([Vector2(-27, -80), Vector2(-25, -96), Vector2(-21, -88), Vector2(-17, -104), Vector2(-12, -86), Vector2(-7, -92), Vector2(-4, -84), Vector2(-8, -78)])
	Ink.part(ci, xf, splinter, bp, 2.0, 1.0, 0.3)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-21, -82), Vector2(-17, -100)]), 1.0, bp["ombre"].darkened(0.3))
	# Une pousse verte sur l'écharde : la vie qui reste dans le bois.
	var leafc := {"clair": Art.ec("racine", "clair").darkened(0.1), "ombre": Art.ec("racine", "clair").darkened(0.5), "reflet": Art.ec("seve", "clair")}
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-17, -102), Vector2(-15, -110)]), 1.0, leafc["ombre"], 1.0, 0.0)
	Ink.part(ci, xf, Ink.leaf(Vector2(-15, -109), -0.6 + 0.12 * sin(t * 2.0), 9.0, 4.2, 0.08), leafc, 1.1, 1.0, 0.5)
	# Gouttes de sève qui montent pendant le soin ; gerbe au moment du soin.
	if glow > 0.0 and not Ink.mono:
		for i in 4:
			var u := fposmod(t * 1.1 + i / 4.0, 1.0)
			var q := topc + Vector2((i - 1.5) * 7.0 + sin(t * 3.0 + i) * 2.0, -6.0 - u * 30.0)
			ci.draw_circle(xf * q, (2.4 - 1.4 * u) * xf.get_scale().abs().x, Color(S.sap(), (1.0 - u) * kk))
	if rel > 0.0 and not Ink.mono:
		var u := 1.0 - rel
		for i in 10:
			var a := -PI * (0.05 + 0.9 * i / 9.0)
			var q := topc + Vector2(cos(a) * (8.0 + 40.0 * u), sin(a) * (6.0 + 26.0 * u) + 30.0 * u * u)
			ci.draw_circle(xf * q, (2.6 - 1.2 * u) * xf.get_scale().abs().x, Color(S.sap(), rel))
	if elite:
		var rim := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			rim.append(topc + Vector2(cos(a) * 28.5, sin(a) * 9.5))
		S.elite(ci, xf, Vector2(0, -36), 30.0, 6.0, t, rim)
	# Racines de devant, qui se lèvent tour à tour.
	for i in 2:
		var ph := walk + PI * 0.5 + i * PI
		var lift := maxf(0.0, sin(ph)) * 6.0 * mv
		var hip := Vector2(-18 + i * 30.0, -10)
		_root(ci, xf, base, hip, Vector2(-38 + i * 70.0 + cos(ph) * 5.0 * mv, 1.0 - lift), bp, 10.0)
	Ink.mono = prev_mono
	Ink.flash = 0.0


## Racine-patte : de la hanche (repère du tronc) au pied (au sol), effilée, radicelles au bout.
static func _root(ci: CanvasItem, xf: Transform2D, base: Transform2D, hip: Vector2, foot: Vector2, pal: Dictionary, w: float) -> void:
	var h := base.affine_inverse() * (xf * hip)
	var side := signf(foot.x - h.x)
	var knee := h.lerp(foot, 0.45) + Vector2(side * 4.0, -7.0)
	var pts := PackedVector2Array([h, knee, foot])
	Ink.brush(ci, base, pts, w + 2.6, Ink.encre(), 1.0, 0.25)
	Ink.brush(ci, base, pts, w, pal["clair"], 1.0, 0.2)
	Ink.brush(ci, base, PackedVector2Array([h + Vector2(-1, -1), knee + Vector2(-1, -1.5)]), w * 0.28, pal.get("reflet", pal["clair"]).lerp(pal["clair"], 0.5))
	for s: float in [-1.0, 0.0, 1.0]:
		Ink.brush(ci, base, PackedVector2Array([foot, foot + Vector2(side * 5.0 + s * 3.0, 1.0 + absf(s))]), 2.0, pal["ombre"], 1.0, 0.0)


## Poche de sève : loupe ronde de l'écorce, translucide ; la sève y luit selon glow.
static func _pocket(ci: CanvasItem, xf: Transform2D, c: Vector2, r: float, glow: float, t: float) -> void:
	var dull := Art.bc("seve", "ombre").lerp(Art.ec("seve", "sombre"), 0.5)
	var lit := S.sap()
	var col := dull.lerp(lit, glow)
	Ink.part(ci, xf, Ink.lumpy(c, r, r * 0.9, 20, 0.06, 5.0), {"clair": col.lightened(0.15), "ombre": col.darkened(0.25), "reflet": Art.ec("seve", "clair")}, 1.8, 1.0, 0.9)
	# Rebord d'écorce qui la serre.
	if not Ink.mono:
		var lip := PackedVector2Array()
		for i in 9:
			var a := PI * 0.15 + PI * 0.7 * i / 8.0
			lip.append(c + Vector2(cos(a) * r * 1.02, sin(a) * r * 0.95))
		Ink.brush(ci, xf, lip, 2.2, bark()["ombre"].darkened(0.2), 1.0, 1.0)
		ci.draw_circle(xf * (c + Vector2(-r * 0.35, -r * 0.4)), r * 0.2 * xf.get_scale().abs().x, Color(1, 1, 1, 0.45 + 0.35 * glow))
		if glow > 0.0:
			Ink.halo(ci, xf * c, r * 2.2 * xf.get_scale().abs().x, lit, glow * (0.8 + 0.2 * sin(t * 6.0)))
