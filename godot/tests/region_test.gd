## Test de la région du roncier (jalon 3, tâche C) : géométrie de la région, résistance aux
## dégâts de Ronce, buissons d'épines, vague de vie, apparitions et comportements des ennemis.
## Lancer : tools/godot.sh --headless -s res://tests/region_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")

var failures := 0
var main
var game


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


func _run() -> void:
	game = root.get_node("Game")
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true      # ni sauvegarde lue ni écrite
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _steps(2)
	main.autotest = false     # plus de robot : le joueur ne bouge que si on le déplace
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	main.player.invuln = 1.0e9

	print("Géométrie")
	var c: Vector2 = main.region_center("ronce")
	check(main.region_at(c) == "ronce", "le centre de la région est dans le roncier")
	check(main.region_at(Vector2.ZERO) == "", "la graine n'est dans aucune région")
	check(main.region_at(-c) != "ronce", "le côté opposé n'est pas le roncier")
	var ronce_dir := Vector2.from_angle(Regions.angle_of("ronce"))
	var node_dir := Vector2.ZERO
	for n in game.tree.nodes:
		if n["branch"] == 0 and n["ring"] == 12:
			node_dir += n["pos"].normalized()
	check(node_dir.normalized().dot(ronce_dir) > 0.97, "la région est dans la direction de la branche Ronce de l'arbre")
	check(c.length() > 600.0 and c.length() < main.WORLD_HALF, "le centre est au-delà de l'oasis et dans le monde")

	print("Résistance aux dégâts de Ronce")
	var tireur = main.spawn_enemy_kind("tireur", c + Vector2(300, 0), 1.0)
	var fletri = main.spawn_enemy_kind(0, c + Vector2(-300, 0), 1.0)
	check(is_equal_approx(main.branch_factor(tireur, "ronce"), 0.75), "un Tireur d'épines ignore 25 % des dégâts de Ronce")
	check(is_equal_approx(main.branch_factor(tireur, ""), 1.0), "… mais pas les autres dégâts")
	check(is_equal_approx(main.branch_factor(fletri, "ronce"), 1.0), "un Flétri ordinaire ne résiste pas")
	tireur.queue_free()
	fletri.queue_free()
	await _steps(2)
	main.enemies.clear()

	print("Buissons d'épines")
	check(main.flora.bushes.size() > 20, "le roncier a des buissons d'épines (%d)" % main.flora.bushes.size())
	var inside_region := true
	var clear_center := true
	# Les obstacles des autres régions (rochers des plateaux…) sont dans leur propre région.
	var ronce_bushes: Array = main.flora.bushes.filter(func(b): return not main.region_at(b.position) in Regions.ids() or main.region_at(b.position) == "ronce")
	for b in ronce_bushes:
		inside_region = inside_region and main.region_at(b.position) == "ronce"
		clear_center = clear_center and b.position.distance_to(c) >= float(Regions.section("ronce", "decor").get("clear_center", 340.0))
	check(inside_region, "tous les buissons sont dans la région")
	check(clear_center, "le centre de la région (Cœur, arène) reste libre")
	var bush = main.flora.bushes[0]
	main.player.position = bush.position + Vector2(3, 0)
	await _steps(1)
	check(main.player.position.distance_to(bush.position) >= bush.radius + main.player.radius - 0.5, "le joueur est repoussé hors d'un buisson")
	check(main.flora.push_out(Vector2.ZERO, 14.0) == Vector2.ZERO, "rien ne gêne à la graine")

	print("Vague de vie")
	var spot: Vector2 = c + Vector2(0, 200)
	main.ground.finish_waves()   # vagues des nœuds appris au lancement
	var before: float = main.ground.total
	main.ground.paint_wave(spot, 300.0, 0.9)
	await _steps(30)
	var mid_edge: float = main.ground.life_at(spot + Vector2(280, 0))
	check(main.ground.life_at(spot) > 0.45 and mid_edge < 0.05, "à mi-chemin, le centre est vert et le bord encore mort")
	await _steps(90)
	check(main.ground.waves.is_empty(), "la vague se termine en moins de 2 s")
	var wave_gain: float = main.ground.total - before
	# Même apport qu'une peinture instantanée au même endroit (sur une carte neuve).
	var g2 = load("res://scripts/ground.gd").new()
	root.add_child(g2)
	g2.paint(spot, 300.0, 0.9)
	check(absf(g2.total - wave_gain) < 0.01, "la vague apporte exactement la même vie qu'une peinture (%.2f / %.2f)" % [wave_gain, g2.total])
	g2.queue_free()
	var revived := 0
	for t in main.flora.trees:
		if t.alive and t.position.distance_to(spot) < 200.0:
			revived += 1
	check(revived > 0, "des ronces ont reverdi sous la vague (%d)" % revived)
	main.ground.paint_wave(spot + Vector2(600, 0), 200.0, 0.5)
	await _steps(5)
	main.ground.export_map()
	check(main.ground.waves.is_empty(), "une sauvegarde termine les vagues en cours")

	print("Apparitions")
	var counts := {}
	main.player.position = c
	for i in 400:
		var pos: Vector2 = c + Vector2.from_angle(main.rng.randf() * TAU) * 200.0
		var k: String = main._region_kind("ronce", pos)
		counts[k] = int(counts.get(k, 0)) + 1
	check(int(counts.get("tireur", 0)) > 0 and int(counts.get("chargeur", 0)) > 0, "tireurs et chargeurs naissent au centre de la région " + str(counts))
	var near := 0
	var far := 0
	for i in 400:
		if main._region_kind("ronce", ronce_dir * 520.0) != "":
			near += 1
		if main._region_kind("ronce", ronce_dir * 2700.0) != "":
			far += 1
	check(far > near * 2, "plus nombreux loin de la graine (%d près, %d loin)" % [near, far])
	game.flags["ronce_coeur_purifie"] = true
	var purified := 0
	for i in 400:
		if main._region_kind("ronce", ronce_dir * 2700.0) != "":
			purified += 1
	check(purified < far * 0.6, "moins nombreux une fois le Cœur purifié (%d)" % purified)
	game.flags.erase("ronce_coeur_purifie")
	var outside := 0
	main.spawn_timer = 0.0
	# Un point hors de toute région (à l'opposé de Ronce, ou en tournant autour de la graine
	# s'il tombe dans une autre région : Spore, Vent…), loin de leurs bords.
	var away := -c
	for k in 36:
		var p := c.rotated(PI + k * TAU / 36.0)
		if main.region_at(p) == "" and main.region_at(p.rotated(0.6)) == "" and main.region_at(p.rotated(-0.6)) == "":
			away = p
			break
	main.player.position = away
	await _steps(2)
	main.spawn_timer = 1.0e9
	# Les apparitions tombent à 760-980 px du joueur, parfois dans une région voisine : on ne
	# compte que les Flétris nés hors de toute région.
	var born_outside := 0
	for e in main.enemies:
		if main.region_at(e.position) != "":
			continue
		born_outside += 1
		if e.region != "":
			outside += 1
	check(outside == 0 and born_outside > 0, "hors de la région, seuls des Flétris ordinaires naissent (%d nés hors des régions)" % born_outside)
	for e in main.enemies:
		e.queue_free()
	main.enemies.clear()
	await _steps(1)

	print("Comportements")
	main.player.position = c
	var shooter = main.spawn_enemy_kind("tireur", c + Vector2(300, 0), 1.0)
	shooter.cd = 0.0
	await _steps(3)
	check(shooter.state == "windup", "le Tireur annonce son tir")
	await _steps(int(shooter.data["windup"] * 60) + 2)
	var thorns: Array = main.projectiles_layer.get_children().filter(func(p): return p.get_script() == load("res://scripts/enemy_thorn.gd"))
	check(thorns.size() == 1, "puis tire une épine")
	main.player.invuln = 0.0
	var hp0: float = main.player.hp
	await _steps(70)
	check(main.player.hp < hp0, "l'épine blesse le joueur (%.0f -> %.0f)" % [hp0, main.player.hp])
	main.player.invuln = 1.0e9
	main.player.hp = game.stats["max_hp"]
	shooter.queue_free()

	var charger = main.spawn_enemy_kind("chargeur", c + Vector2(-300, 0), 1.0)
	charger.cd = 0.0
	await _steps(3)
	check(charger.state == "windup", "le Chargeur annonce sa charge")
	var start: Vector2 = charger.position
	await _steps(int(charger.data["windup"] * 60) + 20)
	check(charger.state == "charge" or charger.state == "recover", "puis charge")
	check(charger.position.distance_to(start) > 100.0, "en ligne droite, vite (%.0f px)" % charger.position.distance_to(start))
	charger.queue_free()

	var nest = main.spawn_enemy_kind("nid", c + Vector2(0, -250), 1.0)
	nest.cd = 0.0
	var nest_pos: Vector2 = nest.position
	await _steps(int(nest.data["windup"] * 60) + 5)
	check(nest.young.size() == 1 and nest.young[0].kind_id == "rejeton", "le Nid fait naître un Rejeton")
	check(nest.position == nest_pos, "le Nid ne bouge pas")
	nest.cd = 0.0
	nest.young.append_array([nest, nest, nest])  # plein : plus de naissance
	await _steps(int(nest.data["windup"] * 60) + 5)
	check(nest.state == "", "il s'arrête quand il a assez de petits")

	main.queue_free()
	await process_frame
	print("Région du roncier : %s" % ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
