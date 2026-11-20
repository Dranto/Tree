## Test du Cœur de flétrissure et de la Mère-Ronce : siège et purification, ouverture de l'arène,
## phases du boss, mort du joueur (le Cœur reste purifié), victoire (drapeau, points et greffe), puis
## sauvegarde aller-retour des drapeaux.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/boss_test.gd
## Une autre région : … -s res://tests/boss_test.gd -- --region=spore (son Cœur et son boss).
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree


## Régions dont le boss resserre l'arène en phase 3 (arena.start_shrink).
const SHRINKING_REGIONS := ["ronce", "spore", "seve"]

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
	check(boss.statuses.has("enracine"), "l'enracinement la ralentit")
	_place(arena.center + Vector2(0, 420))
	check(await _until(func(): return boss.attack != "" and boss.stage == "annonce"), "une attaque est annoncée avant de frapper")
	boss.take_damage(boss.max_hp * 0.4, false)
	check(await _until(func(): return boss.phase == 2), "sous 66 % de vie : phase 2")
	boss.take_damage(boss.max_hp * 0.3, false)
	check(await _until(func(): return boss.phase == 3), "sous 33 % de vie : phase 3")
	# Seuls les boss dont la phase 3 appelle arena.start_shrink resserrent l'arène : Ronce, Spore et
	# Sève. Le Harfang (tempête) et la Phalène (pluie de lumière) gardent leur arène entière.
	if arena.region in SHRINKING_REGIONS:
		check(await _until(func(): return arena.radius < arena.max_radius), "en phase 3 l'arène rétrécit")
	else:
		await _steps(120)
		check(arena.radius == arena.max_radius, "en phase 3 l'arène garde sa taille (pas de resserrement dans cette région)")
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
	await _until(func(): return not is_instance_valid(boss), 300)
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
