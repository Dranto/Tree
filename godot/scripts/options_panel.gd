## Panneau d'options : volume, plein écran, aide de départ. Les changements s'appliquent et s'enregistrent aussitôt.
extends PanelContainer

signal closed

const UiTheme = preload("res://scripts/ui_theme.gd")

var volume_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
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

	volume_slider = _slider_row(col, "Volume", Settings.volume, _on_volume)
	music_slider = _slider_row(col, "Musique", Settings.music_volume, func(v): Settings.set_music_volume(v); Settings.save_settings(); _update_labels())
	sfx_slider = _slider_row(col, "Effets", Settings.sfx_volume, func(v): Settings.set_sfx_volume(v); Settings.save_settings(); _update_labels())
	_update_labels()

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


## Une ligne « nom, curseur, pourcentage ». Le libellé du pourcentage est rangé dans la méta « label » du curseur.
func _slider_row(parent: Control, text: String, value: float, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_ALL
	sl.value_changed.connect(on_change)
	row.add_child(sl)
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(60, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	sl.set_meta("label", pct)
	return sl


func _on_volume(v: float) -> void:
	Settings.set_volume(v)
	Settings.save_settings()
	_update_labels()


func _update_labels() -> void:
	for sl in [volume_slider, music_slider, sfx_slider]:
		if sl != null:
			sl.get_meta("label").text = "%d %%" % roundi(sl.value * 100.0)


func open() -> void:
	visible = true
	volume_slider.value = Settings.volume
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
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
