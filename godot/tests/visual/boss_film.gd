## Film des boss (jalon Éclat C) : pour chacun des 7 boss, l'arrivée, un changement de phase et la
## mort, joués dans le vrai jeu, une image sur deux enregistrée (tools/boss-film.sh assemble les GIF
## avant/après). Rien n'est comparé : c'est un outil. N'utilise que l'interface des arènes et des boss
## (marche aussi sur une version antérieure, pour l'« avant »).
##
## Arguments (après « -- ») :
##   --bosses=ronce,spore…   boss à filmer (les 7 par défaut)
##   --out=DOSSIER           dossier des images (un sous-dossier par boss)
extends Node

const MainScene = preload("res://scenes/main.tscn")
const Regions = preload("res://scripts/regions.gd")

const BOSSES := ["ronce", "spore", "vent", "seve", "aube", "racine", "finale"]
## Images de jeu (60 i/s) de chaque moment.
const ARRIVAL := 130
const PHASE := 110
const DEATH := 260

var main
var out_dir := "res://tests/visual/out/boss_film"
var shot := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bosses: Array = BOSSES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bosses="):
			bosses = Array(arg.get_slice("=", 1).split(","))
		elif arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
	main = MainScene.instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	add_child(main)
	main.tree_ui.play_intro = false
	await _frames(3)
	main.hud.visible = false
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
	p.position = arena.center + Vector2(0, 130)
	p.reset_physics_interpolation()
	main.camera.reset_smoothing()
	await _frames(2)
	# Le joueur posé dans l'arène peut déjà avoir réveillé le boss : pas de second boss par-dessus.
	if not is_instance_valid(arena.get("boss")) or arena.boss.dead:
		arena._start_fight()
	var boss = arena.boss
	await _record(id, ARRIVAL)
	# Changement de phase : juste sous la première limite.
	if is_instance_valid(boss):
		boss.take_damage(boss.hp - boss.max_hp * float(boss.phase_limits[0]) + 1.0, false)
	await _record(id, PHASE)
	if is_instance_valid(boss):
		boss.take_damage(boss.hp + 1.0, false)
	await _record(id, DEATH)
	print("FILM %s : %d images" % [id, shot])


func _record(id: String, n: int) -> void:
	var p = main.player
	for f in n:
		p.invuln = 0.5
		p.hp = Game.stats["max_hp"]
		p.fire_cd = 1.0
		await _frames(1)
		if f % 2 == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png(ProjectSettings.globalize_path("%s/%s/%03d.png" % [out_dir, id, shot]))
			shot += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
