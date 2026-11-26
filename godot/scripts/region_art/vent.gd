## Dessins de la région de Vent (les hauts plateaux) : le Cœur de cendre des plateaux et le cercle de
## pierres levées de l'arène du Harfang. Voir region_art.gd (le reste est celui du roncier).
##   - Cœur (refonte du monde, vague 2 P3) : un nid de pierres plates et de racines tordues autour d'un
##     œuf d'orage d'ardoise fendu de braise, où courent de petits éclairs ; purifié, l'œuf s'ouvre en un
##     bouquet de grandes plumes blanches et d'herbes argentées, qui lâche des plumes dans le vent ;
##   - mur de l'arène : un muret de pierres sèches ponctué de pierres levées ; brèche du côté du Cœur ;
##     des runes de braise s'allument pendant le combat ; vaincue, la mousse et l'herbe le gagnent.
extends "res://scripts/region_art.gd"

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const Plateau = preload("res://scripts/decor_plateau.gd")
const SolVent = preload("res://scripts/world_bake/sol/vent.gd")


static func _m(etat: String, key: String):
	return Art.mc("vent", etat, key)


## Le Cœur, partie fixe (cuite) : nid de pierres et de racines, œuf d'orage (flétri, qui a cédé de k),
## ou bouquet de plumes et d'herbes (purifié). Pied en (0, 0).
static func heart_body(c: CanvasItem, _region: String, s: float, purified: bool, k: float) -> void:
	var h := Lieux.HEART_H * s
	var etat := "ravive" if purified else "fletri"
	var st: Dictionary = _m(etat, "pierre")
	var bois: Dictionary = _m(etat, "bois")
	var z := Vector2.ZERO
	O.poly(c, O.blob(z, h * 0.86, h * 0.32, 11.0, 0.14, 40), Color(_m(etat, "sol_sombre"), 0.55 if purified else 0.7))
	O.cast_shadow(c, z, h * 0.75, h * 0.7, 0.4)
	Lieux._roots(c, z, s, bois["ombre"], bois["clair"], 7, 135.0, not purified, false, 23, k)
	# Nid : un anneau de pierres plates (la moitié du fond d'abord), des racines tordues entre elles.
	var stones := []
	for i in 11:
		var a := TAU * i / 11.0 + 0.2
		stones.append([Vector2(cos(a) * h * 0.5, sin(a) * h * 0.17 - h * 0.08), a])
	stones.sort_custom(func(x, y): return x[0].y < y[0].y)
	var back := stones.filter(func(x): return x[0].y < -h * 0.08)
	var front := stones.filter(func(x): return x[0].y >= -h * 0.08)
	for sn in back:
		_nest_stone(c, sn[0], h, st, etat, sn[1])
	_nest_roots(c, h, s, bois, -1.0)
	var egg := Vector2(0, -h * 0.44)
	if not purified:
		# L'œuf d'orage : ardoise sombre, bandes de nuées, fentes de braise qui virent à la sève.
		var pal := {"clair": _m("fletri", "orage_reflet"), "ombre": _m("fletri", "orage"), "reflet": _m("fletri", "cendre")}
		O.part(c, Ink.lumpy(egg, h * 0.29, h * 0.38, 32, 0.03, 4.0), pal, 2.0, 1.0, 0.8)
		for j in 3:
			var y := egg.y - h * (0.16 - 0.13 * j)
			var w := h * (0.2 - 0.03 * absf(j - 1.0))
			O.brush(c, O.curve(Vector2(-w, y + h * 0.02), Vector2(0, y - h * 0.04), Vector2(w, y + h * 0.01), 8), 2.2 * s, Color(_m("fletri", "orage_reflet").lightened(0.15), 0.45), 0.0, 0.0)
		Lieux._crack(c, egg + Vector2(-h * 0.05, -h * 0.24), Vector2(0.25, 1), h * 0.4, s, 0.5, 31, k)
		Lieux._crack(c, egg + Vector2(h * 0.1, -h * 0.1), Vector2(-0.15, 1), h * 0.26, s, 0.5, 44, k)
		# Plumes grises sèches prises dans le nid.
		for i in 4:
			var a := -PI * 0.5 + (i - 1.5) * 0.55
			Plateau.P.feather(c, Vector2((i - 1.5) * h * 0.22, -h * 0.12), a, h * 0.22, "fletri", 0.1)
	else:
		# Les deux moitiés de la coquille, rabattues de part et d'autre.
		var shell := {"clair": _m("ravive", "orage_reflet"), "ombre": _m("ravive", "orage"), "reflet": Color.WHITE}
		for sx in [-1.0, 1.0]:
			var p := Vector2(sx * h * 0.17, -h * 0.13)
			var pts := PackedVector2Array()
			for i in 11:
				var a := PI + PI * i / 10.0
				pts.append(p + Vector2(cos(a) * h * 0.14, sin(a) * h * 0.11 * (1.0 + 0.3 * sin(i * 2.7))))
			pts.append(p + Vector2(h * 0.14, h * 0.03))
			pts.append(p + Vector2(-h * 0.14, h * 0.03))
			O.part(c, pts, shell, 1.4, 1.0, 0.7)
		# Bouquet : herbes argentées à plumets, puis grandes plumes blanches en éventail, fleurs.
		var side := SolVent.side()
		var herbe: Dictionary = _m("ravive", "herbe")
		for i in 9:
			var u := (i - 4) / 4.0
			var b := Vector2(u * h * 0.1, -h * 0.12)
			var tip := b + Vector2(u * h * 0.45 + side * h * 0.12, -h * (1.05 - 0.3 * absf(u)))
			var mid := b.lerp(tip, 0.5) + Vector2(-u * h * 0.06, -h * 0.05)
			O.brush(c, O.curve(b, mid, tip, 8), 2.4 * s, herbe["ombre"] if i % 2 else herbe["clair"], 1.0, 0.0)
			if i % 2 == 0:
				var end := tip + Vector2(side * h * 0.16, h * 0.03)
				O.brush(c, O.curve(tip, tip.lerp(end, 0.5) + Vector2(0, -h * 0.02), end, 6), 3.0 * s, Color(_m("ravive", "plume"), 0.85), 0.0, 0.0)
		for i in 7:
			var u := (i - 3) / 3.0
			var a := -PI * 0.5 + u * 0.7 + side * 0.12
			Plateau.P.feather(c, Vector2(u * h * 0.05, -h * 0.14), a, h * (0.82 - 0.2 * absf(u)), "ravive", u * 0.12)
		for fl in [[Vector2(-0.24, -0.3), 0.055], [Vector2(0.2, -0.26), 0.05], [Vector2(-0.08, -0.2), 0.045], [Vector2(0.3, -0.42), 0.04], [Vector2(-0.34, -0.48), 0.04]]:
			O.flower(c, fl[0] * h, fl[1] * h, _m("ravive", "fleur" if fl[0].x < 0.0 else "fleur_2"), _m("ravive", "fleur_coeur"), fl[0].x * 7.0)
	_nest_roots(c, h, s, bois, 1.0)
	for sn in front:
		_nest_stone(c, sn[0], h, st, etat, sn[1])


static func _nest_stone(c: CanvasItem, p: Vector2, h: float, st: Dictionary, etat: String, a: float) -> void:
	var rx := h * (0.14 + 0.03 * sin(a * 3.0))
	O.part(c, O.blob(p + Vector2(0, -h * 0.04), rx, h * 0.07, a * 5.0, 0.18, 16, sin(a) * 0.2), st, 1.3, 1.0, 0.5)
	O.poly(c, O.blob(p + Vector2(-rx * 0.3, -h * 0.07), rx * 0.3, h * 0.02, a, 0.3, 8), Color(_m(etat, "lichen"), 0.75))


## Racines tordues tressées dans le nid (dos : derrière l'œuf ; face : devant).
static func _nest_roots(c: CanvasItem, h: float, s: float, bois: Dictionary, face: float) -> void:
	for i in 2:
		var a0 := (0.15 + 0.5 * i) * PI if face > 0.0 else (1.15 + 0.5 * i) * PI
		var pts := PackedVector2Array()
		for j in 12:
			var a := a0 + PI * 0.55 * j / 11.0
			pts.append(Vector2(cos(a) * h * 0.46, sin(a) * h * 0.15 - h * 0.12 - sin(j * 1.3) * h * 0.04))
		O.brush(c, pts, 6.0 * s, Ink.encre(), 1.0, 1.0)
		O.brush(c, pts, 4.2 * s, bois["ombre"], 1.0, 1.0)
		O.brush(c, pts, 1.6 * s, bois["clair"], 1.0, 1.0)


## Partie animée du Cœur : celle des lieux (lueur, braises, halo), plus de petits éclairs autour de
## l'œuf (flétri) ou des plumes que le vent arrache au bouquet (purifié).
static func heart_live(c: CanvasItem, h, s: float) -> void:
	Lieux.heart_live(c, h.region, Vector2.ZERO, s, h.state == "purifie", h.ratio(), h.t, h.state == "siege")
	var hh := Lieux.HEART_H * s
	var t: float = h.t
	var side := SolVent.side()
	if h.state == "purifie":
		for i in 5:
			var u := fposmod(t * 0.16 + i / 5.0, 1.0)
			var p := Vector2(side * hh * (0.1 + 1.1 * u), -hh * (0.7 + 0.25 * sin(u * PI)) + sin(t * 2.0 + i) * hh * 0.05)
			var a := -PI * 0.5 + side * (0.8 + 1.8 * u) + sin(t * 3.0 + i) * 0.4
			var l := hh * 0.09
			var d := Vector2.from_angle(a)
			c.draw_colored_polygon(Ink.leaf(p, a, l, l * 0.28, 0.1), Color(_m("ravive", "plume"), 0.8 * sin(PI * u)))
			c.draw_line(p, p + d * l, Color(_m("ravive", "plume_ombre"), 0.6 * sin(PI * u)), 1.0, true)
		return
	# Éclairs : un ou deux traits brisés qui claquent près de l'œuf, plus souvent pendant le siège.
	var siege: bool = h.state == "siege"
	var rate := 7.0 if siege else 2.5
	var phase := fposmod(t * rate, 1.0)
	if phase > (0.35 if siege else 0.18):
		return
	var n := int(floor(t * rate))
	var r := RandomNumberGenerator.new()
	r.seed = n * 7919 + 3
	var col: Color = Lieux._braise_coeur(h.ratio())
	for j in (2 if siege else 1):
		var a := r.randf_range(-PI * 0.95, -PI * 0.05)
		var p := Vector2(0, -hh * 0.4) + Vector2(cos(a) * hh * 0.22, sin(a) * hh * 0.3)
		var pts := PackedVector2Array([p])
		for i in 4:
			p += Vector2.from_angle(a + r.randf_range(-0.8, 0.8)) * hh * 0.07
			pts.append(p)
		c.draw_polyline(pts, Color(col, 0.35), 3.5 * s, true)
		c.draw_polyline(pts, Color(col.lightened(0.4), 0.9 * (1.0 - phase * 2.0)), 1.2 * s, true)


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
