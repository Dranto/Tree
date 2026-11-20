## Dessins de la région de Racine (la forêt pétrifiée) : le Cœur des cernes et la palissade de troncs
## pétrifiés de la clairière de l'Ancien. Voir region_art.gd (le reste est celui du roncier).
##   - Cœur flétri : le bulbe des Flétris enchâssé dans une énorme souche de pierre coupée net, dont
##     les cernes gravés rougeoient de braise ; des racines de roche rayonnent et se fendent ;
##   - Cœur purifié : la souche redevient bois, ses cernes luisent d'un vert tendre, un jeune chêne
##     pousse au milieu ; de la mousse et des glands au pied ;
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


## Le Cœur flétri : une souche de pierre coupée net, le bulbe enchâssé au milieu ; les cernes gravés
## rougeoient de braise (plus vite pendant le siège) et virent au vert à mesure qu'il cède.
static func draw_heart(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var k: float = h.ratio()
	var t: float = h.t
	var siege: bool = h.state == "siege"
	Art.shadow(c, Vector2(0, 2), r * 1.5)
	var rock := stone(k * 0.3)
	# Racines de roche qui rayonnent et s'enfoncent, fendues de braise.
	var crack := Art.ec("cendre").lerp(Art.ec("racine", "clair"), k)
	for i in 7:
		var a := PI * (0.02 + 0.96 * i / 6.0)
		var tip := Vector2(cos(a) * r * 2.0, sin(a) * r * 0.6 + r * 0.15)
		var base := Vector2(cos(a) * r * 0.9, sin(a) * r * 0.3)
		var n := (tip - base).orthogonal().normalized() * r * 0.16
		c.draw_colored_polygon(PackedVector2Array([base + n, tip, base - n]), rock.darkened(0.2 + 0.06 * (i % 2)))
		c.draw_line(base, base.lerp(tip, 0.7), Color(crack, 0.35 + 0.25 * sin(t * (7.0 if siege else 2.5) + i)), 1.5, true)
	# La souche : un cylindre bas et large.
	var w := r * 1.35
	var hh := r * 0.75
	var body := PackedVector2Array([Vector2(-w, -hh), Vector2(-w * 1.05, r * 0.1), Vector2(-w * 0.6, r * 0.32), Vector2(w * 0.6, r * 0.32), Vector2(w * 1.05, r * 0.1), Vector2(w, -hh)])
	Art.volume(c, body, rock, 0.5)
	# Le dessus coupé et ses cernes gravés qui rougeoient.
	var top := Art.ellipse(Vector2(0, -hh), w, w * 0.36, 28)
	c.draw_colored_polygon(top, rock.lightened(0.12))
	var glow := Art.ec("cendre").lerp(Art.ec("racine", "clair"), k)
	for i in 4:
		var u := 0.35 + 0.17 * i
		var pulse := 0.4 + 0.35 * sin(t * (6.0 if siege else 2.0) - i * 0.8)
		c.draw_polyline(Art.ellipse(Vector2(0, -hh), w * u, w * 0.36 * u, 24), Color(glow, pulse), 1.6, true)
	Art.outline(c, body, Color(Art.c("ennemi_contour"), 0.5), Art.TRAIT)
	# Le bulbe enchâssé au milieu de la souche.
	heart_bulb(c, h, lift, r)
	# Échardes de pierre plantées sur le bord, comme une couronne cassée.
	for i in 6:
		var a := PI + PI * (i + 0.5) / 6.0
		var b := Vector2(cos(a) * w * 0.92, -hh + sin(a) * w * 0.33)
		var tip := b + Vector2(cos(a) * r * 0.15, -r * (0.45 + 0.2 * (i % 2)))
		c.draw_colored_polygon(PackedVector2Array([b + Vector2(-r * 0.1, 0), tip, b + Vector2(r * 0.1, 0)]), rock.darkened(0.1 * (i % 2)))


## Le Cœur purifié : la souche redevient bois vivant, ses cernes luisent ; un jeune chêne pousse au
## milieu, de la mousse et des glands au pied.
static func draw_heart_purified(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var t: float = h.t
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	Art.shadow(c, Vector2(0, 2), r * 1.5)
	Art.glow(c, lift + Vector2(0, -r * 0.6), r * (1.8 + 0.1 * b), "racine")
	var wood := stone(1.0)
	var w := r * 1.35
	var hh := r * 0.75
	# Racines de bois, moussues.
	var moss := Art.c("decor_vivant")
	for i in 7:
		var a := PI * (0.02 + 0.96 * i / 6.0)
		var tip := Vector2(cos(a) * r * 2.0, sin(a) * r * 0.6 + r * 0.15)
		var base := Vector2(cos(a) * r * 0.9, sin(a) * r * 0.3)
		var n := (tip - base).orthogonal().normalized() * r * 0.16
		c.draw_colored_polygon(PackedVector2Array([base + n, tip, base - n]), wood.darkened(0.15 + 0.06 * (i % 2)))
		c.draw_colored_polygon(Art.ellipse(base.lerp(tip, 0.4) + Vector2(0, -r * 0.05), r * 0.2, r * 0.07, 8), moss.darkened(0.1))
	var body := PackedVector2Array([Vector2(-w, -hh), Vector2(-w * 1.05, r * 0.1), Vector2(-w * 0.6, r * 0.32), Vector2(w * 0.6, r * 0.32), Vector2(w * 1.05, r * 0.1), Vector2(w, -hh)])
	Art.volume(c, body, wood, 0.5)
	c.draw_colored_polygon(Art.ellipse(Vector2(0, -hh), w, w * 0.36, 28), wood.lightened(0.18))
	for i in 4:
		var u := 0.35 + 0.17 * i
		c.draw_polyline(Art.ellipse(Vector2(0, -hh), w * u, w * 0.36 * u, 24), Color(Art.ec("racine", "clair"), 0.35 + 0.3 * sin(t * 1.5 - i * 0.7)), 1.5, true)
	# Mousse qui coule sur le bord de la souche.
	for i in 5:
		var x := (i - 2) * w * 0.38
		c.draw_colored_polygon(Art.ellipse(Vector2(x, -hh + w * 0.3 * (1.0 - absf(i - 2) * 0.3)), r * 0.28, r * 0.1, 10), moss.darkened(0.05 * (i % 2)))
	# Le jeune chêne : un tronc souple et une couronne lobée.
	var bark := Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.15)
	var foot := Vector2(0, -hh)
	var top := foot + Vector2(r * 0.08, -r * 1.6)
	c.draw_colored_polygon(PackedVector2Array([foot + Vector2(-r * 0.14, 0), foot + Vector2(-r * 0.06, -r * 0.9), top, foot + Vector2(r * 0.12, -r * 0.9), foot + Vector2(r * 0.16, 0)]), bark)
	for sgn in [-1.0, 1.0]:
		c.draw_line(foot + Vector2(0, -r * 1.0), foot + Vector2(sgn * r * 0.5, -r * 1.45), bark, 3.0, true)
	var leaf := Art.c("decor_vivant").lerp(Art.ec("racine", "clair"), 0.25)
	var lobes := [[0.0, -0.35, 0.55], [-0.55, -0.1, 0.42], [0.55, -0.1, 0.42], [-0.3, 0.15, 0.38], [0.3, 0.15, 0.38]]
	for l in lobes:
		var q: Vector2 = top + Vector2(l[0] * r * (1.0 + 0.02 * b), l[1] * r)
		Art.volume_circle(c, q, r * l[2], leaf.darkened(0.04 * (absi(int(l[0] * 10)) % 3)), 0.6)
	# Glands au pied, qui brillent doucement.
	for i in 3:
		var p := Vector2((i - 1) * w * 0.55 + r * 0.1, r * 0.28 + (i % 2) * r * 0.08)
		c.draw_colored_polygon(Art.ellipse(p, r * 0.1, r * 0.13, 10), Art.ec("racine").lightened(0.15))
		c.draw_colored_polygon(Art.ellipse(p + Vector2(0, -r * 0.1), r * 0.12, r * 0.06, 10), Art.ec("racine", "sombre"))
		c.draw_circle(p + Vector2(-r * 0.03, -r * 0.02), 1.5 + b, Color(Art.ec("racine", "clair"), 0.6))


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
