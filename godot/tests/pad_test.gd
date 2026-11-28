## Test de la manette (jalon 11) : entrées simulées (Input.parse_input_event) dans le jeu, les menus
## et l'arbre. Liaisons par défaut et réassignées (enregistrées puis relues) ; bascule automatique
## des glyphes clavier ↔ manette ; marche au stick gauche, visée au stick droit (cible automatique
## sinon), compétences aux gâchettes et aux boutons, esquive ; pause (Start), retour (B) ; menu pause
## et options parcourus à la croix, onglets à LB / RB, écoute d'un bouton ; arbre : saut de nœud en
## nœud, curseur libre, zoom aux gâchettes, apprendre / oublier, zones des outils et de la couronne
## (prendre une greffe, la poser) ; carte du monde.
## Lancer : tools/godot.sh --xvfb --fixed-fps 60 --audio-driver Dummy -s res://tests/pad_test.gd
## (sans écran, Godot ne transmet pas les évènements aux menus).
## Ne lit ni n'écrit la sauvegarde de partie ; remet le fichier d'options tel qu'il était.
extends SceneTree

var failures := 0
var main
var p
var settings
var game


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _button(b: int, pressed := true) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = b
	ev.pressed = pressed
	ev.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


## Appuie puis relâche un bouton, avec deux images entre les deux (le temps que les menus le voient).
func _tap(b: int) -> void:
	_button(b, true)
	await _frames(2)
	_button(b, false)
	await _frames(2)


func _axis(axis: int, v: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = v
	Input.parse_input_event(ev)


func _stick(left: bool, v: Vector2) -> void:
	_axis(JOY_AXIS_LEFT_X if left else JOY_AXIS_RIGHT_X, v.x)
	_axis(JOY_AXIS_LEFT_Y if left else JOY_AXIS_RIGHT_Y, v.y)


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)


func _has_pad(action: String, code: int) -> bool:
	for ev in InputMap.action_get_events(action):
		var jb := ev as InputEventJoypadButton
		if jb != null and jb.button_index == code:
			return true
		var jm := ev as InputEventJoypadMotion
		if jm != null and code >= settings.PAD_AXIS and jm.axis == code - settings.PAD_AXIS:
			return true
	return false


func _run() -> void:
	settings = root.get_node("Settings")
	settings.wind = 0.0
	game = root.get_node("Game")
	var cfg_path: String = settings.PATH
	var had_cfg := FileAccess.file_exists(cfg_path)
	var backup := FileAccess.get_file_as_string(cfg_path) if had_cfg else ""
	settings.move_mode = "clavier"
	settings.reset_bindings()

	print("Liaisons")
	check(_has_pad("skill_main_1", settings.PAD_RT) and _has_pad("skill_main_2", settings.PAD_LT), "compétences principales sur RT et LT")
	check(_has_pad("slot_1", JOY_BUTTON_X) and _has_pad("slot_4", JOY_BUTTON_RIGHT_SHOULDER), "secondaires sur X Y B RB")
	check(_has_pad("dash", JOY_BUTTON_A) and _has_pad("toggle_tree", JOY_BUTTON_BACK) and _has_pad("toggle_map", JOY_BUTTON_LEFT_SHOULDER), "esquive A, arbre Affichage, carte LB")
	check(_has_pad("ui_accept", JOY_BUTTON_A) and _has_pad("ui_cancel", JOY_BUTTON_B) and _has_pad("pause", JOY_BUTTON_START), "menus : A valide, B revient, Start met en pause")
	check(InputMap.has_action("aim_left") and InputMap.action_get_deadzone("move_left") < 0.3, "stick droit pour viser, zone morte du stick gauche réduite")
	check(settings.set_pad_binding(2, JOY_BUTTON_Y) == "" and settings.pad_bindings[2] == JOY_BUTTON_Y and settings.pad_bindings[3] == JOY_BUTTON_INVALID,
		"réassigner un emplacement : l'autre emplacement perd le bouton")
	check(settings.set_pad_binding(2, JOY_BUTTON_A) != "" and settings.pad_bindings[2] == JOY_BUTTON_Y, "un bouton d'une commande du jeu (esquive) est refusé")
	check(settings.set_pad_action("toggle_map", JOY_BUTTON_RIGHT_SHOULDER) != "", "une commande du jeu ne prend pas le bouton d'une compétence")
	check(settings.set_pad_action("toggle_map", JOY_BUTTON_DPAD_UP) == "" and _has_pad("toggle_map", JOY_BUTTON_DPAD_UP), "carte réassignée à la croix")
	settings.pad_style = "playstation"
	settings.save_settings()
	settings.pad_bindings = settings.PAD_SLOT_DEFAULTS.duplicate()
	settings.pad_actions = settings.PAD_ACTION_DEFAULTS.duplicate()
	settings.pad_style = "auto"
	settings.load_settings()
	check(settings.pad_bindings[2] == JOY_BUTTON_Y and settings.pad_actions["toggle_map"] == JOY_BUTTON_DPAD_UP and settings.pad_style == "playstation",
		"liaisons de la manette et style des glyphes enregistrés puis relus")
	check(settings.pad_name_of(settings.PAD_RT) == "R2" and settings.pad_name_of(JOY_BUTTON_A) == "Croix", "style PlayStation : R2, Croix")
	settings.set_pad_style("xbox")
	check(settings.pad_name_of(settings.PAD_RT) == "RT" and settings.pad_name_of(JOY_BUTTON_A) == "A", "style Xbox : RT, A")
	settings.set_pad_style("auto")
	settings.pad_name = "PS5 Controller"
	check(settings.pad_layout() == "playstation", "style automatique : une manette Sony prend les glyphes PlayStation")
	settings.pad_name = "Steam Deck"
	check(settings.pad_layout() == "xbox", "Steam Deck : glyphes A B X Y")
	settings.reset_bindings()

	print("Bascule clavier ↔ manette")
	check(settings.last_device == "clavier", "une partie démarre au clavier")
	_button(JOY_BUTTON_X)
	_button(JOY_BUTTON_X, false)
	await _frames(2)
	check(settings.pad_active(), "un bouton de manette : glyphes de manette")
	_key(KEY_K)
	await _frames(1)
	check(not settings.pad_active(), "une touche : retour au clavier")
	_axis(JOY_AXIS_LEFT_X, 0.2)
	await _frames(1)
	check(not settings.pad_active(), "un stick à peine effleuré ne bascule pas")
	_axis(JOY_AXIS_LEFT_X, 0.9)
	await _frames(1)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	check(settings.pad_active(), "un stick poussé bascule à la manette")

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)
	p = main.player
	p.invuln = 1.0e6
	settings.set_device("manette")

	print("Glyphes")
	check(main.hud.slot_keys_text(0) == "pad:%d" % settings.PAD_RT and main.hud.slot_keys_text(2) == "pad:%d" % JOY_BUTTON_X, "barre : glyphes RT et X sous les emplacements")
	check(main.hud.key_label("toggle_tree") == "pad:%d" % JOY_BUTTON_BACK, "coin : glyphe du bouton de l'arbre")
	var g: Array = main.hud.glyphs.glyph_for("esquive")
	check(g[0] == "pad" and g[1] == [JOY_BUTTON_A], "tutoriel : glyphe A pour l'esquive")
	check(main.hud.glyphs.glyph_for("bouger") == ["pad", [settings.PAD_STICK_L]], "tutoriel : stick gauche pour se déplacer")
	var rows: Array = load("res://scripts/controls_text.gd").reminder_rows()
	check(rows[0][0] == "Stick gauche" and rows[5][0] == "A", "rappel des commandes aux noms des boutons")
	settings.set_device("clavier")
	check(not main.hud.slot_keys_text(2).begins_with("pad:") and main.hud.slot_keys_text(2).contains(settings.binding_name(2)), "au clavier, la barre reprend les touches")
	settings.set_device("manette")

	print("Jeu")
	var start: Vector2 = p.position
	_stick(true, Vector2(1, 0))
	await _steps(30)
	_stick(true, Vector2.ZERO)
	await _steps(2)
	var speed: float = game.stats["move_speed"]
	check(p.position.x - start.x > speed * 0.35 and absf(p.position.y - start.y) < 2.0, "stick gauche : le héros marche (%.0f px en 0,5 s)" % (p.position.x - start.x))
	_stick(false, Vector2(0, -1))
	await _steps(3)
	check(p.pad_aiming and p.aim.y < -0.95, "stick droit : il vise vers le haut")
	check(p.aim_point.distance_to(p.position) > p.PAD_AIM_NEAR, "à fond, le point visé est loin du héros")
	_stick(false, Vector2.ZERO)
	await _steps(3)
	check(not p.pad_aiming, "stick droit lâché : visée automatique")
	var Enemy = load("res://scripts/enemy.gd")
	var e = Enemy.new()
	e.main = main
	e.position = p.position + Vector2(-200, 40)
	e.setup(0, 50.0)
	main.enemies_layer.add_child(e)
	main.enemies.append(e)
	e.set_physics_process(false)
	p.target = null
	await _steps(TARGET_WAIT)
	check(p.target == e and p.aim_point.distance_to(e.position) < 1.0, "sans stick droit, la visée se pose sur la cible la plus proche du héros")
	# Compétences : nova, fouet, racines, volée dans la barre ; RT, LT, X et Y les lancent.
	game.test_skills = {"nova": true, "fouet": true, "racines": true, "volee": true}
	game.recompute()
	game.tree_changed.emit()
	await _steps(1)
	p.bar = ["nova", "fouet", "racines", "volee", "", ""]
	for k in p.cds:
		p.cds[k] = 0.0
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _steps(2)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(p.cds["nova"] > 0.0 and p.cds["fouet"] == 0.0, "RT : compétence principale 1")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _steps(2)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	check(p.cds["fouet"] > 0.0, "LT : compétence principale 2")
	_button(JOY_BUTTON_X)
	_button(JOY_BUTTON_Y)
	await _steps(2)
	_button(JOY_BUTTON_X, false)
	_button(JOY_BUTTON_Y, false)
	check(p.cds["racines"] > 0.0 and p.cds["volee"] > 0.0, "X et Y : compétences secondaires 1 et 2")
	p.cds["nova"] = 0.0
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _steps(2)
	p.cds["nova"] = 0.0
	await _steps(2)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _steps(1)
	check(p.cds["nova"] > 0.0, "gâchette tenue : la compétence repart dès qu'elle est prête")
	p.dash_cd = 0.0
	_stick(true, Vector2(0, 1))
	await _steps(2)
	_button(JOY_BUTTON_A)
	await _steps(2)
	_button(JOY_BUTTON_A, false)
	check(p.dash_time > 0.0 or p.dash_cd > 0.0, "A : esquive")
	check(p.dash_dir.y > 0.95, "l'esquive suit le stick gauche")
	_stick(true, Vector2.ZERO)
	e.queue_free()
	main.enemies.clear()
	await _steps(20)

	print("Pause et menus")
	await _tap(JOY_BUTTON_B)
	check(not main.pause_menu.visible, "B en jeu n'ouvre pas la pause (c'est une compétence)")
	await _tap(JOY_BUTTON_START)
	check(main.pause_menu.visible and paused, "Start : pause")
	check(main.pause_menu.resume_button.has_focus(), "« Reprendre » a le focus")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	var focused = root.gui_get_focus_owner()
	check(focused != null and focused != main.pause_menu.resume_button and focused.text == "Options", "croix bas : focus sur « Options »")
	await _tap(JOY_BUTTON_A)
	var opts = main.pause_menu.options
	check(opts.visible and opts.tab_buttons[0].has_focus(), "A : les options s'ouvrent, focus sur le premier onglet")
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(opts.tab == 3, "RB : onglet suivant (Commandes)")
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	check(opts.tab == 2, "LB : onglet précédent")
	opts.show_tab(3)
	opts.pad_slot_buttons[5].grab_focus()
	await _tap(JOY_BUTTON_A)
	check(opts.listening == opts.PAD_ROW0 + 5, "A sur une ligne de la manette : elle attend un bouton")
	await _tap(JOY_BUTTON_PADDLE1)
	check(settings.pad_bindings[5] == JOY_BUTTON_PADDLE1 and opts.listening < 0, "le bouton pressé est lié (palette)")
	check(opts.pad_slot_buttons[5].text == settings.pad_name_of(JOY_BUTTON_PADDLE1), "la ligne affiche son nom")
	await _tap(JOY_BUTTON_B)
	check(not opts.visible and main.pause_menu.resume_button.has_focus(), "B ferme les options, retour à « Reprendre »")
	await _tap(JOY_BUTTON_START)
	check(not main.pause_menu.visible and not paused, "Start reprend la partie")
	settings.reset_bindings()
	settings.set_device("manette")

	print("Carte")
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	check(main.quest_ui.current == "carte" and paused, "LB ouvre la carte")
	await _tap(JOY_BUTTON_B)
	check(main.quest_ui.current == "" and not paused, "B la referme")

	print("Arbre")
	var ui = main.tree_ui
	ui.play_intro = false
	game.points = 5
	await _tap(JOY_BUTTON_BACK)
	check(ui.visible and paused, "Affichage ouvre l'arbre")
	await _frames(3)
	check(ui.hover >= 0 and ui.pad.attached, "un nœud est visé dès l'ouverture")
	check(ui.help_text().contains("apprendre") and ui.help_text().contains("RT"), "l'en-tête donne les boutons de la manette")
	ui.pad.select(0, false)
	await _frames(1)
	var neighbors: Array = game.tree.nodes[0]["neighbors"]
	var target: int = neighbors[0]
	var d: Vector2 = (game.tree.nodes[target]["pos"] - game.tree.nodes[0]["pos"]).normalized()
	var got: int = ui.pad.hop(d)
	check(got == target, "saut dans la direction d'un voisin : ce voisin (%d → %d)" % [target, got])
	ui.pad.select(0, false)
	_stick(true, d)
	await _frames(3)
	_stick(true, Vector2.ZERO)
	await _frames(2)
	check(ui.hover == target, "stick gauche poussé : même saut")
	var before_pts: int = game.points
	await _tap(JOY_BUTTON_A)
	await _frames(2)
	check(game.allocated.has(target) or ui.choice_open(), "A apprend le nœud visé")
	if ui.choice_open():
		await _tap(JOY_BUTTON_A)
	check(game.points < before_pts, "un point est dépensé")
	await _tap(JOY_BUTTON_X)
	await _frames(2)
	check(not game.allocated.has(target), "X oublie le nœud")
	var z0: float = ui.zoom
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(20)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _frames(2)
	check(ui.zoom > z0 * 1.1, "RT zoome (%.2f → %.2f)" % [z0, ui.zoom])
	var c0: Vector2 = ui.pad.cursor
	_stick(false, Vector2(1, 0))
	await _frames(10)
	_stick(false, Vector2.ZERO)
	await _frames(1)
	check(ui.pad.cursor.x > c0.x + 40.0 and not ui.pad.attached, "stick droit : le curseur libre avance")
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(ui.pad.zone == "outils", "RB : zone des outils")
	var tools: Array = ui.panels.pad_controls()
	check(tools[0].has_focus(), "la recherche a le focus")
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.pad.tool_index > 0 and tools[ui.pad.tool_index].has_focus(), "croix droite : bouton suivant, focus visible")
	await _tap(JOY_BUTTON_B)
	check(ui.pad.zone == "arbre" and ui.visible, "B revient à l'arbre sans le fermer")
	# Builds : le panneau ouvert devient une zone ; « Copier ici » pressé au pad, le focus reste visible.
	ui.panels.set_builds_visible(true)
	await _frames(2)
	check("builds" in ui.pad.zones(), "panneau des builds ouvert : zone des builds")
	ui.pad.set_zone("builds")
	var bs: Array = ui.panels.builds_panel.pad_controls()
	check(bs.size() >= 2 and bs[0].has_focus(), "zone des builds : premier bouton pris")
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.pad._tool_controls()[ui.pad.tool_index].text == "Copier ici", "croix droite : « Copier ici »")
	await _tap(JOY_BUTTON_A)
	await _frames(2)
	check(not game.build_info(1)["empty"], "A copie le build actif dans l'emplacement 2")
	var bs2: Array = ui.panels.builds_panel.pad_controls()
	check(ui.pad.tool_index < bs2.size() and bs2[ui.pad.tool_index].has_focus(), "après l'action, le focus revient sur le panneau refait")
	await _tap(JOY_BUTTON_B)
	ui.panels.set_builds_visible(false)
	check(ui.pad.zone == "arbre" and not ("builds" in ui.pad.zones()), "panneau fermé : plus de zone des builds")
	# Couronne : trois greffes trouvées, la première posée au pad.
	var ids: Array = load("res://scripts/content.gd").grafts().keys()
	ids.sort()
	for gid in ids.slice(0, 3):
		game.give_graft(gid)
	ui.grafts_panel.refresh()
	await _frames(2)
	check("couronne" in ui.pad.zones(), "une greffe trouvée : la couronne devient une zone")
	ui.pad.set_zone("couronne")
	ui.pad.crown_index = game.crown_size()
	ui.pad._crown_show()
	await _tap(JOY_BUTTON_A)
	check(ui.grafts_panel.held == ids[0], "A prend la greffe visée")
	check(ui.pad.crown_index < game.crown_size(), "le curseur va sur un emplacement libre")
	await _tap(JOY_BUTTON_A)
	check(game.graft_slot(ids[0]) >= 0, "A la pose dans la couronne")
	await _tap(JOY_BUTTON_X)
	check(game.graft_slot(ids[0]) < 0, "X la retire")
	await _tap(JOY_BUTTON_B)
	await _tap(JOY_BUTTON_B)
	check(not ui.visible and not paused, "B (zone arbre) ferme l'arbre")

	print("Écran titre")
	main.queue_free()
	paused = false
	await _frames(2)
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await _frames(3)
	var first = root.gui_get_focus_owner()
	check(first != null and (first == title.continue_button or first == title.new_button), "une entrée du titre a le focus")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	var second = root.gui_get_focus_owner()
	check(second != null and second != first, "croix bas : entrée suivante")
	var card_text := ""
	for l in title.controls_card.get_child(0).get_children():
		card_text += l.text + " "
	check(card_text.contains("Stick gauche") and card_text.contains("RT"), "le rappel des commandes du titre donne les boutons")
	title.queue_free()

	# Remet les options du poste comme avant le test.
	settings.set_device("clavier")
	settings.reset_bindings()
	if had_cfg:
		var f := FileAccess.open(cfg_path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
	if failures == 0:
		print("MANETTE : tout est bon")
	else:
		print("MANETTE : %d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


const TARGET_WAIT := 8
