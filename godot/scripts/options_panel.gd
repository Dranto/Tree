## Panneau d'options : volume, plein écran, aide de départ. Les changements s'appliquent et s'enregistrent aussitôt.
extends PanelContainer

signal closed

const UiTheme = preload("res://scripts/ui_theme.gd")

var volume_slider: HSlider
var volume_label: Label
var fullscreen_box: CheckBox
var hints_box: CheckBox
var back_button: Button


func _ready() -> void:
	theme = UiTheme.make()
	custom_minimum_size = Vector2(520, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	add_child(col)

	var title := Label.new()
	title.text = "Options"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var lbl := Label.new()
	lbl.text = "Volume"
	lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lbl)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = Settings.volume
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.focus_mode = Control.FOCUS_ALL
	volume_slider.value_changed.connect(_on_volume)
	row.add_child(volume_slider)
	volume_label = Label.new()
	volume_label.custom_minimum_size = Vector2(60, 0)
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(volume_label)
	_update_volume_label()

	fullscreen_box = CheckBox.new()
	fullscreen_box.text = "Plein écran"
	fullscreen_box.button_pressed = Settings.fullscreen
	fullscreen_box.toggled.connect(func(on): Settings.set_fullscreen(on); Settings.save_settings())
	col.add_child(fullscreen_box)

	hints_box = CheckBox.new()
	hints_box.text = "Afficher l'aide de départ en jeu"
	hints_box.button_pressed = Settings.show_hints
	hints_box.toggled.connect(func(on): Settings.set_show_hints(on); Settings.save_settings())
	col.add_child(hints_box)

	back_button = UiTheme.button("Retour", 200)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(close)
	col.add_child(back_button)


func _on_volume(v: float) -> void:
	Settings.set_volume(v)
	Settings.save_settings()
	_update_volume_label()


func _update_volume_label() -> void:
	volume_label.text = "%d %%" % roundi(volume_slider.value * 100.0)


func open() -> void:
	visible = true
	volume_slider.value = Settings.volume
	fullscreen_box.button_pressed = Settings.fullscreen
	hints_box.button_pressed = Settings.show_hints
	volume_slider.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
