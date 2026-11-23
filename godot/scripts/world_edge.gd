## Le bord du monde : au-delà de ± Regions.WORLD_HALF, un décor propre à chaque région qui se fond
## peu à peu dans le noir, au lieu du fond quasi noir du moteur.
##   - Ronce : un mur de ronces à perte de vue (tiges à épines, baies rouges) ;
##   - Spore : les eaux du marais (nénuphars, roseaux, champignons géants, brume de spores) ;
##   - Vent : le bord d'un plateau qui tombe dans une mer de nuages (rochers flottants, traînées) ;
##   - Sève : la vallée vue d'en haut (cimes touffues, fils de sève lumineux, brume verte) ;
##   - Aube : un ciel de verre sous le bord d'une falaise (aiguilles, rayons, éclats qui flottent) ;
##   - Racine : la forêt pétrifiée (racines géantes, troncs de pierre, lichens).
## Une région sans décor à elle (région d'essai) prend celui du roncier ; le fichier d'une région peut
## aussi choisir le sien avec le champ « edge » (data/README.md).
##
## Le bord est un anneau de profondeur DEPTH autour du monde carré, en quatre trapèzes (joints en onglet
## aux coins), coupés en tuiles de CHUNK px le long du bord. Une tuile est un nœud dont tout le dessin
## tient en un seul appel de rendu (DrawBatch) : dégradé de fond sommet par sommet, puis les formes du
## décor (world_edge_painter.gd). Elle est dessinée une fois, quand la caméra s'en approche, et le moteur
## ne la redessine plus ; loin du bord aucune tuile n'est visible, le coût est nul.
## Chaque forme est tirée avec une graine fixe (côté, tuile, thème) : le bord est le même à chaque
## partie. Aux frontières entre deux régions, les décors se mêlent (poids en BLEND radians).
##
## La carte du monde (world_map.gd) dessine le même bord, réduit, dans la marge de son cadre
## (draw_map_frame).
extends Node2D

const Painter = preload("res://scripts/world_edge_painter.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")
const Regions = preload("res://scripts/regions.gd")

## Les tuiles à moins de PREPARE px de l'écran sont dessinées d'avance (une par image au plus).
const PREPARE := 1100.0

var main
var _chunks: Dictionary = {}
## Les fonds de toutes les tuiles sont dessinés avant tous les décors : une forme qui déborde sur la
## tuile voisine n'est pas recouverte par son fond.
var _base_layer: Node2D
var _decor_layer: Node2D
## Couches de vie (région purifiée), par région : posées sur le décor, qui apparaissent peu à peu.
var _life_layer: Node2D
## Avancement de la vie du bord de chaque région (0 à 1) et ses tuiles : région → {clé de tuile → nœud}.
var _life: Dictionary = {}
var _life_nodes: Dictionary = {}
## Durée (s) du reverdissement du bord.
const LIFE_TIME := 3.0
## Marge de la carte du monde, en part du monde : le bord y est montré sur cette profondeur.
const MAP_MARGIN := 0.09
static var _map_cache: Dictionary = {}


func _ready() -> void:
	Painter.load_regions()
	_base_layer = Node2D.new()
	add_child(_base_layer)
	_decor_layer = Node2D.new()
	add_child(_decor_layer)
	_life_layer = Node2D.new()
	add_child(_life_layer)


func _process(delta: float) -> void:
	if main == null or not is_instance_valid(main) or main.camera == null:
		return
	_update_life(delta)
	var under: bool = main.underground()
	visible = not under
	if under:
		return
	var half: float = main.world_half
	var view := get_viewport().get_visible_rect().size
	var c: Vector2 = main.camera.get_screen_center_position()
	var reach := view * 0.5 + Vector2(PREPARE, PREPARE)
	# Tout l'écran (marge comprise) dans le monde : rien à préparer.
	if absf(c.x) + reach.x <= half and absf(c.y) + reach.y <= half:
		return
	ensure(Rect2(c - reach, reach * 2.0), 1)


## Dessine les tuiles qui touchent « area » (coordonnées du monde) et ne le sont pas encore, au plus
## « budget » par appel (0 : toutes, pour les captures et les tests).
func ensure(area: Rect2, budget := 0) -> void:
	Painter.load_regions()
	var made := 0
	for side in 4:
		for i in Painter.chunk_count():
			var key := side * 100 + i
			if _chunks.has(key) or not Painter.chunk_rect(side, i).intersects(area):
				continue
			_chunks[key] = [_make_chunk(_base_layer, side, i, false), _make_chunk(_decor_layer, side, i, true)]
			for id in _life:
				_make_life(id, side, i)
			made += 1
			if budget > 0 and made >= budget:
				return


func _make_chunk(parent: Node2D, side: int, i: int, decor: bool, life_id := "") -> Node2D:
	var node := Chunk.new()
	node.side = side
	node.index = i
	node.decor = decor
	node.life_id = life_id
	parent.add_child(node)
	return node


## Fait avancer le reverdissement de chaque région vers son état (main.regions_purified).
func _update_life(delta: float) -> void:
	for id in Painter.regs:
		var target := 1.0 if bool(main.regions_purified.get(id, false)) else 0.0
		var cur := float(_life.get(id, 0.0))
		if cur == target:
			continue
		if not _life.has(id):
			_life[id] = 0.0
			# Les tuiles déjà dessinées reçoivent leur couche de vie.
			for key in _chunks:
				_make_life(id, int(key) / 100, int(key) % 100)
		cur = move_toward(cur, target, delta / LIFE_TIME)
		_life[id] = cur
		for k in _life_nodes.get(id, {}):
			_life_nodes[id][k].modulate.a = cur
			_life_nodes[id][k].visible = cur > 0.001
		if cur <= 0.0:
			_life.erase(id)


## Couche de vie de la région « id » sur la tuile (côté, rang), s'il y en a une à cet endroit.
func _make_life(id: String, side: int, i: int) -> void:
	if not Painter.present(side, i).has(id):
		return
	var nodes: Dictionary = _life_nodes.get(id, {})
	var key := side * 100 + i
	if nodes.has(key):
		return
	var node := _make_chunk(_life_layer, side, i, true, id)
	node.modulate.a = float(_life.get(id, 0.0))
	nodes[key] = node
	_life_nodes[id] = nodes


## Nombre de tuiles déjà dessinées (tests).
func chunk_total() -> int:
	return _chunks.size()


## Une tuile : son dessin se fait à la création, en un seul lot.
class Chunk extends Node2D:
	var side := 0
	var index := 0
	var decor := false
	var life_id := ""
	var batch := DrawBatch.new()

	func _ready() -> void:
		Painter.build(batch, side, index, Painter.DEPTH, decor, life_id)
		queue_redraw()

	func _draw() -> void:
		batch.flush(self)


## Le bord jusqu'à la profondeur « depth » en un lot (sommets, couleurs, indices), mis en cache : la
## carte le redessine à chaque ouverture.
static func map_batch(depth: float, decor: bool) -> DrawBatch:
	Painter.load_regions()
	var key := "%d/%s/%s" % [int(depth), decor, ",".join(Regions.ids())]
	if _map_cache.has(key):
		return _map_cache[key]
	var b := DrawBatch.new()
	for side in 4:
		for i in Painter.chunk_count():
			if Painter.chunk_rect(side, i, depth).intersects(Rect2(-Regions.WORLD_HALF - depth, -Regions.WORLD_HALF - depth, 2.0 * (Regions.WORLD_HALF + depth), 2.0 * (Regions.WORLD_HALF + depth))):
				Painter.build(b, side, i, depth, decor)
	_map_cache[key] = b
	return b


## Dessine le bord dans le cadre de la carte : « outer » est le cadre entier, « world_rect » la place du
## monde (carré) à l'intérieur. La marge montre le bord sur la profondeur qu'elle permet, puis se perd
## dans le noir.
static func draw_map_frame(ci: CanvasItem, outer: Rect2, world_rect: Rect2) -> void:
	var k := world_rect.size.x / (2.0 * Regions.WORLD_HALF)
	var depth: float = (outer.size.x * 0.5) / k - Regions.WORLD_HALF
	var xf := Transform2D(0.0, Vector2(k, k), 0.0, world_rect.position + world_rect.size * 0.5)
	for decor in [false, true]:
		var b := map_batch(depth, decor)
		if not b.indices.is_empty():
			var pts: PackedVector2Array = xf * b.points
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), b.indices, pts, b.colors)
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
