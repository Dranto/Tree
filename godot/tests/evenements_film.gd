## Film des événements du monde (refonte du monde, vague 2 E) : scènes jouées image par image pour les GIF
## avant/après (tools/evenements-film.sh). N'utilise que des appels qui existent aussi sur develop : le même
## script tourne sur la base et sur la branche.
## Lancer : tools/godot.sh --xvfb --fixed-fps 60 --resolution 1600x900 -s res://tests/evenements_film.gd -- --scene=coeur --out=/chemin
## Scènes : coeur (siège tenu puis purification et vague de vie), sanctuaire (allumé), autel (ravivé),
## niveau (montée de niveau et greffe ramassée), elite (mort d'un élite dans le décor vivant).
extends SceneTree

const Regions = preload("res://scripts/regions.gd")

var main
var scene := "coeur"
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
	match scene:
		"coeur":
			var h = main.hearts[region]
			_put(h.center + Vector2(-h.zone * 0.55, h.zone * 0.25))
			await _steps(120, false)
			h.wave_every = 1.0e9
			await _steps(2, false)
			h.wave_timer = 1.0e9
			await _steps(60 * 5)
			h.progress = h.hold_time
			await _steps(60 * 3)
			await _steps(30)
		"sanctuaire":
			var sc = main.sanctuaries[0]
			for s2 in main.sanctuaries:
				if Regions.region_at(s2.position) == region:
					sc = s2
					break
			_put(sc.position + Vector2(-60, 40))
			await _steps(120, false)
			await _steps(15)
			sc.light()
			await _steps(60 * 3)
		"autel":
			var al = null
			for a in main.altars:
				if Regions.region_at(a.position) == region:
					al = a
					break
			if al == null:
				al = main.altars[0]
			_put(al.position + Vector2(-70, 50))
			await _steps(120, false)
			await _steps(15)
			al.activate()
			await _steps(60 * 3)
		"niveau":
			var spot := _dense_spot(Regions.center(region))
			main.ground.paint(spot, 520.0, 1.0)
			main.flora.finish_pending()
			_put(spot)
			await _steps(150, false)
			await _steps(15)
			main.world_fx.level_up()
			await _steps(100)
			main.world_fx.graft_pickup(spot + Vector2(60, 20), "")
			await _steps(90)
		"elite":
			var spot := _dense_spot(Regions.center(region))
			main.ground.paint(spot, 520.0, 1.0)
			main.flora.finish_pending()
			_put(spot + Vector2(-150, 60))
			await _steps(150, false)
			var e = main.spawn_enemy_at(spot + Vector2(40, 0), 0)
			e.set_physics_process(false)
			main.make_elite(e)
			await _steps(30)
			e.take_damage(e.hp + 1.0, false)
			await _steps(60 * 3)
	print("%d images dans %s" % [_n, out])
	quit()
