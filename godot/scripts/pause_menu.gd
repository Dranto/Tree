## Menu pause (direction « Herbier ») : un cadre orné au centre, entrées centrées. Échap (ou Start à la manette) met le jeu en pause (sauf quand l'Arbre de vie est ouvert, qui gère déjà Échap).
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const OptionsPanel = preload("res://scripts/options_panel.gd")

var main
var menu_panel: PanelContainer
var resume_button: Button
var options: PanelContainer
## Rappel discret sous les entrées : niveau et nœuds appris.
var footer: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	visible = false

	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", UiTheme.cadre(true, Color(UiTheme.PAPER, 0.97), UiTheme.GOLD, 44))
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(menu_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	menu_panel.add_child(col)
	var kicker := Label.new()
	kicker.text = "LE MONDE RETIENT SON SOUFFLE"
	kicker.add_theme_font_override("font", UiTheme.serif(500, 3))
	kicker.add_theme_font_size_override("font_size", UiTheme.fs(14))
	kicker.add_theme_color_override("font_color", Color(UiTheme.GOLD, 0.75))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	var title := Label.new()
	title.text = "Pause"
	title.add_theme_font_override("font", UiTheme.display(600, 2))
	title.add_theme_font_size_override("font_size", UiTheme.fs(50))
	title.add_theme_color_override("font_color", UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var divider := Control.new()
	divider.custom_minimum_size = Vector2(300, 30)
	divider.draw.connect(func(): UiTheme.draw_divider(divider, divider.size.x / 2.0, 8.0, 120.0))
	col.add_child(divider)
	resume_button = UiTheme.menu_item(Loc.key("Reprendre"), 30, HORIZONTAL_ALIGNMENT_CENTER, 320)
	resume_button.pressed.connect(close)
	col.add_child(resume_button)
	var opt := UiTheme.menu_item(Loc.key("Options"), 30, HORIZONTAL_ALIGNMENT_CENTER, 320)
	opt.pressed.connect(_open_options)
	col.add_child(opt)
	var title_btn := UiTheme.menu_item(Loc.key("Retour au titre"), 30, HORIZONTAL_ALIGNMENT_CENTER, 320)
	title_btn.pressed.connect(Flow.go_title)
	col.add_child(title_btn)
	if not OS.has_feature("web"):
		var quit := UiTheme.menu_item(Loc.key("Quitter"), 30, HORIZONTAL_ALIGNMENT_CENTER, 320)
		quit.pressed.connect(Flow.quit)
		col.add_child(quit)
	footer = Label.new()
	footer.add_theme_font_size_override("font_size", UiTheme.fs(16))
	footer.add_theme_color_override("font_color", Color(UiTheme.SOFT, 0.85))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(footer)

	options = OptionsPanel.new()
	options.visible = false
	options.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	options.grow_horizontal = Control.GROW_DIRECTION_BOTH
	options.grow_vertical = Control.GROW_DIRECTION_BOTH
	options.closed.connect(func(): menu_panel.visible = true; resume_button.grab_focus())
	add_child(options)


func _draw() -> void:
	# Voile brun chaud et coins assombris : le jeu reste deviné derrière.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.045, 0.03, 0.72))
	var edge := Color(0, 0, 0, 0.0)
	var dark := Color(0, 0, 0, 0.45)
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h * 0.22), Vector2(0, h * 0.22)]), PackedColorArray([dark, dark, edge, edge]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.78), Vector2(w, h * 0.78), Vector2(w, h), Vector2(0, h)]), PackedColorArray([edge, edge, dark, dark]))


## Échap ou Start ouvrent la pause ; Échap, Start ou B (manette) la referment. B seul n'ouvre rien :
## en jeu, c'est une compétence.
func _unhandled_input(event: InputEvent) -> void:
	var pause := InputMap.has_action("pause") and event.is_action_pressed("pause")
	if not pause and not (visible and event.is_action_pressed("ui_cancel")):
		return
	if visible:
		# Le panneau d'options gère lui-même Échap quand il est ouvert.
		if not options.visible:
			get_viewport().set_input_as_handled()
			close()
	elif not get_tree().paused:
		get_viewport().set_input_as_handled()
		open()


func open() -> void:
	visible = true
	get_tree().paused = true
	menu_panel.visible = true
	options.visible = false
	footer.text = tr("Niveau %d  ·  %d nœuds appris") % [Game.level, Game.allocated.size()]
	resume_button.grab_focus()
	queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false


func _open_options() -> void:
	menu_panel.visible = false
	options.open()
