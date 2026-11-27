## Barre d'affrontement en haut de l'écran : vie de la Mère-Ronce ou corruption du Cœur de flétrissure.
## Nœuds Control avec le thème commun ; cachée hors affrontement. Elle vit dans le calque du HUD,
## donc l'audit des tests visuels la relève avec le reste de l'écran de jeu (UiAudit.scan_controls).
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")

const WIDTH := 480.0
const TOP := 16.0

## Paliers marqués sur la barre (parts de 0 à 1), par exemple les changements de phase.
var marks: Array = []

var _title: Label
var _sub: Label
var _bar: ProgressBar
var _fill: StyleBoxFlat
var _ticks: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.make()
	visible = false
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 3)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, int(TOP))
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", UiTheme.font(true))
	_title.add_theme_font_size_override("font_size", UiTheme.fs(20))
	_title.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(_title)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.custom_minimum_size = Vector2(WIDTH, 16)
	_bar.add_theme_stylebox_override("background", UiTheme.box(Color(0.1, 0.05, 0.06, 0.9), Color(0.9, 0.8, 0.7, 0.35), 1, 3))
	_fill = UiTheme.box(Color("c84b44"), Color(0, 0, 0, 0), 0, 3)
	_bar.add_theme_stylebox_override("fill", _fill)
	box.add_child(_bar)
	_ticks = Control.new()
	_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ticks.draw.connect(_draw_ticks)
	_bar.add_child(_ticks)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", UiTheme.fs(18))
	_sub.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
	box.add_child(_sub)


## Affiche la barre : titre, part restante (0 à 1), ligne d'état et couleur du remplissage.
func show_bar(title: String, ratio: float, sub: String, color: Color) -> void:
	visible = true
	_title.text = title
	_sub.text = sub
	_bar.value = clampf(ratio, 0.0, 1.0)
	if _fill.bg_color != color:
		_fill.bg_color = color
	_ticks.queue_redraw()


func hide_bar() -> void:
	visible = false


func _draw_ticks() -> void:
	for m in marks:
		var x: float = _ticks.size.x * float(m)
		_ticks.draw_line(Vector2(x, 0), Vector2(x, _ticks.size.y), Color(0.05, 0.03, 0.03, 0.85), 2.0)
