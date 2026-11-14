## Test du parcours des menus branché sur la sauvegarde :
## Nouvelle partie -> progression -> Retour au titre (sauvegarde) -> Continuer (reprise).
## Lancer : tools/godot.sh --headless -s res://tests/flow_test.gd
## Attention : utilise et remplace la sauvegarde par défaut (user://saves/partie.json).
extends SceneTree

var failures := 0


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


func _run() -> void:
	var game = root.get_node("Game")
	var save = root.get_node("SaveGame")
	var flow = root.get_node("Flow")
	save.delete_save()

	print("Nouvelle partie")
	flow.new_game()
	await _frames(5)
	check(current_scene != null and current_scene.has_method("save_game"), "la scène de jeu est ouverte")
	check(game.level == 1 and game.allocated.size() == 1, "progression remise à zéro")
	game.add_xp(500.0)
	var lvl: int = game.level
	var nid: int = game.tree.nodes[0]["neighbors"][0]
	game.allocate(nid)
	check(lvl > 1 and game.allocated.has(nid), "progression simulée (niveau %d)" % lvl)

	print("Retour au titre")
	flow.go_title()
	await _frames(5)
	check(save.has_save(), "la partie est sauvegardée en quittant la scène")
	check(int(save.peek().get("level", 0)) == lvl, "le résumé de la sauvegarde donne le bon niveau")

	print("Continuer")
	flow.continue_game()
	await _frames(5)
	check(game.level == lvl, "niveau repris")
	check(game.allocated.has(nid), "nœud appris repris")
	check(flow.continue_requested == false, "la demande de reprise est consommée")

	print("Nouvelle partie par-dessus une sauvegarde")
	flow.go_title()
	await _frames(5)
	flow.new_game()
	await _frames(5)
	check(game.level == 1 and game.allocated.size() == 1, "nouvelle partie sans reprendre l'ancienne")

	current_scene.autosave_enabled = false
	save.delete_save()
	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
