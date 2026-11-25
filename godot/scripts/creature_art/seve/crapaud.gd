## Crapaud des sources (Sève, bondisseur), direction « Bestiaire d'herbier » : un gros crapaud de la
## vallée, verruqueux, une feuille de nénuphar morte collée au dos, rongé à l'arrière par la
## Flétrissure (pustules de braise). Trapu et bas, les cuisses repliées sur les flancs.
## Annonce : il se ramasse, la gorge se gonfle et s'allume de braise. Bond (« lift ») : il s'étire en
## l'air, pattes tendues, l'ombre reste au sol. Retombée (« strike ») : gerbe d'eau, puis sonné
## (« recover », yeux mi-clos).
##
## Pose : t, walk, moving, k (annonce 0 → 1), state (""/windup/leap/recover), lift (0 → 1),
##   strike (0 → 1 après la retombée, -1 : aucune), hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const S = preload("res://scripts/creature_art/seve/_seve.gd")

## 100 unités en px du jeu (1600×900) : ~55 px de haut à l'écran en 1080p.
const HEIGHT := 46.0
## Pose propre (comportement hopper) : hauteur du bond, de 0 à 1 (contrat moteur).
const CUSTOM := {"lift": 4}
## Collier et liseré d'élite dessinés ici (pose « elite »).
const DRAWS_ELITE := true


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var state: String = o.get("state", "")
	var lift: float = o.get("lift", 0.0)
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
	var land := 0.0 if strike < 0.0 else 1.0 - strike
	var dazed := 1.0 if state == "recover" else 0.0
	var base := Ink.frame(feet, h, flip)
	Ink.ground_shadow(ci, base, Vector2(0, 0), 44.0 * (1.0 - 0.35 * lift))
	# Gerbe d'eau à la retombée : gouttes qui jaillissent en anneau autour de lui.
	if land > 0.0 and not Ink.mono:
		var u := 1.0 - land
		var water := Art.ec("seve", "clair").lerp(Art.bc("seve", "reflet"), 0.5)
		var ring := Ink.oval(Vector2(0, 0), 30.0 + 34.0 * u, (30.0 + 34.0 * u) * Art.OMBRE_APLATI, 32)
		ring.append(ring[0])
		ci.draw_polyline(base * ring, Color(water, 0.7 * land), 2.4 * h / 100.0, true)
		for i in 9:
			var a := PI + PI * i / 8.0
			var q := Vector2(cos(a) * (26.0 + 30.0 * u), -sin(PI * u) * (14.0 + 10.0 * (i % 3)) + sin(a) * 6.0)
			ci.draw_circle(base * q, (2.6 - 1.4 * u) * h / 100.0, Color(water, land))
	# Petits sauts de la marche, ramassé dans l'annonce, étiré en l'air, écrasé à la retombée.
	var hop := absf(sin(walk)) * 8.0 * mv
	var breath := sin(t * TAU / 2.4)
	var sq := Vector2(1.0 + 0.12 * kk - 0.12 * lift + 0.16 * land + 0.08 * hit, 1.0 - 0.13 * kk + 0.16 * lift - 0.14 * land - 0.12 * hit)
	var tilt := -0.32 * lift * (1.0 - lift * 0.4) + 0.06 * kk + 0.08 * hit
	var rise := hop + lift * 52.0
	var xf := base * Transform2D(tilt, sq, 0.0, Vector2(0, -rise))
	var body_pal := S.pal()
	var far := S.pal(0.8)
	# Patte avant du fond.
	_arm(ci, xf, Vector2(24, -16), Vector2(32, -1) + Vector2(10, 10) * lift, far)
	# Cuisse du fond (on n'en voit que le pied qui dépasse).
	_foot(ci, xf, Vector2(-20, -2) + Vector2(-14, 12) * lift, -0.2 - 0.6 * lift, far)
	# Corps et tête d'un seul tenant : dos bossu, museau large et plat.
	var back := Ink.lumpy(Vector2(-8, -29), 32.0, 27.0 + 1.0 * breath, 40, 0.03, 9.0)
	var head := Ink.oval(Vector2(23, -24), 18.0, 13.5, 28, -0.1)
	var shapes := Geometry2D.merge_polygons(back, head)
	var body: PackedVector2Array = shapes[0] if not shapes.is_empty() else back
	for i in body.size():
		body[i].y = minf(body[i].y, -5.0)
	Ink.part(ci, xf, body, body_pal, 2.6, 1.0, 0.7)
	# Ventre pâle de vase, côté sol.
	var belly := PackedVector2Array()
	for p in body:
		if p.y > -16.0 and p.x > -30.0:
			belly.append(p)
	if belly.size() >= 3:
		var bl := Geometry2D.convex_hull(belly)
		var clip := Geometry2D.intersect_polygons(body, Transform2D(0.0, Vector2(1.0, 1.0), 0.0, Vector2(0, 3)) * bl)
		for poly in clip:
			Ink.flat(ci, xf, poly, Art.bc("seve", "detail").lerp(Art.bc("os"), 0.35).darkened(0.15))
	# Gorge qui se gonfle pendant l'annonce : une poche pâle où la braise s'allume.
	var sac := 5.0 + 12.0 * kk
	if kk > 0.02:
		var sp := Ink.oval(Vector2(31, -13 + sac * 0.15), sac * 0.95, sac * 0.75, 20)
		Ink.part(ci, xf, sp, {"clair": Art.bc("os").darkened(0.1), "ombre": Art.bc("seve", "detail").darkened(0.2), "reflet": Color.WHITE}, 1.6, 1.0, 0.8)
		if kk > 0.0:
			Ink.flat(ci, xf, Ink.oval(Vector2(31, -12 + sac * 0.15), sac * 0.6, sac * 0.45, 16), Color(Art.bc("braise"), 0.75 * kk))
			Ink.flat(ci, xf, Ink.oval(Vector2(30, -13 + sac * 0.15), sac * 0.32, sac * 0.22, 12), Color(Art.bc("braise_coeur"), 0.8 * kk))
			Ink.halo(ci, xf * Vector2(31, -13), 18.0 * xf.get_scale().abs().x * (0.5 + 0.6 * kk), Art.bc("braise"), kk * 1.4)
	# Glande derrière l'œil (bourrelet) et verrues en relief.
	Ink.part(ci, xf, Ink.leaf(Vector2(2, -46), -0.15, 18.0, 6.5, 0.05), {"clair": body_pal["clair"].lightened(0.08), "ombre": body_pal["ombre"], "reflet": body_pal["reflet"]}, 1.2, 1.0, 0.6)
	for w: Vector3 in [Vector3(-18, -42, 3.4), Vector3(-8, -36, 2.6), Vector3(-26, -30, 3.0), Vector3(-12, -24, 2.2), Vector3(6, -34, 2.4), Vector3(-30, -42, 2.2), Vector3(14, -40, 1.8)]:
		Ink.part(ci, xf, Ink.oval(Vector2(w.x, w.y), w.z, w.z * 0.85, 12), {"clair": body_pal["clair"].lightened(0.12), "ombre": body_pal["ombre"].lightened(0.05), "reflet": body_pal["reflet"]}, 0.8, 1.0, 1.0)
	# Taches sombres de la robe.
	for q: Vector3 in [Vector3(-2, -40, 3.2), Vector3(-20, -34, 2.6), Vector3(-34, -22, 2.4)]:
		Ink.flat(ci, xf, Ink.lumpy(Vector2(q.x, q.y), q.z * 1.3, q.z, 12, 0.3, 4.0), Color(body_pal["ombre"].darkened(0.3), 0.8))
	# Feuille de nénuphar morte collée au dos, déchirée.
	var pad := Ink.oval(Vector2(-14, -50), 11.0, 4.5, 20, -0.08)
	var notch := PackedVector2Array([Vector2(-14, -50), Vector2(-6, -56), Vector2(-3, -48)])
	var cut := Geometry2D.clip_polygons(pad, notch)
	if not cut.is_empty():
		Ink.part(ci, xf, cut[0], {"clair": Art.bc("seve", "detail"), "ombre": Art.bc("seve", "detail").darkened(0.35), "reflet": Art.bc("os")}, 1.2, 1.0, 0.3)
	for a: float in [-2.6, -1.9, -0.6]:
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-14, -50), Vector2(-14, -50) + Vector2(cos(a) * 9.0, sin(a) * 3.6)]), 0.7, Art.bc("seve", "detail").darkened(0.45))
	# La Flétrissure ronge l'arrière : plaque sombre, pustules de braise qui couvent.
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-33, -30), 7.0, 9.0, 22, 0.45, 3.0, 0.8), Art.bc("ronge"))
	for q: Vector3 in [Vector3(-34, -33, 2.2), Vector3(-30, -24, 1.6), Vector3(-37, -26, 1.3)]:
		Ink.ember(ci, xf, Ink.oval(Vector2(q.x, q.y), q.z, q.z * 0.9, 10), 0.3 + 0.6 * kk)
	Ink.sparks(ci, xf, Vector2(-34, -38), Vector2(0.1, -1.0), 2, t, 1.1, 0.5 + 0.5 * kk)
	# Bouche : un long sourire de crapaud.
	Ink.brush(ci, xf, PackedVector2Array([Vector2(40, -25), Vector2(30, -21), Vector2(18, -22), Vector2(10, -27)]), 2.0, Ink.encre(), 0.6, 0.0)
	# Narine.
	Ink.flat(ci, xf, Ink.oval(Vector2(38, -33), 1.2, 0.9, 8), Ink.encre())
	if elite:
		S.elite(ci, xf, Vector2(8, -24), 6.0, 18.0, t, PackedVector2Array([Vector2(-36, -40), Vector2(-24, -51), Vector2(-6, -54), Vector2(10, -48)]))
	# Yeux saillants : braise, pupille fendue à l'horizontale (celui du fond plus petit). Mi-clos sonné.
	var glow := 0.3 + 0.7 * maxf(kk, lift)
	var lid := clampf(maxf(dazed * 0.55, 1.0 if hit > 0.4 else 0.0) + Ink.blink(t, 1.1) * (1.0 - kk), 0.0, 1.0)
	var gaze := Vector2.from_angle(clampf(la, -0.6, 0.6)) * 0.9
	_eye(ci, xf, Vector2(33, -42), 4.4, glow, lid, gaze, far)
	_eye(ci, xf, Vector2(22, -45), 6.2, glow, lid, gaze, body_pal)
	# Cuisse repliée sur le flanc, et le pied palmé ; tendue vers l'arrière en l'air.
	var thigh := Ink.oval(Vector2(-14, -16) + Vector2(-4, 4) * lift, 15.0, 10.0, 22, -0.35 - 0.4 * lift)
	Ink.part(ci, xf, thigh, body_pal, 2.0, 1.0, 0.6)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-24, -18), Vector2(-14, -23), Vector2(-4, -20)]), 1.1, body_pal["ombre"].darkened(0.3))
	_foot(ci, xf, Vector2(-6, -1) + Vector2(-26, 8) * lift, 0.1 - 0.9 * lift, body_pal)
	# Patte avant : main palmée posée devant ; tendue vers le sol en l'air.
	_arm(ci, xf, Vector2(16, -16), Vector2(22, 0) + Vector2(12, 8) * lift, body_pal)
	# Gouttes d'eau qui tombent de lui en l'air.
	S.drips(ci, xf, Vector2(-4, -6), 3, t * 1.6, 1.4, Art.ec("seve", "clair").lerp(Art.bc("seve", "reflet"), 0.5), lift)
	Ink.mono = prev_mono
	Ink.flash = 0.0


## Œil saillant : paupière (bourrelet), iris de braise, pupille horizontale qui suit la cible.
static func _eye(ci: CanvasItem, xf: Transform2D, c: Vector2, r: float, glow: float, lid: float, gaze: Vector2, pal: Dictionary) -> void:
	Ink.part(ci, xf, Ink.oval(c, r * 1.25, r * 1.15, 18), pal, 1.6, 1.0, 0.9)
	if lid >= 0.95:
		Ink.brush(ci, xf, PackedVector2Array([c + Vector2(-r * 0.9, r * 0.1), c + Vector2(r * 0.9, r * 0.1)]), 1.4, Ink.encre())
		return
	Ink.ember(ci, xf, Ink.oval(c + Vector2(0.4, 0.3), r * 0.9, r * 0.8, 16), glow)
	Ink.flat(ci, xf, Ink.oval(c + Vector2(0.4, 0.3) + gaze, r * 0.5, r * 0.16, 10), Art.bc("ronge"))
	if lid > 0.0:
		var top := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			top.append(c + Vector2(cos(a) * r * 1.05, sin(a) * r * 1.0))
		for i in range(12, -1, -1):
			var a := PI + PI * i / 12.0
			top.append(c + Vector2(cos(a) * r * 1.05, -r * 1.0 + (sin(a) + 1.0) * r * 2.0 * lid * 0.0 + r * 2.0 * lid - r))
		Ink.flat(ci, xf, top, pal["ombre"])
		Ink.brush(ci, xf, PackedVector2Array([c + Vector2(-r, -r + r * 2.0 * lid), c + Vector2(r, -r + r * 2.0 * lid)]), 1.0, Ink.encre())


## Patte avant : épaule → main palmée.
static func _arm(ci: CanvasItem, xf: Transform2D, sh: Vector2, hand: Vector2, pal: Dictionary) -> void:
	var el := sh.lerp(hand, 0.5) + Vector2(3, -1)
	var pts := PackedVector2Array([sh, el, hand])
	Ink.brush(ci, xf, pts, 10.0, Ink.encre(), 1.0, 0.6)
	Ink.brush(ci, xf, pts, 7.6, pal["clair"], 1.0, 0.5)
	for i in 3:
		var a := -0.5 + i * 0.5
		Ink.brush(ci, xf, PackedVector2Array([hand, hand + Vector2(cos(a) * 5.0, sin(a) * 1.6 + 0.6)]), 2.2, pal["ombre"], 1.0, 0.0)


## Pied palmé de la patte arrière, posé en p, orienté de a (radians, local).
static func _foot(ci: CanvasItem, xf: Transform2D, p: Vector2, a: float, pal: Dictionary) -> void:
	var web := PackedVector2Array([p])
	for i in 4:
		var aa := a - 0.45 + i * 0.3
		web.append(p + Vector2.from_angle(aa) * Vector2(11.0, 3.6))
	Ink.part(ci, xf, web, pal, 1.4, 1.0, 0.0)
	for i in 4:
		var aa := a - 0.45 + i * 0.3
		Ink.brush(ci, xf, PackedVector2Array([p, p + Vector2.from_angle(aa) * Vector2(11.5, 3.8)]), 1.2, pal["ombre"].darkened(0.3), 1.0, 0.0)
