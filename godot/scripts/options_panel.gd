## Panneau d'options : volume, plein écran, aide de départ, touches de la barre de compétences. Les changements s'appliquent et s'enregistrent aussitôt.
extends PanelContainer

signal closed

const UiTheme = preload("res://scripts/ui_theme.gd")

var volume_slider: HSlider
var volume_label: Label
var fullscreen_box: CheckBox
var hints_box: CheckBox
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


func _on_volume(v: float) -> void:
	Settings.set_volume(v)
	Settings.save_settings()
	_update_volume_label()


func _update_volume_label() -> void:
	volume_label.text = "%d %%" % roundi(volume_slider.value * 100.0)


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


func open() -> void:
	visible = true
	listening = -1
	keys_hint.text = ""
	_update_keys()
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
