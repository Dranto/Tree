## Cuisson « vivante » d'un grand dessin de boss (refonte des personnages, B4) : le dessin du code est
## rendu dans un SubViewport transparent, à la demande (au plus `rate` fois par seconde, ou tout de
## suite quand sa clé change), et chaque image du jeu n'affiche plus que sa texture. Le dessin garde
## sa vie (respiration, braises) au rythme des Flétris cuits (~20 i/s), pour une fraction du coût.
##
## La texture est en alpha prémultiplié : l'afficher avec shaders/sprite_tint.gdshader (teinte d'état
## et éclair du coup dans la couleur passée à draw_texture_rect, comme les Flétris).
## Sans rendu (--headless), rien n'est cuit : `ready` reste faux, l'appelant dessine en direct s'il veut.
extends RefCounted

const Cuisson = preload("res://scripts/boss_art/cuisson.gd")

## Repère local du dessin (px du jeu) couvert par la texture.
var box: Rect2
## Pixels de texture par px du jeu (hauteur de la fenêtre / 900, ×1,5, pas de 0,25, de 1,5 à 2,5).
var scale := 1.0
## Au plus tant de rendus par seconde (hors changement de clé).
var rate := 20.0
var drawer: Callable
var vp: SubViewport
var node: Node2D
var key = null
var _last := -INF
var _pending := 0
## Une image au moins est rendue (la texture peut être affichée).
var ready := false
## Palette du dernier rendu (Cuisson.epoch) : le mode daltonien change, la texture est refaite tout de suite.
var _epoch := Cuisson.epoch


static func available() -> bool:
	return Cuisson.active()


func _init(host: Node, box_: Rect2, drawer_: Callable) -> void:
	box = box_
	drawer = drawer_
	if not available():
		return
	# ×1,5 de suréchantillonnage (le SubViewport n'a pas de MSAA en Compatibility) : bords lisses.
	scale = Cuisson.window_scale(1.5, 1.5, 2.5)
	vp = SubViewport.new()
	vp.size = Vector2i((box.size * scale).ceil())
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	node = Node2D.new()
	node.scale = Vector2(scale, scale)
	node.position = -box.position * scale
	node.draw.connect(func(): drawer.call(node))
	vp.add_child(node)
	# Différé : l'hôte peut être en train de se dessiner (cuisson créée dans un _draw).
	host.add_child.call_deferred(vp)


## Demande un rendu si la clé a changé, ou si le dernier date de plus de 1/rate s (now : horloge en s).
func update(new_key, now: float) -> void:
	if vp == null:
		return
	if _pending > 0:
		# Le rendu demandé est fait à la fin de l'image : la texture est bonne à l'image suivante.
		_pending -= 1
		if _pending == 0:
			ready = true
	if new_key == key and now - _last < 1.0 / rate and now >= _last and _epoch == Cuisson.epoch:
		return
	_epoch = Cuisson.epoch
	key = new_key
	_last = now
	node.queue_redraw()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not ready and _pending == 0:
		_pending = 2


## Affiche la texture dans ci, le repère local du dessin posé en at. tint : couleur pour sprite_tint
## (rgb = couleur visée, 1 - alpha = sa part ; blanc opaque : aucune).
func draw(ci: CanvasItem, at := Vector2.ZERO, tint := Color.WHITE) -> void:
	if vp == null or not ready:
		return
	ci.draw_texture_rect(vp.get_texture(), Rect2(at + box.position, box.size), false, tint)


func free_viewport() -> void:
	if vp != null and is_instance_valid(vp):
		vp.queue_free()
	vp = null
	ready = false
