## Cuisson du corps d'un boss redessiné (refonte des personnages, vague 2) : le dessin « Bestiaire
## d'herbier » d'un boss coûte plusieurs ms ; il est rendu une fois par pose (clé : la pose sans le
## temps, quantifiée par le boss) dans un SubViewport gardé en vie, dont la texture est ensuite
## posée à chaque image (aucune relecture GPU). Ce qui bouge sans cesse (yeux, spores, bulles,
## veines, étincelles) reste dessiné en direct par-dessus (couche « live » du script de dessin).
##
## Une pose nouvelle est rendue pendant l'image où elle apparaît ; la texture de la pose précédente
## reste affichée une image de plus (aucun dessin direct), sauf au tout début (aucune texture : dessin
## direct). Cache LRU de MAX poses.
extends RefCounted

## Rendu suréchantillonné (lissage des bords, comme la cuisson des Flétris).
const SS := 1.5
const MAX := 24

## Rectangle du dessin autour des pieds, en px du jeu (avant l'échelle de l'écran).
var rect: Rect2
var host: Node
var draw_fn: Callable
var scale := 1.0
## clé → {"vp", "frame" (image de création), "used"}.
var entries := {}
var shown := ""
var misses := 0


func _init(h: Node, r: Rect2, fn: Callable) -> void:
	host = h
	rect = r
	draw_fn = fn
	scale = clampf(snappedf(_window_h() / 900.0 * 1.1, 0.25), 1.0, 3.0) * SS


static func _window_h() -> float:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return float((ml as SceneTree).root.size.y)
	return 900.0


class Painter extends Node2D:
	var fn: Callable
	var pose: Dictionary

	func _draw() -> void:
		fn.call(self, pose)


## Texture de la pose (clé key), ou null si aucune n'est encore prête (dessiner en direct).
func texture(key: String, pose: Dictionary) -> Texture2D:
	var now := Engine.get_process_frames()
	if not entries.has(key):
		_make(key, pose, now)
	var e: Dictionary = entries[key]
	e["used"] = now
	if int(e["frame"]) < now:
		shown = key
		return e["vp"].get_texture()
	# Pas encore rendue : la précédente, si elle existe encore.
	if shown != "" and entries.has(shown):
		entries[shown]["used"] = now
		return entries[shown]["vp"].get_texture()
	return null


func _make(key: String, pose: Dictionary, now: int) -> void:
	misses += 1
	if entries.size() >= MAX:
		var old := ""
		var best := 1 << 62
		for k in entries:
			if k != shown and int(entries[k]["used"]) < best:
				best = int(entries[k]["used"])
				old = k
		if old != "":
			entries[old]["vp"].queue_free()
			entries.erase(old)
	var vp := SubViewport.new()
	vp.size = Vector2i((rect.size * scale).ceil())
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	var p := Painter.new()
	p.fn = draw_fn
	p.pose = pose
	p.position = -rect.position * scale
	p.scale = Vector2(scale, scale)
	vp.add_child(p)
	host.add_child(vp)
	entries[key] = {"vp": vp, "frame": now, "used": now}


## Pose la texture de la pose sur ci, pieds en feet (repère de ci), teintée de mod.
func draw(ci: CanvasItem, feet: Vector2, tex: Texture2D, mod := Color.WHITE) -> void:
	ci.draw_texture_rect(tex, Rect2(feet + rect.position, rect.size), false, mod)


func clear() -> void:
	for k in entries:
		entries[k]["vp"].queue_free()
	entries.clear()
	shown = ""


## Dessine un boss redessiné : le corps (couche « body » de art, cuit par pose : clé = la pose sans
## « t ») puis ce qui bouge (couche « live »), le tout sous la transformation xf posée aux pieds
## (respiration, balancement). direct : sans cuisson (tests figés, sans écran).
func paint(ci: CanvasItem, art, h: float, feet: Vector2, pose: Dictionary, xf: Transform2D, direct := false) -> void:
	ci.draw_set_transform_matrix(Transform2D(0.0, feet) * xf)
	var b := pose.duplicate()
	b["layer"] = "body"
	var tex: Texture2D = null
	if not direct:
		# L'éclair du coup reçu et la teinte du poison ne sont pas cuits : la texture est teintée.
		var key := b.duplicate()
		key.erase("t")
		key.erase("hit")
		key.erase("poison")
		var cooked := b.duplicate()
		cooked.erase("hit")
		cooked.erase("poison")
		tex = texture(str(key), cooked)
	if tex != null:
		var mod := Color.WHITE
		if pose.get("poison", false):
			mod = Color(0.88, 0.78, 1.0)
		if float(pose.get("hit", 0.0)) > 0.0:
			mod = Color(1.9, 1.8, 1.6)
		draw(ci, Vector2.ZERO, tex, mod)
	else:
		art.draw(ci, Vector2.ZERO, h, b)
	var l := pose.duplicate()
	l["layer"] = "live"
	art.draw(ci, Vector2.ZERO, h, l)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Sans écran (tests --headless), rien n'est rendu : dessiner en direct.
static func headless() -> bool:
	return DisplayServer.get_name() == "headless"
