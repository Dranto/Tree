## Dessins de la région de Spore (le marais) : le Cœur de moisissure et le cercle de champignons de
## l'arène de l'Amanite-Mère. Voir region_art.gd (ce qui n'est pas remplacé ici reste celui du roncier).
##   - Cœur : celui du Marais de world_art/lieux.gd (refonte du monde, vague 1 C) ;
##   - arène (vague 3 A) : en décor cuit (world_art/arenes.gd), un rond de sorcière de touffes de
##     champignons et de vesses-de-loup sur leur mycélium, le chapeau géant au fond ; draw_arena_floor et
##     draw_arena_wall (l'ancien cordon de mycélium) ne servent plus qu'aux comparaisons.
extends "res://scripts/region_art.gd"


## Chapeau de champignon (demi-ellipse en volume, lamelles sombres) posé en « p », de demi-largeur s,
## penché de « tilt » radians.
static func _cap(c: CanvasItem, p: Vector2, s: float, col: Color, tilt := 0.0) -> void:
	var dome := PackedVector2Array()
	for j in 9:
		var u := PI + PI * j / 8.0
		dome.append(p + Vector2(cos(u) * s, sin(u) * s * 0.7).rotated(tilt))
	Art.volume(c, dome, col, 0.6)
	Art.outline(c, dome, Color(Art.c("ennemi_contour"), 0.5), Art.TRAIT_FIN)
	c.draw_line(p + Vector2(-s * 0.8, 0).rotated(tilt), p + Vector2(s * 0.8, 0).rotated(tilt), col.darkened(0.45), Art.TRAIT_FIN)


static func _small_mushroom(c: CanvasItem, p: Vector2, s: float, i: int) -> void:
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.18, 0), p + Vector2(-s * 0.14, -s * 1.1), p + Vector2(s * 0.14, -s * 1.1), p + Vector2(s * 0.18, 0)]), Art.c("interactif").darkened(0.25))
	var col := Art.ec("poison", "clair").darkened(0.1) if i % 2 else Art.ec("seve", "sombre").lightened(0.3)
	_cap(c, p + Vector2(0, -s * 1.1), s * 0.75, col)


## Sol de l'arène : une vase violacée tant que l'Amanite-Mère vit, une mousse claire ensuite.
static func draw_arena_floor(c: CanvasItem, a) -> void:
	if a.state == "vaincue":
		c.draw_circle(a.center, a.max_radius * 0.5, Color(Art.c("decor_vivant").lightened(0.2), 0.1 + 0.03 * sin(a.t * 2.0)))
	else:
		c.draw_circle(a.center, a.radius, Color(Art.ec("poison", "sombre").darkened(0.6), 0.32 if a.state == "combat" else 0.22))


## Cercle de champignons : un cordon de mycélium au sol, et sur lui des champignons de tailles
## tirées une fois (a._wall), penchés vers l'extérieur.
static func draw_arena_wall(c: CanvasItem, a) -> void:
	var wall: Array = a._wall
	var n := wall.size()
	var center: Vector2 = a.center
	var fight: bool = a.state == "combat"
	var alive: bool = a.state == "vaincue"
	var cord := Art.c("brume").lerp(Art.ec("poison", "sombre"), 0.4)
	var cap := Art.c("ennemi").lerp(Art.ec("poison", "sombre"), 0.5).darkened(0.1)
	var stem := Art.c("brume").darkened(0.15)
	if fight:
		cord = Art.ec("poison", "sombre")
		cap = Art.c("ennemi").lerp(Art.ec("poison"), 0.35)
	elif alive:
		cord = Art.c("decor_vivant").lightened(0.1)
		cap = Art.ec("poison", "clair").lerp(Art.c("interactif"), 0.25)
		stem = Art.c("interactif").darkened(0.2)
	# Le cordon de mycélium, interrompu par la brèche.
	var pts := PackedVector2Array()
	for i in n + 1:
		var w: Array = wall[i % n]
		var ang := TAU * i / n
		if in_gap(a, ang):
			if pts.size() >= 2:
				c.draw_polyline(pts, cord, 6.0, true)
			pts = PackedVector2Array()
			continue
		pts.append(center + Vector2.from_angle(ang) * a.radius * (1.0 + w[0]))
	if pts.size() >= 2:
		c.draw_polyline(pts, cord, 6.0, true)
	# Les champignons : un sur deux points du mur, deux rangs (l'intérieur plus bas).
	for i in n:
		var w: Array = wall[i]
		var ang := TAU * i / n
		if in_gap(a, ang, 0.47):
			continue
		var dir := Vector2.from_angle(ang)
		var row := i % 2
		var base: Vector2 = center + dir * a.radius * (1.0 + w[0]) + dir * (10.0 if row == 0 else -4.0)
		var s: float = (11.0 if row == 0 else 7.0) * w[1]
		var lean := dir * s * 0.35
		var top: Vector2 = base + Vector2(0, -s * 1.3) + lean
		c.draw_line(base, top, stem, maxf(2.0, s * 0.35), true)
		_cap(c, top, s, cap.darkened(0.08 * ((i >> 1) % 3)), lean.x * 0.03)
		if fight and i % 3 == 0:
			# Lamelles qui luisent de poison : la ronde est hostile.
			c.draw_circle(top + Vector2(0, s * 0.15), s * 0.35, Color(Art.ec("poison", "clair"), 0.35 + 0.25 * sin(a.t * 4.0 + i)))
		elif alive and i % 4 == 0:
			c.draw_circle(top + Vector2(s * 0.2, -s * 0.4), 2.0, Art.ec("seve", "clair"))


# --- Arène en décor (vague 3 A, world_art/arenes.gd) : un rond de sorcière ---


static func arena_baked(region: String) -> bool:
	return true


static func arena_pieces(region: String, a) -> Array:
	return arena_ring(a, 44, Arenes.MUR_VARIANTES, [["r0", 0.0, 70.0]], 59)


static func arena_piece_keys(region: String) -> Array:
	return Arenes.keys("spore")


static func arena_piece_box(region: String, key: String) -> Rect2:
	return Arenes.piece_box("spore", key)


static func arena_piece(ci: CanvasItem, region: String, key: String, etat: String) -> void:
	Arenes.piece(ci, "spore", key, etat)


static func arena_piece_live(ci: CanvasItem, region: String, key: String, a, i: int) -> void:
	Arenes.piece_live(ci, "spore", key, a, i)


static func arena_floor(ci: CanvasItem, a, etat: String) -> void:
	Arenes.ground(ci, a, "spore", etat)


static func arena_live(ci: CanvasItem, a) -> void:
	Arenes.live(ci, a, "spore")
