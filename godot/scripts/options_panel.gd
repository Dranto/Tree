## Panneau d'options (direction « Herbier ») : cadre orné et quatre onglets (Son, Affichage, Jeu,
## Commandes). Volume, plein écran, glyphes du tutoriel, accessibilité (contraste, taille du texte, mode
## daltonien, secousse, éclats, micro-pauses), rafales de vent, difficulté, déplacement, visée,
## pause hors focus, toutes les commandes. Les changements s'appliquent et s'enregistrent aussitôt.
extends PanelContainer

signal closed

const UiTheme = preload("res://scripts/ui_theme.gd")
const Difficulty = preload("res://scripts/difficulty.gd")

var volume_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var fullscreen_box: CheckBox
var hints_box: CheckBox
var numbers_select: OptionButton
var shake_slider: HSlider
var shake_label: Label
var wind_slider: HSlider
var wind_label: Label
var reduce_box: CheckBox
var flash_slider: HSlider
var hitstop_slider: HSlider
var contrast_box: CheckBox
var text_select: OptionButton
var colorblind_select: OptionButton
var access_hint: Label
var focus_box: CheckBox
## Boutons des commandes du jeu (Settings.GAME_ACTIONS), écoutés à partir de ACTION_ROW0.
var action_buttons: Array = []
const ACTION_ROW0 := 100
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
const TAB_NAMES := ["Son", "Affichage", "Jeu", "Commandes"]
## Largeur des libellés devant les curseurs et les listes.
const LABEL_W := 170.0
var pages: Array = []
var tab_buttons: Array = []
var tab := 0
const SLOT_LABELS := ["Compétence principale 1", "Compétence principale 2", "Compétence secondaire 1", "Compétence secondaire 2", "Compétence secondaire 3", "Compétence secondaire 4"]


func _ready() -> void:
	theme = UiTheme.make()
	add_theme_stylebox_override("panel", UiTheme.cadre(true, Color(UiTheme.PAPER, 0.97), UiTheme.GOLD, 44))
	custom_minimum_size = Vector2(680, 0)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	add_child(outer)
	var title := Label.new()
	title.text = "Options"
	title.add_theme_font_override("font", UiTheme.display(600, 2))
	title.add_theme_font_size_override("font_size", UiTheme.fs(46))
	title.add_theme_color_override("font_color", UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	# Onglets : Son, Affichage, Jeu, Commandes (un seul visible à la fois).
	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 8)
	outer.add_child(tab_row)
	var rule := Control.new()
	rule.custom_minimum_size = Vector2(0, 8)
	rule.draw.connect(func(): rule.draw_line(Vector2(0, 0), Vector2(rule.size.x, 0), Color(UiTheme.GOLD, 0.25), 1.0))
	outer.add_child(rule)
	# Le contenu défile si besoin : à 1280 x 720 une page longue peut ne pas tenir.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	outer.add_child(_scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(col)
	_content = col
	get_viewport().size_changed.connect(_fit)
	var group := ButtonGroup.new()
	for i in TAB_NAMES.size():
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 16)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(page)
		pages.append(page)
		var tb := _tab_button(TAB_NAMES[i], group)
		tb.pressed.connect(show_tab.bind(i))
		tab_row.add_child(tb)
		tab_buttons.append(tb)
	var p_son: VBoxContainer = pages[0]
	var p_aff: VBoxContainer = pages[1]
	var p_jeu: VBoxContainer = pages[2]
	var p_cmd: VBoxContainer = pages[3]

	volume_slider = _slider_row(p_son, "Volume général", Settings.volume, _on_volume)
	music_slider = _slider_row(p_son, "Musique", Settings.music_volume, func(v): Settings.set_music_volume(v); Settings.save_settings(); _update_labels())
	sfx_slider = _slider_row(p_son, "Effets", Settings.sfx_volume, func(v): Settings.set_sfx_volume(v); Settings.save_settings(); _update_labels())
	_update_labels()

	fullscreen_box = CheckBox.new()
	fullscreen_box.text = "Plein écran"
	fullscreen_box.button_pressed = Settings.fullscreen
	fullscreen_box.toggled.connect(func(on): Settings.set_fullscreen(on); Settings.save_settings())
	p_aff.add_child(fullscreen_box)
	hints_box = CheckBox.new()
	hints_box.text = "Afficher les glyphes de touches (tutoriel)"
	hints_box.button_pressed = Settings.show_hints
	hints_box.toggled.connect(func(on): Settings.set_show_hints(on); Settings.save_settings())
	p_aff.add_child(hints_box)
	numbers_select = _select_row(p_aff, "Chiffres de dégâts")
	for id in Settings.DAMAGE_NUMBERS:
		numbers_select.add_item(Settings.DAMAGE_NUMBERS_NAMES[id])
	numbers_select.select(Settings.DAMAGE_NUMBERS.find(Settings.damage_numbers))
	numbers_select.item_selected.connect(func(i): Settings.set_damage_numbers(Settings.DAMAGE_NUMBERS[i]); Settings.save_settings())
	reduce_box = CheckBox.new()
	reduce_box.text = "Réduire les effets (secousse, micro-pause, particules)"
	reduce_box.button_pressed = Settings.reduce_effects
	reduce_box.toggled.connect(func(on): Settings.set_reduce_effects(on); Settings.save_settings())
	p_aff.add_child(reduce_box)
	shake_slider = _slider_row(p_aff, "Secousse", Settings.shake_scale, _on_shake, 0.1)
	shake_label = shake_slider.get_meta("label")
	_update_shake_label()
	flash_slider = _slider_row(p_aff, "Éclats lumineux", Settings.flash_scale, func(v): Settings.set_flash(v); Settings.save_settings(); _update_pct(flash_slider, "Aucun"), 0.1)
	hitstop_slider = _slider_row(p_aff, "Micro-pauses", Settings.hitstop_scale, func(v): Settings.hitstop_scale = v; Settings.save_settings(); _update_pct(hitstop_slider, "Aucune"), 0.1)
	_update_pct(flash_slider, "Aucun")
	_update_pct(hitstop_slider, "Aucune")
	# Accessibilité : contraste, taille du texte, mode daltonien.
	contrast_box = CheckBox.new()
	contrast_box.text = "Contraste renforcé"
	contrast_box.button_pressed = Settings.high_contrast
	contrast_box.toggled.connect(func(on): Settings.set_high_contrast(on); Settings.save_settings(); _update_access())
	p_aff.add_child(contrast_box)
	text_select = _select_row(p_aff, "Taille du texte")
	for n in Settings.TEXT_SCALE_NAMES:
		text_select.add_item(n)
	text_select.item_selected.connect(func(i): Settings.set_text_scale(Settings.TEXT_SCALES[i]); Settings.save_settings(); _update_access())
	colorblind_select = _select_row(p_aff, "Mode daltonien")
	for id in Settings.COLORBLIND_MODES:
		colorblind_select.add_item(Settings.COLORBLIND_NAMES[id])
	colorblind_select.item_selected.connect(func(i): Settings.set_colorblind_mode(Settings.COLORBLIND_MODES[i]); Settings.save_settings(); _update_access())
	access_hint = _hint(p_aff)
	_update_access()

	# Difficulté : vie et dégâts des ennemis (Normal par défaut).
	difficulty_select = _select_row(p_jeu, "Difficulté")
	for id in Settings.DIFFICULTIES:
		difficulty_select.add_item(Difficulty.mode_name(id))
	difficulty_select.item_selected.connect(_on_difficulty)
	difficulty_hint = _hint(p_jeu)
	_update_difficulty()
	# Déplacement : suivre le curseur (par défaut), clic droit façon MOBA, ou clavier.
	move_select = _select_row(p_jeu, "Déplacement")
	for id in Settings.MOVE_MODES:
		move_select.add_item(Settings.MOVE_MODE_NAMES[id])
	move_select.item_selected.connect(_on_move_mode)
	move_hint = _hint(p_jeu)
	_update_move_mode()
	# Visée de l'attaque automatique : l'ennemi le plus proche du curseur, ou toujours le curseur.
	aim_select = _select_row(p_jeu, "Visée")
	for id in Settings.AIM_MODES:
		aim_select.add_item(Settings.AIM_MODE_NAMES[id])
	aim_select.item_selected.connect(_on_aim_mode)
	aim_hint = _hint(p_jeu)
	_update_aim_mode()
	# Rafales de la région de Vent (wind.gd) : elles poussent le joueur et dévient les projectiles.
	wind_slider = _slider_row(p_jeu, "Rafales", Settings.wind, _on_wind, 0.1)
	wind_label = wind_slider.get_meta("label")
	_update_wind_label()
	focus_box = CheckBox.new()
	focus_box.text = "Mettre en pause quand la fenêtre perd le focus"
	focus_box.button_pressed = Settings.pause_on_focus_loss
	focus_box.toggled.connect(func(on): Settings.set_pause_on_focus_loss(on); Settings.save_settings())
	p_jeu.add_child(focus_box)

	var keys_title := Label.new()
	keys_title.text = "Commandes des compétences"
	keys_title.add_theme_color_override("font_color", UiTheme.GOLD)
	p_cmd.add_child(keys_title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	p_cmd.add_child(grid)
	for i in Settings.SLOT_COUNT + 1:
		var l := Label.new()
		l.text = "Principale 2, mode MOBA" if i == MOBA_ROW else SLOT_LABELS[i]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 0)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_listen.bind(i))
		grid.add_child(b)
		slot_buttons.append(b)
	var game_title := Label.new()
	game_title.text = "Commandes du jeu"
	game_title.add_theme_color_override("font_color", UiTheme.GOLD)
	p_cmd.add_child(game_title)
	var grid2 := GridContainer.new()
	grid2.columns = 2
	grid2.add_theme_constant_override("h_separation", 16)
	grid2.add_theme_constant_override("v_separation", 8)
	p_cmd.add_child(grid2)
	for i in Settings.GAME_ACTIONS.size():
		var l := Label.new()
		l.text = Settings.GAME_ACTION_NAMES[Settings.GAME_ACTIONS[i]]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid2.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 0)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_listen.bind(ACTION_ROW0 + i))
		grid2.add_child(b)
		action_buttons.append(b)
	keys_hint = _hint(p_cmd)
	var reset := Button.new()
	reset.text = "Rétablir les commandes par défaut"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.focus_mode = Control.FOCUS_ALL
	reset.pressed.connect(func(): Settings.reset_bindings(); Settings.save_settings(); listening = -1; _update_keys(); _update_move_mode())
	p_cmd.add_child(reset)
	_update_keys()

	back_button = UiTheme.menu_item("Retour", 28, HORIZONTAL_ALIGNMENT_CENTER, 240)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(close)
	outer.add_child(back_button)
	show_tab(0)


## Onglet : texte seul, en or et souligné quand il est ouvert.
func _tab_button(text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(140, 40)
	b.add_theme_font_size_override("font_size", UiTheme.fs(25))
	var pad := StyleBoxEmpty.new()
	pad.content_margin_bottom = 6
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, pad)
	b.add_theme_color_override("font_color", UiTheme.SOFT)
	b.add_theme_color_override("font_hover_color", UiTheme.INK)
	b.add_theme_color_override("font_focus_color", UiTheme.INK)
	b.add_theme_color_override("font_pressed_color", UiTheme.GOLD)
	b.add_theme_color_override("font_hover_pressed_color", UiTheme.GOLD)
	b.draw.connect(func():
		var w := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.fs(25)).x
		var y := b.size.y - 2.0
		if b.button_pressed:
			b.draw_line(Vector2((b.size.x - w) / 2.0 - 6, y), Vector2((b.size.x + w) / 2.0 + 6, y), UiTheme.GOLD, 1.5, true)
		elif b.has_focus():
			b.draw_line(Vector2((b.size.x - w) / 2.0, y), Vector2((b.size.x + w) / 2.0, y), Color(UiTheme.GOLD, 0.5), 1.0, true))
	b.focus_entered.connect(b.queue_redraw)
	b.focus_exited.connect(b.queue_redraw)
	b.mouse_entered.connect(func(): Sfx.play("survol"))
	b.pressed.connect(func(): Sfx.play("clic"))
	return b


## Ouvre l'onglet i (0 Son, 1 Affichage, 2 Jeu, 3 Commandes).
func show_tab(i: int) -> void:
	tab = i
	for k in pages.size():
		pages[k].visible = k == i
		tab_buttons[k].set_pressed_no_signal(k == i)
		tab_buttons[k].queue_redraw()
	_fit.call_deferred()


func _select_row(parent: Control, text: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var name := Label.new()
	name.text = text
	name.custom_minimum_size = Vector2(LABEL_W, 0)
	row.add_child(name)
	var sel := OptionButton.new()
	sel.focus_mode = Control.FOCUS_ALL
	sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sel)
	return sel


func _hint(parent: Control) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", UiTheme.fs(17))
	l.add_theme_color_override("font_color", UiTheme.SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


## Une ligne « nom, curseur, pourcentage ». Le libellé du pourcentage est rangé dans la méta « label » du curseur.
func _slider_row(parent: Control, text: String, value: float, on_change: Callable, step := 0.05) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(LABEL_W, 0)
	row.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = step
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_ALL
	sl.value_changed.connect(on_change)
	row.add_child(sl)
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(76, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_color_override("font_color", UiTheme.GOLD)
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
	for i in action_buttons.size():
		var a: String = Settings.GAME_ACTIONS[i]
		var extra: Array = Settings.ACTION_EXTRAS.get(a, [])
		var txt := Settings.action_key_name(a)
		if not extra.is_empty():
			txt += " (ou %s)" % ", ".join(extra.map(func(k): return Settings.key_name(k)))
		action_buttons[i].text = "…" if listening == ACTION_ROW0 + i else txt
	if listening >= ACTION_ROW0:
		keys_hint.text = "Appuie sur une touche pour : %s (Échap : annuler)." % Settings.GAME_ACTION_NAMES[Settings.GAME_ACTIONS[listening - ACTION_ROW0]].to_lower()
	elif listening == MOBA_ROW:
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
	elif m != null and m.pressed and listening < MOBA_ROW and m.button_index in Settings.MOUSE_BUTTONS:
		code = -m.button_index
	else:
		return
	get_viewport().set_input_as_handled()
	var i := listening
	listening = -1
	if code == KEY_ESCAPE:
		pass
	elif i >= ACTION_ROW0:
		var taken := Settings.set_action_key(Settings.GAME_ACTIONS[i - ACTION_ROW0], code)
		if taken == "":
			Settings.save_settings()
			keys_hint.text = ""
		else:
			keys_hint.text = "%s est déjà utilisée : %s." % [Settings.code_name(code), taken]
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


## Pourcentage d'un curseur, ou « zero » à 0.
func _update_pct(sl: HSlider, zero: String) -> void:
	if sl != null:
		sl.get_meta("label").text = zero if sl.value <= 0.001 else "%d %%" % roundi(sl.value * 100.0)


func _update_access() -> void:
	contrast_box.button_pressed = Settings.high_contrast
	text_select.select(maxi(0, Settings.TEXT_SCALES.find(Settings.text_scale)))
	colorblind_select.select(maxi(0, Settings.COLORBLIND_MODES.find(Settings.colorblind_mode)))
	var parts: Array = []
	if Settings.colorblind_mode != "aucun":
		parts.append("Les dangers, les élites et le butin changent de teinte ; les zones d'attaque annoncées sont hachurées.")
	if Settings.high_contrast:
		parts.append("Textes secondaires et filets plus marqués, zones de danger plus opaques.")
	if Settings.text_scale != 1.0:
		parts.append("La taille du texte s'applique aux écrans ouverts ensuite.")
	access_hint.text = " ".join(parts)


func _on_wind(v: float) -> void:
	Settings.set_wind(v)
	Settings.save_settings()
	_update_wind_label()


func _update_wind_label() -> void:
	wind_label.text = "Coupées" if wind_slider.value <= 0.001 else "%d %%" % roundi(wind_slider.value * 100.0)


## Hauteur du panneau : tout le contenu s'il tient, sinon 90 % de la fenêtre (le reste défile).
func _fit() -> void:
	if _scroll == null:
		return
	# Hauteur fixe, celle de l'onglet le plus long : le cadre ne saute pas d'un onglet à l'autre.
	var room := get_viewport().get_visible_rect().size.y * 0.9 - 250.0
	var tallest := 0.0
	for page in pages:
		tallest = maxf(tallest, page.get_combined_minimum_size().y)
	_scroll.custom_minimum_size = Vector2(0, minf(tallest, room))


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
	numbers_select.select(Settings.DAMAGE_NUMBERS.find(Settings.damage_numbers))
	shake_slider.value = Settings.shake_scale
	flash_slider.value = Settings.flash_scale
	hitstop_slider.value = Settings.hitstop_scale
	focus_box.button_pressed = Settings.pause_on_focus_loss
	_update_access()
	wind_slider.value = Settings.wind
	reduce_box.button_pressed = Settings.reduce_effects
	_update_difficulty()
	_update_move_mode()
	_update_aim_mode()
	show_tab(0)
	tab_buttons[0].grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
