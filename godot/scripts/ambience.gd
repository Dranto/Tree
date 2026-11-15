## Ambiance du monde : cendres en suspension sur la terre morte, pollen et papillons sur la terre
## vivante, et une légère vignette sur l'écran. Tout est dessiné par le code.
## « Réduire les effets » (options) coupe les particules ; la vignette reste.
extends Node2D

const MOTES := 22
const BUTTERFLIES := 4
## Marge (pixels du monde) autour de l'écran où les particules naissent et disparaissent.
const MARGIN := 80.0
const BUTTERFLY_COLORS := [Color("f2d06b"), Color("e98aa5"), Color("9fd8e8"), Color("f4efd8"), Color("c9a2e8")]

var main
var motes: Array = []
var butterflies: Array = []
var vignette_layer: CanvasLayer
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _skip := false


func _ready() -> void:
	_rng.seed = 4141
	z_index = 4
	_show_vignette(true)
	var rect := _view_rect()
	for i in MOTES:
		motes.append(_new_mote(rect, true))
	for i in BUTTERFLIES:
		butterflies.append({
			"pos": _random_in(rect), "heading": _rng.randf() * TAU, "ph": _rng.randf() * TAU,
			"color": BUTTERFLY_COLORS[i % BUTTERFLY_COLORS.size()], "size": _rng.randf_range(5.0, 7.0), "a": 0.0})


## La vignette vit sur son propre calque. Quand l'arbre couvre l'écran, calque et texture disparaissent tout
## à fait : une texture ou un calque inutilisé coûte encore du temps de rendu à chaque image.
func _show_vignette(on: bool) -> void:
	if on and vignette_layer == null:
		vignette_layer = CanvasLayer.new()
		vignette_layer.layer = 2
		vignette_layer.add_child(_make_vignette())
		add_child(vignette_layer)
	elif not on and vignette_layer != null:
		vignette_layer.queue_free()
		vignette_layer = null


## Vignette dessinée par le code : quatre bandes le long des bords, sombres au bord et transparentes vers l'intérieur.
## Peu de surface à remplir, pour ne pas coûter cher au rendu.
class Vignette extends Control:
	const DEPTH := 0.13
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var clear := Color(0.02, 0.03, 0.02, 0.0)
		var dark := Color(0.02, 0.03, 0.02, 0.4)
		var d := size.y * DEPTH
		var w := size.x
		var h := size.y
		_strip(Vector2(0, 0), Vector2(w, 0), Vector2(w, d), Vector2(0, d), dark, clear)
		_strip(Vector2(0, h), Vector2(w, h), Vector2(w, h - d), Vector2(0, h - d), dark, clear)
		_strip(Vector2(0, 0), Vector2(0, h), Vector2(d, h), Vector2(d, 0), dark, clear)
		_strip(Vector2(w, 0), Vector2(w, h), Vector2(w - d, h), Vector2(w - d, 0), dark, clear)

	func _strip(a: Vector2, b: Vector2, c: Vector2, e: Vector2, edge: Color, inner: Color) -> void:
		draw_polygon(PackedVector2Array([a, b, c, e]), PackedColorArray([edge, edge, inner, inner]))


func _make_vignette() -> Control:
	return Vignette.new()


func _view_rect() -> Rect2:
	var half := get_viewport_rect().size / 2.0 + Vector2(MARGIN, MARGIN)
	var center: Vector2 = main.player.position if main != null and main.player != null else Vector2.ZERO
	return Rect2(center - half, half * 2.0)


func _random_in(rect: Rect2) -> Vector2:
	return rect.position + Vector2(_rng.randf(), _rng.randf()) * rect.size


func _new_mote(rect: Rect2, anywhere: bool) -> Dictionary:
	var pos := _random_in(rect)
	if not anywhere:
		# Ressort sur un bord de l'écran, côté du vent pour la cendre.
		pos = Vector2(rect.position.x if _rng.randf() < 0.5 else rect.end.x, rect.position.y + _rng.randf() * rect.size.y)
	var living: bool = main.ground.life_at(pos) > 0.4
	return {"pos": pos, "living": living, "ph": _rng.randf() * TAU, "size": _rng.randf_range(1.2, 2.6),
		"ember": not living and _rng.randf() < 0.12, "speed": _rng.randf_range(0.6, 1.4)}


func _process(delta: float) -> void:
	var tree_open: bool = main.tree_ui != null and main.tree_ui.visible
	_show_vignette(not tree_open)
	if tree_open:
		return
	if Settings.reduce_effects:
		if _t >= 0.0:
			_t = -1.0
			queue_redraw()
		return
	_t = maxf(_t, 0.0) + delta
	var rect := _view_rect()
	var far := rect.grow(MARGIN * 2.0)
	for i in motes.size():
		var m: Dictionary = motes[i]
		var v: Vector2
		if m["living"]:
			v = Vector2(sin(_t * 0.8 + m["ph"]) * 14.0, -10.0 - 6.0 * sin(_t * 0.5 + m["ph"]))
		else:
			v = Vector2(22.0 + 8.0 * sin(_t * 0.6 + m["ph"]), 12.0 + 6.0 * sin(_t * 0.9 + m["ph"] * 2.0))
		m["pos"] += v * m["speed"] * delta
		if not far.has_point(m["pos"]):
			motes[i] = _new_mote(rect, false)
	for b in butterflies:
		_step_butterfly(b, delta, rect, far)
	# Mouvements lents : redessiner une image sur deux suffit et allège le rendu.
	_skip = not _skip
	if not _skip:
		queue_redraw()


func _step_butterfly(b: Dictionary, delta: float, rect: Rect2, far: Rect2) -> void:
	var life: float = main.ground.life_at(b["pos"])
	var want := smoothstep(0.4, 0.6, life)
	b["a"] = move_toward(b["a"], want, delta * 0.8)
	# Vol saccadé : le cap change doucement, la vitesse pulse.
	b["heading"] += sin(_t * 1.7 + b["ph"]) * 2.2 * delta
	var speed := 38.0 + 22.0 * sin(_t * 3.1 + b["ph"])
	b["pos"] += Vector2.from_angle(b["heading"]) * speed * delta
	if not far.has_point(b["pos"]):
		# Revient dans l'écran, de préférence sur une terre vivante.
		var best := _random_in(rect)
		for i in 5:
			var p := _random_in(rect)
			if main.ground.life_at(p) > main.ground.life_at(best):
				best = p
		b["pos"] = best
		b["heading"] = _rng.randf() * TAU
		b["a"] = 0.0


func _draw() -> void:
	if Settings.reduce_effects:
		return
	for m in motes:
		var p: Vector2 = m["pos"]
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + m["ph"] * 3.0)
		if m["living"]:
			var col := Color(1.0, 0.95, 0.6, 0.35 + 0.4 * tw)
			draw_circle(p, m["size"] * 0.9, col)
		elif m["ember"]:
			draw_circle(p, m["size"] * 2.4, Color(1.0, 0.55, 0.25, 0.12 * (0.5 + tw)))
			draw_circle(p, m["size"] * 0.8, Color(1.0, 0.65, 0.3, 0.5 + 0.4 * tw))
		else:
			draw_circle(p, m["size"], Color(0.62, 0.58, 0.55, 0.28 + 0.2 * tw))
	for b in butterflies:
		if b["a"] > 0.02:
			_draw_butterfly(b)


func _draw_butterfly(b: Dictionary) -> void:
	var p: Vector2 = b["pos"]
	var d := Vector2.from_angle(b["heading"])
	var n := d.orthogonal()
	var s: float = b["size"]
	var col: Color = b["color"]
	col.a = 0.9 * b["a"]
	# Battement d'ailes : la largeur apparente oscille vite.
	var flap := 0.25 + 0.75 * absf(sin(_t * 16.0 + b["ph"]))
	for side in [-1.0, 1.0]:
		var wn: Vector2 = n * side * flap
		var up := PackedVector2Array([p + d * s * 0.2, p + d * s * 1.1 + wn * s * 1.0, p + d * s * 0.2 + wn * s * 1.4, p - d * s * 0.1 + wn * s * 0.3])
		var low := PackedVector2Array([p, p - d * s * 0.9 + wn * s * 0.5, p - d * s * 0.1 + wn * s * 1.0])
		draw_colored_polygon(up, col)
		draw_colored_polygon(low, Color(col.r * 0.85, col.g * 0.85, col.b * 0.85, col.a))
	draw_line(p + d * s * 0.5, p - d * s * 0.5, Color(0.12, 0.1, 0.1, col.a), 1.6)
