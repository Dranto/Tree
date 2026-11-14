## Menu pause : Échap met le jeu en pause (sauf quand l'Arbre de vie est ouvert, qui gère déjà Échap).
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const OptionsPanel = preload("res://scripts/options_panel.gd")

var main
var menu_panel: PanelContainer
var resume_button: Button
var options: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	visible = false

	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(menu_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	menu_panel.add_child(col)
	var title := Label.new()
	title.text = "Pause"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	resume_button = UiTheme.button("Reprendre")
	resume_button.pressed.connect(close)
	col.add_child(resume_button)
	var opt := UiTheme.button("Options")
	opt.pressed.connect(_open_options)
	col.add_child(opt)
	var title_btn := UiTheme.button("Retour au titre")
	title_btn.pressed.connect(Flow.go_title)
	col.add_child(title_btn)
	if not OS.has_feature("web"):
		var quit := UiTheme.button("Quitter")
		quit.pressed.connect(Flow.quit)
		col.add_child(quit)

	options = OptionsPanel.new()
	options.visible = false
	options.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	options.grow_horizontal = Control.GROW_DIRECTION_BOTH
	options.grow_vertical = Control.GROW_DIRECTION_BOTH
	options.closed.connect(func(): menu_panel.visible = true; resume_button.grab_focus())
	add_child(options)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
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
	resume_button.grab_focus()
	queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false


func _open_options() -> void:
	menu_panel.visible = false
	options.open()
