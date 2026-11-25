## Animation des moments forts (jalon Éclat, tâche A) : critique lourd, mort d'élite, phase et mort
## de boss, Cœur purifié. Chaque image est enregistrée (temps fixé) dans --out=<dossier>/<séquence>/,
## puis tools/eclat-anim.sh assemble les GIF avant/après. Marche aussi sans moments.gd (le « avant »).
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 \
##   -s res://tests/eclat_anim.gd -- --out=/chemin/absolu
extends SceneTree

var main
var out := ""
var seq := ""
var n := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(k: int, record := true) -> void:
	for i in k:
		await process_frame
		if record and seq != "":
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png("%s/%s/%03d.png" % [out, seq, n])
			n += 1


func _begin(name: String) -> void:
	seq = name
	n = 0
	DirAccess.make_dir_recursive_absolute("%s/%s" % [out, seq])


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	if out == "":
		printerr("--out=<dossier> manquant")
		quit(2)
		return
	var settings = root.get_node("Settings")
	settings.reduce_effects = false
	settings.damage_numbers = "aucun"
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(2, false)
	main.autotest = false
	main.spawn_timer = 1.0e9
	var p = main.player
	p.set_physics_process(false)
	p.invuln = 1.0e9
	main.hud.glyphs.hide()

	# Critique lourd : un Flétri perd 60 % de sa vie d'un coup critique.
	var at := Vector2(-900, 500)
	p.position = at
	main.camera.reset_smoothing()
	var e = main.spawn_enemy_at(at + Vector2(110, -20), 0)
	main.spawn_enemy_at(at + Vector2(-140, 60), 1)
	main.spawn_enemy_at(at + Vector2(30, 150), 0)
	await _frames(20, false)
	_begin("critique")
	await _frames(12)
	e.take_damage(e.max_hp * 0.6, true)
	await _frames(60)
	_clear()

	# Mort d'une élite, d'un coup critique.
	var el = main.spawn_enemy_at(at + Vector2(120, 10), 2)
	main.make_elite(el)
	main.spawn_enemy_at(at + Vector2(-120, -70), 0)
	main.spawn_enemy_at(at + Vector2(60, 160), 1)
	await _frames(20, false)
	_begin("elite")
	await _frames(12)
	el.take_damage(el.hp + 1.0, true)
	await _frames(75)
	_clear()

	# Cœur purifié.
	var heart = main.heart
	p.position = heart.center + Vector2(-150, 110)
	main.camera.reset_smoothing()
	for i in 4:
		main.spawn_enemy_at(heart.center + Vector2.from_angle(i * 1.4) * 230.0, i % 2)
	await _frames(30, false)
	_begin("coeur")
	await _frames(12)
	heart.purify()
	await _frames(110)
	_clear()

	# Phase puis mort de la Mère-Ronce.
	var arena = main.arena
	p.position = arena.center + Vector2(130, 160)
	main.camera.reset_smoothing()
	arena._start_fight()
	arena.gap_open = 0.0
	var boss = arena.boss
	await _frames(5, false)
	boss.intro = 0.0
	await _frames(60, false)
	_begin("boss_phase")
	await _frames(12)
	boss.take_damage(boss.hp - boss.max_hp * 0.6, false)
	await _frames(90)
	_begin("boss_mort")
	await _frames(12)
	boss.take_damage(boss.hp + 1.0, false)
	await _frames(130)
	seq = ""
	print("eclat_anim : images dans ", out)
	quit(0)


func _clear() -> void:
	seq = ""
	for x in main.enemies:
		if is_instance_valid(x):
			x.queue_free()
	main.enemies = []
