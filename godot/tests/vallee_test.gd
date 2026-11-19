## Test de la région de Sève (jalon 8, tâche E) : géométrie et décor de la vallée des sources, les
## quatre Flétris de la vallée (Sangsue de vase, Crapaud des sources, Libellule de cendre, Souche
## gorgée), le Cœur des sources, puis le Saule exsangue (attaques, vie reprise, siphon, invocation,
## étang qui se resserre, victoire) et la sauvegarde de ses drapeaux.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/vallee_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
## Chargés au lancement (load) : ils citent des autoloads, inconnus quand ce script est compilé.
var Enemy
var Vallee

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


func _until(cond: Callable, limit := 900) -> bool:
	for i in limit:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _place(pos: Vector2) -> void:
	main.player.position = pos
	main.player.hp = 1.0e6


func _clear() -> void:
	for e in main.enemies:
		if is_instance_valid(e) and not e.get("behavior") == "boss":
			e.queue_free()
	main.enemies = main.enemies.filter(func(e): return is_instance_valid(e) and e.get("behavior") == "boss")


func _run() -> void:
	game = root.get_node("Game")
	Enemy = load("res://scripts/enemy.gd")
	Vallee = load("res://scripts/decor_vallee.gd")
	var save = root.get_node("SaveGame")
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true      # ni sauvegarde lue ni écrite
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _steps(2)
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.autosave_enabled = false
	var p = main.player

	print("Géométrie et décor")
	check("seve" in Regions.ids(), "la région de Sève est chargée (data/regions/seve.json)")
	check(Regions.def("seve").get("name", "").find("factice") < 0, "c'est la vraie région, pas la région factice des tests")
	var c := Regions.center("seve")
	check(main.region_at(c) == "seve" and main.region_at(Regions.center("vent")) == "vent" and main.region_at(Regions.center("spore")) == "spore", "region_at distingue la vallée de ses voisines")
	check(absf(angle_difference(c.angle(), Regions.angle_of("seve"))) < 0.01, "la vallée est dans le secteur de la branche Sève")
	var ar: Dictionary = Regions.section("seve", "boss")["arena"]
	check(float(ar["offset"]) + float(ar["radius"]) <= 1640.0, "l'étang du Saule tient dans le monde (offset + rayon ≤ 1640)")
	check(Regions.art("seve").resource_path.ends_with("region_art/seve.gd"), "Cœur et arène dessinés par region_art/seve.gd")
	var counts := {"rock": 0, "spring": 0, "fern": 0, "willow": 0}
	for t in main.flora.trees:
		if main.region_at(t.position) != "seve":
			continue
		if is_instance_of(t, Vallee.MossRock):
			counts["rock"] += 1
		elif is_instance_of(t, Vallee.Spring):
			counts["spring"] += 1
		elif is_instance_of(t, Vallee.Fern):
			counts["fern"] += 1
		elif is_instance_of(t, Vallee.Willow):
			counts["willow"] += 1
	check(counts["rock"] > 12, "des blocs moussus font obstacle (%d)" % counts["rock"])
	check(counts["spring"] > 15 and counts["fern"] > 60 and counts["willow"] > 10, "sources (%d), fougères (%d) et saules (%d)" % [counts["spring"], counts["fern"], counts["willow"]])
	var rock = null
	var in_pond := 0
	var arena_c: Vector2 = Regions.arena_center("seve")
	for b in main.flora.bushes:
		if main.region_at(b.position) == "seve":
			if rock == null:
				rock = b
			if b.position.distance_to(arena_c) < float(ar["radius"]):
				in_pond += 1
	check(rock != null and main.flora.push_out(rock.position, 10.0) != rock.position, "un bloc repousse ce qui le touche")
	check(in_pond == 0, "aucun bloc dans l'étang du Saule (%d)" % in_pond)
	check(main.hearts.has("seve") and main.arenas.has("seve"), "un Cœur et une arène pour la région")
	check(main.sanctuary("seve_source") != null and main.sanctuary("seve_source").region == "seve", "le sanctuaire de la Source est posé")

	print("Flétris de la vallée")
	p.fire_cd = 1.0e9
	for k in ["sangsue_vase", "crapaud", "libellule", "souche"]:
		check(Enemy.kind_index(k) >= 0, "sorte « %s » dans enemies.json" % k)
	var spot := c + Vector2(0, -420)
	if main.region_at(spot) != "seve":
		spot = c * 0.85
	# Sangsue de vase : elle se jette sur le joueur et boit la vie qu'elle lui prend.
	_place(spot)
	p.hp = 100.0
	p.invuln = 0.0
	var leech = main.spawn_enemy_kind("sangsue_vase", spot + Vector2(150, 0), 1.0)
	leech.cd = 0.0
	leech.hp = leech.max_hp * 0.4
	var l_hp: float = leech.hp
	check(await _until(func(): return leech.state == "windup", 120), "la Sangsue annonce son bond (couloir au sol)")
	check(await _until(func(): return leech.state == "charge", 120), "puis elle se jette sur le joueur")
	check(await _until(func(): return p.hp < 100.0, 120), "elle le mord")
	check(leech.hp > l_hp, "et reprend de la vie en buvant (%d → %d)" % [int(l_hp), int(leech.hp)])
	check(leech.pose().has("gorged"), "gorgée, elle enfle (pose « gorged »)")
	leech.queue_free()
	await _steps(2)
	_clear()
	# Crapaud des sources : il marque le point de chute, bondit et retombe dans une gerbe d'eau.
	_place(spot)
	p.hp = 1.0e6
	p.set_physics_process(false)
	var toad = main.spawn_enemy_kind("crapaud", spot + Vector2(260, 0), 1.0)
	toad.cd = 0.0
	check(await _until(func(): return toad.state == "windup", 120), "le Crapaud se ramasse et marque son point de chute")
	var landing: Vector2 = toad.get_meta("cible")
	check(landing.distance_to(spot) < 2.0, "le point de chute est la place du joueur")
	check(await _until(func(): return toad.state == "leap", 120) and toad.pose().get("lift", -1.0) >= 0.0, "il bondit (pose « lift »)")
	var hp1: float = p.hp
	p.invuln = 0.0
	check(await _until(func(): return toad.state == "recover", 120), "il retombe")
	check(toad.position.distance_to(landing) < 30.0 and p.hp < hp1, "là où il l'a marqué, et la gerbe blesse le joueur resté dedans")
	p.set_physics_process(true)
	toad.queue_free()
	await _steps(2)
	_clear()
	# Libellule de cendre : elle tourne, puis fond en piqué (comportement « diver »).
	_place(spot)
	var fly = main.spawn_enemy_kind("libellule", spot + Vector2(280, 0), 1.0)
	fly.cd = 0.0
	check(await _until(func(): return fly.state == "windup", 120) and await _until(func(): return fly.state == "charge", 120), "la Libellule annonce son piqué puis fond sur le joueur")
	fly.queue_free()
	await _steps(2)
	_clear()
	# Souche gorgée : elle soigne les Flétris blessés autour d'elle.
	_place(spot + Vector2(-600, 0))
	var stump = main.spawn_enemy_kind("souche", spot + Vector2(200, 0), 1.0)
	var hurt = main.spawn_enemy_kind("fletri", spot + Vector2(260, 40), 1.0)
	hurt.set_physics_process(false)
	hurt.hp = hurt.max_hp * 0.3
	var h_hp: float = hurt.hp
	stump.cd = 0.0
	check(await _until(func(): return stump.state == "windup", 120), "la Souche se gonfle de sève (cercle vert, pas rouge)")
	check(await _until(func(): return hurt.hp > h_hp, 200), "puis soigne le Flétri blessé à côté d'elle (%d → %d)" % [int(h_hp), int(hurt.hp)])
	check(stump.resist.get("seve", 0.0) > 0.0, "les Flétris de la vallée résistent un peu à Sève")
	stump.queue_free()
	hurt.queue_free()
	await _steps(2)
	_clear()

	print("Cœur des sources")
	p.fire_cd = 0.0
	var heart = main.hearts["seve"]
	var arena = main.arenas["seve"]
	check(heart.state == "fletri" and arena.state == "fermee", "Cœur flétri, arène fermée")
	_place(heart.center + Vector2(heart.zone * 0.6, 0))
	await _steps(90)
	check(heart.state == "siege" and heart.spawned.size() > 0, "tenir la zone lance le siège et une vague")
	heart.progress = heart.hold_time - 0.2
	await _steps(30)
	check(heart.state == "purifie" and game.flags.get("seve_coeur_purifie", false) == true, "Cœur purifié, drapeau seve_coeur_purifie")
	check(arena.state == "ouverte", "l'étang du Saule s'ouvre")
	_clear()

	print("Le Saule exsangue")
	p.fire_cd = 1.0e9
	_place(arena.center + Vector2(0, 250))
	await _steps(5)
	var boss = arena.boss
	check(arena.state == "combat" and is_instance_valid(boss) and boss.get_script().resource_path.ends_with("boss_seve.gd"), "entrer dans l'étang réveille le Saule")
	check(boss in main.enemies_near(boss.position + Vector2(boss.radius + 4.0, 0), 8.0), "enemies_near le trouve")
	_place(arena.center + Vector2(0, 330))
	check(await _until(func(): return boss.attack != "" and boss.stage == "annonce"), "une attaque est annoncée avant de frapper")
	await _until(func(): return boss.attack == "")
	# Racines : elles frappent sous le joueur, et le Saule boit ce qu'il prend.
	boss.gap = 1.0e9
	var spot2: Vector2 = arena.center + Vector2(160, 160)
	_place(spot2)
	p.hp = 100.0
	p.invuln = 0.0
	p.set_physics_process(false)
	boss.hp = boss.max_hp * 0.8
	var bhp: float = boss.hp
	boss._begin("racines")
	check(boss.roots.size() == 3 and boss.roots[0].distance_to(spot2) < 2.0, "trois cercles de racines, le premier sous le joueur")
	check(boss.danger_time(spot2) < INF, "le robot voit la menace")
	check(await _until(func(): return boss.attack == "", 200), "les racines jaillissent")
	check(p.hp < 100.0 and boss.hp > bhp, "elles blessent le joueur, et le Saule reprend de la vie (%d → %d)" % [int(bhp), int(boss.hp)])
	p.set_physics_process(true)
	# Rideau : un cône devant lui ; derrière, rien.
	p.hp = 100.0
	p.invuln = 0.0
	_place(arena.center + Vector2(0, 200))
	p.hp = 100.0
	p.set_physics_process(false)
	boss._begin("rideau")
	check(boss._in_curtain(p.position, 0.0) and not boss._in_curtain(arena.center + Vector2(0, -200), 0.0), "le rideau balaie vers le joueur, pas derrière le Saule")
	check(await _until(func(): return boss.attack == "", 200) and p.hp < 100.0, "le rideau frappe le joueur pris dans le cône")
	p.set_physics_process(true)
	# Graines : des salves qui volent vers le joueur.
	boss._begin("graines")
	check(await _until(func(): return not boss.seeds.is_empty(), 200), "la salve de graines part")
	await _until(func(): return boss.attack == "", 300)
	# Phase 2 : siphon et invocation.
	boss.hp = boss.max_hp * 0.55
	check(await _until(func(): return boss.phase == 2), "sous 66 % de vie : phase 2")
	await _until(func(): return boss.transition <= 0.0)
	boss.gap = 1.0e9
	_place(arena.center + Vector2(0, 150))
	p.hp = 100.0
	p.invuln = 0.0
	p.set_physics_process(false)
	boss._begin("siphon")
	check(boss.danger_time(p.position) < INF and boss.bot_ring(arena.radius) > boss.SIPHON["radius"], "le siphon s'annonce ; le robot tourne hors de son cercle")
	check(await _until(func(): return boss.stage == "frappe", 200), "le siphon boit")
	check(await _until(func(): return p.hp < 100.0, 120), "le joueur resté dans le cercle perd de la vie")
	p.set_physics_process(true)
	await _until(func(): return boss.attack == "", 300)
	var before_minions: int = boss.minions.size()
	boss._begin("invocation")
	check(await _until(func(): return boss.attack == "", 200) and boss.minions.size() > before_minions, "des Sangsues sortent de l'étang")
	check(boss.minions.all(func(m): return not is_instance_valid(m) or m.kind_id == "sangsue_vase"), "ce sont des Sangsues de vase")
	_clear()
	boss.minions = []
	# Phase 3 : l'étang se resserre.
	boss.hp = boss.max_hp * 0.25
	check(await _until(func(): return boss.phase == 3), "sous 33 % de vie : phase 3")
	await _steps(120)
	check(arena.radius < arena.max_radius, "l'étang se vide : l'arène se resserre")
	boss.gap = 1.0e9
	boss._begin("racines")
	check(boss.roots.size() == 5, "cinq cercles de racines en phase 3")
	await _until(func(): return boss.attack == "", 200)

	print("Victoire")
	_clear()
	var points: int = game.points
	boss.take_damage(boss.max_hp + 1.0, false)
	check(boss.dead and game.flags.get("seve_boss_vaincu", false) == true, "Saule vaincu : drapeau seve_boss_vaincu")
	check(game.points == points + 2, "2 points d'arbre gagnés")
	check(arena.state == "vaincue" and not main.spawn_paused, "l'étang refleurit, les naissances reprennent")
	await _steps(150)
	check(not is_instance_valid(boss), "le Saule a disparu")

	print("Sauvegarde")
	var data: Dictionary = JSON.parse_string(JSON.stringify(save.capture(main)))
	game.reset()
	check(not game.flags.has("seve_coeur_purifie") and not game.flags.has("seve_boss_vaincu"), "nouvelle partie : drapeaux effacés")
	save.apply(data, main)
	await _steps(3)
	check(game.flags.get("seve_coeur_purifie", false) == true and game.flags.get("seve_boss_vaincu", false) == true, "les drapeaux de Sève sont sauvegardés et rechargés")

	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
