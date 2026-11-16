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


func paused_now() -> bool:
	return paused


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

	print("Objectifs et fin de la tranche")
	var obj = root.get_node("Objectives")
	var boss_done: Array = []
	obj.completed.connect(func(id): if id == "boss": boss_done.append(id))
	var q = current_scene.quest_ui
	check(q != null and obj.main == current_scene, "les objectifs sont rattachés à la partie reprise")
	check(obj.is_done("premier_noeud") and not obj.is_done("boss"), "le premier nœud appris est un objectif accompli, pas le boss")
	game.flags["ronce_coeur_purifie"] = true
	obj.check()
	check(obj.is_done("coeur") and obj.current().get("id", "") != "coeur", "le Cœur purifié fait avancer les objectifs")
	game.flags["ronce_boss_vaincu"] = true
	obj.check()
	check(obj.is_done("boss") and boss_done.size() == 1, "le boss vaincu accomplit son objectif")
	q._process(q.ENDING_DELAY + 0.5)
	check(q.ending.active and bool(game.flags.get("fin_ronce_vue", false)), "la fin se déclenche")
	q.ending.set_time(10.0)
	q.ending._on_continue()
	check(not paused_now(), "« Continuer à jouer » reprend la partie")
	q._process(60.0)
	check(not q.ending.active, "la fin ne se déclenche qu'une fois")
	flow.go_title()
	await _frames(5)
	flow.continue_game()
	await _frames(5)
	q = current_scene.quest_ui
	q._process(60.0)
	check(obj.is_done("boss") and not q.ending.active and not obj.ending_due(), "après Continuer, la fin ne revient pas")
	check(boss_done.size() == 1, "l'objectif du boss n'est pas ré-accompli au chargement")

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
