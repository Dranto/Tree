## Film de la Forêt pétrifiée (refonte du monde, vague 2 P6), image par image, pour les GIF avant/après :
## le siège puis la purification du Cœur des cernes et le bord de vie qui avance (coeur), un sanctuaire
## qu'on ravive (sanctuaire). Copie de lieux_film.gd réglée sur la région racine (ce fichier est propre à
## la forêt, pour ne pas toucher à l'outil commun) ; le même script tourne sur la base et sur la branche.
##   tools/godot.sh --xvfb --fixed-fps 60 --resolution 960x540 -s res://tests/paysages/foret_film.gd -- --scene=coeur --out=/chemin
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
		"coeur":
			var h = main.hearts["racine"]
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
			var s = main.sanctuary("racine_souche")
			s.frozen = false
			_put(s.position + Vector2(-190, 40))
			await _steps(40, false)
			await _steps(30)
			_put(s.position + Vector2(0, 6))
			await _steps(3 * 60 + 120)
	print("FORET film : %d images dans %s" % [_n, out])
	quit(0)
