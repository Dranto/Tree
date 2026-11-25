## Test du mode démo (jalon 12 E, scripts/demo.gd) : régions hors Ronce fermées par la ronce, nœuds
## de l'arbre hors démo, objectifs, fin de démo (sceau de la graine), et sauvegarde de la démo reprise
## par le jeu complet sans perte (et l'inverse).
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/demo_test.gd
extends SceneTree

const Demo = preload("res://scripts/demo.gd")
const Regions = preload("res://scripts/regions.gd")
const PATH := "user://tests/demo_test.json"

var failures := 0
var game
var save
var obj
var main


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
		await physics_frame


func _new_main() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await process_frame
	await process_frame
	main.autosave_enabled = false


func _free_main() -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _run() -> void:
	game = root.get_node("Game")
	save = root.get_node("SaveGame")
	obj = root.get_node("Objectives")
	save.delete_save(PATH)

	print("Indicateur")
	Demo.forced = -1
	check(not game.is_demo(), "jeu complet par défaut (ni export « demo » ni --demo)")
	Demo.forced = 1
	check(game.is_demo(), "Game.is_demo() suit l'indicateur")
	check(Demo.regions() == ["ronce"], "la démo ouvre la région de Ronce seule")

	print("Monde fermé")
	game.reset()
	await _new_main()
	check(main.demo_wall != null, "la haie de la démo existe")
	check(Demo.wall_pieces().size() == 3, "trois pièces : deux bords du secteur, l'arc de l'oasis")
	var ronce := Regions.center("ronce")
	check(Demo.keep_inside(ronce, 14.0) == ronce, "le centre du roncier est libre")
	check(Demo.keep_inside(Vector2(0, 100), 14.0) == Vector2(0, 100), "l'oasis de la graine est libre")
	check(Demo.keep_inside(Regions.arena_center("ronce"), 14.0) == Regions.arena_center("ronce"), "l'arène de la Mère-Ronce est libre")
	for sp in Regions.heart_spots("ronce"):
		check(Demo.allowed(sp["pos"], 60.0), "Cœur de Ronce à %s accessible" % str(sp["pos"].round()))
	for id in Regions.ids():
		if id == "ronce":
			continue
		var c := Regions.center(id)
		var q := Demo.keep_inside(c, 14.0)
		check(q != c and Regions.region_at(q) in ["ronce", ""], "centre de %s fermé, ramené au bord" % id)
	# Le héros ne franchit pas la ronce : poussé vers le marais de Spore, il reste dehors.
	main.player.position = Vector2.from_angle(Regions.angle_of("ronce") + Regions.half_width()) * 1400.0
	var push := Vector2.from_angle(Regions.angle_of("spore"))
	for i in 120:
		main.player.position += push * 6.0
		main.player.position = main.clamp_to_world(main.player.position)
	await _frames(2)
	check(Regions.region_at(main.player.position) != "spore", "le héros reste de ce côté de la haie")
	# Les Flétris ne naissent pas derrière la ronce.
	main.player.position = Vector2.from_angle(Regions.angle_of("ronce") + Regions.half_width() - 0.05) * 1200.0
	var outside := 0
	for i in 40:
		main._spawn_enemy()
	await _frames(2)
	for e in main.enemies:
		if is_instance_valid(e) and not Demo.allowed(e.position, 0.0):
			outside += 1
	check(outside == 0, "aucun Flétri derrière la ronce (%d nés)" % main.enemies.size())
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	await _frames(2)

	print("Arbre")
	var spore_ash := -1
	var ronce_ash := -1
	var closed_border := -1
	var open_border := -1
	var spore_small := -1
	for n in game.tree.nodes:
		var f := str(n["requires_flag"])
		if n["type"] == "withered" and f.begins_with("spore_") and spore_ash < 0:
			spore_ash = n["id"]
		if n["type"] == "withered" and f.begins_with("ronce_") and ronce_ash < 0:
			ronce_ash = n["id"]
		if int(n["border"]) >= 0:
			var names: Array = game.tree.BRANCHES.map(func(b): return b["id"])
			var pair := [names[n["branch"]], names[n["border"]]]
			if not "ronce" in pair and closed_border < 0:
				closed_border = n["id"]
			if "ronce" in pair and open_border < 0:
				open_border = n["id"]
		if n["branch"] >= 0 and game.tree.BRANCHES[n["branch"]]["id"] == "spore" and n["type"] == "small" and int(n["border"]) < 0 and spore_small < 0:
			spore_small = n["id"]
	check(spore_ash >= 0 and game.lock_reason(spore_ash) == game.DEMO_LOCK, "nœud flétri de Spore : « %s »" % game.DEMO_LOCK)
	check(ronce_ash >= 0 and game.lock_reason(ronce_ash) != game.DEMO_LOCK, "nœud flétri de Ronce : libéré par la démo")
	check(closed_border >= 0 and game.lock_reason(closed_border) == game.DEMO_LOCK, "frontière hybride sans Ronce fermée")
	check(open_border >= 0 and not Demo.node_closed(game.tree.nodes[open_border]), "frontière hybride de Ronce ouverte")
	check(spore_small >= 0 and game.lock_reason(spore_small) == game.DEMO_LOCK, "les autres branches sont sous la ronce (ni lues ni apprises)")
	var ronce_bi: int = game.tree.BRANCHES.map(func(b): return b["id"]).find("ronce")
	var ronce_open: Array = game.tree.nodes.filter(func(n): return n["branch"] == ronce_bi and int(n["border"]) < 0 and str(n["requires_flag"]) == "")
	check(not ronce_open.is_empty() and not ronce_open.any(func(n): return Demo.node_closed(n)), "toute la branche de Ronce se lit (%d nœuds)" % ronce_open.size())
	check(not Demo.node_closed(game.tree.nodes[0]), "la graine reste ouverte")
	var ui = main.tree_ui
	ui.toggle()
	await _frames(2)
	var tip: Array = ui.tooltip_lines(game.tree.nodes[spore_small], "locked")
	check(tip.size() == 1 and tip[0][0] == game.DEMO_LOCK, "infobulle d'un nœud de Spore : « %s » seulement" % game.DEMO_LOCK)
	ui.zoom = 0.9
	ui.cam = game.tree.nodes[spore_small]["pos"]
	ui.queue_redraw()
	await _frames(2)
	var sname := str(game.tree.nodes[spore_small]["name"])
	check(not ui.layout_labels().any(func(l): return str(l[1]) == sname), "pas de libellé sous la ronce")
	check(ui.panels._preview_for(spore_small)["route"].is_empty(), "pas de chemin tracé vers un nœud sous la ronce")
	var spore_far := -1
	for n in game.tree.nodes:
		if int(n["ring"]) >= 4 and n["branch"] == ronce_bi and int(n["border"]) < 0 and not Demo.node_closed(n):
			spore_far = n["id"]
			break
	var r_path: Array = ui.panels.planner.route_to(spore_far)
	check(not r_path.is_empty() and not r_path.any(func(i): return Demo.node_closed(game.tree.nodes[i])), "les chemins vers Ronce contournent la ronce")
	ui.panels.set_query(str(game.tree.nodes[spore_small]["name"]))
	check(not ui.panels.matches.has(spore_small), "la recherche ne trouve pas les nœuds sous la ronce")
	ui.panels.set_query("")
	ui.toggle()
	await _frames(2)

	print("Objectifs")
	var ids: Array = obj.list().map(func(o): return o["id"])
	check(not ids.any(func(i): return str(i).begins_with("spore_") or str(i).begins_with("racine_")), "pas d'objectif des régions fermées")
	check("demo_sceau" in ids and "boss" in ids, "objectifs de Ronce et retour au sceau")
	check(obj.current().get("id", "") != "demo_sceau", "le sceau n'est pas un objectif avant la Mère-Ronce")

	print("Fin de la démo")
	check(not Demo.finished(game.flags), "démo pas finie au départ")
	for i in Regions.heart_count("ronce"):
		game.flags[Regions.heart_part_flag("ronce", i)] = true
	game.flags[Regions.heart_flag("ronce")] = true
	game.flags[Regions.boss_flag("ronce")] = true
	game.flags[Regions.ending_flag("ronce")] = true
	for o in obj.list():
		if str(o.get("region", "")) == "ronce" or o["id"] == "premier_noeud":
			game.flags[obj.FLAG_PREFIX + o["id"]] = true
	check(Demo.finished(game.flags), "la Mère-Ronce vaincue finit la démo")
	check(obj.followed().get("id", "") == "demo_sceau", "la veine mène au sceau de la graine")
	check(obj.target_pos(obj.followed()) == main.finale.descent_point(), "cible : la brèche au pied de la graine")
	check(main.finale.state == "fermee", "la brèche reste scellée")
	main.player.position = Vector2(0, 260)
	await _frames(30)
	check(game.flags.get(Demo.SEAL_SEEN, false), "le héros a vu le sceau")
	check(main.demo_wall.finished and main.demo_wall.line_k > 0.0, "le sceau bat, la ligne s'écrit")
	check(not main.quest_ui.world_ending.active, "pas de fin d'aventure ni d'écran")

	print("Sauvegarde de la démo reprise par le jeu complet")
	game.add_xp(600.0)
	var learned := 0
	while game.points > 0 and learned < 8:
		var done := false
		for n in game.tree.nodes:
			if game.can_allocate(n["id"]):
				game.allocate(n["id"])
				learned += 1
				done = true
				break
		if not done:
			break
	main.player.position = Regions.center("ronce")
	var before := {"level": game.level, "points": game.points, "uids": game.allocated_uids(), "flags": game.flags.duplicate(true), "xp": game.xp}
	check(save.save_now(main, PATH), "écriture (démo)")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(int(data.get("version", 0)) == save.VERSION, "même format que le jeu complet (version %d)" % save.VERSION)
	await _free_main()
	Demo.forced = 0
	game.reset()
	await _new_main()
	check(main.demo_wall == null, "jeu complet : pas de haie")
	check(save.load_into(main, PATH), "chargement dans le jeu complet")
	check(game.level == before["level"] and game.points == before["points"] and is_equal_approx(game.xp, before["xp"]), "niveau, points, expérience")
	check(game.allocated_uids() == before["uids"], "nœuds appris (%d)" % before["uids"].size())
	# Valeur par valeur : le JSON relit les nombres en flottants (1 → 1.0), égaux pour le jeu.
	var same: bool = game.flags.size() == before["flags"].size()
	for k in before["flags"]:
		same = same and game.flags.has(k) and game.flags[k] == before["flags"][k]
	check(same, "drapeaux (%d)" % before["flags"].size())
	check(main.player.position.is_equal_approx(Regions.center("ronce")), "position")
	check(obj.list().any(func(o): return o["id"] == "spore_sanctuaire") and not obj.list().any(func(o): return o["id"] == "demo_sceau"), "jeu complet : la suite (Spore) s'ouvre, plus de sceau")
	check(obj.followed().get("region", "") == "spore", "le jeu complet reprend à la région suivante")

	print("Partie du jeu complet reprise dans la démo")
	main.player.position = Regions.center("spore")
	check(save.save_now(main, PATH), "écriture (jeu complet, héros dans le marais)")
	await _free_main()
	Demo.forced = 1
	game.reset()
	await _new_main()
	check(save.load_into(main, PATH), "chargement dans la démo")
	check(Demo.allowed(main.player.position, main.player.radius), "le héros repart de ce côté de la ronce")
	check(game.allocated_uids() == before["uids"], "nœuds appris gardés")

	await _free_main()
	Demo.forced = -1
	save.delete_save(PATH)
	print("DEMO %s (%d échec(s))" % ["OK" if failures == 0 else "ÉCHEC", failures])
	quit(1 if failures > 0 else 0)
