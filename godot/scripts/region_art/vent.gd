## Dessins de la région de Vent (les hauts plateaux) : le Cœur de cendre des plateaux et le cercle de
## pierres levées de l'arène du Harfang. Voir region_art.gd (le reste est celui du roncier).
##   - Cœur flétri : le bulbe des Flétris pris dans une couronne d'éclats de pierre qui flottent, des
##     traînées de cendre que le vent étire d'un côté ; une assise de dalles fendues au pied ;
##   - Cœur purifié : une pierre levée claire gravée d'une spirale de sève, des rubans qui flottent
##     au vent depuis son sommet, de l'herbe à son pied ;
##   - mur de l'arène : un muret de pierres sèches ponctué de pierres levées ; brèche du côté du Cœur ;
##     des runes de braise s'allument pendant le combat ; vaincue, la mousse et l'herbe le gagnent.
extends "res://scripts/region_art.gd"


## Pierre levée (polygone cassé) : pied en « p », hauteur hgt, demi-largeur wid, penchée de lean.
static func stone(p: Vector2, wid: float, hgt: float, lean := 0.0) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(-wid, 0), p + Vector2(-wid * 1.05 + lean * 0.5, -hgt * 0.55),
		p + Vector2(-wid * 0.6 + lean, -hgt), p + Vector2(wid * 0.35 + lean, -hgt * 1.04), p + Vector2(wid + lean * 0.6, -hgt * 0.7),
		p + Vector2(wid, 0)])


static func draw_heart(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var k: float = h.ratio()
	var t: float = h.t
	Art.shadow(c, Vector2(0, 2), r * 1.2)
	# Assise de dalles fendues au pied.
	var slab := Art.c("brume").lerp(Art.ec("vent", "sombre"), 0.4).darkened(0.25)
	for i in 5:
		var x := (i - 2) * r * 0.62
		var pts := PackedVector2Array([Vector2(x - r * 0.34, r * 0.1), Vector2(x - r * 0.26, -r * 0.14), Vector2(x + r * 0.3, -r * 0.1), Vector2(x + r * 0.34, r * 0.16)])
		Art.volume(c, pts, slab.darkened(0.06 * (i % 2)), 0.4)
	# Traînées de cendre que le vent étire vers la droite (derrière le bulbe).
	var ash := Art.c("brume").lerp(Art.ec("cendre", "sombre"), 0.5).lerp(Art.ec("vent", "clair"), k)
	for i in 4:
		var y := -r * (0.2 + 0.32 * i)
		var wave := 6.0 * sin(t * 2.2 + i * 1.3)
		var pts := PackedVector2Array()
		for j in 7:
			var u := j / 6.0
			pts.append(lift + Vector2(r * (0.2 + 1.7 * u), y + r * 0.6 + wave * u + 8.0 * sin(u * 5.0 + t * 3.0 + i)))
		c.draw_polyline(pts, Color(ash, 0.55 - 0.08 * i), 3.0 - 0.4 * i, true)
	heart_bulb(c, h, lift, r)
	# Couronne d'éclats de pierre qui flottent autour du bulbe (au-dessus et sur les flancs).
	var shard := Art.c("brume").lerp(Art.ec("vent", "sombre"), 0.3).lerp(Art.c("decor_vivant").darkened(0.1), k)
	for i in 7:
		var a := -PI / 2.0 + (i - 3) * 0.45
		var d := Vector2.from_angle(a)
		var bob := 3.0 * sin(t * 1.6 + i * 0.9)
		var base := lift + d * r * 1.22 + Vector2(0, bob)
		var s := r * (0.3 if i % 2 == 0 else 0.22)
		var n := d.orthogonal()
		var pts := PackedVector2Array([base - n * s * 0.5, base + d * s * 0.2 - n * s * 0.3, base + d * s * 1.1, base + n * s * 0.55, base - d * s * 0.3])
		Art.volume(c, pts, shard, 0.5)
		Art.outline(c, pts, Color(Art.c("ennemi_contour"), 0.55), Art.TRAIT_FIN)


## Le Cœur purifié : une pierre levée claire, gravée d'une spirale de sève qui luit, d'où partent
## trois rubans qui flottent au vent ; de l'herbe pousse à son pied.
static func draw_heart_purified(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var t: float = h.t
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	Art.shadow(c, Vector2(0, 2), r * 1.3)
	Art.glow(c, lift + Vector2(0, -r * 0.4), r * (1.8 + 0.1 * b), "seve")
	var col := Art.c("brume").lerp(Art.ec("vent", "clair"), 0.45)
	var menhir := stone(Vector2.ZERO, r * 0.48, r * 2.2, r * 0.08)
	Art.volume(c, menhir, col, 0.7)
	Art.outline(c, menhir, Color(Art.c("contour"), 0.7), Art.TRAIT)
	# Spirale gravée qui luit de sève.
	var mid := Vector2(r * 0.02, -r * 1.05)
	var spiral := PackedVector2Array()
	for i in 22:
		var u := i / 21.0
		spiral.append(mid + Vector2.from_angle(u * TAU * 1.6 + t * 0.2) * r * (0.04 + 0.3 * u) * Vector2(1.0, 1.25))
	c.draw_polyline(spiral, Color(Art.ec("seve", "clair"), 0.6 + 0.3 * b), Art.TRAIT, true)
	# Rubans au vent depuis le sommet : ils ondulent vers la droite.
	var top := Vector2(r * 0.05, -r * 2.15)
	var colors := [Art.ec("vent", "clair"), Art.ec("seve"), Art.c("or")]
	for i in 3:
		var pts := PackedVector2Array()
		for j in 9:
			var u := j / 8.0
			pts.append(top + Vector2(r * (0.1 + 1.6 * u), r * (0.15 * i + 0.5 * u * u) + 7.0 * sin(u * 6.0 - t * 4.0 + i * 1.7) * u))
		c.draw_polyline(pts, colors[i], 3.0, true)
	# Herbe au pied, couchée par le vent.
	var grass := Art.c("decor_vivant").lightened(0.15)
	for i in 9:
		var x := (i - 4) * r * 0.2
		var p := Vector2(x, r * 0.05 * ((i % 3) - 1))
		c.draw_line(p, p + Vector2(r * 0.16 + 2.0 * sin(t * 2.0 + i), -r * (0.3 + 0.08 * (i % 3))), grass, 2.0, true)
	# Rafales claires qui passent.
	for i in 2:
		var u := fposmod(t * 0.4 + i * 0.5, 1.0)
		var p := Vector2(-r * 1.6 + r * 3.2 * u, -r * (0.8 + 0.9 * i))
		c.draw_line(p, p + Vector2(r * 0.5, 0), Color(Art.ec("vent", "clair"), sin(PI * u) * 0.7), 2.0, true)


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
