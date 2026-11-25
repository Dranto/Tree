## Piste A, « Esprit masqué » : un petit esprit de la forêt sous un masque de bois clair aux yeux de sève.
## En grandissant : il s'étire, sa cape de feuilles s'allonge et se déchire en pointes, des bois poussent
## du masque, une écharpe de feuilles flotte derrière lui, la graine devient le cœur d'un bâton, et à
## maturité des feuilles-glyphes tournent autour de lui. Les marques du masque, la lueur des yeux et
## les bois prennent la couleur de la branche.
## Pose : t, walk, moving, look, hit, build, evol (0 → 1) ou stade (1 → 3).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const K = preload("res://scripts/creature_art/heros/commun.gd")

const HEIGHT := 56.0


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var look: float = o.get("look", 0.0)
	var build: String = o.get("build", "aucun")
	var p := K.progress(o)
	var flip := cos(look) < 0.0
	Ink.flash = o.get("hit", 0.0)
	var base := Ink.frame(feet, h * (0.62 + 0.38 * p), flip)
	var u := base.get_scale().y
	var acc := K.accent(build)
	var gl := K.glow(build)
	var lv := K.leaves(build)
	var dark := {"clair": lv["ombre"], "ombre": lv["ombre"].darkened(0.35), "reflet": lv["clair"]}
	K.aura(ci, base, t, p, acc)
	Ink.ground_shadow(ci, base, Vector2.ZERO, 18.0 + 8.0 * p)
	var bob := sin(t * TAU / 2.4) * 1.2 - absf(sin(walk)) * 3.0 * mv
	var xf := base * Transform2D(0.06 * mv, Vector2.ONE, 0.0, Vector2(0, bob))
	var legl := 10.0 + 14.0 * p
	var ch := 30.0 + 26.0 * p
	var top := -legl - ch
	var rm := 17.0 - 2.0 * p
	var mc := Vector2(3.0, top - rm * 0.55)
	var sway := sin(t * 1.7)
	# Écharpe de feuilles qui flotte derrière (dès les premiers nœuds).
	if p > 0.15:
		var sl := 10.0 + 52.0 * p
		var sc := PackedVector2Array()
		for i in 9:
			var k := i / 8.0
			sc.append(Vector2(-2.0 - sl * 0.8 * k, top + 4.0 + sin(k * 4.0 - t * 3.0) * 4.0 * k + sl * 0.55 * k * k))
		Ink.brush(ci, xf, sc, 8.6, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, xf, sc, 6.4, acc.lerp(K.CREME, 0.15), 1.0, 0.0)
		for i in [3, 5, 7]:
			if i / 8.0 < p + 0.2:
				K.leaf(ci, xf, sc[i], PI * 0.62 + 0.3 * sin(t * 2.0 + i), 6.0 + 3.0 * p, 3.6, lv, 0.0, 0.9)
	# Bois du masque (côté du fond).
	if p > 0.25:
		_antler(ci, xf, mc + Vector2(-rm * 0.55, -rm * 0.7), -1.0, p, build, acc, gl, t, true)
	# Capuche : un fond sombre qui découpe le masque.
	Ink.part(ci, xf, Ink.oval(mc + Vector2(-3.0, -1.0), rm * 1.18, rm * 1.15, 28), dark, 2.0, 1.0, 0.3)
	# Jambes fines.
	var sw := sin(walk) * 6.0 * mv
	for j in 2:
		var x := (3.0 if j == 0 else -4.0)
		var f := Vector2(x + (sw if j == 0 else -sw), 0)
		var pts := PackedVector2Array([Vector2(x, -legl - 2), Vector2(x + 1.0, -legl * 0.45), f + Vector2(0, -2)])
		Ink.brush(ci, xf, pts, 5.6, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, xf, pts, 3.4, Color("5b4636") if j == 0 else Color("3f3026"), 1.0, 1.0)
		Ink.part(ci, xf, Ink.leaf(f + Vector2(-3, -1.5), 0.0, 9.0, 4.0), {"clair": Color("5b4636"), "ombre": Color("3f3026")}, 1.0, 1.0, 0.0)
	# Cape : du cou à l'ourlet déchiré en pointes de feuilles.
	var sh := 9.0 + 5.0 * p
	var hem := 15.0 + 12.0 * p
	var cape := PackedVector2Array([Vector2(-sh, top + 4.0), Vector2(sh, top + 4.0)])
	var nt := 4 + roundi(4.0 * p)
	cape.append(Vector2(hem + 1.0 * sway, -legl + 2.0))
	for i in nt + 1:
		var k := i / float(nt)
		var x := lerpf(hem, -hem - 6.0 * p, k)
		var y := -legl + 2.0 + (5.0 + 6.0 * p) * (1.0 if i % 2 == 0 else 0.0) * (0.0 if i == 0 or i == nt else 1.0) + sway * k * 1.5
		cape.append(Vector2(x, y))
	cape.append(Vector2(-hem - 6.0 * p + sway, -legl + 2.0))
	var cpal := {"clair": lv["ombre"].lightened(0.12), "ombre": lv["ombre"].darkened(0.35), "reflet": lv["clair"]}
	Ink.part(ci, xf, cape, cpal, 2.2, 1.0, 0.6)
	# Doublure crème visible par l'ouverture de la cape.
	var op := PackedVector2Array([Vector2(1.0, top + 5.0), Vector2(5.0, top + 5.0), Vector2(hem * 0.55, -legl + 4.0), Vector2(-hem * 0.1, -legl + 4.0)])
	Ink.part(ci, xf, op, {"clair": K.CREME, "ombre": K.CREME.darkened(0.18), "reflet": Color.WHITE}, 1.0, 1.0, 0.4)
	# Ourlet teinté de la branche.
	var hp := PackedVector2Array()
	for i in range(2, cape.size()):
		hp.append(cape[i] + Vector2(0, -3.0))
	Ink.brush(ci, xf, hp, 2.6, acc, 1.0, 1.0)
	# Plis.
	for x: float in [-5.0, 4.0]:
		Ink.brush(ci, xf, PackedVector2Array([Vector2(x * 0.5, top + 8.0), Vector2(x, -legl * 0.9 - ch * 0.3), Vector2(x * 1.5, -legl)]), 1.2, cpal["ombre"].darkened(0.1))
	# Collerette de feuilles sur les épaules (grandit).
	var nc := 3 + roundi(4.0 * p)
	for i in nc:
		var a := PI * (0.15 + 0.7 * i / maxf(nc - 1, 1)) + 0.05 * sway
		K.leaf(ci, xf, Vector2(0, top + 3.0), a, 9.0 + 7.0 * p, 5.0 + 2.0 * p, lv if i % 2 == 0 else dark, 0.05, 1.0)
	# Cœur de sève sur la poitrine, avec des veines vers les bords à maturité.
	var core := Vector2(4.0, top + 16.0 + 6.0 * p)
	if p > 0.3:
		var k := (p - 0.3) / 0.7
		if not Ink.mono:
			for i in 5:
				var a := -PI * 0.5 + (i - 2) * 0.7
				var vein := PackedVector2Array([core, core + Vector2.from_angle(a) * 6.0 * k + Vector2(1, 2), core + Vector2.from_angle(a) * 12.0 * k])
				Ink.brush(ci, xf, vein, 1.2, Color(gl, 0.8 * k), 1.0, 0.0)
			Ink.halo(ci, xf * core, 9.0 * u * (0.6 + k), gl, 1.0 + k)
		Ink.part(ci, xf, Ink.oval(core, 2.6 + 1.6 * k, 3.2 + 1.8 * k, 14), {"clair": gl, "ombre": gl.darkened(0.3), "reflet": Color.WHITE}, 1.0, 1.0, 1.0)
	# Masque : ovale à menton pointu, éclairé, marques de la branche.
	var mask := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var d := Vector2(cos(a), sin(a))
		var r := Vector2(rm * 0.86, rm)
		if d.y > 0.0:
			r.x *= 1.0 - 0.35 * d.y * d.y
			r.y *= 1.0 + 0.12 * d.y
		mask.append(mc + d * r)
	Ink.part(ci, xf, mask, {"clair": Color("fbf6e8"), "ombre": Color("d9ccb0"), "reflet": Color.WHITE}, 2.0, 1.0, 1.0)
	# Arête du nez (trois quarts).
	Ink.brush(ci, xf, PackedVector2Array([mc + Vector2(rm * 0.38, -rm * 0.25), mc + Vector2(rm * 0.5, rm * 0.25), mc + Vector2(rm * 0.36, rm * 0.36)]), 1.2, Color("c9b99a"), 0.4, 0.4)
	if p > 0.2:
		var k := clampf((p - 0.2) / 0.5, 0.0, 1.0)
		# Trait du front et larmes sous les yeux, en couleur de branche.
		Ink.flat(ci, xf, Ink.leaf(mc + Vector2(rm * 0.08, -rm * 0.95), PI * 0.5, rm * 0.6 * k, 3.0), acc)
		for q: Vector2 in [mc + Vector2(-rm * 0.18, rm * 0.2), mc + Vector2(rm * 0.62, rm * 0.18)]:
			Ink.flat(ci, xf, Ink.leaf(q, PI * 0.5 - 0.1, rm * 0.45 * k, 2.4 * (0.8 if q.x > mc.x + rm * 0.3 else 1.0)), acc)
	if p > 0.7:
		var k := (p - 0.7) / 0.3
		for q: Vector2 in [mc + Vector2(-rm * 0.48, -rm * 0.45), mc + Vector2(rm * 0.62, -rm * 0.5)]:
			Ink.flat(ci, xf, Ink.oval(q, 1.4 * k, 1.4 * k, 8), acc)
	# Yeux : fentes lumineuses (couleur de branche, plus vives en grandissant).
	K.slit(ci, xf, mc + Vector2(-rm * 0.12, -rm * 0.08), -0.25, 8.0 + 1.0 * p, 4.6, gl, 0.6 + 0.6 * p)
	K.slit(ci, xf, mc + Vector2(rm * 0.52, -rm * 0.1), -0.32, 5.6, 3.6, gl, 0.6 + 0.6 * p)
	# Pousse au sommet (graine de départ) qui laisse place aux bois.
	if p < 0.6:
		var k := 1.0 - p / 0.6
		Ink.brush(ci, xf, PackedVector2Array([mc + Vector2(0, -rm * 1.05), mc + Vector2(1, -rm * 1.4)]), 2.2, lv["ombre"], 1.0, 0.4)
		K.leaf(ci, xf, mc + Vector2(1, -rm * 1.4), -2.4 + 0.1 * sway, 9.0 * k, 5.0 * k, lv)
		K.leaf(ci, xf, mc + Vector2(1, -rm * 1.4), -0.7 + 0.1 * sway, 8.0 * k, 4.6 * k, lv)
	if p > 0.25:
		_antler(ci, xf, mc + Vector2(rm * 0.35, -rm * 0.8), 1.0, p, build, acc, gl, t, false)
	# Bras et graine : la graine flotte dans la main au début, puis couronne un bâton.
	var hand := Vector2(sh + 4.0, top + 16.0 + 4.0 * p)
	if p > 0.45:
		var k := clampf((p - 0.45) / 0.35, 0.0, 1.0)
		var st := PackedVector2Array([Vector2(hand.x + 2.0, -2.0), hand, Vector2(hand.x - 1.0, top - (6.0 + 22.0 * k))])
		Ink.brush(ci, xf, st, 5.0, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, xf, st, 3.0, Color("8a6a4a"), 1.0, 1.0)
		var tip: Vector2 = st[2]
		for j in 3:
			var a := -PI * 0.5 + (j - 1) * 0.7
			Ink.brush(ci, xf, PackedVector2Array([tip + Vector2(0, 4), tip + Vector2.from_angle(a) * 7.0 + Vector2(0, 2)]), 2.0, Color("8a6a4a"), 1.0, 0.2)
		K.seed(ci, xf * (tip + Vector2(0, -2.0 + sin(t * 2.6) * 1.0)), u, p, t, gl, 4.6 + 1.0 * k)
	Ink.part(ci, xf, Ink.leaf(Vector2(sh - 3.0, top + 6.0), (hand - Vector2(sh - 3.0, top + 6.0)).angle(), 14.0, 7.0), {"clair": K.CREME, "ombre": K.CREME.darkened(0.2)}, 1.4, 1.0, 0.5)
	Ink.part(ci, xf, Ink.oval(hand, 2.8, 2.6, 10), {"clair": Color("5b4636"), "ombre": Color("3f3026")}, 1.0)
	if p <= 0.45:
		K.seed(ci, xf * (hand + Vector2(8, -6 + sin(t * 2.6) * 1.4)), u, p, t, gl)
	# Feuilles-glyphes en orbite, à maturité.
	if p > 0.7 and not Ink.mono:
		var k := (p - 0.7) / 0.3
		for i in 3:
			var a := t * 1.1 + i * TAU / 3.0
			var q := Vector2(cos(a) * (hem + 12.0), top + 10.0 + sin(a) * 8.0)
			Ink.halo(ci, xf * q, 6.0 * u, gl, k)
			Ink.flat(ci, xf, Ink.leaf(q + Vector2(-3, 0), a, 7.0, 3.6), Color(gl.lerp(Color.WHITE, 0.3), k), 0.6)


## Bois du masque : rameaux qui poussent puis se ramifient ; épineux (Ronce), à pointes lumineuses
## (Sève), noueux (Racine), à plumes (Vent).
static func _antler(ci: CanvasItem, xf: Transform2D, b: Vector2, side: float, p: float, build: String, acc: Color, gl: Color, t: float, far: bool) -> void:
	var k := clampf((p - 0.25) / 0.75, 0.0, 1.0)
	var l := 6.0 + 26.0 * k
	var wood := Color("8a6a4a").darkened(0.25 if far else 0.0)
	var a0 := -PI * 0.5 - 0.45 * side * -1.0 - (0.25 if far else 0.0)
	var tip := b + Vector2.from_angle(a0 - 0.35) * l
	var mid := b + Vector2.from_angle(a0) * l * 0.5
	var main := PackedVector2Array([b, mid, tip])
	Ink.brush(ci, xf, main, 5.4 + 1.5 * k, Ink.encre(), 1.0, 0.15)
	Ink.brush(ci, xf, main, 3.4 + 1.2 * k, wood, 1.0, 0.15)
	var tines: Array = []
	if k > 0.3:
		tines.append([mid, a0 + 0.7 * (1.0 if side > 0 else 1.0), l * 0.4])
	if k > 0.6:
		tines.append([b.lerp(tip, 0.78), a0 - 1.0, l * 0.32])
		tines.append([b.lerp(mid, 0.5), a0 + 1.1, l * 0.25])
	for tn: Array in tines:
		var tb: Vector2 = tn[0]
		var te: Vector2 = tb + Vector2.from_angle(tn[1]) * float(tn[2])
		Ink.brush(ci, xf, PackedVector2Array([tb, te]), 4.0, Ink.encre(), 1.0, 0.1)
		Ink.brush(ci, xf, PackedVector2Array([tb, te]), 2.4, wood, 1.0, 0.1)
		_tip(ci, xf, te, float(tn[1]), build, acc, gl, k, t)
	_tip(ci, xf, tip, a0 - 0.35, build, acc, gl, k, t)
	if build == "ronce":
		for q: Vector2 in [b.lerp(mid, 0.6), mid.lerp(tip, 0.5)]:
			Ink.part(ci, xf, Ink.thorn(q, a0 - PI * 0.5 * side, 3.0 + 3.0 * k, 2.0), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.7, 1.0, 0.0)


static func _tip(ci: CanvasItem, xf: Transform2D, q: Vector2, a: float, build: String, acc: Color, gl: Color, k: float, t: float) -> void:
	match build:
		"ronce":
			Ink.part(ci, xf, Ink.oval(q, 2.2 + k, 2.2 + k, 10), {"clair": acc, "ombre": acc.darkened(0.4), "reflet": Color.WHITE}, 0.8)
		"seve":
			if not Ink.mono:
				Ink.halo(ci, xf * q, 5.0 * xf.get_scale().abs().x, gl, 1.2 * k)
				ci.draw_circle(xf * q, 1.6 * xf.get_scale().abs().x, gl)
		"vent":
			Ink.part(ci, xf, Ink.leaf(q, a + 0.3 * sin(t * 2.5), 7.0 + 4.0 * k, 3.4), {"clair": Color("e4eef7"), "ombre": Color("a4bcd4")}, 0.8, 1.0, 0.0)
		"spore":
			var cap := PackedVector2Array()
			for i in 9:
				var aa := PI + PI * i / 8.0
				cap.append(q + Vector2(cos(aa) * (3.0 + 1.5 * k), sin(aa) * (2.4 + k)))
			Ink.part(ci, xf, cap, {"clair": Color("a07cc0"), "ombre": Color("4a3560"), "reflet": Color("e2d0f2")}, 0.8, 1.0, 0.4)
		"aube":
			Ink.part(ci, xf, Ink.thorn(q, a, 6.0 + 3.0 * k, 3.4), {"clair": Color("fffde6"), "ombre": Color("d9b860"), "reflet": Color.WHITE}, 0.7, 1.0, 1.0)
			if not Ink.mono:
				Ink.halo(ci, xf * q, 5.0 * xf.get_scale().abs().x, Art.ec("lumiere"), k)
		_:
			Ink.part(ci, xf, Ink.leaf(q, a + 0.4, 5.0 + 3.0 * k, 3.2), K.leaves(build), 0.8, 1.0, 0.3)
