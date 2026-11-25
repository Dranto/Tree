## Film des effets (jalon Éclat) : rejoue de courtes scènes du vrai jeu et en enregistre chaque image,
## pour assembler des GIF avant/après (tools/eclat-film.sh). Rien n'est comparé : c'est un outil.
##
## Arguments (après « -- ») :
##   --clips=a,b,c   scènes à filmer (voir CLIPS), toutes par défaut
##   --out=DOSSIER   dossier des images (une sous-dossier par scène), res://tests/visual/out/film par défaut
extends Node

const MainScene = preload("res://scenes/main.tscn")
const Enemy = preload("res://scripts/enemy.gd")
const Content = preload("res://scripts/content.gd")

## Scène : compétence lancée (ou « esquive »), et disposition des Flétris autour du héros.
const CLIPS := ["fouet", "racines", "volee", "saignee", "nova", "esquive", "pret",
	"cloud", "vesse", "essaim", "eclosion", "bloom", "tornade", "ruee", "appel_air", "liane", "fontaine", "cocon",
	"aurore", "prisme", "lance_aube", "ecorce", "ancrage", "pieux", "cumul"]
## Images enregistrées par scène (une sur deux à 60 i/s : GIF à 30 i/s).
const FRAMES := 44
## Lieu des scènes : sur la terre ravivée, à l'écart du sanctuaire de départ.
const ORIGIN := Vector2(0, 320)

var main
var out_dir := "res://tests/visual/out/film"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var clips: Array = CLIPS.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clips="):
			clips = Array(arg.get_slice("=", 1).split(","))
		elif arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
	Settings.set_move_mode(Settings.MOVE_MODE_DEFAULT)
	Settings.aim_mode = "auto"
	Settings.bindings = Settings.BINDING_DEFAULTS.duplicate()
	Settings.apply_bindings()
	main = MainScene.instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	add_child(main)
	main.tree_ui.play_intro = false
	await _frames(3)
	var p = main.player
	Game.test_skills = {}
	for id in Content.skills():
		Game.test_skills[id] = true
	Game.recompute()
	main.hud.glyphs.hide()
	main.hud.visible = false   # le film recadre sur le héros : l'interface n'y paraît pas
	main.autotest = false
	main.spawn_timer = 1e9
	for c in clips:
		if not c in CLIPS:
			printerr("FILM scène inconnue : ", c)
			continue
		await _clip(str(c))
	get_tree().quit(0)


func _clip(id: String) -> void:
	var p = main.player
	_clear()
	p.position = ORIGIN
	p.reset_physics_interpolation()
	main.camera.zoom = Vector2.ONE * 1.6
	main.camera.reset_smoothing()
	p.hp = Game.stats["max_hp"]
	for k in p.cds:
		p.cds[k] = 0.0
	p.dash_cd = 0.0
	if id == "cumul":
		Game.test_attack = [{"attack_form": "rayon", "priority": 99}, {"attack_form": "lame"}, {"attack_form": "massue"},
			{"attack_form": "fouet"}, {"attack_form": "spore_lobee"}, {"attack_form": "perle"}]
	else:
		Game.test_attack = []
	Game.recompute()
	# « pret » : une longue recharge (les racines) qui s'achève sous nos yeux.
	Game.flags["barre"] = (id if id in Content.skills() else ("racines" if id == "pret" else "fouet")) + ",volee"
	p.sync_bar()
	await _frames(2)
	# Flétris : un groupe devant (à droite), deux sur le côté, un derrière.
	for i in 4:
		_spawn(ORIGIN + Vector2(150 + (i % 2) * 45, -70 + i * 45), 0)
	_spawn(ORIGIN + Vector2(60, 150), 1)
	_spawn(ORIGIN + Vector2(-160, -40), 0)
	await _frames(2)
	for e in main.enemies:
		e.apply_status("saignement", 1.0, 6.0)
		e.apply_status("poison", 1.0, 6.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [out_dir, id]))
	var s: Dictionary = Game.stats
	p.aim = Vector2.RIGHT
	p.aim_point = ORIGIN + Vector2(170, 0)
	var shot := 0
	await _frames(1)
	if main.skill_fx != null:
		main.skill_fx.effects.clear()   # pas d'éclat « prête » laissé par la remise à zéro des recharges
	for f in FRAMES * 2:
		p.invuln = 0.4
		if id != "cumul":
			p.fire_cd = 1.0   # pas d'attaque de base : seule la compétence filmée
		p.hp = Game.stats["max_hp"]
		for e in main.enemies:
			e.hp = maxf(e.hp, e.max_hp * 0.5)   # ils restent debout : on voit tout l'effet
		if f == 8:
			match id:
				"esquive":
					Input.action_press("dash")
				"pret":
					p.cds["racines"] = 0.05
				"cumul":
					pass
				_:
					# Le pas physique refait la visée à chaque image : elle est reposée juste avant.
					p.aim = Vector2.RIGHT
					p.aim_point = ORIGIN + Vector2(170, 0)
					p.cast(id, s)
		if f == 10 and id == "esquive":
			Input.action_release("dash")
		if id == "cumul" and f >= 8:
			p.target = main.enemies[0]
		await _frames(1)
		if f % 2 == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png(ProjectSettings.globalize_path("%s/%s/%03d.png" % [out_dir, id, shot]))
			shot += 1


func _clear() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	if main.skill_fx != null:
		main.skill_fx.effects.clear()


func _spawn(pos: Vector2, kind: int) -> void:
	var e = Enemy.new()
	e.main = main
	e.position = pos
	e.setup(kind, 3.0)
	e.t = 0.0
	main.enemies_layer.add_child(e)
	main.enemies.append(e)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
