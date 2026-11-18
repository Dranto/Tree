## Captures de la branche Vent (jalon 7, tâche D), pour les joindre à une PR :
##  - l'attaque de chaque build de Vent (data/builds.json, branch « vent ») à trois moments :
##    sa forme tout juste prise (« debut »), au niveau 10 et au niveau 20 ;
##  - le secteur de Vent dans l'Arbre de vie, à trois zooms.
## Lancer : tools/godot.sh --xvfb -s res://tests/vent_captures.gd -- --shot=attaque:lames:10
##          tools/godot.sh --xvfb -s res://tests/vent_captures.gd -- --shot=arbre
## Les images vont dans godot/tests/visual/out/vent_*.png (dossier ignoré par git).
extends SceneTree

const OUT := "res://tests/visual/out"
const BuildBot = preload("res://scripts/build_bot.gd")

var main
var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var shot := "arbre"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
	game = root.get_node("Game")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(5)
	main.autotest = false
	main.autosave_enabled = false
	main.spawn_paused = true
	main.hud.hint_time = 0.0
	if shot == "arbre":
		await _tree()
	else:
		var parts := shot.split(":")
		await _attack(parts[1], parts[2])
	quit(0)


## Le build appris jusqu'au niveau demandé (« debut » : seulement son ouverture), puis quelques
## Flétris figés devant le héros, et l'attaque qui part sur eux.
func _attack(build: String, level: String) -> void:
	var all := BuildBot.load_all()
	var b: Dictionary = all[build]
	var bot = BuildBot.new()
	bot.name = build
	bot.branch = str(b.get("branch", "vent"))
	bot.choices = b.get("choices", {})
	if level == "debut":
		bot.targets = b.get("opening", [])
		var guard := 0
		while guard < 40:
			guard += 1
			var id: int = -1
			for uid in bot.targets:
				if not game.allocated.has(game.tree.id_for_uid(uid)):
					id = bot._next(game)
					break
			if id < 0:
				break
			game.points += 1
			if not game.allocate(id):
				break
			bot._choose(game, id)
	else:
		bot.targets = b.get("opening", []) + b.get("targets", [])
		bot.start_level = int(level)
		bot.spend(game)
	await _frames(3)
	var p = main.player
	var spot: Vector2 = p.position + Vector2(-60, 330)
	_place(spot)
	var melee: bool = str(b.get("style", "distance")) == "melee"
	var d := 130.0 if melee else 330.0
	for i in 5:
		var at: Vector2 = spot + Vector2(d + (i % 2) * 50.0, (i - 2) * 55.0)
		var e = main.spawn_enemy_at(at, 0)
		e.set_physics_process(false)
		e.hp = 1.0e6
		e.max_hp = 1.0e6
	if build == "tornade" and level != "debut":
		p.cds.clear()
		var tor = p.skill_object("tornade")
		if tor != null:
			p.aim = Vector2.RIGHT
			tor.cast(p)
	await _physics(70 if not melee else 40)
	main.hud.banner_time = 0.0
	await _shot("vent_attaque_%s_%s" % [build, level])


## Le secteur de Vent : vue d'ensemble de la branche, une grappe, puis de près.
func _tree() -> void:
	game.points = 0
	var ui = main.tree_ui
	ui.toggle()
	await _frames(5)
	var t = game.tree
	var mid: Vector2 = t.nodes[t.id_for_uid("key:pas_du_vent")]["pos"]
	var near_id: int = t.id_for_uid("c:vent:course:r4")
	var near: Vector2 = t.nodes[near_id]["pos"] if near_id >= 0 else mid * 0.55
	for z in [["loin", 0.42, mid * 0.75], ["moyen", 0.8, mid * 0.62], ["proche", 1.6, near]]:
		ui.zoom = z[1]
		ui.cam = z[2]
		ui._redraw_all()
		await _shot("vent_arbre_%s" % z[0])


func _place(pos: Vector2) -> void:
	main.player.position = pos
	main.player.hp = 1.0e6
	main.player.reset_physics_interpolation()


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _physics(k: int) -> void:
	for i in k:
		await physics_frame
		main.player.hp = 1.0e6


func _shot(shot_name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
	print("CAPTURE ", shot_name)
