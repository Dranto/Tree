## Sonde : compare l'arbre pendant un déplacement / zoom (image en cache déplacée) à l'arbre au repos.
## Lancer : tools/godot.sh --xvfb --resolution 1280x720 -s res://tests/tree_pan_probe.gd -- --out=DOSSIER
extends SceneTree

var main
var ui
var out := "/tmp/pan"


func _initialize() -> void:
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _img() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _diff(a0: Image, b0: Image) -> float:
	# Image réduite : on ne compare que les grandes masses (fond, troncs), pas les contours des nœuds.
	var a := a0.duplicate() as Image
	var b := b0.duplicate() as Image
	a.resize(a.get_width() / 8, a.get_height() / 8, Image.INTERPOLATE_BILINEAR)
	b.resize(b.get_width() / 8, b.get_height() / 8, Image.INTERPOLATE_BILINEAR)
	var n := 0
	var tot := 0
	var area: Rect2i = Rect2i(0, 140, a.get_width(), a.get_height() - 140)
	for y in range(area.position.y / 8, a.get_height()):
		for x in range(0, a.get_width()):
			tot += 1
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.12:
				n += 1
	return 100.0 * n / tot


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
	var game = root.get_node("Game")
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(5)
	main.autotest = false
	main.autosave_enabled = false
	main.spawn_paused = true
	ui = main.tree_ui
	ui.toggle()
	await _frames(5)
	while ui._intro < ui.TreeArt.INTRO_DUR or ui._open < 1.0:
		await process_frame
	ui.zoom = 0.6
	ui.cam = Vector2(300, -200)
	await _frames(40)
	DirAccess.make_dir_recursive_absolute(out)
	var worst := 0.0
	# Glisser : 12 images, 18 px à chaque image ; on compare chaque image à la vue au repos.
	for step in 12:
		ui._interactive = true
		ui.cam -= Vector2(60, 25) / ui.zoom
		ui._fitted = false
		await _frames(1)
		var moving := await _img()
		var saved_cam: Vector2 = ui.cam
		# Repos : on force une image refaite.
		ui._render_cache()
		await _frames(4)
		var rest := await _img()
		var d := _diff(moving, rest)
		worst = maxf(worst, d)
		print("PAN pas %d : %.2f %% de pixels différents" % [step, d])
		if d > 3.0:
			moving.save_png("%s/pan_%02d_mouvement.png" % [out, step])
			rest.save_png("%s/pan_%02d_repos.png" % [out, step])
	# Longue traîne : 150 images de suite, avec les rafraîchissements du cache en cours de route.
	var bad := 0
	for step in 150:
		ui._interactive = true
		var dir := Vector2(40, 17) if (step / 50) % 2 == 0 else Vector2(-40, -17)
		ui.cam -= dir / ui.zoom
		ui.cam = ui.cam.limit_length(ui._extent())
		ui._fitted = false
		await _frames(1)
		var moving := await _img()
		if step % 3 == 0:
			ui._render_cache()
			await _frames(4)
			var rest := await _img()
			var d := _diff(moving, rest)
			if d > 0.5:
				bad += 1
				moving.save_png("%s/long_%03d_mouvement.png" % [out, step])
				rest.save_png("%s/long_%03d_repos.png" % [out, step])
				print("LONG pas %d : %.2f %%" % [step, d])
	print("LONG mauvais : ", bad)
	# Zoom à la molette.
	for step in 8:
		ui.zoom_at(Vector2(700, 400), 1.15 if step < 4 else 1.0 / 1.15)
		await _frames(1)
		var moving := await _img()
		ui._render_cache()
		await _frames(4)
		var rest := await _img()
		var d := _diff(moving, rest)
		worst = maxf(worst, d)
		print("ZOOM pas %d : %.2f %%" % [step, d])
		if d > 3.0:
			moving.save_png("%s/zoom_%02d_mouvement.png" % [out, step])
			rest.save_png("%s/zoom_%02d_repos.png" % [out, step])
	print("PIRE ", worst)
	quit(0)
