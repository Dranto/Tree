## Dessins de la région de Spore (le marais) : le Cœur de moisissure et le cercle de champignons de
## l'arène de l'Amanite-Mère. Voir region_art.gd (ce qui n'est pas remplacé ici reste celui du roncier).
##   - Cœur flétri : le bulbe des Flétris coiffé de chapeaux de moisissure, des filaments de mycélium
##     au pied, des spores sombres qui s'en échappent ;
##   - Cœur purifié : une grande amanite de sève (chapeau tacheté, lamelles, anneau), entourée de
##     petits champignons ; des spores claires en montent ;
##   - mur de l'arène : un cordon de mycélium hérissé de champignons de toutes tailles ; brèche du
##     côté du Cœur ; il luit de poison pendant le combat, puis les chapeaux s'éclaircissent.
extends "res://scripts/region_art.gd"


static func draw_heart(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var k: float = h.ratio()
	var t: float = h.t
	Art.shadow(c, Vector2(0, 2), r * 1.2)
	# Mycélium au pied : des filaments pâles et ramifiés qui s'étalent sur la vase.
	var myc := Art.ec("poison", "sombre").lerp(Art.c("brume"), 0.5).lerp(Art.c("decor_vivant"), k)
	for i in 7:
		var a := PI * (0.05 + 0.9 * i / 6.0)
		var p1 := Vector2(cos(a) * r * 0.9, sin(a) * r * 0.25)
		var p2 := Vector2(cos(a + 0.25) * r * 1.6, sin(a + 0.25) * r * 0.45)
		var p3 := Vector2(cos(a - 0.2) * r * 2.0, sin(a - 0.2) * r * 0.55)
		c.draw_polyline(PackedVector2Array([Vector2(0, -2), p1, p2, p3]), Color(myc, 0.8), Art.TRAIT_FIN, true)
		c.draw_circle(p3, 2.0, Color(myc, 0.8))
	# Chapeaux de moisissure qui coiffent le bulbe, derrière lui (en haut) et sur ses flancs.
	var cap := Art.c("ennemi").lerp(Art.ec("poison", "sombre"), 0.45).lerp(Art.c("decor_vivant").darkened(0.15), k)
	for i in 7:
		var a := -PI / 2.0 + (i - 3) * 0.42 + 0.04 * sin(t * 1.3 + i)
		var d := Vector2.from_angle(a)
		var s := r * (0.5 if i % 2 == 0 else 0.36)
		_cap(c, lift + d * r * 0.98, s, cap, d.angle() + PI / 2.0)
	heart_bulb(c, h, lift, r)
	# Spores sombres qui s'échappent du Cœur : elles virent au vert quand il cède.
	var spore := Art.ec("poison").lerp(Art.ec("seve"), k)
	for i in 6:
		var u := fposmod(t * 0.22 + i / 6.0, 1.0)
		var p := lift + Vector2(sin(i * 1.9 + t * 0.8) * r * (0.6 + 0.8 * u), -r * 0.6 - 110.0 * u)
		c.draw_circle(p, 3.5 * (1.0 - u * 0.5), Color(spore, sin(PI * u) * 0.55))


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


## Le Cœur purifié : une grande amanite de sève, chapeau clair tacheté, lamelles et anneau ; une ronde
## de petits champignons à son pied ; des spores claires qui montent.
static func draw_heart_purified(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var t: float = h.t
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	Art.shadow(c, Vector2(0, 2), r * 1.4)
	Art.glow(c, lift + Vector2(0, -r * 0.5), r * (1.9 + 0.1 * b), "seve")
	# Ronde de petits champignons au pied (ceux de derrière d'abord).
	for i in 7:
		var a := PI + TAU * i / 7.0 + 0.4
		var p := Vector2(cos(a) * r * 1.35, sin(a) * r * 0.5)
		if p.y < 0.0:
			_small_mushroom(c, p, r * (0.22 + 0.05 * (i % 3)), i)
	# Pied : un fût pâle, renflé à la base, avec son anneau.
	var stem := Art.c("interactif").darkened(0.08)
	var foot := PackedVector2Array([Vector2(-r * 0.3, 0), Vector2(-r * 0.22, -r * 0.9), Vector2(-r * 0.17, -r * 1.35),
		Vector2(r * 0.17, -r * 1.35), Vector2(r * 0.22, -r * 0.9), Vector2(r * 0.3, 0), Vector2(0, r * 0.1)])
	Art.volume(c, foot, stem, 0.7)
	Art.outline(c, foot, Color(Art.c("contour"), 0.6), Art.TRAIT_FIN)
	var ring := PackedVector2Array([Vector2(-r * 0.3, -r * 0.95), Vector2(r * 0.3, -r * 0.95), Vector2(r * 0.22, -r * 0.78), Vector2(-r * 0.22, -r * 0.78)])
	Art.volume(c, ring, stem.lightened(0.15), 0.8)
	# Chapeau : large dôme violet clair qui tire vers la sève, lamelles dessous, taches claires.
	var top := Vector2(0, -r * 1.3 - 2.0 * b)
	var col := Art.ec("poison", "clair").lerp(Art.ec("seve"), 0.3)
	var gills := PackedVector2Array([top + Vector2(-r * 1.15, 0), top + Vector2(r * 1.15, 0), top + Vector2(r * 0.6, r * 0.22), top + Vector2(-r * 0.6, r * 0.22)])
	c.draw_colored_polygon(gills, Art.ec("poison", "sombre").lerp(Art.ec("seve", "sombre"), 0.5))
	for i in 7:
		var x := (i - 3) / 3.0
		c.draw_line(top + Vector2(x * r * 1.0, 1), top + Vector2(x * r * 0.55, r * 0.2), Color(Art.ec("seve", "clair"), 0.35), 1.0)
	var dome := PackedVector2Array()
	for j in 13:
		var u := PI + PI * j / 12.0
		dome.append(top + Vector2(cos(u) * r * 1.2, sin(u) * r * 0.85))
	Art.volume(c, dome, col, 0.8)
	Art.outline(c, dome, Color(Art.c("contour"), 0.7), Art.TRAIT)
	for w in [[-0.6, -0.25, 0.13], [-0.15, -0.6, 0.11], [0.4, -0.45, 0.14], [0.75, -0.15, 0.09], [0.1, -0.2, 0.08], [-0.85, -0.05, 0.07]]:
		Art.volume_circle(c, top + Vector2(w[0] * r, w[1] * r), w[2] * r, Art.ec("seve", "clair"), 0.5)
	# Ronde de devant.
	for i in 7:
		var a := PI + TAU * i / 7.0 + 0.4
		var p := Vector2(cos(a) * r * 1.35, sin(a) * r * 0.5)
		if p.y >= 0.0:
			_small_mushroom(c, p, r * (0.22 + 0.05 * (i % 3)), i)
	# Spores claires qui montent du chapeau.
	for i in 6:
		var u := fposmod(t * 0.25 + i / 6.0, 1.0)
		var p := top + Vector2(sin(i * 2.1 + t * 0.9) * r * 0.9, -r * 0.6 - 90.0 * u)
		c.draw_circle(p, 2.2, Color(Art.ec("seve", "clair"), sin(PI * u)))


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
