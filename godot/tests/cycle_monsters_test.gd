## Test des monstres de cycle (jalon 14, tâche M) : plancher de menace, Flétris d'autres régions mêlés
## aux habitués, élites plus fréquentes, et les trois modificateurs réservés au New Game+ (voilé,
## siphonneur, rémanent).
## Lancer : tools/godot.sh --headless -s res://tests/cycle_monsters_test.gd
extends SceneTree

var failures := 0
var main
var cycles


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _steps(n: int) -> void:
	for i in n:
		await physics_frame


func _clear() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	for p in main.projectiles_layer.get_children():
		p.queue_free()
	await _steps(2)


func _run() -> void:
	cycles = root.get_node("Cycles")
	cycles.forced = 1
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _steps(2)
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	main.player.invuln = 1.0e9
	var at := Vector2(-1500, 600)
	main.player.position = at
	var Regions = load("res://scripts/regions.gd")
	var deep: Vector2 = Regions.center("ronce")
	var Enemy = main.Enemy
	var game = root.get_node("Game")
	game.level = 1

	print("Cycle 1 : rien ne change")
	var t1: float = main.threat(Vector2.ZERO)
	check(t1 < 2.0, "menace d'un Flétri près de la graine (%.2f), sans plancher" % t1)
	game.level = 15
	var plain = main.spawn_enemy_kind("fletri", at + Vector2(0, 300), 1.0)
	check(not "voile" in plain.allowed_affixes() and not "siphon" in plain.allowed_affixes() and not "remanent" in plain.allowed_affixes(),
		"les trois modificateurs du NG+ ne sont pas permis au cycle 1")
	var foreign := {}
	for i in 600:
		var k: String = main._pick_kind(deep)
		if Enemy.KINDS[Enemy.kind_index(k)].get("region", "ronce") != "ronce":
			foreign[k] = true
	check(foreign.is_empty(), "au cycle 1, une région ne fait naître que ses Flétris et les ordinaires")
	await _clear()

	print("Cycle 2")
	cycles.forced = 2
	var floor2 := float(cycles.value("threat_floor", 0.0))
	check(floor2 > 1.0 and main.threat(Vector2.ZERO) >= floor2, "plancher de menace : %.2f ≥ %.2f" % [main.threat(Vector2.ZERO), floor2])
	var ok_floor := true
	for lv in [1, 5, 30]:
		game.level = lv
		ok_floor = ok_floor and main.threat(Vector2.ZERO) >= floor2 - 0.001
	game.level = 15
	check(ok_floor, "… à tout niveau")
	check(main.threat(deep) <= float(main.Difficulty.data()["threat"]["max"]) + 0.001, "la menace garde son plafond")
	var mix: Dictionary = cycles.value("mix", {})
	check(mix.has("ronce") and mix.has("ordinaires"), "cycles.json › mix décrit chaque région (%d entrées)" % mix.size())
	var all_known := true
	for reg in mix:
		for k in mix[reg].get("kinds", {}):
			all_known = all_known and Enemy.KIND_INDEX.has(k)
	check(all_known, "toutes les sortes mêlées existent dans enemies.json")
	var foreign2 := {}
	var n_foreign := 0
	for i in 1000:
		var k: String = main._pick_kind(deep)
		if Enemy.KINDS[Enemy.kind_index(k)].get("region", "ronce") != "ronce":
			foreign2[k] = true
			n_foreign += 1
	check(n_foreign > 100 and foreign2.size() >= 3, "des Flétris d'autres régions se mêlent à ceux du roncier (%d sur 1000, %d sortes)" % [n_foreign, foreign2.size()])
	var ord := {}
	for i in 600:
		ord[main._pick_kind(at)] = true
	check(ord.size() > 6, "hors région, les sortes mêlées s'ajoutent aux ordinaires (%d sortes)" % ord.size())
	var near_big := false
	cycles.forced = 3
	for i in 800:
		var k: String = main._pick_kind(Vector2(-300, 0))
		near_big = near_big or k in ["menhir", "souche", "quartz", "tertre"]
	check(not near_big, "cycle 3 : pas de gros Flétris mêlés près de la graine (min_dist)")
	cycles.forced = 2

	print("Élites du cycle 2")
	var cyc: Dictionary = cycles.value("elites", {})
	var cap := int(cyc.get("max_alive", 2))
	for i in 3000:
		var x = main.spawn_enemy_kind("fletri", at + Vector2(i % 400, 900), 1.0)
		main._roll_elite(x, x.position)
		if not x.elite:
			x.queue_free()
			main.enemies.erase(x)
	var elites: int = main.enemies.filter(func(x): return x.elite).size()
	check(elites == cap and cap > int(Enemy.ELITES["max_alive"]), "plus d'élites à la fois qu'au cycle 1 (%d, plafond %d)" % [elites, cap])
	var seen := {}
	for x in main.enemies:
		if x.elite:
			for a in x.affixes:
				seen[a] = true
	print("  info modificateurs vus : ", seen.keys())
	await _clear()

	print("Voilé")
	var vo = main.spawn_enemy_kind("fletri", at + Vector2(600, 0), 1.0)
	vo.make_elite(["voile"])
	check("voile" in vo.affixes and vo.elite_name == "Flétri voilé", "une élite peut être voilée (« %s »)" % vo.elite_name)
	vo.aff_cd["voile"] = 0.0
	await _steps(3)
	check(vo.aff_state == "voile" and vo.blink_to.distance_to(at) < 400.0, "il annonce l'endroit où il reparaîtra, près du héros")
	var dest: Vector2 = vo.blink_to
	await _steps(int(Enemy.ELITES["affixes"]["voile"]["windup"] * 60) + 4)
	check(vo.position.distance_to(dest) < 60.0, "puis il y saute (%.0f px du point annoncé)" % vo.position.distance_to(dest))
	vo.aff_cd["voile"] = 0.0
	vo.position = at + Vector2(100, 0)
	await _steps(3)
	check(vo.aff_state != "voile", "trop près du héros, il ne saute pas")
	await _clear()

	print("Siphonneur")
	var si = main.spawn_enemy_kind("colosse", at + Vector2(150, 0), 1.0)
	si.make_elite(["siphon"])
	si.hp = si.max_hp * 0.5
	si.aff_cd["siphon"] = 0.0
	var hp0: float = si.hp
	await _steps(3)
	check(si.aff_state == "siphon", "il annonce son cercle quand le héros est tout près")
	await _steps(int(Enemy.ELITES["affixes"]["siphon"]["windup"] * 60) + 4)
	check(si.hp > hp0 + si.max_hp * 0.05, "le héros resté dans le cercle nourrit le siphonneur (%.0f → %.0f)" % [hp0, si.hp])
	si.hp = si.max_hp * 0.5
	si.aff_cd["siphon"] = 0.0
	si.position = at + Vector2(1500, 0)
	await _steps(3)
	check(si.aff_state != "siphon", "loin du héros, il ne s'annonce pas")
	await _clear()

	print("Rémanent")
	var re = main.spawn_enemy_kind("fletri", at + Vector2(0, 700), 1.0)
	re.make_elite(["remanent"])
	var n0: int = main.projectiles_layer.get_child_count()
	re.take_damage(re.hp + 1.0, false)
	await _steps(3)
	check(main.projectiles_layer.get_child_count() == n0 + 1, "à sa mort, une poche de cendre s'annonce au sol")
	await _clear()
	var normal = main.spawn_enemy_kind("fletri", at + Vector2(0, 700), 1.0)
	n0 = main.projectiles_layer.get_child_count()
	normal.take_damage(normal.hp + 1.0, false)
	await _steps(3)
	check(main.projectiles_layer.get_child_count() == n0, "un Flétri ordinaire n'en laisse pas")

	print("Retour au cycle 1")
	cycles.forced = 1
	var back = main.spawn_enemy_kind("fletri", at, 1.0)
	check(not "voile" in back.allowed_affixes(), "les modificateurs du NG+ disparaissent au cycle 1")
	check(main.Difficulty.validate().is_empty() and main.Enemy.validate_kinds().is_empty(), "les données restent valides")

	main.queue_free()
	await process_frame
	print("Monstres de cycle : %s" % ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
