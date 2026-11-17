## Rendu direct à l'écran (main.gd, docs/performances.md) : l'image affichée doit être la même,
## pixel pour pixel, que celle rendue dans la texture du viewport (chemin habituel, et celui des
## captures). Le jeu est mis en pause sur une image de combat, capturé par la texture du viewport,
## puis affiché en direct et relu sur l'écran (DisplayServer.screen_get_image).
## Lancer : tools/godot.sh --xvfb --fixed-fps 60 --resolution 1600x900 --position 0,0 -s res://tests/direct_screen_test.gd
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_render_direct_to_screen(vp, false)
	await _frames(150)
	paused = true
	await _frames(3)
	var a := root.get_texture().get_image()
	a.convert(Image.FORMAT_RGB8)
	RenderingServer.viewport_set_render_direct_to_screen(vp, true)
	await _frames(3)
	var screen := DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
	if screen == null:
		print("DIRECT ÉCHEC : écran illisible")
		quit(1)
		return
	var pos := DisplayServer.window_get_position()
	var b := screen.get_region(Rect2i(pos, a.get_size()))
	b.convert(Image.FORMAT_RGB8)
	var diff := 0
	var worst := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := roundi(maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b)) * 255.0)
			if d > 0:
				diff += 1
				worst = maxi(worst, d)
	if diff > 0:
		a.save_png("/tmp/direct_texture.png")
		b.save_png("/tmp/direct_ecran.png")
	print("DIRECT %s : %d pixels différents sur %d (écart max %d)" % ["OK" if diff == 0 else "ÉCHEC", diff, a.get_width() * a.get_height(), worst])
	quit(0 if diff == 0 else 1)
