## Captures de la branche Ronce zoomée (grappes écrites à la main), pour les joindre à une PR.
## Lancer : tools/godot.sh --xvfb -s res://tests/ronce_captures.gd
## Les images vont dans godot/tests/visual/out/ronce_*.png (dossier ignoré par git).
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

	# Vue de toute la branche, sans rien d'appris.
	var center := _cluster_center("")
	ui.zoom = 0.42
	ui.cam = center
	await _shot("ronce_branche")

	# Une grappe par capture, zoomée.
	for c in ["fouet", "epines", "sang", "racines", "vorace", "coeur", "venin", "souche"]:
		ui.zoom = 1.25
		ui.cam = _cluster_center(c)
		_hover(-1)
		await _shot("ronce_grappe_" + c)

	# Le build « fouet » joué par le robot d'équilibrage, puis survol de la mutation du fouet.
	var bot = BuildBot.new()
	bot.targets = BuildBot.load_all()["fouet"]["targets"]
	bot.choices = BuildBot.load_all()["fouet"]["choices"]
	game.points = 30
	bot.spend(game)
	game.tree_changed.emit()
	ui.zoom = 0.7
	ui.cam = _cluster_center("racines") * 0.6
	_hover(game.tree.id_for_uid("c:ronce:fouet:f5"))
	await _shot("ronce_build_fouet")
	quit(0)


## Centre des nœuds d'une grappe (« » : toute la branche Ronce).
func _cluster_center(cluster: String) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	var prefix := "c:ronce:%s:" % cluster
	for node in game.tree.nodes:
		var hit: bool = node["branch"] == 0 if cluster == "" else str(node["uid"]).begins_with(prefix)
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
		ui.mouse = (game.tree.nodes[id]["pos"] - ui.cam) * ui.zoom + ui.size / 2.0
	ui.queue_redraw()


func _shot(shot_name: String) -> void:
	if ui.choice_open():
		ui.close_choice(false)
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
	print("CAPTURE ", shot_name)
