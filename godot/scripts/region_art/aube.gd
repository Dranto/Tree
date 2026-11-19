## Dessins de la région d'Aube (les falaises de verre) : le Cœur de l'aurore et le cercle d'éclats de
## verre de l'arène de la Phalène. Voir region_art.gd (ce qui n'est pas remplacé ici reste celui du
## roncier).
##   - Cœur flétri : le bulbe des Flétris serti dans une couronne de prismes de verre fumé, fêlés,
##     d'où ne filtre qu'une lumière sale ; des éclats de verre jonchent son pied ;
##   - Cœur purifié : une flèche de cristal clair au cœur d'or, qui jette des rayons d'aube et des
##     reflets irisés ; des fleurs pâles poussent entre les éclats ;
##   - mur de l'arène : un cercle d'aiguilles de verre plantées dans la roche ; brèche du côté du
##     Cœur ; pendant le combat la lumière crue y court et les arêtes brûlent ; une fois la Phalène
##     vaincue, le verre s'éclaircit et des fleurs d'aube s'ouvrent à son pied.
##
## Palette des falaises (PAL) : partagée par le décor (decor_falaise.gd), les Flétris
## (enemy_art/aube.gd) et la Phalène (boss_aube.gd). Ce sont les couleurs de la branche Aube
## (#f2d06b) et de son verre.
extends "res://scripts/region_art.gd"

const PAL := {
	## La lumière d'aube : couleur, reflet, ombre.
	"lumiere": Color("f2d06b"),
	"lumiere_clair": Color("fff4cf"),
	"lumiere_sombre": Color("6e5418"),
	## Le verre des falaises : clair, puis fumé (flétri).
	"verre": Color("bcdde6"),
	"verre_clair": Color("f0fbff"),
	"verre_sombre": Color("3e5866"),
	"verre_fume": Color("4c4a56"),
	## La roche des falaises : calcaire pâle, presque blanc sous la lumière crue.
	"roche": Color("8a8476"),
	"roche_clair": Color("c8c0aa"),
	## Reflets irisés du prisme (rouge, or, vert, bleu), très légers.
	"iris_1": Color("f29a8a"),
	"iris_2": Color("f2e08a"),
	"iris_3": Color("9ae8b0"),
	"iris_4": Color("9ab8f2"),
}


static func pal(key: String) -> Color:
	return PAL[key]


## Prisme de verre (polygone effilé) : pied en « p », demi-largeur wid, hauteur hgt, penché de lean.
static func prism(p: Vector2, wid: float, hgt: float, lean := 0.0) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(-wid, 0), p + Vector2(-wid * 0.9 + lean * 0.6, -hgt * 0.7),
		p + Vector2(lean, -hgt), p + Vector2(wid * 0.9 + lean * 0.6, -hgt * 0.72), p + Vector2(wid, 0)])


## Un prisme en volume : face sombre à gauche, face claire à droite, arête lumineuse au milieu.
static func draw_prism(c, pts: PackedVector2Array, col: Color, edge: Color, alpha := 1.0) -> void:
	var tip: Vector2 = pts[2]
	var base: Vector2 = pts[0].lerp(pts[4], 0.5)
	c.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], tip, base]), Color(col.darkened(0.22), alpha))
	c.draw_colored_polygon(PackedVector2Array([base, tip, pts[3], pts[4]]), Color(col.lightened(0.1), alpha))
	c.draw_line(base, tip, Color(edge, 0.85 * alpha), Art.TRAIT_FIN, true)
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, Color(Art.c("contour"), 0.55 * alpha), Art.TRAIT_FIN, true)


## Le Cœur de l'aurore flétri : prismes de verre fumé, fêlés, autour du bulbe ; une lumière sale
## filtre entre eux et se dore à mesure qu'il cède.
static func draw_heart(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var k: float = h.ratio()
	var t: float = h.t
	Art.shadow(c, Vector2(0, 2), r * 1.2)
	var smoke := pal("verre_fume").lerp(pal("verre"), k * 0.7)
	var light := pal("lumiere_sombre").lerp(pal("lumiere"), k)
	# Éclats de verre au pied, à plat.
	for i in 6:
		var x := (i - 2.5) * r * 0.45
		var y := r * (0.05 + 0.08 * (i % 2))
		var pts := PackedVector2Array([Vector2(x - r * 0.18, y), Vector2(x, y - r * 0.12), Vector2(x + r * 0.2, y + r * 0.02), Vector2(x + r * 0.02, y + r * 0.1)])
		c.draw_colored_polygon(pts, Color(smoke.darkened(0.1 * (i % 3)), 0.9))
	# Rais de lumière sale derrière le bulbe (ils se dorent quand il cède).
	for i in 5:
		var a := -PI / 2.0 + (i - 2) * 0.38
		var d := Vector2.from_angle(a)
		var len := r * (2.0 + 0.5 * sin(t * 1.4 + i)) * (0.6 + 0.4 * k)
		var n := d.orthogonal() * r * 0.1
		c.draw_colored_polygon(PackedVector2Array([lift + n, lift + d * len, lift - n]), Color(light, 0.12 + 0.18 * k))
	# Couronne de prismes fumés, derrière et sur les flancs.
	for i in 7:
		var a := -PI / 2.0 + (i - 3) * 0.46
		var d := Vector2.from_angle(a)
		var foot := lift + d * r * 0.7
		var hgt := r * (1.05 if i % 2 == 0 else 0.75)
		var pts := PackedVector2Array()
		for q in prism(Vector2.ZERO, r * 0.2, hgt, 0.0):
			pts.append(foot + q.rotated(a + PI / 2.0))
		draw_prism(c, pts, smoke, light)
		# Fêlure.
		var mid := foot + d * hgt * 0.45
		c.draw_line(mid - d.orthogonal() * r * 0.1, mid + d * r * 0.15, Color(Art.c("contour"), 0.6), 1.2, true)
	heart_bulb(c, h, lift, r)


## Le Cœur de l'aurore purifié : une flèche de cristal clair au cœur d'or, des rayons d'aube et des
## reflets irisés ; quelques fleurs pâles entre les éclats.
static func draw_heart_purified(c: CanvasItem, h, lift: Vector2, r: float) -> void:
	var t: float = h.t
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	Art.shadow(c, Vector2(0, 2), r * 1.3)
	var core := Vector2(0, -r * 1.1)
	# Rayons d'aube qui tournent lentement.
	for i in 8:
		var a := t * 0.12 + TAU * i / 8.0
		var d := Vector2.from_angle(a)
		var len := r * (2.4 + 0.3 * sin(t * 1.3 + i))
		var n := d.orthogonal() * r * 0.12
		c.draw_colored_polygon(PackedVector2Array([core + n, core + d * len, core - n]), Color(pal("lumiere"), 0.16 + 0.06 * b))
	Art.glow(c, core, r * (1.8 + 0.1 * b), "seve")
	# Petits prismes autour du pied.
	for i in 5:
		var x := (i - 2) * r * 0.55
		var hgt := r * (0.55 + 0.2 * (i % 2))
		draw_prism(c, prism(Vector2(x, r * 0.08 * ((i % 2) * 2 - 1)), r * 0.16, hgt, (i - 2) * r * 0.06), pal("verre"), pal("verre_clair"))
	# La grande flèche de cristal.
	var spire := prism(Vector2.ZERO, r * 0.42, r * 2.5, r * 0.04)
	draw_prism(c, spire, pal("verre"), pal("verre_clair"), 0.92)
	# Cœur d'or qui bat dans le cristal.
	Art.volume_circle(c, core, r * (0.3 + 0.03 * b), pal("lumiere"), 0.9)
	c.draw_circle(core + Vector2(-r * 0.08, -r * 0.08), r * 0.1, pal("lumiere_clair"))
	# Reflets irisés sur les arêtes.
	for i in 4:
		var u := fposmod(t * 0.25 + i * 0.25, 1.0)
		var p := Vector2(lerpf(-r * 0.3, r * 0.3, u), -r * (0.4 + 1.8 * u))
		c.draw_line(p, p + Vector2(r * 0.16, -r * 0.08), Color(pal("iris_%d" % (i + 1)), sin(PI * u) * 0.8), 2.0, true)
	# Fleurs pâles au pied.
	for i in 4:
		var p := Vector2((i - 1.5) * r * 0.7, r * 0.18)
		for j in 5:
			c.draw_circle(p + Vector2.from_angle(TAU * j / 5.0 + i) * 3.2, 2.6, pal("lumiere_clair"))
		c.draw_circle(p, 1.8, pal("lumiere"))
	# Poussière dorée qui monte.
	for i in 5:
		var u := fposmod(t * 0.3 + i / 5.0, 1.0)
		var p := core + Vector2(sin(i * 2.3 + t) * r * 0.7, -90.0 * u)
		c.draw_circle(p, 2.0, Color(pal("lumiere_clair"), sin(PI * u)))


## Sol de l'arène : la roche pâle, brûlée de lumière tant que la Phalène vit ; dorée ensuite.
static func draw_arena_floor(c: CanvasItem, a) -> void:
	if a.state == "vaincue":
		c.draw_circle(a.center, a.max_radius * 0.5, Color(Art.c("decor_vivant").lerp(pal("lumiere"), 0.35), 0.09 + 0.03 * sin(a.t * 2.0)))
	else:
		c.draw_circle(a.center, a.radius, Color(pal("verre_sombre").darkened(0.55), 0.3 if a.state == "combat" else 0.2))
		if a.state == "combat":
			# Un halo de lumière crue au centre, qui pulse.
			c.draw_arc(a.center, a.radius * 0.55, 0.0, TAU, 48, Color(pal("lumiere"), 0.08 + 0.05 * sin(a.t * 3.0)), 18.0, true)


## Cercle d'aiguilles de verre : un socle de roche pâle, une aiguille tous les trois points du mur.
static func draw_arena_wall(c: CanvasItem, a) -> void:
	var wall: Array = a._wall
	var n := wall.size()
	var center: Vector2 = a.center
	var fight: bool = a.state == "combat"
	var alive: bool = a.state == "vaincue"
	var rock := pal("roche").darkened(0.25)
	var dark := rock.darkened(0.35)
	var glass := pal("verre_fume").lerp(pal("verre"), 0.35)
	var edge := pal("verre")
	if fight:
		glass = pal("verre_fume")
		edge = pal("lumiere")
	elif alive:
		glass = pal("verre")
		edge = pal("verre_clair")
	# Le socle : deux rangs de roche, interrompus par la brèche.
	var pts := PackedVector2Array()
	var pts2 := PackedVector2Array()
	for i in n + 1:
		var w: Array = wall[i % n]
		var ang := TAU * i / n
		if in_gap(a, ang):
			_ledge(c, pts, pts2, rock, dark)
			pts = PackedVector2Array()
			pts2 = PackedVector2Array()
			continue
		var dir := Vector2.from_angle(ang)
		var r: float = a.radius * (1.0 + w[0])
		pts.append(center + dir * r)
		pts2.append(center + dir * (r + 12.0 + 4.0 * w[2]))
	_ledge(c, pts, pts2, rock, dark)
	# Les aiguilles de verre.
	for i in n:
		if i % 3 != 0:
			continue
		var w: Array = wall[i]
		var ang := TAU * i / n
		if in_gap(a, ang, 0.47):
			continue
		var dir := Vector2.from_angle(ang)
		var p: Vector2 = center + dir * (a.radius * (1.0 + w[0]) + 6.0)
		var hgt: float = 26.0 + 22.0 * w[1]
		var pts3 := prism(p, 6.0 + 2.0 * w[2], hgt, 5.0 * w[2])
		draw_prism(c, pts3, glass, edge)
		if fight:
			# La lumière crue court le long des aiguilles.
			var u := fposmod(a.t * 0.9 + i * 0.07, 1.0)
			var q: Vector2 = pts3[0].lerp(pts3[2], u)
			c.draw_circle(q, 3.0, Color(pal("lumiere_clair"), sin(PI * u)))
		elif alive and i % 2 == 0:
			for j in 5:
				c.draw_circle(p + Vector2(7.0, 2.0) + Vector2.from_angle(TAU * j / 5.0 + i) * 2.6, 2.2, pal("lumiere_clair"))
			c.draw_circle(p + Vector2(7.0, 2.0), 1.6, pal("lumiere"))


static func _ledge(c: CanvasItem, pts: PackedVector2Array, pts2: PackedVector2Array, rock: Color, dark: Color) -> void:
	if pts.size() >= 2:
		c.draw_polyline(pts2, dark, 10.0)
		c.draw_polyline(pts, rock, 12.0)
