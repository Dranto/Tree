## Test des objectifs, de la veine de sève, de la carte et de la fin de la tranche : la suite d'objectifs
## principaux s'enchaîne par des appels directs, les facultatifs rapportent leur point, la fin se
## déclenche une seule fois, tout survit à une sauvegarde.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/objectives_test.gd
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree

var failures := 0
var main
var done_log: Array = []


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


func _fake(group: String, id: String, pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.set_meta("x", 0)
	n.set_script(load("res://tests/objectives_fake.gd"))
	n.id = id
	n.position = pos
	n.add_to_group(group)
	main.add_child(n)
	return n


func _run() -> void:
	var game = root.get_node("Game")
	var obj = root.get_node("Objectives")
	game.reset()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	await _frames(3)
	main.spawn_timer = 1.0e9
	main.set_physics_process(false)
	main.player.set_physics_process(false)
	obj.completed.connect(func(id): done_log.append(id))

	print("Départ")
	# Les objectifs de Ronce et les objectifs communs (les autres régions ont les leurs).
	var ronce_list: Array = obj.list().filter(func(o): return str(o.get("region", "")) in ["", "ronce"])
	check(ronce_list.size() == 10 and ronce_list.filter(func(o): return o.get("main", false)).size() == 7, "10 objectifs dont 7 principaux (la finale comprise)")
	check(obj.current().get("id", "") == "premier_noeud", "le premier objectif est le premier nœud")
	check(obj.main_done_count() == 0, "aucun objectif accompli")
	check(main.quest_ui != null and obj.main == main, "l'interface des objectifs est branchée")

	print("Monde réel")
	check(not get_nodes_in_group("sanctuaire").is_empty() and not get_nodes_in_group("autel").is_empty(), "les sanctuaires et les autels du roncier sont dans leurs groupes")
	# La suite se joue dans un monde sans sanctuaire ni autel, puis avec des faux bien placés.
	for g in ["sanctuaire", "autel"]:
		for n in get_nodes_in_group(g):
			n.remove_from_group(g)

	print("Premier nœud")
	game.points = 50
	var nid: int = game.tree.nodes[0]["neighbors"][0]
	game.allocate(nid)
	obj.check()
	check(obj.is_done("premier_noeud") and "premier_noeud" in done_log, "apprendre un nœud accomplit l'objectif")
	check(obj.current().get("id", "") == "noeud_cle", "sans sanctuaire ni autel dans le monde, ces objectifs sont passés")

	print("Sanctuaires et autels")
	var s1 := _fake("sanctuaire", "lisiere", Vector2(800, -700))
	_fake("autel", "ronce_1", Vector2(1100, -900))
	check(obj.current().get("id", "") == "sanctuaire", "avec un sanctuaire dans le monde, c'est l'objectif en cours")
	check(obj.target_pos(obj.current()) == s1.position, "la flèche vise le sanctuaire")
	game.flags["sanctuaire_graine"] = true
	obj.check()
	check(not obj.is_done("sanctuaire"), "le sanctuaire de la graine ne compte pas")
	game.flags["sanctuaire_lisiere"] = true
	obj.check()
	check(obj.is_done("sanctuaire"), "un sanctuaire de Ronce ravivé accomplit l'objectif")
	check(obj.current().get("id", "") == "autel", "l'autel suit")
	game.flags["autel_ronce_1_vu"] = true
	game.flags["secret_ronce_vu"] = true
	obj.check()
	check(not obj.is_done("autel") and not obj.is_done("secret"), "apercevoir un autel ou le secret n'accomplit rien")
	game.flags["autel_ronce_1"] = true
	obj.check()
	check(obj.is_done("autel") and not obj.is_done("autels"), "un autel accomplit l'objectif, pas « tous les autels »")

	print("Nœud clé de Ronce")
	check(not obj.is_done("noeud_cle"), "pas de nœud clé au départ")
	var key_id := -1
	for n in game.tree.nodes:
		if n["branch"] == 0 and n["type"] == "keystone":
			key_id = n["id"]
			break
	var planner = main.tree_ui.panels.planner
	var path: Array = planner.path_to(key_id)
	game.points = path.size() + 1
	planner.learn_path(path)
	obj.check()
	check(game.allocated.has(key_id) and obj.is_done("noeud_cle"), "apprendre un nœud clé de Ronce accomplit l'objectif")
	check(obj.current().get("id", "") == "coeur", "le Cœur suit")
	check(obj.target_pos(obj.current()) == main.heart.center, "la flèche vise le Cœur")

	print("Étape sautée")
	var flags_saved: Dictionary = game.flags.duplicate(true)
	game.flags.erase("obj_autel")
	game.flags.erase("autel_ronce_1")
	game.flags["ronce_coeur_purifie"] = true
	obj.check()
	check(obj.current().get("id", "") == "boss", "Cœur purifié avant l'autel : l'objectif en cours est le boss, pas l'autel")
	check(obj.skipped(obj.get_def("autel")) and not obj.skipped(obj.get_def("boss")), "l'autel est une étape passée")
	game.flags.erase("ronce_coeur_purifie")
	game.flags.erase("obj_coeur")
	game.flags.erase("obj_noeud_cle")
	check(obj.current().get("id", "") == "autel" and not obj.skipped(obj.get_def("autel")), "sans grande étape franchie, l'ordre du début reste libre : l'autel redevient l'objectif")
	game.flags["ronce_coeur_purifie"] = true
	obj.check()
	var vein = main.quest_ui.vein
	vein._check = 0.0
	vein._process(0.01)
	check(obj.followed().get("id", "") == "boss" and vein._target == main.arena.center, "la veine de sève mène à l'arène du boss")
	game.flags = flags_saved

	print("Trois Cœurs, puis le boss")
	var Rg = load("res://scripts/regions.gd")
	var cur_heart: Dictionary = obj.get_def("coeur")
	check(Rg.heart_count("ronce") == 3 and main.region_hearts["ronce"].size() == 3, "trois Cœurs dans le roncier")
	check(obj.progress(cur_heart) == [0, 3], "compteur des Cœurs : 0 / 3")
	var first = main.next_heart("ronce", main.player.position)
	game.flags[Rg.heart_part_flag("ronce", first.index)] = true
	obj.check()
	check(not obj.is_done("coeur") and obj.progress(cur_heart) == [1, 3], "un Cœur purifié : 1 / 3, l'objectif reste ouvert")
	var next = main.next_heart("ronce", main.player.position)
	check(next != first and obj.target_pos(cur_heart) == next.center, "la flèche vise un autre Cœur, pas celui déjà purifié")
	game.flags.erase(Rg.heart_part_flag("ronce", first.index))
	game.flags["ronce_coeur_purifie"] = true
	obj.check()
	check(obj.is_done("coeur") and obj.current().get("id", "") == "boss", "Cœur purifié : le boss est l'objectif")
	check(obj.target_pos(obj.current()) == main.arena.center, "la flèche vise l'arène")
	check(not obj.ending_due(), "pas de fin avant le boss")
	game.flags["ronce_boss_vaincu"] = true
	obj.check()
	check(obj.is_done("boss") and obj.current("ronce").is_empty(), "boss vaincu : tous les objectifs principaux de Ronce sont faits")
	check(done_log.count("boss") == 1, "l'objectif du boss est accompli une seule fois")
	check(obj.complete("boss") == false, "accomplir deux fois ne fait rien")

	print("Facultatifs")
	var pts: int = game.points
	for i in 3:
		obj._on_elite_killed()
	check(obj.is_done("elites"), "trois élites accomplissent l'objectif")
	check(game.points == pts + 1, "et rapportent un point d'arbre")
	obj.check()
	check(game.points == pts + 1, "le point n'est donné qu'une fois")
	game.flags["secret_ronce"] = true
	obj.check()
	check(obj.is_done("secret"), "un secret accomplit l'objectif")

	print("Morts")
	main.deaths += 2
	check(obj.deaths_total() == 2, "les morts sont comptées")
	obj._process(1.0)
	check(int(game.flags.get("stat_morts", 0)) == 2 and obj.deaths_total() == 2, "elles sont reportées dans les drapeaux, sans double compte")

	print("Carte (plus de journal)")
	var q = main.quest_ui
	check(q.get("journal") == null and not InputMap.has_action("toggle_journal"), "plus de journal ni de touche J")
	q.toggle("carte")
	check(paused and q.current == "carte" and q.world_map.visible, "M ouvre la carte")
	q.toggle("carte")
	check(not paused and q.current == "" and not q.world_map.visible, "M referme la carte")
	main.tree_ui.toggle()
	q.toggle("carte")
	check(q.current == "", "la carte ne s'ouvre pas par-dessus l'Arbre de vie")
	main.tree_ui.toggle()
	await _frames(2)

	print("Reverdie de la région (sans écran ni texte)")
	check(obj.ending_due(), "la célébration est due après le boss")
	q._process(q.ENDING_DELAY - 1.0)
	check(not q.fanfare.active, "elle n'a pas lieu avant le délai")
	q._process(2.0)
	check(q.fanfare.active and not paused, "elle se lance après le délai, sans pause")
	check(main.hud.get_parent().visible, "l'interface de jeu reste là")
	check(bool(game.flags.get("ronce_fin_vue", false)) and not obj.ending_due(), "elle est marquée comme vue")
	check(not q.fanfare is CanvasItem, "aucun texte ni médaillon par-dessus le jeu")
	check("ronce" in q.world_map.pending_reveal, "la carte rejouera la région qui reverdit")
	check(main.spawn_paused, "aucun Flétri ne naît pendant la célébration")
	q.fanfare.set_time(30.0)
	check(not q.fanfare.active and not main.spawn_paused, "elle s'efface seule, les Flétris reviennent")
	q.toggle("carte")
	check(q.world_map._reveal.has("ronce") and q.world_map.pending_reveal.is_empty(), "la carte joue la reverdie et le sceau brisé")
	q.toggle("carte")
	q._process(60.0)
	await _frames(2)
	check(not q.fanfare.active, "la célébration ne revient pas")

	print("Sauvegarde")
	var data: Dictionary = root.get_node("SaveGame").capture(main)
	var flags_before: Dictionary = game.flags.duplicate(true)
	game.reset()
	check(not obj.is_done("boss"), "une nouvelle partie remet les objectifs à zéro")
	root.get_node("SaveGame").apply(JSON.parse_string(JSON.stringify(data)), main)
	check(obj.is_done("boss") and obj.is_done("noeud_cle") and not obj.ending_due(), "objectifs et fin vue survivent à la sauvegarde")
	var diff: Array = []
	for k in flags_before:
		if game.flags.get(k) != flags_before[k]:
			diff.append("%s: %s -> %s" % [k, flags_before[k], game.flags.get(k)])
	check(diff.is_empty() and game.flags.size() == flags_before.size(), "les drapeaux sont identiques " + str(diff))
	var count := done_log.size()
	obj.check()
	check(done_log.size() == count, "rien n'est accompli une seconde fois au chargement")

	main.autosave_enabled = false
	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
