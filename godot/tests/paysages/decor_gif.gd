## GIF du décor composé (refonte du monde, vague 1 D) : le héros passe derrière un grand élément de la
## lisière (il s'efface puis revient), puis une vague de vie fait reverdir la lisière (fondu cuit).
## Images dans DOSSIER/gif_NNN.png (assemblées en GIF à part).
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --resolution 1600x900 --fixed-fps 30 -s res://tests/paysages/decor_gif.gd -- --out=DOSSIER [--zone=ronce]
extends SceneTree

const Regions = preload("res://scripts/regions.gd")

var main
var out := "user://decor_gif"
var zone := "ronce"
var n := 0


func _initialize() -> void:
	_run.call_deferred()


func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--zone="):
			zone = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	for i in 3:
		await _frame()
	main.autotest = false
	main.spawn_timer = 1.0e9
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies = []
	main.hud.visible = false
	main.player.set_physics_process(false)
	# Un grand élément de la lisière, assez loin des lieux.
	var best = null
	var center := Regions.place(zone, {"dist": 1700.0, "side": 0.1})
	var bd := INF
	for t in main.flora.trees:
		if is_instance_valid(t) and t.tall > 140.0 and t.bake_region == zone and not t in main.flora.landmarks:
			var d: float = t.position.distance_to(center)
			if d < bd:
				bd = d
				best = t
	var foot: Vector2 = best.position
	var a := foot + Vector2(-60, 70)
	var b := foot + Vector2(10, -best.tall * 0.5)
	main.player.position = a
	main.player.reset_physics_interpolation()
	main.camera.reset_smoothing()
	for i in 20:
		await _frame()
	# Le héros passe derrière, s'y arrête, ressort.
	for i in 40:
		main.player.position = a.lerp(b, i / 39.0)
		await _shot()
	for i in 20:
		await _shot()
	for i in 40:
		main.player.position = b.lerp(a, i / 39.0)
		await _shot()
	# Vague de vie : la lisière reverdit (fondu de l'image morte à la vivante).
	main.ground.paint_wave(a, 650.0, 1.0)
	for i in 70:
		await _shot()
	quit(0)


func _shot() -> void:
	await _frame()
	await _frame()
	var img := root.get_texture().get_image()
	img.resize(800, 450, Image.INTERPOLATE_BILINEAR)
	img.save_png("%s/gif_%03d.png" % [out, n])
	n += 1
