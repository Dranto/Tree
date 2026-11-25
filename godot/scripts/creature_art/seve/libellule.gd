## Libellule de cendre (Sève, piqueur), direction « Bestiaire d'herbier » : une grande libellule des
## sources dont la Flétrissure a brûlé les ailes (trous bordés de braise) et noirci le bout de
## l'abdomen. Elle vole : son ombre reste au sol, loin sous elle. Gros yeux à facettes de braise.
## Annonce : elle pique du nez vers la cible, ailes levées qui vibrent, l'abdomen se recourbe et son
## bout s'allume. Piqué (« charge ») : ailes plaquées en arrière, corps tendu, traînée de cendre, plus
## près du sol. Retour (« recover ») : ailes grandes ouvertes, elle remonte en planant.
##
## Pose : t, walk (sert au battement), moving, k (annonce 0 → 1), state (""/windup/charge/recover),
##   charge (0 → 1), strike, hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const S = preload("res://scripts/creature_art/seve/_seve.gd")

## 100 unités en px du jeu (1600×900) : ~48 px à l'écran en 1080p (envergure et vol compris).
const HEIGHT := 46.0
## Collier et liseré d'élite dessinés ici (pose « elite »).
const DRAWS_ELITE := true


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var k: float = o.get("k", 0.0)
	var state: String = o.get("state", "")
	var charge: float = o.get("charge", 1.0 if state == "charge" else 0.0)
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
	var glide := 1.0 if state == "recover" else 0.0
	var base := Ink.frame(feet, h, flip)
	# Vol : elle plane haut, plus bas dans le piqué ; l'ombre au sol rétrécit quand elle monte.
	var hover := 52.0 + 3.0 * sin(t * TAU / 1.2) - 20.0 * charge + 6.0 * glide - 4.0 * kk
	Ink.ground_shadow(ci, base, Vector2(-8, 0), 26.0 - 0.12 * hover)
	# Traînée de cendre derrière elle pendant le piqué.
	if charge > 0.0 and not Ink.mono:
		for i in 5:
			var y := -hover + (i - 2) * 4.0
			var x0 := -40.0 - i * 6.0
			ci.draw_line(base * Vector2(x0, y), base * Vector2(x0 - 34.0 - 8.0 * (i % 2), y + 2.0), Color(Art.c("brume"), 0.35 * charge), 1.6 * h / 100.0, true)
	# Assiette : le corps suit un peu la cible, pique du nez dans l'annonce, tendu dans le piqué.
	var pitch := clampf(la, -0.35, 0.35) * 0.5 * (1.0 - charge) + 0.32 * kk - 0.12 * glide + 0.1 * hit
	var sq := Vector2(1.0 + 0.1 * charge + 0.06 * hit, 1.0 - 0.08 * charge - 0.1 * hit)
	var shake := sin(t * 80.0) * 0.8 * kk
	var xf := base * Transform2D(pitch, sq, 0.0, Vector2(0, -hover + shake))
	# Battement : très rapide au vol, encore plus dans l'annonce ; plaquées dans le piqué ; ouvertes au plané.
	var beat := sin(t * 40.0 + walk * 3.0) * (1.0 - glide) * (1.0 + 0.6 * kk)
	var wing_l := lerpf(44.0, 38.0, charge)
	var ash := Art.bc("os").lerp(Art.bc("seve", "reflet"), 0.45)
	var wing_far := {"clair": Color(ash.darkened(0.2), 0.5), "ombre": Color(ash.darkened(0.4), 0.55), "reflet": Color(ash, 0.4)}
	var wing_near := {"clair": Color(ash, 0.62), "ombre": Color(ash.darkened(0.15), 0.66), "reflet": Color(Color.WHITE, 0.5)}
	# Vue de trois quarts d'en haut : les ailes du fond montent à l'écran, celles de devant descendent
	# (plus courtes, vues en raccourci). Levées dans l'annonce, plaquées en arrière dans le piqué.
	var swing := 0.38 * beat
	var fa := [-PI / 2.0 - 0.3 - swing - 0.35 * kk, -PI / 2.0 - 0.78 - swing - 0.3 * kk]
	var na := [PI / 2.0 - 0.32 + swing * 0.8 - 0.75 * kk, PI / 2.0 - 0.8 + swing * 0.8 - 0.6 * kk]
	for i in 2:
		fa[i] = lerp_angle(fa[i], PI - 0.1 - 0.08 * i, charge)
		na[i] = lerp_angle(na[i], PI + 0.12 + 0.08 * i, charge)
	# Ailes du fond (derrière le corps).
	_wing(ci, xf, Vector2(4, -6), fa[0], wing_l, 13.0, wing_far, beat, charge, false)
	_wing(ci, xf, Vector2(-3, -5), fa[1], wing_l * 0.92, 14.0, wing_far, beat, charge, false)
	# Pattes repliées sous le thorax.
	for i in 3:
		var p := Vector2(6 - i * 4.0, 5)
		Ink.brush(ci, xf, PackedVector2Array([p, p + Vector2(2.0 - i, 5.0), p + Vector2(4.0 - i * 2.0, 7.0)]), 1.4, Ink.encre(), 1.0, 0.0)
	# Abdomen : un long fuseau annelé qui se recourbe dans l'annonce ; le bout est rongé.
	var curl := kk * 1.0
	var seg := PackedVector2Array()
	var p0 := Vector2(-6, 0)
	var ang := PI + 0.08 - 0.1 * charge
	var segs := 10
	for i in segs + 1:
		seg.append(p0)
		var u := i / float(segs)
		ang += (0.04 + curl * 0.28 * u) * (1.0 - charge)
		p0 += Vector2.from_angle(ang) * (5.4 - 1.2 * u)
	var abd := _tube(seg, 4.6, 1.8)
	Ink.part(ci, xf, abd, S.pal(), 1.6, 1.0, 0.7)
	for i in range(1, segs):
		var a := seg[i]
		var nn := (seg[i + 1] - seg[i - 1]).normalized().orthogonal()
		var w := lerpf(4.6, 1.8, i / float(segs))
		var band := Art.bc("seve", "detail") if i % 2 == 0 else Art.bc("seve", "ombre").darkened(0.3)
		Ink.brush(ci, xf, PackedVector2Array([a + nn * w, a - nn * w * 0.9]), 1.5 if i % 2 == 0 else 1.0, band)
	# Le bout rongé : cendre et braise ; s'allume dans l'annonce, comme un dard.
	var tip := seg[segs]
	Ink.flat(ci, xf, _tube(PackedVector2Array([seg[segs - 3], seg[segs - 2], seg[segs - 1], tip]), 2.6, 1.6), Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([seg[segs - 3], seg[segs - 1]]), 0.9, Art.bc("braise"))
	Ink.ember(ci, xf, Ink.oval(tip, 1.6 + 1.6 * kk, 1.6 + 1.6 * kk, 10), 0.2 + 0.8 * kk)
	if kk > 0.0 and not Ink.mono:
		Ink.halo(ci, xf * tip, 10.0 * xf.get_scale().abs().x * (0.5 + 0.6 * kk), Art.bc("braise"), kk * 1.3)
	Ink.sparks(ci, xf, tip, Vector2(0.0, 1.0), 2, t, 0.9, 0.5 + 0.5 * kk)
	# Thorax trapu, liseré de lumière.
	var thorax := Ink.lumpy(Vector2(2, -1), 10.5, 8.0, 22, 0.05, 6.0)
	Ink.part(ci, xf, thorax, S.pal(), 2.0, 1.0, 0.8)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-6, -4), Vector2(2, -8), Vector2(9, -5)]), 1.6, Art.bc("seve", "detail"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-3, 2), Vector2(4, 4)]), 1.2, Art.bc("seve", "ombre").darkened(0.3))
	if elite:
		var rim := PackedVector2Array()
		for i in range(0, segs - 2, 2):
			rim.append(seg[i] + (seg[i + 1] - seg[i]).normalized().orthogonal() * -4.5)
		S.elite(ci, xf, Vector2(10, -1), 3.0, 8.0, t, rim)
	# Tête : deux gros yeux à facettes de braise (celui du fond dépasse à peine).
	var glow := 0.35 + 0.65 * maxf(kk, charge)
	Ink.part(ci, xf, Ink.oval(Vector2(16, -3), 6.0, 5.6, 16), S.pal(0.6), 1.4, 1.0, 0.0)
	if hit > 0.4:
		Ink.part(ci, xf, Ink.oval(Vector2(14, -2), 7.2, 6.6, 18), S.pal(), 1.6, 1.0, 0.5)
		Ink.brush(ci, xf, PackedVector2Array([Vector2(10, -2), Vector2(18, -3)]), 1.4, Ink.encre())
	else:
		var eye := Ink.oval(Vector2(14, -2), 7.2, 6.6, 18)
		Ink.ink_world(ci, xf * eye, 1.6 * xf.get_scale().abs().x)
		Ink.ember(ci, xf, eye, glow)
		# Facettes : un fin quadrillage sombre sur l'œil.
		if not Ink.mono:
			for i in 3:
				var y := -6.0 + i * 3.4
				Ink.brush(ci, xf, PackedVector2Array([Vector2(8.5, y), Vector2(19.5, y + 0.6)]), 0.5, Color(Art.bc("ronge"), 0.5))
				var x := 10.5 + i * 3.4
				Ink.brush(ci, xf, PackedVector2Array([Vector2(x, -8), Vector2(x + 0.6, 4)]), 0.5, Color(Art.bc("ronge"), 0.5))
			ci.draw_circle(xf * Vector2(11.5, -5.5), 1.4 * xf.get_scale().abs().x, Color(1, 1, 1, 0.7))
	# Mandibules.
	Ink.brush(ci, xf, PackedVector2Array([Vector2(19, 2), Vector2(22, 4), Vector2(20, 6)]), 1.4, Art.bc("os").darkened(0.2), 1.0, 0.0)
	# Ailes de devant (par-dessus le corps, en raccourci), avec la trace du battement.
	if charge < 0.5 and glide < 0.5 and not Ink.mono:
		var ghost := {"clair": Color(ash, 0.18), "ombre": Color(ash, 0.18)}
		_wing(ci, xf, Vector2(4, 3), na[0] - 0.7 * beat, wing_l * 0.78, 13.0, ghost, beat, 0.0, false, 0.0)
	_wing(ci, xf, Vector2(4, 3), na[0], wing_l * 0.78, 13.0, wing_near, beat, charge, true)
	_wing(ci, xf, Vector2(-3, 3), na[1], wing_l * 0.72, 14.0, wing_near, beat, charge, false)
	Ink.mono = prev_mono
	Ink.flash = 0.0


## Contour d'un tube le long de pts (largeur w0 → w1, bouts arrondis).
static func _tube(pts: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
	var n := pts.size()
	var l := PackedVector2Array()
	var r := PackedVector2Array()
	for i in n:
		var d := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var w := lerpf(w0, w1, i / float(n - 1))
		l.append(pts[i] + d.orthogonal() * w)
		r.append(pts[i] - d.orthogonal() * w)
	var end := pts[n - 1] + (pts[n - 1] - pts[n - 2]).normalized() * w1
	r.reverse()
	l.append(end)
	l.append_array(r)
	return l


## Une aile : longue amande de base b, direction a ; nervures ; brûlée (trous de braise) si burnt.
static func _wing(ci: CanvasItem, xf: Transform2D, b: Vector2, a: float, l: float, w: float, pal: Dictionary, beat: float, fold: float, burnt: bool, ink := 0.9) -> void:
	var shape := Ink.leaf(b, a, l, w * (1.0 - 0.45 * fold) * (1.0 - 0.15 * absf(beat)), 0.04)
	if burnt and not Ink.mono:
		var hole := Ink.lumpy(b + Vector2.from_angle(a) * l * 0.72, w * 0.3, w * 0.24, 14, 0.4, 4.0, 0.7)
		var cut := Geometry2D.clip_polygons(shape, hole)
		if cut.size() == 1:
			shape = cut[0]
	if ink > 0.0:
		Ink.ink_world(ci, xf * shape, ink * xf.get_scale().abs().x)
	if Ink.mono:
		Ink._poly(ci, xf * shape, Color.BLACK)
		return
	Ink.fill_world(ci, xf * shape, pal, 0.6, 0.0)
	if ink <= 0.0:
		return
	# Nervures et tache de l'aile (ptérostigma).
	var d := Vector2.from_angle(a)
	var nn := d.orthogonal()
	var vein := Color(Art.c("brume").darkened(0.5), 0.6)
	Ink.brush(ci, xf, PackedVector2Array([b, b + d * l * 0.5 + nn * w * 0.08, b + d * l * 0.92]), 0.6, vein)
	Ink.brush(ci, xf, PackedVector2Array([b + d * l * 0.15 + nn * w * 0.12, b + d * l * 0.6 + nn * w * 0.28]), 0.4, vein)
	Ink.brush(ci, xf, PackedVector2Array([b + d * l * 0.15 - nn * w * 0.1, b + d * l * 0.6 - nn * w * 0.25]), 0.4, vein)
	Ink.flat(ci, xf, Ink.oval(b + d * l * 0.86 + nn * w * 0.18, 2.4, 1.0, 8, a), Color(Art.bc("ronge"), 0.75))
	if burnt:
		var hp := b + d * l * 0.72
		var ring := Ink.lumpy(hp, w * 0.3, w * 0.24, 14, 0.4, 4.0, 0.7)
		ring.append(ring[0])
		ci.draw_polyline(xf * ring, Art.bc("braise"), 0.9 * xf.get_scale().abs().x, true)
