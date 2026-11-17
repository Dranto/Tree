## Test des modes de déplacement (Settings.move_mode) : suivre le curseur (zone morte, tir posté,
## souris pas encore bougée), clic droit façon MOBA (destination, arrivée pile, repère, clic sur
## l'interface ignoré, abandon contre un obstacle, clavier prioritaire), clavier seul, esquive
## vers le curseur, sanctuaire ravivé dans chaque mode, et le réglage enregistré puis relu.
## Lancer : tools/godot.sh --xvfb --fixed-fps 60 --audio-driver Dummy -s res://tests/move_test.gd
## (avec --headless aussi, sauf le clic droit sur l'interface, que Godot ne transmet pas sans écran).
## Ne lit ni n'écrit la sauvegarde de partie ; remet le fichier d'options tel qu'il était.
extends SceneTree

var failures := 0
var main
var p
var settings


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _steps(n: int) -> void:
	for i in n:
		await physics_frame


func _place(pos: Vector2) -> void:
	p.position = pos
	p._step_start = pos
	p.invuln = 1.0e6
	p.clear_destination()
	p.dash_time = 0.0


func _motion() -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(3, 0)
	Input.parse_input_event(ev)


func _right_click(world: Vector2) -> void:
	p.test_mouse = world
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	Input.parse_input_event(up)


func _run() -> void:
	settings = root.get_node("Settings")
	var old_mode: String = settings.move_mode
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)
	p = main.player
	var speed: float = root.get_node("Game").stats["move_speed"]
	var spot := Vector2(-300, 260)

	print("Suivre le curseur (par défaut)")
	check(settings.MOVE_MODES[0] == "curseur", "le mode par défaut est « suivre le curseur »")
	settings.move_mode = "curseur"
	_place(spot)
	p.test_mouse = spot + Vector2(400, 0)
	p.mouse_live = false
	await _steps(30)
	check(p.position.distance_to(spot) < 1.0, "souris pas encore bougée dans la fenêtre : le héros reste sur place")
	_motion()
	await _steps(30)
	var moved: float = p.position.x - spot.x
	check(moved > speed * 0.4 and absf(p.position.y - spot.y) < 1.0, "la souris bouge : le héros marche vers elle (%.0f px en 0,5 s)" % moved)
	_place(spot)
	p.test_mouse = spot + Vector2(0, p.FOLLOW_DEAD - 6.0)
	await _steps(30)
	check(p.position.distance_to(spot) < 1.0, "souris dans la zone morte : il s'arrête")
	check(p.aim.y > 0.99, "mais il vise toujours la souris")
	_place(spot)
	p.test_mouse = spot + Vector2(-400, 0)
	Input.action_press("attack")
	await _steps(30)
	Input.action_release("attack")
	check(p.position.distance_to(spot) < 1.0, "clic gauche tenu : il s'arrête pour tirer")
	check(p.fire_cd > 0.0 or p.shoot_anim > 0.0, "et il tire bien")
	_place(spot)
	p.test_mouse = spot + Vector2(0, -400)
	p.dash_cd = 0.0
	Input.action_press("dash")
	await _steps(2)
	Input.action_release("dash")
	check(p.dash_dir.y < -0.99, "l'esquive part vers le curseur")
	await _steps(20)
	_place(spot)
	p.test_mouse = spot + Vector2(400, 0)
	Input.action_press("move_down")
	await _steps(20)
	Input.action_release("move_down")
	check(p.position.y - spot.y > speed * 0.25 and absf(p.position.x - spot.x) < 2.0, "une touche de direction tenue prend la main sur la souris")

	print("Clic droit (MOBA)")
	settings.move_mode = "moba"
	_place(spot)
	p.test_mouse = spot + Vector2(400, 0)
	await _steps(30)
	check(p.position.distance_to(spot) < 1.0, "sans clic droit, le héros ne suit pas la souris")
	var goal := spot + Vector2(150, -80)
	_right_click(goal)
	await _steps(2)
	check(p.has_dest and p.dest.distance_to(goal) < 0.01, "clic droit : destination posée")
	check(main.move_marker.alpha > 0.9 and main.move_marker.pos.distance_to(goal) < 0.01, "le repère s'affiche au sol sur la destination")
	p.test_mouse = spot + Vector2(-500, 300)   # la souris s'en va : la destination reste
	Input.action_press("attack")
	await _steps(20)
	check(p.has_dest and p.position.distance_to(spot) > 20.0, "il continue d'avancer en tirant ailleurs")
	Input.action_release("attack")
	await _steps(90)
	check(not p.has_dest and p.position.distance_to(goal) < 1.0, "arrivé pile sur la destination (écart %.2f px), destination effacée" % p.position.distance_to(goal))
	await _steps(20)
	check(main.move_marker.alpha == 0.0, "le repère s'efface à l'arrivée")
	_place(spot)
	_right_click(spot + Vector2(-300, 0))
	await _steps(5)
	p.test_mouse = spot + Vector2(0, 300)
	p.dash_cd = 0.0
	Input.action_press("dash")
	await _steps(2)
	Input.action_release("dash")
	check(p.dash_dir.y > 0.99 and not p.has_dest, "l'esquive part vers le curseur et annule la destination")
	await _steps(20)
	_place(spot)
	_right_click(spot + Vector2(300, 0))
	await _steps(3)
	Input.action_press("move_up")
	await _steps(10)
	Input.action_release("move_up")
	check(not p.has_dest and p.position.y < spot.y - 10.0, "une touche de direction annule la destination")
	# Destination hors du monde : bornée au bord, et le héros ne piétine pas contre lui.
	var h: float = main.world_half
	_place(Vector2(h - 30.0, 0))
	_right_click(Vector2(h + 800.0, 0))
	await _steps(2)
	check(p.dest.x <= h, "destination bornée au monde")
	# Contre un buisson d'épines : la destination est abandonnée.
	var bush = _a_bush()
	if bush != null:
		var c: Vector2 = bush["pos"]
		_place(c + Vector2(-float(bush["r"]) - 80.0, 0))
		_right_click(c)
		await _steps(120)
		check(not p.has_dest, "destination dans un buisson : abandonnée quand le héros bute")
	else:
		check(false, "un buisson d'épines pour le test")
	# Clic droit sur l'interface (géré par un Control) : pas de destination.
	_place(spot)
	var blocker := Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(blocker)
	root.add_child(layer)
	root.notification(Node.NOTIFICATION_WM_MOUSE_ENTER)   # sans écran, la souris n'est jamais « entrée »
	await process_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	ev.position = Vector2(100, 100)
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	await _steps(2)
	var ev2 := ev.duplicate()
	ev2.pressed = false
	Input.parse_input_event(ev2)
	layer.queue_free()
	if DisplayServer.get_name() == "headless":
		print("  (sans écran, l'interface ne reçoit pas les clics : relancer avec --xvfb pour ce contrôle)")
	else:
		check(not p.has_dest, "un clic droit sur l'interface ne déplace pas le héros")

	print("Clavier")
	settings.move_mode = "clavier"
	_place(spot)
	p.test_mouse = spot + Vector2(400, 0)
	_motion()
	_right_click(spot + Vector2(200, 0))
	await _steps(30)
	check(p.position.distance_to(spot) < 1.0 and not p.has_dest, "ni la souris ni le clic droit ne déplacent le héros")
	Input.action_press("move_right")
	await _steps(30)
	Input.action_release("move_right")
	check(p.position.x - spot.x > speed * 0.4, "Z Q S D : il marche")

	print("Sanctuaire dans chaque mode")
	for mode in settings.MOVE_MODES:
		settings.move_mode = mode
		var sanct = main.sanctuary(["lisiere", "ravin", "veille"][settings.MOVE_MODES.find(mode)])
		_place(sanct.position + Vector2(-260, 0))
		match mode:
			"curseur":
				_motion()
				p.test_mouse = sanct.position
				await _steps(90)
				p.test_mouse = p.position   # souris sur le héros : il s'arrête dans le cercle
			"moba":
				_right_click(sanct.position)
			"clavier":
				Input.action_press("move_right")
				await _steps(int(260.0 / speed * 60.0))
				Input.action_release("move_right")
		await _steps(260)
		check(sanct.is_lit(), "%s : le sanctuaire est ravivé en s'y rendant" % mode)

	print("Options")
	var cfg_path: String = settings.PATH
	var had_cfg := FileAccess.file_exists(cfg_path)
	var backup := FileAccess.get_file_as_string(cfg_path) if had_cfg else ""
	for mode in settings.MOVE_MODES:
		settings.set_move_mode(mode)
		settings.save_settings()
		settings.move_mode = "x"
		settings.load_settings()
		check(settings.move_mode == mode, "« %s » enregistré puis relu" % mode)
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)
	cfg.set_value("controls", "move_mode", "nimporte")
	cfg.save(cfg_path)
	settings.load_settings()
	check(settings.move_mode == "curseur", "valeur inconnue : retour au suivi du curseur")
	var panel = load("res://scripts/options_panel.gd").new()
	root.add_child(panel)
	await process_frame
	panel.open()
	panel.move_select.select(1)
	panel.move_select.item_selected.emit(1)
	check(settings.move_mode == "moba" and panel.move_hint.text.contains("Clic droit"), "le choix des options change le mode et son explication")
	settings.load_settings()
	check(settings.move_mode == "moba", "et l'enregistre aussitôt")
	panel.queue_free()
	for mode in settings.MOVE_MODES:
		settings.move_mode = mode
		var line: String = main.hud.move_hint_line()
		check(line.contains("esquive") and (mode != "moba" or line.contains("Clic droit")) and (mode != "curseur" or line.contains("souris")), "aide de départ adaptée (%s)" % mode)
	# Remet les options du poste comme avant le test.
	if had_cfg:
		var f := FileAccess.open(cfg_path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
	settings.move_mode = old_mode

	if failures == 0:
		print("DÉPLACEMENT : tout est bon")
	else:
		print("DÉPLACEMENT : %d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


## Un buisson d'épines du roncier (centre et rayon), loin du bord du monde.
func _a_bush():
	for b in main.flora.bushes:
		if b.position.length() < main.world_half - 400.0:
			return {"pos": b.position, "r": b.radius}
	return null
