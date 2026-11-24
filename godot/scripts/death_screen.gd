## Écran de mort (direction « Herbier ») : quelques secondes au centre de l'écran pour dire ce qui est perdu, où renaît
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
## Icônes de ce que la mort a coûté (jalon 11 : plus de phrases) : renaissance au sanctuaire, sève
## laissée sur place (avec sa quantité), sève perdue pour de bon, siège ou boss à reprendre, Arbre intact.
var _icons: Control
var info: Dictionary = {}
## Fil qui se consume : le temps qui reste avant que l'écran ne s'efface.
var _fuse: Control
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
	_veil.color = Color(0.1, 0.04, 0.025, 0.78)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pas de boîte : une feuille flétrie gravée, le titre, un séparateur, les lignes, puis un fil
	# rouge qui se consume pendant que l'écran reste affiché.
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_panel.add_child(v)
	var leaf := Control.new()
	leaf.custom_minimum_size = Vector2(0, 96)
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaf.draw.connect(_draw_leaf.bind(leaf))
	v.add_child(leaf)
	_icons = Control.new()
	_icons.custom_minimum_size = Vector2(420, 84)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.draw.connect(_draw_icons)
	v.add_child(_icons)
	_fuse = Control.new()
	_fuse.custom_minimum_size = Vector2(0, 40)
	_fuse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fuse.draw.connect(_draw_fuse)
	v.add_child(_fuse)
	_pointer = Control.new()
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pointer.draw.connect(_draw_pointer)
	add_child(_pointer)
	_pointer_label = Label.new()
	_pointer_label.add_theme_font_size_override("font_size", UiTheme.fs(17))
	_pointer_label.add_theme_color_override("font_color", UiTheme.GOLD)
	_pointer.add_child(_pointer_label)
	_veil.hide()
	_panel.hide()
	_pointer_label.hide()


## Affiche l'écran. info : {"place", "dropped", "lost", "reset"} (voir main.player_died).
func show_death(i: Dictionary) -> void:
	info = i
	time_left = DURATION
	_veil.show()
	_panel.show()
	_icons.queue_redraw()
	_layout()


## Icônes alignées, de gauche à droite (voir _icons).
func icon_list() -> Array:
	var out: Array = ["renaissance"]
	if roundi(float(info.get("dropped", 0.0))) > 0:
		out.append("seve")
	if roundi(float(info.get("lost", 0.0))) > 0:
		out.append("seve_perdue")
	if str(info.get("reset", "")) in ["coeur", "boss"]:
		out.append("reprise")
	out.append("arbre")
	return out


func _draw_icons() -> void:
	var list := icon_list()
	var gap := 92.0
	var x0 := _icons.size.x / 2.0 - gap * (list.size() - 1) / 2.0
	var font := UiTheme.font(true)
	for i in list.size():
		var c := Vector2(x0 + gap * i, 36.0)
		match str(list[i]):
			"renaissance":
				# La flamme du sanctuaire, sur sa pierre.
				_icons.draw_rect(Rect2(c + Vector2(-16, 14), Vector2(32, 8)), Color(UiTheme.INK, 0.8))
				_flame(c + Vector2(0, 6), 1.0, Art.ec("seve", "clair"))
			"seve":
				_drop(c, Color("e8d36b"))
				var n := str(roundi(float(info.get("dropped", 0.0))))
				var w := font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
				_icons.draw_string(font, Vector2(c.x - w / 2.0, c.y + 44.0), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.GOLD)
			"seve_perdue":
				_drop(c, Color(UiTheme.RED, 0.8))
				_icons.draw_line(c + Vector2(-18, -18), c + Vector2(18, 18), UiTheme.RED, 3.0, true)
			"reprise":
				# Une flèche qui revient sur elle-même : le siège ou le boss repart de zéro.
				_icons.draw_arc(c, 16.0, 0.4, TAU - 0.4, 24, UiTheme.RED, 3.0, true)
				var tip := c + Vector2.from_angle(0.4) * 16.0
				_icons.draw_colored_polygon(PackedVector2Array([tip + Vector2(-2, -9), tip + Vector2(8, 2), tip + Vector2(-6, 5)]), UiTheme.RED)
			"arbre":
				# Une feuille saine : l'Arbre de vie est intact.
				UiTheme.draw_leaf(_icons, c + Vector2(-14, 10), -0.7, 34.0, 11.0, Color("8fc76f"), Color("8fc76f", 0.35), 1.6)


func _drop(c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI / 2.0 + TAU * i / 16.0
		var r := 13.0
		var p := c + Vector2(0, 6) + Vector2.from_angle(a) * r
		if a > PI and a < TAU:
			p.y -= (1.0 - absf(cos(a))) * 18.0 * absf(sin(a))
		pts.append(p)
	_icons.draw_colored_polygon(pts, Color(col, 0.85))


func _flame(c: Vector2, k: float, col: Color) -> void:
	var f := 1.0 + 0.08 * sin(t * 9.0)
	var pts := PackedVector2Array([c + Vector2(0, -26) * f * k, c + Vector2(10, -6) * k, c + Vector2(6, 6) * k, c + Vector2(-6, 6) * k, c + Vector2(-10, -6) * k])
	_icons.draw_colored_polygon(pts, Color(col, 0.9))


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
		_fuse.queue_redraw()
		if time_left <= 0.0:
			_veil.hide()
			_panel.hide()
	_update_pointer()


## Feuille flétrie, gravée en rouge : elle penche et se recroqueville.
func _draw_leaf(c: Control) -> void:
	var p := Vector2(c.size.x / 2.0 - 30.0, 30.0)
	var col := Color(UiTheme.RED, 0.8)
	UiTheme.draw_leaf(c, p, 0.6, 66.0, 17.0, col, Color(UiTheme.RED, 0.12), 1.3)
	var d := Vector2.from_angle(0.6)
	for i in 5:
		var q := p + d * (12.0 + i * 10.0)
		c.draw_line(q, q + Vector2.from_angle(0.6 - 1.1) * (11.0 - i), Color(UiTheme.RED, 0.5), 0.9, true)
		c.draw_line(q, q + Vector2.from_angle(0.6 + 1.1) * (9.0 - i), Color(UiTheme.RED, 0.35), 0.9, true)


func _draw_fuse() -> void:
	var cx := _fuse.size.x / 2.0
	var y := 26.0
	var k := clampf(time_left / DURATION, 0.0, 1.0)
	_fuse.draw_line(Vector2(cx - 140, y), Vector2(cx + 140, y), Color(UiTheme.RED, 0.2), 1.0, true)
	_fuse.draw_line(Vector2(cx - 140, y), Vector2(cx - 140 + 280 * k, y), Color(UiTheme.RED, 0.75), 1.5, true)
	_fuse.draw_circle(Vector2(cx - 140 + 280 * k, y), 2.5, Color("f4b08f"))


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
			_pointer_label.text = str(roundi(sap.amount))
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
	_pointer.draw_colored_polygon(PackedVector2Array([p + d * 14.0, p - d * 10.0 + side * 11.0, p - d * 4.0, p - d * 10.0 - side * 11.0]), UiTheme.GOLD)
