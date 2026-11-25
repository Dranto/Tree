## Lieux des « Paysages d'herbier » : des choses du monde vues de trois quarts, plus des pictogrammes.
##   - Cœur : une chose vivante et enracinée de la région. Roncier : un nœud de ronces qui serre un
##     gros bouton fendu de braise ; purifié, le nœud s'ouvre en églantine. Marais : des vesses-de-loup
##     gonflées, craquelées de braise, au milieu de leur mycélium ; purifié, une couronne de petits
##     chapeaux qui luisent. La zone de siège reste dite par un cercle en tirets (fonction lisible).
##   - Sanctuaire : un cercle de pierres levées autour d'une pierre creuse où brûle la flamme de sève
##     (vert sève : le signe du vivant), éteinte tant qu'on ne l'a pas ravivé.
##   - Autel : une vraie pierre taillée, son signe gravé luit, la greffe flotte au-dessus.
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")


# --- Cœur ---


## Fente de braise : un trait brisé qui se ramifie (jamais un signe régulier), lueur autour.
static func _crack(ci: CanvasItem, from: Vector2, dir: Vector2, l: float, s: float, glow: float, seed: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var pts := PackedVector2Array([from])
	var p := from
	var a := dir.angle()
	for i in 5:
		a += r.randf_range(-0.6, 0.6)
		p += Vector2.from_angle(a) * l / 5.0
		pts.append(p)
	ci.draw_polyline(pts, Color(Art.bc("braise"), 0.18 + 0.2 * glow), 5.0 * s, true)
	ci.draw_polyline(pts, Art.bc("braise"), 1.8 * s, true)
	ci.draw_polyline(pts.slice(0, 4), Art.bc("braise_coeur"), 0.8 * s, true)
	var b := pts[2]
	var e := b + Vector2.from_angle(a + 1.1) * l * 0.3
	ci.draw_polyline(PackedVector2Array([b, b.lerp(e, 0.5) + Vector2(1, -1), e]), Art.bc("braise"), 1.2 * s, true)


## Cœur de la région en c (pied au sol), taille s (1 : Grand Cœur). purified : purifié. zone : rayon de
## la zone de siège (0 : pas de cercle). t : temps (pulsation).
static func heart(ci: CanvasItem, reg: String, c: Vector2, s: float, purified: bool, zone: float, t: float) -> void:
	if not purified and zone > 0.0:
		_zone(ci, c, zone, t)
	if reg == "spore":
		_coeur_marais(ci, c, s, purified, t)
	else:
		_coeur_roncier(ci, c, s, purified, t)


## Cercle de siège au sol : tirets braise, vus de trois quarts (ellipse).
static func _zone(ci: CanvasItem, c: Vector2, zone: float, t: float) -> void:
	var n := 56
	for i in n:
		if i % 2 == 1:
			continue
		var a0 := TAU * i / n + t * 0.05
		var a1 := TAU * (i + 1) / n + t * 0.05
		var p0 := c + Vector2(cos(a0) * zone, sin(a0) * zone * 0.62)
		var p1 := c + Vector2(cos(a1) * zone, sin(a1) * zone * 0.62)
		ci.draw_line(p0, p1, Color(Art.bc("braise"), 0.38), 2.0, true)


## Racines rampantes autour d'un Cœur (ronces noires ou mycélium), braises le long des racines flétries.
static func _roots(ci: CanvasItem, c: Vector2, s: float, col: Color, light: Color, n: int, reach: float, ember: bool, thorns: bool, seed: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	for i in n:
		var a := TAU * i / n + r.randf_range(-0.2, 0.2)
		var pts := PackedVector2Array()
		var p := c + Vector2(cos(a) * 14.0 * s, sin(a) * 6.0 * s)
		var l := reach * s * r.randf_range(0.6, 1.0)
		for j in 9:
			var u := j / 8.0
			var aa := a + sin(u * 5.0 + i) * 0.25
			pts.append(p + Vector2(cos(aa), sin(aa) * 0.6) * l * u)
		O.brush(ci, pts, 5.0 * s, col, 1.0, 0.0)
		O.brush(ci, pts, 1.8 * s, light, 1.0, 0.0)
		if thorns:
			for j in range(2, 8, 2):
				var d := (pts[j + 1] - pts[j - 1]).normalized().orthogonal() * (1.0 if j % 4 == 0 else -1.0)
				O.poly(ci, Ink.thorn(pts[j], d.angle(), 4.5 * s, 2.0 * s), col)
		if ember and i % 2 == 0:
			var q := pts[5]
			ci.draw_circle(q, 5.0 * s, Color(Art.bc("braise"), 0.14))
			ci.draw_circle(q, 1.5 * s, Art.bc("braise"))


## Cœur du Roncier : nœud de ronces autour d'un gros bouton (cynorhodon) fendu de braise ; purifié, une
## grande églantine ouverte au milieu de ses feuilles.
static func _coeur_roncier(ci: CanvasItem, c: Vector2, s: float, purified: bool, t: float) -> void:
	var ron: Dictionary = Art.mc("ronce", "ravive" if purified else "fletri", "ronce")
	var pulse := 0.5 + 0.5 * sin(t * 2.6)
	var h := 120.0 * s
	if purified:
		ci.draw_circle(c + Vector2(0, -h * 0.3), h * 1.1, Color(Art.mc("commun", "", "seve"), 0.06))
		O.poly(ci, O.blob(c, h * 0.9, h * 0.34, 2.0, 0.12, 40), Color(Art.mc("ronce", "ravive", "sol_clair"), 0.8))
	else:
		O.poly(ci, O.blob(c, h * 0.85, h * 0.32, 2.0, 0.14, 40), Color(Art.mc("ronce", "fletri", "cendre"), 0.25))
	O.cast_shadow(ci, c, h * 0.7, h * 0.7, 0.4)
	_roots(ci, c, s, ron["ombre"], ron["clair"], 9, 150.0, not purified, true, 5)
	var bud := c + Vector2(0, -h * 0.5)
	if purified:
		_heart_canes(ci, c, h, s, ron, true)
	if not purified:
		# Le bouton : forme gonflée, sépales secs au sommet, fentes de braise qui battent.
		var pal: Dictionary = {"clair": Art.bc("ronce", "clair"), "ombre": Art.bc("ronce", "ombre"), "reflet": Art.bc("ronce", "reflet")}
		ci.draw_circle(bud, h * 0.55, Color(Art.bc("braise"), 0.05 + 0.04 * pulse))
		Ink.part(ci, Transform2D.IDENTITY, Ink.lumpy(bud, h * 0.27, h * 0.33, 30, 0.06, 6.0), pal, 2.2, 1.0, 1.0)
		for i in 5:
			var a := -PI * 0.5 + (i - 2) * 0.45
			Ink.part(ci, Transform2D.IDENTITY, Ink.leaf(bud + Vector2(0, -h * 0.3), a, h * 0.2, h * 0.07, 0.15), {"clair": Color("5a4a2e"), "ombre": Color("33281a")}, 1.2, 1.0, 0.0)
		_crack(ci, bud + Vector2(-h * 0.05, -h * 0.2), Vector2(0.2, 1), h * 0.38, s, pulse, 3)
		_crack(ci, bud + Vector2(h * 0.12, -h * 0.12), Vector2(0.1, 1), h * 0.24, s, pulse, 8)
		_heart_canes(ci, c, h, s, ron, false)
	else:
		# L'églantine : feuilles autour, cinq grands pétales vus de trois quarts, étamines dorées.
		var leaf: Dictionary = Art.mc("ronce", "ravive", "feuillage")
		for i in 7:
			var a := PI * (1.05 + 0.9 * i / 6.0)
			Ink.part(ci, Transform2D.IDENTITY, Ink.leaf(bud + Vector2(0, h * 0.05), a, h * 0.34, h * 0.16, 0.08), leaf, 1.3, 1.0, 0.6)
		var petal := {"clair": Art.mc("ronce", "ravive", "fleur"), "ombre": Art.mc("ronce", "ravive", "fleur").darkened(0.25), "reflet": Color("fff0f2")}
		for i in 5:
			var a := -PI * 0.5 + TAU * i / 5.0
			var p := bud + Vector2(cos(a) * h * 0.22, sin(a) * h * 0.13)
			Ink.part(ci, Transform2D.IDENTITY, Ink.lumpy(p, h * 0.21, h * 0.15, 18, 0.12, 2.0, a), petal, 1.4, 1.0, 0.9)
			ci.draw_line(bud, p + (p - bud) * 0.5, Color(petal["ombre"], 0.6), 1.0, true)
		ci.draw_circle(bud, h * 0.09, Art.mc("ronce", "ravive", "fleur_coeur"))
		for i in 12:
			var a := TAU * i / 12.0
			ci.draw_line(bud, bud + Vector2(cos(a), sin(a) * 0.6) * h * 0.1, Art.mc("ronce", "ravive", "fleur_coeur").darkened(0.3), 1.0, true)
			ci.draw_circle(bud + Vector2(cos(a), sin(a) * 0.6) * h * 0.1, 1.4, Color("fff2b0"))


## Trois grosses tiges de ronce qui montent en spirale et serrent le Cœur (écartées une fois purifié).
static func _heart_canes(ci: CanvasItem, c: Vector2, h: float, s: float, ron: Dictionary, purified: bool) -> void:
	var open := 1.0 if purified else 0.0
	var top := c + Vector2(0, -h * 0.62)
	for i in 3:
		var pts := PackedVector2Array()
		var a0 := TAU * i / 3.0
		for j in 14:
			var u := j / 13.0
			var rad := h * (0.32 - 0.18 * sin(u * PI) + open * 0.25 * u)
			var a := a0 + u * 2.6
			pts.append(c.lerp(top, u) + Vector2(cos(a) * rad, sin(a) * rad * 0.35 - u * open * h * 0.15))
		O.brush(ci, pts, 7.5 * s, Ink.encre(), 1.0, 0.0)
		O.brush(ci, pts, 5.5 * s, ron["ombre"], 1.0, 0.0)
		O.brush(ci, pts, 2.2 * s, ron["clair"], 1.0, 0.0)
		for j in range(2, 13, 2):
			var d := (pts[j + 1] - pts[j - 1]).normalized().orthogonal() * (1.0 if j % 4 == 0 else -1.0)
			O.poly(ci, Ink.thorn(pts[j], d.angle(), 6.0 * s, 2.6 * s), Ink.encre())


## Cœur du Marais : grappe de vesses-de-loup gonflées et craquelées de braise sur leur mycélium ; purifié,
## une couronne de chapeaux qui luisent (turquoise et violet), des spores claires au-dessus.
static func _coeur_marais(ci: CanvasItem, c: Vector2, s: float, purified: bool, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 2.2)
	var h := 120.0 * s
	var etat := "ravive" if purified else "fletri"
	var myc: Color = Art.mc("spore", etat, "cendre")
	if purified:
		ci.draw_circle(c + Vector2(0, -h * 0.3), h * 1.15, Color(Art.mc("spore", "ravive", "lueur"), 0.07))
		O.poly(ci, O.blob(c, h * 0.9, h * 0.34, 4.0, 0.12, 40), Color(Art.mc("spore", "ravive", "sol_clair"), 0.8))
	else:
		O.poly(ci, O.blob(c, h * 0.9, h * 0.34, 4.0, 0.12, 40), Color(Art.mc("spore", "fletri", "sol_sombre"), 0.8))
	O.cast_shadow(ci, c, h * 0.8, h * 0.6, 0.4)
	_roots(ci, c, s, Color(myc, 0.5), Color(myc, 0.8), 11, 160.0, not purified, false, 9)
	if not purified:
		var pal: Dictionary = Art.mc("spore", "fletri", "chapeau")
		var balls := [[Vector2(-0.3, -0.12), 0.2], [Vector2(0.32, -0.08), 0.16], [Vector2(0.0, -0.36), 0.34]]
		ci.draw_circle(c + Vector2(0, -h * 0.4), h * 0.6, Color(Art.bc("braise"), 0.04 + 0.04 * pulse))
		for b in balls:
			var p: Vector2 = c + b[0] * h
			var rr: float = b[1] * h
			Ink.part(ci, Transform2D.IDENTITY, Ink.lumpy(p, rr, rr * 0.92, 28, 0.05, 5.0, p.x), pal, 2.2, 1.0, 0.8)
			# Peau craquelée : réseau de fentes où la braise couve.
			_crack(ci, p + Vector2(-rr * 0.3, -rr * 0.5), Vector2(0.4, 1), rr * 1.1, s, pulse, int(p.x))
		# Bouche au sommet, qui fume.
		var top: Vector2 = c + Vector2(0, -h * 0.68)
		O.poly(ci, Ink.oval(top, h * 0.07, h * 0.03, 12), Art.bc("ronge"))
		for k in 3:
			ci.draw_circle(top + Vector2(sin(t + k) * 4.0, -h * 0.1 * (k + 1)), h * (0.04 + 0.02 * k), Color(Art.mc("spore", "fletri", "air"), 0.35 - 0.08 * k))
	else:
		var caps := [[Vector2(0.0, -0.05), 1.0, 0.4, "fleur_2"], [Vector2(-0.4, 0.05), 0.65, 0.27, "fleur"], [Vector2(0.42, 0.08), 0.72, 0.3, "fleur"],
			[Vector2(-0.2, 0.2), 0.42, 0.18, "fleur"], [Vector2(0.22, 0.24), 0.36, 0.16, "fleur_2"], [Vector2(-0.55, 0.22), 0.3, 0.13, "fleur_2"]]
		caps.sort_custom(func(x, y): return x[0].y < y[0].y)
		for cp in caps:
			var base: Vector2 = c + cp[0] * h
			var hh: float = cp[1] * h
			var cw: float = cp[2] * h
			var col: Color = Art.mc("spore", "ravive", cp[3])
			var pied: Dictionary = Art.mc("spore", "ravive", "pied")
			var top := base + Vector2(0, -hh)
			ci.draw_circle(top, cw * 1.6, Color(col, 0.10))
			Ink.part(ci, Transform2D.IDENTITY, PackedVector2Array([base + Vector2(-cw * 0.2, 0), top + Vector2(-cw * 0.13, 0), top + Vector2(cw * 0.13, 0), base + Vector2(cw * 0.22, 0)]), pied, 1.4, 1.0, 0.5)
			var dome := PackedVector2Array()
			for i in 15:
				var a := PI + PI * i / 14.0
				dome.append(top + Vector2(cos(a) * cw, sin(a) * cw * 0.7))
			for i in range(14, -1, -1):
				var a := PI * i / 14.0
				dome.append(top + Vector2(cos(a) * cw, sin(a) * cw * 0.18))
			Ink.part(ci, Transform2D.IDENTITY, dome, {"clair": col, "ombre": col.darkened(0.35), "reflet": Color.WHITE}, 1.6, 1.0, 1.0)
			for i in 4:
				var a := PI * (1.2 + 0.6 * i / 3.0)
				ci.draw_circle(top + Vector2(cos(a) * cw * 0.55, sin(a) * cw * 0.35), cw * 0.08, Color(1, 1, 1, 0.75))
		for i in 7:
			var p := c + Vector2(sin(i * 2.3 + t) * h * 0.4, -h * (0.9 + 0.12 * i) + cos(i + t) * 6.0)
			ci.draw_circle(p, 5.0, Color(Art.mc("spore", "ravive", "lueur"), 0.15))
			ci.draw_circle(p, 1.6, Art.mc("spore", "ravive", "fleur_coeur"))


# --- Sanctuaire ---

const STONES := 7
const SANCT_RX := 66.0
const SANCT_RY := 30.0


## Pierres levées du sanctuaire, arrière (back = vrai : celles derrière le centre) ou avant.
static func sanctuary_stones(ci: CanvasItem, reg: String, c: Vector2, etat: String, lit: bool, back: bool) -> void:
	var st: Dictionary = Art.mc(reg, "ravive" if etat == "ravive" else "fletri", "pierre")
	if etat == "apaise":
		st = {"clair": st["clair"].lightened(0.08), "ombre": st["ombre"].lightened(0.08), "reflet": st["reflet"]}
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var list := []
	for i in STONES:
		var a := -PI * 0.5 + TAU * i / STONES + 0.2
		var p := c + Vector2(cos(a) * SANCT_RX, sin(a) * SANCT_RY)
		var hh := r.randf_range(42.0, 58.0) * (0.72 if i == 3 else 1.0)
		list.append([p, hh, sin(a) < 0.0, i])
	list.sort_custom(func(x, y): return x[0].y < y[0].y)
	for s in list:
		if s[2] != back:
			continue
		var p: Vector2 = s[0]
		var hh: float = s[1]
		var w := hh * 0.34
		O.cast_shadow(ci, p, w * 1.6, hh, 0.34)
		var lean := (p.x - c.x) / SANCT_RX * 0.08
		var pts := PackedVector2Array([p + Vector2(-w * 0.55, 1), p + Vector2(-w * 0.6 + lean * hh, -hh * 0.6), p + Vector2(-w * 0.35 + lean * hh, -hh),
			p + Vector2(w * 0.2 + lean * hh, -hh - 3), p + Vector2(w * 0.55 + lean * hh, -hh * 0.75), p + Vector2(w * 0.6, 1)])
		O.part(ci, pts, st, 1.6, 1.0, 0.5)
		# Rune gravée : vert sève quand le sanctuaire est ravivé, creux sombre sinon.
		var rc := p + Vector2(lean * hh * 0.5, -hh * 0.55)
		var col: Color = Art.mc("commun", "", "seve") if lit else Color(st["ombre"].darkened(0.4), 0.9)
		if lit:
			ci.draw_circle(rc, 8.0, Color(col, 0.16))
		# Graine gravée : une amande, une pousse qui en sort.
		ci.draw_polyline(Ink.oval(rc + Vector2(0, 2), 2.6, 4.0, 12) + PackedVector2Array([rc + Vector2(0, -2)]), col, 1.2, true)
		ci.draw_polyline(O.curve(rc + Vector2(0, -2), rc + Vector2(1, -6), rc + Vector2(3.5, -8), 4), col, 1.2, true)
		if etat == "ravive":
			O.tuft(ci, p + Vector2(w * 0.4, 1), 12.0, Art.mc(reg, "ravive", "touffe"), Art.mc(reg, "ravive", "touffe_2"), s[3] * 13)


## Centre du sanctuaire : dalle ronde au sol, pierre creuse, flamme de sève (éteinte : une braise
## froide et un filet de fumée).
static func sanctuary_center(ci: CanvasItem, reg: String, c: Vector2, etat: String, lit: bool, t: float) -> void:
	var st: Dictionary = Art.mc(reg, "ravive" if etat == "ravive" else "fletri", "pierre")
	var seve: Color = Art.mc("commun", "", "seve")
	O.poly(ci, Ink.oval(c, SANCT_RX * 0.78, SANCT_RY * 0.78, 40), Color(st["ombre"], 0.55))
	O.poly(ci, Ink.oval(c + Vector2(-2, -1), SANCT_RX * 0.7, SANCT_RY * 0.68, 40), Color(st["clair"], 0.35))
	if lit:
		O.poly(ci, Ink.oval(c, SANCT_RX * 0.95, SANCT_RY * 0.95, 40), Color(seve, 0.08))
	# Pierre creuse (vasque).
	var b := c + Vector2(0, 4)
	O.cast_shadow(ci, b, 26.0, 16.0, 0.35)
	O.part(ci, PackedVector2Array([b + Vector2(-13, 0), b + Vector2(-16, -12), b + Vector2(16, -12), b + Vector2(13, 0)]), st, 1.5, 1.0, 0.4)
	O.part(ci, Ink.oval(b + Vector2(0, -12), 16.0, 5.0, 20), st, 1.3, 1.0, 0.3)
	O.poly(ci, Ink.oval(b + Vector2(0, -12), 12.0, 3.4, 20), Color(0.05, 0.04, 0.05))
	var f := b + Vector2(0, -13)
	if lit:
		var fl := 1.0 + 0.08 * sin(t * 9.0)
		ci.draw_circle(f + Vector2(0, -12), 34.0, Color(seve, 0.07))
		ci.draw_circle(f + Vector2(0, -10), 18.0, Color(seve, 0.12))
		var flame := PackedVector2Array([f + Vector2(-8, 0), f + Vector2(-6, -12 * fl), f + Vector2(0, -28 * fl), f + Vector2(6, -12 * fl), f + Vector2(8, 0)])
		O.poly(ci, flame, Color(seve, 0.9))
		O.poly(ci, Transform2D(0.0, Vector2(0.5, 0.6), 0.0, Vector2(f.x * 0.5, f.y * 0.4 + 1.0)) * flame, Art.mc("commun", "", "seve_clair"))
	else:
		ci.draw_circle(f, 2.2, Color(seve, 0.4))
		for k in 3:
			ci.draw_circle(f + Vector2(sin(t * 0.8 + k) * 3.0, -8.0 - 9.0 * k), 3.0 + k, Color(0.6, 0.6, 0.62, 0.12))


# --- Autel ---


## Autel : une table de pierre (deux pierres dressées, une dalle posée dessus), son signe gravé luit
## (couleur « interactif ») et la greffe flotte au-dessus.
static func altar(ci: CanvasItem, reg: String, c: Vector2, etat: String, t: float) -> void:
	var st: Dictionary = Art.mc(reg, "ravive" if etat == "ravive" else "fletri", "pierre")
	var glow: Color = Art.c("interactif")
	O.cast_shadow(ci, c, 56.0, 30.0, 0.36)
	for sx in [-1.0, 1.0]:
		var b := c + Vector2(sx * 16.0, 0)
		O.part(ci, PackedVector2Array([b + Vector2(-7, 1), b + Vector2(-6, -20), b + Vector2(5, -21), b + Vector2(7, 1)]), st, 1.4, 1.0, 0.3)
	O.poly(ci, Ink.oval(c + Vector2(0, -2), 9.0, 3.0, 12), Color(0, 0, 0, 0.5))
	var slab := PackedVector2Array([c + Vector2(-30, -18), c + Vector2(-27, -27), c + Vector2(-8, -31), c + Vector2(26, -28), c + Vector2(31, -20), c + Vector2(24, -15), c + Vector2(-22, -14)])
	O.part(ci, slab, st, 1.6, 1.0, 0.5)
	var g := c + Vector2(0, -23)
	ci.draw_circle(g, 9.0, Color(glow, 0.16))
	ci.draw_arc(g, 4.0, 0.0, TAU, 14, glow, 1.3, true)
	ci.draw_line(g + Vector2(-7, 0), g + Vector2(7, 0), glow, 1.1, true)
	var y := -50.0 + sin(t * 2.0) * 2.0
	ci.draw_circle(c + Vector2(0, y), 13.0, Color(glow, 0.12))
	Ink.part(ci, Transform2D.IDENTITY, Ink.oval(c + Vector2(0, y), 5.0, 6.5, 14), {"clair": glow.lightened(0.3), "ombre": glow.darkened(0.2), "reflet": Color.WHITE}, 1.2, 1.0, 1.0)
	if etat == "fletri" and reg == "ronce":
		var ron: Dictionary = Art.mc("ronce", "fletri", "ronce")
		O.brush(ci, O.curve(c + Vector2(-34, 0), c + Vector2(-14, -34), c + Vector2(34, -12)), 2.4, ron["ombre"], 1.0, 0.0)
	elif etat == "ravive":
		O.tuft(ci, c + Vector2(26, 2), 12.0, Art.mc(reg, "ravive", "touffe"), Art.mc(reg, "ravive", "touffe_2"), 5)
