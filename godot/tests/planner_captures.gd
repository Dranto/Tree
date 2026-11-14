## Captures des outils de planification de l'arbre, pour les joindre à une PR ou vérifier à l'œil.
## Lancer : tools/godot.sh --xvfb -s res://tests/planner_captures.gd
## Les images vont dans godot/tests/visual/out/outils_*.png (dossier ignoré par git).
## La partie est en mode robot : aucune sauvegarde n'est lue ni écrite.
extends SceneTree

const OUT := "res://tests/visual/out"

var main
var ui
var panels
var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(5)
	main.autotest = false
	ui = main.tree_ui
	panels = ui.panels
	ui.toggle()
	game.reset()

	# Un début de build dans la Ronce.
	game.points = 40
	panels.planner.learn(_find("key:nova"))
	game.points = 6

	# 1. Recherche : « poison », troisième résultat centré.
	panels.set_query("poison")
	ui.zoom = 0.3
	await _shot("outils_recherche_ensemble")
	panels.next_match()
	panels.next_match()
	panels.next_match()
	await _shot("outils_recherche_suivant")
	panels.set_query("")

	# 2. Chemin vers un nœud éloigné, avec assez de points : coût et aperçu des statistiques.
	ui.zoom = 0.8
	var target := _at(7, 0, 3)
	ui.cam = (game.tree.nodes[target]["pos"] + game.tree.nodes[_find("key:nova")]["pos"]) / 2.0
	_hover(target)
	await _shot("outils_chemin")
	# 3. Le même survol sans assez de points.
	game.points = 1
	game.tree_changed.emit()
	_hover(target)
	await _shot("outils_chemin_trop_cher")

	# 4. Apprendre le chemin d'un clic, puis annuler.
	game.points = 6
	panels.click(target)
	_hover(-1)
	await _shot("outils_chemin_appris")
	panels.undo()
	await _shot("outils_annulation")

	# 5. Mode plan : deux objectifs tracés sans point, survol d'un troisième.
	game.points = 2
	game.tree_changed.emit()
	panels.set_plan_mode(true)
	panels.click(target)
	panels.click(_find("key:ecorce_vive"))
	ui.zoom = 0.62
	ui.cam = game.tree.nodes[_find("key:ecorce_vive")]["pos"] * 0.75
	_hover(_at(9, 0, 2))
	await _shot("outils_plan")

	# 6. Résumé du build, plan compris.
	_hover(-1)
	panels.set_summary_visible(true)
	await _shot("outils_resume")

	# 7. Plan validé une fois les points gagnés.
	game.points = panels.planner.plan_cost() + 1
	game.tree_changed.emit()
	await _shot("outils_plan_pret")
	panels.commit_plan()
	await _shot("outils_plan_valide")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _find(uid: String) -> int:
	return game.tree.id_for_uid(uid)


func _at(ring: int, branch: int, index: int) -> int:
	return _find("%s:%d:%d" % [game.tree.BRANCHES[branch]["id"], ring, index])


func _hover(id: int) -> void:
	ui.hover = id
	if id >= 0:
		ui.mouse = (game.tree.nodes[id]["pos"] - ui.cam) * ui.zoom + ui.size / 2.0
	ui.queue_redraw()


func _shot(shot_name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
	print("CAPTURE ", shot_name)
