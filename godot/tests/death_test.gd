## Test de la mort et des sanctuaires : sanctuaire ravivé (point de renaissance, vie rendue),
## mort (renaissance au sanctuaire, sève laissée au sol, arbre intact), sauvegarde entre la mort
## et le ramassage, sève reprise, sève perdue par une seconde mort, siège du Cœur remis à zéro,
## et le robot d'équilibrage qui renaît toujours sur place.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/death_test.gd
## Ne lit ni n'écrit la sauvegarde par défaut.
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


## Pose le joueur, à l'abri des coups (le test choisit ses morts).
func _place(pos: Vector2) -> void:
	main.player.position = pos
	main.player.invuln = 1.0e6


## Un vrai coup mortel, par le même chemin qu'en jeu (player.take_hit).
func _die_at(pos: Vector2) -> void:
	main.player.position = pos
	main.player.invuln = 0.0
	main.player.take_hit(1.0e6, null)
	main.player.invuln = 1.0e6
	await _steps(2)


## Icônes de l'écran de mort (jalon 11 : plus de phrases), séparées par des espaces.
func _death_icons() -> Array:
	return main.hud.death_screen.icon_list()


func _run() -> void:
	game = root.get_node("Game")
	var save = root.get_node("SaveGame")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)

	print("Sanctuaires")
	check(main.sanctuaries.size() >= 4, "%d sanctuaires (la Graine et ceux de Ronce)" % main.sanctuaries.size())
	var ronce: Array = main.sanctuaries.filter(func(s): return main.region_at(s.position) == "ronce")
	check(ronce.size() >= 3 and ronce.size() <= 4, "%d sanctuaires dans le roncier" % ronce.size())
	var clear := true
	for s in main.sanctuaries:
		if s.position.distance_to(main.heart.center) < main.heart.zone + 300.0 or s.position.distance_to(main.arena.center) < main.arena.max_radius + 80.0:
			clear = false
		if main.flora.push_out(s.position, 20.0) != s.position:
			clear = false
	check(clear, "aucun sanctuaire dans la zone du Cœur, l'arène ou un buisson d'épines")
	check(main.sanctuary("graine").is_lit() and game.flags.get("sanctuaire_graine", false) == true, "la Graine est ravivée dès le départ")
	check(main.respawn_point() == Vector2.ZERO, "sans autre sanctuaire, on renaît à la graine")

	var lisiere = main.sanctuary("lisiere")
	var ravin = main.sanctuary("ravin")
	check(not lisiere.is_lit(), "la Lisière est éteinte")
	_place(ravin.position)
	await _steps(60)
	check(ravin.progress > 0.5 and not ravin.is_lit(), "une seconde dans le cercle : le sanctuaire commence à reprendre")
	_place(ravin.position + Vector2(300, 0))
	await _steps(30)
	check(ravin.progress < 0.9 and ravin.progress > 0.0 and not ravin.is_lit(), "hors du cercle, l'avancée retombe")
	_place(lisiere.position + Vector2(20, 0))
	main.player.hp = 5.0
	await _steps(200)
	check(lisiere.is_lit() and game.flags.get("sanctuaire_lisiere", false) == true, "trois secondes dans le cercle : Lisière ravivée, drapeau posé")
	check(game.flags.get("renaissance", "") == "lisiere" and main.respawn_point() == lisiere.position, "la Lisière devient le point de renaissance")
	check(main.player.hp == game.stats["max_hp"], "toute la vie est rendue")
	check(main.ground.life_at(lisiere.position) > 0.45, "la vie revient autour du sanctuaire")

	print("Mort")
	var first := -1
	for m in game.tree.nodes[0]["neighbors"]:
		if game.can_allocate(m):
			first = m
			break
	# Les autels voisins du sanctuaire ont pu donner des points : on compte à partir d'ici.
	var p0: int = game.points
	game.allocate(first)
	game.add_xp(game.xp_to_next() + 7.5)   # un niveau gagné, un point gardé en réserve
	var level: int = game.level
	var points: int = game.points
	var uids: Array = game.allocated_uids()
	var xp: float = game.xp
	check(xp > 7.0 and points == p0, "avant la mort : %.1f d'expérience non dépensée, un point gagné en réserve" % xp)
	var fall: Vector2 = lisiere.position + Vector2(-1100, -300)
	await _die_at(fall)
	check(main.player.position == lisiere.position, "le joueur renaît au dernier sanctuaire ravivé")
	check(main.player.hp == game.stats["max_hp"] and main.deaths == 1, "avec toute sa vie")
	check(game.xp == 0.0 and game.level == level, "l'expérience non dépensée quitte le joueur, le niveau reste")
	check(game.points == points and game.allocated_uids() == uids, "les points et les nœuds appris ne sont pas perdus")
	check(main.lost_sap != null and main.lost_sap.position == fall and is_equal_approx(main.lost_sap.amount, xp), "la sève perdue reste au sol là où il est tombé")
	check(is_equal_approx(float(game.flags.get("seve_perdue", 0.0)), xp), "elle est gardée dans les drapeaux de la partie")
	check(main.hud.death_screen.is_showing(), "l'écran de mort s'affiche")
	var icons := _death_icons()
	check(icons == ["renaissance", "seve", "arbre"] and roundi(float(main.hud.death_screen.info.get("dropped", 0.0))) == roundi(xp), "ses icônes : renaissance, sève au sol, arbre intact (%s)" % [icons])
	check(main.hud.death_screen.find_children("*", "Label", true, false).filter(func(l): return l.visible and l.text.length() > 12).is_empty(), "aucune phrase à lire")
	check(main.enemies.is_empty(), "les ennemis se sont dissipés")
	await _steps(30)
	check(main.hud.death_screen._pointer_label.visible, "une flèche au bord de l'écran montre la sève hors de vue")

	print("Sauvegarde entre la mort et le ramassage")
	var data: Dictionary = JSON.parse_string(JSON.stringify(save.capture(main)))
	game.reset()
	await _steps(2)
	check(main.lost_sap == null, "nouvelle partie : plus de sève au sol")
	save.apply(data, main)
	await _steps(2)
	check(main.lost_sap != null and main.lost_sap.position.distance_to(fall) < 0.01 and is_equal_approx(main.lost_sap.amount, xp), "partie rechargée : la sève est toujours au sol")
	check(main.respawn_point() == lisiere.position and lisiere.is_lit(), "et la Lisière reste le point de renaissance")

	print("Sève reprise")
	_place(fall)
	await _steps(3)
	check(is_equal_approx(game.xp, xp) and game.level == level, "toucher la sève rend toute l'expérience")
	check(main.lost_sap == null and not game.flags.has("seve_perdue"), "la sève a disparu du sol et des drapeaux")

	print("Seconde mort avant de reprendre la sève")
	var a: Vector2 = lisiere.position + Vector2(400, 0)
	var b: Vector2 = lisiere.position + Vector2(0, 400)
	await _die_at(a)
	var first_drop: float = main.lost_sap.amount
	game.xp = 3.0
	await _die_at(b)
	check(main.lost_sap != null and main.lost_sap.position == b and main.lost_sap.amount == 3.0, "la nouvelle sève tombe au nouvel endroit")
	check(main.orbs_layer.get_children().filter(func(n): return n.get_script() == main.LostSap and not n.is_queued_for_deletion()).size() == 1, "l'ancienne sève est perdue")
	check("seve_perdue" in _death_icons(), "l'écran le montre (sève perdue barrée, %d)" % roundi(first_drop))
	await _die_at(a)
	check(main.lost_sap == null and not game.flags.has("seve_perdue"), "mourir sans expérience ne laisse rien au sol et perd la sève restante")
	check(game.points == points and game.allocated_uids() == uids, "toujours aucun point ni nœud perdu après trois morts")

	print("Siège du Cœur")
	var heart = main.heart
	_place(heart.center + Vector2(heart.zone * 0.5, 0))
	await _steps(120)
	check(heart.state == "siege" and heart.progress > 1.5, "le siège a commencé")
	await _die_at(heart.center + Vector2(heart.zone * 0.5, 0))
	check(heart.state == "fletri" and heart.progress == 0.0 and not heart.bar.visible, "mourir pendant le siège remet le Cœur à zéro")
	check("reprise" in _death_icons(), "l'écran de mort le montre (flèche de reprise)")
	check(main.player.position == lisiere.position, "renaissance à la Lisière")

	print("Deux sièges commencés")
	var list: Array = main.region_hearts[heart.region]
	var h1 = list[0]
	var h2 = list[1]
	_place(h1.center + Vector2(h1.zone * 0.5, 0))
	await _steps(90)
	_place(h2.center + Vector2(h2.zone * 0.5, 0))
	await _steps(90)
	check(h1.state == "siege" and h2.state == "siege", "le premier siège, laissé en plan, n'est pas encore retombé")
	check(h2.bar.visible and not h1.bar.visible, "une seule barre de siège : celle du Cœur où l'on est")
	h1.reset_siege()
	h2.reset_siege()

	print("Autre sanctuaire visité")
	_place(main.sanctuary("graine").position + Vector2(0, 10))
	await _steps(3)
	check(main.respawn_point() == Vector2.ZERO and game.flags.get("renaissance", "") == "graine", "revenir à la Graine en refait le point de renaissance")

	print("Robot d'équilibrage")
	main.build_bot = RefCounted.new()
	var here := Vector2(123, 456)
	game.xp = 4.0
	await _die_at(here)
	check(main.player.position.distance_to(here) < 5.0 and game.xp >= 4.0 and main.lost_sap == null, "le robot renaît sur place, sans perdre sa sève")
	main.build_bot = null

	print("")
	if failures == 0:
		print("MORT : tout est bon")
	else:
		print("MORT : %d échec(s)" % failures)
	main.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
