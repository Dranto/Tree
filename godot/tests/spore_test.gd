## Test de la région de Spore (jalon 7, tâche C) : géométrie, décor du marais (troncs pourris en
## obstacles, flaques au sol), apparitions, résistances, et chaque Flétri du marais : la flaque du
## Traîne-vase, la division du Scissipore, la croûte et la frappe du Lichen cuirassé.
## Le boss : tests/boss_test.gd -- --region=spore.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/spore_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Puddles = preload("res://scripts/marsh_puddles.gd")

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
	main.enemies = []


func _run() -> void:
	game = root.get_node("Game")
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _steps(2)
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	var p = main.player
	# Les Cœurs ne font naître personne pendant le test.
	for h in main.hearts.values():
		h.set_physics_process(false)

	print("Géométrie et décor")
	check(Regions.exists("spore") and Regions.branch_of("spore") == "spore", "la région de Spore existe, sur la branche Spore")
	var c: Vector2 = main.region_center("spore")
	check(main.region_at(c) == "spore", "le centre de la région est dans le marais")
	var arena = main.arenas["spore"]
	check(arena.center.x + arena.max_radius < main.WORLD_HALF, "l'arène tient dans le monde")
	var logs := 0
	var pools := 0
	var ok_logs := true
	for t in main.flora.trees:
		if "radius" in t and t.get_parent() == main.flora.trees_parent and Regions.weight(t.position, "spore") > 0.5 and t in main.flora.bushes:
			logs += 1
			ok_logs = ok_logs and t.position.distance_to(c) >= 340.0
		elif t.get_parent() == main.flora:
			pools += 1
	check(logs > 5 and ok_logs, "des troncs pourris font obstacle, hors du centre (%d)" % logs)
	check(pools > 5, "des flaques au sol, sous les personnages (%d)" % pools)
	check(main.sanctuary("berge") != null, "le sanctuaire de la Berge est posé")

	print("Apparitions")
	var dir := Vector2.from_angle(Regions.angle_of("spore"))
	var seen := {}
	for i in 400:
		var k: String = main._region_kind("spore", dir * 2400.0)
		if k != "":
			seen[k] = true
	check(seen.has("traine_vase") and seen.has("scissipore") and seen.has("lichen"), "les trois sortes du marais apparaissent (%s)" % str(seen.keys()))
	check(not seen.has("sporule"), "les Sporules ne naissent que d'un Scissipore")

	print("Résistances")
	# Loin du Cœur (au-delà de son réveil) : il ne fait naître personne pendant le test.
	var spot: Vector2 = c * 0.5
	p.position = spot
	var li = main.spawn_enemy_kind("lichen", spot + Vector2(600, 0), 1.0)
	var tv = main.spawn_enemy_kind("traine_vase", spot + Vector2(-600, 0), 1.0)
	check(is_equal_approx(main.branch_factor(li, "spore"), 0.5), "le Lichen cuirassé ignore la moitié des coups de Spore")
	check(is_equal_approx(main.branch_factor(tv, "spore"), 0.75), "le Traîne-vase ignore 25 % des coups de Spore")
	check(is_equal_approx(main.branch_factor(li, "ronce"), 1.0), "aucune résistance aux autres branches")
	li.apply_poison(20.0, 3.0)
	tv.apply_poison(20.0, 3.0)
	check(is_equal_approx(li.poison_dps, 5.0) and is_equal_approx(tv.poison_dps, 20.0), "la croûte boit 75 % du poison")
	_clear()
	await _steps(1)

	print("Traîne-vase")
	p.hp = 1.0e6
	tv = main.spawn_enemy_kind("traine_vase", spot + Vector2(120, 0), 1.0)
	tv.cd = 0.0
	await _steps(3)
	check(tv.state == "windup", "il se ramasse avant de répandre sa vase (annonce)")
	await _steps(40)
	var field = Puddles.of(main)
	check(field.puddles.size() == 1, "puis une flaque reste derrière lui")
	check(field.get_index() < main.actors_layer.get_index(), "les flaques sont au sol, sous les personnages")
	var at: Vector2 = field.puddles[0]["pos"]
	tv.queue_free()
	main.enemies.erase(tv)
	await _steps(20)
	p.position = at
	p.invuln = 0.0
	var hp: float = p.hp
	await _steps(40)
	check(p.hp < hp, "s'y tenir blesse le Porte-Graine")
	check(field.hurts_at(at), "la flaque blesse tant qu'elle dure")
	await _steps(400)
	check(field.puddles.is_empty(), "puis elle sèche (%s)" % str(field.puddles))
	for i in 6:
		field.add(null, spot, 40.0, 5.0, 1.0, 99)
	tv = main.spawn_enemy_kind("traine_vase", spot, 1.0)
	for i in 6:
		field.add(tv, spot, 40.0, 5.0, 1.0, 4)
	check(field.puddles.filter(func(x): return x["owner"] == tv.get_instance_id()).size() == 4, "au plus quatre flaques par Traîne-vase")
	field.puddles = []
	_clear()
	await _steps(1)

	print("Scissipore")
	p.position = spot
	var sc = main.spawn_enemy_kind("scissipore", spot + Vector2(60, 0), 1.0)
	sc.cd = 0.0
	await _steps(2)
	check(sc.state == "windup", "au contact, il gonfle (annonce)")
	p.invuln = 0.0
	hp = p.hp
	await _steps(50)
	check(p.hp < hp, "puis sa bouffée blesse qui est resté dans le cercle")
	var n_before: int = main.enemies.size()
	sc.take_damage(sc.hp + 1.0, false)
	await _steps(3)
	var young: Array = main.enemies.filter(func(e): return is_instance_valid(e) and e.kind_id == "sporule")
	check(young.size() == 2, "à sa mort, il se divise en deux Sporules")
	check(not young.is_empty() and not young[0].can_be_elite(), "une Sporule ne devient jamais une élite")
	young[0].take_damage(999.0, false)
	await _steps(3)
	check(main.enemies.filter(func(e): return is_instance_valid(e) and e.kind_id == "sporule").size() == 1, "une Sporule ne se divise pas")
	_clear()
	await _steps(1)

	print("Lichen cuirassé")
	p.position = spot
	li = main.spawn_enemy_kind("lichen", spot + Vector2(80, 0), 1.0)
	li.cd = 0.0
	await _steps(2)
	check(li.state == "windup", "il se dresse avant de frapper (annonce)")
	p.position = spot + Vector2(-300, 0)
	li.position = spot + Vector2(80, 0)
	p.invuln = 0.0
	hp = p.hp
	await _steps(70)
	check(p.hp == hp, "reculer hors du cercle annoncé évite le coup")
	_clear()

	print("Purification")
	game.flags["spore_coeur_purifie"] = true
	var n := 0
	for i in 400:
		if main._region_kind("spore", dir * 2400.0) != "":
			n += 1
	game.flags.erase("spore_coeur_purifie")
	check(n < 200, "le Cœur purifié, le marais fait naître moins des siens (%d / 400)" % n)

	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
