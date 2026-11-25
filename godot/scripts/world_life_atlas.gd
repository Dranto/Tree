## Monde vivant (refonte du monde, vague 1 V) : images cuites de la petite vie du monde.
##
## Feuilles, cailloux, éclats, spores, plumes, gouttes, cendre des pas, fleurs des pas, rides et
## éclaboussures, et la faune ambiante (papillon, oiseau, grenouille, luciole) sont dessinés une fois par
## le code au démarrage, ×SCALE et lissés (dessinés SS fois plus grands dans un SubViewport, puis réduits),
## dans un seul atlas. En jeu, world_life.gd n'envoie que des quadrilatères texturés de cet atlas, tous
## dans un seul appel de rendu par calque.
##
## Les images sont en tons de gris (le blanc prend la teinte donnée au dessin, l'encre reste sombre) :
## une même feuille sert à toutes les régions, teintée par Art.MONDE › vivant. Alpha prémultiplié (rendu
## d'un SubViewport transparent) : voir shaders/world_life.gdshader.
##
## Aucun texte, aucun chiffre de jeu : apparence seulement. Sans rendu (--headless), pas d'atlas : rien
## n'est dessiné, la logique tourne quand même.
extends RefCounted

## Pixels de l'atlas par pixel du monde, et suréchantillonnage du dessin.
const SCALE := 2
const SS := 2
## Côté d'une case, en pixels du monde (centre = point d'ancrage).
const CELL := 40
const COLS := 8

## Images, dans l'ordre de l'atlas.
const FRAMES := [
	"feuille", "petale", "caillou", "eclat", "spore", "plume", "sciure", "goutte",
	"cendre", "fleur_pas", "ride", "eclabous", "lueur",
	"papillon_0", "papillon_1", "papillon_2", "papillon_3",
	"oiseau_sol_0", "oiseau_sol_1", "oiseau_vol_0", "oiseau_vol_1", "oiseau_vol_2", "oiseau_vol_3",
	"grenouille_0", "grenouille_1", "grenouille_2", "luciole",
]

static var tex: ImageTexture = null
static var bytes := 0
static var bake_usec := 0
static var _rects := {}
static var _baking := false


## Rectangle (pixels de l'atlas) d'une image.
static func rect(frame: String) -> Rect2:
	if _rects.is_empty():
		for i in FRAMES.size():
			var px := CELL * SCALE
			_rects[FRAMES[i]] = Rect2((i % COLS) * px, (i / COLS) * px, px, px)
	return _rects.get(frame, Rect2())


static func ready() -> bool:
	return tex != null


## Cuit l'atlas (une fois par partie) : un SubViewport rendu une fois, lu à l'image suivante.
static func bake(host: Node) -> void:
	if tex != null or _baking or DisplayServer.get_name() == "headless":
		return
	_baking = true
	var t0 := Time.get_ticks_usec()
	var rows := int(ceil(FRAMES.size() / float(COLS)))
	var k := SCALE * SS
	var vp := SubViewport.new()
	vp.size = Vector2i(COLS * CELL * k, rows * CELL * k)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	var painter := Painter.new()
	painter.k = k
	vp.add_child(painter)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image() if vp.get_texture() != null else null
	vp.queue_free()
	_baking = false
	if img == null or img.is_empty():
		return
	img.resize(img.get_width() / SS, img.get_height() / SS, Image.INTERPOLATE_TRILINEAR)
	img.generate_mipmaps()
	tex = ImageTexture.create_from_image(img)
	bytes = img.get_data_size()
	bake_usec = Time.get_ticks_usec() - t0


## Dessine chaque image dans sa case (coordonnées du monde, ×k).
class Painter extends Node2D:
	var k := 4

	func _draw() -> void:
		for i in FRAMES.size():
			var c := Vector2((i % COLS) + 0.5, (i / COLS) + 0.5) * CELL * k
			draw_set_transform(c, 0.0, Vector2(k, k))
			_frame(FRAMES[i])
		draw_set_transform(Vector2.ZERO)

	func _frame(f: String) -> void:
		var ink: Color = Art.mc("commun", "", "encre_decor")
		var w := Color(1, 1, 1)
		var g1 := Color(0.82, 0.82, 0.82)
		var g2 := Color(0.62, 0.62, 0.62)
		match f:
			"feuille":
				# Feuille pointue, nervure claire, tournée vers la droite (le dessin la fait tourner).
				var pts := _leaf(Vector2(-7, 0), 14.0, 0.0, 0.36)
				draw_colored_polygon(_grow(pts, Vector2(-0.0, 0.0), 0.9), Color(ink, 0.7))
				draw_colored_polygon(pts, g1)
				draw_colored_polygon(_leaf(Vector2(-7, -0.6), 13.0, -0.05, 0.2), w)
				draw_line(Vector2(-7, 0), Vector2(6, 0), Color(g2, 0.9), 0.7)
			"petale":
				draw_colored_polygon(Art.ellipse(Vector2.ZERO, 5.0, 3.0, 14), g1)
				draw_colored_polygon(Art.ellipse(Vector2(-0.8, -0.6), 3.6, 2.0, 12), w)
			"caillou":
				var p := PackedVector2Array([Vector2(-4.5, 1.5), Vector2(-3, -3), Vector2(1.5, -4), Vector2(4.8, -0.5), Vector2(3.5, 3), Vector2(-1.5, 3.8)])
				draw_colored_polygon(_grow(p, Vector2.ZERO, 0.8), Color(ink, 0.8))
				draw_colored_polygon(p, g2)
				draw_colored_polygon(PackedVector2Array([Vector2(-3, -2.5), Vector2(1.3, -3.4), Vector2(0.5, -0.8), Vector2(-2.6, 0.2)]), w)
			"eclat":
				var p := PackedVector2Array([Vector2(0, -7), Vector2(2.6, -1), Vector2(0.6, 6), Vector2(-2.4, 0.5)])
				draw_colored_polygon(_grow(p, Vector2.ZERO, 0.7), Color(ink, 0.6))
				draw_colored_polygon(p, g1)
				draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(2.6, -1), Vector2(0.2, 0.0)]), w)
			"spore":
				for i in 5:
					draw_circle(Vector2.ZERO, 6.0 - i * 1.0, Color(w, 0.14 + 0.12 * i))
				draw_circle(Vector2(-0.6, -0.6), 1.4, w)
			"plume":
				draw_line(Vector2(-8, 1), Vector2(8, -1), Color(g2, 1.0), 0.8)
				var p := PackedVector2Array()
				for i in 9:
					var u := i / 8.0
					p.append(Vector2(-7 + 15 * u, -1.0 - 3.2 * sin(u * PI)))
				for i in 9:
					var u := 1.0 - i / 8.0
					p.append(Vector2(-7 + 15 * u, 1.5 + 2.4 * sin(u * PI)))
				draw_colored_polygon(p, Color(w, 0.92))
				draw_line(Vector2(-8, 0.6), Vector2(7, -0.4), Color(g2, 0.9), 0.6)
			"sciure":
				draw_colored_polygon(PackedVector2Array([Vector2(-3.5, -1), Vector2(3, -2), Vector2(3.6, 1.2), Vector2(-2.8, 1.8)]), g1)
				draw_line(Vector2(-3, 0), Vector2(3, -0.6), Color(g2, 0.9), 0.6)
			"goutte":
				var p := PackedVector2Array()
				for i in 14:
					var a := TAU * i / 14.0
					var r := 3.2 * (1.0 + 0.55 * maxf(0.0, -sin(a)))
					p.append(Vector2(cos(a) * 3.0, sin(a) * r + 0.8))
				draw_colored_polygon(p, Color(w, 0.85))
				draw_circle(Vector2(-1, -0.5), 0.9, w)
			"cendre":
				# Empreinte de cendre : une tache ovale à bords doux, quelques grains.
				for i in 4:
					draw_colored_polygon(Art.ellipse(Vector2.ZERO, 9.0 - i * 1.8, 4.6 - i * 0.9, 18), Color(w, 0.18 + 0.12 * i))
				for q in [Vector2(-7, 2), Vector2(6, -2), Vector2(9, 1.5), Vector2(-9, -1)]:
					draw_circle(q, 0.9, Color(w, 0.7))
			"fleur_pas":
				# Petite fleur de cinq pétales posée à plat (vue de trois quarts), coeur sombre.
				for i in 5:
					var a := TAU * i / 5.0 - PI / 2.0
					var c := Vector2(cos(a) * 3.2, sin(a) * 2.0)
					draw_colored_polygon(Art.ellipse(c, 2.6, 1.7, 10), Color(ink, 0.35))
				for i in 5:
					var a := TAU * i / 5.0 - PI / 2.0
					draw_colored_polygon(Art.ellipse(Vector2(cos(a) * 3.0, sin(a) * 1.8 - 0.3), 2.2, 1.4, 10), w)
				draw_circle(Vector2(0, -0.3), 1.3, ink.lightened(0.25))
				# Deux feuilles sous la fleur.
				draw_colored_polygon(_leaf(Vector2(2.0, 2.0), 5.0, 0.35, 0.34), g2)
				draw_colored_polygon(_leaf(Vector2(-2.0, 2.0), 5.0, PI - 0.35, 0.34), g2)
			"ride":
				var ring := Art.ellipse(Vector2.ZERO, 16.0, 8.0, 36)
				ring.append(ring[0])
				draw_polyline(ring, Color(w, 0.9), 1.3)
				var ring2 := Art.ellipse(Vector2.ZERO, 11.0, 5.5, 30)
				ring2.append(ring2[0])
				draw_polyline(ring2, Color(w, 0.45), 0.9)
			"eclabous":
				for i in 7:
					var a := PI + PI * i / 6.0
					var q := Vector2(cos(a) * 9.0, sin(a) * 9.0 * 0.9)
					draw_circle(q, 1.8 - absf(i - 3) * 0.25, Color(w, 0.9))
					draw_line(q * 0.4, q * 0.82, Color(w, 0.6), 1.0)
				var ring := Art.ellipse(Vector2(0, 1), 8.0, 3.2, 24)
				ring.append(ring[0])
				draw_polyline(ring, Color(w, 0.8), 1.0)
			"lueur":
				for i in 8:
					draw_circle(Vector2.ZERO, 16.0 - i * 2.0, Color(w, 0.05 + 0.03 * i))
			"luciole":
				for i in 6:
					draw_circle(Vector2.ZERO, 7.0 - i * 1.1, Color(w, 0.08 + 0.1 * i))
				draw_circle(Vector2.ZERO, 1.3, w)
			_:
				if f.begins_with("papillon_"):
					_butterfly(int(f.get_slice("_", 1)), ink, w, g1, g2)
				elif f.begins_with("oiseau_sol_"):
					_bird_ground(int(f.get_slice("_", 2)), ink, w, g1, g2)
				elif f.begins_with("oiseau_vol_"):
					_bird_fly(int(f.get_slice("_", 2)), ink, w, g1, g2)
				elif f.begins_with("grenouille_"):
					_frog(int(f.get_slice("_", 1)), ink, w, g1, g2)

	## Papillon vu de trois quarts : ailes qui battent (ouverture de l'image 0, ouvertes, à 3, fermées).
	func _butterfly(i: int, ink: Color, w: Color, g1: Color, g2: Color) -> void:
		var open: float = [1.0, 0.62, 0.22, 0.6][i]
		for side in [-1.0, 1.0]:
			var up := PackedVector2Array([Vector2(0, -0.5), Vector2(side * 9.0 * open, -7.5), Vector2(side * 10.5 * open, -2.5), Vector2(side * 3.0 * open, 0.5)])
			var lo := PackedVector2Array([Vector2(0, 0.5), Vector2(side * 7.0 * open, 1.0), Vector2(side * 5.0 * open, 6.0), Vector2(side * 1.0, 3.0)])
			draw_colored_polygon(_grow(up, Vector2.ZERO, 0.8), Color(ink, 0.8))
			draw_colored_polygon(_grow(lo, Vector2.ZERO, 0.8), Color(ink, 0.8))
			draw_colored_polygon(up, w)
			draw_colored_polygon(lo, g1)
			draw_circle(Vector2(side * 6.0 * open, -4.0), 1.1 * open + 0.3, Color(ink, 0.55))
		draw_line(Vector2(0, -3.5), Vector2(0, 4.5), ink, 1.4)
		draw_line(Vector2(0, -3.5), Vector2(-2.0, -6.5), Color(ink, 0.8), 0.6)
		draw_line(Vector2(0, -3.5), Vector2(2.0, -6.5), Color(ink, 0.8), 0.6)

	## Petit oiseau posé, tourné vers la droite : tête haute (0) ou qui picore (1).
	func _bird_ground(i: int, ink: Color, w: Color, g1: Color, g2: Color) -> void:
		draw_colored_polygon(Art.ellipse(Vector2(0, 7.5), 6.0, 1.6, 14), Color(Art.c("ombre"), 0.25))
		var body := Art.ellipse(Vector2(-1, 1.5), 6.5, 4.6, 18)
		draw_colored_polygon(_grow(body, Vector2(-1, 1.5), 0.9), ink)
		draw_colored_polygon(body, g1)
		draw_colored_polygon(Art.ellipse(Vector2(-0.5, 3.0), 4.5, 2.6, 14), w)
		# Queue.
		draw_colored_polygon(PackedVector2Array([Vector2(-6.5, 0), Vector2(-11, -2.5), Vector2(-10.5, 1.0), Vector2(-6, 2.5)]), g2)
		var head := Vector2(5.0, -3.2) if i == 0 else Vector2(6.2, 2.4)
		draw_circle(head, 3.4, ink)
		draw_circle(head, 2.7, g1)
		var beak := head + (Vector2(3.6, 0.4) if i == 0 else Vector2(2.6, 2.6))
		draw_colored_polygon(PackedVector2Array([head + Vector2(1.8, -0.9), beak, head + Vector2(1.6, 1.0)]), ink.lightened(0.3))
		draw_circle(head + Vector2(0.9, -0.7), 0.8, ink)
		draw_line(Vector2(0, 6), Vector2(-0.5, 7.5), ink, 0.8)
		draw_line(Vector2(2, 6), Vector2(2.2, 7.5), ink, 0.8)

	## Oiseau en vol, vu de trois quarts : battement d'ailes en quatre images.
	func _bird_fly(i: int, ink: Color, w: Color, g1: Color, g2: Color) -> void:
		var lift: float = [-7.0, -2.0, 4.0, -1.0][i]
		var body := Art.ellipse(Vector2(0, 0), 6.0, 3.2, 16)
		for side in [-1.0, 1.0]:
			var tip := Vector2(-2.0 + side * 1.0, lift * (1.0 if side > 0 else 0.8) - 1.0) + Vector2(0, side * 1.0)
			var wing := PackedVector2Array([Vector2(-3, -0.5), tip + Vector2(-6, 0), tip + Vector2(2, -1), Vector2(3, -0.5)])
			if side < 0:
				wing = PackedVector2Array([Vector2(-3, 0.5), Vector2(-3, 0.5) + Vector2(-4, lift * 0.6 + 2.0), Vector2(1, lift * 0.6 + 3.0), Vector2(2, 0.5)])
			draw_colored_polygon(_grow(wing, Vector2.ZERO, 0.8), Color(ink, 0.85))
			draw_colored_polygon(wing, g1 if side > 0 else g2)
		draw_colored_polygon(_grow(body, Vector2.ZERO, 0.8), ink)
		draw_colored_polygon(body, w)
		draw_colored_polygon(PackedVector2Array([Vector2(-5.5, -0.5), Vector2(-10, -2), Vector2(-9.5, 1.5), Vector2(-5.5, 1.0)]), g2)
		draw_circle(Vector2(5.5, -1.2), 2.6, ink)
		draw_circle(Vector2(5.5, -1.2), 2.0, g1)
		draw_colored_polygon(PackedVector2Array([Vector2(7, -2), Vector2(10, -1), Vector2(7, -0.4)]), ink.lightened(0.3))

	## Grenouille : assise (0), qui s'élance (1), en l'air pattes tendues (2).
	func _frog(i: int, ink: Color, w: Color, g1: Color, g2: Color) -> void:
		draw_colored_polygon(Art.ellipse(Vector2(0, 6.5), 6.5, 1.8, 14), Color(Art.c("ombre"), 0.25 if i == 0 else 0.0))
		var stretch: float = [1.0, 1.15, 1.35][i]
		var body := Art.ellipse(Vector2(0, 1.0), 6.0 * stretch, 4.4 / stretch, 18)
		draw_colored_polygon(_grow(body, Vector2(0, 1), 0.9), ink)
		draw_colored_polygon(body, g1)
		draw_colored_polygon(Art.ellipse(Vector2(1.0, 2.5), 4.0 * stretch, 2.0, 14), w)
		if i == 0:
			for side in [-1.0, 1.0]:
				draw_colored_polygon(Art.ellipse(Vector2(side * 5.5 - 1.0, 4.5), 3.0, 1.8, 10), g2)
		else:
			draw_line(Vector2(-5 * stretch, 3), Vector2(-10 * stretch, 6), ink, 1.6)
			draw_line(Vector2(-5 * stretch, 3), Vector2(-10 * stretch, 6), g2, 1.0)
		for side in [-1.0, 1.0]:
			var eye := Vector2(3.5 * stretch + side * 1.8, -2.6)
			draw_circle(eye, 1.9, ink)
			draw_circle(eye, 1.4, w)
			draw_circle(eye + Vector2(0.3, 0.2), 0.7, ink)

	static func _leaf(p: Vector2, l: float, a: float, wk: float) -> PackedVector2Array:
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var pts := PackedVector2Array()
		for i in 7:
			var u := i / 6.0
			pts.append(p + d * l * u + n * l * wk * sin(u * PI))
		for i in range(5, 0, -1):
			var u := i / 6.0
			pts.append(p + d * l * u - n * l * wk * sin(u * PI))
		return pts

	## Contour : le polygone agrandi de « by » autour de « c ».
	static func _grow(pts: PackedVector2Array, c: Vector2, by: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q in pts:
			var d := q - c
			out.append(q + (d.normalized() * by if d.length() > 0.01 else Vector2.ZERO))
		return out
