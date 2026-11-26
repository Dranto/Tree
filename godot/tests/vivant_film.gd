## Film du monde vivant (refonte du monde, vague 1 V) : scènes jouées image par image pour les GIF
## avant/après (tools/vivant-film.sh). N'utilise que des appels qui existent aussi sur develop : le même
## script tourne sur la base et sur la branche.
## Lancer : tools/godot.sh --xvfb --fixed-fps 60 --resolution 960x540 -s res://tests/vivant_film.gd -- --scene=buisson --out=/chemin
## Scènes : buisson (le héros traverse les ronces), charge (un Flétri charge à travers le décor),
## coup (coups lourds près du décor), faune (le héros approche de la faune), marais (mares, champignons,
## grenouilles), vivant (tout à la suite, pour le GIF « monde vivant »).
extends SceneTree

const Regions = preload("res://scripts/regions.gd")

var main
var scene := "buisson"
var out := "/tmp/vivant_film"
var every := 3
var region := "ronce"
var _n := 0
var _f := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene = a.substr(8)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--region="):
			region = a.substr(9)
	if scene == "marais":
		region = "spore"
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


## L'élément du décor le plus proche de « at ».
func _decor(at: Vector2) -> Node2D:
	var best: Node2D = null
	var bd := INF
	for t in main.flora.trees:
		var d: float = t.position.distance_squared_to(at)
		if d < bd:
			bd = d
			best = t
	return best


## Un coin de la région riche en décor, loin des sanctuaires, des autels et des Cœurs (tirages fixes).
func _dense_spot(c: Vector2) -> Vector2:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var best := c
	var bn := -1
	var avoid: Array = []
	for s in main.sanctuaries:
		avoid.append(s.position)
	for a in main.altars:
		avoid.append(a.position)
	for h in main.all_hearts:
		avoid.append(h.center)
	for sp in Regions.heart_spots(region):
		avoid.append(Regions.place(region, sp))
	avoid.append(c)
	var arenas: Array = []
	for a in main.arenas.values():
		arenas.append(a)
	for i in 160:
		var q: Vector2 = c + Vector2.from_angle(r.randf() * TAU) * r.randf_range(300.0, 1700.0)
		if Regions.region_at(q) != region or Regions.weight(q, region) < 0.99:
			continue
		var ok := true
		for v in avoid:
			if v.distance_to(q) < 480.0:
				ok = false
		for a in arenas:
			var ar: float = float(a.get("radius") if a.get("radius") != null else 600.0)
			var ac: Vector2 = a.center if a.get("center") != null else a.position
			if ac.distance_to(q) < ar + 380.0:
				ok = false
		if not ok:
			continue
		var n := 0
		for t in main.flora.trees:
			var d: float = t.position.distance_to(q)
			if d < 260.0 and d > 50.0:
				n += 1
			elif d <= 50.0:
				n -= 3
		if n > bn:
			bn = n
			best = q
	return best


func _walk(dir: String, n: int) -> void:
	Input.action_press(dir)
	await _steps(n)
	Input.action_release(dir)


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.autosave_enabled = false
	main.spawn_paused = true
	root.add_child(main)
	await _steps(5, false)
	var player = main.player
	player.invuln = 1.0e6
	var spot := _dense_spot(Regions.center(region))
	_put(spot)
	await _steps(30, false)
	match scene:
		"buisson":
			main.ground.paint(spot + Vector2(160, 0), 220.0, 1.0)
			main.flora.finish_pending()
			await _steps(60, false)
			_put(spot + Vector2(-220, 0))
			await _steps(20, false)
			await _walk("move_right", 110)
			Input.action_press("move_right")
			Input.action_press("dash")
			await _steps(2)
			Input.action_release("dash")
			await _steps(40)
			Input.action_release("move_right")
			await _steps(60)
		"charge":
			main.ground.paint(spot, 520.0, 1.0)
			main.flora.finish_pending()
			_put(spot + Vector2(0, 90))
			await _steps(90, false)
			var e = main.spawn_enemy_at(spot + Vector2(-380, 30), 0)
			e.hp = 1.0e9
			e.max_hp = 1.0e9
			e.set_physics_process(false)
			await _steps(10)
			for i in 70:
				e.position += Vector2(11.0, 0.4 * sin(i * 0.3))
				await _steps(1)
			await _steps(60)
		"coup":
			_put(spot + Vector2(-80, 60))
			await _steps(30)
			for k in 3:
				var at: Vector2 = spot + Vector2(40 + k * 50, -10 + 30 * (k % 2))
				main.fx.impact(at, 999.0, k == 2, 16.0, "", true)
				await _steps(40)
			await _steps(40)
		"faune":
			main.ground.paint(spot, 600.0, 1.0)
			main.flora.finish_pending()
			_put(spot + Vector2(-200, 0))
			await _steps(240, false)
			await _steps(60)
			await _walk("move_right", 120)
			await _steps(90)
		"marais":
			_put(spot + Vector2(-200, 0))
			await _steps(200, false)
			await _walk("move_right", 120)
			main.fx.impact(main.player.position + Vector2(80, -20), 999.0, false, 16.0, "", true)
			await _steps(80)
		"vivant":
			main.ground.paint(spot + Vector2(120, 0), 520.0, 1.0)
			main.flora.finish_pending()
			_put(spot + Vector2(-240, 0))
			await _steps(240, false)
			await _walk("move_right", 100)
			Input.action_press("move_right")
			Input.action_press("dash")
			await _steps(2)
			Input.action_release("dash")
			await _steps(30)
			Input.action_release("move_right")
			var pp: Vector2 = main.player.position
			var e = main.spawn_enemy_at(pp + Vector2(-420, 90), 0)
			e.hp = 1.0e9
			e.max_hp = 1.0e9
			e.set_physics_process(false)
			for i in 70:
				e.position += Vector2(12.0, -0.3)
				await _steps(1)
			await _steps(20)
			main.fx.impact(pp + Vector2(90, -40), 999.0, true, 16.0, "", true)
			await _steps(90)
	print("%d images dans %s" % [_n, out])
	quit()
