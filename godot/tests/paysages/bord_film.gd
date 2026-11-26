## Enregistre le bord du monde en action (refonte du monde, vague 3 K), image par image, pour des GIF
## avant/après (tools/bord-film.sh) : le bord d'une région qui reverdit quand son Cœur est purifié, ou
## une marche le long du bord à travers une frontière. N'utilise que des appels qui existent aussi sur
## develop : le même script tourne sur la base et sur la branche.
##   tools/godot.sh --xvfb --fixed-fps 60 --resolution 960x540 -s res://tests/paysages/bord_film.gd -- --scene=ronce --out=/chemin
## Scènes : <région> (reverdit), longe (marche le long du bord nord, du Roncier à la Forêt).
extends SceneTree

const Regions = preload("res://scripts/regions.gd")

var main
var scene := "ronce"
var out := "/tmp/bord_film"
var every := 3
var _n := 0
var _f := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene = a.substr(8)
		elif a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _put(pos: Vector2) -> void:
	main.player.position = pos
	main.player.reset_physics_interpolation()
	main.camera.reset_smoothing()


func _edge_point(angle: float, inset := 160.0) -> Vector2:
	var d := Vector2.from_angle(angle)
	return d * ((Regions.WORLD_HALF - inset) / maxf(absf(d.x), absf(d.y)))


func _steps(n: int, shoot := true) -> void:
	for i in n:
		await physics_frame
		_f += 1
		if shoot and _f % every == 0:
			var img: Image = main.get_viewport().get_texture().get_image()
			img.save_png("%s/%03d.png" % [out, _n])
			_n += 1


func _prepare(pos: Vector2) -> void:
	main.world_edge.ensure(Rect2(pos - Vector2(1500, 1000), Vector2(3000, 2000)))
	if main.world_edge.has_method("settle"):
		await main.world_edge.settle()
	await _steps(4, false)


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.autosave_enabled = false
	main.spawn_paused = true
	root.add_child(main)
	await _steps(5, false)
	main.player.invuln = 1.0e6
	main.player.set_physics_process(false)
	main.hud.glyphs.hide()
	if scene == "longe":
		var y := -Regions.WORLD_HALF + 140.0
		var x0 := 900.0
		_put(Vector2(x0, y))
		await _prepare(Vector2(x0, y))
		for i in 240:
			_put(Vector2(x0 - i * 8.0, y))
			if i % 20 == 0:
				main.world_edge.ensure(Rect2(main.player.position - Vector2(1500, 1000), Vector2(3000, 2000)))
			await _steps(1)
	else:
		var pos := _edge_point(Regions.angle_of(scene))
		_put(pos)
		await _prepare(pos)
		await _steps(45)
		root.get_node("Game").flags[Regions.heart_flag(scene)] = true
		await _steps(260)
	print("images dans ", out, " : ", _n)
	quit()
