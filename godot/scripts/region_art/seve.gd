## Dessins de la région de Sève (la vallée des sources) : le Cœur des sources et la ceinture de
## roseaux et de racines de l'étang du Saule. Voir region_art.gd (le reste est celui du roncier).
##   - Cœur (refonte du monde, vague 2 P4) : un bulbe de sève gonflé, ambré et trouble, fendu de braise,
##     pris dans un nid de racines noires au milieu d'une mare croupie ; purifié, le bulbe s'est ouvert
##     en fontaine claire : une vasque de racines et de pierres moussues d'où jaillit une eau vive
##     (le jet et les gouttes sont animés par heart_live), fougères, nénuphars et myosotis ;
##   - sol de l'arène : l'eau trouble de l'étang tant que le Saule vit, une eau claire ensuite ;
##   - mur de l'arène : une ceinture de roseaux serrés et de racines qui sortent de terre ; brèche du
##     côté du Cœur ; pendant le combat, les roseaux noircissent et leurs pointes rougeoient ;
##     vaincue, des massettes et des fleurs d'eau.
extends "res://scripts/region_art.gd"

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")


static func _m(etat: String, key: String):
	return Art.mc("seve", etat, key)


## Partie fixe du Cœur des sources (cuite), pied en (0, 0), taille s ; k : ce qu'il a cédé au siège.
static func heart_body(c: CanvasItem, _region: String, s: float, purified: bool, k: float) -> void:
	var h := Lieux.HEART_H * s
	var etat := "ravive" if purified else "fletri"
	var bois: Dictionary = _m(etat, "bois")
	var z := Vector2.ZERO
	# Mare au pied : croupie (morte), claire (purifiée).
	O.poly(c, O.blob(z + Vector2(3, 3) * s, h * 0.95, h * 0.34, 5.0, 0.12, 40), Color(Ink.encre(), 0.4))
	O.poly(c, O.blob(z, h * 0.92, h * 0.32, 5.0, 0.12, 40), _m(etat, "sol_sombre") if not purified else Art.mc("seve", "ravive", "pierre")["ombre"])
	O.poly(c, O.blob(z + Vector2(0, -h * 0.01), h * 0.8, h * 0.26, 5.0, 0.1, 40), _m(etat, "eau"))
	c.draw_line(z + Vector2(-h * 0.6, -h * 0.07), z + Vector2(-h * 0.25, -h * 0.1), Color(_m(etat, "eau_reflet"), 0.5), 1.6 * s, true)
	O.cast_shadow(c, z, h * 0.7, h * 0.7, 0.36 if not purified else 0.28)
	# Nid de racines : noires et noueuses (braises le long), ou brunes et vivantes.
	Lieux._roots(c, z, s, bois["ombre"], bois["clair"], 9, 150.0, not purified, false, 23, k)
	if not purified:
		_bulb(c, h, s, k)
	else:
		_fountain(c, h, s)


## Le bulbe flétri : un oignon de sève gonflé, ambré et trouble, serré par des racines, fendu de
## braise ; une bouche au sommet d'où la sève a coulé et figé.
static func _bulb(c: CanvasItem, h: float, s: float, k: float) -> void:
	var sv: Dictionary = _m("fletri", "seve")
	var bois: Dictionary = _m("fletri", "bois")
	var mid := Vector2(0, -h * 0.42)
	# Racines arrière qui montent serrer le bulbe.
	for i in 3:
		var x := (i - 1) * h * 0.22
		var pts := O.curve(Vector2(x * 1.6, 0), Vector2(x * 1.9, -h * 0.35), Vector2(x * 0.4, -h * 0.78), 8)
		O.brush(c, pts, 7.0 * s, Ink.encre(), 0.2, 0.9)
		O.brush(c, pts, 5.0 * s, bois["ombre"], 0.2, 0.9)
	var bulb := Ink.lumpy(mid, h * 0.3, h * 0.36, 32, 0.06, 6.0, 1.3)
	Ink.part(c, Transform2D.IDENTITY, bulb, sv, 2.2, 1.0, 0.9)
	# Nervures du bulbe (des côtes d'oignon), plus sombres.
	for i in 4:
		var x := (i - 1.5) * h * 0.12
		c.draw_polyline(O.curve(mid + Vector2(x * 0.7, h * 0.32), mid + Vector2(x * 1.35, 0), mid + Vector2(x * 0.5, -h * 0.33), 8), Color(sv["ombre"], 0.8), 1.4 * s, true)
	# Reflet trouble en haut à gauche.
	O.poly(c, Ink.oval(mid + Vector2(-h * 0.13, -h * 0.17), h * 0.06, h * 0.11, 14, -0.4), Color(sv["reflet"], 0.45))
	Lieux._crack(c, mid + Vector2(-h * 0.05, -h * 0.16), Vector2(0.15, 1), h * 0.4, s, 0.5, 51, k)
	Lieux._crack(c, mid + Vector2(h * 0.14, -h * 0.02), Vector2(-0.1, 1), h * 0.24, s, 0.5, 63, k)
	# Racines avant qui le serrent.
	for i in 2:
		var sgn := -1.0 if i == 0 else 1.0
		var pts := O.curve(Vector2(sgn * h * 0.4, h * 0.02), mid + Vector2(sgn * h * 0.36, h * 0.05), mid + Vector2(-sgn * h * 0.05, -h * 0.2), 9)
		O.brush(c, pts, 6.5 * s, Ink.encre(), 0.0, 0.8)
		O.brush(c, pts, 4.5 * s, bois["clair"], 0.0, 0.8)
	# Bouche au sommet et coulées de sève figée.
	var top := mid + Vector2(0, -h * 0.34)
	O.poly(c, Ink.oval(top, h * 0.07, h * 0.03, 12), Art.bc("ronge"))
	for i in 2:
		var x := (i - 0.5) * h * 0.1
		var drip := O.curve(top + Vector2(x, h * 0.01), top + Vector2(x * 1.6, h * 0.12), top + Vector2(x * 1.3, h * 0.22 + i * h * 0.05), 6)
		O.brush(c, drip, 3.4 * s, sv["ombre"], 0.0, 0.3)
		c.draw_circle(drip[-1], 2.4 * s, sv["ombre"])


## La fontaine claire : une vasque de racines et de pierres moussues, une eau qui monte en gerbe
## (le jet est dessiné par heart_live), fougères, nénuphars et myosotis.
static func _fountain(c: CanvasItem, h: float, s: float) -> void:
	var st: Dictionary = _m("ravive", "pierre")
	var mousse: Dictionary = _m("ravive", "fougere")
	var bois: Dictionary = _m("ravive", "bois")
	var base := Vector2(0, -h * 0.12)
	# Vasque : un anneau de pierres moussues et de racines, l'eau claire au milieu.
	var back := []
	var front := []
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		var p := base + Vector2(cos(a) * h * 0.36, sin(a) * h * 0.14)
		(back if sin(a) < 0.0 else front).append([p, a, i])
	for e in back:
		_stone(c, e[0], h * 0.09, st, mousse, e[2])
	O.poly(c, Ink.oval(base, h * 0.33, h * 0.12, 30), _m("ravive", "eau"))
	O.poly(c, Ink.oval(base + Vector2(-h * 0.08, -h * 0.03), h * 0.16, h * 0.04, 20), Color(_m("ravive", "eau_reflet"), 0.35))
	for e in front:
		_stone(c, e[0], h * 0.1, st, mousse, e[2])
	# Deux racines vivantes s'arquent au-dessus de la vasque.
	for sgn in [-1.0, 1.0]:
		var pts := O.curve(base + Vector2(sgn * h * 0.42, h * 0.08), base + Vector2(sgn * h * 0.4, -h * 0.5), base + Vector2(sgn * h * 0.08, -h * 0.42), 10)
		O.brush(c, pts, 6.0 * s, Ink.encre(), 0.0, 0.7)
		O.brush(c, pts, 4.2 * s, bois["ombre"], 0.0, 0.7)
		O.brush(c, pts.slice(0, 6), 1.6 * s, bois["clair"], 0.0, 0.7)
		for j in 3:
			var q: Vector2 = pts[3 + j * 2]
			Ink.part(c, Transform2D.IDENTITY, Ink.leaf(q, -PI * 0.5 + sgn * (0.6 + 0.3 * j), h * 0.1, h * 0.045, 0.05 * sgn), mousse, 1.0, 1.0, 0.6)
	# Fougères de part et d'autre, nénuphars et myosotis sur la mare.
	for sgn in [-1.0, 1.0]:
		var foot := Vector2(sgn * h * 0.62, h * 0.02)
		for j in 5:
			var a: float = -PI * 0.5 + (j - 2) * 0.42 + sgn * 0.2
			var tip: Vector2 = foot + Vector2.from_angle(a) * h * 0.26 + Vector2(0, h * 0.05)
			var rib := O.curve(foot, foot.lerp(tip, 0.5) + Vector2(0, -h * 0.05), tip, 7)
			O.brush(c, rib, 1.6 * s, mousse["ombre"], 0.0, 0.8)
			for q in range(1, 6):
				var d: Vector2 = (rib[q + 1] - rib[q - 1]).normalized()
				for t in [-1.0, 1.0]:
					O.poly(c, Ink.leaf(rib[q], (d.orthogonal() * t + d * 0.6).angle(), h * 0.045 * (1.0 - q / 7.0) + 2.0, h * 0.02), mousse["clair"] if (q + int(t)) % 2 == 0 else mousse["ombre"])
	for p in [Vector2(-0.5, 0.04), Vector2(0.45, 0.1), Vector2(0.2, 0.18)]:
		var q: Vector2 = p * h
		O.poly(c, Ink.oval(q, h * 0.06, h * 0.024, 14), _m("ravive", "feuillage")["clair"])
		O.flower(c, q + Vector2(0, -2.0 * s), h * 0.03, _m("ravive", "fleur_2"), _m("ravive", "fleur_coeur"))
	for i in 7:
		var q := Vector2(sin(i * 2.3) * h * 0.7, h * (0.12 + 0.05 * cos(i * 1.7)))
		O.flower(c, q, h * 0.02 + 1.0, _m("ravive", "fleur"), _m("ravive", "fleur_coeur"), i * 0.7)


static func _stone(c: CanvasItem, p: Vector2, r: float, st: Dictionary, mousse: Dictionary, i: int) -> void:
	Ink.part(c, Transform2D.IDENTITY, Ink.lumpy(p + Vector2(0, -r * 0.4), r, r * 0.7, 16, 0.12, 5.0, float(i)), st, 1.3, 1.0, 0.5)
	O.poly(c, Ink.lumpy(p + Vector2(0, -r * 0.95), r * 0.7, r * 0.22, 12, 0.3, 7.0, float(i)), mousse["clair"])


## Partie animée : flétri, celle des Cœurs (lueur de braise, braises qui montent) ; purifié, le jet
## de la fontaine (une gerbe d'eau claire qui monte et retombe), des gouttes, des rides sur la mare et
## un halo vert d'eau.
static func heart_live(c: CanvasItem, h, s: float) -> void:
	if h.state != "purifie":
		Lieux.heart_live(c, h.region, Vector2.ZERO, s, false, h.ratio(), h.t, h.state == "siege")
		return
	var hh := Lieux.HEART_H * s
	var t: float = h.t
	var eau: Color = _m("ravive", "eau_reflet")
	var halo: Color = _m("ravive", "seve")["clair"]
	var base := Vector2(0, -hh * 0.14)
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	c.draw_circle(base + Vector2(0, -hh * 0.3), hh * 0.75, Color(halo, 0.03 + 0.02 * b))
	c.draw_circle(base + Vector2(0, -hh * 0.3), hh * 0.42, Color(halo, 0.05 + 0.03 * b))
	# Rides sur la vasque.
	for i in 3:
		var u := fposmod(t * 0.45 + i / 3.0, 1.0)
		var pts := Ink.oval(base, hh * (0.05 + 0.26 * u), hh * (0.02 + 0.09 * u), 24)
		pts.append(pts[0])
		c.draw_polyline(pts, Color(eau, 0.5 * (1.0 - u)), 1.2 * s, true)
	# Le jet : une colonne qui ondule, coiffée d'une gerbe ; gouttes qui retombent en arc.
	var top := base + Vector2(sin(t * 2.1) * hh * 0.015, -hh * (0.62 + 0.03 * sin(t * 3.3)))
	var col := O.curve(base, base.lerp(top, 0.5) + Vector2(sin(t * 2.7) * hh * 0.02, 0), top, 8)
	O.brush(c, col, 7.0 * s, Color(_m("ravive", "eau"), 0.55), 0.3, 0.6)
	O.brush(c, col, 3.6 * s, Color(eau, 0.85), 0.2, 0.7)
	for i in 14:
		var u := fposmod(t * 0.7 + i / 14.0, 1.0)
		var a := -PI * 0.5 + (i % 7 - 3) * 0.32 + sin(i * 1.9) * 0.08
		var v := Vector2.from_angle(a) * hh * 0.55
		var p := top + v * u + Vector2(0, hh * 1.1 * u * u)
		if p.y > base.y + hh * 0.02:
			continue
		var al := sin(PI * minf(1.0, u * 1.3))
		c.draw_circle(p, 2.2 * s * (1.0 - u * 0.4), Color(eau, 0.8 * al))
	# Lueurs qui montent (comme les Cœurs purifiés), vert d'eau.
	for i in 5:
		var u := fposmod(t * 0.2 + i / 5.0, 1.0)
		var p := Vector2(sin(i * 2.3 + t * 0.9) * hh * 0.45, -hh * 0.5 - hh * 0.8 * u)
		c.draw_circle(p, 3.5 * s, Color(halo, 0.12 * sin(PI * u)))
		c.draw_circle(p, 1.4 * s, Color(halo.lightened(0.5), 0.8 * sin(PI * u)))


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


# --- Arène en décor (vague 3b A2, world_art/arenes_seve.gd) : l'étang du Saule ---
# draw_arena_floor et draw_arena_wall (l'ancienne ceinture de roseaux) ne servent plus qu'aux comparaisons.

const ArenesSeve = preload("res://scripts/world_art/arenes_seve.gd")


static func arena_baked(region: String) -> bool:
	return true


static func arena_pieces(region: String, a) -> Array:
	return arena_ring(a, 42, ArenesSeve.MUR_VARIANTES, [["r0", 0.0, 78.0]], 67)


static func arena_piece_keys(region: String) -> Array:
	return ArenesSeve.keys()


static func arena_piece_box(region: String, key: String) -> Rect2:
	return ArenesSeve.piece_box(key)


static func arena_piece(ci: CanvasItem, region: String, key: String, etat: String) -> void:
	ArenesSeve.piece(ci, key, etat)


static func arena_piece_live(ci: CanvasItem, region: String, key: String, a, i: int) -> void:
	ArenesSeve.piece_live(ci, key, a, i)


static func arena_floor(ci: CanvasItem, a, etat: String) -> void:
	ArenesSeve.ground(ci, a, etat)


static func arena_live(ci: CanvasItem, a) -> void:
	ArenesSeve.live(ci, a)
