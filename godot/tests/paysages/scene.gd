## Captures « avant » de la planche « Paysages d'herbier » (refonte du monde, vague 0, tâche W) : la
## vraie partie, posée sur le cadre d'une région (scripts/world_art/cadres.gd), le héros au centre et les
## mêmes Flétris figés aux mêmes places que sur l'« après ». Deux états : flétri (le Cœur vit), puis
## ravivé (le Cœur purifié, sa vie peinte au sol, la région apaisée). Écrit aussi les positions réelles
## des lieux et des personnages (cadre_<région>.json) pour que l'« après » se dessine au même endroit.
## Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1920x1080 res://tests/paysages/scene.tscn -- --region=ronce --out=DOSSIER [--prefix=deck_]
extends Node

const MainScene = preload("res://scenes/main.tscn")
const Cadres = preload("res://scripts/world_art/cadres.gd")

var main


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var out := _arg("--out=", "user://paysages")
	var reg := _arg("--region=", "ronce")
	var pre := _arg("--prefix=", "")
	DirAccess.make_dir_recursive_absolute(out)
	var cadre := Cadres.get_cadre(reg)
	main = MainScene.instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	add_child(main)
	main.tree_ui.play_intro = false
	main.autotest = false
	main.spawn_timer = 1.0e9
	var p = main.player
	p.set_physics_process(false)
	var c: Vector2 = cadre["center"]
	p.position = c
	p.reset_physics_interpolation()
	main.camera.reset_smoothing()
	await _frames(40)
	_clear_enemies()
	# Les Cœurs ne font plus naître personne pendant la pose.
	for h in main.all_hearts:
		h.set_physics_process(false)
	main.hud.glyphs.visible = false
	p.aim = Vector2(1, -0.2).normalized()
	var list := []
	for k in cadre["cast"]:
		var e = main.spawn_enemy_kind(k["kind"], c + k["at"], 1.0)
		e.t = 0.5
		for key in k["pose"]:
			e.set(key, k["pose"][key])
		e.attack_dir = (c + Vector2(0, -20) - e.position).normalized()
		e.face = e.attack_dir
		e.cd = 99.0
		e.set_process(false)
		e.set_physics_process(false)
		list.append(e)
	await _frames(8)
	_quiet_hud()
	await _frames(2)
	(await _grab()).save_png(out + "/%s%s_avant_fletri.png" % [pre, reg])
	# Positions réelles des lieux (le sanctuaire s'écarte parfois des buissons).
	var heart = null
	for h in main.region_hearts.get(reg, []):
		if heart == null or h.center.distance_to(cadre["heart_pos"]) < heart.center.distance_to(cadre["heart_pos"]):
			heart = h
	var real := {"heart_pos": heart.center, "cast": []}
	for s in main.sanctuaries:
		if s.id == cadre["sanctuary"]:
			real["sanctuary_pos"] = s.position
	for a in main.altars:
		if a.id == cadre["altar"]:
			real["altar_pos"] = a.position
	for e in list:
		real["cast"].append(e.position)
	real["camera"] = main.camera.get_screen_center_position()
	var f := FileAccess.open(out + "/%scadre_%s.json" % [pre, reg], FileAccess.WRITE)
	f.store_string(JSON.stringify(_jsonable(real), "  "))
	f.close()
	# Ravivé : le Cœur purifié, sa vie peinte au sol (sans la vague ni les effets), la région apaisée.
	heart._set_purified(false)
	main.ground.set_purified(reg, 1.0)
	main.ground.paint(heart.center, heart.life_radius, 1.0)
	main.ground.finish_waves()
	await _frames(30)
	_quiet_hud()
	await _frames(2)
	(await _grab()).save_png(out + "/%s%s_avant_ravive.png" % [pre, reg])
	get_tree().quit(0)


func _clear_enemies() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies = []


func _quiet_hud() -> void:
	main.hud.banner_queue = []
	main.hud.banner_time = 0.0


func _jsonable(v):
	if v is Vector2:
		return [v.x, v.y]
	if v is Array:
		return v.map(func(x): return _jsonable(x))
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _jsonable(v[k])
		return o
	return v


func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key):
			return a.substr(key.length())
	return def


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
