## Jalon Éclat G : apprendre un nœud devient un plaisir (animations de l'écran de l'Arbre de vie).
## Vérifie que chaque animation se joue puis finit, que l'état final est celui de la logique (rien
## ne change dans skill_tree.gd ni dans Game), que l'éclair d'écran respecte Settings.flash_strength()
## (contour à 0) et ne dépasse pas 3 par seconde, et que « Réduire les effets » les allège.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/tree_anim_test.gd
extends SceneTree

const TreePlanner = preload("res://scripts/tree_planner.gd")
const Content = preload("res://scripts/content.gd")

var failures := 0
var main
var ui
var game
var Settings


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


## Attend la fin de toutes les animations (au plus « limit » images).
func _settle(limit := 400) -> int:
	var n := 0
	await _frames(2)
	while ui.effects_active() and n < limit:
		await process_frame
		n += 1
	return n


func _path_to_type(kind: String) -> Array:
	for n in game.tree.nodes:
		if n["type"] != kind or n["requires_flag"] != "":
			continue
		var p: Array = TreePlanner.shortest_path(game.tree, game.allocated, n["id"])
		var ok := not p.is_empty()
		for id in p:
			if game.lock_reason(id) != "" or game.tree.nodes[id]["type"] == "mutation":
				ok = false
		if ok:
			return p
	return []


func _states_match() -> bool:
	var saved: Dictionary = ui._states.duplicate()
	ui._refresh_states()
	return saved == ui._states


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(5)
	main.autotest = false
	game = root.get_node("Game")
	Settings = root.get_node("Settings")
	ui = main.tree_ui
	game.reset()
	game.points = 80
	Settings.reduce_effects = false
	Settings.flash_scale = 1.0
	ui.play_intro = false
	ui.toggle()
	await _frames(3)
	check(ui.visible, "l'arbre est ouvert")

	print("Apprendre un petit nœud")
	var start: Array = game.tree.nodes[0]["neighbors"].duplicate()
	start.sort()
	var small: int = start[0]
	game.allocate(small)
	await _frames(2)
	check(ui._blooms.has(small) and not ui._big.has(small), "un petit nœud éclôt, sans grande fleur")
	var n_blooms: int = await _settle()
	check(not ui.effects_active() and n_blooms < 200, "l'éclosion finit (%d images)" % n_blooms)
	check(game.allocated.has(small) and _states_match(), "l'état final est celui de Game")

	print("Nœud clé, maîtrise, mutation")
	for kind in ["keystone", "mastery"]:
		var path := _path_to_type(kind)
		if path.is_empty():
			print("  (aucun nœud « %s » joignable sans règle : ignoré)" % kind)
			continue
		var before: int = game.points
		for id in path.slice(0, path.size() - 1):
			game.allocate(id)
		await _settle()
		var target: int = path[path.size() - 1]
		game.allocate(target)
		await _frames(2)
		check(ui._big.has(target), "%s : s'ouvre en grande fleur" % kind)
		var flashed := false
		for i in 120:
			await process_frame
			if ui._flash_k > 0.0:
				flashed = true
		check(flashed, "%s : un éclair d'écran doux" % kind)
		await _settle()
		check(ui._big.is_empty() and game.allocated.has(target) and game.points == before - path.size(), "%s : fleur finie, points inchangés par l'animation" % kind)
	check(_states_match(), "états de l'arbre cohérents")

	print("Éclair d'écran : réglage et plafond")
	Settings.flash_scale = 0.0
	ui._contours.clear()
	ui._flash_k = 0.0
	var key_id := 0
	for id in game.allocated:
		if game.tree.nodes[id]["type"] != "root":
			key_id = id
	ui._flower_burst(key_id)
	check(ui._flash_k == 0.0 and ui._contours.has(key_id), "éclair à 0 : seulement un contour lumineux")
	Settings.flash_scale = 1.0
	ui._flash_times.clear()
	ui._contours.clear()
	for i in 6:
		ui._flower_burst(key_id)
	check(ui._flash_times.size() <= 3, "jamais plus de 3 éclairs par seconde (%d)" % ui._flash_times.size())
	await _settle()

	print("Oublier un nœud")
	var leaf := -1
	for id in game.allocated:
		if id != 0 and game.can_refund(id):
			leaf = id
	check(leaf >= 0, "un nœud oubliable existe")
	var pts: int = game.points
	check(game.refund(leaf, true), "oubli (logique inchangée)")
	await _frames(2)
	check(ui._wilts.has(leaf), "le nœud oublié se fane")
	await _settle()
	check(ui._wilts.is_empty() and not game.allocated.has(leaf) and game.points == pts + 1, "fanage fini, point rendu")
	check(_states_match(), "états cohérents après l'oubli")

	print("Bascule de build")
	game.at_sanctuary = true
	var count: int = game.allocated.size()
	var free_slot := -1
	for i in game.build_slots():
		if i != game.active_build and game.build_empty(i):
			free_slot = i
			break
	check(free_slot >= 0 and game.switch_build(free_slot), "bascule vers un build neuf")
	await _frames(3)
	check(ui._wave >= 0.0 and not ui._wilts.is_empty(), "la vague part de la graine, les nœuds se fanent")
	await _settle()
	check(ui._wilts.is_empty() and ui._wave < 0.0 and game.allocated.size() == 1, "vague finie, arbre vidé")
	check(game.switch_build(0), "retour au premier build")
	await _frames(3)
	check(ui._wave >= 0.0 and not ui._glints.is_empty(), "les nœuds se rallument dans la vague")
	check(ui._glints.size() <= int(Content.feel().get("tree", {}).get("recompose", {}).get("max", 90)), "nombre d'étincelles plafonné (%d)" % ui._glints.size())
	await _settle()
	check(game.allocated.size() == count and ui._glints.is_empty(), "retour : mêmes nœuds, animation finie")
	check(_states_match(), "états cohérents après la bascule")

	print("Greffe posée dans la couronne")
	var gid: String = str(Content.grafts().keys()[1])
	if not game.graft_inventory.has(gid):
		game.graft_inventory.append(gid)
	game.tree_changed.emit()
	await _frames(2)
	var panel = ui.grafts_panel
	check(game.place_graft(0, gid), "greffe posée")
	await _frames(2)
	check(panel._roots.has(0), "des racines poussent dans l'emplacement")
	var r := 0
	while not panel._roots.is_empty() and r < 200:
		await process_frame
		r += 1
	check(panel._roots.is_empty(), "racines finies (%d images)" % r)

	print("Réduire les effets")
	Settings.reduce_effects = true
	var nxt := -1
	for n in game.tree.nodes:
		if game.can_allocate(n["id"]) and n["type"] == "small":
			nxt = n["id"]
			break
	check(nxt >= 0, "un nœud à apprendre existe")
	if nxt >= 0:
		game.allocate(nxt)
		await _frames(2)
		check(ui._big.is_empty() and ui._blooms.has(nxt) and ui._blooms[nxt] >= 0.0, "éclosion simple, sans sève ni fleur")
		check(game.refund(nxt, true), "oubli")
		await _frames(2)
		check(ui._wilts.is_empty(), "pas de fanage animé")
	Settings.reduce_effects = false
	await _settle()
	check(not ui.effects_active(), "plus aucune animation en cours")

	print("Aucune animation ne laisse de reste : ", "ok" if failures == 0 else "%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)
