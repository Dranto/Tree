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

	print("Tutoriel discret")
	var hud = current_scene.hud
	var settings = root.get_node("Settings")
	var glyphs = hud.glyphs
	settings.set_move_mode("clavier")
	var g: Array = glyphs.glyph_for("bouger")
	check(g[0] == "cross" and g[1].size() == 4, "tutoriel : se déplacer au clavier montre les quatre touches")
	check(glyphs.glyph_for("competence") == ["mouse", "left"], "tutoriel : la compétence se montre sur le clic gauche")
	settings.set_move_mode("moba")
	check(glyphs.glyph_for("bouger") == ["mouse", "right"] and glyphs.glyph_for("competence") == ["mouse", "left"], "mode MOBA : le clic droit marche")
	settings.set_move_mode("clavier")
	game.flags.erase("tuto_esquive")
	glyphs.step = "esquive"
	glyphs.finish("esquive")
	check(glyphs.step == "" and glyphs.done("esquive"), "tutoriel : un geste réussi efface son glyphe pour de bon")
	check(hud.slot_keys_text(0) == "" and hud.slot_is_key(0) == false, "la barre : le clic gauche est dessiné, sans texte")
	check(hud.slot_keys_text(2).contains(" · 1"), "la barre : une secondaire donne sa touche et son chiffre")
	var pl = current_scene.player
	var before: Array = pl.bar.duplicate()
	pl.swap_slots(0, 1)
	check(pl.bar[0] == before[1] and pl.bar[1] == before[0], "glisser-déposer : deux emplacements échangent leur compétence")
	pl.swap_slots(0, 1)
	check(pl.bar == before, "l'échange est réversible")
	hud._process(0.1)
	check(hud.banners_idle(), "aucune annonce écrite pendant la partie")

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

	print("Objectifs et reverdie de la région")
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
	check(q.fanfare.active and bool(game.flags.get("ronce_fin_vue", false)), "la reverdie de la région se déclenche")
	check(not paused_now(), "sans pause ni écran plein : on continue à jouer")
	q.fanfare.set_time(30.0)
	q._process(60.0)
	check(not q.fanfare.active, "la reverdie ne se déclenche qu'une fois")
	flow.go_title()
	await _frames(5)
	flow.continue_game()
	await _frames(5)
	q = current_scene.quest_ui
	q._process(60.0)
	check(obj.is_done("boss") and not q.fanfare.active and not obj.ending_due(), "après Continuer, la reverdie ne revient pas")
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
