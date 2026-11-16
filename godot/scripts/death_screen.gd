## Écran de mort : quelques secondes au centre de l'écran pour dire ce qui est perdu, où renaît
## le joueur et où reprendre sa sève. Le jeu continue derrière (les ennemis ont été dissipés et
## le joueur est invulnérable un instant). Ensuite, tant que la sève perdue n'est pas reprise,
## une flèche au bord de l'écran montre où elle est.
##
## Créé par hud.gd ; rempli par main.player_died via hud.show_death(info).
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")

## Durée totale de l'écran (s), dont FADE_OUT de fondu à la fin.
const DURATION := 5.0
const FADE_IN := 0.3
const FADE_OUT := 1.0
const EDGE := 56.0

var main
var time_left := 0.0
var _veil: ColorRect
var _panel: PanelContainer
var _title: Label
var _lines: VBoxContainer
var _pointer: Control
var _pointer_label: Label
## Position de la flèche à l'écran et direction (vers la sève).
var _arrow_pos := Vector2.ZERO
var _arrow_dir := Vector2.RIGHT
var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil = ColorRect.new()
	_veil.color = Color(0.05, 0.02, 0.02, 0.55)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.box(Color(0.07, 0.05, 0.05, 0.92), Color(0.78, 0.4, 0.35, 0.5), 1, 10)
	sb.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color("e8907f"))
	v.add_child(_title)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 6)
	v.add_child(_lines)
	_pointer = Control.new()
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pointer.draw.connect(_draw_pointer)
	add_child(_pointer)
	_pointer_label = Label.new()
	_pointer_label.add_theme_font_size_override("font_size", 14)
	_pointer_label.add_theme_color_override("font_color", Color("e8d36b"))
	_pointer.add_child(_pointer_label)
	_veil.hide()
	_panel.hide()
	_pointer_label.hide()


## Affiche l'écran. info : {"place", "dropped", "lost", "reset"} (voir main.player_died).
func show_death(info: Dictionary) -> void:
	_title.text = "Tu t'es flétri"
	var texts: Array = [["Tu renais au sanctuaire %s." % info.get("place", "de la Graine"), UiTheme.INK]]
	var dropped := roundi(float(info.get("dropped", 0.0)))
	if dropped > 0:
		if str(info.get("reset", "")) == "boss":
			texts.append(["Ta sève (%d d'expérience) t'attend devant l'arène : va la reprendre." % dropped, Color("e8d36b")])
		else:
			texts.append(["Ta sève (%d d'expérience) est restée là où tu es tombé : va la reprendre." % dropped, Color("e8d36b")])
	else:
		texts.append(["Tu n'avais pas de sève à perdre.", UiTheme.INK])
	var lost := roundi(float(info.get("lost", 0.0)))
	if lost > 0:
		texts.append(["La sève de ta mort précédente (%d) est perdue pour de bon." % lost, Color("e8907f")])
	match str(info.get("reset", "")):
		"coeur": texts.append(["Le Cœur de flétrissure s'est rendormi : le siège est à recommencer.", Color("e8907f")])
		"boss": texts.append(["La Mère-Ronce s'est rendormie avec toute sa vie.", Color("e8907f")])
	texts.append(["Ton Arbre de vie est intact : aucun nœud ni point perdu.", Color("9fd88a")])
	for c in _lines.get_children():
		_lines.remove_child(c)
		c.queue_free()
	for line in texts:
		var l := Label.new()
		l.text = line[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", line[1])
		_lines.add_child(l)
	time_left = DURATION
	_veil.show()
	_panel.show()
	_layout()


func is_showing() -> bool:
	return time_left > 0.0


func _layout() -> void:
	_panel.reset_size()
	_panel.position = ((size - _panel.size) / 2.0 - Vector2(0, size.y * 0.08)).floor()


func _process(delta: float) -> void:
	t += delta
	if time_left > 0.0:
		time_left = maxf(0.0, time_left - delta)
		var shown := DURATION - time_left
		var a := minf(1.0, shown / FADE_IN) * minf(1.0, time_left / FADE_OUT)
		_veil.modulate.a = a
		_panel.modulate.a = a
		_layout()
		if time_left <= 0.0:
			_veil.hide()
			_panel.hide()
	_update_pointer()


## Flèche au bord de l'écran vers la sève perdue, quand elle est hors de vue.
func _update_pointer() -> void:
	var sap = main.lost_sap if main != null else null
	var show := false
	if sap != null and is_instance_valid(sap):
		var screen: Vector2 = main.get_viewport().get_canvas_transform() * sap.global_position
		var inner := Rect2(Vector2.ZERO, size).grow(-EDGE)
		if not inner.has_point(screen):
			show = true
			var mid := size / 2.0
			var d := screen - mid
			# Point du bord intérieur sur la droite qui va du centre de l'écran à la sève.
			var sx := (inner.size.x / 2.0) / maxf(absf(d.x), 0.001)
			var sy := (inner.size.y / 2.0) / maxf(absf(d.y), 0.001)
			_arrow_pos = mid + d * minf(sx, sy)
			_arrow_dir = d.normalized()
			_pointer_label.text = "Sève perdue (%d)" % roundi(sap.amount)
			_pointer_label.reset_size()
			# Libellé sous la flèche (au-dessus si elle est en bas de l'écran), centré sur elle.
			var ls := _pointer_label.size
			var y := _arrow_pos.y + 26.0 if _arrow_pos.y < size.y / 2.0 else _arrow_pos.y - 26.0 - ls.y
			_pointer_label.position = Vector2(_arrow_pos.x - ls.x / 2.0, y).clamp(Vector2(8, 8), size - ls - Vector2(8, 8)).floor()
	_pointer_label.visible = show
	_pointer.set_meta("show", show)
	_pointer.queue_redraw()


func _draw_pointer() -> void:
	if not _pointer.get_meta("show", false):
		return
	var p := _arrow_pos
	var d := _arrow_dir
	var side := d.orthogonal()
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	_pointer.draw_circle(p - d * 8.0, 20.0, Color(0.9, 0.83, 0.42, 0.15 + 0.1 * pulse))
	_pointer.draw_colored_polygon(PackedVector2Array([p + d * 14.0, p - d * 10.0 + side * 11.0, p - d * 4.0, p - d * 10.0 - side * 11.0]), Color("e8d36b"))
