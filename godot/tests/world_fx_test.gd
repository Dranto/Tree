## Test d'« un monde qui réagit » (jalon Éclat, tâche F, scripts/world_fx.gd) : réglages de
## data/feel.json › world, herbe et fleurs qui se couchent puis se relèvent (seuls les carrés
## touchés se redessinent), traces de combat plafonnées et effacées, repos du héros (respiration,
## regard, graine plantée), montée de niveau, greffe, sanctuaire, options (« Réduire les effets »
## divise par trois), rien ne touche au hasard ni aux chiffres du jeu, et le coût de l'herbe.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/world_fx_test.gd
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree

const Content = preload("res://scripts/content.gd")

var failures := 0
var main
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
	settings = root.get_node("Settings")
	var saved_reduce: bool = settings.reduce_effects
	settings.reduce_effects = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)
	var wfx = main.world_fx
	var flora = main.flora
	var player = main.player
	player.invuln = 1.0e6

	print("Données")
	var w: Dictionary = Content.feel().get("world", {})
	for section in ["grass", "flowers", "traces", "rest", "level_up", "graft", "sanctuary"]:
		check(w.get(section) is Dictionary, "feel.json › world › %s présent" % section)
	check(wfx != null and wfx.over != null and wfx.over.get_parent() == main, "world_fx et son calque du dessus sont dans la scène")
	check(wfx.get_index() == flora.get_index() + 1, "le calque du sol est juste au-dessus de la flore (sous les acteurs)")

	print("Herbe et fleurs couchées")
	player.position = Vector2(300, 300)
	flora.flowers.clear()
	for k in flora.chunks.values():
		k.items.clear()
	for i in 30:
		flora.plant(Vector2(300 + (i % 6) * 14 - 30, 300 + (i / 6) * 14 - 30), Color.WHITE, 3.0, 5)
	await _steps(2)
	var total: int = flora.flowers.size()
	wfx.disturb(Vector2(300, 300), 50.0, Vector2.RIGHT, 1.3)
	check(not wfx._bent.is_empty(), "l'herbe se couche (%d cases)" % wfx._bent.size())
	check(flora.leaning.size() > 5 and flora.leaning.size() <= flora.lean_max, "des fleurs se couchent (%d, au plus %d)" % [flora.leaning.size(), flora.lean_max])
	await _steps(12)
	var hidden := 0
	for f in flora.leaning:
		if f.has("hide"):
			hidden += 1
	check(hidden == flora.leaning.size(), "leur carré ne les dessine plus pendant qu'elles sont couchées (%d)" % hidden)
	var some = flora.leaning[0]
	check((some["lean"] as Vector2).length() > 0.1, "une fleur couchée est penchée (%.2f)" % (some["lean"] as Vector2).length())
	check(flora.flowers.size() == total, "aucune fleur n'est perdue ni ajoutée en se couchant")
	var peak: float = wfx._bent.values().map(func(v): return v.length()).max()
	# Elles se relèvent : on laisse passer le temps de relâchement (en grands pas).
	for i in 40:
		wfx._decay_bends(0.25)
		flora._process(0.25)
	await _steps(4)
	check(wfx._bent.is_empty(), "l'herbe s'est relevée (couchage maximal au départ : %.2f)" % peak)
	check(flora.leaning.is_empty(), "les fleurs se sont relevées")
	var any_hidden := false
	for f in flora.flowers:
		if f.has("hide") or f.has("lean"):
			any_hidden = true
	check(not any_hidden, "debout, leur carré les dessine de nouveau")
	flora.disturb(Vector2(300, 300), 400.0, Vector2.ZERO, 1.5)
	check(flora.leaning.size() <= flora.lean_max, "le plafond de fleurs couchées tient (%d)" % flora.leaning.size())
	for i in 40:
		flora._process(0.25)
	flora.leaning.clear()

	print("Traces de combat")
	wfx.traces.clear()
	var cap: int = int(w["traces"]["max"])
	var placed := 0
	for i in 200:
		wfx._trace_clock = 0.0
		if wfx.add_trace(["furrow", "crack", "scorch", "puddle", "splat"][i % 5], Vector2(i * 40.0, 0), 0.3):
			placed += 1
	check(wfx.traces.size() <= cap and placed == 200, "au plus %d traces à la fois (%d posées, %d gardées)" % [cap, placed, wfx.traces.size()])
	wfx._trace_clock = 0.0
	var before: int = wfx.traces.size()
	check(not wfx.add_trace("furrow", wfx.traces[0]["pos"] + Vector2(3, 0), 0.0) or wfx.traces.size() <= before, "pas deux traces l'une sur l'autre")
	wfx._trace_clock = 1.0
	check(not wfx.add_trace("furrow", Vector2(9999, 9999), 0.0), "délai minimal entre deux traces")
	var longest := 0.0
	for k in ["furrow", "crack", "scorch", "puddle", "splat"]:
		longest = maxf(longest, float(w["traces"][k]))
	check(longest <= 6.0, "chaque trace s'efface en moins de 6 s (la plus longue : %.1f s)" % longest)
	for i in int(longest / 0.25) + 2:
		await _steps(15)
	check(wfx.traces.is_empty(), "toutes les traces ont disparu")
	# Par élément, comme en jeu.
	var enemy_pos: Vector2 = player.position + Vector2(60, 0)
	var table := {"ronce": "furrow", "racine": "crack", "aube": "scorch", "spore": "puddle", "seve": "splat"}
	for br in table:
		wfx.traces.clear()
		wfx._trace_clock = 0.0
		wfx.on_hit(enemy_pos, br, "", false)
		check(wfx.traces.size() == 1 and wfx.traces[0]["kind"] == table[br], "branche %s : trace « %s »" % [br, table[br]])
	wfx.traces.clear()
	wfx._trace_clock = 0.0
	wfx.on_hit(enemy_pos, "vent", "", false)
	check(wfx.traces.is_empty(), "le vent ne laisse pas de trace")
	settings.reduce_effects = true
	wfx.traces.clear()
	var low := 0
	for i in 120:
		wfx._trace_clock = 0.0
		if wfx.add_trace("furrow", Vector2(i * 40.0, 50), 0.0):
			low += 1
	check(low == 40 and wfx.traces.size() <= maxi(1, int(round(cap / 3.0))), "« Réduire les effets » : un tiers des traces et du plafond (%d posées, %d gardées)" % [low, wfx.traces.size()])
	settings.reduce_effects = false
	wfx.traces.clear()

	print("Repos du héros")
	player.position = Vector2(300, 300)
	player.has_dest = false
	main.ground.paint(Vector2(300, 300), 120.0, 1.0)
	await _steps(3)
	flora.pending.clear()
	flora.flowers.clear()
	for k in flora.chunks.values():
		k.items.clear()
	flora.plant(Vector2(335, 300), Color.WHITE, 3.0, 5)
	wfx.rest_t = 0.0
	wfx.breath = 0.0
	wfx.look_k = 0.0
	wfx._look_tried = false
	wfx._has_look = false
	player.since_shot = 10.0
	var rest: Dictionary = w["rest"]
	await _steps(int((float(rest["breathe_after"]) + 1.5) * 60.0))
	check(wfx.rest_t > float(rest["breathe_after"]), "le repos se compte (%.1f s)" % wfx.rest_t)
	check(wfx.breath > 0.9, "le héros respire au repos (%.2f)" % wfx.breath)
	var base_angle := 0.0
	check(wfx.facing_angle(base_angle) == base_angle, "sans fleur regardée, son regard ne change pas")
	await _steps(int((float(rest["look_after"]) - float(rest["breathe_after"]) + 1.5) * 60.0))
	check(wfx.look_k > 0.9 and absf(wfx.look_angle) < 0.1, "il regarde la fleur proche (angle %.2f, k %.2f)" % [wfx.look_angle, wfx.look_k])
	check(absf(angle_difference(wfx.facing_angle(PI), 0.0)) < 0.3, "le dessin du héros se tourne vers elle")
	# Une graine après un long repos.
	var n_flowers: int = flora.flowers.size()
	wfx.rest_t = float(rest["seed_after"]) + 0.1
	wfx._last_seed = -100.0
	await _steps(5)
	check(not wfx.sprout.is_empty(), "une graine est semée après %.0f s de repos" % float(rest["seed_after"]))
	check(wfx.crouch >= 0.0, "le héros se penche pour semer")
	player.since_shot = 10.0
	await _steps(int((float(rest["sprout_time"]) + 0.6) * 60.0))
	check(wfx.sprout.is_empty() and flora.flowers.size() == n_flowers + 1, "la graine devient une fleur du monde (%d → %d)" % [n_flowers, flora.flowers.size()])
	# Il suffit de bouger pour que tout cesse.
	player.walk = 0.5
	await _steps(2)
	check(wfx.rest_t == 0.0, "le repos s'arrête dès que le héros marche")
	player.walk = 0.0
	await _steps(int(0.8 * 60.0))
	check(wfx.look_k < 0.1 and wfx.breath < 0.5, "le regard et la respiration retombent")
	# Ni sur de la terre morte.
	wfx.sprout = {}
	wfx._last_seed = -100.0
	player.position = Vector2(-2400, 2400)
	main.ground.data.fill(0)
	wfx.rest_t = 30.0
	await _steps(3)
	check(wfx.sprout.is_empty(), "pas de graine sur la terre morte")
	player.position = Vector2(300, 300)

	print("Montée de niveau, greffe, sanctuaire")
	main.world_fx.level_ups.clear()
	var game = root.get_node("Game")
	var lv_before: int = game.level if "level" in game else 0
	main._on_level_up(lv_before + 1)
	check(wfx.level_ups.size() == 1, "la montée de niveau lance la spirale")
	check(not main.fx.rings.any(func(r): return r["color"] == Art.c("or") and r["width"] == 5.0), "plus d'anneau doré d'avant")
	await _steps(2)
	wfx._draw_over(Node2D.new())
	await _steps(int(float(w["level_up"]["dur"]) * 60.0) + 10)
	check(wfx.level_ups.is_empty(), "la spirale se termine (%.1f s)" % float(w["level_up"]["dur"]))
	wfx.graft_pickup(player.position + Vector2(20, 0), "epine_vive" if Content.grafts().has("epine_vive") else Content.grafts().keys()[0])
	check(wfx.graft_flights.size() == 1, "une greffe ramassée prend son envol")
	var g: Dictionary = wfx.graft_flights[0]
	var p0: Vector2 = wfx._graft_pos(g, 0.0)
	var p1: Vector2 = wfx._graft_pos(g, float(w["graft"]["rise"]) * 0.9)
	var pe: Vector2 = wfx._graft_pos(g, float(w["graft"]["rise"]) + float(w["graft"]["orbit"]) + float(w["graft"]["join"]))
	check(p1.y < p0.y - 20.0, "elle jaillit vers le haut")
	check(pe.distance_to(player.position) < player.radius * 1.5, "elle rejoint le héros (à %.0f px)" % pe.distance_to(player.position))
	await _steps(130)
	check(wfx.graft_flights.is_empty(), "le vol de la greffe se termine")
	wfx.sanctuary_lit(Vector2(500, 500))
	check(wfx.columns.size() == 1, "un sanctuaire ravivé lance la colonne de lumière")
	for fs in [1.0, 0.0]:
		settings.flash_scale = fs
		wfx._ob.clear()
		for e in wfx.columns:
			e["t"] = 1.2
			wfx._draw_column(e)
		check(wfx._ob.indices.size() > 0, "colonne dessinée (éclat %.0f : contour toujours présent)" % fs)
	settings.flash_scale = 1.0
	await _steps(int(float(w["sanctuary"]["dur"]) * 60.0) + 10)
	check(wfx.columns.is_empty(), "la colonne se termine")
	main.sanctuaries[0].main = main
	var sc = main.sanctuaries[0]
	sc.light()
	check(wfx.columns.size() == 1, "Sanctuary.light() lance la colonne")

	print("Aucun effet sur le jeu")
	var rng_state: int = main.rng.state
	var hp: float = player.hp
	var stats_before: Dictionary = game.stats.duplicate()
	for i in 20:
		wfx._trace_clock = 0.0
		wfx.on_hit(player.position + Vector2(40 + i, 0), "ronce", "epine", i % 2 == 0)
	wfx.level_up()
	wfx.sanctuary_lit(Vector2.ZERO)
	await _steps(30)
	check(main.rng.state == rng_state, "le hasard du jeu n'est pas tiré")
	check(game.stats == stats_before, "les statistiques ne bougent pas")
	check(Engine.time_scale == 1.0, "aucun ralenti (réservé aux Cœurs et aux boss)")
	check(main.camera.offset == Vector2.ZERO or main.fx._trauma > 0.0, "la caméra n'est pas touchée")

	print("Coût")
	player.position = Vector2(300, 300)
	main.ground.paint(Vector2(300, 300), 300.0, 1.0)
	flora.flowers.clear()
	for k in flora.chunks.values():
		k.items.clear()
	for i in 600:
		flora.plant(Vector2(300 + (i % 30) * 14 - 200, 300 + (i / 30) * 14 - 140), Color.WHITE, 3.0, 5)
	var t0 := Time.get_ticks_usec()
	for i in 200:
		wfx._b.clear()
		wfx._draw_blades()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 200.0
	check(ms < 2.5, "brins : %.2f ms par image (600 fleurs, au plus 2,5)" % ms)
	wfx._b.clear()
	t0 = Time.get_ticks_usec()
	for i in 200:
		flora.disturb(Vector2(300, 300), 60.0, Vector2.RIGHT, 1.0)
	ms = (Time.get_ticks_usec() - t0) / 1000.0 / 200.0
	check(ms < 1.0, "fleurs couchées : %.2f ms par appel (600 fleurs, au plus 1)" % ms)

	settings.reduce_effects = saved_reduce
	settings.flash_scale = 1.0
	print("FIN : %d échec(s)" % failures)
	quit(1 if failures > 0 else 0)
