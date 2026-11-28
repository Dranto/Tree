## Test de la fiche des statistiques en jeu (jalon 14.5, lot S) : la touche C (clic du stick gauche
## à la manette) la montre tant qu'elle est tenue, sans mettre le jeu en pause ; elle donne vie,
## dégâts, vitesses, critique, défense et l'attaque cumulée, tirées de Game.stats ; elle se met à
## jour quand les statistiques changent ; la touche est réassignable ; le glyphe de découverte
## apparaît au niveau 3 et s'efface une fois la touche tenue.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/stats_test.gd
## Ne lit ni n'écrit la sauvegarde de partie.
extends SceneTree

var failures := 0
var settings


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _texts(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	for c in node.get_children():
		out += _texts(c)
	return out


func _run() -> void:
	settings = root.get_node("Settings")
	var game = root.get_node("Game")
	settings.reset_bindings()

	print("Commande")
	check("show_stats" in settings.GAME_ACTIONS and settings.action_keys["show_stats"] == KEY_C, "action « show_stats » sur C par défaut")
	check(InputMap.has_action("show_stats") and not InputMap.action_get_events("show_stats").is_empty(), "action créée")
	var pad_ok := false
	for e in InputMap.action_get_events("show_stats"):
		if e is InputEventJoypadButton and e.button_index == JOY_BUTTON_LEFT_STICK:
			pad_ok = true
	check(pad_ok, "clic du stick gauche à la manette")
	check(settings.set_action_key("show_stats", KEY_TAB) != "", "Tab (l'arbre) reste refusé")
	check(settings.set_action_key("show_stats", KEY_X) == "", "réassignable (X)")
	settings.reset_bindings()

	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	await _frames(5)
	var card = main.hud.stats_card
	check(card != null and not card.visible, "fiche cachée au départ")

	print("Fiche tenue")
	Input.action_press("show_stats")
	await _frames(20)
	check(card.visible and card.alpha > 0.9, "visible tant que la touche est tenue")
	check(not paused, "le jeu ne s'arrête pas")
	var txt: String = _texts(card)
	check(txt.contains("Vie maximale") and txt.contains("Dégâts") and txt.contains("Vitesse d'attaque") and txt.contains("Vitesse de déplacement"), "vie, dégâts, vitesses")
	check(txt.contains("Chance de critique") and txt.contains("Armure"), "critique et défense")
	check(txt.contains("100") and txt.contains("230"), "valeurs de départ (vie 100, vitesse 230)")
	check(txt.contains(": "), "ligne d'attaque")
	var before_pos: Vector2 = main.player.position
	await _frames(10)
	Input.action_release("show_stats")
	await _frames(20)
	check(not card.visible, "cachée au relâchement")

	print("Mise à jour")
	var dmg_before: float = game.stats["damage"]
	game.stats["damage"] = dmg_before + 8.0
	card._base = card._base.duplicate()
	Input.action_press("show_stats")
	await _frames(6)
	txt = _texts(card)
	check(txt.contains("20") or txt.contains("%d" % int(dmg_before + 8.0)), "dégâts relus après un changement")
	Input.action_release("show_stats")
	game.stats["damage"] = dmg_before
	await _frames(15)

	print("Pause")
	paused = true
	Input.action_press("show_stats")
	await _frames(15)
	check(not card.visible, "pas de fiche par-dessus une pause (arbre, menu, carte)")
	paused = false
	Input.action_release("show_stats")

	print("Glyphe de découverte")
	var g = main.hud.glyphs
	game.flags["tuto_bouger"] = true
	game.flags["tuto_esquive"] = true
	game.flags["tuto_competence"] = true
	game.flags["tuto_arbre"] = true
	game.flags.erase("tuto_stats")
	game.level = 2
	check(g._pick(main.player) == "", "pas avant le niveau 3")
	game.level = 3
	check(g._pick(main.player) == "stats", "le glyphe des statistiques au niveau 3")
	check(g.glyph_for("stats") == ["keys", ["C"]], "glyphe : la touche C")
	Input.action_press("show_stats")
	g._validate(main.player)
	Input.action_release("show_stats")
	check(g.done("stats") and g._pick(main.player) == "", "touche tenue : le glyphe ne revient plus")

	main.queue_free()
	await _frames(2)
	settings.reset_bindings()
	if failures == 0:
		print("STATISTIQUES : tout est bon")
	else:
		print("STATISTIQUES : %d échec(s)" % failures)
	quit(1 if failures > 0 else 0)
