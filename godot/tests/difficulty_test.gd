## Test de la difficulté (jalon 4, tâche A) : la menace suit le niveau, la zone et les Cœurs
## purifiés mais jamais le temps passé ; plafonds d'apparition par zone ; courbe d'expérience ;
## choix Facile / Normal / Difficile.
## Lancer : tools/godot.sh --headless -s res://tests/difficulty_test.gd
extends SceneTree

const Difficulty = preload("res://scripts/difficulty.gd")
const Regions = preload("res://scripts/regions.gd")

var failures := 0
var main
var game
var settings


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
	settings = root.get_node("Settings")
	var saved_difficulty: String = settings.difficulty
	settings.difficulty = "normal"
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
	var deep: Vector2 = Vector2.from_angle(Regions.angle_of("ronce")) * 2400.0

	print("Menace")
	game.level = 20
	main.elapsed = 0.0
	var t0: float = main.threat(Vector2.ZERO)
	main.elapsed = 3600.0
	check(is_equal_approx(main.threat(Vector2.ZERO), t0), "une heure de jeu ne change pas la menace (%.2f)" % t0)
	check(is_equal_approx(main.power(), main.threat()), "power() reste un alias de threat() à la position du joueur")
	game.level = 1
	var t1: float = main.threat(Vector2.ZERO)
	check(is_equal_approx(t1, float(Difficulty.data()["threat"]["base"])), "au niveau 1 près de la graine, la menace vaut la base (%.2f)" % t1)
	check(t0 > t1, "la menace monte avec le niveau (%.2f → %.2f)" % [t1, t0])
	game.level = 20
	var t_deep: float = main.threat(deep)
	check(t_deep > t0, "la menace est plus forte au fond du roncier (%.2f) qu'à la graine (%.2f)" % [t_deep, t0])
	game.flags["ronce_coeur_purifie"] = true
	check(main.hearts_purified() == 1, "un Cœur purifié est compté")
	check(main.threat(deep) > t_deep, "un Cœur purifié fait monter la menace")
	game.flags.erase("ronce_coeur_purifie")
	game.level = 999
	check(main.threat(deep) <= float(Difficulty.data()["threat"]["max"]) + 0.001, "la menace a un plafond")
	game.level = 20

	print("Apparitions")
	check(Difficulty.spawn_cap(20, 0.0) < Difficulty.spawn_cap(20, 1.0), "moins d'ennemis à l'écran près de la graine (%d) qu'au fond du roncier (%d)" % [Difficulty.spawn_cap(20, 0.0), Difficulty.spawn_cap(20, 1.0)])
	check(Difficulty.spawn_burst(20, 0.0) <= Difficulty.spawn_burst(20, 1.0), "des salves plus grosses au fond du roncier")
	check(Difficulty.spawn_cap(99, 1.0) <= 120, "plafond absolu d'ennemis à l'écran")
	check(Difficulty.spawn_interval(1) > Difficulty.spawn_interval(20), "la cadence suit le niveau")
	check(Difficulty.spawn_interval(999) >= float(Difficulty.data()["spawn"]["interval_min"]), "la cadence a un plancher")
	var e = main.spawn_enemy_kind(0, deep, main.threat(deep))
	check(is_equal_approx(e.power, main.threat(deep)), "un ennemi né au fond du roncier reçoit la menace de cet endroit")
	check(e.xp_value > float(e.data["xp"]), "il donne plus d'expérience qu'un Flétri du début")

	print("Courbe d'expérience")
	game.level = 1
	var x1: float = game.xp_to_next()
	game.level = 20
	check(game.xp_to_next() > x1, "il faut plus d'expérience au niveau 20 qu'au niveau 1")
	check(is_equal_approx(game.xp_to_next(), Difficulty.xp_to_next(20)), "Game.xp_to_next lit difficulty.json")
	var ok := true
	for l in range(1, 30):
		ok = ok and Difficulty.target_minutes(l) > 0.0 and Difficulty.target_minutes(l) <= 3.0
	check(ok, "durée visée par niveau entre 0 et 3 minutes jusqu'au niveau 30")

	print("Choix de difficulté")
	var p: float = main.threat(Vector2.ZERO)
	var base = main.spawn_enemy_kind(0, Vector2(500, 0), p)
	for id in ["facile", "difficile"]:
		settings.set_difficulty(id)
		var m: Dictionary = Difficulty.mode(id)
		var x = main.spawn_enemy_kind(0, Vector2(500, 0), p)
		check(is_equal_approx(x.max_hp, base.max_hp * float(m["hp"])), "%s : vie × %.2f" % [m["name"], float(m["hp"])])
		check(is_equal_approx(x.damage, base.damage * float(m["damage"])), "%s : dégâts × %.2f" % [m["name"], float(m["damage"])])
	settings.set_difficulty("n'importe quoi")
	check(settings.difficulty == "normal", "une difficulté inconnue revient à Normal")
	check(Difficulty.mode_name("facile") == "Facile" and Difficulty.mode_name("difficile") == "Difficile", "noms des modes")
	check(Difficulty.validate().is_empty(), "difficulty.json est valide")

	settings.difficulty = saved_difficulty
	print("difficulty_test : %s" % ("OK" if failures == 0 else "%d ÉCHEC(S)" % failures))
	quit(1 if failures > 0 else 0)
