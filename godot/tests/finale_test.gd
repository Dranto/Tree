## Test de la finale de l'aventure, avec six régions (cinq du jeu et la région factice « essai »,
## tests/regions/, posée à la place de Racine, plus courte à jouer) : la finale reste fermée tant qu'une région n'est pas
## purifiée ; la dernière séquence de région annonce la retraite sous la graine ; brèche, descente
## et remontée ; combat (phases, mort du joueur, victoire) ; épilogue et générique ; sauvegarde
## (position sous la graine, drapeaux, migration d'une sauvegarde du format 4).
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/finale_test.gd
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
const Content = preload("res://scripts/content.gd")

var failures := 0
var main
var game
var objectives


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
	main.player.reset_physics_interpolation()
	# Le test ne porte pas sur la survie du joueur.
	main.player.hp = game.stats["max_hp"]
	main.player.invuln = 1.0e6


func _run() -> void:
	game = root.get_node("Game")
	objectives = root.get_node("Objectives")
	var save = root.get_node("SaveGame")
	Regions.set_extra_dirs(["res://tests/regions/"], ["racine"])
	print("Régions : ", Regions.ids())
	check(Regions.ids().size() == 6 and "essai" in Regions.ids(), "six régions : cinq du jeu (Racine écartée le temps du test) et la région factice à sa place")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	await _steps(3)
	var finale = main.finale
	var q = main.quest_ui

	print("Avant la finale")
	check(finale != null and finale.state == "fermee", "la finale est fermée en début de partie")
	check(not finale.holds(Vector2.ZERO) and finale.holds(finale.center), "l'arène est hors du monde, sous la graine")
	for id in Regions.ids():
		if id != "essai":
			game.flags[Regions.heart_flag(id)] = true
			game.flags[Regions.boss_flag(id)] = true
			game.flags[Regions.ending_flag(id)] = true
	await _steps(3)
	check(finale.state == "fermee" and not game.flags.get("finale_ouverte", false), "une région reste à purifier : toujours fermée")
	check(str(objectives.current().get("id", "")) != "finale", "l'objectif de la finale n'existe pas encore")
	_place(finale.descent_point())
	await _steps(90)
	check(not finale.holds(main.player.position), "pas de descente tant que la brèche est fermée")

	print("La dernière région")
	_place(Vector2(-300, 300))
	game.flags[Regions.heart_flag("essai")] = true
	game.flags[Regions.boss_flag("essai")] = true
	check(objectives.ending_region() == "essai", "la dernière reverdie est due")
	await _steps(3)
	check(finale.state == "ouverte" and game.flags.get("finale_ouverte", false), "toutes les régions purifiées : la brèche s'ouvre")
	q.start_ending()
	check(q.fanfare.active and not game.flags.has("fin_aventure_vue"), "la reverdie de région n'est pas la fin de l'aventure")
	check(q.fanfare.last and q.fanfare.duration == q.fanfare.DURATION_LONG, "la cendre reflue vers la graine, sans texte")
	var ash_before: int = main.fx.particles.size()
	q.fanfare._process(0.5)
	check(main.fx.particles.size() > ash_before, "des flocons de cendre dérivent vers la graine")
	q.fanfare.finish()
	await _steps(2)
	check(not objectives.ending_due() and not objectives.epilogue_due(), "plus de séquence due, pas d'épilogue avant la finale")
	objectives.check()
	var cur: Dictionary = objectives.current()
	check(str(cur.get("id", "")) == "finale" and objectives.followed().get("id", "") == "finale", "l'objectif principal est la finale")
	check(objectives.target_pos(cur) == finale.descent_point(), "la flèche pointe vers la brèche au pied de la graine")

	print("Descente et remontée")
	main.spawn_timer = 0.0
	for i in 3:
		main.spawn_enemy_at(Vector2(200 + 40 * i, 200), 0)
	_place(finale.descent_point())
	await _steps(30)
	check(not finale.holds(main.player.position) and finale.hold > 0.0, "se tenir dans la brèche : l'anneau se remplit")
	check(await _until(func(): return finale.holds(main.player.position), 120), "après une seconde, descente sous la graine")
	check(main.underground() and main.enemies.is_empty(), "les Flétris du monde ne suivent pas")
	check(finale.state == "ouverte" and not main.in_boss_fight(), "le combat ne commence pas dès l'arrivée")
	check(objectives.target_pos(cur) == finale.center, "sous la graine, la flèche montre la Flétrissure")
	main.player.hp = 100.0
	await _steps(200)
	check(main.enemies.is_empty(), "rien ne naît sous la graine")
	var far: Vector2 = finale.center + Vector2(0, finale.max_radius + 150.0)
	main.player.position = far
	await _steps(2)
	check(main.player.position.distance_to(finale.center) < finale.max_radius, "le mur de racines tient le joueur dans le creux")
	check(main.region_at(main.player.position) == "" and main.map_position(main.player.position) == finale.descent_point(), "sous la graine : aucune région, la carte montre la brèche")
	var entry: Dictionary = save.capture(main)["world"]["player"]
	check(Vector2(entry["x"], entry["y"]).distance_to(finale.entrance()) < 1.0, "sauvegardé sous la graine, le joueur reprendra au pied de la graine")
	_place(finale.landing() + Vector2(120, 0))
	await _steps(3)
	_place(finale.landing())
	check(await _until(func(): return not finale.holds(main.player.position), 120), "revenir dans le puits de lumière fait remonter")
	check(main.player.position.distance_to(finale.entrance()) < 5.0, "le joueur remonte à côté de la brèche")

	print("Combat")
	finale.descend()
	await _steps(2)
	_place(finale.center + Vector2(0, 200))
	await _steps(5)
	var boss = finale.boss
	check(finale.state == "combat" and is_instance_valid(boss) and main.in_boss_fight(), "s'avancer réveille la Flétrissure")
	check(boss.has_method("_fight_step") and boss in main.enemies and finale.bar.visible, "un boss BossBase, inscrit dans les ennemis, avec sa barre")
	check(main.active_arena() == finale, "main.active_arena() renvoie la finale")
	check(await _until(func(): return boss.attack != "" and boss.stage == "annonce"), "une attaque est annoncée avant de frapper")
	var seen := {}
	for i in 600:
		if boss.attack != "":
			seen[boss.attack] = true
		await physics_frame
	check(seen.has("epines") and seen.has("spores"), "phase 1 : épines et spores (%s)" % ", ".join(seen.keys()))
	boss.take_damage(boss.max_hp * 0.4, false)
	check(await _until(func(): return boss.phase == 2), "sous 66 % de vie : phase 2")
	seen = {}
	for i in 900:
		if boss.attack != "":
			seen[boss.attack] = true
		await physics_frame
	check(seen.has("siphon") and seen.has("rafale"), "phase 2 : la sève et le vent (%s)" % ", ".join(seen.keys()))
	boss.take_damage(boss.max_hp * 0.3, false)
	check(await _until(func(): return boss.phase == 3), "sous 33 % de vie : phase 3")
	check(boss.unbound and boss.transforming(), "sous 33 % : elle prend sa seconde forme")
	var hp_before: float = boss.hp
	boss.take_damage(500.0, false)
	check(boss.hp == hp_before, "invulnérable pendant la transformation")
	check(await _until(func(): return finale.radius < finale.max_radius), "le creux s'effondre autour d'elle")
	check(await _until(func(): return not boss.transforming() and finale.radius == finale.collapse_radius and finale.collapse_k == 1.0), "il ne reste qu'une île de radius_collapse au-dessus du gouffre")
	check(boss.form_k() == 1.0, "la transformation est finie")
	seen = {}
	for i in 1500:
		if boss.attack != "":
			seen[boss.attack] = true
		await physics_frame
	check(seen.has("lumiere") and seen.has("racines"), "seconde forme : la lumière et les racines (%s)" % ", ".join(seen.keys()))
	check(seen.has("tempete") and seen.has("floraison") and seen.has("aurore"), "seconde forme : les attaques combinées des six gardiens (%s)" % ", ".join(seen.keys()))

	print("Mort face à la Flétrissure")
	main.player_died()
	await _steps(5)
	check(finale.state == "ouverte" and not main.in_boss_fight() and not main.spawn_paused, "le combat s'arrête, la brèche reste ouverte")
	check(not finale.holds(main.player.position), "le joueur renaît dans le monde")
	check(int(game.flags.get("stat_finale_essais", 0)) == 1, "l'essai perdu est compté")
	if game.flags.has("seve_perdue_x"):
		check(Vector2(game.flags["seve_perdue_x"], game.flags["seve_perdue_y"]).distance_to(finale.entrance()) < 1.0, "la sève attend près de la brèche")

	print("Victoire")
	finale.descend()
	await _steps(2)
	_place(finale.center + Vector2(0, 200))
	await _steps(5)
	boss = finale.boss
	check(finale.state == "combat" and boss.hp == boss.max_hp and boss.phase == 1, "la Flétrissure revient avec toute sa vie")
	var points: int = game.points
	boss.take_damage(boss.max_hp + 1.0, false)
	check(boss.dead and game.flags.get("finale_vaincue", false), "Flétrissure vaincue : drapeau finale_vaincue")
	check(game.points == points + int(Content._load("finale")["boss"]["reward"]["points"]), "les points de la finale sont donnés")
	await _steps(3)
	check(objectives.is_done("finale") and objectives.epilogue_due(), "objectif accompli, l'épilogue est dû")
	var ending = q.world_ending
	check(not ending.active, "la fin attend que le creux refleurisse")
	check(await _until(func(): return ending.active, int(q.EPILOGUE_DELAY * 60.0) + 60), "puis la fin se joue dans le monde")
	check(not paused and game.flags.get("fin_aventure_vue", false), "sans pause ni écran : fin de l'aventure notée")
	check(not finale.holds(main.player.position), "le joueur est remonté au pied de la graine")
	var names: Array = []
	for g in ending.groups:
		names.append_array(g["lines"])
	check(Regions.section("essai", "boss").get("name", "?") in names and "La Flétrissure" in names, "le générique nomme les gardiens et la Flétrissure")
	check(ending.group_k(ending.groups.size() - 1) == 0.0, "le générique s'écrit peu à peu dans l'herbe")
	ending.set_time(ending.duration() + 1.0)
	main.ground.finish_waves()
	check(main.ground.life_at(Regions.center("aube")) > 0.9 and main.ground.life_at(Regions.center("essai")) > 0.9, "le monde entier reverdit")
	check(not ending.active and ending.group_k(ending.groups.size() - 1) == 1.0 and not main.spawn_paused, "tous les noms sont écrits, le jeu continue")
	await _steps(int(q.EPILOGUE_DELAY * 60.0) + 30)
	check(not ending.active and not objectives.epilogue_due(), "la fin ne revient pas")
	finale.descend()
	await _steps(5)
	check(finale.state == "vaincue" and not main.in_boss_fight() and finale.bloom > 0.99, "après la fin, le creux reste fleuri et paisible")

	print("Sauvegarde")
	var data: Dictionary = JSON.parse_string(JSON.stringify(save.capture(main)))
	check(int(data["version"]) == save.VERSION, "format %d" % save.VERSION)
	for k in ["finale_ouverte", "finale_vaincue", "fin_aventure_vue"]:
		check(data["game"]["flags"].get(k, false) == true, "drapeau « %s » sauvegardé" % k)
	# Une sauvegarde du format 4 qui avait vu l'ancienne fin (toutes les régions, texte de fin) :
	# l'épilogue n'est pas marqué vu, la finale s'ouvre au chargement.
	var old := {"format": "seve-save", "version": 4, "game": {"level": 22, "flags": {"fin_aventure_vue": true}}, "tree": {}, "world": {}}
	for id in Regions.ids():
		old["game"]["flags"][Regions.boss_flag(id)] = true
		old["game"]["flags"][Regions.heart_flag(id)] = true
		old["game"]["flags"][Regions.ending_flag(id)] = true
	var migrated: Dictionary = save._migrate(old.duplicate(true))
	check(int(migrated["version"]) == save.VERSION and not migrated["game"]["flags"].has("fin_aventure_vue"), "format 4 → %d : l'ancienne fin n'est plus « l'aventure finie »" % save.VERSION)
	save.apply(migrated, main)
	await _steps(3)
	check(finale.state == "ouverte" and game.flags.get("finale_ouverte", false), "la finale s'ouvre au chargement")
	var won := {"format": "seve-save", "version": 4, "game": {"flags": {"fin_aventure_vue": true, "finale_vaincue": true}}}
	check(save._migrate(won)["game"]["flags"].get("fin_aventure_vue", false), "une partie déjà finie le reste")

	Regions.set_extra_dirs([])
	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
