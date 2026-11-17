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

	print("Aide des commandes")
	var hud = current_scene.hud
	var settings = root.get_node("Settings")
	settings.set_move_mode("clavier")
	check(hud.move_hint_line().contains("l'attaque part toute seule") and hud.move_hint_line().contains("se déplacer"), "aide : le clavier se déplace, l'attaque part seule")
	check(hud.skills_hint_line().contains("Clic gauche") and hud.skills_hint_line().contains("Clic droit"), "aide : clic gauche et clic droit pour les compétences")
	settings.set_move_mode("moba")
	check(hud.move_hint_line().contains("Clic droit") and not hud.skills_hint_line().contains("Clic droit"), "mode MOBA : le clic droit marche, la compétence 2 passe sur une touche")
	settings.set_move_mode("clavier")
	check(hud.slot_keys_text(0) == "" and hud.slot_is_key(0) == false, "la barre : le clic gauche est dessiné, sans texte")
	check(hud.slot_keys_text(2).contains(" · 1"), "la barre : une secondaire donne sa touche et son chiffre")
	var pl = current_scene.player
	var before: Array = pl.bar.duplicate()
	pl.swap_slots(0, 1)
	check(pl.bar[0] == before[1] and pl.bar[1] == before[0], "glisser-déposer : deux emplacements échangent leur compétence")
	pl.swap_slots(0, 1)
	check(pl.bar == before, "l'échange est réversible")
	game.flags.erase("tuto_attaque")
	hud.banner_queue.clear()
	hud.banner_time = 0.0
	hud._on_attack_node({"type": "attack", "name": "Échardes", "effects": [{"attack_form": "echarde"}]})
	check(hud.banner_text.contains("Échardes") and game.flags.get("tuto_attaque", false), "tutoriel : la première transformation de l'attaque est annoncée")
	hud.banner_time = 0.0
	hud.banner_queue.clear()
	hud._on_attack_node({"type": "attack", "name": "Autre", "effects": [{"attack_form": "fouet"}]})
	check(hud.banner_queue.is_empty() and not hud.banner_text.contains("Autre"), "tutoriel : annoncée une seule fois")
	game.flags.erase("tuto_attaque")

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
