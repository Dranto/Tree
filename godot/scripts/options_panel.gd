## Panneau d'options : volume, plein écran, aide de départ, difficulté, déplacement, visée, commandes de la barre de compétences. Les changements s'appliquent et s'enregistrent aussitôt.
extends PanelContainer

signal closed

const UiTheme = preload("res://scripts/ui_theme.gd")
const Difficulty = preload("res://scripts/difficulty.gd")

var volume_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var fullscreen_box: CheckBox
var hints_box: CheckBox
var numbers_box: CheckBox
var shake_slider: HSlider
var shake_label: Label
var reduce_box: CheckBox
var difficulty_select: OptionButton
var difficulty_hint: Label
var back_button: Button
var move_select: OptionButton
var move_hint: Label
var aim_select: OptionButton
var aim_hint: Label
## Boutons des commandes de la barre (un par emplacement, plus la touche du clic droit en mode
## « moba », MOBA_ROW) et emplacement en attente d'une touche ou d'un clic.
var slot_buttons: Array = []
var listening := -1
var keys_hint: Label
var _scroll: ScrollContainer
var _content: VBoxContainer
const MOBA_ROW := 6
const SLOT_LABELS := ["Compétence principale 1", "Compétence principale 2", "Compétence secondaire 1", "Compétence secondaire 2", "Compétence secondaire 3", "Compétence secondaire 4"]


func _ready() -> void:
	theme = UiTheme.make()
	custom_minimum_size = Vector2(520, 0)
	# Le contenu défile : à 1280 x 720 le panneau entier ne tient pas à l'écran.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(col)
	_content = col
	get_viewport().size_changed.connect(_fit)

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
	numbers_box = CheckBox.new()
	numbers_box.text = "Afficher les chiffres de dégâts"
	numbers_box.button_pressed = Settings.show_damage_numbers
	numbers_box.toggled.connect(func(on): Settings.show_damage_numbers = on; Settings.save_settings())
	col.add_child(numbers_box)

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

	# Difficulté : vie et dégâts des ennemis (Normal par défaut).
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 14)
	col.add_child(diff_row)
	var diff_name := Label.new()
	diff_name.text = "Difficulté"
	diff_name.custom_minimum_size = Vector2(110, 0)
	diff_row.add_child(diff_name)
	difficulty_select = OptionButton.new()
	difficulty_select.focus_mode = Control.FOCUS_ALL
	difficulty_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in Settings.DIFFICULTIES:
		difficulty_select.add_item(Difficulty.mode_name(id))
	difficulty_select.item_selected.connect(_on_difficulty)
	diff_row.add_child(difficulty_select)
	difficulty_hint = Label.new()
	difficulty_hint.add_theme_font_size_override("font_size", 13)
	difficulty_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
	difficulty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(difficulty_hint)
	_update_difficulty()

	# Déplacement : suivre le curseur (par défaut), clic droit façon MOBA, ou clavier.
	var move_row := HBoxContainer.new()
	move_row.add_theme_constant_override("separation", 14)
	col.add_child(move_row)
	var move_name := Label.new()
	move_name.text = "Déplacement"
	move_name.custom_minimum_size = Vector2(110, 0)
	move_row.add_child(move_name)
	move_select = OptionButton.new()
	move_select.focus_mode = Control.FOCUS_ALL
	move_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in Settings.MOVE_MODES:
		move_select.add_item(Settings.MOVE_MODE_NAMES[id])
	move_select.item_selected.connect(_on_move_mode)
	move_row.add_child(move_select)
	move_hint = Label.new()
	move_hint.add_theme_font_size_override("font_size", 13)
	move_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
	move_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(move_hint)
	_update_move_mode()

	# Visée de l'attaque automatique : l'ennemi le plus proche du curseur, ou toujours le curseur.
	var aim_row := HBoxContainer.new()
	aim_row.add_theme_constant_override("separation", 14)
	col.add_child(aim_row)
	var aim_name := Label.new()
	aim_name.text = "Visée"
	aim_name.custom_minimum_size = Vector2(110, 0)
	aim_row.add_child(aim_name)
	aim_select = OptionButton.new()
	aim_select.focus_mode = Control.FOCUS_ALL
	aim_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in Settings.AIM_MODES:
		aim_select.add_item(Settings.AIM_MODE_NAMES[id])
	aim_select.item_selected.connect(_on_aim_mode)
	aim_row.add_child(aim_select)
	aim_hint = Label.new()
	aim_hint.add_theme_font_size_override("font_size", 13)
	aim_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
	aim_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(aim_hint)
	_update_aim_mode()

	var keys_title := Label.new()
	keys_title.text = "Commandes des compétences"
	col.add_child(keys_title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for i in Settings.SLOT_COUNT + 1:
		var l := Label.new()
		l.text = "Principale 2, mode MOBA" if i == MOBA_ROW else SLOT_LABELS[i].replace("Compétence p", "P").replace("Compétence s", "S")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(100, 0)
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
		if listening == i:
			b.text = "…"
		elif i == MOBA_ROW:
			b.text = Settings.code_name(Settings.moba_main_2_key)
		else:
			var digit: int = Settings.SLOT_DIGITS[i]
			var name := Settings.code_name(Settings.bindings[i])
			b.text = name if digit == KEY_NONE else "%s (ou %s)" % [name, Settings.key_name(digit)]
	if listening == MOBA_ROW:
		keys_hint.text = "Appuie sur une touche pour la compétence principale 2 en mode MOBA (Échap : annuler)."
	elif listening >= 0:
		keys_hint.text = "Appuie sur une touche ou un bouton de la souris pour : %s (Échap : annuler, Retour arrière : aucune)." % SLOT_LABELS[listening].to_lower()
	elif keys_hint.text.begins_with("Appuie"):
		keys_hint.text = ""


## Pendant l'attente d'une commande : la touche ou le bouton de souris pressé est assigné à
## l'emplacement, sauf si une autre commande du jeu (déplacement, esquive, arbre) l'utilise déjà.
## La ligne du mode MOBA n'accepte qu'une touche (le clic droit y sert à marcher).
func _input(event: InputEvent) -> void:
	if listening < 0 or not visible:
		return
	var code := KEY_NONE
	var k := event as InputEventKey
	var m := event as InputEventMouseButton
	if k != null and k.pressed and not k.echo:
		code = k.physical_keycode
	elif m != null and m.pressed and listening != MOBA_ROW and m.button_index in Settings.MOUSE_BUTTONS:
		code = -m.button_index
	else:
		return
	get_viewport().set_input_as_handled()
	var i := listening
	listening = -1
	if code == KEY_ESCAPE:
		pass
	elif code == KEY_BACKSPACE and i != MOBA_ROW:
		Settings.set_binding(i, KEY_NONE)
		Settings.save_settings()
	elif code > 0 and Settings.key_owner(code) != "":
		keys_hint.text = "%s est déjà utilisée par une autre commande." % Settings.code_name(code)
	elif i == MOBA_ROW:
		Settings.set_moba_main_2_key(code)
		Settings.save_settings()
		keys_hint.text = ""
	else:
		Settings.set_binding(i, code)
		Settings.save_settings()
		keys_hint.text = ""
	_update_keys()
	_update_move_mode()


func _on_difficulty(index: int) -> void:
	Settings.set_difficulty(Settings.DIFFICULTIES[index])
	Settings.save_settings()
	_update_difficulty()


func _update_difficulty() -> void:
	difficulty_select.select(maxi(0, Settings.DIFFICULTIES.find(Settings.difficulty)))
	difficulty_hint.text = str(Difficulty.mode(Settings.difficulty).get("text", ""))


func _on_move_mode(index: int) -> void:
	Settings.set_move_mode(Settings.MOVE_MODES[index])
	Settings.save_settings()
	_update_move_mode()


func _update_move_mode() -> void:
	move_select.select(maxi(0, Settings.MOVE_MODES.find(Settings.move_mode)))
	move_hint.text = Settings.move_mode_text(Settings.move_mode)


func _on_aim_mode(index: int) -> void:
	Settings.set_aim_mode(Settings.AIM_MODES[index])
	Settings.save_settings()
	_update_aim_mode()


func _update_aim_mode() -> void:
	aim_select.select(maxi(0, Settings.AIM_MODES.find(Settings.aim_mode)))
	aim_hint.text = Settings.aim_mode_text(Settings.aim_mode)


func _on_shake(v: float) -> void:
	Settings.set_shake(v)
	Settings.save_settings()
	_update_shake_label()


func _update_shake_label() -> void:
	shake_label.text = "Aucune" if shake_slider.value <= 0.001 else "%d %%" % roundi(shake_slider.value * 100.0)


## Hauteur du panneau : tout le contenu s'il tient, sinon 90 % de la fenêtre (le reste défile).
func _fit() -> void:
	if _scroll == null:
		return
	var room := get_viewport().get_visible_rect().size.y * 0.9 - 40.0
	_scroll.custom_minimum_size = Vector2(0, minf(_content.get_combined_minimum_size().y, room))


func open() -> void:
	visible = true
	_fit.call_deferred()
	listening = -1
	keys_hint.text = ""
	_update_keys()
	volume_slider.value = Settings.volume
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	fullscreen_box.button_pressed = Settings.fullscreen
	hints_box.button_pressed = Settings.show_hints
	numbers_box.button_pressed = Settings.show_damage_numbers
	shake_slider.value = Settings.shake
	reduce_box.button_pressed = Settings.reduce_effects
	_update_difficulty()
	_update_move_mode()
	_update_aim_mode()
	volume_slider.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
