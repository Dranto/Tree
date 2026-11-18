## Captures de l'attaque de base (et des compétences) de chaque build de Spore aux niveaux 1, 10
## et 20, pour les joindre à une PR. Le robot d'équilibrage dépense les points du build.
## Lancer : tools/godot.sh --xvfb -s res://tests/spore_attack_captures.gd
## Les images vont dans godot/tests/visual/out/spore_attaque_<build>_<niveau>.png.
extends SceneTree

const OUT := "res://tests/visual/out"
const AttackScript = preload("res://scripts/attack.gd")

var main
var game


func _initialize() -> void:
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await physics_frame


func _run() -> void:
	game = root.get_node("Game")
	var BuildBot = load("res://scripts/build_bot.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(5)
	main.autotest = false
	main.spawn_timer = 1e9
	var p = main.player
	p.set_physics_process(false)
	p.invuln = 1e9
	var all: Dictionary = BuildBot.load_all()
	for b in ["nuages", "contagion", "toxines"]:
		for level in [1, 10, 20]:
			_clear()
			game.reset()
			var bot = BuildBot.new()
			bot.name = b
			bot.targets = all[b].get("opening", []) + all[b]["targets"]
			bot.choices = all[b]["choices"]
			bot.branch = "spore"
			bot.start_level = level
			bot.spend(game)
			game.tree_changed.emit()
			p.position = Vector2(-2400, 0).rotated(-0.6)
			p.aim = Vector2.RIGHT
			var list := []
			for off in [Vector2(260, -40), Vector2(330, 60), Vector2(400, -10), Vector2(450, 90), Vector2(380, -120)]:
				list.append(_spawn(p.position + off))
			p.aim_point = list[0].position
			await _frames(2)
			for k in p.skills:
				if game.has_key(k):
					p.cast(k, game.stats)
			for i in 3:
				AttackScript.fire(p, list[i % list.size()])
				for j in 14:
					for k in p.skills:
						var obj = p.skill_object(k)
						if obj != null:
							obj.tick(1.0 / 60.0)
						AttackScript.step(p, 1.0 / 60.0)
					await physics_frame
			await _frames(4)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/spore_attaque_%s_%d.png" % [OUT, b, level])
			print("CAPTURE %s %d %s" % [b, level, str(AttackScript.current())])
	quit(0)


func _spawn(pos: Vector2):
	var e = load("res://scripts/enemy.gd").new()
	e.main = main
	e.position = pos
	e.setup(0, 50.0)
	e.hp = 1e6
	e.max_hp = 1e6
	e.speed = 0.0
	e.set_physics_process(false)
	main.enemies_layer.add_child(e)
	main.enemies.append(e)
	main._rebuild_grid()
	return e


func _clear() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	for c in main.projectiles_layer.get_children():
		c.queue_free()
	main.attack_fx.zones.clear()
	main.attack_fx.effects.clear()
	main.fx.clouds.clear()
	main.skill_fx.effects.clear()
	# Champignons, chaînes d'essaim… du build précédent.
	main.player._skill_objects.clear()
	# Annonces laissées par le build précédent (« Ton attaque a changé… »).
	main.hud.banner_queue.clear()
	main.hud.banner_time = 0.0
	main._rebuild_grid()
