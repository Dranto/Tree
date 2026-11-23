## Test de la région de Racine (jalon 9, tâche E) : géométrie et décor de la forêt pétrifiée, les
## quatre Flétris de la forêt (Termite de cendre, Mandragore, Scarabée perce-écorce, Tertre de
## pierre), le perce-armure, le Cœur des cernes, puis l'Ancien pétrifié (attaques, pieu qui perce
## l'armure, chute, invocation, clairière qui se resserre, victoire) et la sauvegarde de ses drapeaux.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/foret_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
## Chargés au lancement (load) : ils citent des autoloads, inconnus quand ce script est compilé.
var Enemy
var Foret

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
	Foret = load("res://scripts/decor_foret.gd")
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
	check("racine" in Regions.ids(), "la région de Racine est chargée (data/regions/racine.json)")
	check(Regions.def("racine").get("place", "") == "la forêt pétrifiée", "c'est la vraie région, la forêt pétrifiée")
	var c := Regions.center("racine")
	check(main.region_at(c) == "racine" and main.region_at(Regions.center("aube")) == "aube" and main.region_at(Regions.center("ronce")) == "ronce", "region_at distingue la forêt de ses voisines (Aube, Ronce)")
	check(absf(angle_difference(c.angle(), Regions.angle_of("racine"))) < 0.01, "la forêt est dans le secteur de la branche Racine")
	var ar: Dictionary = Regions.section("racine", "boss")["arena"]
	check(float(ar["offset"]) + float(ar["radius"]) <= 1640.0, "la clairière de l'Ancien tient dans le monde (offset + rayon ≤ 1640)")
	check(Regions.art("racine").resource_path.ends_with("region_art/racine.gd"), "Cœur et arène dessinés par region_art/racine.gd")
	var counts := {"root": 0, "stump": 0, "scree": 0, "tree": 0}
	for t in main.flora.trees:
		if main.region_at(t.position) != "racine":
			continue
		if is_instance_of(t, Foret.GiantRoot):
			counts["root"] += 1
		elif is_instance_of(t, Foret.Stump):
			counts["stump"] += 1
		elif is_instance_of(t, Foret.Scree):
			counts["scree"] += 1
		elif is_instance_of(t, Foret.StoneTree):
			counts["tree"] += 1
	check(counts["root"] > 10, "des racines géantes font obstacle (%d)" % counts["root"])
	check(counts["stump"] > 20 and counts["scree"] > 60 and counts["tree"] > 10, "souches (%d), éboulis (%d) et troncs pétrifiés (%d)" % [counts["stump"], counts["scree"], counts["tree"]])
	var rock = null
	var in_clearing := 0
	var arena_c: Vector2 = Regions.arena_center("racine")
	for b in main.flora.bushes:
		if main.region_at(b.position) == "racine":
			if rock == null:
				rock = b
			if b.position.distance_to(arena_c) < float(ar["radius"]):
				in_clearing += 1
	check(rock != null and main.flora.push_out(rock.position, 10.0) != rock.position, "une racine géante repousse ce qui la touche")
	check(in_clearing == 0, "aucune racine dans la clairière de l'Ancien (%d)" % in_clearing)
	check(main.hearts.has("racine") and main.arenas.has("racine"), "un Cœur et une arène pour la région")
	check(main.sanctuary("racine_souche") != null and main.sanctuary("racine_souche").region == "racine", "le sanctuaire de la Souche est posé")
	# Revivre le décor ne doit rien casser (dessin des pousses).
	for t in main.flora.trees:
		if main.region_at(t.position) == "racine" and not t.alive:
			t.revive(true)
	await _steps(30)

	print("Flétris de la forêt")
	p.fire_cd = 1.0e9
	for k in ["termite", "mandragore", "scarabee", "tertre"]:
		check(Enemy.kind_index(k) >= 0, "sorte « %s » dans enemies.json" % k)
	var spot := c + Vector2(0, 420).rotated(Regions.angle_of("racine") - PI / 2.0)
	if main.region_at(spot) != "racine":
		spot = c * 0.85
	# Termite : petit et rapide, il vient au contact ; jamais élite.
	_place(spot)
	p.hp = 100.0
	p.invuln = 0.0
	var mite = main.spawn_enemy_kind("termite", spot + Vector2(200, 0), 1.0)
	check(not mite.can_be_elite(), "un Termite ne devient jamais élite (ils viennent en nombre)")
	check(await _until(func(): return p.hp < 100.0, 240), "le Termite court au joueur et le mord")
	mite.queue_free()
	await _steps(2)
	_clear()
	# Mandragore : elle s'enfonce, file sous terre (intouchable, inoffensive), marque son cercle sous
	# le joueur, jaillit, puis reste sonnée.
	_place(spot)
	p.hp = 1.0e6
	p.set_physics_process(false)
	var mand = main.spawn_enemy_kind("mandragore", spot + Vector2(300, 0), 1.0)
	mand.cd = 0.0
	check(await _until(func(): return mand.state == "sous", 120), "la Mandragore s'enfonce sous terre")
	var hp_m: float = mand.hp
	main.player_hit_enemy(mand, 10.0, false)
	check(mand.hp == hp_m, "sous terre, les coups directs ne l'atteignent pas")
	check(mand.pose().get("under", 0.0) > 0.0, "on ne voit qu'un sillon (pose « under »)")
	check(mand.hidden() and p.auto_target() != mand, "le tir automatique ne vise pas une Mandragore sous terre")
	check(await _until(func(): return mand.state == "windup", 180), "elle s'arrête sous le joueur et marque son cercle")
	check(mand.position.distance_to(p.position) < 30.0, "le cercle est sous le joueur (%d px, joueur à %s, ennemi à %s, visé %s)" % [int(mand.position.distance_to(p.position)), p.position, mand.position, spot])
	var hp2: float = p.hp
	p.invuln = 0.0
	check(await _until(func(): return mand.state == "recover", 120), "elle jaillit")
	check(p.hp < hp2, "le joueur resté dans le cercle est blessé")
	main.player_hit_enemy(mand, 10.0, false)
	check(mand.hp < hp_m, "sonnée à découvert, elle prend les coups")
	p.set_physics_process(true)
	mand.queue_free()
	await _steps(2)
	_clear()
	# Scarabée perce-écorce : il charge, et ses coups ignorent une part de l'armure.
	_place(spot)
	var beetle = main.spawn_enemy_kind("scarabee", spot + Vector2(240, 0), 1.0)
	beetle.cd = 0.0
	check(await _until(func(): return beetle.state == "windup", 120) and await _until(func(): return beetle.state == "charge", 120), "le Scarabée annonce sa charge puis fonce")
	beetle.set_physics_process(false)
	var plain = main.spawn_enemy_kind("fletri", spot + Vector2(-400, 0), 1.0)
	plain.set_physics_process(false)
	var armor_before: float = game.stats["armor"]
	game.stats["armor"] = 0.5
	p.hp = 1000.0
	p.invuln = 0.0
	p.take_hit(20.0, plain)
	var lost_plain: float = 1000.0 - p.hp
	p.hp = 1000.0
	p.invuln = 0.0
	p.take_hit(20.0, beetle)
	var lost_beetle: float = 1000.0 - p.hp
	game.stats["armor"] = armor_before
	check(absf(lost_plain - 10.0) < 0.01, "un coup ordinaire perd la moitié contre 50 %% d'armure (%.1f)" % lost_plain)
	check(absf(lost_beetle - 20.0 * (1.0 - 0.5 * (1.0 - beetle.armor_pierce))) < 0.01 and lost_beetle > lost_plain, "le Scarabée perce l'armure (%.1f au lieu de %.1f)" % [lost_beetle, lost_plain])
	beetle.queue_free()
	plain.queue_free()
	await _steps(2)
	_clear()
	# Tertre de pierre : il lève les poings, frappe le sol autour de lui ; rien ne le pousse.
	_place(spot)
	p.hp = 1.0e6
	p.set_physics_process(false)
	var mound = main.spawn_enemy_kind("tertre", spot + Vector2(90, 0), 1.0)
	mound.cd = 0.0
	check(mound.data.get("no_root", false) and mound.data.get("no_push", false), "le Tertre : ni poussé, ni enraciné (no_push, no_root)")
	check(await _until(func(): return mound.state == "windup", 120), "le Tertre lève les poings et marque son cercle")
	var hp3: float = p.hp
	p.invuln = 0.0
	check(await _until(func(): return mound.state == "recover", 120) and p.hp < hp3, "il frappe le sol : le joueur dans le cercle est blessé")
	check(mound.resist.get("racine", 0.0) > 0.0, "les Flétris de la forêt résistent un peu à Racine")
	p.set_physics_process(true)
	mound.queue_free()
	await _steps(2)
	_clear()

	print("Cœur des cernes")
	p.fire_cd = 0.0
	var heart = main.hearts["racine"]
	# Les deux autres Cœurs de la région sont déjà purifiés : le Grand Cœur ouvre l'arène.
	for h in main.region_hearts["racine"]:
		if h != heart:
			game.flags[h.flag] = true
	var arena = main.arenas["racine"]
	check(heart.state == "fletri" and arena.state == "fermee", "Cœur flétri, arène fermée")
	_place(heart.center + Vector2(heart.zone * 0.6, 0))
	await _steps(90)
	check(heart.state == "siege" and heart.spawned.size() > 0, "tenir la zone lance le siège et une vague")
	heart.progress = heart.hold_time - 0.2
	await _steps(30)
	check(heart.state == "purifie" and game.flags.get("racine_coeur_purifie", false) == true, "Cœur purifié, drapeau racine_coeur_purifie")
	check(arena.state == "ouverte", "la clairière de l'Ancien s'ouvre")
	_clear()

	print("L'Ancien pétrifié")
	p.fire_cd = 1.0e9
	_place(arena.center + Vector2(0, 250))
	await _steps(5)
	var boss = arena.boss
	check(arena.state == "combat" and is_instance_valid(boss) and boss.get_script().resource_path.ends_with("boss_racine.gd"), "entrer dans la clairière réveille l'Ancien")
	check(boss.get("no_root") == true, "l'enracinement ne le tient pas (no_root)")
	check(boss in main.enemies_near(boss.position + Vector2(boss.radius + 4.0, 0), 8.0), "enemies_near le trouve")
	_place(arena.center + Vector2(0, 330))
	check(await _until(func(): return boss.attack != "" and boss.stage == "annonce"), "une attaque est annoncée avant de frapper")
	await _until(func(): return boss.attack == "")
	boss.gap = 1.0e9
	# Racines : des couloirs en éventail vers le joueur ; entre deux couloirs, rien.
	var spot2: Vector2 = arena.center + Vector2(0, 220)
	_place(spot2)
	p.hp = 100.0
	p.invuln = 0.0
	p.set_physics_process(false)
	boss._begin("racines")
	check(boss.lines.size() == 3, "trois couloirs de racines en phase 1")
	check(boss.danger_time(spot2) < INF, "le robot voit la menace sous le joueur")
	var between: Vector2 = boss.anchor + Vector2.from_angle(boss.aim.angle() + boss.ROOTS["spread"] * 0.5) * 300.0
	check(boss.danger_time(between, 0.0) == INF, "entre deux couloirs, rien ne menace")
	check(await _until(func(): return boss.attack == "", 200) and p.hp < 100.0, "les racines jaillissent et blessent le joueur")
	# Éboulis : des cercles autour du joueur, le premier sous lui (le coup des racines l'a fait reculer).
	_place(spot2)
	p.hp = 100.0
	p.invuln = 0.0
	boss._begin("eboulis")
	check(boss.circles.size() == 4 and boss.circles[0].distance_to(spot2) < 2.0, "quatre pierres tombent, la première sur le joueur")
	check(await _until(func(): return boss.attack == "", 200) and p.hp < 100.0, "la pierre blesse le joueur resté dessous")
	# Pieu : il perce l'armure.
	var armor_b: float = game.stats["armor"]
	game.stats["armor"] = 0.6
	p.hp = 1000.0
	p.invuln = 0.0
	boss._begin("pieu")
	check(await _until(func(): return boss.attack == "", 200), "le pieu est planté")
	var lost: float = 1000.0 - p.hp
	var full: float = boss.STAKE["damage"] * boss.damage_scale
	check(lost > full * (1.0 - 0.6) + 0.5, "le pieu perce l'armure (%.1f perdus, %.1f sans perçage)" % [lost, full * 0.4])
	check(boss.armor_pierce == 0.0, "le perçage ne vaut que pour le pieu")
	game.stats["armor"] = armor_b
	p.set_physics_process(true)
	# Phase 2 : chute et invocation de Termites.
	boss.hp = boss.max_hp * 0.55
	check(await _until(func(): return boss.phase == 2), "sous 66 % de vie : phase 2")
	await _until(func(): return boss.transition <= 0.0)
	boss.gap = 1.0e9
	_place(arena.center + Vector2(120, 150))
	p.hp = 100.0
	p.invuln = 0.0
	p.set_physics_process(false)
	boss._begin("chute")
	check(boss.circles.size() == 1 and boss.danger_time(p.position) < INF, "un pan de cime va tomber sous le joueur (annoncé)")
	check(await _until(func(): return boss.attack == "", 200) and p.hp < 100.0, "la chute écrase le joueur resté dessous")
	p.set_physics_process(true)
	var before_minions: int = boss.minions.size()
	boss._begin("invocation")
	check(await _until(func(): return boss.attack == "", 200) and boss.minions.size() > before_minions, "des Termites sortent de la roche")
	check(boss.minions.all(func(m): return not is_instance_valid(m) or m.kind_id == "termite"), "ce sont des Termites de cendre")
	_clear()
	boss.minions = []
	# Phase 3 : la forêt se referme ; des Mandragores.
	boss.hp = boss.max_hp * 0.25
	check(await _until(func(): return boss.phase == 3), "sous 33 % de vie : phase 3")
	await _steps(120)
	check(arena.radius < arena.max_radius, "la forêt se referme : l'arène se resserre")
	boss.gap = 1.0e9
	boss._begin("racines")
	check(boss.lines.size() == 5, "cinq couloirs de racines en phase 3")
	await _until(func(): return boss.attack == "", 200)
	boss._begin("invocation")
	await _until(func(): return boss.attack == "", 200)
	check(not boss.minions.is_empty() and boss.minions.all(func(m): return not is_instance_valid(m) or m.kind_id == "scarabee"), "en phase 3, des Scarabées")

	print("Victoire")
	_clear()
	boss.minions = []
	var points: int = game.points
	boss.take_damage(boss.max_hp + 1.0, false)
	check(boss.dead and game.flags.get("racine_boss_vaincu", false) == true, "Ancien vaincu : drapeau racine_boss_vaincu")
	check(game.points == points + 2, "2 points d'arbre gagnés")
	check(arena.state == "vaincue" and not main.spawn_paused, "la clairière reverdit, les naissances reprennent")
	await _steps(150)
	check(not is_instance_valid(boss), "l'Ancien a disparu")

	print("Sauvegarde")
	var data: Dictionary = JSON.parse_string(JSON.stringify(save.capture(main)))
	game.reset()
	check(not game.flags.has("racine_coeur_purifie") and not game.flags.has("racine_boss_vaincu"), "nouvelle partie : drapeaux effacés")
	save.apply(data, main)
	await _steps(3)
	check(game.flags.get("racine_coeur_purifie", false) == true and game.flags.get("racine_boss_vaincu", false) == true, "les drapeaux de Racine sont sauvegardés et rechargés")

	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
