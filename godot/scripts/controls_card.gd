## Rappel des commandes : une grille « touche, action » à deux colonnes de paires, lue dans
## controls_text.gd. Sert au journal et à l'écran titre ; se remet à jour quand les réglages changent.
extends GridContainer

const UiTheme = preload("res://scripts/ui_theme.gd")
const Controls = preload("res://scripts/controls_text.gd")

var font_size := 14


func _init(fs := 14) -> void:
	font_size = fs
	columns = 4
	add_theme_constant_override("h_separation", 10)
	add_theme_constant_override("v_separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	Settings.changed.connect(refresh)
	refresh()


## Reconstruit la grille avec les touches du moment.
func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var rows: Array = Controls.reminder_rows()
	# Deux colonnes de paires : la première moitié à gauche, le reste à droite.
	var half := ceili(rows.size() / 2.0)
	for i in half:
		for j in [i, i + half]:
			if j < rows.size():
				_cell(str(rows[j][0]), true)
				_cell(str(rows[j][1]), false)
			else:
				_cell("", false)
				_cell("", false)


func _cell(text: String, key: bool) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(UiTheme.GOLD, 0.9) if key else UiTheme.SOFT)
	if key:
		l.add_theme_font_override("font", UiTheme.font(true))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
