## Traîne-vase (Spore, puddler), « Bestiaire d'herbier » : une limace des marais rongée par la Flétrissure,
## qui porte trois champignons sur le dos et laisse une traînée de vase. Ses deux cornes oculaires finissent
## en braise et suivent la cible.
## Annonce (windup) : elle se ramasse, les chapeaux se rabattent, leurs lames rougeoient et la vase
## bouillonne sous elle ; frappe (strike) : elle s'aplatit et la flaque gicle autour d'elle.
##
## Pose : t, walk, moving, k (annonce 0 → 1), strike (0 → 1 après la flaque, -1 : aucune), hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const Sp = preload("res://scripts/creature_art/spore/outils.gd")

## 100 unités (la hauteur, champignons compris) en px du jeu : ~53 px de haut et ~85 px de long en 1080p (massive, demandé le 25/11).
const HEIGHT := 44.0
## La sorte dessine elle-même son collier d'élite (pose elite).
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
	var kk := Anim.ease_out(k)
	var splat := 0.0 if strike < 0.0 else 1.0 - Anim.ease_out(strike)
	# Flaque qui gicle à la frappe, traînée de vase derrière elle.
	if strike >= 0.0:
		Sp.puddle(ci, base, Vector2(0, 2), 50.0 + 60.0 * Anim.ease_out(strike), 1.0 - 0.4 * strike, 1.3)
	Sp.puddle(ci, base, Vector2(-92 - 4.0 * sin(walk * 0.5) * mv, 1), 28.0, 0.75, 0.4)
	Ink.ground_shadow(ci, base, Vector2(-4, 0), 70.0)
	Sp.bubbles(ci, base, Vector2(-4, 1), 64.0, t, kk, 7)
	# Reptation : une vague court le long du pied, le corps s'allonge et se ramasse.
	var crawl := 0.07 * sin(walk) * mv
	var sx := (1.0 + crawl) * (1.0 - 0.12 * kk + 0.14 * splat) * (1.0 + 0.08 * hit)
	var sy := (1.0 - crawl * 0.8) * (1.0 + 0.16 * kk - 0.22 * splat) * (1.0 - 0.14 * hit)
	var breath := sin(t * TAU / 2.6) * 0.02
	var xf := base * Transform2D(0.0, Vector2(sx, sy + breath), 0.0, Vector2(-6.0 * kk, 0))
	var fl := Sp.flesh()
	var body := _body(walk, mv, t)
	# Champignon du fond (derrière la bosse).
	Sp.cap(ci, xf, Vector2(-34, -40), -PI / 2.0 - 0.6 - 0.3 * kk, 16.0 - 4.0 * kk, 26.0, 0.3 * sin(t * 1.9 + 1.0), kk * 0.8)
	# Corne oculaire du fond.
	var aim := clampf(la, -0.9, 0.6)
	var stalk := 1.0 - 0.6 * hit
	_stalk(ci, xf, Vector2(64, -38), aim - 1.0, 24.0 * stalk, k, t, true)
	# Le corps : pied clair dessous, manteau mauve, flanc dans l'ombre.
	Ink.part(ci, xf, body, fl, 2.6, 1.0, 0.8)
	# Le pied (sole) : bande claire, ondulée par la reptation.
	var sole := PackedVector2Array()
	for i in 17:
		var x := lerpf(-80.0, 72.0, i / 16.0)
		sole.append(Vector2(x, -6.0 - 2.0 * sin(PI * i / 16.0) + 1.4 * sin(x * 0.12 - walk * 2.0) * (0.3 + mv)))
	for i in range(32, -1, -1):
		var x := lerpf(-84.0, 76.0, i / 32.0)
		sole.append(Vector2(x, 1.0 - 2.2 * absf(sin(x * 0.2 - walk * 2.0 * mv))))
	Ink.flat(ci, xf, sole, fl["ombre"].lerp(fl["clair"], 0.35))
	if not Ink.mono:
		# Taches sombres du manteau, comme une limace léopard.
		for q: Vector3 in [Vector3(-58, -16, 3.2), Vector3(-30, -30, 4.0), Vector3(-6, -36, 3.0), Vector3(-18, -22, 2.4), Vector3(8, -24, 2.8), Vector3(-44, -10, 2.2), Vector3(56, -20, 2.4)]:
			Ink.flat(ci, xf, Ink.lumpy(Vector2(q.x, q.y), q.z * 1.3, q.z, 12, 0.25, 3.0, q.x), Color(fl["ombre"], 0.75))
	# Le manteau (bouclier de la limace) sur l'avant du dos, son bord en relief.
	var mantle := Ink.lumpy(Vector2(30, -32), 24.0, 12.0, 26, 0.05, 6.0)
	Ink.part(ci, xf, mantle, {"clair": fl["clair"].lightened(0.08), "ombre": fl["ombre"].lightened(0.06), "reflet": fl["reflet"]}, 1.6, 1.0, 0.6)
	if not Ink.mono:
		for i in 2:
			var ridge := PackedVector2Array()
			for j in 9:
				var a := PI * (1.05 + 0.9 * j / 8.0)
				ridge.append(Vector2(32, -30) + Vector2(cos(a) * (17.0 - i * 7.0), sin(a) * (8.0 - i * 3.5)))
			Ink.brush(ci, xf, ridge, 1.1, fl["ombre"])
	# Plis du corps et mucus luisant.
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-70, -12), Vector2(-46, -26), Vector2(-20, -36), Vector2(4, -38)]), 1.5, fl["ombre"].darkened(0.2))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-56, -10), Vector2(-24, -18), Vector2(6, -16), Vector2(50, -14)]), 1.3, fl["ombre"])
	if not Ink.mono:
		for q: Vector3 in [Vector3(-20, -42, 3.0), Vector3(8, -46, 2.2), Vector3(-48, -28, 2.0), Vector3(40, -36, 1.8)]:
			base_shine(ci, xf, Vector2(q.x, q.y), q.z)
	# La Flétrissure : une plaque sombre sur le flanc, fendue de braise ; le pneumostome rougeoie à l'annonce.
	var rot := Ink.lumpy(Vector2(-40, -20), 15.0, 9.0, 22, 0.32, 5.0, 1.2)
	Ink.flat(ci, xf, rot, Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-50, -24), Vector2(-42, -18), Vector2(-36, -22), Vector2(-28, -16)]), 1.8, Art.bc("braise"))
	Ink.flat(ci, xf, Ink.oval(Vector2(42, -26), 4.4, 3.2, 12), Art.bc("ronge"), 1.0)
	Ink.ember(ci, xf, Ink.oval(Vector2(42, -26), 2.6, 1.8, 10), 0.2 + 0.8 * kk)
	Ink.sparks(ci, xf, Vector2(-40, -16), Vector2(-0.2, 1.0), 2, t, 1.4, 0.7)
	# Champignons du dos : le grand au milieu, un petit devant.
	Sp.cap(ci, xf, Vector2(-12, -46), -PI / 2.0 - 0.15 - 0.35 * kk, 26.0 - 8.0 * kk, 42.0, 0.35 * sin(t * 1.6), kk)
	Sp.cap(ci, xf, Vector2(-52, -26), -PI / 2.0 - 0.9 - 0.3 * kk, 11.0 - 3.0 * kk, 16.0, 0.4 * sin(t * 2.1 + 2.0), kk)
	# Liseré et collier d'élite : couronne d'amanites dorées derrière la tête.
	if elite:
		Sp.elite_rim(ci, xf, body.slice(1, 12))
		Sp.elite_caps(ci, xf, [Vector2(52, -40), Vector2(60, -42), Vector2(-28, -42), Vector2(4, -48)], t)
	# Corne oculaire avant, et les petits tentacules du museau.
	_stalk(ci, xf, Vector2(72, -36), aim - 0.65, 28.0 * stalk, k, t, false)
	for s: float in [0.0, 1.0]:
		var b := Vector2(82, -12 - s * 5.0)
		Ink.brush(ci, xf, PackedVector2Array([b, b + Vector2.from_angle(0.25 - s * 0.3 + 0.2 * sin(t * 3.0 + s)) * 9.0]), 3.2, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, xf, PackedVector2Array([b, b + Vector2.from_angle(0.25 - s * 0.3 + 0.2 * sin(t * 3.0 + s)) * 9.0]), 2.0, fl["clair"], 1.0, 0.0)
	# Bouche : une fente sombre sous le museau.
	Ink.brush(ci, xf, PackedVector2Array([Vector2(64, -7), Vector2(74, -9), Vector2(80, -7)]), 1.6, Art.bc("ronge"))
	# Gouttes de vase projetées à la frappe.
	if strike >= 0.0 and not Ink.mono:
		var u := Anim.ease_out(strike)
		for i in 8:
			var a := PI + PI * i / 7.0
			var q := Vector2(cos(a) * (50.0 + 70.0 * u), -sin(PI * u) * 26.0 * (0.6 + 0.4 * fposmod(i * 0.61, 1.0)) + sin(a) * 4.0)
			var rr := 3.0 * (1.0 - u) * xf.get_scale().abs().x
			ci.draw_circle(base * q, rr + 0.8, Ink.encre())
			ci.draw_circle(base * q, rr, Art.bc("spore", "vase_reflet"))


## Silhouette du corps : limace basse, bosse du manteau au milieu, museau arrondi devant (+x).
static func _body(walk: float, mv: float, _t: float) -> PackedVector2Array:
	var top := [Vector2(-90, -1), Vector2(-80, -7), Vector2(-62, -20), Vector2(-38, -36), Vector2(-12, -46), Vector2(14, -48),
		Vector2(36, -44), Vector2(50, -38), Vector2(58, -40), Vector2(70, -40), Vector2(80, -33), Vector2(85, -20), Vector2(82, -8), Vector2(74, -2)]
	var pts := PackedVector2Array()
	for i in top.size():
		var p: Vector2 = top[i]
		# La vague de reptation soulève le dos d'avant en arrière.
		# Dos plus haut (massive) : la bosse monte de 12 %.
		p.y *= 1.12
		p.y -= 3.0 * mv * maxf(sin(p.x * 0.05 - walk * 2.0), 0.0) * (1.0 if p.y < -10.0 else 0.0)
		pts.append(p)
	pts.append(Vector2(50, 1))
	pts.append(Vector2(0, 2))
	pts.append(Vector2(-60, 1))
	return pts


## Reflet du mucus : une petite tache claire luisante.
static func base_shine(ci: CanvasItem, xf: Transform2D, p: Vector2, r: float) -> void:
	ci.draw_circle(xf * p, r * xf.get_scale().abs().x, Color(Art.bc("spore", "reflet"), 0.6))


## Corne oculaire : de b, angle a, longueur l, terminée par un œil de braise (far : celle du fond).
static func _stalk(ci: CanvasItem, xf: Transform2D, b: Vector2, a: float, l: float, k: float, t: float, far: bool) -> void:
	var d := Vector2.from_angle(a + 0.08 * sin(t * 2.4 + (1.0 if far else 0.0)))
	var tip := b + d * l
	var mid := b.lerp(tip, 0.5) + d.orthogonal() * 3.0
	var col := Art.bc("spore", "clair").darkened(0.25 if far else 0.0)
	Ink.brush(ci, xf, PackedVector2Array([b, mid, tip]), 7.4, Ink.encre(), 1.0, 0.7)
	Ink.brush(ci, xf, PackedVector2Array([b, mid, tip]), 5.0, col, 1.0, 0.6)
	var r := 3.2 if far else 4.4
	Ink.flat(ci, xf, Ink.oval(tip, r + 1.2, r + 1.2, 14), Art.bc("ronge"), 1.2)
	if Ink.blink(t, 0.8 if far else 0.0) > 0.0 and k == 0.0:
		Ink.brush(ci, xf, PackedVector2Array([tip - d.orthogonal() * r, tip + d.orthogonal() * r]), 1.6, Art.bc("braise").darkened(0.3))
	else:
		Ink.ember(ci, xf, Ink.oval(tip, r * 0.8, r * 0.8, 12), 0.3 + 0.7 * k)
