## Dessins propres à une région : son Cœur de flétrissure (flétri, puis purifié) et le mur de l'arène
## de son boss. Ce fichier donne ceux du roncier, et les parties communes à toutes les régions.
##
## Une région en change par le champ « art » de data/regions/<id>.json : "art": "spore" fait dessiner
## son Cœur et son arène par scripts/region_art/spore.gd, qui étend ce fichier et ne remplace que les
## fonctions qui changent (Regions.art). Tout est statique : h est le Cœur (heart.gd : t, state,
## ratio(), pulse()), a l'arène (boss_arena.gd : center, radius, max_radius, gap_open, state, t,
## heart, _wall) ; on dessine sur le CanvasItem c.
##
## - heart_body(c, region, s, purified, k) : le Cœur, partie fixe (cuite), pied en (0, 0) ;
## - heart_live(c, h, s)                   : le Cœur, partie animée (lueur, braises, halo) ;
## - draw_arena_floor(c, a)             : le sol de l'arène (sombre, puis une clairière une fois vaincue) ;
## - draw_arena_wall(c, a)              : le mur, avec une brèche du côté du Cœur quand l'arène s'ouvre.
extends RefCounted

const Lieux = preload("res://scripts/world_art/lieux.gd")


## Le Cœur (refonte du monde, vague 1 C) : une chose vivante et enracinée de la région, vue de trois
## quarts (scripts/world_art/lieux.gd : Roncier, Marais, et un Cœur commun en attendant ceux des autres
## régions). Sa partie fixe est cuite en image (heart_body, à la taille s, flétri ou purifié, k : ce
## qu'il a cédé) ; sa partie animée (lueur qui bat, braises, halo) est dessinée à chaque image
## (heart_live). Une région change de Cœur en remplaçant ces fonctions dans region_art/<art>.gd.
static func heart_body(c: CanvasItem, region: String, s: float, purified: bool, k: float) -> void:
	Lieux.heart_body(c, region, Vector2.ZERO, s, purified, k)


## Partie animée du Cœur h (heart.gd : region, t, state, ratio()), pied en (0, 0), taille s.
static func heart_live(c: CanvasItem, h, s: float) -> void:
	Lieux.heart_live(c, h.region, Vector2.ZERO, s, h.state == "purifie", h.ratio(), h.t, h.state == "siege")


## Place prise par heart_body autour du pied (pixels du monde), pour la cuisson.
static func heart_box(s: float) -> Rect2:
	return Lieux.heart_box(s)


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
