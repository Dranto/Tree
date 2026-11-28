## Film des boss exaltés (NG+, jalon 14 B1) : pour chaque boss, l'entrée dans la phase exaltée puis
## l'attaque nouvelle jouée deux fois, dans le vrai jeu, au cycle imposé par « --cycle=2 ». Une image
## sur trois enregistrée. Rien n'est comparé : c'est un outil (GIF assemblés par ffmpeg à la main).
##
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 \
##   res://tests/visual/exalte_film.tscn -- --cycle=2 --bosses=ronce,spore,vent --out=DOSSIER
extends Node

const MainScene = preload("res://scenes/main.tscn")
const Regions = preload("res://scripts/regions.gd")

## Images de jeu (60 i/s) : entrée dans la phase exaltée, puis au plus LIMIT images d'attaque.
const ENTRY := 150
const LIMIT := 900

var main
var out_dir := "res://tests/visual/out/exalte_film"
var shot := 0
var every := 3


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bosses: Array = ["ronce", "spore", "vent"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bosses="):
			bosses = Array(arg.get_slice("=", 1).split(","))
		elif arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--every="):
			every = maxi(1, int(arg.get_slice("=", 1)))
	main = MainScene.instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	add_child(main)
	main.tree_ui.play_intro = false
	await _frames(3)
	main.autotest = false
	main.autosave_enabled = false
	main.spawn_timer = 1e9
	for id in bosses:
		await _film(str(id))
	get_tree().quit(0)


func _film(id: String) -> void:
	var arena = main.arenas.get(id)
	if arena == null:
		printerr("FILM boss inconnu : ", id)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [out_dir, id]))
	shot = 0
	Game.flags[Regions.heart_flag(id)] = true
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	var p = main.player
	p.position = arena.center + Vector2(0, 200)
	p.reset_physics_interpolation()
	main.camera.reset_smoothing()
	await _frames(2)
	if not is_instance_valid(arena.get("boss")) or arena.boss.dead:
		arena._start_fight()
	var boss = arena.boss
	await _frames(int(boss.intro / (1.0 / 60.0)) + 5)
	# Jusqu'à la phase exaltée, sans filmer les phases 2 et 3.
	for want in [2, 3, 4]:
		if want - 2 >= boss.phase_limits.size():
			break
		boss.hp = boss.max_hp * (float(boss.phase_limits[want - 2]) - 0.01)
		for i in 600:
			if boss.phase == want and (want == 4 or boss.transition <= 0.0):
				break
			await _frames(1)
	await _record(id, ENTRY, Callable())
	# L'attaque nouvelle, deux fois de suite.
	boss.cycle = 0
	var seen := 0
	var was := false
	var n := 0
	while seen < 2 and n < LIMIT and is_instance_valid(boss) and not boss.dead:
		await _record(id, 1, Callable())
		n += 1
		var on: bool = boss.attack == boss.EXALTED_ATTACK
		if was and not on:
			seen += 1
		was = on
	if is_instance_valid(boss):
		boss.take_damage(boss.hp + 1.0, false)
	await _record(id, 60, Callable())
	print("FILM %s : %d images" % [id, shot])
	await _frames(200)


var _frame := 0


func _record(id: String, n: int, _cb: Callable) -> void:
	var p = main.player
	for f in n:
		p.invuln = 0.5
		p.hp = Game.stats["max_hp"]
		await _frames(1)
		_frame += 1
		if _frame % every == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png(ProjectSettings.globalize_path("%s/%s/%03d.png" % [out_dir, id, shot]))
			shot += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
