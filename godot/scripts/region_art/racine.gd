## Dessins de la région de Racine (la forêt pétrifiée) : le Cœur des cernes et la palissade de troncs
## pétrifiés de la clairière de l'Ancien. Voir region_art.gd (le reste est celui du roncier).
##   - Cœur : celui de world_art/lieux.gd (refonte du monde, vague 1 C), commun en attendant le sien ;
##   - sol de l'arène : une dalle de roche sombre tant que l'Ancien vit, une clairière moussue ensuite ;
##   - mur de l'arène : une palissade de troncs pétrifiés cassés net, reliés par des arches de
##     racines ; brèche du côté du Cœur ; pendant le combat, la braise couve dans les fentes ;
##     vaincue, les troncs reverdissent.
extends "res://scripts/region_art.gd"


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
