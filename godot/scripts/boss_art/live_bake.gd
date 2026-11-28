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
## Affichage par bandes (cuissons rares seulement : corps et bras de la Flétrissure, sol) : après chaque
## rendu, la texture est relue une fois et découpée en bandes de STRIP pixels, chacune réduite à la partie
## où ses pixels ne sont pas transparents (± 2 pixels pour le filtrage). Le rendu logiciel paie chaque
## pixel d'un rectangle affiché, même transparent : le corps et les bras sont vides à ~85 %. Même
## image ; tant que les bandes du dernier rendu ne sont pas prêtes, la texture entière est affichée.
var trim := false
const STRIP := 16
var _strips: Array = []
var _strips_at := -1


static func available() -> bool:
	return Cuisson.active()


## mult : le dessin est affiché mult fois plus grand que son repère (la texture est d'autant plus fine).
func _init(host: Node, box_: Rect2, drawer_: Callable, mult := 1.0) -> void:
	box = box_
	drawer = drawer_
	if not available():
		return
	# ×1,5 de suréchantillonnage (le SubViewport n'a pas de MSAA en Compatibility) : bords lisses.
	scale = Cuisson.window_scale(1.5, 1.5, 2.5) * mult
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


## Change la boîte couverte (au prochain rendu) : une boîte serrée sur la pose du moment coûte moins
## à afficher qu'une boîte qui couvre toutes les poses (rendu logiciel : chaque pixel transparent compte).
func set_box(b: Rect2) -> void:
	if b == box:
		return
	box = b
	if vp == null:
		return
	vp.size = Vector2i((box.size * scale).ceil())
	node.position = -box.position * scale


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
	if trim:
		_strips.clear()
		_strips_at = Engine.get_frames_drawn() + 2


## Relit la texture rendue et la découpe en bandes (voir trim) ; une fois par rendu, deux images après
## la demande (le rendu est fait à la fin de l'image).
func _make_strips() -> void:
	_strips_at = -1
	var img: Image = vp.get_texture().get_image() if vp.get_texture() != null else null
	if img == null or img.is_empty():
		return
	var w := img.get_width()
	var h := img.get_height()
	var out := []
	for y in range(0, h, STRIP):
		var y0 := maxi(0, y - 2)
		var y1 := mini(h, y + STRIP + 2)
		var used := img.get_region(Rect2i(0, y0, w, y1 - y0)).get_used_rect()
		if used.size.x <= 0:
			continue
		var x0 := maxi(0, used.position.x - 2)
		var x1 := mini(w, used.end.x + 2)
		out.append(Rect2(x0, y, x1 - x0, mini(STRIP, h - y)))
	_strips = out


## Affiche la texture dans ci, le repère local du dessin posé en at. tint : couleur pour sprite_tint
## (rgb = couleur visée, 1 - alpha = sa part ; blanc opaque : aucune).
func draw(ci: CanvasItem, at := Vector2.ZERO, tint := Color.WHITE) -> void:
	if vp == null or not ready:
		return
	if _strips_at >= 0 and Engine.get_frames_drawn() >= _strips_at:
		_make_strips()
	if _strips.is_empty() or _strips_at >= 0:
		ci.draw_texture_rect(vp.get_texture(), Rect2(at + box.position, box.size), false, tint)
		return
	# Texels → repère du dessin : la texture entière couvre la boîte (même rapport que ci-dessus).
	var tex := vp.get_texture()
	var k := box.size / Vector2(vp.size)
	var o := at + box.position
	for r: Rect2 in _strips:
		ci.draw_texture_rect_region(tex, Rect2(o + r.position * k, r.size * k), r, tint, false, false)


func free_viewport() -> void:
	if vp != null and is_instance_valid(vp):
		vp.queue_free()
	vp = null
	ready = false
