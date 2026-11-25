## GIF du jalon Éclat G : apprendre un petit nœud, un nœud clé, oublier, poser une greffe, basculer de
## build. Ne dépend d'aucune API nouvelle (le même script tourne sur develop pour l'« avant »).
## Lancer : tools/eclat-arbre.sh DOSSIER_SORTIE [DOSSIER_GODOT]
extends SceneTree

const TreePlanner = preload("res://scripts/tree_planner.gd")
const STEP := 3

var out := "res://tests/visual/out/eclat_arbre"
var scene := ""
var main
var ui
var game
var _count := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _record(n: int) -> void:
	for i in n:
		await _frames(STEP - 1)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(out) + "/%s_%03d.png" % [scene, _count])
		_count += 1


func _path_to(kind: String) -> Array:
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


func _look(id: int, z: float) -> void:
	ui.zoom = z
	ui.cam = game.tree.nodes[id]["pos"]


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		if arg.begins_with("--scene="):
			scene = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	game = root.get_node("Game")
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(5)
	main.autotest = false
	ui = main.tree_ui
	game.reset()
	game.points = 90
	ui.play_intro = false
	var gid: String = str(preload("res://scripts/content.gd").grafts().keys()[1])
	var start: Array = game.tree.nodes[0]["neighbors"].duplicate()
	start.sort()
	# Un début d'arbre : un chemin vers un nœud clé, appris jusqu'à l'avant-dernier nœud.
	var path := _path_to("keystone")
	for id in path.slice(0, path.size() - 1):
		game.allocate(id)
	ui.toggle()
	await _frames(4)
	var key: int = path[path.size() - 1]
	var before_key: int = path[maxi(path.size() - 2, 0)]
	match scene:
		"petit":
			var nxt := -1
			for n in game.tree.nodes:
				if game.can_allocate(n["id"]) and n["type"] == "small":
					nxt = n["id"]
					break
			_look(nxt, 1.1)
			await _record(8)
			game.allocate(nxt)
			await _record(40)
		"cle":
			_look(key, 0.8)
			await _record(8)
			game.allocate(key)
			await _record(56)
		"oubli":
			var leaf := -1
			for id in game.allocated:
				if id != 0 and game.can_refund(id):
					leaf = id
			_look(leaf, 1.1)
			await _record(8)
			game.refund(leaf, true)
			await _record(36)
		"greffe":
			game.graft_inventory.append(gid)
			game.tree_changed.emit()
			ui.toggle()
			ui.toggle()
			await _frames(4)
			ui.zoom = 0.5
			await _record(6)
			game.place_graft(0, gid)
			await _record(40)
		"build":
			game.at_sanctuary = true
			ui.fit_view()
			await _record(8)
			game.switch_build(2)
			await _record(36)
			game.switch_build(0)
			await _record(36)
	quit(0)
