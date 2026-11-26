## Dessins de la région de Racine (la forêt pétrifiée) : le Cœur des cernes et la palissade de troncs
## pétrifiés de la clairière de l'Ancien. Voir region_art.gd (le reste est celui du roncier).
##   - Cœur (refonte du monde, vague 2 P6) : un nœud de racines pétrifiées serré autour d'un cœur d'ambre
##     fendu de braise ; purifié, le nœud s'ouvre, redevient bois moussu, et un jeune chêne aux feuilles
##     d'or pousse de l'ambre devenu clair ;
##   - sol de l'arène : une dalle de roche sombre tant que l'Ancien vit, une clairière moussue ensuite ;
##   - mur de l'arène : une palissade de troncs pétrifiés cassés net, reliés par des arches de
##     racines ; brèche du côté du Cœur ; pendant le combat, la braise couve dans les fentes ;
##     vaincue, les troncs reverdissent.
extends "res://scripts/region_art.gd"

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")


## Pierre du Cœur et du mur : grise et chaude ; reprend la couleur du bois avec k (0 → 1).
static func stone(k := 0.0) -> Color:
	var rock := Art.c("brume").lerp(Art.c("decor"), 0.4).lerp(Art.ec("racine", "sombre"), 0.22).darkened(0.18)
	var bark := Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.2).lightened(0.08)
	return rock.lerp(bark, k)


## Un tronc pétrifié cassé (pied p, hauteur h, largeur w), en volume ; renvoie le haut.
static func stone_trunk(c: CanvasItem, p: Vector2, h: float, w: float, col: Color, notch := 0.0) -> Vector2:
	var top := p + Vector2(0, -h)
	var pts := PackedVector2Array([p + Vector2(-w, 0), p + Vector2(-w * 1.2, w * 0.3), p + Vector2(w * 1.2, w * 0.3), p + Vector2(w, 0), top + Vector2(w * 0.8, 0), top + Vector2(w * 0.3, -w * 0.5 - notch), top + Vector2(-w * 0.2, -w * 0.15), top + Vector2(-w * 0.8, -w * 0.6)])
	Art.volume(c, pts, col, 0.5)
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, Color(Art.c("contour"), 0.6), Art.TRAIT_FIN + 0.5)
	return top


## Sol de l'arène : une dalle de roche sombre tant que l'Ancien vit, une clairière moussue ensuite.
static func draw_arena_floor(c: CanvasItem, a) -> void:
	if a.state == "vaincue":
		c.draw_circle(a.center, a.max_radius * 0.55, Color(Art.c("decor_vivant").lerp(Art.ec("racine", "clair"), 0.3), 0.12 + 0.03 * sin(a.t * 2.0)))
	else:
		c.draw_circle(a.center, a.radius, Color(stone().darkened(0.4), 0.34 if a.state == "combat" else 0.24))


## Palissade : des troncs pétrifiés cassés net, de hauteurs inégales, reliés par des arches de
## racines (un point du mur sur deux).
static func draw_arena_wall(c: CanvasItem, a) -> void:
	var wall: Array = a._wall
	var n := wall.size()
	var center: Vector2 = a.center
	var fight: bool = a.state == "combat"
	var alive: bool = a.state == "vaincue"
	var col := stone(0.6 if alive else 0.0)
	if fight:
		col = col.darkened(0.15)
	var root := col.darkened(0.12)
	for i in n:
		var w: Array = wall[i]
		var ang := TAU * i / n
		if in_gap(a, ang, 0.47):
			continue
		var dir := Vector2.from_angle(ang)
		var p: Vector2 = center + dir * a.radius * (1.0 + w[0])
		if i % 2 == 1:
			# Arche de racine qui sort de terre et y replonge.
			var q := p + dir.orthogonal() * 22.0
			var top := p.lerp(q, 0.5) + Vector2(0, -14.0 - 8.0 * w[1])
			c.draw_polyline(PackedVector2Array([p, top, q]), root, 6.0, true)
			c.draw_polyline(PackedVector2Array([p + Vector2(0, -2.5), top + Vector2(0, -2.5)]), root.lightened(0.15), 2.0, true)
			if fight:
				c.draw_circle(top, 2.5, Color(Art.ec("cendre", "clair"), 0.55 + 0.3 * sin(a.t * 5.0 + i)))
			continue
		var hgt: float = 26.0 + 16.0 * w[1]
		var tip := stone_trunk(c, p, hgt, 6.5, col.darkened(0.05 * (i % 3)), 3.0 * w[1])
		if fight:
			c.draw_line(p + Vector2(-1.0, -4.0), p.lerp(tip, 0.7) + Vector2(1.5, 0), Color(Art.ec("cendre"), 0.5 + 0.35 * sin(a.t * 5.0 + i)), 1.6, true)
		elif alive and i % 4 == 0:
			Art.volume_circle(c, tip + Vector2(0, -6.0), 8.0, Art.c("decor_vivant").lerp(Art.ec("racine", "clair"), 0.2), 0.6)
		elif alive and i % 4 == 2:
			c.draw_colored_polygon(Art.ellipse(p + Vector2(0, -2.0), 9.0, 3.0, 8), Art.c("decor_vivant").darkened(0.1))


# --- Cœur des cernes (refonte du monde, vague 2 P6) ---


## Place prise par heart_body autour du pied (pixels du monde), pour la cuisson.
static func heart_box(s: float) -> Rect2:
	return Lieux.heart_box(s)


## Partie fixe (cuite) : flétri, cédé de k (les fentes de braise virent à la sève), ou purifié.
static func heart_body(c: CanvasItem, _region: String, s: float, purified: bool, k: float) -> void:
	var h := Lieux.HEART_H * s
	var e := "ravive" if purified else "fletri"
	var bois: Dictionary = Art.mc("racine", e, "bois")
	var base := Vector2.ZERO
	O.poly(c, O.blob(base, h * 0.9, h * 0.34, 11.0, 0.12, 40), Color(Art.mc("racine", e, "sol_sombre"), 0.6 if purified else 0.75))
	O.cast_shadow(c, base, h * 0.75, h * 0.8, 0.4)
	# Racines qui rampent au sol tout autour (braises le long, tant qu'il est flétri).
	Lieux._roots(c, base, s, bois["ombre"], bois["clair"], 9, 150.0, not purified, false, 23, k)
	var core := base + Vector2(0, -h * 0.36)
	var amber: Color = Art.mc("racine", e, "ambre")
	if not purified:
		# Le cœur d'ambre, sombre et trouble, fendu de braise.
		var am := {"clair": amber.darkened(0.25), "ombre": amber.darkened(0.6), "reflet": amber.lightened(0.2)}
		Ink.part(c, Transform2D.IDENTITY, Ink.lumpy(core, h * 0.24, h * 0.27, 24, 0.07, 5.0, 2.0), am, 2.0, 1.0, 0.8)
		Lieux._crack(c, core + Vector2(-h * 0.06, -h * 0.18), Vector2(0.25, 1), h * 0.34, s, 0.5, 31, k)
		Lieux._crack(c, core + Vector2(h * 0.1, -h * 0.08), Vector2(-0.1, 1), h * 0.2, s, 0.5, 37, k)
		# Le nœud : des racines pétrifiées tressées qui serrent l'ambre et se rejoignent en pointe.
		_knot(c, base, h, s, bois, 0.0)
	else:
		# Le nœud s'ouvre : les racines (bois moussu) s'écartent, l'ambre est clair et luit au pied.
		_knot(c, base, h, s, bois, 1.0)
		var am := {"clair": amber.darkened(0.08), "ombre": amber.darkened(0.4), "reflet": Color("fff4d0")}
		Ink.part(c, Transform2D.IDENTITY, Ink.lumpy(core + Vector2(0, h * 0.2), h * 0.11, h * 0.08, 18, 0.08, 4.0, 1.0), am, 1.6, 1.0, 1.0)
		_oak(c, base + Vector2(0, -h * 0.25), h, s)


## Tresse de racines autour du cœur : fermée (open 0, pierre, pointes réunies) ou ouverte (1).
static func _knot(c: CanvasItem, base: Vector2, h: float, s: float, bois: Dictionary, open: float) -> void:
	var top := base + Vector2(0, -h * (0.82 - 0.25 * open))
	for i in 4:
		var a0 := TAU * i / 4.0 + 0.4
		var pts := PackedVector2Array()
		for j in 14:
			var u := j / 13.0
			var rad := h * (0.3 - 0.2 * u * (1.0 - open) + 0.12 * sin(u * PI) + open * 0.22 * u)
			var a := a0 + u * (2.4 - 1.2 * open)
			pts.append(base.lerp(top, u) + Vector2(cos(a) * rad, sin(a) * rad * 0.35 - u * open * h * 0.1))
		# Les brins de derrière d'abord (ceux dont le milieu est plus haut à l'écran).
		O.brush(c, pts, 9.0 * s, Ink.encre(), 0.0, 0.6)
		O.brush(c, pts, 7.0 * s, bois["ombre"], 0.0, 0.6)
		O.brush(c, pts, 2.6 * s, bois["clair"], 0.0, 0.7)
		if open < 0.5:
			# Veine d'ocre dans la pierre.
			O.brush(c, pts.slice(3, 8), 1.0 * s, Color(Art.mc("racine", "fletri", "veine"), 0.8), 0.2, 0.2)
		else:
			var m: Dictionary = Art.mc("racine", "ravive", "mousse")
			O.part(c, Ink.lumpy(pts[4] + Vector2(0, -3.0 * s), 7.0 * s, 3.0 * s, 12, 0.2, 5.0, float(i)), m, 0.8, 1.0, 0.4)


## Jeune chêne qui sort de l'ambre : un tronc fin, trois branches, une couronne d'or et d'ocre, des glands.
static func _oak(c: CanvasItem, foot: Vector2, h: float, s: float) -> void:
	var bois: Dictionary = Art.mc("racine", "ravive", "bois")
	var top := foot + Vector2(h * 0.03, -h * 0.62)
	O.brush(c, O.curve(foot, foot.lerp(top, 0.5) + Vector2(-h * 0.04, 0), top, 8), 6.0 * s, bois["ombre"], 0.0, 0.5)
	O.brush(c, O.curve(foot + Vector2(-1.5, 0) * s, foot.lerp(top, 0.5) + Vector2(-h * 0.045, 0), top, 8), 2.2 * s, bois["clair"], 0.0, 0.6)
	for b in [[0.55, -2.4, 0.22], [0.7, -0.7, 0.2], [0.85, -1.6, 0.16]]:
		var from: Vector2 = foot.lerp(top, b[0])
		O.brush(c, PackedVector2Array([from, from + Vector2.from_angle(b[1]) * h * b[2]]), 3.0 * s, bois["ombre"], 0.0, 0.8)
	var r := RandomNumberGenerator.new()
	r.seed = 4711
	_crown(c, top + Vector2(0, -h * 0.02), h * 0.3, h * 0.17, 16, h * 0.085, r)
	for p in [Vector2(-0.12, 0.1), Vector2(0.16, 0.02), Vector2(0.04, 0.16)]:
		var q: Vector2 = top + p * h
		c.draw_circle(q, 3.2 * s, Art.mc("racine", "ravive", "feuille").darkened(0.15))
		c.draw_circle(q + Vector2(0, -2.6 * s), 3.0 * s, Art.mc("racine", "ravive", "fruit"))


## Partie animée (chaque image) : l'ambre qui bat et les braises qui montent (flétri) ; la lueur d'ambre
## et des feuilles d'or qui tombent doucement (purifié).
static func heart_live(c: CanvasItem, h, s: float) -> void:
	var t: float = h.t
	var hh := Lieux.HEART_H * s
	var purified: bool = h.state == "purifie"
	var siege: bool = h.state == "siege"
	var k: float = h.ratio()
	var core := Vector2(0, -hh * 0.36)
	if purified:
		var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
		var amber: Color = Art.mc("racine", "ravive", "ambre")
		c.draw_circle(core + Vector2(0, hh * 0.14), hh * 0.5, Color(amber, 0.04 + 0.03 * b))
		c.draw_circle(core + Vector2(0, hh * 0.14), hh * 0.24, Color(amber, 0.08 + 0.05 * b))
		var leaf: Color = Art.mc("racine", "ravive", "feuille")
		for i in 6:
			var u := fposmod(t * 0.16 + i / 6.0, 1.0)
			var p := Vector2(sin(i * 2.1 + t * 0.7) * hh * 0.4 + sin(u * 9.0 + i) * 6.0 * s, -hh * 1.05 + hh * 1.0 * u)
			O.poly(c, Ink.leaf(p, u * 7.0 + i, 6.0 * s, 2.6 * s, 0.2), Color(leaf, 0.85 * sin(PI * u)))
		return
	var pulse := 0.5 + 0.5 * sin(t * (6.0 if siege else 2.6))
	var ember := Lieux._braise(k)
	c.draw_circle(core, hh * 0.55, Color(ember, 0.04 + 0.05 * pulse + (0.04 if siege else 0.0)))
	c.draw_circle(core, hh * 0.3, Color(ember, 0.06 + 0.07 * pulse))
	var hot := Lieux._braise_coeur(k)
	for i in 9:
		var u := fposmod(t * (0.6 if siege else 0.32) + i / 9.0, 1.0)
		var p := Vector2(sin(i * 2.7 + t * 1.1) * hh * (0.15 + 0.35 * u), -hh * 0.8 - hh * 1.1 * u)
		var sz := 2.6 * s * (1.0 - u * 0.5)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -sz * 1.4), p + Vector2(sz, 0), p + Vector2(0, sz * 1.1), p + Vector2(-sz, 0)]), Color(hot if i % 3 == 0 else ember, 0.85 * sin(PI * u)))
	# Poussière de pierre qui tombe du nœud.
	for j in 3:
		var u := fposmod(t * 0.5 + j / 3.0, 1.0)
		c.draw_circle(Vector2((j - 1) * hh * 0.18, -hh * 0.75 + hh * 0.6 * u), 1.4 * s, Color(Art.mc("racine", "fletri", "cendre"), 0.5 * sin(PI * u)))


## Couronne d'automne (même dessin que les arbres de la forêt, decor_foret.gd › Petrified.paint_crown) :
## un nuage de masses or et ocre (quelques-unes olive), encre d'un seul tenant, deux tons et un reflet.
static func _crown(ci: CanvasItem, c: Vector2, rx: float, ry: float, n: int, mass: float, r: RandomNumberGenerator) -> void:
	var leaf: Dictionary = Art.mc("racine", "ravive", "feuillage")
	var mo: Dictionary = Art.mc("racine", "ravive", "mousse")
	var masses := []
	for i in n:
		var a := r.randf() * TAU
		var d := sqrt(r.randf())
		masses.append([c + Vector2(cos(a) * rx * d, sin(a) * ry * d), mass * r.randf_range(0.75, 1.1) * (1.0 - 0.25 * d), r.randf() < 0.18])
	masses.sort_custom(func(x, y): return x[0].y < y[0].y)
	for ms in masses:
		O.poly(ci, Ink.lumpy(ms[0] + Vector2(0.6, 0.8), ms[1] + 1.2, (ms[1] + 1.2) * 0.84, 20, 0.12, 8.0, ms[0].x), Art.mc("commun", "", "encre_decor"))
	for ms in masses:
		var pal: Dictionary = mo if ms[2] else leaf
		var p: Vector2 = ms[0]
		var rr: float = ms[1]
		O.poly(ci, Ink.lumpy(p, rr, rr * 0.82, 20, 0.12, 8.0, p.x), pal["ombre"])
		O.poly(ci, Ink.lumpy(p + Vector2(-0.18, -0.22) * rr, rr * 0.8, rr * 0.62, 18, 0.14, 7.0, p.y), pal["clair"])
		O.poly(ci, Ink.lumpy(p + Vector2(-0.38, -0.42) * rr, rr * 0.32, rr * 0.22, 12, 0.2, 5.0, p.x), Color(pal["reflet"], 0.75))


# --- Arène en décor (vague 3b A2, world_art/arenes_racine.gd) : la clairière de l'Ancien ---
# draw_arena_floor et draw_arena_wall (l'ancienne palissade) ne servent plus qu'aux comparaisons.

const ArenesRacine = preload("res://scripts/world_art/arenes_racine.gd")


static func arena_baked(region: String) -> bool:
	return true


static func arena_pieces(region: String, a) -> Array:
	return arena_ring(a, 42, ArenesRacine.MUR_VARIANTES, [["r0", 0.0, 76.0]], 73)


static func arena_piece_keys(region: String) -> Array:
	return ArenesRacine.keys()


static func arena_piece_box(region: String, key: String) -> Rect2:
	return ArenesRacine.piece_box(key)


static func arena_piece(ci: CanvasItem, region: String, key: String, etat: String) -> void:
	ArenesRacine.piece(ci, key, etat)


static func arena_piece_live(ci: CanvasItem, region: String, key: String, a, i: int) -> void:
	ArenesRacine.piece_live(ci, key, a, i)


static func arena_floor(ci: CanvasItem, a, etat: String) -> void:
	ArenesRacine.ground(ci, a, etat)


static func arena_live(ci: CanvasItem, a) -> void:
	ArenesRacine.live(ci, a)
