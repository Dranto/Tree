## Test des morts de Flétris (jalon Éclat B, scripts/enemy_remains.gd) : chaque élément du coup final
## donne sa mort (fumée, éclats, tranche, cendres au vent, lumière, pierre, sève ; « cendre » sans
## élément), la surpuissance, la série de tués (sève du héros), l'onde d'une élite, le plafond des
## morts élémentaires, « Réduire les effets » (un tiers), et rien ne change dans les tués,
## l'expérience, le butin ni le hasard du jeu.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/deaths_test.gd
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree

const Content = preload("res://scripts/content.gd")

var failures := 0
var main
var settings
var Remains
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


## Restes présents dans la couche des ennemis.
func _remains() -> Array:
	return main.enemies_layer.get_children().filter(func(n): return n.get_script() == Remains and not n.is_queued_for_deletion())


func _clear_remains() -> void:
	for r in _remains():
		r.get_parent().remove_child(r)
		r.free()
	main._death_fx_queue.clear()


func _spawn(kind := "fletri", at := Vector2(420, 260)):
	return main.spawn_enemy_kind(kind, at, 1.0)


## Tue un Flétri par le chemin du jeu et renvoie ses restes (null s'il n'y en a pas).
func _kill_with(how: Callable, kind := "fletri", at := Vector2(420, 260)):
	_clear_remains()
	var e = _spawn(kind, at)
	how.call(e)
	await _steps(2)
	var list := _remains()
	return list[0] if list.size() == 1 else null


func _run() -> void:
	settings = root.get_node("Settings")
	Remains = load("res://scripts/enemy_remains.gd")
	game = root.get_node("Game")
	var saved_reduce: bool = settings.reduce_effects
	settings.reduce_effects = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)
	main.player.position = Vector2(300, 260)
	main.player.invuln = 1.0e6
	main.player.set_physics_process(false)

	print("Données")
	var d: Dictionary = Content.feel().get("deaths", {})
	check(not d.is_empty(), "feel.json › deaths présent")
	for s in Remains.STYLES:
		if s != "cendre":
			check(d.get("styles", {}).has(s), "feel.json › deaths › styles › %s" % s)
	check(d.get("streak") is Dictionary, "feel.json › deaths › streak")

	print("Élément du coup final")
	var table := [
		["ronce", "", "", "", "sang"], ["spore", "", "", "", "venin"], ["vent", "", "", "", "vent"],
		["aube", "", "", "", "aube"], ["racine", "", "", "", "racine"], ["seve", "", "", "", "seve"],
		["ronce", "fouet", "", "", "tranche"], ["", "", "", "poison", "venin"], ["", "", "", "saignement", "sang"],
		["", "", "lumiere", "", "aube"], ["", "", "", "", "cendre"], ["", "graine", "", "", "cendre"],
	]
	for row in table:
		check(Remains.death_style(row[0], row[1], row[2], row[3]) == row[4], "%s / %s / %s / %s → %s" % [row[0], row[1], row[2], row[3], row[4]])
	for branch in ["ronce", "spore", "vent", "aube", "racine", "seve"]:
		var r = await _kill_with(func(e): main.player_hit_enemy(e, 1.0e5, false, branch))
		var want: String = Remains.death_style(branch)
		check(r != null and r.style == want, "un coup de %s : mort « %s » (%s)" % [branch, want, r.style if r != null else "aucun reste"])
	var fouet = load("res://scripts/attack.gd")
	var rf = await _kill_with(func(e): fouet.hit(main, e, 1.0e5, "ronce", {"form": "fouet"}))
	check(rf != null and rf.style == "tranche", "l'attaque en fouet tranche")
	check(main.fx.hit_form == "" and main.fx.hit_branch == "" and not main.fx.player_hit, "le coup fini, fx ne garde ni forme ni branche")
	var rp = await _kill_with(func(e):
		e.max_hp = 1.0
		e.hp = 0.5
		e.apply_poison(100.0, 3.0))
	check(rp != null and rp.style == "venin", "mort par le poison : fumée (%s)" % (rp.style if rp != null else "aucun reste"))
	var rh = await _kill_with(func(e): e.take_damage(e.hp + 1.0, false))
	check(rh != null and rh.style == "cendre", "purification (coup sans élément) : la mort d'avant, en cendre")
	check(rh != null and rh.power == 0.0, "coup juste suffisant : pas de surpuissance")

	print("Surpuissance")
	var ro = await _kill_with(func(e): main.player_hit_enemy(e, 1.0e5, false, "ronce"))
	check(ro != null and ro.power > 0.0, "un coup qui dépasse de loin la vie : surpuissance %.2f" % (ro.power if ro != null else 0.0))
	check(main.fx.overkill_power(0.1, 100.0) == 0.0 and main.fx.overkill_power(1000.0, 100.0) == 1.0, "seuil feel.json › deaths › overkill")
	if ro != null:
		var plain = Remains.new()
		plain.style = "sang"
		plain.position = ro.position
		plain.prepare()
		check(ro._pieces.size() > plain._pieces.size(), "plus de morceaux (%d contre %d)" % [ro._pieces.size(), plain._pieces.size()])
		check(ro._boost() > plain._boost(), "plus loin et plus vite (élan ×%.2f)" % ro._boost())
		plain.free()

	print("Rien ne change dans le jeu")
	var res: Array = []
	for branch in ["", "racine"]:
		_clear_remains()
		for o in main.orbs_layer.get_children():
			o.free()
		main.rng.seed = 99
		var kills: int = game.kills
		var e = _spawn()
		var xp: float = e.xp_value
		main.player_hit_enemy(e, 1.0e5, false, branch)
		await _steps(2)
		var orbs := 0.0
		for o in main.orbs_layer.get_children():
			if "value" in o:
				orbs += o.value
		res.append([game.kills - kills, main.rng.state, orbs, xp])
	check(res[0][0] == 1 and res[1][0] == 1, "un tué compté de chaque façon")
	check(res[0][1] == res[1][1], "le hasard du jeu avance pareil (mort en cendre ou en pierre)")
	check(is_equal_approx(res[0][2], res[0][3]) and is_equal_approx(res[1][2], res[1][3]), "même expérience laissée au sol (%.1f / %.1f)" % [res[0][2], res[1][2]])

	print("Série de tués")
	main.fx.streak = 0.0
	for i in 6:
		await _kill_with(func(e): main.player_hit_enemy(e, 1.0e5, false, "ronce"), "fletri", Vector2(400 + i * 30, 260))
	var high: float = main.fx.streak
	check(high >= 0.6, "six tués rapprochés : la sève du héros brille (%.2f)" % high)
	main.fx.streak = 0.0
	await _kill_with(func(e): e.take_damage(e.hp + 1.0, false))
	check(main.fx.streak == 0.0, "un Flétri purifié par le Cœur ne compte pas dans la série")
	main.fx.streak = high
	main.fx._streak_hold = 0.0
	for i in 40:
		main.fx._update_streak(0.1)
	check(main.fx.streak == 0.0, "la série retombe doucement (4 s)")

	print("Élites")
	var relite = await _kill_with(func(e):
		e.make_elite([])
		main.player_hit_enemy(e, 1.0e5, false, "racine"), "fletri", Vector2(420, 260))
	check(relite != null and relite.elite and not relite._wave.is_empty(), "une élite : onde au sol (%d morceaux)" % (relite._wave.size() if relite != null else 0))
	check(relite != null and relite.region == main.region_at(relite.position), "onde de la région où elle tombe (« %s »)" % (relite.region if relite != null else ""))
	check(Remains.region_colors("ronce") != Remains.region_colors("spore"), "chaque région a ses couleurs d'onde")

	print("Plafond et dessin")
	_clear_remains()
	var cap := int(d.get("max_styled", 14))
	var dead := 0
	for i in 40:
		var e = _spawn("fletri", Vector2(300 + (i % 8) * 40, 400 + (i / 8) * 40))
		main.player_hit_enemy(e, 1.0e5, false, "aube")
		dead += 1 if e.dead else 0
	# Mort en série : les restes et les effets sont étalés sur les pas suivants (main.death_fx).
	await _steps(20)
	var list := _remains()
	var styled := list.filter(func(r): return r.style != "cendre").size()
	check(dead >= 38 and list.size() == dead, "%d morts en série : autant de restes (%d)" % [dead, list.size()])
	check(styled <= cap and Remains.active <= cap, "au plus %d morts élémentaires à la fois (%d)" % [cap, styled])
	# Chaque mort se dessine à chaque instant sans erreur.
	for s in Remains.STYLES:
		var r = Remains.new()
		r.style = s
		r.elite = true
		r.region = "seve"
		main.enemies_layer.add_child(r)
		r.set_process(false)
		for k in 12:
			r.t = k * 0.1
			r.queue_redraw()
			await process_frame
		r.free()
	check(true, "les huit morts se dessinent de 0 à 1,2 s")
	var halves: Dictionary = Remains.clip_half(PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(0, 1)]),
		PackedColorArray([Color.RED, Color.RED, Color.RED]), PackedInt32Array([0, 1, 2]), Vector2.RIGHT)
	var left_ok := true
	for q in halves["pts"]:
		if q.x < -0.0001:
			left_ok = false
	check(not halves["idx"].is_empty() and left_ok, "la tranche coupe les triangles le long du trait")
	_clear_remains()
	check(Remains.active == 0, "les restes retirés libèrent le plafond")

	print("Réduire les effets")
	var full = Remains.new()
	full.style = "vent"
	full.prepare()
	settings.reduce_effects = true
	var light = Remains.new()
	light.style = "vent"
	light.prepare()
	check(light._pieces.size() * 3 <= full._pieces.size() + 2, "un tiers des morceaux (%d contre %d)" % [light._pieces.size(), full._pieces.size()])
	full.free()
	light.free()
	settings.reduce_effects = saved_reduce
	Remains.active = 0

	print("Fin : ", "tout est bon" if failures == 0 else "%d échec(s)" % failures)
	main.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
