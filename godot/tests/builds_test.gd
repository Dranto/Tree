## Test des builds multiples et de l'oubli payant (jalon 11 I) : coût de l'oubli selon l'anneau et le
## sanctuaire, emplacements de build (copier, charger, build neuf, build trop grand pour les points),
## annulation gratuite, sauvegarde version 8 et migration depuis la version 7, panneau de l'arbre.
## Lancer : tools/godot.sh --headless -s res://tests/builds_test.gd
extends SceneTree

const TreePlanner = preload("res://scripts/tree_planner.gd")
const Content = preload("res://scripts/content.gd")

var failures := 0
var game


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


## Premier nœud de l'anneau « ring » joignable sans nœud flétri ni mutation, et le chemin qui y mène.
func _path_to_ring(ring: int, owned: Dictionary) -> Array:
	var tree = game.tree
	for n in tree.nodes:
		if n["ring"] != ring or n["type"] in ["withered", "mutation"] or n["requires_flag"] != "":
			continue
		var p: Array = TreePlanner.shortest_path(tree, owned, n["id"])
		var ok := not p.is_empty()
		for id in p:
			if game.lock_reason(id) != "" or tree.nodes[id]["type"] == "mutation":
				ok = false
		if ok:
			return p
	return []


func _learn(path: Array) -> void:
	for id in path:
		game.allocate(id)


func _run() -> void:
	game = root.get_node("Game")
	var save = root.get_node("SaveGame")
	var r: Dictionary = Content.respec()
	var free_rings: int = int(r.get("free_rings", 3))
	game.reset()

	print("Barème d'oubli")
	check(int(r.get("slots", 0)) >= 3 and int(r.get("slots", 0)) <= 5, "3 à 5 emplacements de build (data/respec.json)")
	game.points = 40
	var far: Array = _path_to_ring(free_rings + 4, game.allocated)
	check(far.size() >= free_rings + 4, "chemin vers l'anneau %d (%d nœuds)" % [free_rings + 4, far.size()])
	_learn(far)
	var near_id: int = far[0]
	var far_id: int = far.back()
	check(game.tree.nodes[near_id]["ring"] <= free_rings and game.refund_cost(near_id) == 0, "oublier près de la graine est gratuit")
	var cost: int = game.refund_cost(far_id)
	check(cost > 0, "oublier loin de la graine coûte de l'essence (%d)" % cost)
	var deeper: int = -1
	for id in far:
		if game.tree.nodes[id]["ring"] == free_rings + 1:
			deeper = id
	check(deeper >= 0 and game.refund_cost(deeper) < cost, "le coût grandit avec l'anneau")
	game.xp = 0.0
	var pts: int = game.points
	check(not game.refund(far_id) and game.allocated.has(far_id) and game.points == pts, "sans essence, l'oubli est refusé")
	game.at_sanctuary = true
	check(game.refund_cost(far_id) == 0 and game.refund_cost(far_id, true) == cost, "au sanctuaire, l'oubli est gratuit")
	check(game.refund(far_id) and game.points == pts + 1, "oubli gratuit au sanctuaire, point rendu")
	game.at_sanctuary = false
	game.allocate(far_id)
	game.xp = float(cost) + 5.0
	check(game.refund(far_id) and is_equal_approx(game.xp, 5.0), "oubli payé sur l'expérience du niveau en cours")

	print("Annulation")
	var planner = TreePlanner.new(game)
	game.xp = 0.0
	var step: Array = planner.path_to(far_id)
	check(step.size() == 1 and planner.learn_path(step), "réapprendre le nœud lointain")
	check(planner.undo() and not game.allocated.has(far_id), "défaire un apprentissage ne coûte rien")
	check(planner.learn_path(planner.path_to(far_id)), "réappris")
	planner.clear_undo()
	check(not planner.can_undo(), "la pile d'annulation se vide (fermeture de l'arbre)")

	print("Builds")
	check(game.build_slots() == int(r["slots"]) and game.active_build == 0, "emplacement 0 actif au départ")
	var first_uids: Array = game.allocated_uids()
	var total: int = game.points + game.allocated.size() - 1
	game.rename_build(0, "Épines")
	check(game.build_name(0) == "Épines" and game.build_name(1) == "Build 2", "noms des emplacements")
	game.set_graft(0, Content.grafts().keys()[0])
	var crown0: Array = game.crown.duplicate()
	check(game.copy_build_to(1) and not game.build_empty(1) and game.build_info(1)["nodes"] == first_uids.size(), "copier le build actif dans l'emplacement 2")
	check(game.build_empty(2) and game.switch_cost(2) > 0, "charger un build neuf hors sanctuaire coûte l'oubli des nœuds lointains")
	game.xp = 0.0
	check(not game.switch_build(2) and game.active_build == 0, "sans essence, la bascule est refusée")
	game.at_sanctuary = true
	check(game.switch_cost(2) == 0, "au sanctuaire, la bascule est gratuite")
	check(game.switch_build(2) and game.active_build == 2 and game.allocated.size() == 1 and game.points == total, "build neuf : tous les points rendus")
	check(game.crown == crown0, "un build neuf garde la couronne")
	# Un autre build, proche de la graine.
	var other: Array = _path_to_ring(free_rings, game.allocated)
	_learn(other)
	check(game.points == total - other.size(), "le build neuf dépense ses points")
	check(game.switch_build(0) and game.allocated_uids() == first_uids and game.points == total - first_uids.size(), "recharger le premier build : mêmes nœuds, mêmes points")
	check(game.crown == crown0 and game.build_name(0) == "Épines", "couronne et nom du premier build")
	check(game.build_info(2)["nodes"] == other.size(), "le build neuf est enregistré dans son emplacement")
	game.at_sanctuary = false
	# Hors sanctuaire : le coût est celui des nœuds qui disparaissent (ici, presque tout le premier build).
	var expect := 0
	for id in game.allocated:
		var keep := false
		for o in other:
			if o == id:
				keep = true
		if id != 0 and not keep:
			expect += game.refund_cost(id)
	check(game.switch_cost(2) == expect, "coût de bascule = oubli des nœuds qui disparaissent (%d)" % expect)
	game.xp = float(expect)
	check(game.switch_build(2) and game.xp < 1.0, "bascule payée en essence")
	game.at_sanctuary = true
	check(game.switch_build(0), "retour au premier build")

	print("Build plus grand que les points")
	game.points += 3
	var more: Array = _path_to_ring(free_rings + 5, game.allocated)
	_learn(more)
	var big: int = game.allocated.size()
	check(game.copy_build_to(3), "build de %d nœuds copié" % (big - 1))
	game.switch_build(2)
	# Moins de points que le build n'en demande (3 de moins) : on en retire au build neuf.
	game.points = (big - 1 - 3) - (game.allocated.size() - 1)
	check(game.switch_build(3), "charger le grand build")
	check(game.allocated.size() == big - 3 and game.points == 0, "les nœuds en trop ne sont pas appris")
	planner.sync()
	check(planner.plan.size() == 3, "ils attendent dans le plan du build (%d)" % planner.plan.size())
	game.points += 3
	check(planner.plan_commit() and game.allocated.size() == big, "le plan validé complète le build")
	check(not game.flags.has(TreePlanner.FLAG), "plan vidé")
	game.switch_build(0)
	planner.sync()
	check(planner.plan.is_empty(), "le plan suit son build")
	check(game.clear_build(3) and game.build_empty(3) and not game.clear_build(0), "vider un emplacement (pas le build actif)")

	print("Sauvegarde version 8")
	var uids0: Array = game.allocated_uids()
	game.copy_build_to(3)
	game.switch_build(1)
	var data: Dictionary = save.capture(null)
	check(int(data["version"]) == 8 and data["tree"]["builds"].size() == game.build_slots() and int(data["tree"]["active_build"]) == 1, "builds et build actif enregistrés")
	var live: Array = game.allocated_uids()
	var names: Array = []
	for i in game.build_slots():
		names.append(game.build_name(i))
	data = JSON.parse_string(JSON.stringify(data))
	save.apply(save._migrate(data), null)
	check(game.active_build == 1 and game.allocated_uids() == live, "rechargés : build actif et ses nœuds")
	var same := true
	for i in game.build_slots():
		same = same and game.build_name(i) == names[i]
	check(same and game.build_info(0)["nodes"] == uids0.size() and not game.build_empty(2), "rechargés : noms et contenu des emplacements")
	check(game.switch_build(0) and game.allocated_uids() == uids0, "un build rechargé se recharge")

	print("Migration 7 → 8")
	var v7 := {"format": "seve-save", "version": 7, "game": {"level": 5, "points": 0, "flags": {}},
		"tree": {"allocated": first_uids, "choices": {}, "crown": [], "inventory": []}, "world": {}}
	var m: Dictionary = save._migrate(JSON.parse_string(JSON.stringify(v7)))
	check(int(m["version"]) == 8 and m["tree"]["builds"] == [] and int(m["tree"]["active_build"]) == 0, "champs des builds créés")
	save.apply(m, null)
	check(game.active_build == 0 and game.build_info(0)["nodes"] == first_uids.size() and game.build_empty(1), "le build courant devient le premier emplacement")

	print("Panneau de l'arbre")
	var TreeBuilds = load("res://scripts/tree_builds.gd")
	var panel = TreeBuilds.new()
	root.add_child(panel)
	await process_frame
	check(panel._rows.get_child_count() == game.build_slots(), "une ligne par emplacement")
	game.at_sanctuary = true
	check(panel.rule_text().begins_with("Au sanctuaire"), "la règle dit que c'est gratuit au sanctuaire")
	game.at_sanctuary = false
	check(panel.rule_text().contains("essence"), "hors sanctuaire, elle parle d'essence")
	panel.queue_free()

	game.reset()
	print("builds_test : %s" % ("OK" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
