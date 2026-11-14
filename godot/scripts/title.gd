## Écran titre : Continuer, Nouvelle partie, Options, Quitter. Fond vivant dessiné par le code.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const OptionsPanel = preload("res://scripts/options_panel.gd")

## Position horizontale (part de la largeur) de la colonne du titre et des boutons.
const MENU_X := 0.08

var menu: VBoxContainer
var continue_button: Button
var new_button: Button
var options_button: Button
var quit_button: Button
var options: PanelContainer
var font: Font
var t := 0.0
var motes: Array = []
## Mode « -- --menutest » : enregistre des captures des menus dans godot/autotest/ puis quitte.
var menutest := false


func _ready() -> void:
	font = UiTheme.font(true)
	if Flow.skip_title:
		Flow.new_game.call_deferred()
		set_process(false)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		motes.append({"x": rng.randf(), "y": rng.randf(), "s": rng.randf_range(0.02, 0.07), "r": rng.randf_range(1.5, 4.0), "p": rng.randf() * TAU})

	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	# Colonne de gauche (8 % de la largeur), centrée sous le titre : l'arbre décoratif occupe la droite.
	menu.anchor_left = MENU_X
	menu.anchor_right = MENU_X
	menu.anchor_top = 0.6
	menu.anchor_bottom = 0.6
	menu.grow_horizontal = Control.GROW_DIRECTION_END
	menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(menu)
	continue_button = UiTheme.button("Continuer")
	continue_button.pressed.connect(Flow.continue_game)
	menu.add_child(continue_button)
	new_button = UiTheme.button("Nouvelle partie")
	new_button.pressed.connect(Flow.new_game)
	menu.add_child(new_button)
	options_button = UiTheme.button("Options")
	options_button.pressed.connect(_open_options)
	menu.add_child(options_button)
	if OS.has_feature("web"):
		pass
	else:
		quit_button = UiTheme.button("Quitter")
		quit_button.pressed.connect(Flow.quit)
		menu.add_child(quit_button)

	options = OptionsPanel.new()
	options.visible = false
	options.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	options.grow_horizontal = Control.GROW_DIRECTION_BOTH
	options.grow_vertical = Control.GROW_DIRECTION_BOTH
	options.closed.connect(_close_options)
	add_child(options)

	continue_button.disabled = not Flow.has_save()
	var sum := Flow.save_summary()
	if not continue_button.disabled and sum.has("level"):
		continue_button.text = "Continuer  (niveau %d)" % int(sum["level"])
	_focus_first()
	menutest = "--menutest" in OS.get_cmdline_user_args()
	if menutest:
		_menutest()


func _focus_first() -> void:
	(new_button if continue_button.disabled else continue_button).grab_focus()


func _open_options() -> void:
	menu.visible = false
	options.open()


func _close_options() -> void:
	menu.visible = true
	_focus_first()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Ciel nocturne en dégradé.
	var steps := 24
	for i in steps:
		var k := float(i) / steps
		var c := Color("0b1410").lerp(Color("1d2f22"), k)
		draw_rect(Rect2(0, h * k, w, h / steps + 1.0), c)
	# Arbre de vie stylisé : branches qui se divisent, nœuds lumineux.
	var base := Vector2(maxf(w * 0.72, w - h * 0.55), h * 0.95)
	_branch(base, -PI / 2.0, h * 0.11, 7, 0)
	# Spores qui montent.
	for m in motes:
		var y := fmod(m["y"] - t * m["s"] + 10.0, 1.0)
		var x: float = m["x"] + sin(t * 0.5 + m["p"]) * 0.015
		var a := 0.25 + 0.2 * sin(t * 1.3 + m["p"])
		draw_circle(Vector2(x * w, y * h), m["r"], Color(0.5, 0.85, 0.45, a))
	# Titre, aligné à gauche sur la colonne des boutons.
	var x := w * MENU_X
	var glow := 0.75 + 0.25 * sin(t * 1.2)
	var title_size := clampi(roundi(h * 0.105), 48, 140)
	var ty := h * 0.2
	draw_string(font, Vector2(x, ty + 3), "SÈVE", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(x, ty), "SÈVE", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, UiTheme.INK.lerp(UiTheme.LEAF, 1.0 - glow))
	var sub_font := UiTheme.font()
	var sub_col := Color(0.75, 0.85, 0.75, 0.8)
	draw_string(sub_font, Vector2(x, ty + 40), "Un monde désolé reprend vie", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, sub_col)
	draw_string(sub_font, Vector2(x, ty + 66), "au rythme de ton arbre", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, sub_col)


func _branch(p: Vector2, ang: float, length: float, depth: int, seed_i: int) -> void:
	var sway := sin(t * 0.6 + depth * 0.9 + seed_i) * 0.025
	var end := p + Vector2.from_angle(ang + sway) * length
	var col := Color("5a4630").lerp(Color("7fd36b"), 1.0 - depth / 7.0)
	draw_line(p, end, col, maxf(1.5, depth * 2.2), true)
	if depth <= 0:
		draw_circle(end, 5.0, Color(UiTheme.GOLD, 0.8 + 0.2 * sin(t * 2.0 + seed_i)))
		return
	_branch(end, ang - 0.45, length * 0.74, depth - 1, seed_i * 2 + 1)
	_branch(end, ang + 0.45, length * 0.74, depth - 1, seed_i * 2 + 2)
	if depth <= 3:
		draw_circle(end, 3.0 + depth, Color(UiTheme.LEAF, 0.55))


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
