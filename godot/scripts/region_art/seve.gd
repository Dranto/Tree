## Dessins de la région de Sève (la vallée des sources) : le Cœur des sources et la ceinture de
## roseaux et de racines de l'étang du Saule. Voir region_art.gd (le reste est celui du roncier).
##   - Cœur flétri : le bulbe des Flétris planté dans une source croupie ; des racines noires y
##     plongent et en boivent l'eau (des gouttes remontent vers le bulbe) ; des roseaux morts autour ;
##   - Cœur purifié : une source claire cerclée de pierres moussues, d'où monte un jeune saule aux
##     branches qui retombent ; l'eau bouillonne et des gouttes de rosée brillent ;
##   - sol de l'arène : l'eau trouble de l'étang tant que le Saule vit, une eau claire ensuite ;
##   - mur de l'arène : une ceinture de roseaux serrés et de racines qui sortent de terre ; brèche du
##     côté du Cœur ; pendant le combat, les roseaux noircissent et leurs pointes rougeoient ;
##     vaincue, des massettes et des fleurs d'eau.
extends "res://scripts/region_art.gd"


## Eau croupie (mort) ou claire (vivant), selon k (0 → 1).
static func water(k: float) -> Color:
	var dead := Art.c("sol_mort").darkened(0.35).lerp(Art.ec("racine", "sombre"), 0.35)
	var clear := Art.ec("seve", "sombre").lerp(Art.ec("vent", "sombre"), 0.35)
	return dead.lerp(clear, k)


## Roseau (pied p, hauteur h, penché de lean) : une tige effilée.
static func reed(c: CanvasItem, p: Vector2, h: float, lean: float, col: Color, w := 2.4) -> Vector2:
	var tip := p + Vector2(lean, -h)
	var mid := p.lerp(tip, 0.5) + Vector2(lean * 0.15, 0)
	var n := (tip - p).orthogonal().normalized()
	c.draw_colored_polygon(PackedVector2Array([p - n * w * 0.5, mid - n * w * 0.35, tip, mid + n * w * 0.35, p + n * w * 0.5]), col)
	return tip


static func draw_heart(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var k: float = h.ratio()
	var t: float = h.t
	Art.shadow(c, Vector2(0, 2), r * 1.3)
	# La source croupie : une mare sombre au pied, un reflet huileux qui glisse.
	var pool := Art.ellipse(Vector2(0, r * 0.05), r * 1.6, r * 0.55, 24)
	c.draw_colored_polygon(Art.ellipse(Vector2(0, r * 0.1), r * 1.75, r * 0.62, 24), Art.c("sol_mort").darkened(0.45))
	c.draw_colored_polygon(pool, water(k * 0.6))
	var sheen := Color(Art.ec("poison", "clair").lerp(Art.ec("seve", "clair"), k), 0.12 + 0.08 * sin(t * 1.3))
	c.draw_colored_polygon(Art.ellipse(Vector2(-r * 0.5 + r * 0.2 * sin(t * 0.4), -r * 0.08), r * 0.45, r * 0.06, 12), sheen)
	# Roseaux morts autour de la mare.
	var dead_reed := Art.c("decor").lerp(Art.c("brume"), 0.4).lerp(Art.c("decor_vivant"), k * 0.6)
	for i in 9:
		var a := PI * (0.05 + 0.9 * i / 8.0) + PI
		var p := Vector2(cos(a) * r * 1.55, sin(a) * r * 0.5 + r * 0.05)
		reed(c, p, r * (0.7 + 0.25 * (i % 3)), (i - 4) * 1.5 + 2.0 * sin(t + i), dead_reed)
	# Racines noires qui plongent du bulbe dans l'eau, et l'eau bue qui remonte en gouttes.
	var root := Art.c("ennemi").darkened(0.5).lerp(Art.ec("racine", "sombre"), k)
	var drops := Art.ec("seve").lerp(Art.ec("cendre"), 1.0 - k)
	for i in 5:
		var a := PI * (0.15 + 0.7 * i / 4.0)
		var end := Vector2(cos(a) * r * 1.2, sin(a) * r * 0.35 + r * 0.1)
		var start := lift + Vector2(cos(a) * r * 0.5, r * 0.6)
		var mid := start.lerp(end, 0.5) + Vector2(cos(a) * r * 0.2, r * 0.15)
		c.draw_polyline(PackedVector2Array([start, mid, end]), root, 4.0, true)
		var u := fposmod(t * 0.7 + i * 0.23, 1.0)
		var q := end.lerp(mid, minf(u * 2.0, 1.0)) if u < 0.5 else mid.lerp(start, (u - 0.5) * 2.0)
		c.draw_circle(q, 2.4, Color(drops, 0.85 * sin(PI * u)))
	heart_bulb(c, h, lift, r)
	# Branches de saule mortes qui retombent de la couronne du bulbe.
	var twig := Art.c("ennemi").darkened(0.3).lerp(Art.c("decor_vivant").darkened(0.2), k)
	for i in 6:
		var a := -PI / 2.0 + (i - 2.5) * 0.4
		var base := lift + Vector2.from_angle(a) * r * 0.9
		var pts := PackedVector2Array()
		for j in 6:
			var u := j / 5.0
			pts.append(base + Vector2(cos(a) * r * 0.5 * u + 2.0 * sin(t * 1.5 + i + u * 2.0), -r * 0.3 * sin(PI * u * 0.5) + r * 1.2 * u * u))
		c.draw_polyline(pts, twig, 2.0, true)


## Le Cœur purifié : une source claire dans un cercle de pierres moussues, un jeune saule au milieu.
static func draw_heart_purified(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var t: float = h.t
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	Art.shadow(c, Vector2(0, 2), r * 1.4)
	Art.glow(c, lift + Vector2(0, -r * 0.3), r * (1.8 + 0.1 * b), "seve")
	# La source : eau claire, rides qui s'élargissent depuis le pied du saule.
	c.draw_colored_polygon(Art.ellipse(Vector2(0, r * 0.08), r * 1.55, r * 0.55, 24), water(1.0))
	for i in 3:
		var u := fposmod(t * 0.35 + i / 3.0, 1.0)
		c.draw_arc(Vector2(0, r * 0.05), r * (0.2 + 1.2 * u), 0.0, TAU, 28, Color(Art.ec("seve", "clair"), 0.35 * (1.0 - u)), 1.5, true)
	# Pierres moussues autour.
	var stone := Art.c("brume").lerp(Art.ec("racine", "sombre"), 0.25)
	var moss := Art.c("decor_vivant").lightened(0.1)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var p := Vector2(cos(a) * r * 1.6, sin(a) * r * 0.58 + r * 0.08)
		var s := r * (0.22 + 0.06 * (i % 2))
		var pts := Art.ellipse(p, s, s * 0.6, 8)
		Art.volume(c, pts, stone, 0.5)
		c.draw_colored_polygon(Art.ellipse(p + Vector2(0, -s * 0.35), s * 0.7, s * 0.25, 8), moss)
	# Le jeune saule : un tronc souple, une couronne d'où retombent des rideaux de feuilles.
	var bark := Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.25)
	var top := Vector2(r * 0.1, -r * 1.7)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.12, 0), Vector2(-r * 0.05, -r * 0.9), top, Vector2(r * 0.1, -r * 0.9), Vector2(r * 0.14, 0)]), bark)
	var leaf := Art.c("decor_vivant").lerp(Art.ec("seve"), 0.25)
	for i in 9:
		var a := PI + PI * (i + 0.5) / 9.0
		var base := top + Vector2(cos(a) * r * 0.75, sin(a) * r * 0.3)
		var pts := PackedVector2Array()
		for j in 7:
			var u := j / 6.0
			var sway := 3.0 * sin(t * 1.4 + i * 0.7 + u * 2.0) * u
			pts.append(base + Vector2(cos(a) * r * 0.25 * u + sway, r * 1.3 * u))
		c.draw_polyline(pts, leaf.darkened(0.06 * (i % 3)), 3.0, true)
	Art.volume(c, Art.ellipse(top, r * 0.85, r * 0.38, 18), leaf, 0.6)
	# Gouttes de rosée qui brillent sur les rideaux.
	for i in 5:
		var p := top + Vector2((i - 2) * r * 0.32, r * (0.6 + 0.25 * (i % 2)))
		c.draw_circle(p, 2.0 + b, Color(Art.ec("seve", "clair"), 0.5 + 0.4 * sin(t * 2.0 + i)))


## Sol de l'arène : l'eau trouble de l'étang tant que le Saule vit, une eau claire et verte ensuite.
static func draw_arena_floor(c: CanvasItem, a) -> void:
	if a.state == "vaincue":
		c.draw_circle(a.center, a.max_radius * 0.55, Color(water(1.0).lerp(Art.c("decor_vivant"), 0.3), 0.14 + 0.03 * sin(a.t * 2.0)))
	else:
		c.draw_circle(a.center, a.radius, Color(water(0.0).darkened(0.2), 0.32 if a.state == "combat" else 0.22))


## Ceinture de roseaux : des touffes serrées sur le bord, une racine qui sort de terre tous les
## cinq points du mur.
static func draw_arena_wall(c: CanvasItem, a) -> void:
	var wall: Array = a._wall
	var n := wall.size()
	var center: Vector2 = a.center
	var fight: bool = a.state == "combat"
	var alive: bool = a.state == "vaincue"
	var stem := Art.c("decor").lerp(Art.c("brume"), 0.3).lerp(Art.ec("seve", "sombre"), 0.25)
	if fight:
		stem = Art.c("decor").darkened(0.35)
	elif alive:
		stem = Art.c("decor_vivant").darkened(0.05)
	var root := Art.c("ennemi").darkened(0.4) if not alive else Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.3)
	# Berge : un liseré de vase sous les roseaux, interrompu par la brèche.
	var bank := PackedVector2Array()
	for i in n + 1:
		var w: Array = wall[i % n]
		var ang := TAU * i / n
		if in_gap(a, ang):
			if bank.size() >= 2:
				c.draw_polyline(bank, Art.c("sol_mort").darkened(0.3), 12.0)
			bank = PackedVector2Array()
			continue
		bank.append(center + Vector2.from_angle(ang) * a.radius * (1.0 + w[0]))
	if bank.size() >= 2:
		c.draw_polyline(bank, Art.c("sol_mort").darkened(0.3), 12.0)
	for i in n:
		var w: Array = wall[i]
		var ang := TAU * i / n
		if in_gap(a, ang, 0.47):
			continue
		var dir := Vector2.from_angle(ang)
		var p: Vector2 = center + dir * a.radius * (1.0 + w[0])
		if i % 5 == 0:
			# Racine arquée qui sort de terre et y replonge.
			var q := p + dir.orthogonal() * 18.0
			var top := p.lerp(q, 0.5) + Vector2(0, -16.0 * w[1])
			c.draw_polyline(PackedVector2Array([p, top, q]), root, 5.0, true)
			if fight:
				c.draw_circle(top, 2.5, Color(Art.ec("cendre", "clair"), 0.6 + 0.3 * sin(a.t * 5.0 + i)))
			continue
		# Touffe de trois roseaux.
		for j in 3:
			var foot := p + dir.orthogonal() * (j - 1) * 5.0
			var hgt: float = (22.0 + 10.0 * w[1]) * (1.0 - 0.15 * absf(j - 1))
			var tip := reed(c, foot, hgt, (j - 1) * 3.0 + 2.0 * sin(a.t * 1.5 + i), stem.darkened(0.06 * j))
			if fight and j == 1:
				c.draw_circle(tip, 2.0, Color(Art.ec("cendre", "clair"), 0.5 + 0.4 * sin(a.t * 5.0 + i)))
			elif alive and j == 1 and i % 2 == 0:
				# Massette brune au bout du roseau du milieu.
				c.draw_colored_polygon(Art.ellipse(tip + Vector2(0, 5.0), 2.4, 5.0, 8), Art.ec("racine", "sombre").lightened(0.15))
			elif alive and j == 0 and i % 3 == 0:
				c.draw_circle(foot + Vector2(-4, -3), 2.6, Art.ec("seve", "clair"))
