## Écran titre : Continuer, Nouvelle partie, Options, Quitter. Fond vivant dessiné par le code.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const OptionsPanel = preload("res://scripts/options_panel.gd")

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
	font = ThemeDB.fallback_font
	if Flow.skip_title:
		Flow.new_game.call_deferred()
		set_process(false)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	font = ThemeDB.fallback_font
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		motes.append({"x": rng.randf(), "y": rng.randf(), "s": rng.randf_range(0.02, 0.07), "r": rng.randf_range(1.5, 4.0), "p": rng.randf() * TAU})

	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu.position.y += 90
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
	var base := Vector2(w * 0.5, h * 0.93)
	_branch(base, -PI / 2.0, 100.0, 7, 0)
	# Spores qui montent.
	for m in motes:
		var y := fmod(m["y"] - t * m["s"] + 10.0, 1.0)
		var x: float = m["x"] + sin(t * 0.5 + m["p"]) * 0.015
		var a := 0.25 + 0.2 * sin(t * 1.3 + m["p"])
		draw_circle(Vector2(x * w, y * h), m["r"], Color(0.5, 0.85, 0.45, a))
	# Titre.
	var glow := 0.75 + 0.25 * sin(t * 1.2)
	draw_string(font, Vector2(0, h * 0.16 + 3), "SÈVE", HORIZONTAL_ALIGNMENT_CENTER, w, 96, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(0, h * 0.16), "SÈVE", HORIZONTAL_ALIGNMENT_CENTER, w, 96, UiTheme.INK.lerp(UiTheme.LEAF, 1.0 - glow))
	draw_string(font, Vector2(0, h * 0.16 + 40), "Un monde désolé reprend vie au rythme de ton arbre", HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(0.75, 0.85, 0.75, 0.8))


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
