## Dessins propres à une région : son Cœur de flétrissure (flétri, puis purifié) et le mur de l'arène
## de son boss. Ce fichier donne ceux du roncier, et les parties communes à toutes les régions.
##
## Une région en change par le champ « art » de data/regions/<id>.json : "art": "spore" fait dessiner
## son Cœur et son arène par scripts/region_art/spore.gd, qui étend ce fichier et ne remplace que les
## fonctions qui changent (Regions.art). Tout est statique : h est le Cœur (heart.gd : t, state,
## ratio(), pulse()), a l'arène (boss_arena.gd : center, radius, max_radius, gap_open, state, t,
## heart, _wall) ; on dessine sur le CanvasItem c.
##
## - draw_heart(c, h, lift, r)          : le Cœur flétri, au pied (0, 0), son milieu en « lift » ;
## - draw_heart_purified(c, h, lift, r) : le Cœur purifié, la plante de la région ;
## - draw_arena_floor(c, a)             : le sol de l'arène (sombre, puis une clairière une fois vaincue) ;
## - draw_arena_wall(c, a)              : le mur, avec une brèche du côté du Cœur quand l'arène s'ouvre.
extends RefCounted


## Le Cœur : un bulbe anguleux de Flétri (forme cassée, contour clair), couronné d'épines et fendu
## de braises ; des braises en montent et se voient de loin. Il vire au vert à mesure qu'il cède.
static func draw_heart(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var k: float = h.ratio()
	var t: float = h.t
	var siege: bool = h.state == "siege"
	Art.shadow(c, Vector2(0, 2), r * 1.2)
	heart_roots(c, r)
	# Couronne d'épines, en volume (un côté clair, un côté sombre).
	var husk := heart_husk(k)
	for i in 12:
		var a := TAU * i / 12.0 - PI / 2.0 + 0.05 * sin(t * 1.5 + i)
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var base := lift + d * r * 0.8
		var tip := base + d * r * (0.8 if i % 2 == 0 else 0.55) * (1.0 if d.y < 0.3 else 0.7)
		c.draw_colored_polygon(PackedVector2Array([base + n * r * 0.2, tip, base]), husk.lightened(0.1))
		c.draw_colored_polygon(PackedVector2Array([base, tip, base - n * r * 0.2]), husk.darkened(0.35))
	heart_bulb(c, h, lift, r)


## Racines noueuses au pied du Cœur.
static func heart_roots(c: CanvasItem, r: float) -> void:
	var root := Art.c("ennemi").darkened(0.55)
	for i in 6:
		var a := PI * (0.08 + 0.84 * i / 5.0)
		var tip := Vector2(cos(a) * r * 1.55, sin(a) * r * 0.42)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-6, -2), tip, Vector2(6, -2)]), root)


## Teinte de l'écorce du Cœur : celle des Flétris, qui verdit à mesure qu'il cède (k de 0 à 1).
static func heart_husk(k: float) -> Color:
	return Art.c("ennemi").lerp(Art.c("decor_vivant").darkened(0.2), k)


## Le bulbe commun à tous les Cœurs : polygone cassé en volume, contour clair, fissures et œil de
## braise qui virent au vert, braises qui montent (on repère le Cœur de loin).
static func heart_bulb(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var k: float = h.ratio()
	var t: float = h.t
	var siege: bool = h.state == "siege"
	var husk := heart_husk(k)
	var pts := PackedVector2Array()
	var n_pts := 9
	for i in n_pts:
		var a := TAU * i / n_pts - PI / 2.0
		var rr := r * (1.0 if i % 2 == 0 else 0.82) * (1.0 + 0.04 * sin(t * 2.0 + i))
		pts.append(lift + Vector2.from_angle(a) * rr)
	Art.volume(c, pts, husk, 0.5)
	Art.outline(c, pts, Art.c("ennemi_contour").lerp(Art.ec("seve", "clair"), k), Art.TRAIT_FORT)
	# Fissures de braise : elles virent au vert à mesure que le Cœur cède.
	var crack := Art.ec("cendre").lerp(Art.ec("seve"), k)
	crack.a = 0.7 + 0.3 * sin(t * (9.0 if siege else 3.0))
	for i in 5:
		var a := -PI / 2.0 + (i - 2) * 0.62 + PI
		var p0 := lift + Vector2.from_angle(a) * r * 0.2
		var p1 := lift + Vector2.from_angle(a + 0.3) * r * 0.55
		var p2 := lift + Vector2.from_angle(a - 0.1) * r * 0.8
		c.draw_polyline(PackedVector2Array([p0, p1, p2]), crack, Art.TRAIT, true)
	# Œil de braise au centre.
	c.draw_circle(lift, r * 0.34, Color(crack.r, crack.g, crack.b, 0.3))
	var eye := PackedVector2Array([lift + Vector2(-r * 0.24, 0), lift + Vector2(0, -r * 0.13), lift + Vector2(r * 0.24, 0), lift + Vector2(0, r * 0.13)])
	c.draw_colored_polygon(eye, Art.ec("cendre", "clair").lerp(Art.ec("seve", "clair"), k))
	c.draw_circle(lift, r * 0.07, Art.c("contour"))
	# Braises qui montent : on repère le Cœur de loin.
	var ember_col := Art.ec("cendre", "clair").lerp(Art.ec("seve", "clair"), k)
	for i in 10:
		var u := fposmod(t * (0.35 if not siege else 0.6) + i / 10.0, 1.0)
		var p := lift + Vector2(sin(i * 2.7 + t * 1.1) * r * (0.5 + 0.6 * u), -r * 0.8 - 160.0 * u)
		var sz := 3.2 * (1.0 - u * 0.6)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -sz * 1.4), p + Vector2(sz, 0), p + Vector2(0, sz * 1.1), p + Vector2(-sz, 0)]), Color(ember_col, sin(PI * u) * 0.9))


## Le Cœur purifié du roncier : une rose ouverte, feuilles dessous, pétales en deux rangs, cœur d'or.
static func draw_heart_purified(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var t: float = h.t
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	Art.shadow(c, Vector2(0, 2), r * 1.3)
	Art.glow(c, lift, r * (2.0 + 0.1 * b), "seve")
	var leaf := Art.c("decor_vivant")
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var lf := petal(lift, a, r * 1.45, r * 0.42)
		Art.volume(c, lf, leaf.darkened(0.1 * (i % 2)), 0.5)
		Art.outline(c, lf, Art.c("contour"), Art.TRAIT_FIN)
	var col := Art.ec("saignement", "clair").lerp(Art.c("interactif"), 0.35)
	for row in 2:
		var n := 6 - row
		for i in n:
			var a := TAU * i / n + row * 0.5 + t * 0.06 * (1 - 2 * row)
			var pp := petal(lift, a, r * (1.0 - row * 0.32), r * (0.5 - row * 0.1))
			Art.volume(c, pp, col.lightened(0.1 * row), 0.7)
			Art.outline(c, pp, Color(Art.c("contour"), 0.7), Art.TRAIT_FIN)
	Art.volume_circle(c, lift, r * 0.28, Art.c("or"), 0.8)
	for i in 5:
		var u := fposmod(t * 0.3 + i / 5.0, 1.0)
		var p := lift + Vector2(sin(i * 2.3 + t) * r * 0.6, -r * 0.4 - 90.0 * u)
		c.draw_circle(p, 2.0, Color(Art.ec("seve", "clair"), sin(PI * u)))


## Pétale (ou feuille) en losange, de « origin » vers « angle ».
static func petal(origin: Vector2, angle: float, length: float, width: float) -> PackedVector2Array:
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal() * width
	return PackedVector2Array([origin, origin + dir * length * 0.55 + side, origin + dir * length, origin + dir * length * 0.55 - side])


## Sol de l'arène : sombre tant que le boss vit, une clairière qui respire une fois vaincu.
static func draw_arena_floor(c: CanvasItem, a) -> void:
	if a.state == "vaincue":
		c.draw_circle(a.center, a.max_radius * 0.5, Color(0.55, 0.95, 0.5, 0.08 + 0.03 * sin(a.t * 2.0)))
	else:
		c.draw_circle(a.center, a.radius, Color(0.08, 0.02, 0.03, 0.3 if a.state == "combat" else 0.2))


## Angle (autour du centre de l'arène) du milieu de la brèche : du côté du Cœur.
static func gate_angle(a) -> float:
	return (a.heart.center - a.center).angle()


## Vrai si l'angle « ang » tombe dans la brèche (ouverte de gap_open, de 0 à 1).
static func in_gap(a, ang: float, half := 0.42) -> bool:
	return absf(wrapf(ang - gate_angle(a), -PI, PI)) < half * a.gap_open


## Mur de ronces du roncier : deux tiges sombres hérissées d'épines ; une brèche s'ouvre du côté du
## Cœur quand l'arène est ouverte ; une fois le boss vaincu, les ronces reverdissent et fleurissent.
static func draw_arena_wall(c: CanvasItem, a) -> void:
	var wall: Array = a._wall
	var n := wall.size()
	var center: Vector2 = a.center
	var fight: bool = a.state == "combat"
	var alive: bool = a.state == "vaincue"
	var stem := Color("2c2226")
	var thorn := Color("8a7f78")
	if fight:
		stem = Color("3d1f24")
		thorn = Color("e0a090")
	elif alive:
		stem = Color("2f6b2a")
		thorn = Color("468f38")
	var pts := PackedVector2Array()
	var pts2 := PackedVector2Array()
	for i in n + 1:
		var w: Array = wall[i % n]
		var ang := TAU * i / n
		if in_gap(a, ang):
			_wall_strip(c, pts, pts2, stem)
			pts = PackedVector2Array()
			pts2 = PackedVector2Array()
			continue
		var dir := Vector2.from_angle(ang)
		var r: float = a.radius * (1.0 + w[0])
		pts.append(center + dir * r)
		pts2.append(center + dir * (r + 16.0 + 8.0 * w[2]))
		var len: float = 16.0 * w[1]
		var lean := Vector2.from_angle(ang + 0.5 * w[2])
		c.draw_line(center + dir * r, center + dir * r - lean * len, thorn, 3.0)
		c.draw_line(center + dir * (r + 14.0), center + dir * (r + 14.0) + lean * len, thorn, 3.0)
		if alive and i % 3 == 0:
			var rose := center + dir * (r + 8.0)
			for j in 5:
				c.draw_circle(rose + Vector2.from_angle(TAU * j / 5.0 + i) * 5.0, 4.5, Color("e0675e").lerp(Color("f48fb1"), 0.5 + 0.5 * w[2]))
			c.draw_circle(rose, 3.0, Color("fff3c4"))
	_wall_strip(c, pts, pts2, stem)


static func _wall_strip(c: CanvasItem, pts: PackedVector2Array, pts2: PackedVector2Array, stem: Color) -> void:
	if pts.size() >= 2:
		c.draw_polyline(pts, stem, 13.0)
		c.draw_polyline(pts2, stem.darkened(0.25), 9.0)
