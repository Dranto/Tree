## Vues du décor composé et cuit (refonte du monde, vague 1 D) : le vrai jeu, sans Flétris, le héros posé
## en quelques points de chaque région, flétri puis ravivé autour de lui. Pour la planche avant/après
## (avec « -- --decor-ancien » : le semis d'avant) et pour régler la composition.
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --resolution 1600x900 -s res://tests/paysages/decor_vues.gd -- --out=DOSSIER [--zones=ronce,spore] [--decor-ancien]
extends SceneTree

const Regions = preload("res://scripts/regions.gd")

var main
var out := "user://decor_vues"
var regions: Array = []
var spots := [[1500.0, -0.45], [1150.0, 0.55], [2250.0, 0.1]]


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--zones="):
			regions = Array(a.substr(8).split(","))
		elif a.begins_with("--spots="):
			spots = JSON.parse_string(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(3)
	var C = load("res://scripts/world_bake/decor_compose.gd")
	for k in C.report:
		print("COMPO ", k, " ", C.report[k])
	if "--compo" in OS.get_cmdline_user_args():
		quit(0)
		return
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies = []
	if main.hud != null:
		main.hud.visible = false
	if regions.is_empty():
		regions = Regions.ids()
	for reg in regions:
		for i in spots.size():
			var p: Vector2 = Regions.place(reg, {"dist": spots[i][0], "side": spots[i][1]})
			main.player.position = p
			main.player.reset_physics_interpolation()
			await physics_frame
			main.camera.reset_smoothing()
			await _frames(25)
			_save("%s/%s_%d_fletri.png" % [out, reg, i])
			main.ground.paint(p, 700.0, 1.0)
			await _frames(25)
			_save("%s/%s_%d_ravive.png" % [out, reg, i])
	quit(0)


func _save(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("VUE ", path)
