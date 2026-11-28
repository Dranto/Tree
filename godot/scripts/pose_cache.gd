## Cache de poses d'un grand dessin « Bestiaire d'herbier » (boss, et leur sommeil ou leur victoire dans
## l'arène) : chaque pose est dessinée une seule fois dans un nœud enfant, qui garde ses commandes de dessin
## ; ensuite on ne fait que montrer le bon nœud, le placer et le teinter. Le dessin direct d'un boss
## (encre, deux tons, reflets : des découpes de polygones) coûte plusieurs ms ; une pose déjà vue ne coûte
## plus rien aux scripts. Les poses sont donc des cases discrètes (une animation en N images), comme les
## sprites cuits des Flétris (sprite_bake.gd), mais sans texture : le dessin reste vectoriel et net.
##
## Une nouvelle pose est dessinée par le moteur à l'image suivante : en attendant, la précédente reste
## visible (pas de clignotement). Les poses les moins récentes sont oubliées au-delà de `limit`.
## Apparence seulement : rien ici ne touche au jeu.
##
## Montrer et cacher passe par le serveur de rendu (`_show`), pas par `visible` : dans Godot 4, un nœud
## qui redevient visible (lui ou un parent) est redessiné ; chaque retour d'une pose déjà vue refaisait
## donc tout son dessin (~5 ms), et le retour du cache entier après le piqué du Harfang les refaisait
## toutes. Les propriétés `visible` restent vraies ; `shown` dit si le cache est montré.
extends Node2D

const NAME := "PoseCache"  # i18n: non
const Cuisson = preload("res://scripts/boss_art/cuisson.gd")
const LieuxBake = preload("res://scripts/world_bake/lieux_bake.gd")

## Nombre de poses gardées (la plus ancienne est oubliée au-delà).
var limit := 220
## Facultatif : le cache se masque tout seul quand cette condition devient fausse (arène : le boss
## endormi ou la victoire ne sont plus dessinés).
var visible_if := Callable()

var _nodes := {}
var _stamp := {}
var _clock := 0
var _current: Node2D = null
var _prev: Node2D = null
## Poses dessinées (compteur, pour les bancs et les tests).
var drawn_count := 0
## Palette des poses gardées (Cuisson.epoch) : le mode daltonien change, elles sont redessinées.
var _epoch := Cuisson.epoch
## Le cache est montré (voir l'en-tête : `visible` reste vrai).
var shown := true

## --- Pose affichée en image (facultatif : bake_box posé par le boss) ---
## Les poses gardent leurs commandes de dessin, mais dans un SubViewport : il n'est rendu que quand la
## pose change (~8 fois par seconde), et l'écran ne montre plus qu'une image (alpha prémultiplié). En
## rendu logiciel, retracer les milliers de sommets d'une pose à chaque image coûtait ~2,5 ms.
## bake_box : repère de la pose (pieds en 0, px du jeu) qui contient toutes ses poses.
var bake_box := Rect2()
## Rendus de la pose affichée (compteur, pour les tests).
var renders := 0
var _vp: SubViewport
var _holder: Node2D
var _view: Node2D
var _mod := Color.WHITE
var _want_render := false
var _has_image := false


class Pose extends Node2D:
	var drawer: Callable
	var drawn := false
	var owner_cache

	func _draw() -> void:
		drawer.call(self)
		drawn = true
		owner_cache.drawn_count += 1


## Le cache d'un nœud (créé au premier appel, enfant dessiné par-dessus le nœud).
static func on(host: Node2D) -> Node2D:
	var c := host.get_node_or_null(NAME)
	if c == null:
		c = load("res://scripts/pose_cache.gd").new()
		c.name = NAME
		host.add_child(c)
	return c


## Montre la pose key (la dessine avec drawer(ci) la première fois), placée en xf, teintée de mod.
func show_pose(key: String, drawer: Callable, xf: Transform2D, mod := Color.WHITE) -> void:
	_clock += 1
	_show(self, true)
	if _epoch != Cuisson.epoch:
		_epoch = Cuisson.epoch
		for k in _nodes:
			_nodes[k].queue_free()
		_nodes.clear()
		_stamp.clear()
		_current = null
		_prev = null
		_want_render = false
	var baking := _baking()
	var n: Node2D = _nodes.get(key)
	if n == null:
		var p := Pose.new()
		p.drawer = drawer
		p.owner_cache = self
		if baking:
			_holder.add_child(p)
		else:
			add_child(p)
		_nodes[key] = p
		n = p
		_trim()
	_stamp[key] = _clock
	if baking:
		_show_baked(n, xf, mod)
		return
	n.transform = xf
	n.modulate = mod
	_show(n, true)
	if n != _current:
		if _prev != null and _prev != n and is_instance_valid(_prev):
			_show(_prev, false)
		_prev = _current
		_current = n
	# L'ancienne pose reste visible tant que la nouvelle n'est pas dessinée ; elle suit la même place.
	if _prev != null and is_instance_valid(_prev):
		if (n as Pose).drawn:
			_show(_prev, false)
			_prev = null
		else:
			_prev.transform = xf
			_prev.modulate = mod


## Les poses passent par une image : bake_box posé et cuisson possible (écran, pas « --no-sprites »).
func _baking() -> bool:
	if not bake_box.has_area() or not Cuisson.active():
		return false
	if _vp == null:
		var sc := Cuisson.window_scale(1.5, 1.5, 2.5)
		_vp = SubViewport.new()
		_vp.size = Vector2i((bake_box.size * sc).ceil())
		_vp.transparent_bg = true
		_vp.disable_3d = true
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_holder = Node2D.new()
		_holder.scale = Vector2(sc, sc)
		_holder.position = -bake_box.position * sc
		_vp.add_child(_holder)
		add_child(_vp)
		_view = Node2D.new()
		_view.material = LieuxBake.plain_material()
		_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_view.draw.connect(_draw_view)
		add_child(_view)
	return true


func _show_baked(n: Node2D, xf: Transform2D, mod: Color) -> void:
	_view.transform = xf
	if mod != _mod:
		_mod = mod
		_view.queue_redraw()
	if n == _current:
		return
	if _current != null and is_instance_valid(_current):
		_show(_current, false)
	_show(n, true)
	_current = n
	_want_render = true


func _draw_view() -> void:
	if _has_image:
		_view.draw_texture_rect(_vp.get_texture(), bake_box, false, _mod)


## Rend la pose affichée dans l'image. Demandé à l'image qui suit le changement : en Godot 4.7, un rendu
## demandé dans l'image même d'un changement montre l'état d'avant (docs/performances.md).
func _render_pose() -> void:
	if not _want_render or _current == null or not (_current as Pose).drawn:
		return
	_want_render = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	renders += 1
	if not _has_image:
		_has_image = true
		_view.queue_redraw()


func hide_all() -> void:
	_show(self, false)


## Montre ou cache un nœud sans toucher à `visible` (qui le ferait redessiner à son retour).
func _show(n: CanvasItem, on: bool) -> void:
	if n == self:
		if shown == on:
			return
		shown = on
	elif n.has_meta(&"pc_shown") and bool(n.get_meta(&"pc_shown")) == on:
		return
	else:
		n.set_meta(&"pc_shown", on)
	RenderingServer.canvas_item_set_visible(n.get_canvas_item(), on)


func _process(_delta: float) -> void:
	if _vp != null:
		_render_pose()
	if _prev != null and is_instance_valid(_prev) and _current != null and (_current as Pose).drawn:
		_show(_prev, false)
		_prev = null
	if visible_if.is_valid() and not visible_if.call():
		_show(self, false)


func size() -> int:
	return _nodes.size()


func _trim() -> void:
	while _nodes.size() > limit:
		var oldest := ""
		var best := 1 << 62
		for k in _stamp:
			var n: Node2D = _nodes[k]
			if n != _current and n != _prev and _stamp[k] < best:
				best = _stamp[k]
				oldest = k
		if oldest == "":
			return
		_nodes[oldest].queue_free()
		_nodes.erase(oldest)
		_stamp.erase(oldest)
