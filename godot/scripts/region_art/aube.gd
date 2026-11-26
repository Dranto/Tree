## Dessins de la région d'Aube (les falaises de verre) : le Cœur de l'aurore et le cercle d'éclats de
## verre de l'arène de la Phalène. Voir region_art.gd (ce qui n'est pas remplacé ici reste celui du
## roncier).
##   - Cœur (refonte du monde, vague 2 P5) : une géode fermée, calcaire en strates fendu de braise,
##     des pointes de quartz fumé qui percent la croûte, prise dans des racines de pierre ; purifiée,
##     elle s'ouvre en deux et montre sa couronne de cristaux de nacre et d'or qui luit ;
##   - mur de l'arène : un cercle d'aiguilles de verre plantées dans la roche ; brèche du côté du
##     Cœur ; pendant le combat la lumière crue y court et les arêtes brûlent ; une fois la Phalène
##     vaincue, le verre s'éclaircit et des fleurs d'aube s'ouvrent à son pied.
##
## Palette des falaises (PAL) : partagée par le décor (decor_falaise.gd), les Flétris
## (enemy_art/aube.gd) et la Phalène (boss_aube.gd). Ce sont les couleurs de la branche Aube
## (#f2d06b) et de son verre.
extends "res://scripts/region_art.gd"

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

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


# --- Cœur de l'aurore (refonte du monde, vague 2 P5) ---


static func _m(etat: String, key: String):
	return Art.mc("aube", etat, key)


## Partie fixe du Cœur, pied en (0, 0), taille s : géode fermée qui a cédé de k (fentes de braise →
## sève), ou géode ouverte (purifiée).
static func heart_body(c: CanvasItem, _region: String, s: float, purified: bool, k: float) -> void:
	var h := Lieux.HEART_H * s
	var etat := "ravive" if purified else "fletri"
	var rock: Dictionary = _m(etat, "roche")
	var base := Vector2.ZERO
	O.poly(c, O.blob(base, h * 0.9, h * 0.34, 3.0, 0.12, 40), Color(_m(etat, "sol_sombre"), 0.55 if purified else 0.7))
	O.cast_shadow(c, base, h * 0.75, h * 0.7, 0.4)
	# Racines de pierre (veinées de braise tant qu'il vit).
	Lieux._roots(c, base, s, rock["ombre"], rock["clair"], 8, 140.0, not purified, false, 29, k)
	if purified:
		_geode_open(c, base, h, s)
	else:
		_geode_closed(c, base, h, s, k)


## Partie animée du Cœur h (heart.gd) : flétri, la lueur et les braises communes ; purifié, un halo
## d'or, des rayons qui tournent lentement et des éclats qui montent en scintillant.
static func heart_live(c: CanvasItem, h, s: float) -> void:
	if h.state != "purifie":
		Lieux.heart_live(c, h.region, Vector2.ZERO, s, false, h.ratio(), h.t, h.state == "siege")
		return
	var hh := Lieux.HEART_H * s
	var t: float = h.t
	var gold: Color = _m("ravive", "lueur")
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	var mid := Vector2(0, -hh * 0.38)
	c.draw_circle(mid, hh * 0.8, Color(gold, 0.03 + 0.02 * b))
	c.draw_circle(mid, hh * 0.42, Color(gold, 0.06 + 0.04 * b))
	# Rayons obliques depuis le cœur ouvert.
	for i in 5:
		var a := -PI * 0.5 + (i - 2) * 0.42 + sin(t * 0.3 + i) * 0.06
		var d := Vector2.from_angle(a)
		var l := hh * (0.75 + 0.15 * sin(t * 0.8 + i * 1.7))
		c.draw_colored_polygon(PackedVector2Array([mid + d.orthogonal() * hh * 0.03, mid + d * l + d.orthogonal() * hh * 0.09,
			mid + d * l - d.orthogonal() * hh * 0.09, mid - d.orthogonal() * hh * 0.03]), Color(gold, 0.035 + 0.025 * b))
	# Éclats qui montent, en losange, et clignent.
	var white: Color = _m("ravive", "nacre")["reflet"]
	for i in 8:
		var u := fposmod(t * 0.2 + i / 8.0, 1.0)
		var p := mid + Vector2(sin(i * 2.1 + t * 0.7) * hh * 0.4, -hh * 0.2 - hh * 0.9 * u)
		var tw := 0.5 + 0.5 * sin(t * 7.0 + i * 3.1)
		var z := 3.0 * s * (0.6 + 0.4 * tw)
		var a := sin(PI * u)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -z * 1.5), p + Vector2(z, 0), p + Vector2(0, z * 1.5), p + Vector2(-z, 0)]), Color(gold, 0.8 * a))
		c.draw_line(p - Vector2(z * 2.2, 0), p + Vector2(z * 2.2, 0), Color(white, 0.6 * a * tw), 1.0, true)


## Place prise par heart_body autour du pied (pixels du monde), pour la cuisson.
static func heart_box(s: float) -> Rect2:
	return Lieux.heart_box(s)


## Géode fermée : un gros œuf de calcaire en strates, posé sur des blocs, croûte fendue de braise ;
## des pointes de quartz fumé percent la croûte.
static func _geode_closed(c: CanvasItem, base: Vector2, h: float, s: float, k: float) -> void:
	var rock: Dictionary = _m("fletri", "roche")
	var glass: Dictionary = _m("fletri", "verre")
	# Blocs du nid, de part et d'autre.
	for b in [[Vector2(-0.36, 0.02), 0.16, 0.12], [Vector2(0.38, 0.04), 0.14, 0.1]]:
		Ink.part(c, Transform2D.IDENTITY, Ink.lumpy(base + b[0] * h, b[1] * h, b[2] * h, 14, 0.12, 3.0, b[0].x * 9.0), rock, 2.0, 0.8, 0.3)
	var mid := base + Vector2(0, -h * 0.4)
	var egg := Ink.lumpy(mid, h * 0.34, h * 0.4, 40, 0.05, 7.0, 1.3)
	Ink.part(c, Transform2D.IDENTITY, egg, rock, 2.2, 1.0, 0.5)
	# Strates de la croûte : bandes courbes, liseré clair au-dessus.
	for i in 4:
		var y := -h * 0.2 + i * h * 0.11
		var w := h * 0.33 * sqrt(maxf(0.0, 1.0 - pow(y / (h * 0.4), 2.0)))
		var line := O.curve(mid + Vector2(-w, y), mid + Vector2(0, y + h * 0.05), mid + Vector2(w, y - h * 0.01), 8)
		O.brush(c, line, 2.0 * s, Color(rock["ombre"].darkened(0.3), 0.75), 0.2, 0.2)
		O.brush(c, Transform2D(0.0, Vector2(0, -2.0 * s)) * line, 1.0 * s, Color(rock["reflet"], 0.4), 0.2, 0.2)
	# Pointes de quartz qui percent la croûte (verre fumé).
	for q in [[Vector2(-0.2, -0.62), 0.13, -0.5], [Vector2(0.14, -0.7), 0.17, 0.3], [Vector2(0.27, -0.42), 0.1, 1.0], [Vector2(-0.3, -0.36), 0.08, -1.1]]:
		var foot: Vector2 = base + q[0] * h
		var d := Vector2.from_angle(-PI * 0.5 + q[2])
		var l: float = q[1] * h
		var w := l * 0.28
		var pts := PackedVector2Array([foot - d.orthogonal() * w, foot + d * l * 0.7 - d.orthogonal() * w * 0.8, foot + d * l,
			foot + d * l * 0.7 + d.orthogonal() * w * 0.8, foot + d.orthogonal() * w])
		Ink.part(c, Transform2D.IDENTITY, pts, glass, 1.4, 0.7, 0.0)
		c.draw_line(foot, foot + d * l, Color(glass["reflet"], 0.6), 1.0 * s, true)
	# Fentes de braise (virent à la sève quand le Cœur cède).
	Lieux._crack(c, mid + Vector2(-h * 0.06, -h * 0.26), Vector2(0.2, 1), h * 0.5, s, 0.5, 13, k)
	Lieux._crack(c, mid + Vector2(h * 0.16, -h * 0.12), Vector2(-0.2, 1), h * 0.3, s, 0.5, 27, k)
	Lieux._crack(c, mid + Vector2(-h * 0.24, h * 0.02), Vector2(0.4, 1), h * 0.16, s, 0.5, 41, k)
	# Bouche au sommet (elle fume : heart_live).
	var top := base + Vector2(h * 0.04, -h * 0.78)
	O.poly(c, Ink.oval(top, h * 0.07, h * 0.028, 12), Art.bc("ronge"))


## Géode ouverte : la géode s'est fendue en deux moitiés dressées de part et d'autre, leur tranche
## tournée vers nous : croûte de calcaire, bandes de nacre et d'or, puis une couronne de dents de
## cristal autour d'un creux qui luit. Entre elles, un bouquet de cristaux clairs.
static func _geode_open(c: CanvasItem, base: Vector2, h: float, s: float) -> void:
	var rock: Dictionary = _m("ravive", "roche")
	var nacre: Dictionary = _m("ravive", "nacre")
	var glass: Dictionary = _m("ravive", "verre")
	var gold: Color = _m("ravive", "lueur")
	for side: float in [-1.0, 1.0]:
		var cc := base + Vector2(side * h * 0.33, -h * 0.27)
		var rot := side * 0.42
		var rx := h * 0.25
		var ry := h * 0.31
		# Croûte (dos de la moitié), puis la tranche : nacre, or, creux ambré.
		Ink.part(c, Transform2D.IDENTITY, Ink.lumpy(cc, rx, ry, 30, 0.05, 6.0, side), rock, 2.2, 1.0, 0.4)
		var face := Transform2D(rot, cc)
		Ink.part(c, Transform2D.IDENTITY, face * Ink.oval(Vector2.ZERO, rx * 0.84, ry * 0.86, 28), nacre, 0.0, 0.8, 0.8)
		O.poly(c, face * Ink.oval(Vector2(0, ry * 0.02), rx * 0.7, ry * 0.72, 28), gold.darkened(0.1))
		O.poly(c, face * Ink.oval(Vector2(0, ry * 0.04), rx * 0.58, ry * 0.6, 28), _m("ravive", "fruit").darkened(0.35))
		# Dents de cristal du bord vers le creux, inégales (druse).
		var rr := RandomNumberGenerator.new()
		rr.seed = 61 + int(side)
		var teeth := 24
		for i in teeth:
			var a := TAU * (i + rr.randf_range(-0.3, 0.3)) / teeth
			var e := Vector2(cos(a) * rx * 0.62, sin(a) * ry * 0.64 + ry * 0.04)
			var inner := Vector2(0, ry * 0.04) + (e - Vector2(0, ry * 0.04)) * rr.randf_range(0.2, 0.62)
			var n := Vector2.from_angle(a).orthogonal() * rx * rr.randf_range(0.06, 0.11)
			var p: Dictionary = nacre if i % 4 == 0 else glass
			O.poly(c, face * PackedVector2Array([e - n, inner, e + n]), p["clair"] if i % 2 == 0 else p["ombre"])
			c.draw_line(face * e.lerp(inner, 0.2), face * inner, Color(p["reflet"], 0.7), 0.8 * s, true)
		c.draw_circle(face * Vector2(0, ry * 0.04), rx * 0.16, Color(gold, 0.75))
		c.draw_circle(face * Vector2(-rx * 0.03, ry * 0.0), rx * 0.06, nacre["reflet"])
	# Bouquet de cristaux entre les deux moitiés, du fond vers l'avant.
	var mid := base + Vector2(0, -h * 0.04)
	c.draw_circle(mid + Vector2(0, -h * 0.2), h * 0.2, Color(gold, 0.18))
	var items := []
	for i in 7:
		var u := (i - 3) / 3.0
		var foot := mid + Vector2(u * h * 0.13, h * 0.03 * (1.0 - absf(u)) * (1.0 if i % 2 == 0 else -0.5))
		var l := h * (0.62 - 0.3 * absf(u)) * (1.0 if i % 2 == 0 else 0.78)
		items.append([foot, l, u, i])
	items.sort_custom(func(a, b): return a[0].y < b[0].y)
	for it in items:
		var foot: Vector2 = it[0]
		var l: float = it[1]
		var d := Vector2.from_angle(-PI * 0.5 + it[2] * 0.45)
		var w := l * 0.15
		var pts := PackedVector2Array([foot - d.orthogonal() * w, foot + d * l * 0.75 - d.orthogonal() * w * 0.85, foot + d * l,
			foot + d * l * 0.75 + d.orthogonal() * w * 0.85, foot + d.orthogonal() * w])
		var p: Dictionary = nacre if int(it[3]) % 3 == 0 else glass
		Ink.part(c, Transform2D.IDENTITY, pts, p, 1.4, 0.7, 0.0)
		O.poly(c, PackedVector2Array([foot, foot + d * l, pts[3], pts[4]]), Color(p["clair"].lightened(0.15), 0.8))
		c.draw_line(foot, foot + d * l, Color(p["reflet"], 0.9), 1.2 * s, true)
	# Fleurs d'aube et herbe dorée autour du nid.
	for i in 7:
		var a := PI * (0.05 + 0.9 * i / 6.0)
		var p := base + Vector2(cos(a) * h * 0.62, sin(a) * h * 0.2 + h * 0.02)
		O.tuft(c, p, h * 0.1, _m("ravive", "touffe"), _m("ravive", "touffe_2"), 300 + i)
		var pts := PackedVector2Array()
		var r := h * 0.028
		var q := p + Vector2(0, -h * 0.08)
		for j in 12:
			pts.append(q + Vector2.from_angle(TAU * j / 12.0 - PI / 2.0) * r * (1.3 if j % 2 == 0 else 0.6) * Vector2(1.0, 0.8))
		O.poly(c, pts, _m("ravive", "fleur") if i % 2 == 0 else _m("ravive", "fleur_2"))
		c.draw_circle(q, r * 0.42, _m("ravive", "fleur_coeur"))
