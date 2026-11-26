## Film des Falaises (région d'Aube, refonte du monde vague 2 P5), image par image, pour les GIF de la
## PR : « coeur » (le siège puis la purification du Cœur : la géode s'ouvre et le bord de vie avance sur
## les falaises), « reactions » (coups lourds près des cristaux sur la terre ravivée : éclats qui
## sautent, reflets qui scintillent). N'utilise que des appels qui existent aussi sur la base : le même
## script tourne avant et après.
##   tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 960x540 -s res://tests/paysages/falaises_film.gd -- --scene=coeur --out=/chemin
extends SceneTree

const Regions = preload("res://scripts/regions.gd")

var main
var scene := "coeur"
var out := "/tmp/falaises_film"
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
			await RenderingServer.frame_post_draw
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
	var h = main.hearts["aube"]
	match scene:
		"coeur":
			h.hold_time = 3.0
			h.wave_base = 0
			h.wave_growth = 0
			h.big_from = 999
			h.idle_max = 0
			_put(h.center + Vector2(-260, 120))
			await _steps(60, false)
			await _steps(30)
			_put(h.center + Vector2(-150, 70))
			await _steps(3 * 60 + 260)
		"reactions":
			# La région ravivée autour du Cœur, puis des coups lourds près des cristaux les plus proches.
			main.ground.paint(h.center, 900.0, 1.0)
			for t in main.flora.trees:
				if is_instance_valid(t) and t.position.distance_to(h.center) < 900.0 and t.has_method("revive"):
					t.revive(false)
			var spot: Vector2 = h.center + Vector2(320, 160)
			var near := []
			for t in main.flora.trees:
				if is_instance_valid(t) and t.position.distance_to(spot) < 380.0 and t.get("radius") != null and main.region_at(t.position) == "aube":
					near.append(t)
			_put(spot)
			await _steps(90, false)
			await _steps(60)
			for k in 4:
				var target: Vector2 = near[k % near.size()].position if not near.is_empty() else spot + Vector2(80, 0)
				main.world_fx.react("heavy", target, 1.2)
				await _steps(45)
			await _steps(90)
	print("FALAISES film : %d images dans %s" % [_n, out])
	quit(0)
