## Enregistre les lieux du jeu en action (refonte du monde, vague 1 C), image par image, pour des GIF
## avant/après (tools/lieux-film.sh) : le siège puis la purification d'un Cœur, un sanctuaire qu'on
## ravive, un autel qu'on réveille. N'utilise que des appels qui existent aussi sur develop : le même
## script tourne sur la base et sur la branche.
##   tools/godot.sh --xvfb --fixed-fps 60 --resolution 960x540 -s res://tests/paysages/lieux_film.gd -- --scene=coeur --out=/chemin
## Scènes : coeur (Roncier), coeur_spore (Marais), coeur_vent (Cœur commun), sanctuaire, autel.
extends SceneTree

const Regions = preload("res://scripts/regions.gd")

var main
var scene := "coeur"
var out := "/tmp/lieux_film"
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
	match scene:
		"coeur", "coeur_spore", "coeur_vent":
			var reg := "ronce" if scene == "coeur" else scene.substr(6)
			var h = main.hearts[reg]
			# Siège court, sans vagues : on ne regarde que le Cœur.
			h.hold_time = 3.0
			h.wave_base = 0
			h.wave_growth = 0
			h.big_from = 999
			h.idle_max = 0
			_put(h.center + Vector2(-260, 120))
			await _steps(40, false)
			await _steps(30)
			_put(h.center + Vector2(-150, 70))
			await _steps(3 * 60 + 150)
		"sanctuaire":
			var s = main.sanctuary("lisiere")
			s.frozen = false
			_put(s.position + Vector2(-190, 40))
			await _steps(40, false)
			await _steps(30)
			_put(s.position + Vector2(0, 6))
			await _steps(3 * 60 + 120)
		"autel":
			var a = main.altars[0]
			_put(a.position + Vector2(-200, 60))
			await _steps(60, false)
			await _steps(30)
			_put(a.position + Vector2(-20, 50))
			await _steps(150 + 90)
	print("LIEUX film : %d images dans %s" % [_n, out])
	quit(0)
