## Test des ennemis variés et des élites (jalon 4, tâche D) : Cracheur de cendre, Gardien d'écorce,
## Boursouflé, tirage des sortes ordinaires, élites et chacun de leurs modificateurs, butin.
## Lancer : tools/godot.sh --headless -s res://tests/enemies_test.gd
extends SceneTree

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


func _clear() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	for p in main.projectiles_layer.get_children():
		p.queue_free()
	await _steps(2)


func _run() -> void:
	game = root.get_node("Game")
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true      # ni sauvegarde lue ni écrite
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _steps(2)
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	main.player.invuln = 1.0e9
	# Loin de la graine, en terre morte, hors du roncier.
	var at := Vector2(-1500, 600)
	main.player.position = at

	print("Cracheur de cendre")
	var k = main.spawn_enemy_kind("cracheur", at + Vector2(120, 0), 1.0)
	var d0: float = k.position.distance_to(at)
	await _steps(30)
	check(k.position.distance_to(at) > d0 + 20.0, "il fuit le joueur trop proche (%.0f → %.0f px)" % [d0, k.position.distance_to(at)])
	k.position = at + Vector2(380, 0)
	k.cd = 0.0
	await _steps(2)
	check(k.state == "windup", "à bonne distance, il annonce son tir")
	var before: int = main.projectiles_layer.get_child_count()
	await _steps(int(k.data["windup"] * 60) + 3)
	var shots := 0
	for p in main.projectiles_layer.get_children():
		if "look" in p and p.look == "cendre":
			shots += 1
	check(shots == int(k.data["shots"]), "puis crache un éventail de %d boules de cendre (%d)" % [k.data["shots"], shots])
	var ball = main.projectiles_layer.get_child(main.projectiles_layer.get_child_count() - 1)
	check(ball.look == "cendre", "les tirs ont l'apparence de boules de cendre")
	await _clear()

	print("Gardien d'écorce")
	var g = main.spawn_enemy_kind("gardien", at + Vector2(400, 0), 1.0)
	var near = main.spawn_enemy_kind("fletri", g.position + Vector2(60, 0), 1.0)
	var far = main.spawn_enemy_kind("fletri", g.position + Vector2(0, 600), 1.0)
	near.anchored = true
	await _steps(2)
	check(near.guard_time > 0.0 and far.guard_time <= 0.0, "il protège ses voisins, pas les ennemis éloignés")
	var hp0: float = near.hp
	near.take_damage(10.0, false)
	var hp1: float = far.hp
	far.take_damage(10.0, false)
	check(is_equal_approx(hp0 - near.hp, 10.0 * (1.0 - g.data["guard"])), "un voisin protégé ignore %d %% des dégâts" % int(g.data["guard"] * 100))
	check(is_equal_approx(hp1 - far.hp, 10.0), "un ennemi éloigné les prend en entier")
	var ghp: float = g.hp
	g.take_damage(10.0, false)
	check(is_equal_approx(ghp - g.hp, 10.0), "le gardien lui-même n'est pas protégé")
	g.take_damage(g.hp + 1.0, false)
	await _steps(20)
	check(near.guard_time <= 0.0, "le gardien vaincu, la protection tombe")
	await _clear()

	print("Boursouflé")
	main.player.invuln = 0.0
	main.player.hp = 1000.0
	var b = main.spawn_enemy_kind("boursoufle", at + Vector2(40, 0), 1.0)
	var victim = main.spawn_enemy_kind("fletri", at + Vector2(80, 30), 1.0)
	victim.anchored = true
	var blast_delay: float = b.data["blast_delay"]
	b.take_damage(b.hp + 1.0, false)
	await _steps(2)
	var blast = null
	for p in main.projectiles_layer.get_children():
		if "enemy_damage" in p:
			blast = p
	check(blast != null, "à sa mort, il laisse une poche de spores")
	var php: float = main.player.hp
	check(is_equal_approx(php, 1000.0), "elle n'éclate pas tout de suite (annonce au sol)")
	await _steps(int(blast_delay * 60) + 4)
	check(main.player.hp < php, "puis elle blesse le joueur resté dedans")
	check(not is_instance_valid(victim) or victim.dead or victim.hp < victim.max_hp, "et aussi les Flétris autour")
	main.player.invuln = 1.0e9
	await _clear()

	print("Tirage des Flétris ordinaires")
	game.level = 1
	var seen := {}
	for i in 400:
		seen[main._ordinary_kind()] = true
	check(seen.has("fletri") and seen.has("cendreux"), "au niveau 1 : Flétris et Cendreux")
	check(not seen.has("colosse") and not seen.has("gardien") and not seen.has("boursoufle"), "… mais pas encore de Colosse, de Gardien ni de Boursouflé")
	game.level = 12
	seen = {}
	for i in 1000:
		seen[main._ordinary_kind()] = true
	check(seen.has("cracheur") and seen.has("gardien") and seen.has("boursoufle") and seen.has("colosse"), "au niveau 12 : toutes les sortes ordinaires")
	for i in 3:
		main.spawn_enemy_kind("gardien", at + Vector2(500 + i * 40, 0), 1.0)
	var gardiens := 0
	for i in 500:
		if main._ordinary_kind() == "gardien":
			gardiens += 1
	check(gardiens == 0, "pas plus de %d Gardiens en même temps" % main.ordinary_spawn["max_alive"]["gardien"])
	await _clear()

	print("Élites")
	var e = main.spawn_enemy_kind("fletri", at + Vector2(500, 0), 1.0)
	var base_hp: float = e.max_hp
	var base_xp: float = e.xp_value
	e.make_elite(["rapide", "enrage"])
	check(e.elite and e.affixes == ["rapide", "enrage"], "une élite garde la liste de ses modificateurs")
	check(e.elite_name == "Flétri rapide et enragé", "son nom dit ses modificateurs (« %s »)" % e.elite_name)
	check(e.max_hp > base_hp * 2.5 and e.xp_value > base_xp * 3.0, "plus de vie et plus d'expérience")
	var nest = main.spawn_enemy_kind("nid", at + Vector2(0, 800), 1.0)
	check(not nest.can_be_elite(), "un Nid de ronces ne devient pas une élite")
	var gd = main.spawn_enemy_kind("gardien", at + Vector2(0, -800), 1.0)
	check(not "ecorce" in gd.allowed_affixes(), "un Gardien d'écorce n'a pas de bouclier d'écorce en plus")
	nest.queue_free()
	gd.queue_free()
	var sp: float = e.speed
	e.take_damage(e.max_hp * 0.6, false)
	await _steps(1)
	check(e.enraged and e.speed > sp, "enragé : sous la moitié de sa vie, il accélère")

	var s = main.spawn_enemy_kind("fletri", at + Vector2(-500, 0), 1.0)
	s.make_elite(["ecorce"])
	var shp: float = s.hp
	s.take_damage(s.max_shield * 0.5, false)
	check(is_equal_approx(s.hp, shp), "cuirassé d'écorce : le bouclier absorbe d'abord les coups")
	s.take_damage(s.max_shield, false)
	check(s.shield <= 0.0 and s.hp < shp, "puis la vie prend le reste")
	s.shield_wait = 0.0
	await _steps(30)
	check(s.shield > 0.0, "le bouclier se reforme après un temps sans coup")

	var sh = main.spawn_enemy_kind("fletri", at + Vector2(0, 300), 1.0)
	sh.make_elite(["epines"])
	sh.aff_cd["epines"] = 0.0
	before = main.projectiles_layer.get_child_count()
	await _steps(int(main.Enemy.ELITES["affixes"]["epines"]["windup"] * 60) + 4)
	check(main.projectiles_layer.get_child_count() - before >= int(main.Enemy.ELITES["affixes"]["epines"]["count"]), "épineux : une couronne d'épines part tout autour, après une annonce")

	var inv = main.spawn_enemy_kind("cendreux", at + Vector2(0, -300), 1.0)
	inv.make_elite(["invocateur"])
	inv.aff_cd["invocateur"] = 0.0
	inv.anchored = true
	await _steps(int(main.Enemy.ELITES["affixes"]["invocateur"]["windup"] * 60) + 4)
	check(inv.young.size() == int(main.Enemy.ELITES["affixes"]["invocateur"]["count"]), "invocateur : il fait naître des Cendreux (%d)" % inv.young.size())
	check(inv.young.all(func(y): return not y.elite), "… qui ne sont pas des élites")

	print("Élite vaincue")
	var got := []
	main.elite_killed.connect(func(x): got.append(x))
	var orbs0: int = main.orbs_layer.get_child_count()
	sh.take_damage(sh.hp + sh.shield + 1.0, false)
	await _steps(2)
	check(got.size() == 1 and got[0] == sh, "main.elite_killed est émis avec l'élite")
	check(main.orbs_layer.get_child_count() - orbs0 >= 6, "elle laisse une gerbe d'essences")
	var plain = main.spawn_enemy_kind("fletri", at + Vector2(200, 200), 1.0)
	plain.take_damage(plain.hp + 1.0, false)
	await _steps(2)
	check(got.size() == 1, "un ennemi ordinaire n'émet rien")

	print("Tirage des élites")
	await _clear()
	game.level = 1
	var elites := 0
	for i in 300:
		var x = main.spawn_enemy_kind("fletri", at + Vector2(i, 900), 1.0)
		main._roll_elite(x, x.position)
		elites += 1 if x.elite else 0
	check(elites == 0, "pas d'élite avant le niveau %d" % main.Enemy.ELITES["min_level"])
	await _clear()
	game.level = 15
	var max_alive: int = main.Enemy.ELITES["max_alive"]
	for i in 3000:
		var x = main.spawn_enemy_kind("fletri", at + Vector2(i % 400, 900), 1.0)
		main._roll_elite(x, x.position)
		if not x.elite:
			x.queue_free()
			main.enemies.erase(x)
	elites = main.enemies.filter(func(x): return x.elite).size()
	check(elites >= 1 and elites <= max_alive, "des élites apparaissent, mais peu à la fois (%d)" % elites)
	var multi: int = main.enemies.filter(func(x): return x.affixes.size() == 2).size()
	print("  info élites : %d, dont %d à deux modificateurs" % [elites, multi])

	main.queue_free()
	await process_frame
	print("Ennemis variés et élites : %s" % ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
