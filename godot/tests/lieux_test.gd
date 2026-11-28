## Test des lieux (refonte du monde, vague 1 C) : les Cœurs, sanctuaires et autels vus de trois quarts.
##   - les parties fixes sont cuites en images (LieuxBake) quand le lieu approche de l'écran, et
##     dessinées depuis l'atlas ensuite ; sans rendu, le dessin direct reste possible ;
##   - les pierres du sanctuaire et la table de l'autel sont dans le calque trié en profondeur ;
##   - les pierres s'allument l'une après l'autre ;
##   - crochets visuels pour les événements du monde : siege_ticked, bloomed, lit ;
##   - aucune logique de jeu changée (durées, zone, rayon du cercle).
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 -s res://tests/lieux_test.gd
extends SceneTree

const LieuxBake = preload("res://scripts/world_bake/lieux_bake.gd")
## Chargés au lancement (ils lisent Game, une autoload) : voir _run.
var Sanctuary
var Heart

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
		await process_frame


func _put(pos: Vector2) -> void:
	main.player.position = pos
	main.player.invuln = 1.0e6
	main.player.reset_physics_interpolation()
	main.camera.reset_smoothing()


## Pixels d'un blanc franc (aucun lieu n'en dessine) dans le carré de 260 px autour du sanctuaire.
func _white_near(s) -> int:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var c: Vector2 = root.get_viewport().get_canvas_transform() * s.position
	var n := 0
	for y in range(maxi(0, int(c.y) - 130), mini(img.get_height(), int(c.y) + 130)):
		for x in range(maxi(0, int(c.x) - 130), mini(img.get_width(), int(c.x) + 130)):
			var px := img.get_pixel(x, y)
			if px.r > 0.99 and px.g > 0.99 and px.b > 0.99:
				n += 1
	return n


func _run() -> void:
	Sanctuary = load("res://scripts/sanctuary.gd")
	Heart = load("res://scripts/heart.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)

	print("Règles inchangées")
	check(Sanctuary.RADIUS == 64.0 and Sanctuary.LIGHT_TIME == 3.0, "sanctuaire : même cercle, même durée")
	check(Heart.BODY_RADIUS == 44.0, "Cœur : même obstacle")

	print("Cœur cuit à l'approche")
	var h = main.hearts["ronce"]
	h.wave_base = 0
	h.wave_growth = 0
	h.big_from = 999
	h.idle_max = 0
	_put(h.center + Vector2(-400, 200))
	await _steps(12)
	var key: String = h._bake_key()
	check(LieuxBake.ready(key), "les images du Cœur sont cuites (%s)" % key)
	var cells: Dictionary = LieuxBake.sets.get(key, {}).get("cells", {})
	check(cells.has("f0") and cells.has("f1") and cells.has("p"), "flétri, flétri qui a cédé, purifié")
	check(h.body.material == LieuxBake.material(), "le Cœur se dessine avec le matériau des lieux cuits")
	for sk in LieuxBake.sets:
		print("    %s : %.1f Mo" % [sk, LieuxBake.sets[sk]["bytes"] / 1048576.0])
	check(LieuxBake.bytes > 0 and LieuxBake.bytes < LieuxBake.BUDGET, "mémoire des lieux cuits : %.1f Mo" % (LieuxBake.bytes / 1048576.0))

	print("Crochets du Cœur")
	var ticks := []
	var blooms := []
	h.siege_ticked.connect(func(k): ticks.append(k))
	h.bloomed.connect(func(w): blooms.append(w))
	h.hold_time = 2.5
	_put(h.center + Vector2(-120, 60))
	for i in 60 * 4:
		await physics_frame
		if h.state == "purifie":
			break
	check(ticks.size() == 2, "un battement par seconde tenue (%d)" % ticks.size())
	check(h.state == "purifie" and blooms == [true], "la purification fait éclore le Cœur")
	check(h.bloom > 0.0, "l'éclosion se joue (%.2f)" % h.bloom)

	print("Sanctuaire")
	var s = main.sanctuary("lisiere")
	s.frozen = false
	var pieces: Array = s._pieces
	check(pieces.size() == Sanctuary.STONES + 1, "sept pierres et la vasque")
	check(pieces.all(func(p): return p.get_parent() == main.actors_layer), "dans le calque trié en profondeur")
	check(pieces.slice(1).all(func(p): return absf(p.position.distance_to(s.position) - 70.0) < 0.5), "pierres sur le cercle, juste dans l'anneau d'or")
	var lit_count := []
	s.lit.connect(func(): lit_count.append(1))
	_put(s.position + Vector2(-300, 0))
	await _steps(10)
	check(LieuxBake.ready(s._bake_key()), "pierres et vasque cuites")
	_put(s.position)
	var first_on := -1.0
	var last_on := -1.0
	for i in 60 * 4:
		await physics_frame
		if s.progress > 1.5 and first_on < 0.0:
			first_on = s.stone_on(0)
			last_on = s.stone_on(Sanctuary.STONES - 1)
	check(first_on == 1.0 and last_on == 0.0, "à mi-chemin, la première pierre est allumée, pas la dernière")
	check(s.is_lit() and lit_count.size() == 1, "ravivé : crochet « lit »")

	print("Autel")
	var a = main.altars[0]
	check(a.body != null and a.body.get_parent() == main.actors_layer, "table de pierre dans le calque trié en profondeur")
	_put(a.position + Vector2(0, 40))
	await _steps(10)
	check(LieuxBake.ready(a._bake_key()), "table cuite")
	check(a.body.visible and a.body.modulate.a > 0.9, "visible de près")

	print("Pas de tache blanche quand les images cuites sont rendues (téléportation)")
	# Les pierres du sanctuaire ne se redessinent pas à chaque image : leurs commandes de dessin gardent
	# la texture de l'atlas. Rendue (budget dépassé après une téléportation), elle ne doit pas s'afficher
	# en tache blanche, ni tout de suite, ni une fois l'atlas recuit.
	s.frozen = true
	_put(s.position + Vector2(0, 250))
	await _steps(10)
	check(LieuxBake.ready(s._bake_key()) and (await _white_near(s)) == 0, "de près, pierres et vasque sans tache blanche")
	var epoch0: int = LieuxBake.epoch
	_put(Vector2(5000, 5000))
	await _steps(10)
	for sk in LieuxBake.sets.keys().duplicate():
		LieuxBake.release(sk)
	check(LieuxBake.epoch > epoch0, "rendre un jeu change le numéro des lieux cuits")
	_put(s.position + Vector2(0, 250))
	await _steps(2)
	check((await _white_near(s)) == 0, "juste après le rendu : pas de tache blanche (%d px)" % (await _white_near(s)))
	await _steps(40)
	check(LieuxBake.ready(s._bake_key()), "l'atlas est recuit")
	var white := 0
	for i in 5:
		await _steps(3)
		white = maxi(white, await _white_near(s))
	check(white == 0, "une fois recuit : pas de tache blanche (%d px)" % white)
	var t0 := Time.get_ticks_msec()
	while not LieuxBake._grave.is_empty() and Time.get_ticks_msec() - t0 < LieuxBake.GRAVE_MSEC * 10:   # temps réel : large, la CI est lente
		await _steps(5)
		LieuxBake.ready(s._bake_key())
	check(LieuxBake._grave.is_empty(), "les textures rendues ne s'accumulent pas")

	print("Libération")
	var n: int = main.actors_layer.get_children().filter(func(c): return c.get("sanct") != null).size()
	s.queue_free()
	await _steps(2)
	var n2: int = main.actors_layer.get_children().filter(func(c): return c.get("sanct") != null).size()
	check(n2 == n - Sanctuary.STONES - 1, "les pierres partent avec leur sanctuaire")

	print("")
	if failures == 0:
		print("LIEUX : tout est bon")
	else:
		print("LIEUX : %d échec(s)" % failures)
	main.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
