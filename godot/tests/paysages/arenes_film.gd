## Enregistre une arène de boss en action (refonte du monde, vague 3 A), image par image, pour des GIF
## avant/après (tools/arenes-film.sh) : l'arène fermée vue de loin, la brèche qui s'ouvre quand le Cœur
## est purifié, le combat (le mur se referme, phase 2, coups), la mort du boss et l'arène qui refleurit.
## N'utilise que des appels qui existent aussi sur develop : le même script tourne sur la base.
##   tools/godot.sh --xvfb --fixed-fps 60 --resolution 960x540 -s res://tests/paysages/arenes_film.gd -- --scene=ronce --out=/chemin
## Scènes : ronce (Roncier), spore (Marais), vent (Plateaux), aube (Falaises) ; toute région du jeu.
extends SceneTree

var main
var scene := "ronce"
var out := "/tmp/arenes_film"
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
		main.player.hp = main.player.max_hp if main.player.get("max_hp") != null else main.player.hp
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
	main.camera.zoom = Vector2(0.62, 0.62)
	var a = main.arenas[scene]
	var gate: Vector2 = (a.heart.center - a.center).normalized()
	# Fermée, vue depuis le Cœur.
	_put(a.center + gate * (a.max_radius + 260.0))
	await _steps(50, false)
	await _steps(40)
	# Le Cœur est purifié : la brèche s'ouvre.
	root.get_node("Game").flags[a.heart.flag] = true
	root.get_node("Game").flags[load("res://scripts/regions.gd").heart_flag(scene)] = true
	await _steps(110)
	# On entre : le mur se referme, le combat.
	_put(a.center + gate * (a.max_radius - 120.0))
	await _steps(150)
	if is_instance_valid(a.boss):
		a.boss.hp = a.boss.max_hp * 0.6
		a.boss.take_damage(1.0, false)
	await _steps(120)
	if is_instance_valid(a.boss):
		a.boss.take_damage(a.boss.max_hp * 2.0, false)
	await _steps(260)
	print("ARENES film : %d images dans %s" % [_n, out])
	quit(0)
