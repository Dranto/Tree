## Captures de la branche Spore (grappes écrites à la main) à trois zooms, et des builds de Spore,
## pour les joindre à une PR.
## Lancer : tools/godot.sh --xvfb -s res://tests/spore_captures.gd
## Les images vont dans godot/tests/visual/out/spore_*.png (dossier ignoré par git).
extends SceneTree

const OUT := "res://tests/visual/out"
const BuildBot = preload("res://scripts/build_bot.gd")

var main
var ui
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
	ui.toggle()
	game.reset()

	# Trois zooms : la branche entière, mi-distance, puis une grappe par capture.
	var center := _cluster_center("")
	ui.zoom = 0.3
	ui.cam = center
	await _shot("spore_branche_loin")
	ui.zoom = 0.6
	ui.cam = center
	await _shot("spore_branche")
	for c in ["graines", "nuee", "brume", "toxines", "propagation", "pourriture", "coeur", "terreau"]:
		ui.zoom = 1.25
		ui.cam = _cluster_center(c)
		_hover(-1)
		await _shot("spore_grappe_" + c)

	# Chaque build de Spore joué par le robot d'équilibrage, survol de sa mutation.
	for b in ["nuages", "contagion", "toxines"]:
		var all: Dictionary = BuildBot.load_all()
		if not all.has(b):
			continue
		game.reset()
		var bot = BuildBot.new()
		bot.targets = all[b]["targets"]
		bot.choices = all[b]["choices"]
		game.points = 21
		bot.spend(game)
		game.tree_changed.emit()
		ui.zoom = 0.6
		ui.cam = center
		_hover(-1)
		await _shot("spore_build_" + b)
	quit(0)


## Centre des nœuds d'une grappe (« » : toute la branche Spore).
func _cluster_center(cluster: String) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	var prefix := "c:spore:%s:" % cluster
	for node in game.tree.nodes:
		var hit: bool = node["branch"] == 1 if cluster == "" else str(node["uid"]).begins_with(prefix)
		if hit:
			sum += node["pos"]
			n += 1
	return sum / maxf(1, n)


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
