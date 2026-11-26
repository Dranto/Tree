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
extends Node2D

const NAME := "PoseCache"

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
	visible = true
	var n: Node2D = _nodes.get(key)
	if n == null:
		var p := Pose.new()
		p.drawer = drawer
		p.owner_cache = self
		add_child(p)
		_nodes[key] = p
		n = p
		_trim()
	_stamp[key] = _clock
	n.transform = xf
	n.modulate = mod
	n.visible = true
	if n != _current:
		if _prev != null and _prev != n and is_instance_valid(_prev):
			_prev.visible = false
		_prev = _current
		_current = n
	# L'ancienne pose reste visible tant que la nouvelle n'est pas dessinée ; elle suit la même place.
	if _prev != null and is_instance_valid(_prev):
		if (n as Pose).drawn:
			_prev.visible = false
			_prev = null
		else:
			_prev.transform = xf
			_prev.modulate = mod


func hide_all() -> void:
	visible = false


func _process(_delta: float) -> void:
	if _prev != null and is_instance_valid(_prev) and _current != null and (_current as Pose).drawn:
		_prev.visible = false
		_prev = null
	if visible_if.is_valid() and not visible_if.call():
		visible = false


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
