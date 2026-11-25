## Démo (jalon 12 E) : la ronce épaisse qui ferme les régions hors démo, et le sceau de la graine.
##
## - La haie suit les bords du monde jouable (demo.gd › wall_pieces) : les deux bords du secteur de
##   Ronce, de l'oasis jusqu'au mur de ronces du bout du monde (world_edge.gd), puis le cercle de
##   l'oasis devant les secteurs fermés. Même dessin que le mur du bout du monde (masses sombres,
##   tiges à épines, baies) : la démo s'arrête là où le roncier se referme.
##   Au-delà, la région fermée s'assombrit un peu : on la voit, on n'y va pas.
## - Dessin en tuiles d'un seul lot (DrawBatch), faites une fois quand la caméra s'en approche, comme
##   le bord du monde : loin de la haie, le coût est nul.
## - Le sceau : un nœud de ronces sur la brèche au pied de la graine (finale_arena.gd › DESCENT).
##   Après la fin de la démo (Demo.finished : la Mère-Ronce vaincue), une lumière de sève bat dessous,
##   et les baies de la haie luisent au même rythme. Sans pause, sans écran, sans texte à lire ; une
##   seule ligne discrète s'écrit dans l'herbe quand on s'approche du sceau.
extends Node2D

const Demo = preload("res://scripts/demo.gd")
const Regions = preload("res://scripts/regions.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

## Longueur d'une tuile le long de la haie (px).
const CHUNK := 700.0
## Les tuiles à moins de PREPARE px de l'écran sont dessinées d'avance (une par image au plus).
const PREPARE := 900.0
## Profondeur du voile sur la région fermée, au-delà de la haie (px).
const VEIL := 520.0
## Battement du sceau et des baies après la fin de la démo (s).
const PULSE_PERIOD := 2.6
## La brèche au pied de la graine (finale_arena.gd › DESCENT).
const SEAL := Vector2(0.0, 150.0)
const SEAL_RADIUS := 58.0
## Ligne discrète écrite dans l'herbe près du sceau, après la fin de la démo (une seule).
const END_LINE := "La suite pousse dans le jeu complet."

var main
## Tuiles : [pièce, rang, rectangle, nœud ou null].
var _tiles: Array = []
var _base: Node2D
var _glow: Node2D
var _seal: Node2D
var t := 0.0
var finished := false
## Ligne de fin : 0 (invisible) à 1.
var line_k := 0.0


func _ready() -> void:
	_base = Node2D.new()
	add_child(_base)
	_glow = Node2D.new()
	_glow.visible = false
	add_child(_glow)
	_seal = Seal.new()
	_seal.wall = self
	add_child(_seal)
	var pieces := Demo.wall_pieces()
	for pi in pieces.size():
		var piece: Dictionary = pieces[pi]
		var n := maxi(1, ceili(Demo.piece_length(piece) / CHUNK))
		for i in n:
			_tiles.append([piece, i, n, _tile_rect(piece, i, n), null, pi])


func _process(delta: float) -> void:
	t += delta
	finished = Demo.finished(Game.flags)
	var near_seal := false
	if main != null and is_instance_valid(main) and main.player != null:
		var p: Vector2 = main.player.position
		near_seal = finished and p.distance_to(SEAL) < Demo.wall_value("seal_reach", 260.0)
		if near_seal and not Game.flags.get(Demo.SEAL_SEEN, false):
			Game.flags[Demo.SEAL_SEEN] = true
		if main.camera != null:
			var view: Vector2 = get_viewport().get_visible_rect().size / main.camera.zoom
			var c: Vector2 = main.camera.get_screen_center_position()
			var reach: Vector2 = view * 0.5 + Vector2(PREPARE, PREPARE)
			ensure(Rect2(c - reach, reach * 2.0), 1)
	line_k = move_toward(line_k, 1.0 if near_seal else 0.0, delta / 1.2)
	_glow.visible = finished
	if finished:
		_glow.modulate.a = pulse()
	_seal.queue_redraw()


## Battement de la lumière (0 à 1) après la fin de la démo.
func pulse() -> float:
	return 0.35 + 0.65 * (0.5 + 0.5 * sin(t * TAU / PULSE_PERIOD))


## Dessine les tuiles qui touchent « area » et ne le sont pas encore, au plus « budget » (0 : toutes).
func ensure(area: Rect2, budget := 0) -> void:
	var made := 0
	for tile in _tiles:
		if tile[4] != null or not tile[3].intersects(area):
			continue
		var node := Tile.new()
		node.piece = tile[0]
		node.index = tile[1]
		node.count = tile[2]
		node.salt = tile[5]
		_base.add_child(node)
		var glow := Tile.new()
		glow.piece = tile[0]
		glow.index = tile[1]
		glow.count = tile[2]
		glow.salt = tile[5]
		glow.glow = true
		_glow.add_child(glow)
		tile[4] = node
		made += 1
		if budget > 0 and made >= budget:
			return


## Nombre de tuiles dessinées (tests).
func tile_total() -> int:
	return _base.get_child_count()


# --- Tuiles ---

static func _tile_rect(piece: Dictionary, i: int, n: int) -> Rect2:
	var len := Demo.piece_length(piece)
	var r := Rect2(Demo.wall_at(piece, len * i / n, 0.0), Vector2.ZERO)
	for k in 5:
		var s := len * (i + k / 4.0) / n
		for d in [-80.0, VEIL]:
			r = r.expand(Demo.wall_at(piece, s, d))
	return r.grow(60.0)


## Une tuile de la haie : son dessin se fait à la création, en un seul lot.
class Tile extends Node2D:
	var piece: Dictionary
	var index := 0
	var count := 1
	var salt := 0
	## Couche de lumière (baies et sève) qui bat après la fin de la démo.
	var glow := false
	var batch := DrawBatch.new()
	var rng := RandomNumberGenerator.new()
	var s0 := 0.0
	var s1 := 0.0

	func _ready() -> void:
		var len := Demo.piece_length(piece)
		s0 = len * index / count
		s1 = len * (index + 1) / count
		rng.seed = hash([salt, index, glow])
		if glow:
			_paint_glow()
		else:
			_paint()
		queue_redraw()

	## Le lot est gardé : la tuile se redessine à l'identique (le monde est caché puis remontré quand
	## l'arbre s'ouvre et se ferme).
	func _draw() -> void:
		if not batch.indices.is_empty():
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), batch.indices, batch.points, batch.colors)

	func P(s: float, d: float) -> Vector2:
		return Demo.wall_at(piece, s, d)

	func poly(pts: PackedVector2Array, col: Color) -> void:
		var w := PackedVector2Array()
		for p in pts:
			w.append(P(p.x, p.y))
		if w.size() >= 3:
			batch.draw_colored_polygon(w, col)

	func blob(s: float, d: float, rx: float, ry: float, col: Color, rot := 0.0, n := 12) -> void:
		var pts := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			var x := cos(a) * rx
			var y := sin(a) * ry
			pts.append(Vector2(s + x * cos(rot) - y * sin(rot), d + x * sin(rot) + y * cos(rot)))
		poly(pts, col)

	## Trait effilé (repère de la haie), comme world_edge_painter.gd › stroke.
	func stroke(path: PackedVector2Array, w0: float, w1: float, col: Color, shift := Vector2.ZERO) -> void:
		var n := path.size()
		if n < 2:
			return
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in n:
			var dir := Vector2.ZERO
			if i > 0:
				dir += (path[i] - path[i - 1]).normalized()
			if i < n - 1:
				dir += (path[i + 1] - path[i]).normalized()
			if dir.length_squared() < 0.0001:
				dir = Vector2.RIGHT
			var nm := dir.normalized().orthogonal()
			var w := lerpf(w0, w1, float(i) / (n - 1)) * 0.5
			left.append(P(path[i].x, path[i].y) + nm * w + shift)
			right.append(P(path[i].x, path[i].y) - nm * w + shift)
		right.reverse()
		left.append_array(right)
		batch.draw_colored_polygon(left, col)

	func wander(a: Vector2, to: Vector2, n: int, wob: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		var nm := (to - a).normalized().orthogonal()
		var phase := rng.randf() * TAU
		for i in n + 1:
			var k := float(i) / n
			out.append(a.lerp(to, k) + nm * sin(phase + k * 3.4) * wob * sin(k * PI) + nm * rng.randf_range(-wob, wob) * 0.25)
		return out

	func _paint() -> void:
		var reach := Demo.wall_value("reach", 150.0)
		# Voile sur la région fermée : de transparent contre la haie à sombre au loin.
		var step := 70.0
		var s := s0
		var dark := Color(0.035, 0.02, 0.025, 0.0)
		while s < s1 - 0.01:
			var e := minf(s + step, s1)
			for band in [[reach * 0.5, reach + 120.0, 0.0, 0.42], [reach + 120.0, VEIL, 0.42, 0.55]]:
				var c0 := Color(dark, band[2])
				var c1 := Color(dark, band[3])
				batch.draw_primitive(PackedVector2Array([P(s, band[0]), P(e, band[0]), P(e, band[1]), P(s, band[1])]), PackedColorArray([c0, c0, c1, c1]))
			s = e
		var len := s1 - s0
		# Masses sombres : la haie n'a pas de trou.
		for k in int(len / 34.0):
			var u := rng.randf_range(s0 - 20.0, s1 + 20.0)
			var d := rng.randf_range(10.0, reach)
			var r := rng.randf_range(38.0, 72.0)
			blob(u, d, r * 1.3, r, Color(0.075, 0.04, 0.05, 0.92), rng.randf() * PI)
		# Tiges à épines, couchées dans le sens de la haie, plus serrées contre le côté jouable.
		for k in int(len / 16.0):
			var u := rng.randf_range(s0 - 30.0, s1 + 10.0)
			var d := reach * pow(rng.randf(), 1.4) - 18.0
			var ang := rng.randf_range(-0.7, 0.7) + (PI if rng.randf() < 0.5 else 0.0)
			var l := rng.randf_range(110.0, 230.0)
			var path := wander(Vector2(u, d), Vector2(u, d) + Vector2.from_angle(ang) * l, 6, l * 0.2)
			# La haie déborde à peine sur le côté jouable.
			for i in path.size():
				path[i].y = clampf(path[i].y, -22.0, reach + 50.0)
			var w0 := rng.randf_range(8.0, 13.0)
			stroke(path, w0 + 6.0, 4.0, Color(0.03, 0.015, 0.02, 0.75), Vector2(3, 5))
			stroke(path, w0, w0 * 0.3, Color(0.17, 0.085, 0.1))
			stroke(path, w0 * 0.4, 1.0, Color(0.3, 0.15, 0.17, 0.8), Vector2(-w0 * 0.18, -w0 * 0.18))
			for i in range(1, path.size() - 1):
				var dir := (path[i + 1] - path[i - 1]).normalized()
				var nm := dir.orthogonal()
				for sgn in [-1.0, 1.0]:
					if rng.randf() < 0.75:
						var base: Vector2 = path[i]
						var tip: Vector2 = base + (nm * sgn + dir * 0.6).normalized() * rng.randf_range(12.0, 22.0)
						poly(PackedVector2Array([base - dir * 4.0, base + dir * 4.0, tip]), Color(0.36, 0.19, 0.2))
			if rng.randf() < 0.3:
				var tip2: Vector2 = path[path.size() - 1]
				blob(tip2.x, tip2.y, 5.5, 5.5, Color(0.72, 0.17, 0.2), 0.0, 8)
				blob(tip2.x - 1.5, tip2.y - 1.5, 1.8, 1.8, Color(1, 0.7, 0.7, 0.7), 0.0, 6)

	## Lumière qui bat après la fin de la démo : des baies qui luisent dans la haie.
	func _paint_glow() -> void:
		var reach := Demo.wall_value("reach", 150.0)
		var col := Color(0.95, 0.42, 0.36)
		for k in int((s1 - s0) / 60.0):
			var u := rng.randf_range(s0, s1)
			var d := rng.randf_range(0.0, reach * 0.8)
			blob(u, d, 22.0, 22.0, Color(col, 0.1), 0.0, 12)
			blob(u, d, 9.0, 9.0, Color(col, 0.3), 0.0, 10)
			blob(u, d, 4.0, 4.0, Color(1.0, 0.8, 0.7, 0.85), 0.0, 8)


## Le sceau de la graine : un nœud de ronces sur la brèche ; une lumière de sève bat dessous après la
## fin de la démo, et une ligne s'écrit dans l'herbe quand on s'en approche.
class Seal extends Node2D:
	var wall

	func _draw() -> void:
		var m = wall.main
		if m != null and is_instance_valid(m) and m.player != null and m.player.position.distance_to(SEAL) > 1500.0:
			return
		var c := SEAL
		var r := SEAL_RADIUS
		var lit: float = wall.pulse() if wall.finished else 0.0
		draw_colored_polygon(Art.ellipse(c, r * 1.3, r * 0.64, 24), Color(0.05, 0.03, 0.03, 0.55))
		if lit > 0.0:
			var sap := Art.ec("seve", "clair")
			draw_colored_polygon(Art.ellipse(c, r * 1.6, r * 0.8, 28), Color(sap, 0.1 * lit))
			draw_colored_polygon(Art.ellipse(c, r * 1.05, r * 0.5, 24), Color(sap, 0.28 * lit))
		draw_colored_polygon(Art.ellipse(c, r * 0.95, r * 0.42, 24), Color(0.02, 0.015, 0.012))
		if lit > 0.0:
			draw_colored_polygon(Art.ellipse(c + Vector2(0, 2), r * 0.55, r * 0.18, 18), Color(Art.ec("seve", "clair"), 0.55 * lit))
		# Tiges de ronce croisées sur la brèche, épines vers le dehors.
		for i in 7:
			var a := TAU * i / 7.0 + 0.3
			var from := c + Vector2(cos(a) * r * 1.35, sin(a) * r * 0.66)
			var to := c + Vector2(cos(a + 2.6) * r * 1.2, sin(a + 2.6) * r * 0.58)
			var mid := (from + to) * 0.5 + Vector2(0, -6.0)
			var pts := PackedVector2Array([from, mid.lerp(from, 0.3), mid, mid.lerp(to, 0.3), to])
			draw_polyline(pts, Color(0.03, 0.015, 0.02, 0.8), 9.0, true)
			draw_polyline(pts, Color(0.22, 0.11, 0.12), 6.0, true)
			for k in range(1, pts.size() - 1):
				var dir := (pts[k + 1] - pts[k - 1]).normalized()
				var tip := pts[k] + (dir.orthogonal() * (1.0 if k % 2 == 0 else -1.0) + dir * 0.5).normalized() * 11.0
				draw_colored_polygon(PackedVector2Array([pts[k] - dir * 3.0, pts[k] + dir * 3.0, tip]), Color(0.38, 0.2, 0.21))
		# Bourgeon fermé au centre.
		draw_colored_polygon(Art.ellipse(c + Vector2(0, -4), 10.0, 13.0, 14), Color(0.45, 0.16, 0.18))
		draw_colored_polygon(Art.ellipse(c + Vector2(-2, -7), 3.5, 5.0, 10), Color(1.0, 0.75, 0.7, 0.35 + 0.5 * lit))
		if wall.line_k > 0.0:
			var k: float = wall.line_k
			var font := UiTheme.font()
			var size_px := 22
			var w := font.get_string_size(END_LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
			var o := Vector2(c.x - w / 2.0, c.y + r + 46.0 + (1.0 - k) * 8.0)
			draw_string_outline(font, o, END_LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 7, Color(0.93, 0.95, 0.82, 0.5 * k))
			draw_string(font, o, END_LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0.1, 0.14, 0.07, 0.9 * k))
