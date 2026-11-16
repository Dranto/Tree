## Captures des greffes et des autels (jalon 4, tâche B), pour les joindre à une PR : un autel
## aperçu puis ravivé, la greffe tombée au sol, et l'inventaire de l'écran de l'arbre avec l'aperçu
## d'une greffe tenue au-dessus d'un emplacement.
## Lancer : tools/godot.sh --xvfb -s res://tests/grafts_captures.gd
## Les images vont dans godot/tests/visual/out/greffes_*.png (dossier ignoré par git).
extends SceneTree

const OUT := "res://tests/visual/out"

var main
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
	main.autosave_enabled = false
	main.spawn_paused = true
	main.hud.hint_time = 0.0

	# Un autel aperçu, encore couvert de cendre, puis ravivé : sa greffe tombe au sol.
	var altar = main.altars[1]
	_place(altar.position + Vector2(-150, 120))
	await _physics(30)
	await _shot("greffes_autel_cendre")
	_place(altar.position + Vector2(-190, 40))
	altar.activate()
	await _physics(50)
	await _shot("greffes_autel_ravive")

	# Inventaire de l'arbre : quelques greffes trouvées, une posée, une tenue au-dessus d'un emplacement.
	for g in ["greffe_ecorce", "greffe_soeurs", "greffe_tournoyante", "greffe_tracante"]:
		game.give_graft(g)
	var ui = main.tree_ui
	var planner = ui.panels.planner
	var slot: int = game.tree.id_for_uid("c:ronce:fouet:f8")
	game.points = 40
	planner.learn(slot)
	game.place_graft(slot, "greffe_tournoyante")
	ui.toggle()
	await _frames(3)
	var target: int = game.tree.id_for_uid("c:ronce:souche:o5")
	planner.learn(target)
	await _frames(3)
	ui._choice_queue.clear()
	ui.close_choice(false)
	ui.zoom = 1.3
	ui.cam = game.tree.nodes[target]["pos"] + Vector2(160, 40) / ui.zoom
	ui.grafts_panel.held = "greffe_soeurs"
	ui.grafts_panel.refresh()
	ui.hover = target
	ui.mouse = (game.tree.nodes[target]["pos"] - ui.cam) * ui.zoom + ui.size / 2.0
	ui._redraw_all()
	await _shot("greffes_inventaire")
	quit(0)


func _place(pos: Vector2) -> void:
	main.player.position = pos
	main.player.hp = 1.0e6
	main.player.reset_physics_interpolation()


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _physics(k: int) -> void:
	for i in k:
		await physics_frame


func _shot(shot_name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
	print("CAPTURE ", shot_name)
