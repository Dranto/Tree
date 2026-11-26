## Dessins de la région de Sève (la vallée des sources) : le Cœur des sources et la ceinture de
## roseaux et de racines de l'étang du Saule. Voir region_art.gd (le reste est celui du roncier).
##   - Cœur : celui de world_art/lieux.gd (refonte du monde, vague 1 C), commun en attendant le sien ;
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
