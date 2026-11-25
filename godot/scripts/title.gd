## Écran titre, direction « Herbier » : une planche botanique gravée (papier brun, filets et vrilles
## d'or, arbre de vie dessiné au trait qui bruisse doucement). Entrées : Continuer, Nouvelle
## partie, Options, Quitter. Tout est dessiné par le code.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const OptionsPanel = preload("res://scripts/options_panel.gd")
const ControlsCard = preload("res://scripts/controls_card.gd")

## Position horizontale (part de la largeur) de la colonne du titre et des boutons.
const MENU_X := 0.1

var menu: VBoxContainer
var continue_button: Button
var new_button: Button
var options_button: Button
var quit_button: Button
var options: PanelContainer
## Rappel des commandes, en bas à gauche (caché quand les options sont ouvertes).
var controls_card: Control
var font: Font
var t := 0.0
var motes: Array = []
var _vignette: Texture2D
## Mode « -- --menutest » : enregistre des captures des menus dans godot/autotest/ puis quitte.
var menutest := false


func _ready() -> void:
	Music.set_mood(0.0)
	Music.start()
	font = UiTheme.font(true)
	if Flow.skip_title:
		Flow.new_game.call_deferred()
		set_process(false)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		motes.append({"x": rng.randf(), "y": rng.randf(), "s": rng.randf_range(0.008, 0.025), "r": rng.randf_range(0.8, 2.0), "p": rng.randf() * TAU})
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.15), Color(0, 0, 0, 0.85)])
	var vt := GradientTexture2D.new()
	vt.gradient = g
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.05, 0.5)
	_vignette = vt

	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 0)
	# Colonne de gauche (10 % de la largeur), sous le titre : l'arbre gravé occupe la droite. Les
	# entrées débordent à gauche de la colonne de la place de leur feuille (marge du bouton).
	menu.anchor_left = MENU_X
	menu.anchor_right = MENU_X
	menu.offset_left = -44
	menu.anchor_top = 0.0
	menu.offset_top = 470
	menu.grow_horizontal = Control.GROW_DIRECTION_END
	add_child(menu)
	continue_button = UiTheme.menu_item(Loc.key("Continuer"), 32)
	continue_button.pressed.connect(Flow.continue_game)
	menu.add_child(continue_button)
	new_button = UiTheme.menu_item(Loc.key("Nouvelle partie"), 32)
	new_button.pressed.connect(Flow.new_game)
	menu.add_child(new_button)
	options_button = UiTheme.menu_item(Loc.key("Options"), 32)
	options_button.pressed.connect(_open_options)
	menu.add_child(options_button)
	if OS.has_feature("web"):
		pass
	else:
		quit_button = UiTheme.menu_item(Loc.key("Quitter"), 32)
		quit_button.pressed.connect(Flow.quit)
		menu.add_child(quit_button)

	controls_card = VBoxContainer.new()
	controls_card.add_theme_constant_override("separation", 4)
	controls_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_card.anchor_left = MENU_X
	controls_card.anchor_top = 1.0
	controls_card.anchor_bottom = 1.0
	controls_card.offset_bottom = -58
	controls_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(controls_card)
	controls_card.add_child(ControlsCard.new(17))

	options = OptionsPanel.new()
	options.visible = false
	options.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	options.grow_horizontal = Control.GROW_DIRECTION_BOTH
	options.grow_vertical = Control.GROW_DIRECTION_BOTH
	options.closed.connect(_close_options)
	add_child(options)

	continue_button.disabled = not Flow.has_save()
	_update_note()
	_focus_first()
	menutest = "--menutest" in OS.get_cmdline_user_args()
	if menutest:
		_menutest()


## Note de « Continuer » : niveau de la partie enregistrée.
func _update_note() -> void:
	var sum := Flow.save_summary()
	if not continue_button.disabled and sum.has("level"):
		continue_button.set("note", tr("niveau %d") % int(sum["level"]))
		if sum.get("ended", false):
			# L'aventure est finie (finale gagnée) : la partie continue, librement.
			continue_button.set("note", tr("niveau %d · fin") % int(sum["level"]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and continue_button != null:
		_update_note()


func _focus_first() -> void:
	(new_button if continue_button.disabled else continue_button).grab_focus()


func _open_options() -> void:
	menu.visible = false
	controls_card.visible = false
	options.open()


func _close_options() -> void:
	menu.visible = true
	controls_card.visible = true
	_focus_first()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	UiTheme.draw_paper(self, Rect2(0, 0, w, h), 1800)
	# Arbre de vie gravé au trait, à droite, avec sa légende de planche.
	var base := Vector2(maxf(w * 0.74, w - h * 0.5), h * 0.86)
	_engraved_tree(base, h * 0.7)
	var cap_font := UiTheme.serif(600, 3)
	var cap := tr("PLANCHE I  ·  L'ARBRE DE VIE")
	draw_string(cap_font, Vector2(base.x - cap_font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x / 2.0, base.y + 66), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UiTheme.GOLD, 0.6))
	# Pollen d'or qui monte lentement.
	for m in motes:
		var y := fmod(m["y"] - t * m["s"] + 10.0, 1.0)
		var x: float = m["x"] + sin(t * 0.4 + m["p"]) * 0.01
		var a := 0.18 + 0.14 * sin(t * 1.1 + m["p"])
		draw_circle(Vector2(x * w, y * h), m["r"], Color(UiTheme.GOLD, a))
	UiTheme.draw_frame(self, Rect2(34, 34, w - 68, h - 68), 1.15)
	# Sans titre (robots, « --autotest ») _ready s'arrête avant de la fabriquer : le dernier dessin avant le changement de scène s'en passe.
	if _vignette != null:
		draw_texture_rect(_vignette, Rect2(-w * 0.1, -h * 0.25, w * 1.2, h * 1.5), false, Color(1, 1, 1, 0.5))
	# Titre, aligné à gauche sur la colonne des entrées.
	var x := w * MENU_X
	var kicker := UiTheme.serif(500, 3)
	draw_string(kicker, Vector2(x, 140), tr("HERBIER  DES  TERRES  FLÉTRIES"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UiTheme.GOLD, 0.8))
	draw_string(UiTheme.display(600, 4), Vector2(x - 5, 290), Loc.game_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 133, UiTheme.INK)
	draw_line(Vector2(x, 322), Vector2(x + 350, 322), Color(UiTheme.GOLD, 0.6), 1.0, true)
	UiTheme.draw_diamond(self, Vector2(x + 357, 322), 3.5, UiTheme.GOLD)
	var sub := UiTheme.serif(500)
	draw_string(sub, Vector2(x, 362), tr("Un monde désolé reprend vie"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiTheme.SOFT)
	draw_string(sub, Vector2(x, 394), tr("au rythme de ton arbre"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiTheme.SOFT)


## Arbre gravé : tronc hachuré, racines, branches qui se divisent, feuilles au trait (certaines
## dorées). Forme fixe (graine 4) ; les branches ondulent à peine.
func _engraved_tree(base: Vector2, h: float) -> void:
	var ink := Color(UiTheme.INK, 0.55)
	var top := base + Vector2(0, -h * 0.42)
	# Tronc évasé à la base, qui s'affine jusqu'à la première fourche.
	draw_polyline(UiTheme.bez(base + Vector2(-26, 0), base + Vector2(-9, -h * 0.08), top + Vector2(-9, h * 0.12), top + Vector2(-2.5, 0)), ink, 1.4, true)
	draw_polyline(UiTheme.bez(base + Vector2(26, 0), base + Vector2(9, -h * 0.08), top + Vector2(9, h * 0.12), top + Vector2(2.5, 0)), ink, 1.4, true)
	for i in 18:
		var y := base.y - 8 - i * h * 0.022
		draw_line(Vector2(base.x + 2, y), Vector2(base.x + 14 - i * 0.35, y - 5), Color(UiTheme.INK, 0.22), 0.9, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 7:
		var a := lerpf(0.15, PI - 0.15, float(i) / 6.0)
		var end := base + Vector2(cos(a) * rng.randf_range(85, 170), sin(a) * rng.randf_range(16, 40))
		draw_polyline(UiTheme.bez(base + Vector2(cos(a) * 14, 0), base + Vector2(cos(a) * 36, 12), end + Vector2(-cos(a) * 36, -10), end), Color(UiTheme.INK, 0.33), 1.0, true)
	draw_line(base + Vector2(-210, 2), base + Vector2(210, 2), Color(UiTheme.GOLD, 0.35), 1.0, true)
	_tree_branch(top, -PI / 2.0, h * 0.16, 6, rng)


func _tree_branch(p: Vector2, ang: float, length: float, depth: int, rng: RandomNumberGenerator) -> void:
	var sway := sin(t * 0.5 + depth * 0.8 + p.x * 0.01) * 0.012 * (6 - depth)
	var a := ang + sway
	var end := p + Vector2.from_angle(a) * length
	var mid := (p + end) / 2.0 + Vector2.from_angle(a).orthogonal() * length * 0.08
	draw_polyline(UiTheme.bez(p, mid, mid, end, 10), Color(UiTheme.INK, 0.5), maxf(0.9, depth * 0.6), true)
	if depth == 0:
		for k in 3:
			var la := a + rng.randf_range(-1.2, 1.2) + sin(t * 1.3 + k + p.y * 0.02) * 0.06
			var filled := rng.randf() < 0.35
			UiTheme.draw_leaf(self, end, la, rng.randf_range(17, 26), rng.randf_range(4.5, 7), Color(UiTheme.INK, 0.6), Color(UiTheme.GOLD, 0.35) if filled else Color(0, 0, 0, 0), 0.9)
		return
	var l := rng.randf_range(0.35, 0.65)
	var r := rng.randf_range(0.35, 0.65)
	_tree_branch(end, a - l, length * 0.74, depth - 1, rng)
	_tree_branch(end, a + r, length * 0.74, depth - 1, rng)
	if depth <= 2:
		UiTheme.draw_leaf(self, end, a + rng.randf_range(-0.4, 0.4), 18, 5.5, Color(UiTheme.INK, 0.5), Color(0, 0, 0, 0), 0.8)


func _menutest() -> void:
	await get_tree().create_timer(0.8).timeout
	await _shot("menu_title")
	_open_options()
	await get_tree().create_timer(0.3).timeout
	await _shot("menu_options")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://autotest"))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://autotest/%s.png" % shot_name)
	print("MENUTEST capture %s" % shot_name)
