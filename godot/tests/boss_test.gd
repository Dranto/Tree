## Test du Cœur de flétrissure et de la Mère-Ronce : siège et purification, ouverture de l'arène,
## phases du boss, mort du joueur (le Cœur reste purifié), victoire (drapeau, points et greffe), puis
## sauvegarde aller-retour des drapeaux.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/boss_test.gd
## Une autre région : … -s res://tests/boss_test.gd -- --region=spore (son Cœur et son boss).
## Cycle exalté (NG+) : … -- --region=seve --cycle=2 (phase exaltée et attaque nouvelle du boss).
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree


## Régions dont le boss resserre l'arène en phase 3 (arena.start_shrink).
const SHRINKING_REGIONS := ["ronce", "spore", "seve", "racine"]

var failures := 0
var main


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


## Attend qu'une condition soit vraie, au plus `limit` pas de jeu.
func _until(cond: Callable, limit := 900) -> bool:
	for i in limit:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _place(pos: Vector2) -> void:
	main.player.position = pos
	main.player.hp = 1.0e6   # le test ne porte pas sur la survie du joueur


func _run() -> void:
	var game = root.get_node("Game")
	var save = root.get_node("SaveGame")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	await _steps(3)
	var heart = main.heart
	var arena = main.arena

	print("Avant le Cœur")
	check(heart.state == "fletri" and arena.state == "fermee", "Cœur flétri, arène fermée")
	_place(arena.center)
	await _steps(3)
	check(main.player.position.distance_to(arena.center) > arena.max_radius, "le mur de ronces repousse le joueur hors de l'arène fermée")

	print("Siège du Cœur")
	_place(heart.center + Vector2(heart.zone * 0.6, 0))
	await _steps(90)
	check(heart.state == "siege" and heart.progress > 1.0, "tenir la zone lance le siège")
	check(heart.spawned.size() > 0, "une vague d'ennemis est arrivée")
	check(heart.bar.visible, "la barre du Cœur est affichée")
	# Loin du Cœur, du côté opposé à l'arène (dont le mur repousse le joueur).
	_place(heart.center + (heart.center - arena.center).normalized() * (heart.zone + 200.0))
	var before: float = heart.progress
	await _steps(30)
	check(heart.progress < before and heart.progress > 0.0, "hors de la zone, l'avancée retombe lentement")
	_place(heart.center + Vector2(heart.zone * 0.6, 0))
	heart.progress = heart.hold_time - 0.2
	await _steps(30)
	check(heart.state == "purifie" and game.flags.get(heart.flag, false) == true, "30 s tenues : Cœur purifié, drapeau posé")
	check(heart.great and main.region_hearts[arena.region].size() == 3, "c'est le Grand Cœur, l'un des trois de la région")
	check(arena.state == "fermee" and not game.flags.get(arena.region + "_coeur_purifie", false), "un Cœur sur trois : l'arène reste scellée")
	for h in main.region_hearts[arena.region]:
		if h != heart:
			game.flags[h.flag] = true
	await _steps(5)
	check(game.flags.get(arena.region + "_coeur_purifie", false), "les trois Cœurs purifiés : drapeau de la région posé")
	check(arena.state == "ouverte", "l'arène s'ouvre")
	check(not heart.bar.visible, "la barre du Cœur disparaît")
	await _steps(150)
	check(main.ground.life_at(heart.center + Vector2(500, 0)) > 0.45, "la vague de vie a ravivé les alentours")

	print("Combat")
	_place(arena.center + Vector2(0, 250))
	await _steps(5)
	var boss = arena.boss
	check(arena.state == "combat" and is_instance_valid(boss), "entrer dans l'arène réveille la Mère-Ronce")
	check(boss in main.enemies and main.spawn_paused, "elle est inscrite dans main.enemies, les naissances sont en pause")
	check(boss in main.enemies_near(boss.position + Vector2(boss.radius + 4.0, 0), 8.0), "enemies_near la trouve malgré sa taille")
	check(arena.bar.visible, "la barre de vie du boss est affichée")
	for i in 7:
		boss.apply_status("saignement", 1.0, 5.0)
	check(boss.statuses["saignement"]["stacks"] == 5, "le saignement se cumule 5 fois au plus")
	var hp_before: float = boss.hp
	var burst: float = boss.burst_bleed(1.0)
	check(burst > 0.0 and not boss.is_bleeding() and boss.hp == hp_before, "la Saignée fait éclater son saignement (burst_bleed, comme les autres ennemis)")
	check(boss.burst_bleed(1.0) == 0.0, "sans saignement, rien n'éclate")
	boss.apply_status("enracine", 1.0, 2.0)
	if boss.get("no_root") == true:
		check(not boss.statuses.has("enracine"), "l'enracinement ne le tient pas (no_root, l'Ancien)")
	else:
		check(boss.statuses.has("enracine"), "l'enracinement la ralentit")
	_place(arena.center + Vector2(0, 420))
	check(await _until(func(): return boss.attack != "" and boss.stage == "annonce"), "une attaque est annoncée avant de frapper")
	boss.take_damage(boss.max_hp * 0.4, false)
	check(await _until(func(): return boss.phase == 2), "sous 66 % de vie : phase 2")
	boss.take_damage(boss.max_hp * 0.3, false)
	check(await _until(func(): return boss.phase >= 3), "sous 33 % de vie : phase 3")
	# Seuls les boss dont la phase 3 appelle arena.start_shrink resserrent l'arène : Ronce, Spore et
	# Sève. Le Harfang (tempête) et la Phalène (pluie de lumière) gardent leur arène entière.
	if arena.region in SHRINKING_REGIONS:
		# Large marge (40 s de jeu) : l'annonce du resserrement dure 1,6 s et le ralenti du boss, le gel
		# d'impact ou une pause peuvent retarder la suite ; seul compte que le mur finisse par avancer.
		# Au cycle exalté, il reste en phase 3 (au-dessus de la phase exaltée) pendant l'attente.
		var shrunk: bool = await _until(func():
			if boss.exalted:
				boss.hp = maxf(boss.hp, boss.max_hp * 0.25)
			return arena.radius < arena.max_radius, 2400)
		if not shrunk:
			print("  diagnostic : état=%s phase=%d rétrécit=%s annonce=%.2f rayon=%.1f time_scale=%.2f en pause=%s" % [
				arena.state, int(boss.phase) if is_instance_valid(boss) else -1, arena.shrinking, arena.shrink_warn,
				arena.radius, Engine.time_scale, paused])
		check(shrunk, "en phase 3 l'arène rétrécit")
	else:
		await _steps(120)
		check(arena.radius == arena.max_radius, "en phase 3 l'arène garde sa taille (pas de resserrement dans cette région)")
	if boss.exalted:
		print("Cycle exalté")
		var at: float = boss.phase_limits[boss.phase_limits.size() - 1]
		check(boss.phase_limits.size() == 3, "cycle %d : une phase exaltée de plus (sous %d %% de vie)" % [root.get_node("Cycles").current(), roundi(at * 100.0)])
		boss.hp = minf(boss.hp, boss.max_hp * (at + 0.02))
		boss.take_damage(boss.max_hp * 0.03, false)
		# Les coups automatiques du héros ne doivent pas l'achever pendant qu'on regarde.
		var keep := func() -> void: boss.hp = maxf(boss.hp, boss.max_hp * 0.2)
		_place(arena.center + Vector2(0, arena.radius - 40.0))
		check(await _until(func(): keep.call(); return boss.phase == 4, 2400), "phase exaltée atteinte")
		await _steps(2)
		check(boss.exalted_phase_seen and boss.is_exalted_phase(), "elle est annoncée (BossBase._exalt_announce)")
		var attack_name: String = boss.get_script().get_script_constant_map()["EXALTED_ATTACK"]
		check(await _until(func(): keep.call(); return boss.exalted_attacks > 0, 2400), "l'attaque nouvelle « %s » est annoncée" % attack_name)
		check(await _until(func(): keep.call(); return boss.attack != attack_name, 900), "puis elle se termine")
		check(not boss.dead, "le boss est toujours debout")
	else:
		check(not boss.exalted and boss.phase_limits.size() == 2, "cycle 1 : ni phase exaltée ni attaque nouvelle")
	_place(arena.center + Vector2(0, 250))
	await _steps(2)

	print("Mort face au boss")
	main.player_died()
	await _steps(5)
	check(arena.state == "ouverte" and not main.spawn_paused, "le combat s'arrête, l'arène reste ouverte")
	check(game.flags.get(heart.flag, false) == true and heart.state == "purifie", "le Cœur reste purifié")
	check(main.player.position.distance_to(main.respawn_point()) < 10.0, "le joueur renaît au dernier sanctuaire ravivé")
	check(not arena.bar.visible and arena.radius == arena.max_radius, "barre cachée, arène à sa taille")

	print("Victoire")
	_place(arena.center + Vector2(0, 250))
	await _steps(5)
	boss = arena.boss
	check(arena.state == "combat" and boss.hp == boss.max_hp and boss.phase == 1, "la Mère-Ronce revient avec toute sa vie")
	var points: int = game.points
	boss.take_damage(boss.max_hp + 1.0, false)
	check(boss.dead and game.flags.get(arena.region + "_boss_vaincu", false) == true, "boss vaincu : drapeau posé")
	check(game.points == points + 2, "2 points d'arbre gagnés")
	check(arena.state == "vaincue" and not main.spawn_paused, "l'arène refleurit, les naissances reprennent")
	# La durée de la mort varie selon le boss (1,6 s pour la Mère-Ronce, 2 s pour le Harfang…).
	var boss_ref: WeakRef = weakref(boss)   # une capture libérée par le boss lui-même ferait une erreur au dernier appel
	await _until(func(): return boss_ref.get_ref() == null, 300)
	check(not is_instance_valid(boss) and not (boss in main.enemies), "la Mère-Ronce a disparu")

	print("Sauvegarde")
	var data: Dictionary = JSON.parse_string(JSON.stringify(save.capture(main)))
	game.reset()
	# Le joueur encore en jeu réécrit « barre » à chaque changement de l'arbre : on ne regarde que les drapeaux de Ronce.
	check(not game.flags.has(heart.flag) and not game.flags.has(arena.region + "_boss_vaincu"), "nouvelle partie : drapeaux effacés")
	save.apply(data, main)
	await _steps(3)
	check(game.flags.get(heart.flag, false) == true and game.flags.get(arena.region + "_boss_vaincu", false) == true, "les deux drapeaux sont sauvegardés et rechargés")
	check(heart.state == "purifie" and arena.state == "vaincue", "le Cœur et l'arène reprennent leur état")

	main.autosave_enabled = false
	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
