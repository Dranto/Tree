## Le bord du monde : au-delà de ± Regions.WORLD_HALF, le paysage propre à chaque région (refonte du
## monde, vague 3 K, style « Paysages d'herbier ») : mur de ronces, eaux du marais, falaise sur une mer
## de nuages, vallée vue d'en haut, ciel doré des falaises de verre, futaie de pierre. Le sol de la région
## se défait vers le bord (pas de coupure droite), les coins sont arrondis, et entre deux régions le bord
## suit les langues de la frontière (world_art/frontieres.gd). Où va quoi : world_edge_painter.gd ;
## les dessins : world_art/bord.gd.
##
## Tuiles (world_edge_painter.gd) : chacune a un fond et un voile (lots de triangles aux couleurs de
## sommet, dessinés une fois) et deux bandes de décor CUITES : dessinées une fois par le code dans un
## SubViewport (suréchantillonné SS fois, réduit), puis montrées comme une seule image (même méthode que
## world_bake/lieux_bake.gd). La bande proche est cuite à pleine résolution, la lointaine (sous le
## voile) à moitié. Une tuile est préparée quand la caméra en approche (PREPARE), une par image ; au-delà
## du budget mémoire, les tuiles qui n'ont pas servi depuis UNUSED_FRAMES images sont rendues.
##
## Le bord reverdit à la purification (décision du jalon 10) : quand le Cœur d'une région est purifié,
## les tuiles où elle est présente sont redessinées dans l'état « ravivé » (couleurs, fleurs, lumière de la
## région) et l'image nouvelle apparaît en fondu sur LIFE_TIME secondes par-dessus l'ancienne.
##
## Sans rendu (--headless) ou avec « -- --bord-direct », le décor est dessiné en direct (même dessin).
##
## La carte du monde (world_map.gd) dessine le même bord, réduit, dans la marge de son cadre
## (draw_map_frame) : le fond en lot, le décor en formes simples cuites une fois.
extends Node2D

const Painter = preload("res://scripts/world_edge_painter.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")
const Regions = preload("res://scripts/regions.gd")
const BordBake = preload("res://scripts/world_bake/bord_bake.gd")

## Les tuiles à moins de PREPARE px de l'écran sont préparées d'avance (une par image au plus).
const PREPARE := 1100.0
## Durée (s) du reverdissement du bord.
const LIFE_TIME := 3.0
## Marge de la carte du monde, en part du monde : le bord y est montré sur cette profondeur.
const MAP_MARGIN := 0.09
## Résolution de cuisson de chaque bande (pixels de l'image par pixel du monde) et suréchantillonnage.
const BAKE_SCALE := [1.0, 0.5]
const SS := 2
## Mémoire des images gardées, et délai avant de rendre une tuile qui ne sert plus.
const BUDGET := 72 * 1024 * 1024
const UNUSED_FRAMES := 240
## Cuissons en cours au plus en même temps (en jeu ; plus pour les captures).
const MAX_BAKING := 1
## Une cuisson s'étale sur plusieurs images : SLICE_KINDS sortes tirées, puis des éléments pour
## SLICE_COST ms estimées par image (world_edge_painter.gd › COST). Découpage fixe, pas au temps : la
## même scène donne les mêmes images au même moment sur toutes les machines (tests visuels).
const SLICE_KINDS := 8
const SLICE_COST := 4.0
## Côté de l'image du décor de la carte (px).
const MAP_TEX := 1400

## « -- --bord-direct » : décor dessiné en direct, sans cuisson (comparaisons, banc).
static var baking := true
static var _configured := false
## États des régions (région → purifiée), vus par la carte.
static var current_states: Dictionary = {}
static var _map_cache: Dictionary = {}
static var _map_tex: Dictionary = {}

var main
var _base_layer: Node2D
var _decor_layer: Node2D
var _veil_layer: Node2D
## Clé (côté × 100 + rang) → Tile.
var _tiles: Dictionary = {}
var _states: Dictionary = {}
var _fading: Dictionary = {}
var _queue: Array = []
var _baking := 0
## Cuissons en même temps : MAX_BAKING en jeu, plus pour les captures (ensure sans budget).
var _max_baking := MAX_BAKING


static func configure() -> void:
	if _configured:
		return
	_configured = true
	for a in OS.get_cmdline_user_args():
		if a == "--bord-direct":
			baking = false


static func can_bake() -> bool:
	configure()
	return baking and DisplayServer.get_name() != "headless"


func _ready() -> void:
	configure()
	_base_layer = Node2D.new()
	add_child(_base_layer)
	_decor_layer = Node2D.new()
	# Les bandes se recouvrent : la plus basse à l'écran passe devant (vue de trois quarts).
	_decor_layer.y_sort_enabled = true
	add_child(_decor_layer)
	_veil_layer = Node2D.new()
	add_child(_veil_layer)


func _exit_tree() -> void:
	for key in _tiles.keys():
		_free_tile(key)
	_queue.clear()


func _process(delta: float) -> void:
	if main == null or not is_instance_valid(main) or main.camera == null:
		return
	_sync_states()
	_advance(delta)
	_pump()
	var under: bool = main.underground()
	visible = not under
	if under:
		return
	var half: float = main.world_half
	var view := get_viewport().get_visible_rect().size
	var c: Vector2 = main.camera.get_screen_center_position()
	var reach := view * 0.5 + Vector2(PREPARE, PREPARE)
	# Tout l'écran (marge comprise) dans le monde, loin du bord : rien à préparer.
	if absf(c.x) + reach.x <= half - Painter.INSET - 200.0 and absf(c.y) + reach.y <= half - Painter.INSET - 200.0:
		_trim()
		return
	ensure(Rect2(c - reach, reach * 2.0), 1)
	_trim()


## Prépare les tuiles qui touchent « area » (coordonnées du monde), au plus « budget » par appel
## (0 : toutes, et leur décor se dessine en direct tant qu'il n'est pas cuit : captures et tests).
func ensure(area: Rect2, budget := 0) -> void:
	_sync_states()
	if budget == 0:
		_max_baking = 4
	var made := 0
	var now := Engine.get_process_frames()
	for side in 4:
		for i in Painter.chunk_count():
			var key := side * 100 + i
			var near_r := Painter.band_rect(side, i, Painter.NEAR)
			var far_r := Painter.band_rect(side, i, Painter.FAR)
			if not near_r.intersects(area) and not far_r.intersects(area):
				continue
			var t: Tile = _tiles.get(key)
			if t == null:
				if budget > 0 and made >= budget:
					continue
				t = _make_tile(side, i, budget == 0)
				made += 1
			t.used = now
			if t.far == null and far_r.intersects(area):
				if budget > 0 and made >= budget:
					continue
				t.far = _slot(_decor_layer, far_r.position)
				t.far.push(_decor_variant(t, Painter.FAR, budget == 0), false)
				made += 1
	_pump()


## Nombre de cuissons en attente ou en cours (les captures attendent qu'il retombe à 0).
func pending() -> int:
	return _queue.size() + _baking


## Attend que toutes les cuissons soient finies (captures).
func settle(max_frames := 120) -> void:
	var n := 0
	while pending() > 0 and n < max_frames:
		await get_tree().process_frame
		n += 1
	await get_tree().process_frame


## Nombre de tuiles préparées (tests).
func chunk_total() -> int:
	return _tiles.size()


func _make_tile(side: int, i: int, direct: bool) -> Tile:
	var t := Tile.new()
	t.side = side
	t.index = i
	t.state = Painter.state_key(side, i, _states)
	t.base = _slot(_base_layer, Vector2.ZERO)
	t.base.push(_mesh_variant(t, false), false)
	t.near = _slot(_decor_layer, Painter.band_rect(side, i, Painter.NEAR).position)
	t.near.push(_decor_variant(t, Painter.NEAR, direct), false)
	t.veil = _slot(_veil_layer, Vector2.ZERO)
	t.veil.push(_mesh_variant(t, true), false)
	_tiles[side * 100 + i] = t
	return t


func _slot(layer: Node2D, at: Vector2) -> Slot:
	var s := Slot.new()
	s.position = at
	layer.add_child(s)
	return s


func _mesh_variant(t: Tile, veil: bool) -> MeshVariant:
	var v := MeshVariant.new()
	Painter.build_field(v.batch, t.side, t.index, _states.duplicate(), veil)
	return v


func _decor_variant(t: Tile, band: int, direct: bool) -> DecorVariant:
	var v := DecorVariant.new()
	v.side = t.side
	v.index = t.index
	v.band = band
	v.states = _states.duplicate()
	v.rect = Painter.band_rect(t.side, t.index, band)
	v.direct = direct or not can_bake()
	if can_bake():
		_queue.append(v)
	else:
		v.shown = true
	return v


## Lance les cuissons en attente (au plus MAX_BAKING à la fois).
func _pump() -> void:
	while _baking < _max_baking and not _queue.is_empty():
		var v = _queue.pop_front()
		if not is_instance_valid(v) or not v.is_inside_tree():
			continue
		_baking += 1
		v.bake(func(): _baking -= 1)


## Suit l'état des régions (Cœur purifié) ; une tuile dont l'état change est redessinée et l'image nouvelle
## apparaît en fondu.
func _sync_states() -> void:
	var now := {}
	if main != null and is_instance_valid(main):
		for id in Regions.ids():
			if bool(main.regions_purified.get(id, false)):
				now[id] = true
	if now == _states:
		return
	_states = now
	current_states = now.duplicate()
	for key in _tiles:
		var t: Tile = _tiles[key]
		var st := Painter.state_key(t.side, t.index, _states)
		if st == t.state:
			continue
		t.state = st
		for pair in [[t.base, null], [t.veil, null], [t.near, Painter.NEAR], [t.far, Painter.FAR]]:
			var s: Slot = pair[0]
			if s == null:
				continue
			if pair[1] == null:
				s.push(_mesh_variant(t, s == t.veil), true)
			else:
				s.push(_decor_variant(t, pair[1], false), true)
			_fading[s] = true


func _advance(delta: float) -> void:
	for s in _fading.keys():
		if not is_instance_valid(s) or s.advance(delta / LIFE_TIME):
			_fading.erase(s)


## Au-delà du budget, rend les tuiles qui n'ont pas servi depuis UNUSED_FRAMES images, les plus anciennes d'abord.
func _trim() -> void:
	if BordBake.bytes <= BUDGET:
		return
	var now := Engine.get_process_frames()
	var keys := _tiles.keys()
	keys.sort_custom(func(a, b): return _tiles[a].used < _tiles[b].used)
	for key in keys:
		if BordBake.bytes <= BUDGET:
			break
		if now - int(_tiles[key].used) > UNUSED_FRAMES:
			_free_tile(key)


func _free_tile(key: int) -> void:
	var t: Tile = _tiles.get(key)
	if t == null:
		return
	for s in [t.base, t.veil, t.near, t.far]:
		if s != null and is_instance_valid(s):
			_fading.erase(s)
			s.release()
	_tiles.erase(key)


## Une tuile du bord : ses quatre couches.
class Tile:
	var side := 0
	var index := 0
	var state := ""
	var used := 0
	var base: Slot
	var veil: Slot
	var near: Slot
	var far: Slot


## Une couche d'une tuile : ses images (la dernière par-dessus, en fondu quand l'état change).
class Slot extends Node2D:
	func push(v: Node2D, fade: bool) -> void:
		if fade:
			v.modulate.a = 0.0
		add_child(v)

	## Fait avancer le fondu de la dernière image ; vrai quand il est fini (les autres sont rendues).
	func advance(k: float) -> bool:
		var n := get_child_count()
		if n == 0:
			return true
		var top: Node2D = get_child(n - 1)
		if not top.get("shown"):
			return false
		top.modulate.a = minf(1.0, top.modulate.a + k)
		if top.modulate.a < 1.0:
			return false
		for c in get_children():
			if c != top:
				c.queue_free()
				if c.has_method("forget"):
					c.forget()
		return true

	func release() -> void:
		for c in get_children():
			if c.has_method("forget"):
				c.forget()
		queue_free()


## Fond ou voile d'une tuile : un lot de triangles, dessiné une fois.
class MeshVariant extends Node2D:
	var batch := DrawBatch.new()
	var shown := true

	func _draw() -> void:
		batch.flush(self)


## Une bande de décor d'une tuile : son image cuite, ou son dessin direct.
class DecorVariant extends Node2D:
	var side := 0
	var index := 0
	var band := 0
	var states := {}
	var rect := Rect2()
	var direct := false
	var shown := false
	var tex: Texture2D
	var _bytes := 0
	var _done := Callable()

	func _finish() -> void:
		if _done.is_valid():
			var d := _done
			_done = Callable()
			d.call()

	func _draw() -> void:
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, rect.size), false)
		elif direct:
			draw_set_transform(-rect.position)
			Painter.paint(self, side, index, band, states)
			draw_set_transform_matrix(Transform2D.IDENTITY)

	func bake(done: Callable) -> void:
		var t0 := Time.get_ticks_usec()
		var k: float = BAKE_SCALE[band] * SS
		var size := Vector2i(ceili(rect.size.x * k), ceili(rect.size.y * k))
		_done = done
		# Tirage des éléments, sorte par sorte, sur autant d'images qu'il faut.
		var list := []
		var t1 := Time.get_ticks_usec()
		var nk := Painter.Bord.KINDS.size()
		for ki in nk + 1:
			if ki < nk:
				list.append_array(Painter.items(side, index, band, states, 0, Painter.DEPTH, ki, ki + 1, false, false))
			else:
				list.append_array(Painter.items(side, index, band, states, 0, Painter.DEPTH, 0, 0, true, false))
			if (ki + 1) % SLICE_KINDS == 0:
				BordBake.items_max_usec = maxi(BordBake.items_max_usec, Time.get_ticks_usec() - t1)
				await get_tree().process_frame
				if not is_instance_valid(self):
					return
				t1 = Time.get_ticks_usec()
		BordBake.items_max_usec = maxi(BordBake.items_max_usec, Time.get_ticks_usec() - t1)
		Painter.sort_items(list)
		var vp := SubViewport.new()
		vp.size = size
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		# Effacée une fois : chaque image de cuisson ajoute sa part du dessin (SLICE_COST ms estimées par image).
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
		add_child(vp)
		var from := 0
		var prev: Node = null
		while true:
			var pn := PaintNode.new()
			pn.variant = self
			pn.k = k
			pn.list = list
			pn.from = from
			if prev != null:
				prev.visible = false
				prev.queue_free()
			vp.add_child(pn)
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			if not is_instance_valid(vp):
				_finish()
				return
			from = pn.next
			prev = pn
			if from >= list.size():
				break
		_finish()
		var img: Image = vp.get_texture().get_image() if vp.get_texture() != null else null
		vp.queue_free()
		if img == null or img.is_empty():
			direct = true
			shown = true
			queue_redraw()
			return
		img.resize(maxi(1, size.x / SS), maxi(1, size.y / SS), Image.INTERPOLATE_BILINEAR)
		tex = ImageTexture.create_from_image(img)
		_bytes = img.get_data_size()
		BordBake.bytes += _bytes
		BordBake.baked += 1
		BordBake.bake_usec = Time.get_ticks_usec() - t0
		material = BordBake.material()
		shown = true
		queue_redraw()

	## Rend la mémoire de l'image (la tuile est rendue ou remplacée).
	func forget() -> void:
		_finish()
		BordBake.bytes -= _bytes
		_bytes = 0
		tex = null


## Peint une bande dans le SubViewport de cuisson.
class PaintNode extends Node2D:
	var variant: DecorVariant
	var k := 1.0
	var list: Array = []
	var from := 0
	var next := 0

	func _draw() -> void:
		var v := variant
		draw_set_transform(-v.rect.position * k, 0.0, Vector2(k, k))
		var t0 := Time.get_ticks_usec()
		next = Painter.draw_items(self, list, v.states, from, 0, 0, SLICE_COST)
		BordBake.paint_usec = Time.get_ticks_usec() - t0
		BordBake.paint_max_usec = maxi(BordBake.paint_max_usec, BordBake.paint_usec)


# --- Carte du monde ---

## Le fond du bord jusqu'à la profondeur « depth », en un lot (sommets, couleurs, indices), mis en cache.
static func map_batch(depth: float, states: Dictionary) -> DrawBatch:
	var key := "%d/%s/%s" % [int(depth), ",".join(Regions.ids()), str(states.keys())]
	if _map_cache.has(key):
		return _map_cache[key]
	var b := DrawBatch.new()
	for side in 4:
		for i in Painter.chunk_count():
			Painter.build_field(b, side, i, states, false, depth)
	_map_cache[key] = b
	return b


## Dessine le bord dans le cadre de la carte : « outer » est le cadre entier, « world_rect » la place du
## monde (carré) à l'intérieur. La marge montre le bord sur la profondeur qu'elle permet, puis se perd
## dans le noir.
static func draw_map_frame(ci: CanvasItem, outer: Rect2, world_rect: Rect2) -> void:
	var k := world_rect.size.x / (2.0 * Regions.WORLD_HALF)
	var depth: float = minf((outer.size.x * 0.5) / k - Regions.WORLD_HALF, Painter.DEPTH)
	var xf := Transform2D(0.0, Vector2(k, k), 0.0, world_rect.position + world_rect.size * 0.5)
	var states := current_states
	var b := map_batch(depth, states)
	if not b.indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), b.indices, xf * b.points, b.colors)
	# Le décor, en formes simples, cuit une fois (dessiné en direct sans rendu).
	var span := Regions.WORLD_HALF + depth
	var key := "%d/%s/%s" % [int(depth), ",".join(Regions.ids()), str(states.keys())]
	var tex: Texture2D = _map_tex.get(key)
	var dst := Rect2(xf * Vector2(-span, -span), Vector2(2.0 * span, 2.0 * span) * k)
	if tex != null:
		ci.draw_texture_rect(tex, dst, false)
	elif not can_bake():
		ci.draw_set_transform_matrix(xf)
		_paint_map(ci, depth, states)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	elif ci is Node and ci.is_inside_tree() and not _map_tex.has(key + "/en cours"):
		_map_tex[key + "/en cours"] = true
		_bake_map(ci, key, depth, span, states)
	# Les bandes extérieures s'assombrissent : le bord de la carte se perd dans le noir.
	var fade := (outer.size.x - world_rect.size.x) * 0.5 * 0.4
	var dark := Color(0.02, 0.03, 0.03, 0.96)
	var clear := Color(dark, 0.0)
	var o := outer
	var tl := o.position
	var tr := o.position + Vector2(o.size.x, 0)
	var bl := o.position + Vector2(0, o.size.y)
	var br := o.end
	var cs := PackedColorArray([dark, dark, clear, clear])
	ci.draw_primitive(PackedVector2Array([tl, tr, tr + Vector2(0, fade), tl + Vector2(0, fade)]), cs, PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([bl, br, br - Vector2(0, fade), bl - Vector2(0, fade)]), cs, PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([tl, bl, bl + Vector2(fade, 0), tl + Vector2(fade, 0)]), cs, PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([tr, br, br - Vector2(fade, 0), tr - Vector2(fade, 0)]), cs, PackedVector2Array())


static func _paint_map(ci: CanvasItem, depth: float, states: Dictionary) -> void:
	for side in 4:
		for i in Painter.chunk_count():
			Painter.paint(ci, side, i, Painter.NEAR, states, 1, depth)


static func _bake_map(ci: CanvasItem, key: String, depth: float, span: float, states: Dictionary) -> void:
	var size := Vector2i(MAP_TEX * SS, MAP_TEX * SS)
	var k := float(size.x) / (2.0 * span)
	var tree := (ci as Node).get_tree()
	# Tirage des formes de toutes les tuiles, sur plusieurs images au besoin.
	var list := []
	for side in 4:
		for i in Painter.chunk_count():
			list.append_array(Painter.items(side, i, Painter.NEAR, states, 1, depth, 0, -1, true, false))
			if (i + 1) % 5 == 0:
				await tree.process_frame
				if not is_instance_valid(ci):
					_map_tex.erase(key + "/en cours")
					return
	Painter.sort_items(list)
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	(ci as Node).add_child(vp)
	var from := 0
	var prev: Node = null
	while true:
		var pn := MapPaint.new()
		pn.states = states.duplicate()
		pn.xf = Transform2D(0.0, Vector2(k, k), 0.0, Vector2(size) * 0.5)
		pn.list = list
		pn.from = from
		if prev != null:
			prev.visible = false
			prev.queue_free()
		vp.add_child(pn)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await tree.process_frame
		await RenderingServer.frame_post_draw
		if not is_instance_valid(vp):
			_map_tex.erase(key + "/en cours")
			return
		from = pn.next
		prev = pn
		if from >= list.size():
			break
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	_map_tex.erase(key + "/en cours")
	if img == null or img.is_empty():
		return
	img.resize(MAP_TEX, MAP_TEX, Image.INTERPOLATE_BILINEAR)
	img.generate_mipmaps()
	_map_tex[key] = ImageTexture.create_from_image(img)
	if is_instance_valid(ci):
		ci.queue_redraw()


class MapPaint extends Node2D:
	var states := {}
	var xf := Transform2D.IDENTITY
	var list: Array = []
	var from := 0
	var next := 0

	func _draw() -> void:
		draw_set_transform_matrix(xf)
		next = Painter.draw_items(self, list, states, from, 1, 0, SLICE_COST * 3.0)
