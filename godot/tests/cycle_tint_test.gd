## Test du monde fané du cycle (New Game+, jalon 14 W : cycle_tint.gd, cycle_wave.gd) : réglages par
## cycle (nuls au cycle 1, le dernier cycle décrit vaut ensuite), étalonnage (identité au cycle 1, plus
## sombre et plus gris ensuite, encre plus marquée), et la vague de flétrissure : monde d'abord ravivé,
## puis rendu à l'état du nouveau cycle derrière le front (terre, arbres, régions), oasis gardée,
## sauvegarde pendant la vague = état d'après, drapeau levé et Flétris de retour à la fin.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/cycle_tint_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
var CycleTint
var Flora

var failures := 0
var game


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


func _sat(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


func _run() -> void:
	game = root.get_node("Game")
	CycleTint = load("res://scripts/cycle_tint.gd")
	Flora = load("res://scripts/flora.gd")

	print("Réglages")
	check(CycleTint.grade(1) == Vector4.ZERO, "cycle 1 : aucun réglage")
	var g2: Vector4 = CycleTint.grade(2)
	var g3: Vector4 = CycleTint.grade(3)
	check(g2.x > 0.0 and g2.y > 0.0 and g2.z > 0.0, "cycle 2 : plus sombre, plus gris, encre (%s)" % g2)
	check(g3.x >= g2.x and g3.y >= g2.y and g3.z >= g2.z, "cycle 3 au moins aussi fané que le 2")
	check(CycleTint.grade(7) == g3, "au-delà du cycle 3 : le dernier réglage décrit")

	print("Étalonnage")
	var green := Color(0.45, 0.62, 0.3)
	var ink := Color(0.1, 0.09, 0.08)
	CycleTint.apply(1)
	check(CycleTint.tint_rgb(green, Vector2(500, 0)) == green, "cycle 1 : couleur inchangée")
	CycleTint.apply(2)
	var t := CycleTint.tint_rgb(green, Vector2(500, 0)) as Color
	check(_lum(t) < _lum(green) and _sat(t) < _sat(green), "cycle 2 : plus sombre et plus gris")
	var ti := CycleTint.tint_rgb(ink, Vector2(500, 0)) as Color
	check(_lum(ti) / _lum(ink) < _lum(t) / _lum(green), "encre plus marquée : les tons sombres baissent davantage")
	# Vague : dedans le cycle 2, dehors le cycle 1.
	CycleTint.set_state(Vector4.ZERO, g2, Vector2.ZERO, 1000.0, 200.0, Color("#8a8478"))
	check(CycleTint.tint_rgb(green, Vector2(400, 0)) == t, "derrière le front : teinte du nouveau cycle")
	check(CycleTint.tint_rgb(green, Vector2(1600, 0)) == green, "devant le front : teinte d'avant")
	CycleTint.clear()

	print("Vague de flétrissure")
	var main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(2)
	main.autotest = false
	var g = main.ground
	g.finish_waves()
	var before: PackedByteArray = g.data.duplicate()
	var wave = main.cycle_wave
	game.flags["cycle_wave"] = 2
	wave.prepare(2)
	await _frames(2)
	check(g.ratio() > 0.99, "avant le front : toute la terre ravivée (%.2f)" % g.ratio())
	var all_purified := true
	for id in Regions.ids():
		all_purified = all_purified and g.purified_of(id) == 1.0
	check(all_purified, "avant le front : régions apaisées")
	check(main.spawn_paused, "pas de Flétris pendant la vague")
	var saved := Image.new()
	saved.load_png_from_buffer(g.export_map())
	saved.convert(Image.FORMAT_R8)
	check(saved.get_data() == before, "sauvegarde pendant la vague : la terre d'après la vague")
	wave.start()
	var steps := 0
	var mid_checked := false
	while wave.active and steps < 2000:
		wave.step(1.0 / 30.0)
		steps += 1
		if not mid_checked and wave.radius > 1600.0:
			mid_checked = true
			check(g.life_at(Vector2(900, 0)) <= Flora.ALIVE and g.life_at(Vector2(2700, 0)) > 0.9, "à mi-course : fané derrière le front, ravivé devant")
	check(not wave.active, "la vague s'arrête (%d pas)" % steps)
	check(g.data == before, "après la vague : la terre du nouveau cycle")
	check(g.life_at(Vector2(0, 120)) > Flora.ALIVE, "l'oasis de la graine reste verte")
	var alive_out := 0
	for tr in main.flora.trees:
		if is_instance_valid(tr) and tr.alive and tr.position.length() > 400.0 and g.life_at(tr.position) <= Flora.ALIVE:
			alive_out += 1
	check(alive_out == 0, "les arbres de la terre fanée ont perdu leurs feuilles (%d restants)" % alive_out)
	var none_purified := true
	for id in Regions.ids():
		none_purified = none_purified and g.purified_of(id) == 0.0
	check(none_purified, "régions de nouveau flétries")
	check(not game.flags.has("cycle_wave"), "drapeau de la vague levé")
	check(not main.spawn_paused, "les Flétris reviennent")
	check(CycleTint.to_grade == g2 and CycleTint.from_grade == g2, "teinte du cycle 2 partout")
	main.queue_free()
	await _frames(2)
	check(CycleTint.to_grade == Vector4.ZERO, "hors du jeu : teinte de la première aventure")

	print("Vague rejouée au chargement")
	# Main remet les drapeaux à zéro sans sauvegarde (Game.reset) : le nœud de la vague est ajouté
	# après coup, comme main l'ajoute après la reprise d'une partie.
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(2)
	main.cycle_wave.queue_free()
	game.flags["cycle_wave"] = 2
	var w2 = load("res://scripts/cycle_wave.gd").new()
	w2.main = main
	main.add_child(w2)
	await _frames(3)
	check(w2.cycle == 2 and w2.active, "drapeau lu au chargement : la vague part")
	check(main.ground.ratio() > 0.9, "rejouée : le monde repart ravivé")
	game.flags.erase("cycle_wave")
	main.queue_free()
	await _frames(2)

	print("Échecs : %d" % failures)
	quit(1 if failures > 0 else 0)
