## Animation de l'Arbre de vie, image par image (temps fixe : lancer avec --fixed-fps 60) :
## ouverture (onde de sève), nœuds disponibles qui invitent, survol, apprentissage d'un chemin
## (éclosions, sève qui circule), nœuds flétris qui fument, pollen.
## Lancer : tools/arbre-anim.sh (assemble le GIF). Images dans godot/tests/visual/out/arbre_anim/.
extends SceneTree

const OUT := "res://tests/visual/out/arbre_anim"
## Une image enregistrée toutes les STEP images du jeu (60 / 3 = 20 images par seconde).
const STEP := 3

var main
var ui
var game
var _count := 0


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
	game.reset()
	game.points = 0
	# Un début de partie : quelques nœuds appris autour de la graine, des points à placer.
	var planner = ui.panels.planner
	var start: Array = game.tree.nodes[0]["neighbors"].duplicate()
	start.sort()
	var first_notable := _first_of_type("notable")
	var path: Array = planner.path_to(first_notable)
	var pre: Array = path.slice(0, maxi(path.size() - 3, 1))
	game.points = pre.size() + 1
	planner.learn_path(pre)
	game.allocate(start[3])
	game.points = 4
	ui.toggle()
	ui.zoom = 0.95
	ui.cam = game.tree.nodes[path[maxi(path.size() - 4, 0)]]["pos"] * 0.8
	await _record(48)   # onde d'ouverture, pollen, invitations
	# Survol du prochain nœud du chemin, puis apprentissage pas à pas.
	var rest: Array = path.slice(pre.size())
	for id in rest:
		_hover(id)
		await _record(14)
		game.allocate(id)
		await _record(10)
	_hover(-1)
	await _record(40)   # la sève circule dans les branches apprises
	# Une grappe de Ronce avec ses nœuds flétris couverts de cendre.
	var withered := _first_of_type("withered")
	ui.zoom = 1.25
	ui.cam = game.tree.nodes[withered]["pos"]
	await _record(36)
	quit(0)


func _first_of_type(kind: String) -> int:
	for n in game.tree.nodes:
		if n["type"] == kind:
			return n["id"]
	return 0


func _hover(id: int) -> void:
	ui.hover = id
	if id >= 0:
		ui.mouse = (game.tree.nodes[id]["pos"] - ui.cam) * ui.zoom + ui.size / 2.0


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Enregistre n images (une toutes les STEP images du jeu).
func _record(n: int) -> void:
	for i in n:
		await _frames(STEP - 1)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + "/%03d.png" % _count))
		_count += 1
