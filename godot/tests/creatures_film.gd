## Film du moteur de créatures (refonte des personnages, vague 1 A) : une même scène de combat du vrai
## jeu, rejouée à l'identique (graine et pas fixes), enregistrée image par image. Lancée deux fois
## (« --no-sprites » puis rendu cuit), elle donne l'avant/après de tools/creatures-film.sh.
##
##   tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1600x900 \
##     res://tests/creatures_film.tscn -- --seed=1234 --out=DOSSIER [--no-sprites] [--scene=melee|elites]
## Rien n'est comparé : c'est un outil.
extends Node

const MainScene = preload("res://scenes/main.tscn")
const Content = preload("res://scripts/content.gd")

## Images enregistrées (une sur deux à 60 i/s : GIF à 30 i/s).
const FRAMES := 150
const ORIGIN := Vector2(0, 320)
## Scènes : [sorte, décalage depuis le héros, élite (modificateurs)].
const SCENES := {
	"melee": [
		["tireur", Vector2(260, -120), []], ["tireur", Vector2(300, 60), []], ["scarabee", Vector2(-280, 40), []],
		["scarabee", Vector2(200, 170), []], ["menhir", Vector2(-220, -150), []], ["menhir", Vector2(120, -230), []],
		["fletri", Vector2(-120, 200), []], ["chargeur", Vector2(330, -10), []],
	],
	"elites": [
		["tireur", Vector2(240, -90), ["rapide"]], ["scarabee", Vector2(-240, 30), ["ecorce"]],
		["menhir", Vector2(160, 170), ["enrage"]], ["fletri", Vector2(-150, -160), ["rapide"]],
	],
}

var main
var game
var out_dir := "user://film"
var scene := "melee"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--scene="):
			scene = arg.get_slice("=", 1)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# Autoloads lus à l'exécution (un script -s ne les connaît pas à la compilation).
	var settings = get_tree().root.get_node("/root/Settings")
	game = get_tree().root.get_node("/root/Game")
	settings.set_move_mode(settings.MOVE_MODE_DEFAULT)
	settings.aim_mode = "auto"
	main = MainScene.instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	get_tree().root.add_child(main)
	main.tree_ui.play_intro = false
	await _frames(3)
	main.hud.glyphs.hide()
	main.hud.visible = false
	main.autotest = false
	main.spawn_timer = 1e9
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	var p = main.player
	p.position = ORIGIN
	p.reset_physics_interpolation()
	main.camera.zoom = Vector2.ONE * 1.5
	main.camera.reset_smoothing()
	for s in SCENES[scene]:
		var e = main.spawn_enemy_kind(s[0], ORIGIN + s[1], 2.0)
		if not s[2].is_empty():
			e.make_elite(s[2])
	# Le temps que les sortes de la scène soient cuites (rendu cuit) : la même attente sans.
	await _frames(12)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var shot := 0
	for f in FRAMES * 2:
		p.invuln = 0.4
		p.hp = game.stats["max_hp"]
		p.fire_cd = 1.0
		for e in main.enemies:
			if is_instance_valid(e):
				e.hp = maxf(e.hp, e.max_hp * 0.6)
		# Quelques coups reçus pour voir l'éclair et le recul.
		if f % 50 == 25 and not main.enemies.is_empty():
			var e = main.enemies[(f / 50) % main.enemies.size()]
			if is_instance_valid(e):
				e.take_damage(1.0, false)
		await _frames(1)
		if f % 2 == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png("%s/%03d.png" % [out_dir, shot])
			shot += 1
	print("FILM %d images dans %s" % [shot, out_dir])
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
