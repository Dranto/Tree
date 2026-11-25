## Enregistre les scènes du jalon Éclat, tâche F (« un monde qui réagit »), image par image, pour en
## faire des GIF avant/après (tools/eclat-f-gif.sh). N'utilise que des appels qui existent aussi
## sur develop (pas de world_fx) : le même script tourne sur la base et sur la branche.
## Lancer : tools/godot.sh --xvfb --fixed-fps 60 --resolution 960x540 -s res://tests/eclat_f_gif.gd -- --scene=herbe --out=/chemin
## Scènes : herbe, combat, repos, niveau, greffe, sanctuaire.
extends SceneTree

var main
var scene := "herbe"
var out := "/tmp/eclat_f"
var every := 3
## Lieu des scènes : loin du sanctuaire de la Graine, sur de l'herbe.
const B := Vector2(260, 180)
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
	var player = main.player
	player.invuln = 1.0e6
	main.ground.paint(Vector2.ZERO, 900.0, 1.0)
	main.flora.finish_pending()
	main.flora.spawn_patch(Vector2.ZERO, 700.0, 260, Color(0, 0, 0, 0))
	main.flora.spawn_patch(B, 300.0, 170, Color(0, 0, 0, 0))
	await _steps(5, false)
	match scene:
		"herbe":
			_put(B + Vector2(-260, 0))
			await _steps(20, false)
			Input.action_press("move_right")
			await _steps(75)
			Input.action_press("dash")
			await _steps(2)
			Input.action_release("dash")
			await _steps(40)
			Input.action_release("move_right")
			await _steps(130)
		"combat":
			_put(B)
			var es := []
			for i in 5:
				var e = main.spawn_enemy_at(B + Vector2.from_angle(TAU * i / 5.0 + 0.4) * 110.0, 0)
				e.hp = 1.0e9
				e.max_hp = 1.0e9
				es.append(e)
			var branches := ["ronce", "ronce", "aube", "spore", "racine", "seve", "ronce"]
			for i in 150:
				if i % 11 == 0:
					var e = es[(i / 11) % es.size()]
					main.player_hit_enemy(e, 1.0, false, branches[(i / 11) % branches.size()])
				await _steps(1)
			await _steps(180)
		"repos":
			every = 6
			_put(B)
			main.flora.add_flower(B + Vector2(52, -8), Color("f2d06b"))
			await _steps(60 * 20)
		"niveau":
			_put(B)
			await _steps(20)
			main._on_level_up(2)
			await _steps(110)
		"greffe":
			_put(B)
			await _steps(20)
			var g = load("res://scripts/graft_pickup.gd").new()
			g.main = main
			g.graft_id = Content_first_graft()
			g.position = B + Vector2(52, 6)
			g.pop = 0.0
			main.add_child(g)
			await _steps(2)
			g.pick_up()
			await _steps(110)
		"sanctuaire":
			var sc = main.sanctuaries[1]
			player.position = sc.position + Vector2(0, 150)
			player.reset_physics_interpolation()
			main.camera.reset_smoothing()
			await _steps(25)
			sc.light()
			await _steps(230)
	print("%d images dans %s" % [_n, out])
	quit(0)


func Content_first_graft() -> String:
	return str(load("res://scripts/content.gd").grafts().keys()[0])
