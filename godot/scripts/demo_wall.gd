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
const CHUNK := 500.0
## Les tuiles à moins de PREPARE px de l'écran sont dessinées d'avance (une par image au plus).
const PREPARE := 900.0
## Au-delà de PREPARE + FORGET px de l'écran, l'image cuite d'une tuile est rendue.
const FORGET := 1500.0
## Profondeur du voile sur la région fermée, au-delà de la haie (px).
const VEIL := 520.0
## Battement du sceau et des baies après la fin de la démo (s).
const PULSE_PERIOD := 2.6
## La brèche au pied de la graine (finale_arena.gd › DESCENT).
const SEAL := Vector2(0.0, 150.0)
const SEAL_RADIUS := 58.0
## Ligne discrète écrite dans l'herbe près du sceau, après la fin de la démo (une seule).
const END_LINE := "La suite pousse dans le jeu complet." # i18n

var main
## Tuiles : [pièce, rang, rectangle, nœud ou null].
var _tiles: Array = []
var _base: Node2D
## Les dessins de la haie (Hedge), au-dessus de tous les voiles, triés par leur bas.
var _hedges: Node2D
var _glow: Node2D
var _seal: Node2D
var t := 0.0
var finished := false
## Ligne de fin : 0 (invisible) à 1.
var line_k := 0.0


func _ready() -> void:
	_base = Node2D.new()
	add_child(_base)
	_hedges = Node2D.new()
	_hedges.y_sort_enabled = true
	add_child(_hedges)
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
			_pump(Rect2(c - reach, reach * 2.0))
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
		node.hedge_layer = _hedges
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


## Cuit la haie des tuiles proches de l'écran (une cuisson à la fois), rend celle des tuiles lointaines.
func _pump(area: Rect2) -> void:
	if not Hedge.WorldEdge.can_bake():
		return
	var far := area.grow(FORGET)
	var busy := false
	for tile in _tiles:
		var node = tile[4]
		if node != null and node.hedge != null and node.hedge.baking:
			busy = true
	for tile in _tiles:
		var node = tile[4]
		if node == null or node.hedge == null:
			continue
		var h: Hedge = node.hedge
		var r: Rect2 = h.rect
		if r.intersects(area):
			if h.tex == null and not busy:
				h.bake()
				busy = true
		elif not r.intersects(far):
			h.forget()


## Cuissons de la haie en cours ou à faire autour de « area » (captures).
func pending(area: Rect2) -> int:
	var n := 0
	if not Hedge.WorldEdge.can_bake():
		return 0
	for tile in _tiles:
		var node = tile[4]
		if node != null and node.hedge != null and (node.hedge.baking or (node.hedge.tex == null and node.hedge.rect.intersects(area))):
			n += 1
	return n


## Attend que la haie autour de « area » soit cuite (captures).
func settle(area: Rect2, max_frames := 120) -> void:
	var n := 0
	while pending(area) > 0 and n < max_frames:
		_pump(area)
		await get_tree().process_frame
		n += 1
	await get_tree().process_frame


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
	## Le dessin de la haie (pas sur la couche de lumière).
	var hedge: Hedge
	var hedge_layer: Node2D

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
		# La haie elle-même : le mur de ronces du bout du monde (world_art/bord.gd), cuit à part.
		hedge = Hedge.new()
		hedge.items = Hedge.plan(piece, s0, s1, hash([salt, index]))
		hedge.rect = Hedge.bounds(hedge.items)
		# Posée par son bas : les images voisines se recouvrent dans l'ordre de l'écran.
		hedge.position = Vector2(hedge.rect.position.x, hedge.rect.end.y)
		hedge_layer.add_child(hedge)

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


## La haie dessinée comme le mur de ronces du bout du monde du Roncier (world_art/bord.gd, refonte du
## monde K) : ronces rampantes côté jouable, fourrés serrés hérissés de tiges, grands arceaux au fond,
## toujours flétrie (la démo s'arrête là). Cuite une fois en une image (SubViewport suréchantillonné SS
## fois, réduit ; même méthode que world_edge.gd), rendue quand la caméra s'éloigne, recuite au retour.
## Sans rendu (--headless) ou avec « -- --bord-direct », dessinée en direct (même dessin).
class Hedge extends Node2D:
	const Bord = preload("res://scripts/world_art/bord.gd")
	const BordBake = preload("res://scripts/world_bake/bord_bake.gd")
	const WorldEdge = preload("res://scripts/world_edge.gd")
	const SS := 2
	## Éléments [y du pied, sorte, pied, graine, hauteur], dans l'ordre de dessin (du haut de l'écran vers le bas).
	var items: Array = []
	## Rectangle du dessin (monde) ; le nœud est posé en bas à gauche du rectangle.
	var rect := Rect2()
	var tex: Texture2D
	var baking := false
	var _bytes := 0

	## Tirage des éléments d'un morceau [s0, s1] de la haie (« d » vers le côté fermé).
	static func plan(piece: Dictionary, s0: float, s1: float, seed: int) -> Array:
		var reach := Demo.wall_value("reach", 150.0)
		var r := RandomNumberGenerator.new()
		r.seed = seed
		var out: Array = []
		var len := s1 - s0
		# Ronces qui rampent sur le sol, du côté jouable.
		for k in int(len / 20.0):
			var q := Demo.wall_at(piece, r.randf_range(s0, s1), r.randf_range(-60.0, 15.0))
			out.append([q.y, "ronce_rampe", q, r.randi(), 0.0])
		# Fourrés serrés : la haie n'a pas de trou ; plus hauts vers le côté fermé.
		for k in int(len / 13.0):
			var d := r.randf_range(0.0, reach + 40.0)
			var q := Demo.wall_at(piece, r.randf_range(s0 - 10.0, s1 + 10.0), d)
			out.append([q.y, "ronce_masse", q, r.randi(), -580.0 + d * 1.5])
		# Grands arceaux au fond.
		for k in int(len / 90.0):
			var d := r.randf_range(reach * 0.5, reach + 90.0)
			var q := Demo.wall_at(piece, r.randf_range(s0, s1), d)
			out.append([q.y, "ronce_arceau", q, r.randi(), r.randf_range(110.0, 200.0)])
		out.sort_custom(func(x, y): return x[0] < y[0])
		return out

	## Rectangle qui contient tous les éléments (estimation large, monde).
	static func bounds(list: Array) -> Rect2:
		var rc := Rect2()
		var first := true
		for it in list:
			var p: Vector2 = it[2]
			var b: Rect2
			match it[1]:
				"ronce_rampe":
					b = Rect2(p - Vector2(100, 100), Vector2(200, 200))
				"ronce_masse":
					var sz: float = 140.0 * (1.0 + float(it[4]) / 1000.0)
					b = Rect2(p - Vector2(sz * 2.0, sz * 1.7), Vector2(sz * 4.0, sz * 2.5))
				_:
					var h: float = it[4]
					b = Rect2(p - Vector2(h * 1.05, h * 1.1), Vector2(h * 2.1, h * 1.25))
			rc = b if first else rc.merge(b)
			first = false
		return rc.grow(24.0)

	## Dessine les éléments en coordonnées du monde (le transform du dessin est posé par l'appelant).
	static func paint(ci: CanvasItem, list: Array) -> void:
		var r := RandomNumberGenerator.new()
		for it in list:
			r.seed = it[3]
			Bord.draw(ci, it[1], it[2], r, "ronce", "fletri", float(it[4]), Vector2.ZERO, float(it[4]) if it[1] == "ronce_arceau" else 1.0e9, 0)

	func _draw() -> void:
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(0, -rect.size.y), rect.size), false)
		elif not baking and not WorldEdge.can_bake():
			draw_set_transform(-rect.position - Vector2(0, rect.size.y))
			paint(self, items)
			draw_set_transform_matrix(Transform2D.IDENTITY)

	## Cuit le dessin en une image (une seule image de rendu).
	func bake() -> void:
		if baking or tex != null:
			return
		baking = true
		var size := Vector2i(ceili(rect.size.x * SS), ceili(rect.size.y * SS))
		var vp := SubViewport.new()
		vp.size = size
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var pn := PaintNode.new()
		pn.hedge = self
		vp.add_child(pn)
		add_child(vp)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not is_instance_valid(vp):
			baking = false
			return
		var img: Image = vp.get_texture().get_image() if vp.get_texture() != null else null
		vp.queue_free()
		baking = false
		if img == null or img.is_empty():
			return
		img.resize(maxi(1, size.x / SS), maxi(1, size.y / SS), Image.INTERPOLATE_BILINEAR)
		tex = ImageTexture.create_from_image(img)
		_bytes = img.get_data_size()
		BordBake.bytes += _bytes
		material = BordBake.material()
		queue_redraw()

	## Rend la mémoire de l'image (recuite si la caméra revient).
	func forget() -> void:
		if tex == null:
			return
		BordBake.bytes -= _bytes
		_bytes = 0
		tex = null
		queue_redraw()

	func _exit_tree() -> void:
		forget()


## Peint la haie dans le SubViewport de cuisson.
class PaintNode extends Node2D:
	var hedge: Hedge

	func _draw() -> void:
		draw_set_transform(-hedge.rect.position * Hedge.SS, 0.0, Vector2(Hedge.SS, Hedge.SS))
		Hedge.paint(self, hedge.items)



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
			var line := Loc.t(END_LINE)
			var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
			var o := Vector2(c.x - w / 2.0, c.y + r + 46.0 + (1.0 - k) * 8.0)
			draw_string_outline(font, o, line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 7, Color(0.93, 0.95, 0.82, 0.5 * k))
			draw_string(font, o, line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0.1, 0.14, 0.07, 0.9 * k))
