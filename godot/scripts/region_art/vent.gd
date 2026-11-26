## Dessins de la région de Vent (les hauts plateaux) : le Cœur de cendre des plateaux et le cercle de
## pierres levées de l'arène du Harfang. Voir region_art.gd (le reste est celui du roncier).
##   - Cœur : celui de world_art/lieux.gd (refonte du monde, vague 1 C), commun en attendant le sien ;
##   - mur de l'arène : un muret de pierres sèches ponctué de pierres levées ; brèche du côté du Cœur ;
##     des runes de braise s'allument pendant le combat ; vaincue, la mousse et l'herbe le gagnent.
extends "res://scripts/region_art.gd"


## Pierre levée (polygone cassé) : pied en « p », hauteur hgt, demi-largeur wid, penchée de lean.
static func stone(p: Vector2, wid: float, hgt: float, lean := 0.0) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(-wid, 0), p + Vector2(-wid * 1.05 + lean * 0.5, -hgt * 0.55),
		p + Vector2(-wid * 0.6 + lean, -hgt), p + Vector2(wid * 0.35 + lean, -hgt * 1.04), p + Vector2(wid + lean * 0.6, -hgt * 0.7),
		p + Vector2(wid, 0)])


## Sol de l'arène : la roche nue, gris bleu, tant que le Harfang vit ; une herbe rase ensuite.
static func draw_arena_floor(c: CanvasItem, a) -> void:
	if a.state == "vaincue":
		c.draw_circle(a.center, a.max_radius * 0.5, Color(Art.c("decor_vivant").lerp(Art.ec("vent", "clair"), 0.2), 0.09 + 0.03 * sin(a.t * 2.0)))
	else:
		c.draw_circle(a.center, a.radius, Color(Art.ec("vent", "sombre").darkened(0.55), 0.3 if a.state == "combat" else 0.2))


## Cercle de pierres : un muret de pierres sèches, et une pierre levée tous les six points du mur.
static func draw_arena_wall(c: CanvasItem, a) -> void:
	var wall: Array = a._wall
	var n := wall.size()
	var center: Vector2 = a.center
	var fight: bool = a.state == "combat"
	var alive: bool = a.state == "vaincue"
	var rock := Art.c("brume").lerp(Art.ec("vent", "sombre"), 0.35).darkened(0.2)
	var dark := rock.darkened(0.35)
	if fight:
		rock = rock.darkened(0.15)
		dark = Art.ec("cendre", "sombre").darkened(0.3)
	# Le muret : deux rangs de pierres, interrompus par la brèche.
	var pts := PackedVector2Array()
	var pts2 := PackedVector2Array()
	for i in n + 1:
		var w: Array = wall[i % n]
		var ang := TAU * i / n
		if in_gap(a, ang):
			_low_wall(c, pts, pts2, rock, dark)
			pts = PackedVector2Array()
			pts2 = PackedVector2Array()
			continue
		var dir := Vector2.from_angle(ang)
		var r: float = a.radius * (1.0 + w[0])
		pts.append(center + dir * r)
		pts2.append(center + dir * (r + 12.0 + 4.0 * w[2]))
	_low_wall(c, pts, pts2, rock, dark)
	# Joints et pierres levées.
	var moss := Art.c("decor_vivant").lightened(0.1)
	for i in n:
		var w: Array = wall[i]
		var ang := TAU * i / n
		if in_gap(a, ang, 0.47):
			continue
		var dir := Vector2.from_angle(ang)
		var p: Vector2 = center + dir * a.radius * (1.0 + w[0])
		if i % 6 != 0:
			c.draw_line(p - dir * 5.0, p + dir * 15.0, dark, 2.0)
			if alive and i % 2 == 0:
				c.draw_line(p + dir * 4.0, p + dir * 4.0 + Vector2(4.0, -9.0 * w[1]), moss, 2.0, true)
			continue
		var hgt: float = 34.0 * w[1]
		var pts3 := stone(p + dir * 6.0, 9.0, hgt, 4.0 * w[2])
		Art.volume(c, pts3, rock.lightened(0.08), 0.5)
		Art.outline(c, pts3, Color(Art.c("contour"), 0.6), Art.TRAIT_FIN)
		var rune := p + dir * 6.0 + Vector2(0, -hgt * 0.55)
		if fight:
			# Runes de braise : l'arène est hostile.
			c.draw_line(rune + Vector2(-3, -4), rune + Vector2(3, 4), Color(Art.ec("cendre", "clair"), 0.6 + 0.3 * sin(a.t * 5.0 + i)), 2.0, true)
			c.draw_line(rune + Vector2(3, -4), rune + Vector2(-3, 4), Color(Art.ec("cendre", "clair"), 0.6 + 0.3 * sin(a.t * 5.0 + i)), 2.0, true)
		elif alive:
			c.draw_colored_polygon(Art.ellipse(rune + Vector2(-1, -hgt * 0.3), 6.0, 3.0, 10), moss)
			c.draw_line(rune + Vector2(6, -hgt * 0.4), rune + Vector2(18, -hgt * 0.35 + 3.0 * sin(a.t * 3.0 + i)), Art.ec("vent", "clair"), 2.0, true)


static func _low_wall(c: CanvasItem, pts: PackedVector2Array, pts2: PackedVector2Array, rock: Color, dark: Color) -> void:
	if pts.size() >= 2:
		c.draw_polyline(pts2, dark, 11.0)
		c.draw_polyline(pts, rock, 13.0)
