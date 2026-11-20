## Captures des frontières hybrides de l'Arbre de vie (jalon 9, tâche A), pour les joindre à une PR :
## pour chaque frontière de data/borders/, une vue d'ensemble de la limite entre les deux branches,
## puis chaque grappe de près (quelques nœuds appris, l'infobulle d'un notable).
## Lancer : tools/godot.sh --xvfb -s res://tests/borders_captures.gd
## Les images vont dans godot/tests/visual/out/frontiere_*.png (dossier ignoré par git).
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
	var t = game.tree
	for bd in t.BORDERS:
		var bid: String = bd["id"]
		# Quelques nœuds de chaque grappe appris : le chemin jusqu'à son premier notable.
		var notables: Array = []
		for c in bd["clusters"]:
			var key := "%s:%s" % [bid, c["id"]]
			for id in t.clusters[key]["nodes"]:
				if t.nodes[id]["type"] == "notable":
					notables.append(id)
					break
		for id in notables:
			for step in TreePlanner.shortest_path(t, game.allocated, id):
				game.points += 1
				if game.allocate(step) and not t.nodes[step]["choices"].is_empty():
					game.set_choice(step, 0)
		await _frames(2)
		if ui.choice_open():
			ui.close_choice(false)
		ui._refresh_states()
		ui._redraw_all()
		# Vue d'ensemble : la limite entre les deux branches, de la graine au bord.
		var sector: float = TAU / t.BRANCHES.size()
		var limit := Vector2.from_angle((bd["a"] + 1) * sector - PI / 2.0)
		_hover(-1)
		ui.zoom = 0.62
		ui.cam = limit * 7.0 * t.RING_GAP
		ui._redraw_all()
		await _shot("frontiere_%s_ensemble" % bid)
		for i in bd["clusters"].size():
			var c: Dictionary = bd["clusters"][i]
			var key := "%s:%s" % [bid, c["id"]]
			var center := Vector2.ZERO
			for id in t.clusters[key]["nodes"]:
				center += t.nodes[id]["pos"]
			center /= t.clusters[key]["nodes"].size()
			ui.zoom = 1.5
			ui.cam = center
			_hover(notables[i] if i < notables.size() else -1)
			ui._redraw_all()
			await _shot("frontiere_%s_%s" % [bid, c["id"]])
	quit(0)


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _hover(id: int) -> void:
	ui.hover = id
	if id >= 0:
		ui.mouse = ui.to_screen(game.tree.nodes[id]["pos"])
	ui.queue_redraw()


func _shot(shot_name: String) -> void:
	if ui.choice_open():
		ui.close_choice(false)
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
	print("CAPTURE ", shot_name)
