## Film de traversée du monde (refonte du monde, vague 3 I) : un tour complet autour de la graine qui
## passe par les six régions et leurs six frontières, image par image, pour un GIF avant/après
## (tools/tour-film.sh). N'utilise que des appels qui existent aussi avant la refonte : le même script
## tourne sur la base et sur la branche.
##   tools/godot.sh --xvfb --fixed-fps 60 --resolution 960x540 -s res://tests/paysages/tour_film.gd -- --scene=fletri --out=/chemin
## Scènes : fletri (tous les Cœurs vivent), ravive (Cœurs purifiés, boss vaincus, terre ravivée le long du tour).
extends SceneTree

const Regions = preload("res://scripts/regions.gd")

## Rayon du tour (px du monde) et pas par image.
const RADIUS := 1700.0
const STEP := 11.0

var main
var scene := "fletri"
var out := "/tmp/tour_film"
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


func _steps(n: int, shoot := true) -> void:
	for i in n:
		await physics_frame
		_f += 1
		if shoot and _f % every == 0:
			var img: Image = main.get_viewport().get_texture().get_image()
			img.save_png("%s/%03d.png" % [out, _n])
			_n += 1


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.autosave_enabled = false
	main.spawn_paused = true
	root.add_child(main)
	await _steps(5, false)
	main.player.invuln = 1.0e6
	main.player.set_physics_process(false)
	main.hud.glyphs.hide()
	# Départ au milieu du Roncier, puis le tour dans le sens des angles croissants.
	var a0 := Regions.angle_of("ronce")
	_put(Vector2.from_angle(a0) * RADIUS)
	if scene == "ravive":
		var game = root.get_node("Game")
		for id in Regions.ids():
			game.flags[Regions.heart_flag(id)] = true
			game.flags[Regions.boss_flag(id)] = true
		# La terre ravivée tout le long du tour (comme après les vagues de vie des Cœurs et des boss).
		for i in 36:
			main.ground.paint(Vector2.from_angle(TAU * i / 36.0) * RADIUS, 650.0, 1.0)
	await _steps(240 if scene == "ravive" else 30, false)
	var n := int(TAU * RADIUS / STEP)
	for i in n + 1:
		_put(Vector2.from_angle(a0 + TAU * i / n) * RADIUS)
		await _steps(1)
	print("images dans ", out, " : ", _n)
	quit()
