## Sol des « Paysages d'herbier » en trois couches, au lieu du brouillard de bruit actuel :
##   1. lavis    : deux ou trois tons de la région en grandes plaques nettes (zones claires usées, zones
##                 sombres sous les lisières, flaques du Marais), sans bruit fin, contraste bas ;
##   2. matière  : ce qui fait la région, à l'encre fine et pâle (craquelures et feuilles mortes du
##                 Roncier, vase, rides et mycélium du Marais ; herbe rase couchée une fois ravivé) ;
##   3. détails  : touffes, cailloux, fleurs, petits chapeaux, toujours en grappes de 3 à 9 avec un
##                 plus grand au milieu, jamais en confettis isolés.
## Puis le bord de vie : une ligne nette où l'herbe et les fleurs de la région poussent en avançant.
##
## m : le paysage (paysage.gd) qui dit l'état en chaque point (etat_at, life_k, front_d, life_poly).
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")

## Taille des cellules de la grille du monde (px) pour chaque couche.
const CELL_LAVIS := 360.0
const CELL_MATIERE := 110.0
const CELL_GRAPPE := 190.0


static func draw(ci: CanvasItem, m, rect: Rect2) -> void:
	var reg: String = m.region
	for rp in m.regions_in_view():
		O.poly(ci, rp[1], Art.mc(rp[0], m.outside_etat_of(rp[0]), "sol"))
	_lavis(ci, m, rect, "", false)
	var lp: PackedVector2Array = m.life_poly()
	if lp.size() > 2:
		for rp in m.regions_in_view():
			for p in Geometry2D.intersect_polygons(lp, rp[1]):
				O.poly(ci, p, Art.mc(rp[0], "ravive", "sol"))
		_lavis(ci, m, rect, "ravive", true)
	_matiere(ci, m, rect)
	if lp.size() > 2:
		_front(ci, m, rect, lp)
	_grappes(ci, m, rect)


static func _cells(rect: Rect2, size: float) -> Array:
	var out := []
	var a := Vector2i(floori(rect.position.x / size) - 1, floori(rect.position.y / size) - 1)
	var b := Vector2i(ceili(rect.end.x / size) + 1, ceili(rect.end.y / size) + 1)
	for y in range(a.y, b.y):
		for x in range(a.x, b.x):
			out.append(Vector2i(x, y))
	return out


## Couche 1 : grandes plaques nettes. inside : seulement dans le bord de vie (découpées par lui).
static func _lavis(ci: CanvasItem, m, rect: Rect2, etat: String, inside: bool) -> void:
	var lp: PackedVector2Array = m.life_poly()
	var shapes := []
	for cell in _cells(rect, CELL_LAVIS):
		var r := O.rng_at(cell, 11)
		for i in r.randi_range(1, 2):
			var c := (Vector2(cell) + Vector2(r.randf(), r.randf())) * CELL_LAVIS
			var rx := r.randf_range(120.0, 260.0)
			var key := "sol_clair" if r.randf() < 0.5 else "sol_sombre"
			shapes.append([O.blob(c, rx, rx * r.randf_range(0.45, 0.7), r.randf() * 10.0, 0.16, 40, r.randf_range(-0.4, 0.4)), key])
	# La clairière : une grande plaque plus claire où l'on se bat (le centre du cadre est dégagé).
	for cl in m.clearings():
		shapes.append([O.blob(cl[0], cl[1].x, cl[1].y, 3.0, 0.1, 48), "sol_clair"])
	for s in shapes:
		if inside:
			for p in Geometry2D.intersect_polygons(s[0], lp):
				for rp in m.regions_in_view():
					var col: Color = Art.mc(rp[0], "ravive", s[1])
					col.a = 0.55 if s[1] == "sol_sombre" else 0.7
					for q in Geometry2D.intersect_polygons(p, rp[1]):
						O.poly(ci, q, col)
			continue
		for rp in m.regions_in_view():
			var col: Color = Art.mc(rp[0], m.outside_etat_of(rp[0]), s[1])
			col.a = 0.55 if s[1] == "sol_sombre" else 0.7
			for p in Geometry2D.intersect_polygons(s[0], rp[1]):
				O.poly(ci, p, col)
	_flaques(ci, m, rect, inside)


## Flaques du Marais : eau sombre, berge plus sombre, reflet du ciel en traits ; turquoise une fois ravivé.
static func _flaques(ci: CanvasItem, m, rect: Rect2, inside: bool) -> void:
	var lp: PackedVector2Array = m.life_poly()
	for cell in _cells(rect, 300.0):
		var r := O.rng_at(cell, 23)
		if r.randf() > 0.55:
			continue
		var c := (Vector2(cell) + Vector2(r.randf(), r.randf())) * 300.0
		if not m.free_at(c, 90.0):
			continue
		var etat: String = m.etat_at(c)
		var reg: String = m.region_at(c)
		if reg != "spore" or inside != (etat == "ravive"):
			continue
		var rx := r.randf_range(50.0, 120.0)
		var ry := rx * r.randf_range(0.35, 0.5)
		var sd := r.randf() * 9.0
		var bank := O.blob(c + Vector2(0, 3), rx + 7.0, ry + 5.0, sd, 0.14, 36)
		var water := O.blob(c, rx, ry, sd, 0.14, 36)
		O.poly(ci, bank, Art.mc(reg, etat, "sol_sombre").darkened(0.15))
		O.poly(ci, water, Art.mc(reg, etat, "eau"))
		# Reflet : le haut de l'eau éclairé (lumière d'en haut à gauche), deux traits fins.
		for poly in Geometry2D.intersect_polygons(water, O.blob(c + Vector2(-rx * 0.3, -ry * 0.45), rx * 0.95, ry * 0.75, sd, 0.1, 24)):
			O.poly(ci, poly, Color(Art.mc(reg, etat, "eau_reflet"), 0.28))
		for poly in Geometry2D.intersect_polygons(water, O.blob(c + Vector2(-rx * 0.45, -ry * 0.6), rx * 0.55, ry * 0.45, sd, 0.1, 24)):
			O.poly(ci, poly, Color(Art.mc(reg, etat, "eau_reflet"), 0.22))
		for k in 2:
			var y := c.y - ry * (0.1 + 0.25 * k)
			var x0 := c.x - rx * (0.5 - 0.15 * k)
			ci.draw_line(Vector2(x0, y), Vector2(x0 + rx * (0.55 - 0.2 * k), y), Color(Art.mc(reg, etat, "eau_reflet"), 0.5), 1.0, true)
		if etat == "ravive":
			# Nénuphars de mousse et petits chapeaux qui luisent sur la berge.
			for k in r.randi_range(2, 4):
				var p := c + Vector2(r.randf_range(-0.6, 0.6) * rx, r.randf_range(-0.4, 0.5) * ry)
				var pad := O.blob(p, 7.0, 3.6, float(k), 0.05, 14)
				O.poly(ci, pad, Art.mc("spore", "ravive", "touffe"))
				ci.draw_line(p, p + Vector2(5, -1), Art.mc("spore", "ravive", "eau"), 1.0)
	return


## Couche 2 : la matière de la région, à l'encre fine et pâle (contraste bas).
static func _matiere(ci: CanvasItem, m, rect: Rect2) -> void:
	for cell in _cells(rect, CELL_MATIERE):
		var r := O.rng_at(cell, 37)
		var c := (Vector2(cell) + Vector2(r.randf(), r.randf())) * CELL_MATIERE
		var etat: String = m.etat_at(c)
		var reg: String = m.region_at(c)
		var ink: Color = Art.mc(reg, etat, "matiere")
		if reg == "ronce":
			if etat == "ravive":
				_herbe_rase(ci, c, r, Art.mc(reg, etat, "sol_sombre"), Art.mc(reg, etat, "sol_clair").lightened(0.08))
			else:
				_craquelure(ci, c, r, ink, etat == "fletri")
			_feuilles(ci, m, c, r, etat)
		else:
			if etat == "ravive":
				_herbe_rase(ci, c, r, Art.mc(reg, etat, "sol_sombre"), Art.mc(reg, etat, "sol_clair").lightened(0.1))
				_mycelium(ci, c, r, Color(Art.mc(reg, etat, "lueur"), 0.35))
			else:
				_rides(ci, c, r, ink)
				_mycelium(ci, c, r, Color(Art.mc(reg, etat, "cendre"), 0.22 if etat == "fletri" else 0.16))
				if r.randf() < 0.35:
					for k in r.randi_range(2, 5):
						var p := c + Vector2(r.randf_range(-20, 20), r.randf_range(-10, 10))
						ci.draw_arc(p, r.randf_range(1.2, 2.6), 0.0, TAU, 10, Color(ink, 0.5), 0.8, true)


## Craquelures de terre sèche : un réseau de traits fins qui se divisent ; braise au fond de certaines.
static func _craquelure(ci: CanvasItem, c: Vector2, r: RandomNumberGenerator, ink: Color, ember: bool) -> void:
	if r.randf() < 0.35:
		return
	var p := c
	var a := r.randf() * TAU
	var pts := PackedVector2Array([p])
	var branches := []
	for i in r.randi_range(4, 7):
		a += r.randf_range(-0.7, 0.7)
		p += Vector2.from_angle(a) * r.randf_range(9.0, 18.0) * Vector2(1.0, 0.7)
		pts.append(p)
		if r.randf() < 0.4:
			var b := p + Vector2.from_angle(a + r.randf_range(0.8, 1.6) * (1 if r.randf() < 0.5 else -1)) * r.randf_range(7.0, 14.0)
			branches.append(PackedVector2Array([p, b]))
	ci.draw_polyline(pts, Color(ink, 0.55), 1.1, true)
	for b in branches:
		ci.draw_polyline(b, Color(ink, 0.4), 0.8, true)
	if ember and r.randf() < 0.22:
		# Braise dans la fissure : le signe des Flétris, rare et petit.
		var mid := pts.slice(1, 4)
		ci.draw_polyline(mid, Color(Art.bc("braise"), 0.85), 0.9, true)
		for q in mid:
			ci.draw_circle(q, 4.0, Color(Art.bc("braise"), 0.08))


## Feuilles mortes en congères : 3 à 9 feuilles couchées (vertes et neuves une fois ravivé).
static func _feuilles(ci: CanvasItem, m, c: Vector2, r: RandomNumberGenerator, etat: String) -> void:
	if r.randf() < 0.55:
		return
	var reg: String = m.region_at(c)
	var n := r.randi_range(3, 9)
	for i in n:
		var p := c + Vector2(r.randf_range(-22, 22), r.randf_range(-10, 10))
		var a := r.randf() * TAU
		var l := r.randf_range(4.0, 7.5)
		var leaf := O.Ink.leaf(p, a, l, l * 0.5, r.randf_range(-0.2, 0.2))
		var col: Color = Art.mc(reg, etat, "feuille" if i % 2 == 0 else "feuille_2")
		O.poly(ci, leaf, Color(col, 0.85))
		ci.draw_line(p, p + Vector2.from_angle(a) * l * 0.8, Color(col.darkened(0.35), 0.7), 0.6, true)


## Herbe rase couchée (le sol ravivé) : petits traits parallèles, penchés dans le même sens.
static func _herbe_rase(ci: CanvasItem, c: Vector2, r: RandomNumberGenerator, dark: Color, light: Color) -> void:
	for i in r.randi_range(6, 12):
		var p := c + Vector2(r.randf_range(-40, 40), r.randf_range(-22, 22))
		var l := r.randf_range(4.0, 8.0)
		var d := Vector2(0.55, -1.0).normalized().rotated(r.randf_range(-0.25, 0.25))
		ci.draw_line(p, p + d * l, Color(dark, 0.55), 1.0, true)
		ci.draw_line(p + Vector2(-1.2, 0), p + Vector2(-1.2, 0) + d * l * 0.8, Color(light, 0.35), 0.8, true)


## Rides de vase : arcs concentriques plats autour d'un creux.
static func _rides(ci: CanvasItem, c: Vector2, r: RandomNumberGenerator, ink: Color) -> void:
	if r.randf() < 0.4:
		return
	var a0 := r.randf_range(-0.6, 0.2)
	for k in r.randi_range(2, 4):
		var rad := 8.0 + k * 6.0
		var pts := PackedVector2Array()
		for i in 9:
			var a := a0 + PI * 0.9 * i / 8.0
			pts.append(c + Vector2(cos(a) * rad * 1.6, sin(a) * rad * 0.55))
		ci.draw_polyline(pts, Color(ink, 0.35 - k * 0.06), 1.0, true)


## Mycélium : fils pâles qui se ramifient (vivants et lumineux une fois ravivé).
static func _mycelium(ci: CanvasItem, c: Vector2, r: RandomNumberGenerator, col: Color) -> void:
	if r.randf() < 0.5:
		return
	var p := c
	var a := r.randf() * TAU
	var pts := PackedVector2Array([p])
	for i in r.randi_range(5, 9):
		a += r.randf_range(-0.9, 0.9)
		p += Vector2.from_angle(a) * r.randf_range(6.0, 12.0)
		pts.append(p)
		if r.randf() < 0.35:
			var b := p + Vector2.from_angle(a + r.randf_range(-1.6, 1.6)) * r.randf_range(5.0, 10.0)
			ci.draw_line(p, b, Color(col, col.a * 0.7), 0.6, true)
	ci.draw_polyline(pts, col, 0.75, true)


## Bord de vie : ligne nette (liseré sève), puis une bande où l'herbe et les fleurs de la région poussent,
## plus hautes à mesure qu'on s'éloigne du front. Quelques pousses devancent la ligne.
static func _front(ci: CanvasItem, m, rect: Rect2, lp: PackedVector2Array) -> void:
	var seve: Color = Art.mc("commun", "", "seve")
	var n := lp.size()
	var glow := rect.grow(60.0)
	# Bande sombre juste dedans (l'herbe dense fait de l'ombre), puis le liseré lumineux.
	var closed := lp.duplicate()
	closed.append(lp[0])
	ci.draw_polyline(closed, Color(Art.mc(m.region, "ravive", "sol_sombre"), 0.55), 7.0, true)
	ci.draw_polyline(closed, Color(seve, 0.22), 4.0, true)
	ci.draw_polyline(closed, Color(seve, 0.75), 1.3, true)
	var cen: Vector2 = m.life_center()
	var grow: float = m.front_grow
	var per := 0.0
	for i in n:
		var a := lp[i]
		var b := lp[(i + 1) % n]
		if not glow.has_point(a):
			continue
		var seg := b - a
		var steps := int(seg.length() / 5.0)
		for s in steps:
			var p := a + seg * (float(s) / maxi(steps, 1))
			per += 1.0
			var r := O.rng_at(Vector2i(roundi(p.x / 5.0), roundi(p.y / 5.0)), 51)
			var inward := (cen - p).normalized()
			var reg: String = m.region_at(p)
			var grass_d: Color = Art.mc(reg, "ravive", "touffe_2")
			var grass_l: Color = Art.mc(reg, "ravive", "touffe")
			# Deux rangs d'herbe : au front (jeune, petite), puis plus loin (pleine hauteur).
			for row in 3:
				var depth := r.randf_range(1.0, 8.0) + row * 11.0
				var q := p + inward * depth
				var h := (6.0 + row * 6.0) * r.randf_range(0.7, 1.25) * grow
				O.blade(ci, q, h, r.randf_range(-0.5, 0.5), 1.5, grass_d if (s + row) % 2 == 0 else grass_l)
			if r.randf() < 0.2:
				var q := p + inward * r.randf_range(8.0, 34.0)
				_fleur_region(ci, reg, q, r.randf_range(3.0, 4.8) * grow, r.randf() * TAU)
			if r.randf() < 0.07:
				# Pousse qui devance le front.
				var q := p - inward * r.randf_range(4.0, 14.0)
				O.blade(ci, q, 4.0 * grow, r.randf_range(-0.4, 0.4), 1.1, Color(seve, 0.8))


## Fleur propre à la région : églantine du Roncier, petit chapeau qui luit du Marais.
static func _fleur_region(ci: CanvasItem, reg: String, p: Vector2, r: float, rot: float) -> void:
	if reg == "ronce":
		O.flower(ci, p, r, Art.mc(reg, "ravive", "fleur"), Art.mc(reg, "ravive", "fleur_coeur"), rot)
	else:
		_petit_chapeau(ci, p, r, true)


## Petit chapeau du Marais (champignon de la taille d'une touffe). lit : luit (ravivé).
static func _petit_chapeau(ci: CanvasItem, p: Vector2, r: float, lit: bool) -> void:
	var etat := "ravive" if lit else "fletri"
	var pied: Dictionary = Art.mc("spore", etat, "pied")
	var cap: Color = Art.mc("spore", etat, "fleur") if lit else Art.mc("spore", etat, "chapeau")["clair"]
	if lit:
		ci.draw_circle(p + Vector2(0, -r * 1.2), r * 2.4, Color(cap, 0.12))
	ci.draw_line(p, p + Vector2(0, -r * 1.3), pied["ombre"], maxf(r * 0.45, 1.0), true)
	var c := p + Vector2(0, -r * 1.3)
	var dome := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		dome.append(c + Vector2(cos(a) * r, sin(a) * r * 0.8))
	O.poly(ci, dome, cap.darkened(0.25))
	O.poly(ci, O.Ink.oval(c + Vector2(-r * 0.2, -r * 0.35), r * 0.5, r * 0.25, 10), cap if not lit else cap.lightened(0.3))


## Couche 3 : détails en grappes (3 à 9, un plus grand au milieu), jamais isolés.
static func _grappes(ci: CanvasItem, m, rect: Rect2) -> void:
	for cell in _cells(rect, CELL_GRAPPE):
		var r := O.rng_at(cell, 71)
		if r.randf() < 0.42:
			continue
		var c := (Vector2(cell) + Vector2(r.randf(), r.randf())) * CELL_GRAPPE
		if not m.free_at(c, 40.0):
			continue
		var etat: String = m.etat_at(c)
		var reg: String = m.region_at(c)
		var n := r.randi_range(3, 9)
		var kind := r.randi_range(0, 2)
		if etat == "ravive" and r.randf() < 0.45:
			kind = 2
		var items := []
		for i in n:
			var big := 1.0 if i == 0 else r.randf_range(0.45, 0.8)
			var off := Vector2.ZERO if i == 0 else Vector2.from_angle(r.randf() * TAU) * r.randf_range(7.0, 22.0) * Vector2(1.0, 0.6)
			items.append([c + off, big, r.randi()])
		items.sort_custom(func(x, y): return x[0].y < y[0].y)
		for it in items:
			_detail(ci, reg, etat, kind, it[0], it[1], it[2])


static func _detail(ci: CanvasItem, reg: String, etat: String, kind: int, p: Vector2, big: float, seed: int) -> void:
	var stone: Dictionary = Art.mc(reg, "ravive" if etat == "ravive" else "fletri", "pierre")
	match kind:
		0:
			O.tuft(ci, p, 14.0 * big, Art.mc(reg, etat, "touffe"), Art.mc(reg, etat, "touffe_2"), seed, etat != "ravive")
		1:
			O.pebble(ci, p, 3.0 + 4.5 * big, stone, float(seed % 97))
		_:
			if etat == "ravive":
				if reg == "ronce":
					O.tuft(ci, p, 10.0 * big, Art.mc(reg, etat, "touffe"), Art.mc(reg, etat, "touffe_2"), seed)
					O.flower(ci, p + Vector2(0, -8.0 * big), 2.5 + 2.5 * big, Art.mc(reg, etat, "fleur" if seed % 3 else "fleur_2"), Art.mc(reg, etat, "fleur_coeur"), float(seed % 7))
				else:
					_petit_chapeau(ci, p, 2.5 + 3.0 * big, true)
			elif reg == "spore":
				_petit_chapeau(ci, p, 2.0 + 3.0 * big, false)
			else:
				# Petit tas de cendre (flétri) ou de feuilles (apaisé).
				var col: Color = Art.mc(reg, etat, "cendre" if etat == "fletri" else "feuille")
				O.poly(ci, O.blob(p, 4.0 + 5.0 * big, 2.0 + 2.2 * big, float(seed % 13), 0.2, 14), Color(col, 0.55))
				if etat == "fletri" and seed % 4 == 0:
					ci.draw_circle(p + Vector2(0, -0.5), 1.4 * big, Art.bc("braise"))
