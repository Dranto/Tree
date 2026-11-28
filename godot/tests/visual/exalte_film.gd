## Film des boss exaltés (NG+, jalon 14) : pour chaque boss de région, l'entrée dans la phase exaltée
## puis quelques secondes de cette phase (son attaque nouvelle en tête), joués dans le vrai jeu au cycle
## imposé (Cycles.forced = 2). Une image sur trois enregistrée. Rien n'est comparé : c'est un outil.
##
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 \
##   res://tests/visual/exalte_film.tscn -- --bosses=seve,aube,racine --out=DOSSIER
## La Flétrissure : --bosses=finale (seconde forme, puis l'Exaltation et sa montée).
extends Node

const MainScene = preload("res://scenes/main.tscn")
const Regions = preload("res://scripts/regions.gd")

const BOSSES := ["ronce", "spore", "vent", "seve", "aube", "racine"]
## Images de jeu (60 i/s) filmées dans la phase exaltée.
const LENGTH := 720

var main
var out_dir := "res://tests/visual/out/exalte_film"
var shot := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bosses: Array = BOSSES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bosses="):
			bosses = Array(arg.get_slice("=", 1).split(","))
		elif arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
	get_node("/root/Cycles").forced = 2
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
	var arena = main.finale if id == "finale" else main.arenas.get(id)
	if arena == null:
		printerr("FILM boss inconnu : ", id)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [out_dir, id]))
	shot = 0
	if id != "finale":
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
	if id == "finale":
		arena.descend()
		await _frames(2)
		p.position = arena.center + Vector2(0, 200)
		await _frames(5)
	if not is_instance_valid(arena.get("boss")) or arena.boss.dead:
		arena._start_fight()
	var boss = arena.boss
	await _frames(200)
	var length := LENGTH
	if id == "finale":
		# Seconde forme d'abord (sa transformation dure le drop), puis l'Exaltation, filmée plus longtemps
		# pour voir la montée (un cran par phrase de quatre mesures).
		while boss.music_waiting():
			await _frames(1)
		boss.take_damage(boss.hp - boss.max_hp * 0.3, false)
		for f in 900:
			if boss.phase >= 3 and not boss.music_waiting() and not boss.transforming():
				break
			await _frames(1)
		length = 1500
	var at: float = boss.phase_limits[boss.phase_limits.size() - 1]
	boss.take_damage(boss.hp - boss.max_hp * at + 1.0, false)
	for f in length:
		if not is_instance_valid(boss) or boss.dead:
			break
		boss.hp = maxf(boss.hp, boss.max_hp * minf(0.15, at * 0.6))
		# Le héros tourne lentement autour du boss (sans tirer), touché mais jamais à terre.
		var a := f / 60.0 * 0.5
		p.position = arena.center + Vector2(cos(a), sin(a) * 0.8) * 230.0
		p.hp = Game.stats["max_hp"]
		p.fire_cd = 1.0
		await _frames(1)
		if f % 3 == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png(ProjectSettings.globalize_path("%s/%s/%03d.png" % [out_dir, id, shot]))
			shot += 1
	if is_instance_valid(boss):
		boss.take_damage(boss.hp + 1.0, false)
	await _frames(150)
	print("FILM %s : %d images" % [id, shot])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
