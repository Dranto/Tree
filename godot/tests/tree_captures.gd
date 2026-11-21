## Captures de l'Arbre de vie entier (jalon 9, tâche F : arbre à 900 nœuds), pour une PR :
## vue d'ensemble (zoom d'ouverture), un secteur au zoom moyen, l'anneau extérieur de près, une
## recherche, et un build avancé (chemins appris jusqu'aux anneaux extérieurs).
## Lancer : tools/godot.sh --xvfb --resolution 1920x1080 -s res://tests/tree_captures.gd
## Les images vont dans godot/tests/visual/out/arbre900_*.png (dossier ignoré par git).
extends SceneTree

const OUT := "res://tests/visual/out"
const TreePlanner = preload("res://scripts/tree_planner.gd")

var main
var game
var ui


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
	main.autosave_enabled = false
	main.spawn_paused = true
	main.hud.hint_time = 0.0
	ui = main.tree_ui
	ui.toggle()
	await _frames(5)
	while ui._intro < ui.TreeArt.INTRO_DUR or ui._open < 1.0:
		await process_frame
	var t = game.tree
	print("CAPTURES %d nœuds" % t.nodes.size())
	ui.zoom = ui.fit_zoom()
	ui.cam = Vector2.ZERO
	ui._redraw_all()
	await _shot("arbre900_ensemble")
	# Un secteur (Ronce) au zoom moyen, de la graine à l'anneau extérieur.
	var sector: float = TAU / t.BRANCHES.size()
	var mid := Vector2.from_angle(0.5 * sector - PI / 2.0)
	ui.zoom = 0.45
	ui.cam = mid * 8.0 * t.RING_GAP
	ui._redraw_all()
	await _shot("arbre900_secteur")
	# L'anneau extérieur de près (zoom proche : noms des notables).
	ui.zoom = 1.0
	ui.cam = mid * 13.5 * t.RING_GAP
	ui._redraw_all()
	await _shot("arbre900_bord")
	# Build avancé : chemin vers un notable de l'anneau 14 dans chaque branche.
	var far: Array = []
	for bi in t.BRANCHES.size():
		for n in t.nodes:
			if n["branch"] == bi and n["ring"] == t.RINGS and n["type"] == "notable":
				far.append(n["id"])
				break
	for id in far:
		for step in TreePlanner.shortest_path(t, game.allocated, id):
			game.points += 1
			if game.allocate(step) and not t.nodes[step]["choices"].is_empty():
				game.set_choice(step, 0)
		await _frames(1)
		if ui.choice_open():
			ui.close_choice(false)
	ui._refresh_states()
	ui.zoom = ui.fit_zoom()
	ui.cam = Vector2.ZERO
	ui._redraw_all()
	await _shot("arbre900_build")
	# Recherche : tous les nœuds qui parlent d'armure.
	ui.panels.set_query("armure")
	ui._redraw_all()
	await _shot("arbre900_recherche")
	quit(0)


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _shot(shot_name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, shot_name]))
	print("CAPTURE ", shot_name)
