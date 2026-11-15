## Panneau d'options : volume, plein écran, aide de départ, touches de la barre de compétences. Les changements s'appliquent et s'enregistrent aussitôt.
extends PanelContainer

signal closed

const UiTheme = preload("res://scripts/ui_theme.gd")

var volume_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var fullscreen_box: CheckBox
var hints_box: CheckBox
var shake_slider: HSlider
var shake_label: Label
var reduce_box: CheckBox
var back_button: Button
## Boutons des touches de la barre (un par emplacement) et emplacement en attente d'une touche.
var slot_buttons: Array = []
var listening := -1
var keys_hint: Label


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

	var shake_row := HBoxContainer.new()
	shake_row.add_theme_constant_override("separation", 14)
	col.add_child(shake_row)
	var shake_name := Label.new()
	shake_name.text = "Secousse"
	shake_name.custom_minimum_size = Vector2(110, 0)
	shake_row.add_child(shake_name)
	shake_slider = HSlider.new()
	shake_slider.min_value = 0.0
	shake_slider.max_value = 1.0
	shake_slider.step = 0.1
	shake_slider.value = Settings.shake
	shake_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shake_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shake_slider.focus_mode = Control.FOCUS_ALL
	shake_slider.value_changed.connect(_on_shake)
	shake_row.add_child(shake_slider)
	shake_label = Label.new()
	shake_label.custom_minimum_size = Vector2(60, 0)
	shake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shake_row.add_child(shake_label)
	_update_shake_label()

	reduce_box = CheckBox.new()
	reduce_box.text = "Réduire les effets (secousse, micro-pause, particules)"
	reduce_box.button_pressed = Settings.reduce_effects
	reduce_box.toggled.connect(func(on): Settings.set_reduce_effects(on); Settings.save_settings())
	col.add_child(reduce_box)

	var keys_title := Label.new()
	keys_title.text = "Touches de la barre de compétences"
	col.add_child(keys_title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for i in Settings.SLOT_COUNT:
		var l := Label.new()
		l.text = "Emplacement %d  (%d ou" % [i + 1, i + 1]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(76, 0)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_listen.bind(i))
		grid.add_child(b)
		slot_buttons.append(b)
	keys_hint = Label.new()
	keys_hint.add_theme_font_size_override("font_size", 13)
	keys_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
	keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(keys_hint)
	_update_keys()

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


func _listen(i: int) -> void:
	listening = i
	_update_keys()


func _update_keys() -> void:
	for i in slot_buttons.size():
		var b: Button = slot_buttons[i]
		b.text = "…" if listening == i else Settings.key_name(Settings.slot_keys[i]) + ")"
	if listening >= 0:
		keys_hint.text = "Appuie sur une touche pour l'emplacement %d (Échap : annuler, Retour arrière : aucune)." % (listening + 1)
	elif keys_hint.text.begins_with("Appuie"):
		keys_hint.text = ""


## Pendant l'attente d'une touche : la touche pressée est assignée à l'emplacement, sauf si
## une autre commande du jeu (déplacement, esquive, arbre) l'utilise déjà.
func _input(event: InputEvent) -> void:
	if listening < 0 or not visible:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	get_viewport().set_input_as_handled()
	var i := listening
	listening = -1
	if k.physical_keycode == KEY_ESCAPE:
		pass
	elif k.physical_keycode == KEY_BACKSPACE:
		Settings.set_slot_key(i, KEY_NONE)
		Settings.save_settings()
	elif Settings.key_owner(k.physical_keycode) != "":
		keys_hint.text = "%s est déjà utilisée par une autre commande." % Settings.key_name(k.physical_keycode)
	else:
		Settings.set_slot_key(i, k.physical_keycode)
		Settings.save_settings()
		keys_hint.text = ""
	_update_keys()


func _on_shake(v: float) -> void:
	Settings.set_shake(v)
	Settings.save_settings()
	_update_shake_label()


func _update_shake_label() -> void:
	shake_label.text = "Aucune" if shake_slider.value <= 0.001 else "%d %%" % roundi(shake_slider.value * 100.0)


func open() -> void:
	visible = true
	listening = -1
	keys_hint.text = ""
	_update_keys()
	volume_slider.value = Settings.volume
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	fullscreen_box.button_pressed = Settings.fullscreen
	hints_box.button_pressed = Settings.show_hints
	shake_slider.value = Settings.shake
	reduce_box.button_pressed = Settings.reduce_effects
	volume_slider.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
