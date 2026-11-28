## Test des cycles du New Game+ (jalon 14 N) : règle de lecture de data/cycles.json (Cycles.value),
## passage au cycle suivant (ce qui se garde, ce qui revient à zéro), fruit de la graine (tenir 1 s,
## seulement après la fin, jamais dans la démo), signal Game.cycle_started, sauvegarde et reprise en
## cycle 2, résumé du menu titre.
## Lancer : tools/godot.sh --headless -s res://tests/cycle_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
const PATH := "user://tests/cycle_test.json"
## ENDING (le nommer compilerait objectives.gd avant les autoloads).
const ENDING := "fin_aventure_vue"

var failures := 0
var main
var game
var cycles
var started: Array = []


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	cycles = root.get_node("Cycles")
	var save = root.get_node("SaveGame")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	_rules()

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.autosave_enabled = false
	game.cycle_started.connect(func(n): started.append(n))

	print("Première aventure")
	check(game.cycle == 1 and cycles.current() == 1 and not cycles.exalted(), "une nouvelle partie est au cycle 1, pas exaltée")
	check(cycles.value("threat_floor", -1.0) == 0.0, "les réglages du cycle 1 sont neutres")
	check(main.cycle_fruit != null and not main.cycle_fruit.ripe(), "pas de fruit avant la fin de l'aventure")

	# Une aventure finie : niveau, nœuds, greffes, couronne, et tous les drapeaux d'une fin.
	game.add_xp(4000.0)
	var learned := 0
	while game.points > 0 and learned < 8:
		var any := false
		for n in game.tree.nodes:
			if game.can_allocate(n["id"]):
				game.allocate(n["id"])
				learned += 1
				any = true
				break
		if not any:
			break
	for id in Regions.ids():
		game.flags[Regions.boss_flag(id)] = true
		game.flags[Regions.heart_flag(id)] = true
		for i in Regions.heart_count(id):
			game.flags[Regions.heart_part_flag(id, i)] = true
		game.flags[Regions.ending_flag(id)] = true
		game.flags["points_%s_boss" % id] = true
	for k in ["finale_ouverte", "finale_vaincue", ENDING, "obj_boss", "sanctuaire_ronce", "autel_ronce_1",
			"renaissance", "stat_morts", "elites_tuees", "seve_perdue", "stat_finale_fin"]:
		game.flags[k] = true if k != "renaissance" else "ronce"
	for k in ["tuto_deplacement", "plan_arbre", "barre", "couronne_vue", "points_hors_niveau"]:
		game.flags[k] = true
	game.flags["barre"] = "nova,fouet"
	for n in game.tree.nodes:
		if not game.allocated.has(n["id"]) and _touches(n):
			game.flags["plan_arbre"] = str(n["uid"])
			break
	var grafts: Array = load("res://scripts/content.gd").grafts().keys().slice(0, 3)
	for gid in grafts:
		game.give_graft(gid)
	game._fit_crown()
	game.set_graft(0, grafts[0])
	var crown_before: int = game.crown.size()
	var before := {"level": game.level, "xp": game.xp, "points": game.points, "uids": game.allocated_uids(),
		"inventory": game.graft_inventory.duplicate(), "crown": game.crown.duplicate(), "builds": game.build_slots(), "kills": game.kills}
	check(crown_before == game.crown_max(), "couronne entière en fin d'aventure (%d)" % crown_before)
	await process_frame
	check(main.cycle_fruit.ripe(), "le fruit pousse une fois la fin vue")

	print("Le fruit (tenir 1 s)")
	var fruit = main.cycle_fruit
	main.player.position = fruit.position + Vector2(fruit.RADIUS * 3.0, 0.0)
	fruit.grown = 1.0
	for i in 30:
		await physics_frame
	check(fruit.progress == 0.0 and not fruit.picked, "loin du fruit, rien ne se passe")
	main.player.position = fruit.position
	for i in 20:
		await physics_frame
	check(not fruit.picked and fruit.progress > 0.0, "un toucher bref ne suffit pas")
	main.player.position = fruit.position + Vector2(fruit.RADIUS * 3.0, 0.0)
	for i in 40:
		await physics_frame
	check(fruit.progress == 0.0, "l'anneau retombe quand on s'éloigne")
	main.player.position = fruit.position
	var held := 0
	while not fruit.picked and held < 200:
		await physics_frame
		held += 1
	check(fruit.picked and held >= 55 and held <= 70, "tenir une seconde cueille le fruit (%d images)" % held)
	await process_frame
	await process_frame

	print("Cycle 2 : ce qui se garde")
	check(game.cycle == 2 and cycles.current() == 2 and cycles.exalted(), "cycle 2, exalté")
	check(started == [2], "Game.cycle_started(2) émis une fois (%s)" % str(started))
	check(game.level == before["level"] and game.xp >= before["xp"] and game.points == before["points"], "niveau, expérience et points gardés (%d/%d, %.1f/%.1f, %d/%d)" % [game.level, before["level"], game.xp, before["xp"], game.points, before["points"]])
	check(game.allocated_uids() == before["uids"], "arbre gardé (%d nœuds)" % (before["uids"] as Array).size())
	# Le cycle 2 ouvre un emplacement de plus (cycles.json › crown, greffes de cycle) : la couronne d'avant est intacte devant.
	var kept_crown: Array = game.crown.slice(0, (before["crown"] as Array).size())
	var new_slots: Array = game.crown.slice((before["crown"] as Array).size())
	check(game.graft_inventory == before["inventory"] and kept_crown == before["crown"] and new_slots.all(func(g): return g == ""), "greffes et couronne gardées (%d emplacements, %d nouveaux)" % [game.crown.size(), new_slots.size()])
	check(game.crown_size() >= crown_before and game.crown_kept == crown_before, "la couronne reste ouverte (%d emplacements)" % game.crown_size())
	check(game.builds.size() == before["builds"], "builds gardés")
	for k in ["tuto_deplacement", "plan_arbre", "barre", "couronne_vue", "points_hors_niveau"]:
		check(game.flags.has(k), "drapeau « %s » gardé" % k)

	print("Cycle 2 : ce qui revient à zéro")
	var any_heart := false
	var any_boss := false
	for id in Regions.ids():
		any_boss = any_boss or game.flags.get(Regions.boss_flag(id), false)
		any_heart = any_heart or game.flags.get(Regions.heart_flag(id), false)
		for i in Regions.heart_count(id):
			any_heart = any_heart or game.flags.get(Regions.heart_part_flag(id, i), false)
	check(not any_heart and not any_boss, "Cœurs et boss remis à zéro")
	for k in ["finale_ouverte", "finale_vaincue", ENDING, "obj_boss", "sanctuaire_ronce", "autel_ronce_1",
			"renaissance", "seve_perdue", "points_ronce_boss", "stat_morts"]:
		check(not game.flags.has(k), "drapeau « %s » remis à zéro" % k)
	check(cycles.wave_pending() == 2, "la vague de flétrissure du cycle 2 est en attente")
	check(not fruit.ripe(), "plus de fruit au début du cycle 2")
	cycles.end_wave()
	check(cycles.wave_pending() == 0, "la vague passée, le drapeau tombe")

	print("Sauvegarde et reprise en cycle 2")
	check(save.save_now(main, PATH), "sauvegarde")
	var crown_kept: int = game.crown_kept
	game.reset()
	check(game.cycle == 1 and game.crown_kept == 0, "une nouvelle partie repart du cycle 1")
	check(save.load_into(main, PATH), "reprise")
	check(game.cycle == 2 and game.crown_kept == crown_kept and game.crown_size() >= crown_before, "cycle et couronne repris")
	var peek: Dictionary = save.peek(PATH)
	check(int(peek.get("cycle", 0)) == 2, "le résumé du menu titre dit cycle 2")
	check(game.allocated_uids() == before["uids"], "arbre repris")

	print("Cycle 3, puis au-delà")
	game.flags[ENDING] = true
	check(cycles.advance_state() == 3 and cycles.current() == 3 and game.flags.get("cycle_wave", 0) == 3, "cycle 3")
	check(game.crown_kept == crown_kept, "la couronne gardée ne double pas")
	game.cycle = 7
	check(cycles.current() == 7, "cycles illimités")

	print("Démo")
	game.cycle = 1
	game.flags[ENDING] = true
	fruit.picked = false
	check(fruit.ripe(), "le fruit est là dans le jeu complet")
	var Demo = load("res://scripts/demo.gd")
	Demo.forced = 1
	check(not fruit.ripe(), "pas de fruit dans la démo")
	Demo.forced = -1
	save.delete_save(PATH)
	main.queue_free()
	await process_frame
	await _real_flow(save)
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)


## Le vrai chemin : partie ouverte par le menu, fruit cueilli, sauvegarde, scène rechargée.
func _real_flow(save) -> void:
	print("Fruit cueilli en jeu : sauvegarde et rechargement")
	var flow = root.get_node("Flow")
	save.delete_save()
	started.clear()
	flow.new_game()
	for i in 5:
		await process_frame
	var m = current_scene
	check(m != null and m.has_method("save_game") and m.autosave_enabled, "partie ouverte par le menu")
	game.add_xp(900.0)
	var lvl: int = game.level
	game.flags["ronce_boss_vaincu"] = true
	game.flags[ENDING] = true
	m.ground.paint(Vector2(900, 900), 400.0, 1.0)
	m.player.position = Vector2(700, 700)
	await process_frame
	var life_before: float = m.ground.total
	m.cycle_fruit.grown = 1.0
	m.cycle_fruit.pick()
	for i in 8:
		await process_frame
	var m2 = current_scene
	check(m2 != null and m2 != m and m2.has_method("save_game"), "la scène de jeu est rechargée")
	check(game.cycle == 2 and game.level == lvl, "cycle 2, niveau %d gardé" % lvl)
	check(started == [2], "Game.cycle_started(2) émis après le rechargement (%s)" % str(started))
	check(m2.player.position.length() < 10.0, "le héros repart de la graine")
	check(m2.ground.total < life_before, "le sol n'est plus purifié (%.0f → %.0f)" % [life_before, m2.ground.total])
	check(not game.flags.has("ronce_boss_vaincu") and game.flags.get("cycle_wave", 0) == 2, "boss remis à zéro, vague en attente")
	check(int(save.peek().get("cycle", 0)) == 2, "la sauvegarde est au cycle 2")
	m2.autosave_enabled = false
	save.delete_save()


func _touches(n: Dictionary) -> bool:
	for m in n["neighbors"]:
		if game.allocated.has(m):
			return true
	return false


## Règle de lecture de cycles.json, sur des données à part.
func _rules() -> void:
	print("Lecture des réglages")
	var d := {
		"cycles": {"1": {"a": 1.0, "b": "un"}, "2": {"b": "deux", "m": {"x": 1}}, "3": {"a": 2.0}},
		"per_cycle_after": {"a": 0.5},
		"caps": {"a": 3.0},
	}
	check(cycles.resolve(d, "a", 0, 1) == 1.0, "cycle 1 lu tel quel")
	check(cycles.resolve(d, "a", 0, 2) == 1.0, "cycle 2 sans la clé : retombe sur le cycle 1 (pas de montée avant le dernier cycle décrit)")
	check(cycles.resolve(d, "a", 0, 3) == 2.0, "cycle 3 lu tel quel")
	check(cycles.resolve(d, "a", 0, 4) == 2.5 and cycles.resolve(d, "a", 0, 5) == 3.0, "au-delà, la clé monte de per_cycle_after par cycle")
	check(cycles.resolve(d, "a", 0, 40) == 3.0, "jusqu'au plafond (caps)")
	check(cycles.resolve(d, "b", "", 9) == "deux", "une clé sans montée reste au dernier cycle qui la donne")
	check(cycles.resolve(d, "z", 42, 2) == 42, "clé absente : valeur par défaut")
	var m: Dictionary = cycles.resolve(d, "m", {}, 2)
	m["x"] = 99
	check(d["cycles"]["2"]["m"]["x"] == 1, "les dictionnaires renvoyés sont des copies")
	var real: Dictionary = cycles.load_data()
	check(real.has("_doc") and real.get("cycles", {}).has("1"), "data/cycles.json se lit (_doc, cycle 1)")
	for key in ["threat_floor", "mix", "elites", "bosses", "tint", "grafts", "crown"]:
		check(real["cycles"]["1"].has(key), "le cycle 1 décrit « %s »" % key)
