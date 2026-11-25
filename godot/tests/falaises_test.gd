## Test de la région d'Aube (jalon 8, tâche G) : géométrie et décor des falaises de verre, les
## quatre Flétris des falaises (Luciole, Miroitier et son éblouissement, Prismeur, Colosse de
## quartz et ses éclats), une élite, le Cœur de l'aurore, puis la Phalène de verre (écailles,
## éclair, rayons, nuée, pluie de lumière, victoire) et la sauvegarde de ses drapeaux.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/falaises_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
## Chargés au lancement (load) : ils citent des autoloads, inconnus quand ce script est compilé.
var Enemy
var Falaise

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
	for n in main.projectiles_layer.get_children():
		if n.get_script() != null and n.get_script().resource_path.ends_with("enemy_thorn.gd"):
			n.queue_free()


func _thorns(look: String) -> Array:
	return main.projectiles_layer.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("enemy_thorn.gd") and n.look == look)


func _run() -> void:
	game = root.get_node("Game")
	Enemy = load("res://scripts/enemy.gd")
	Falaise = load("res://scripts/decor_falaise.gd")
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
	check("aube" in Regions.ids() and Regions.def("aube").get("_path", "").begins_with("res://data/"), "la région d'Aube est chargée (data/regions/aube.json, pas la factice)")
	var c := Regions.center("aube")
	check(main.region_at(c) == "aube" and main.region_at(Regions.center("ronce")) == "ronce", "region_at distingue les falaises et le roncier")
	check(absf(angle_difference(c.angle(), Regions.angle_of("aube"))) < 0.01, "les falaises sont dans le secteur de la branche Aube (ouest)")
	var ar: Dictionary = Regions.section("aube", "boss")["arena"]
	check(float(ar["offset"]) + float(ar["radius"]) <= 1190.0, "secteur peu profond : arène en offset + rayon ≤ 1190 (%d)" % int(float(ar["offset"]) + float(ar["radius"])))
	check(Regions.validate().is_empty(), "check_data accepte la région %s" % [Regions.validate()])
	var crystals := 0
	var cliffs := 0
	var shards := 0
	var trees := 0
	for t in main.flora.trees:
		if main.region_at(t.position) != "aube":
			continue
		if is_instance_of(t, Falaise.Crystals):
			crystals += 1
		elif is_instance_of(t, Falaise.Cliff):
			cliffs += 1
		elif is_instance_of(t, Falaise.Shards):
			shards += 1
		elif is_instance_of(t, Falaise.Bleached):
			trees += 1
	check(crystals > 20 and cliffs > 5, "des cristaux (%d) et des blocs de falaise (%d) font obstacle" % [crystals, cliffs])
	check(shards > 60 and trees > 5, "éclats de verre au sol (%d) et arbres blanchis (%d)" % [shards, trees])
	var solid = null
	for b in main.flora.bushes:
		if main.region_at(b.position) == "aube":
			solid = b
			break
	check(solid != null and main.flora.push_out(solid.position, 10.0) != solid.position, "un cristal repousse ce qui le touche")
	var arena_free := true
	for b in main.flora.bushes:
		if b.position.distance_to(Regions.arena_center("aube")) < float(ar["radius"]) + 40.0:
			arena_free = false
	check(arena_free, "aucun obstacle dans l'arène de la Phalène")
	check(main.hearts.has("aube") and main.arenas.has("aube"), "un Cœur et une arène pour la région")
	check(main.sanctuary("aube_seuil") != null and main.sanctuary("aube_seuil").region == "aube", "le sanctuaire du Seuil est posé")
	check(Regions.art("aube").resource_path.ends_with("region_art/aube.gd"), "Cœur et arène dessinés par region_art/aube.gd")

	print("Flétris des falaises")
	p.fire_cd = 1.0e9
	for k in ["luciole", "miroitier", "prismeur", "quartz"]:
		check(Enemy.kind_index(k) >= 0, "sorte « %s » dans enemies.json" % k)
		check(float(Enemy.KINDS[Enemy.kind_index(k)].get("resist", {}).get("aube", 0.0)) > 0.0, "%s résiste aux coups d'Aube" % k)
	var spot := c + Vector2(0, -420)
	# Luciole : elle fond sur le joueur en zigzaguant.
	_place(spot)
	var bug = main.spawn_enemy_kind("luciole", spot + Vector2(300, 0), 1.0)
	var d0: float = bug.position.distance_to(p.position)
	await _steps(60)
	check(bug.position.distance_to(p.position) < d0 - 80.0, "la Luciole fond sur le joueur")
	check(not bug.can_be_elite(), "la Luciole n'est jamais une élite (trop petite)")
	_clear()
	await _steps(2)
	# Miroitier : il annonce un cône, puis l'éclair blesse et éblouit.
	_place(spot)
	p.invuln = 0.0
	p.set_physics_process(false)
	var mirror = main.spawn_enemy_kind("miroitier", spot + Vector2(200, 0), 1.0)
	mirror.cd = 0.0
	check(await _until(func(): return mirror.state == "windup", 120), "le Miroitier annonce son éclair (cône au sol)")
	var hp0: float = p.hp
	check(await _until(func():
		p.invuln = 0.0
		return mirror.state == "recover", 120), "puis il jette l'éclair")
	check(p.hp < hp0 and p.dazzle > 1.0, "le joueur pris dans le cône est blessé et ébloui (%.1f s)" % p.dazzle)
	p.set_physics_process(true)
	await _steps(30)
	check(p.dazzle < 1.6 and p.dazzle > 0.0, "l'éblouissement passe avec le temps")
	check(p.DAZZLE_SLOW < 1.0, "ébloui, il marche moins vite (× %.2f)" % p.DAZZLE_SLOW)
	p.dazzle = 0.0
	mirror.queue_free()
	await _steps(2)
	_clear()
	# Prismeur : il vise (couloir au sol) puis tire un rayon instantané.
	_place(spot)
	p.invuln = 0.0
	p.set_physics_process(false)
	var prism = main.spawn_enemy_kind("prismeur", spot + Vector2(380, 0), 1.0)
	prism.cd = 0.0
	check(await _until(func(): return prism.state == "windup", 120), "le Prismeur annonce son rayon (couloir au sol)")
	hp0 = p.hp
	check(await _until(func():
		p.invuln = 0.0
		return prism.state == "recover", 120), "puis le rayon part")
	check(p.hp < hp0, "le rayon blesse le joueur dans le couloir")
	# Hors du couloir, le rayon ne touche pas.
	prism.state = ""
	prism.cd = 0.0
	await _until(func(): return prism.state == "windup", 120)
	p.position += prism.attack_dir.orthogonal() * 120.0
	hp0 = p.hp
	await _until(func():
		p.invuln = 0.0
		return prism.state == "recover", 120)
	check(p.hp == hp0, "à côté du couloir, le rayon ne touche pas")
	p.set_physics_process(true)
	prism.queue_free()
	await _steps(2)
	_clear()
	# Colosse de quartz : lourd, et vole en éclats à sa mort.
	_place(spot)
	var qz = main.spawn_enemy_kind("quartz", spot + Vector2(300, 0), 1.0)
	check(qz.data.get("no_push", false) == true, "le Colosse de quartz est lourd (no_push)")
	var n_shards := int(qz.data["shards"])
	qz.take_damage(qz.hp + 1.0, false)
	await _steps(3)
	check(_thorns("verre").size() == n_shards, "à sa mort, il vole en éclats (%d éclats de verre)" % _thorns("verre").size())
	_clear()
	await _steps(2)
	# Une élite des falaises.
	var elite = main.spawn_enemy_kind("prismeur", spot + Vector2(400, 0), 1.0)
	elite.make_elite(["rapide"])
	check(elite.elite and elite.elite_name.begins_with("Prismeur"), "une élite des falaises : %s" % elite.elite_name)
	_clear()
	await _steps(2)
	# Les falaises font naître leurs Flétris.
	var kinds := {}
	for i in 400:
		var k: String = main._region_kind("aube", c * 1.2)
		kinds[k] = kinds.get(k, 0) + 1
	check(kinds.has("luciole") and kinds.has("miroitier") and kinds.has("prismeur") and kinds.has("quartz"), "les quatre Flétris naissent sur les falaises %s" % [kinds])

	print("Cœur de l'aurore")
	p.fire_cd = 0.0
	var heart = main.hearts["aube"]
	# Les deux autres Cœurs de la région sont déjà purifiés : le Grand Cœur ouvre l'arène.
	for h in main.region_hearts["aube"]:
		if h != heart:
			game.flags[h.flag] = true
	var arena = main.arenas["aube"]
	check(heart.state == "fletri" and arena.state == "fermee", "Cœur flétri, arène fermée")
	_place(heart.center + Vector2(heart.zone * 0.6, 0))
	await _steps(90)
	check(heart.state == "siege" and heart.spawned.size() > 0, "tenir la zone lance le siège et une vague")
	heart.progress = heart.hold_time - 0.2
	await _steps(30)
	check(heart.state == "purifie" and game.flags.get("aube_coeur_purifie", false) == true, "Cœur purifié, drapeau aube_coeur_purifie")
	check(arena.state == "ouverte", "le cercle de la Phalène s'ouvre")
	_clear()

	print("La Phalène de verre")
	p.fire_cd = 1.0e9
	_place(arena.center + Vector2(0, 250))
	await _steps(5)
	var boss = arena.boss
	check(arena.state == "combat" and is_instance_valid(boss) and boss.get_script().resource_path.ends_with("boss_aube.gd"), "entrer dans le cercle réveille la Phalène")
	check(boss in main.enemies_near(boss.position + Vector2(boss.radius + 4.0, 0), 8.0), "enemies_near la trouve")
	_place(arena.center + Vector2(0, 330))
	check(await _until(func(): return boss.attack != "" and boss.stage == "annonce"), "une attaque est annoncée avant de frapper")
	await _until(func(): return boss.attack == "")
	# Écailles : un éventail qui vole vers le joueur.
	boss.gap = 1.0e9
	boss._begin("ecailles")
	check(await _until(func(): return boss.scales.size() > 0, 200), "les écailles de verre partent en éventail (%d)" % boss.scales.size())
	await _until(func(): return boss.attack == "")
	# Éclair : blesse et éblouit le joueur pris dans le cône.
	_place(arena.center + Vector2(0, 200))
	p.invuln = 0.0
	p.dazzle = 0.0
	p.set_physics_process(false)
	boss._begin("eclair")
	check(boss.danger_time(p.position) < INF, "le cône de l'éclair menace le joueur (le robot l'évite)")
	var bhp0: float = p.hp
	check(await _until(func():
		p.invuln = 0.0
		return boss.stage == "frappe", 200), "l'éclair frappe après son annonce")
	check(p.hp < bhp0 and p.dazzle > 0.0, "le joueur pris dans l'éclair est blessé et ébloui")
	p.set_physics_process(true)
	await _until(func(): return boss.attack == "")
	# Phase 2 : rayons et nuée.
	boss.take_damage(boss.max_hp * 0.4, false)
	check(await _until(func(): return boss.phase == 2), "sous 66 % de vie : phase 2")
	await _until(func(): return boss.transition <= 0.0)
	boss.gap = 1.0e9
	_place(arena.center + Vector2(0, 220))
	p.set_physics_process(false)
	boss._begin("rayons")
	check(boss.beams.size() == boss.PHASES[2]["beams"], "les rayons partent en étoile (%d couloirs)" % boss.beams.size())
	check(boss.danger_time(p.position) < INF, "un rayon vise le joueur")
	bhp0 = p.hp
	check(await _until(func():
		p.invuln = 0.0
		return boss.stage == "frappe", 200), "les rayons frappent après leur annonce")
	check(p.hp < bhp0, "le joueur dans un couloir est touché")
	p.set_physics_process(true)
	await _until(func(): return boss.attack == "")
	boss._begin("nuee")
	check(await _until(func(): return boss.minions.size() > 0, 200), "la nuée fait naître des Lucioles (%d)" % boss.minions.size())
	await _until(func(): return boss.attack == "")
	_clear()
	boss.minions = []
	# Phase 3 : deux salves de rayons, la pluie de lumière.
	boss.take_damage(boss.max_hp * 0.3, false)
	check(await _until(func(): return boss.phase == 3), "sous 33 % de vie : phase 3")
	await _until(func(): return boss.transition <= 0.0)
	boss.gap = 1.0e9
	boss._begin("rayons")
	var first: Array = boss.beams.duplicate()
	await _until(func(): return boss.stage == "frappe", 200)
	check(await _until(func(): return boss.stage == "annonce" and boss.beams != first, 200), "phase 3 : une seconde salve de rayons, décalée")
	await _until(func(): return boss.attack == "", 400)
	_place(arena.center + Vector2(150, 150))
	p.set_physics_process(false)
	boss._begin("pluie")
	check(boss.pillars.size() == boss.PHASES[3]["pillars"] and boss.pillars[0].distance_to(p.position) < 1.0, "la pluie de lumière vise le joueur (%d colonnes)" % boss.pillars.size())
	var inside := true
	for q in boss.pillars:
		inside = inside and q.distance_to(arena.center) <= arena.radius - boss.RAIN["radius"] + 0.5
	check(inside, "les colonnes tombent dans le cercle")
	bhp0 = p.hp
	check(await _until(func():
		p.invuln = 0.0
		return boss.stage == "frappe", 200), "elles tombent après leur annonce")
	check(p.hp < bhp0, "le joueur sous une colonne est touché")
	p.set_physics_process(true)
	await _until(func(): return boss.attack == "")

	print("Victoire")
	_clear()
	var points: int = game.points
	boss.take_damage(boss.max_hp + 1.0, false)
	check(boss.dead and game.flags.get("aube_boss_vaincu", false) == true, "Phalène vaincue : drapeau aube_boss_vaincu")
	check(game.points == points + 2, "2 points d'arbre gagnés")
	check(arena.state == "vaincue" and not main.spawn_paused, "le cercle refleurit, les naissances reprennent")
	# Le ralenti de la mort du boss (moments.gd) allonge le temps réel : attendre qu'il ait disparu.
	await _until(func(): return not is_instance_valid(boss), 600)
	check(not is_instance_valid(boss), "la Phalène a disparu")

	print("Sauvegarde")
	var data: Dictionary = JSON.parse_string(JSON.stringify(root.get_node("SaveGame").capture(main)))
	game.reset()
	check(not game.flags.has("aube_coeur_purifie") and not game.flags.has("aube_boss_vaincu"), "nouvelle partie : drapeaux effacés")
	root.get_node("SaveGame").apply(data, main)
	await _steps(3)
	check(game.flags.get("aube_coeur_purifie", false) == true and game.flags.get("aube_boss_vaincu", false) == true, "les drapeaux d'Aube sont sauvegardés et rechargés")

	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
