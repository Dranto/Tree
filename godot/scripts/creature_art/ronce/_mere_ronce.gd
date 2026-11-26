## La Mère-Ronce (boss de Ronce), direction « Bestiaire d'herbier » : la souche-mère de toute la
## famille de Ronce. Une galle-mère énorme, couleur de mûre et chevelue comme le Nid, tenue sur quatre
## pattes d'insecte épineuses (le charançon), cerclée de grandes tiges de ronce arquées, des grappes de
## mûres pendues à ses flancs, et couronnée d'une rose de cendre : bouton fermé (phase 1), qui s'ouvre
## (phase 2), puis brûle à cœur ouvert (phase 3, la galle se fend de braise et des larves pointent).
## Vue de trois quarts, tournée vers la droite (le boss retourne l'image).
##
## Ce script ne dessine aucune sorte (son nom commence par « _ ») : boss_ronce.gd le cuit en sprites
## (boss_bake.gd) par groupes, et dessine en direct ce qui bouge vite (lianes, yeux, braises).
##   sol     : les racines et tiges couchées au sol, l'ombre (pose : phase) ;
##   corps   : la Mère-Ronce (pose : phase, t ; die 0 → 1 pour la mort) ;
##   dort    : endormie, repliée, la rose en bouton (arène ouverte) ;
##   vaincu  : à sa place, un roncier vivant en fleurs et en fruits.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const O = preload("res://scripts/creature_art/ronce/_outils.gd")

## 100 unités en px du jeu (1600×900) : ~170 px de haut (~205 px en 1080p), trois fois le héros.
const HEIGHT := 115.0
## Images de la respiration (une période LOOP) par phase, et de la mort.
const IDLE := 6
const LOOP := 2.4
const DEATH := 8
## Où sont les yeux (unités, tournés vers la droite) : dessinés en direct par le boss.
const EYES := [[Vector2(26, -60), -0.2, 13.0, 5.5], [Vector2(43, -55), -0.05, 10.0, 4.5], [Vector2(37, -71), -0.35, 7.5, 3.4]]
## Le cœur de la rose (unités), pour les braises et la vie qui y reprend.
## La galle et tout ce qu'elle porte sont levés de LIFT unités au-dessus des pattes.
const LIFT := 12.0
const HEART := Vector2(2, -106)
## Pieds des tiges du fond, où naissent les lianes dessinées en direct.
const VINE_FEET := [Vector2(-56, -18), Vector2(48, -20), Vector2(-20, -30), Vector2(18, -34), Vector2(-70, -10)]


static func groups() -> Dictionary:
	var sol := []
	var corps := []
	for ph in [1, 2, 3]:
		sol.append(["p%d" % ph, {"phase": ph}])
		for i in IDLE:
			corps.append(["p%d" % ph, {"phase": ph, "t": LOOP * i / IDLE}])
	for i in DEATH:
		corps.append(["mort", {"phase": 3, "die": (i + 0.5) / DEATH}])
	corps.append(["dort", {"sleep": true}])
	return {
		"sol": {"rect": Rect2(-130, -36, 260, 76), "poses": sol},
		"corps": {"rect": Rect2(-112, -150, 224, 164), "poses": corps},
		"vaincu": {"rect": Rect2(-110, -138, 220, 160), "poses": [["vaincu", {"groupe": "vaincu"}]]},
	}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	match str(o.get("groupe", "corps")):
		"sol":
			draw_ground(ci, feet, h, o)
		"vaincu":
			draw_victory(ci, feet, h, o)
		_:
			draw_body(ci, feet, h, o)


static func _phase_k(o: Dictionary) -> Array:
	var ph: int = o.get("phase", 1)
	var open: float = [0.0, 0.55, 1.0][clampi(ph, 1, 3) - 1]
	var rage: float = [0.0, 0.5, 1.0][clampi(ph, 1, 3) - 1]
	if o.get("sleep", false):
		open = -0.25
		rage = 0.0
	return [open, rage]


# --- Sol ---

## Racines et tiges couchées au sol autour d'elle, épines d'os, taches rongées ; l'ombre.
static func draw_ground(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var base := Ink.frame(feet, h, false)
	var rage: float = _phase_k(o)[1]
	Ink.ground_shadow(ci, base, Vector2(0, 2), 92.0)
	if Ink.mono:
		return
	# Sol rongé sous elle.
	Ink.flat(ci, base, Ink.lumpy(Vector2(0, 2), 96.0, 28.0, 40, 0.12, 9.0), Color(Art.bc("ronge"), 0.4))
	Ink.flat(ci, base, Ink.lumpy(Vector2(-6, 4), 70.0, 20.0, 30, 0.2, 7.0, 1.0), Color(Art.bc("ronge").darkened(0.3), 0.6))
	var cane := Art.bc("ronce", "detail").lerp(Art.bc("ronce", "ombre"), 0.45)
	var n := 9
	for i in n:
		var a := TAU * (i + 0.37) / n
		var len := 62.0 + 20.0 * sin(i * 2.3) + 12.0 * rage
		var pts := PackedVector2Array()
		for j in 7:
			var u := j / 6.0
			var w := a + 0.3 * sin(u * 3.2 + i * 1.7) * u
			pts.append(Vector2(cos(w), sin(w) * 0.34) * (30.0 + len * u) + Vector2(0, 4))
		var front := sin(a) > 0.2
		var col := cane.darkened(0.1 if front else 0.3)
		var wd := 9.0 - (i % 3) * 1.5
		Ink.brush(ci, base, pts, wd + 3.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, base, pts, wd, col, 1.0, 0.0)
		Ink.brush(ci, base, pts.slice(0, 4), wd * 0.3, col.lightened(0.3), 1.0, 0.0)
		for j in range(1, 6):
			var d := (pts[j + 1] - pts[j - 1]).normalized()
			var side := 1.0 if (i + j) % 2 else -1.0
			Ink.part(ci, base, Ink.thorn(pts[j] + d.orthogonal() * side * wd * 0.3, d.angle() - side * 1.0 - PI * 0.5 * (1.0 - side) * 0.0, 9.0 - j, 4.0), O.bone(), 0.9, 1.0, 0.0)
	# Quelques mûres tombées et éclatées (rouge sombre) dans les racines.
	for i in 6:
		var p := Vector2(cos(i * 2.1) * (55.0 + 18.0 * (i % 3)), sin(i * 2.1) * 20.0 + 6.0)
		Ink.part(ci, base, Ink.lumpy(p, 6.0, 4.5, 12, 0.15, 8.0), O.pal(0.2), 1.4, 1.0, 0.5)


# --- Corps ---

## Une grande tige de ronce arquée (repère local), de a à b, arche hh, largeur w : encre, tige, épines
## d'os, une feuille sèche. dark : assombrit (tiges du fond).
static func _cane(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, hh: float, w: float, dark: float, t: float, leaf := true) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var sway := sin(t * TAU / LOOP + a.x * 0.05) * 2.0
	for i in 11:
		var u := i / 10.0
		var p := a.lerp(b, u)
		p.y -= (hh + sway) * sin(PI * u)
		p.x += sin(PI * u) * sway * 0.5
		pts.append(p)
	var col := Art.bc("ronce", "detail").lerp(Art.bc("ronce", "ombre"), 0.4).darkened(dark)
	Ink.brush(ci, xf, pts, w + 4.0, Ink.encre(), 1.0, 0.6)
	Ink.brush(ci, xf, pts, w, col, 1.0, 0.6)
	Ink.brush(ci, xf, pts.slice(1, 7), w * 0.28, col.lightened(0.35))
	var bone := O.bone()
	if dark > 0.0:
		bone = {"clair": Art.bc("os").darkened(dark * 0.5), "ombre": Art.bc("os").darkened(0.3 + dark * 0.5)}
	for i in range(1, 10):
		var d := (pts[i + 1] - pts[i - 1]).normalized()
		var side := 1.0 if i % 2 else -1.0
		Ink.part(ci, xf, Ink.thorn(pts[i] + d.orthogonal() * side * w * 0.3, d.angle() + side * PI * 0.5 - 0.6 * side, w * 1.4, w * 0.6, -0.2 * side), bone, 1.2, 1.0, 0.0)
	if leaf and dark < 0.2:
		var q := pts[3]
		Ink.part(ci, xf, Ink.leaf(q, -PI * 0.5 - 1.0 + 0.1 * sin(t * 2.6 + a.x), 18.0, 8.0, 0.12), O.stem(), 1.4, 1.0, 0.4)
	return pts


## Grappe de mûres (3 à 6 drupes) pendue en p, mûre (k 1) ou encore verte.
static func _berries(ci: CanvasItem, xf: Transform2D, p: Vector2, n: int, s: float, ripe := 1.0) -> void:
	var pal := O.pal(0.25) if ripe > 0.5 else {"clair": Art.bc("ronce", "detail"), "ombre": Art.bc("ronce", "detail").darkened(0.4), "reflet": Art.bc("ronce", "detail").lightened(0.4)}
	Ink.brush(ci, xf, PackedVector2Array([p + Vector2(0, -s * 2.2), p + Vector2(s * 0.3, -s * 1.0), p]), 1.6, Ink.encre())
	for i in n:
		var q := p + Vector2((i % 3 - 1) * s * 1.05 + (0.5 * s if i >= 3 else 0.0), (i / 3) * s * 1.1)
		var berry := Ink.lumpy(q, s * 0.72, s * 0.8, 14, 0.12, 10.0)
		Ink.part(ci, xf, berry, pal, 1.3, 1.0, 1.0)


## La galle-mère (contour chevelu), repère local.
static func _gall_shape(breath: float, sag: float) -> PackedVector2Array:
	var pts := Ink.lumpy(Vector2.ZERO, 54.0, 44.0, 72, 0.045, 18.0)
	return Transform2D(0.0, Vector2(1.0 + sag * 0.18, breath * (1.0 - sag * 0.4)), 0.0, Vector2(0, -50 + 30.0 * sag - 44.0 * (breath - 1.0))) * pts


static func draw_body(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var die: float = o.get("die", 0.0)
	var sleep: bool = o.get("sleep", false)
	var pk := _phase_k(o)
	var open: float = pk[0]
	var rage: float = pk[1]
	var dk := Anim.ease_in_out(die) if die > 0.0 else 0.0
	var base := Ink.frame(feet, h, false)
	var cyc := sin(t * TAU / LOOP)
	var breath := 1.0 + 0.022 * cyc + 0.01 * rage * sin(t * TAU / LOOP * 2.0)
	if sleep:
		breath = 1.0 - 0.06
	# À la mort, elle s'affaisse : la galle se tasse, les pattes plient.
	var sag := dk * 0.85
	var crouch := 0.25 if sleep else 0.0
	var xf := base * Transform2D(0.0, Vector2(1.0, 1.0 - 0.12 * crouch), 0.0, Vector2(0, 6.0 * crouch))
	var legc := Art.bc("ronce", "ombre").lerp(Art.bc("ronce", "clair"), 0.25)
	var up := xf * Transform2D(0.0, Vector2(0, -LIFT * (1.0 - dk)))

	# Tiges du fond : deux grandes arches qui font la couronne de la silhouette.
	var arch := 1.0 - 0.55 * dk - (0.35 if sleep else 0.0)
	_cane(ci, base, Vector2(-92, -4), Vector2(-6, -18), 118.0 * arch, 9.0, 0.35, t, false)
	_cane(ci, base, Vector2(-34, -24), Vector2(82, -6), 134.0 * arch, 10.0, 0.25, t + 0.7, false)
	# Pattes d'insecte (le charançon) : quatre, épaisses, épineuses ; repliées endormie, pliées à la mort.
	var fold := maxf(crouch * 2.0, dk)
	var legs := [[Vector2(-34, -34), Vector2(-92, 0)], [Vector2(-12, -28), Vector2(-50, 8)], [Vector2(16, -28), Vector2(54, 8)], [Vector2(38, -36), Vector2(96, 0)]]
	for i in legs.size():
		var hip: Vector2 = legs[i][0] + Vector2(0, 26.0 * sag)
		var foot: Vector2 = legs[i][1].lerp(Vector2(legs[i][1].x * 0.6, 0), fold)
		O.leg(ci, xf, hip, foot, legc.darkened(0.3 if i in [0, 3] else 0.0), 9.0, 24.0 * (1.0 - 0.6 * fold))
	# Grappes de mûres du fond, pendues aux arches.
	if dk < 0.6:
		_berries(ci, base, Vector2(-74, -86 * arch + 4.0), 5, 6.0, 1.0)

	# La galle-mère : fibres chevelues, corps de mûre, drupes, plaques rongées, fentes de braise.
	var gall := _gall_shape(breath, sag)
	for i in 30:
		var a := TAU * i / 30.0 + 0.1
		var p := Vector2(0, -50 + 30.0 * sag) + Vector2(cos(a) * 53.0, sin(a) * 43.0 * (1.0 - sag * 0.4))
		var d := Vector2.from_angle(a + 0.4 * sin(t * TAU / LOOP + i))
		var col := Art.bc("ronce", "clair") if i % 3 else Art.bc("ronce", "reflet").darkened(0.15)
		var hair := PackedVector2Array([p - d * 3.0, p + d * 9.0, p + d * 15.0 + d.orthogonal() * 4.0])
		Ink.brush(ci, up, hair, 4.6, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, up, hair, 2.6, col.darkened(0.1), 1.0, 0.0)
	Ink.part(ci, up, gall, O.pal(), 3.2, 1.0, 0.9)
	if not Ink.mono:
		var sk := up.get_scale().abs().x
		var gc := Vector2(0, -48 + 30.0 * sag)
		for row in 9:
			for col in 11:
				var p := Vector2(-48 + col * 9.6 + (4.8 if row % 2 else 0.0), -88 + row * 9.4 + 30.0 * sag)
				var q := (p - gc) / Vector2(46, 38 * (1.0 - 0.4 * sag))
				if q.length() > 0.92:
					continue
				var lit := clampf(-(q.dot(Ink.LIGHT)) * 0.9 + 0.35, 0.0, 1.0)
				ci.draw_circle(up * (p + Vector2(0.8, 1.1)), 3.6 * sk, Ink.shade(Color(Art.bc("ronce", "ombre"), 0.45)))
				ci.draw_circle(up * (p + Vector2(-1.2, -1.4)), 1.7 * sk, Ink.shade(Color(Art.bc("ronce", "reflet"), 0.15 + 0.5 * lit)))
	# La Flétrissure ronge le bas et le flanc : plaques sombres, plus larges à chaque phase.
	var gy := 30.0 * sag
	Ink.flat(ci, up, Ink.lumpy(Vector2(-24, -22 + gy), 20.0 + 6.0 * rage, 11.0, 26, 0.35, 7.0, 0.8), Art.bc("ronge"))
	Ink.flat(ci, up, Ink.lumpy(Vector2(22, -18 + gy), 14.0, 7.0, 18, 0.3, 6.0, 0.2), Art.bc("ronge"))
	Ink.flat(ci, up, Ink.lumpy(Vector2(-40, -62 + gy), 8.0 + 6.0 * rage, 10.0, 16, 0.3, 5.0, 0.5), Art.bc("ronge"))
	# Fentes de braise de la galle : fines en phase 1, larges et nombreuses en phase 3.
	var slits := [
		[Vector2(-44, -54), Vector2(-38, -44), Vector2(-42, -32)],
		[Vector2(-12, -78), Vector2(-6, -70), Vector2(-12, -60), Vector2(-4, -50)],
		[Vector2(4, -36), Vector2(12, -32), Vector2(20, -35)],
	]
	if rage > 0.0:
		slits.append([Vector2(-30, -84), Vector2(-24, -74), Vector2(-28, -64), Vector2(-20, -56)])
		slits.append([Vector2(-26, -42), Vector2(-14, -38), Vector2(-8, -28)])
	if rage >= 1.0:
		slits.append([Vector2(10, -86), Vector2(18, -76), Vector2(12, -66)])
		slits.append([Vector2(-50, -70), Vector2(-46, -62)])
	var glow := (0.25 + 0.75 * rage) * (1.0 - dk) * (0.0 if sleep else 1.0)
	for s in slits:
		var pts := PackedVector2Array()
		for q: Vector2 in s:
			pts.append(q + Vector2(0, gy))
		Ink.brush(ci, up, pts, 4.5 + 3.5 * rage, Ink.encre())
		if not Ink.mono and glow > 0.0:
			Ink.brush(ci, up, pts, 1.8 + 3.2 * rage, Art.bc("braise").lerp(Art.bc("braise_coeur"), rage * 0.6))
	# La bouche : une fente dentée d'épines d'os, sous les yeux (tournée vers la droite).
	var mouth := PackedVector2Array([Vector2(14, -38), Vector2(24, -34), Vector2(36, -37), Vector2(46, -33), Vector2(52, -38)])
	for i in mouth.size():
		mouth[i].y += gy
	Ink.brush(ci, up, mouth, 6.0 + 2.0 * rage, Ink.encre(), 0.3, 0.3)
	if not Ink.mono and glow > 0.0:
		Ink.brush(ci, up, mouth, 2.0 + 1.5 * rage, Color(Art.bc("braise"), glow))
	for i in 4:
		var p := mouth[i].lerp(mouth[i + 1], 0.5)
		Ink.part(ci, up, Ink.thorn(p + Vector2(0, -2), -PI * 0.5 + 0.2 * (i - 1.5), 6.0, 3.0), O.bone(), 0.8, 1.0, 0.0)
		Ink.part(ci, up, Ink.thorn(p + Vector2(2, 2), PI * 0.5 - 0.2 * (i - 1.5), 5.0, 2.6), O.bone(), 0.8, 1.0, 0.0)
	# Orbites creuses des yeux (les yeux de braise sont dessinés en direct par le boss).
	for e in EYES:
		var p: Vector2 = e[0] + Vector2(0, gy)
		Ink.flat(ci, up, Ink.leaf(p - Vector2.from_angle(e[1]) * 2.0, e[1], e[2] + 4.0, e[3] + 4.0), Art.bc("ronge"), 1.6)
		if sleep:
			Ink.brush(ci, up, PackedVector2Array([p + Vector2(0, 1), p + Vector2.from_angle(e[1]) * e[2] * 0.9 + Vector2(0, 2)]), 2.2, Ink.encre())
	# Larves (des Rejetons) qui pointent par les pores de la galle, dès la phase 2.
	if rage > 0.0 and dk < 0.5:
		var larvae := [Vector2(-34, -74), Vector2(-48, -42)] if rage < 1.0 else [Vector2(-34, -74), Vector2(-48, -42), Vector2(-16, -30), Vector2(-6, -84)]
		for i in larvae.size():
			var p: Vector2 = larvae[i] + Vector2(0, gy)
			var poke := 0.6 + 0.4 * sin(t * TAU / LOOP + i * 1.9)
			Ink.flat(ci, up, Ink.oval(p, 7.0, 4.0, 14), Art.bc("ronge"), 1.6)
			var head := Ink.oval(p + Vector2(-1.5, -5.0 * poke), 5.0, 5.5, 14)
			Ink.part(ci, up, head, O.pal(0.1), 1.4, 1.0, 0.6)
			if not Ink.mono:
				Ink.ember(ci, up, Ink.leaf(p + Vector2(-0.5, -6.0 * poke), -0.2, 3.2, 1.8), 0.6)
	# Grappes de mûres du devant, pendues aux flancs.
	if dk < 0.6:
		_berries(ci, up, Vector2(-58, -38 + gy), 6, 6.5, 1.0)
		_berries(ci, up, Vector2(56, -58 + gy), 4, 5.8, 1.0 if rage > 0.0 else 0.0)

	# La rose de cendre : couronne de la galle. Pétales posés en anneau (vue de trois quarts), triés
	# d'arrière en avant ; le cœur de braise entre les deux.
	_rose(ci, up, Vector2(2, -94 + 34.0 * sag), open, rage, t, dk)

	# Tige du devant : une arche basse qui passe devant les pattes.
	_cane(ci, base, Vector2(28, 2), Vector2(104, -4), 46.0 * (1.0 - 0.5 * dk), 7.5, 0.0, t + 1.3)


## Rose de cendre en c (repère local) : open -0,25 (bouton serré) → 1 (grande ouverte), rage :
## pétales déchirés, cœur à nu ; dk : à la mort, les pétales se détachent et tombent.
static func _rose(ci: CanvasItem, xf: Transform2D, c: Vector2, open: float, rage: float, t: float, dk: float) -> void:
	var rings := [[8, 18.0, 44.0, 32.0, 0.0], [6, 10.0, 34.0, 26.0, 0.6], [5, 4.0, 24.0, 18.0, 1.1]]
	var heart_r := 4.0 + 12.0 * maxf(open, 0.0)
	var petals := []
	for ri in rings.size():
		var rg: Array = rings[ri]
		var n: int = rg[0]
		# Angle des pétales depuis la verticale : serré en bouton, couché quand elle est ouverte.
		var theta := lerpf(0.28 + 0.05 * ri, 1.3 - 0.12 * ri, clampf(open, 0.0, 1.0)) - 0.12 * minf(open, 0.0) * -1.0
		for i in n:
			var a: float = TAU * i / n + rg[4] + 0.05 * sin(t * TAU / LOOP + i)
			var dir3 := Vector3(cos(a) * sin(theta), -cos(theta), sin(a) * sin(theta))
			var b3 := Vector3(cos(a), 0.0, sin(a)) * float(rg[1]) * (0.6 + 0.4 * maxf(open, 0.0))
			petals.append({"z": sin(a) * (1.0 + ri * 0.01) - ri * 0.3, "a": a, "b3": b3, "d3": dir3, "len": float(rg[2]) * (1.0 + 0.15 * maxf(open, 0.0)), "w": float(rg[3]), "ri": ri, "i": i})
	petals.sort_custom(func(p, q): return p["z"] < q["z"])
	var heart_drawn := false
	for p in petals:
		if not heart_drawn and p["z"] > -0.1 and open > 0.05:
			_rose_heart(ci, xf, c, heart_r, rage, t, dk)
			heart_drawn = true
		var b3: Vector3 = p["b3"]
		var d3: Vector3 = p["d3"]
		var b := c + Vector2(b3.x, b3.z * 0.5)
		var d := Vector2(d3.x, d3.y + d3.z * 0.5)
		var len: float = float(p["len"]) * d.length()
		var ang := d.angle()
		if dk > 0.0:
			# Les pétales se détachent et tombent en tournoyant.
			var fall := Anim.ease_in(clampf(dk * 1.4 - p["i"] * 0.05 - p["ri"] * 0.1, 0.0, 1.0))
			b += Vector2(cos(p["a"]) * 50.0 * fall, 90.0 * fall)
			ang += fall * (2.0 if int(p["i"]) % 2 else -2.0)
			if fall >= 0.98:
				continue
		var ri: int = p["ri"]
		var shade: float = 0.22 * (1.0 - (p["z"] + 1.0) * 0.5) + 0.08 * ri
		var pal := {"clair": Art.bc("ronce", "clair").lerp(Art.bc("ronce", "reflet"), 0.2 - 0.1 * ri).darkened(shade),
			"ombre": Art.bc("ronce", "ombre").darkened(shade * 0.6), "reflet": Art.bc("ronce", "reflet")}
		var pts := _petal(b, ang, maxf(len, 8.0), p["w"] * (1.0 - 0.2 * maxf(open, 0.0)), rage if ri == 0 else rage * 0.4)
		Ink.part(ci, xf, pts, pal, 1.8, 1.0, 0.5 if p["z"] > 0.0 else 0.0)
		# Nervure, et le bord brûlé (cendre) des pétales déchirés.
		Ink.brush(ci, xf, PackedVector2Array([b + Vector2.from_angle(ang) * len * 0.15, b + Vector2.from_angle(ang) * len * 0.7]), 1.4, pal["ombre"].darkened(0.3))
		if rage > 0.0 and ri == 0 and not Ink.mono:
			var tip := b + Vector2.from_angle(ang) * len * 0.9
			ci.draw_circle(xf * tip, 2.0 * xf.get_scale().abs().x, Color(Art.bc("braise"), 0.7 * rage * (1.0 - dk)))
	if not heart_drawn and open > 0.05:
		_rose_heart(ci, xf, c, heart_r, rage, t, dk)
	# Sépales secs sous la rose.
	for i in 6:
		var a := PI * (0.12 + i * 0.152)
		Ink.part(ci, xf, Ink.leaf(c + Vector2(cos(a) * 16.0, 4.0 + sin(a) * 6.0), a + 0.2, 20.0 - absf(i - 2.5) * 2.0, 7.0, 0.1), O.stem(), 1.4, 1.0, 0.3)


## Pétale : goutte effilée de b vers l'angle a, déchirée au bout (torn).
static func _petal(b: Vector2, a: float, len: float, w: float, torn: float) -> PackedVector2Array:
	# Pétale de rose : étroit à la base, large et arrondi au bout (une petite encoche au milieu), le
	# bout déchiré en dents quand torn > 0.
	var d := Vector2.from_angle(a)
	var n := d.orthogonal()
	var pts := PackedVector2Array()
	var m := 10
	for i in m + 1:
		var u := float(i) / m
		var wid := w * 0.5 * sin(PI * pow(u, 0.6)) ** 0.8
		pts.append(b + d * len * u * 0.97 + n * wid)
	var notch := 0.06 + 0.2 * torn
	pts.append(b + d * len * (1.0 - notch))
	for i in range(m, -1, -1):
		var u := float(i) / m
		var wid := w * 0.5 * sin(PI * pow(u, 0.6)) ** 0.8
		var tear := 0.0
		if torn > 0.0 and i >= m - 2:
			tear = -len * 0.12 * torn * (1.0 if i % 2 else 0.4)
		pts.append(b + d * (len * u * 0.97 + tear) - n * wid)
	return pts


## Cœur de braise de la rose : de plus en plus à nu (r), il s'éteint à la mort.
static func _rose_heart(ci: CanvasItem, xf: Transform2D, c: Vector2, r: float, rage: float, t: float, dk: float) -> void:
	if Ink.mono:
		Ink.flat(ci, xf, Ink.oval(c, r, r * 0.6, 18), Ink.encre())
		return
	var fade := 1.0 - dk
	Ink.flat(ci, xf, Ink.oval(c, r + 3.0, (r + 3.0) * 0.62, 20), Art.bc("ronge"), 1.6)
	Ink.halo(ci, xf * c, r * 2.2 * xf.get_scale().abs().x, Art.bc("braise"), (0.6 + 0.8 * rage) * fade)
	Ink.flat(ci, xf, Ink.oval(c, r, r * 0.6, 18), Art.bc("braise").darkened(0.2 * (1.0 - fade)))
	Ink.flat(ci, xf, Ink.oval(c + Vector2(-r * 0.15, -r * 0.1), r * 0.55, r * 0.33, 14), Art.bc("braise_coeur").lerp(Color.WHITE, 0.2 * rage * fade))
	# Étamines brûlées.
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var q := c + Vector2(cos(a) * r * 0.6, sin(a) * r * 0.35)
		Ink.brush(ci, xf, PackedVector2Array([q, q + Vector2(cos(a) * 3.0, -6.0)]), 1.4, Ink.encre())
		ci.draw_circle(xf * (q + Vector2(cos(a) * 3.0, -6.5)), 1.6 * xf.get_scale().abs().x, Art.bc("braise_coeur"))


# --- Vaincue ---

## À sa place : un roncier vivant, feuilles vertes, roses ouvertes et mûres mûres. Pas de braise.
static func draw_victory(ci: CanvasItem, feet: Vector2, h: float, _o := {}) -> void:
	var base := Ink.frame(feet, h, false)
	Ink.ground_shadow(ci, base, Vector2(0, 2), 80.0)
	var green := {"clair": Art.ec("racine", "clair").darkened(0.1), "ombre": Art.ec("racine", "clair").darkened(0.5), "reflet": Art.ec("racine", "clair").lightened(0.35)}
	var stem := {"clair": Color("6f8f3a"), "ombre": Color("3e5a22"), "reflet": Color("b8d27a")}
	var rose := {"clair": Color("f27f86"), "ombre": Color("b8475a"), "reflet": Color("ffd6d8")}
	# Tiges arquées, vertes cette fois, avec leurs épines (la ronce reste une ronce).
	var canes := [[Vector2(-96, 0), Vector2(-4, -6), 96.0], [Vector2(-40, -4), Vector2(84, 0), 116.0], [Vector2(-70, 2), Vector2(40, 4), 60.0], [Vector2(20, 2), Vector2(100, -2), 44.0]]
	var tips := []
	for c in canes:
		var pts := PackedVector2Array()
		for i in 11:
			var u := i / 10.0
			var p: Vector2 = c[0].lerp(c[1], u)
			p.y -= c[2] * sin(PI * u)
			pts.append(p)
		Ink.brush(ci, base, pts, 11.0, Ink.encre(), 1.0, 0.6)
		Ink.brush(ci, base, pts, 7.5, stem["clair"], 1.0, 0.6)
		Ink.brush(ci, base, pts.slice(1, 6), 2.0, stem["reflet"])
		for i in range(1, 10, 2):
			var d := (pts[i + 1] - pts[i - 1]).normalized()
			Ink.part(ci, base, Ink.thorn(pts[i] + d.orthogonal() * 2.0, d.angle() - PI * 0.5 + 0.5, 7.0, 3.0), {"clair": Color("d9c48a"), "ombre": Color("9a8452")}, 0.8, 1.0, 0.0)
		tips.append(pts)
	# Feuillage : bouquets de feuilles dentées le long des tiges.
	for pts in tips:
		for i in range(2, 10, 2):
			var q: Vector2 = pts[i]
			for j in 3:
				var a := -PI * 0.5 + (j - 1) * 0.9 + sin(i * 1.3) * 0.4
				Ink.part(ci, base, Ink.leaf(q, a, 18.0, 9.0, 0.1 * (j - 1)), green, 1.4, 1.0, 0.6)
	# Un buisson au pied.
	for i in 7:
		var p := Vector2((i - 3) * 22.0, -18.0 - 10.0 * (i % 2))
		Ink.part(ci, base, Ink.lumpy(p, 22.0, 17.0, 40, 0.07, 9.0, i), green, 2.0, 1.0, 0.6)
	# Roses ouvertes et grappes de mûres mûres.
	var spots := [Vector2(-62, -92), Vector2(-14, -116), Vector2(40, -118), Vector2(66, -80), Vector2(-40, -48), Vector2(10, -44), Vector2(58, -36)]
	for i in spots.size():
		var p: Vector2 = spots[i]
		if i % 3 == 2:
			_berries(ci, base, p + Vector2(0, 6), 5, 5.5, 1.0)
			continue
		for j in 5:
			var a := TAU * j / 5.0 + i
			Ink.part(ci, base, Ink.oval(p + Vector2(cos(a) * 6.5, sin(a) * 4.5), 7.0, 5.5, 12), rose, 1.2, 1.0, 0.6)
		Ink.part(ci, base, Ink.oval(p, 4.0, 3.0, 10), {"clair": Color("fff3c4"), "ombre": Color("e0b860")}, 0.8, 1.0, 0.0)
