## Test des commandes : modes de déplacement (Settings.move_mode) — clavier par défaut, suivre le
## curseur (zone morte, souris pas encore bougée), clic droit façon MOBA (destination, arrivée pile,
## repère, clic sur l'interface ignoré, abandon contre un obstacle, clavier prioritaire) —, esquive
## vers le curseur, sanctuaire ravivé dans chaque mode ; attaque automatique (cible, portée, visée
## au curseur, repère) ; compétences sur les clics et les touches, selon le mode ; réglages
## enregistrés puis relus.
## Lancer : tools/godot.sh --xvfb --fixed-fps 60 --audio-driver Dummy -s res://tests/move_test.gd
## (avec --headless aussi, sauf le clic droit sur l'interface, que Godot ne transmet pas sans écran).
## Ne lit ni n'écrit la sauvegarde de partie ; remet le fichier d'options tel qu'il était.
extends SceneTree

var failures := 0
var main
var p
var settings
var game
var Enemy


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


func _click(button: int, pressed := true) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _key(code: int, pressed := true) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Flétri immobile (sa logique est coupée) posé en pos.
func _spawn(pos: Vector2):
	var e = Enemy.new()
	e.main = main
	e.position = pos
	e.setup(0, 50.0)
	main.enemies_layer.add_child(e)
	main.enemies.append(e)
	e.set_physics_process(false)
	return e


func _clear_enemies() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	for pr in main.projectiles_layer.get_children():
		pr.queue_free()


func _run() -> void:
	settings = root.get_node("Settings")
	game = root.get_node("Game")
	Enemy = load("res://scripts/enemy.gd")
	var old_mode: String = settings.move_mode
	var old_aim: String = settings.aim_mode
	var old_bindings: Array = settings.bindings.duplicate()
	var old_moba_key: int = settings.moba_main_2_key
	settings.aim_mode = "auto"
	settings.bindings = settings.BINDING_DEFAULTS.duplicate()
	settings.moba_main_2_key = settings.MOBA_MAIN_2_DEFAULT
	settings.apply_bindings()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)
	p = main.player
	var speed: float = root.get_node("Game").stats["move_speed"]
	var spot := Vector2(-300, 260)

	print("Suivre le curseur")
	check(settings.MOVE_MODES[0] == "clavier" and settings.MOVE_MODE_DEFAULT == "clavier", "le mode par défaut est le clavier (Z Q S D)")
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
	_click(MOUSE_BUTTON_LEFT)
	await _steps(30)
	_click(MOUSE_BUTTON_LEFT, false)
	check(p.position.x < spot.x - speed * 0.3, "clic gauche tenu : il ne s'arrête plus (plus de tir posté)")
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
	await _steps(20)
	check(p.has_dest and p.position.distance_to(spot) > 20.0, "la destination reste quand la souris s'en va")
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

	await _auto_attack()
	await _skill_clicks()

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
	check(settings.move_mode == "clavier", "valeur inconnue : retour au clavier")
	# Ancien fichier d'options (avant l'attaque automatique) : le mode choisi est gardé, les
	# anciennes touches de la barre (autre disposition) sont ignorées.
	cfg = ConfigFile.new()
	cfg.set_value("controls", "move_mode", "curseur")
	cfg.set_value("controls", "slot_1", KEY_Z)
	cfg.save(cfg_path)
	settings.bindings = settings.BINDING_DEFAULTS.duplicate()
	settings.load_settings()
	check(settings.move_mode == "curseur", "ancien fichier : le mode « suivre le curseur » choisi est gardé")
	check(settings.bindings == settings.BINDING_DEFAULTS and settings.aim_mode == "auto", "ancien fichier : commandes et visée par défaut")
	settings.set_binding(3, -MOUSE_BUTTON_MIDDLE)
	settings.set_moba_main_2_key(KEY_G)
	settings.set_aim_mode("curseur")
	settings.save_settings()
	settings.bindings = settings.BINDING_DEFAULTS.duplicate()
	settings.moba_main_2_key = KEY_SHIFT
	settings.aim_mode = "auto"
	settings.load_settings()
	check(settings.bindings[3] == -MOUSE_BUTTON_MIDDLE and settings.moba_main_2_key == KEY_G and settings.aim_mode == "curseur", "commandes, touche MOBA et visée enregistrées puis relues")
	settings.bindings = settings.BINDING_DEFAULTS.duplicate()
	settings.moba_main_2_key = settings.MOBA_MAIN_2_DEFAULT
	settings.aim_mode = "auto"
	settings.apply_bindings()
	var panel = load("res://scripts/options_panel.gd").new()
	root.add_child(panel)
	await process_frame
	panel.open()
	var moba_i: int = settings.MOVE_MODES.find("moba")
	panel.move_select.select(moba_i)
	panel.move_select.item_selected.emit(moba_i)
	check(settings.move_mode == "moba" and panel.move_hint.text.contains("Clic droit"), "le choix des options change le mode et son explication")
	settings.load_settings()
	check(settings.move_mode == "moba", "et l'enregistre aussitôt")
	panel.aim_select.select(1)
	panel.aim_select.item_selected.emit(1)
	check(settings.aim_mode == "curseur" and panel.aim_hint.text.contains("souris"), "le choix de la visée change le réglage et son explication")
	settings.set_aim_mode("auto")
	panel.queue_free()
	for mode in settings.MOVE_MODES:
		settings.move_mode = mode
		var line: String = main.hud.move_hint_line()
		check(line.contains("esquive") and line.contains("toute seule") and (mode != "moba" or line.contains("Clic droit")) and (mode != "curseur" or line.contains("souris")), "aide de départ adaptée (%s)" % mode)
	# Remet les options du poste comme avant le test.
	if had_cfg:
		var f := FileAccess.open(cfg_path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
	settings.move_mode = old_mode
	settings.aim_mode = old_aim
	settings.bindings = old_bindings
	settings.moba_main_2_key = old_moba_key
	settings.apply_bindings()

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


## Attaque automatique : ne part qu'avec un ennemi à portée, vise le plus proche du curseur (à
## défaut, du héros), garde sa cible, ne freine pas le héros ; visée au curseur ; repères au sol.
func _auto_attack() -> void:
	print("Attaque automatique")
	settings.move_mode = "clavier"
	var spot := Vector2(-300, 260)
	_clear_enemies()
	_place(spot)
	p.test_mouse = spot + Vector2(300, 0)
	p.fire_cd = 0.0
	await _steps(30)
	check(p.target == null and p.fire_cd <= 0.0 and main.projectiles_layer.get_child_count() == 0, "sans ennemi, l'attaque ne part pas")
	_spawn(spot + Vector2(0, -(p.attack_range() + 120.0)))
	await _steps(30)
	check(p.target == null and p.fire_cd <= 0.0, "ennemi hors de portée : pas d'attaque")
	check(main.target_marker.range_alpha > 0.5, "ennemi proche mais hors de portée : le cercle de portée s'affiche")
	var a = _spawn(spot + Vector2(250, 0))
	var b = _spawn(spot + Vector2(-200, 0))
	p.test_mouse = spot + Vector2(400, 0)
	await _steps(p.TARGET_EVERY + 2)
	check(p.target == a, "cible : l'ennemi à portée le plus proche du curseur")
	check(p.fire_cd > 0.0 and p.shot_dir.x > 0.99, "l'attaque part toute seule vers la cible")
	await _steps(15)
	check(main.target_marker.target == a and main.target_marker.target_alpha > 0.5, "un repère au sol marque la cible")
	check(main.target_marker.range_alpha < 0.5, "et le cercle de portée s'efface")
	p.test_mouse = spot + Vector2(10, 0)   # à peine plus près de b : la cible ne saute pas
	await _steps(10)
	check(p.target == a, "la cible reste tant qu'une autre n'est pas nettement plus proche du curseur")
	p.test_mouse = spot + Vector2(-400, 0)
	await _steps(10)
	check(p.target == b, "le curseur passe de l'autre côté : nouvelle cible")
	p.test_mouse = null
	p.mouse_live = false
	b.position = spot + Vector2(-320, 0)
	p.target = null
	await _steps(10)
	check(p.target == a, "souris inconnue : l'ennemi le plus proche du héros")
	_place(spot)
	Input.action_press("move_up")
	await _steps(60)
	Input.action_release("move_up")
	check(spot.y - p.position.y > game.stats["move_speed"] * 0.9 and p.fire_cd > 0.0, "le héros marche sans s'arrêter pendant l'attaque (%.0f px en 1 s)" % (spot.y - p.position.y))
	_clear_enemies()
	await _steps(2)
	settings.aim_mode = "curseur"
	_place(spot)
	p.test_mouse = spot + Vector2(0, 300)
	p.fire_cd = 0.0
	await _steps(2)
	check(p.fire_cd > 0.0 and p.shot_dir.y > 0.99, "visée « vers le curseur » : l'attaque part vers la souris, même sans ennemi")
	await _steps(10)
	check(main.target_marker.target_alpha == 0.0 and main.target_marker.range_alpha == 0.0, "et aucun repère de cible ni de portée")
	settings.aim_mode = "auto"
	_clear_enemies()
	await _steps(2)


## Compétences : clic gauche et droit (principales), A E R F (secondaires) ; en mode MOBA, le
## clic droit marche et la compétence 2 passe sur sa touche ; un clic tenu relance la compétence.
func _skill_clicks() -> void:
	print("Compétences sur les clics")
	game.test_skills = {"nova": true, "cloud": true, "fouet": true, "racines": true, "volee": true}
	game.recompute()
	game.tree_changed.emit()
	await _steps(1)
	p.bar = ["nova", "fouet", "racines", "volee", "", ""]
	var spot := Vector2(-300, 260)
	settings.move_mode = "clavier"
	settings.apply_bindings()
	_place(spot)
	p.test_mouse = spot + Vector2(200, 0)
	for k in p.cds:
		p.cds[k] = 0.0
	_click(MOUSE_BUTTON_LEFT)
	await _steps(2)
	_click(MOUSE_BUTTON_LEFT, false)
	check(p.cds["nova"] > 0.0 and p.cds["fouet"] == 0.0, "clic gauche : compétence principale 1")
	_click(MOUSE_BUTTON_RIGHT)
	await _steps(2)
	_click(MOUSE_BUTTON_RIGHT, false)
	check(p.cds["fouet"] > 0.0 and not p.has_dest, "clic droit : compétence principale 2 (pas de déplacement hors du mode MOBA)")
	_key(KEY_Q)
	await _steps(2)
	_key(KEY_Q, false)
	_key(KEY_E)
	await _steps(2)
	_key(KEY_E, false)
	check(p.cds["racines"] > 0.0 and p.cds["volee"] > 0.0, "A et E (Q et E en QWERTY) : compétences secondaires 1 et 2")
	# Clic tenu : la compétence repart dès qu'elle est prête.
	p.cds["nova"] = 0.0
	_click(MOUSE_BUTTON_LEFT)
	await _steps(2)
	p.cds["nova"] = 0.0
	await _steps(2)
	var held_again: bool = p.cds["nova"] > 0.0
	_click(MOUSE_BUTTON_LEFT, false)
	await _steps(1)
	p.cds["nova"] = 0.0
	await _steps(2)
	check(held_again and p.cds["nova"] == 0.0, "clic tenu : la compétence repart dès qu'elle est prête, et plus une fois relâché")
	print("Compétences en mode MOBA")
	settings.set_move_mode("moba")
	check(settings.binding_name(1) == settings.code_name(KEY_SHIFT) and settings.binding_name(0) == "Clic gauche", "MOBA : la compétence 2 passe sur Maj")
	var dash_shift := false
	for ev in InputMap.action_get_events("dash"):
		if ev is InputEventKey and ev.physical_keycode == KEY_SHIFT:
			dash_shift = true
	check(not dash_shift, "MOBA : l'esquive ne garde qu'Espace")
	_place(spot)
	for k in p.cds:
		p.cds[k] = 0.0
	_right_click(spot + Vector2(150, 0))
	await _steps(2)
	check(p.has_dest and p.cds["fouet"] == 0.0, "MOBA : le clic droit marche, sans lancer de compétence")
	_key(KEY_SHIFT)
	await _steps(2)
	_key(KEY_SHIFT, false)
	check(p.cds["fouet"] > 0.0 and p.dash_time <= 0.0, "MOBA : Maj lance la compétence 2, sans esquiver")
	settings.set_move_mode("clavier")
	var shift_back := false
	for ev in InputMap.action_get_events("dash"):
		if ev is InputEventKey and ev.physical_keycode == KEY_SHIFT:
			shift_back = true
	check(shift_back and settings.binding_name(1) == "Clic droit", "hors MOBA : le clic droit et Maj (esquive) reviennent")
	game.test_skills = {}
	game.recompute()
	game.tree_changed.emit()
