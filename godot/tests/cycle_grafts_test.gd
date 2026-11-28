## Test des greffes de cycle et de la couronne du New Game+ (jalon 14 G) : greffes « min_cycle »
## jamais tirées au cycle 1 et tirées à partir de leur cycle, autel, secret et boss qui donnent une
## greffe de cycle quand leur greffe prévue est déjà possédée (data/cycles.json › grafts), couronne
## qui gagne un emplacement par cycle terminé jusqu'au plafond de crown.json, panneau de la couronne
## à 17 emplacements et plus (médaillons qui ne se touchent pas), sauvegarde inchangée (version 9).
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/cycle_grafts_test.gd
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree

const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")
const PATH := "user://tests/cycle_grafts_test.json"

var failures := 0
var main
var game
var cycles


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


func _place(pos: Vector2) -> void:
	main.player.position = pos
	main.player.hp = 1.0e6
	main.player.invuln = 1000.0


func _pickups() -> Array:
	return main.orbs_layer.get_children().filter(func(g): return "graft_id" in g and not g.is_queued_for_deletion())


func _clear_pickups() -> void:
	for g in _pickups():
		g.queue_free()
	game.grafts_on_ground = {}


## Greffes de cycle : id → premier cycle.
func _cycle_grafts() -> Dictionary:
	var out := {}
	for id in Content.grafts():
		if game.graft_min_cycle(id) >= 2:
			out[id] = game.graft_min_cycle(id)
	return out


## Tire toutes les greffes d'une source jusqu'à épuisement (sans les garder) et renvoie les tirées.
func _drain(source: String) -> Array:
	var got: Array = []
	var saved: Array = game.graft_inventory.duplicate()
	while true:
		var g: String = game.roll_graft(source)
		if g == "" or got.has(g):
			break
		got.append(g)
		game.graft_inventory.append(g)
	game.graft_inventory = saved
	return got


func _run() -> void:
	game = root.get_node("Game")
	cycles = root.get_node("Cycles")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))

	print("Données")
	var errs: PackedStringArray = Content.validate()
	check(errs.is_empty(), "données valides" + ("" if errs.is_empty() else " : " + "; ".join(errs)))
	var cg := _cycle_grafts()
	check(cg.size() >= 6 and cg.size() <= 10, "%d greffes de cycle" % cg.size())
	var shapes := {}
	for id in cg:
		var g: Dictionary = Content.grafts()[id]
		shapes[str(g.get("shape", ""))] = true
		check(Loc.data(str(g["name"])) != "" and str(g.get("desc", "")) != "", "« %s » a un nom et une description" % g["name"])
		for src in g.get("sources", []):
			check(src in Content.GRAFT_SOURCES, "« %s » : source « %s » connue" % [id, src])
	for sh in ["fruit", "fanee", "cerne", "pepin"]:
		check(shapes.has(sh), "forme de cycle « %s » portée par une greffe" % sh)
	for n in [2, 3]:
		for src in cycles.value("grafts", [], n):
			check(src in Content.GRAFT_SOURCES, "cycle %d : source de remplacement « %s » connue" % [n, src])
	check(cycles.value("grafts", null, 1) is Array and cycles.value("grafts", null, 1).is_empty(), "cycle 1 : aucune greffe de cycle en remplacement")

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.autosave_enabled = false
	main.spawn_paused = true

	print("Cycle 1 : aucune greffe de cycle")
	check(cycles.current() == 1, "première aventure")
	var all_sources: Array = []
	for src in Content.GRAFT_SOURCES:
		for g in _drain(src):
			all_sources.append(g)
	var leaked := all_sources.filter(func(g): return cg.has(g))
	check(not all_sources.is_empty() and leaked.is_empty(), "aucune greffe de cycle tirée au cycle 1 (%d tirages)%s" % [all_sources.size(), "" if leaked.is_empty() else " : " + ", ".join(leaked)])
	check(game.reward_graft("greffe_soeurs", "autel") == "greffe_soeurs", "un autel donne sa greffe prévue")
	game.graft_inventory.append("greffe_soeurs")
	check(game.reward_graft("greffe_soeurs", "autel") == "", "cycle 1 : greffe prévue déjà possédée, rien")
	game.graft_inventory.erase("greffe_soeurs")

	print("Cycle 2 : greffes de cycle")
	cycles.forced = 2
	var c2: Array = cg.keys().filter(func(id): return cg[id] <= 2)
	var c3: Array = cg.keys().filter(func(id): return cg[id] == 3)
	var drawn: Array = []
	for src in Content.GRAFT_SOURCES:
		for g in _drain(src):
			if cg.has(g) and not drawn.has(g):
				drawn.append(g)
	c2.sort()
	drawn.sort()
	check(drawn == c2, "au cycle 2, les greffes de cycle 2 sortent (%d), pas celles du cycle 3" % drawn.size())
	# Toutes les greffes ordinaires sont déjà trouvées (cycle d'avant) : autel, secret et boss donnent une greffe de cycle.
	var saved_inv: Array = game.graft_inventory.duplicate()
	for id in Content.grafts():
		if not cg.has(id):
			game.graft_inventory.append(id)
	for src in ["autel", "secret", "boss"]:
		var fixed := ""
		for id in Content.grafts():
			if not cg.has(id) and src in Content.grafts()[id].get("sources", []):
				fixed = id
				break
		var g: String = game.reward_graft(fixed, src)
		var expect := c2.any(func(id): return src in Content.grafts()[id].get("sources", []))
		check((g != "" and cg.has(g) and cg[g] <= 2) if expect else g == "", "%s dont la greffe est déjà trouvée : %s" % [src, g if g != "" else "rien"])
	var elite: Array = _drain("elite")
	check(not elite.is_empty() and elite.all(func(id): return cg.has(id)), "élites : seulement des greffes de cycle une fois les autres trouvées (%s)" % ", ".join(elite))

	print("Autel ravivé au cycle 2")
	var altar = main.altars.filter(func(a): return a.kind == "autel" and str(a.data.get("graft", "")) != "")[0]
	_clear_pickups()
	_place(altar.position)
	await _steps(int(altar.HOLD["autel"] * 60.0) + 5)
	await _steps(2)
	var drops := _pickups()
	check(drops.size() == 1 and cg.has(drops[0].graft_id), "l'autel donne une greffe de cycle (%s)" % (drops[0].graft_id if drops.size() > 0 else "rien"))
	if drops.size() == 1:
		var gid: String = drops[0].graft_id
		_place(drops[0].position)
		await _steps(30)
		check(game.has_graft(gid), "greffe de cycle ramassée")
	_clear_pickups()

	print("Cycle 3")
	cycles.forced = 3
	drawn = []
	game.graft_inventory = saved_inv.duplicate()
	for src in Content.GRAFT_SOURCES:
		for g in _drain(src):
			if cg.has(g) and not drawn.has(g):
				drawn.append(g)
	var all_cg: Array = cg.keys()
	all_cg.sort()
	drawn.sort()
	check(drawn == all_cg and not c3.is_empty(), "au cycle 3, toutes les greffes de cycle sortent (%d dont %d nouvelles)" % [drawn.size(), c3.size()])

	print("Couronne")
	var cr := Content.crown()
	cycles.forced = 1
	game.crown_kept = 0
	var full: int = game.crown_max()
	check(full == 15, "fin de première aventure : %d emplacements" % full)
	check(game.crown_next_cycle() == 0, "au cycle 1, la couronne n'annonce rien du cycle suivant")
	game.crown_kept = full
	var sizes: Array = []
	for n in range(1, 9):
		cycles.forced = n
		sizes.append(game.crown_size())
	check(sizes[1] == full + 1 and sizes[2] == full + 2 and sizes[3] == full + 3, "un emplacement de plus par cycle terminé (%s)" % str(sizes))
	check(sizes.max() == int(cr["max"]) and sizes[7] == int(cr["max"]), "plafond de %d emplacements" % int(cr["max"]))
	for i in range(1, sizes.size()):
		check(sizes[i] >= sizes[i - 1], "cycle %d : la couronne ne rétrécit pas" % (i + 1))
	cycles.forced = 2
	check(game.crown_max() == game.crown_size() and game.crown_next_cycle() == 1, "cycle 2 : tout ouvert, un bourgeon pour le cycle suivant")
	cycles.forced = 8
	check(game.crown_next_cycle() == 0, "plafond atteint : plus de bourgeon")

	print("Panneau à 17 emplacements et plus")
	var gp = main.tree_ui.grafts_panel
	if game.graft_inventory.is_empty():
		game.give_graft("greffe_soeurs")
	for n in [1, 2, 3, 8]:
		cycles.forced = n
		if n == 1:
			game.crown_kept = 0
		else:
			game.crown_kept = full
		gp.refresh()
		await process_frame
		var cv = gp.crown_view
		cv.size = Vector2(cv.size.x, cv.custom_minimum_size.y)
		var pts: Array = cv.slot_points()
		var want: int = game.crown_max() + game.crown_next_cycle()
		var gap := INF
		for i in pts.size():
			gap = minf(gap, (pts[i] as Vector2).distance_to(pts[(i + 1) % pts.size()]))
		var r: float = 14.5 * cv.slot_scale()
		check(pts.size() == want, "cycle %d : %d emplacements dessinés" % [n, want])
		check(gap >= 2.0 * r + 2.0, "cycle %d : médaillons séparés (écart %.1f, diamètre %.1f)" % [n, gap, 2.0 * r])
		check(cv.size.x <= gp.WIDTH + 0.5, "cycle %d : la couronne tient dans la largeur du panneau" % n)
		var aimed := true
		for i in pts.size():
			aimed = aimed and cv.slot_at(pts[i]) == i
		check(aimed, "cycle %d : chaque emplacement se vise au pointeur" % n)
	cycles.forced = 2
	game.crown_kept = full
	gp.refresh()
	gp.set_hover_slot(game.crown_max())
	var txt := " ".join(gp._detail.get_children().map(func(l): return l.text))
	check("cycle suivant" in txt, "bourgeon du cycle suivant : sa fiche le dit")
	gp.set_hover_slot(-1)
	var any_cycle: String = cg.keys()[0]
	game.give_graft(any_cycle)
	gp.refresh()
	gp.set_hover_graft(any_cycle)
	txt = " ".join(gp._detail.get_children().map(func(l): return l.text))
	check("cycle" in txt, "fiche d'une greffe de cycle : elle dit son cycle")
	gp.set_hover_graft("")

	print("Sauvegarde")
	var save = root.get_node("SaveGame")
	game.crown_kept = full
	game.cycle = 2
	cycles.forced = -1
	game._fit_crown()
	var last: int = game.crown_size() - 1
	check(game.place_graft(last, any_cycle), "greffe de cycle posée dans le dernier emplacement (%d)" % (last + 1))
	var data: Dictionary = save.capture(main)
	check(int(data.get("version", 0)) == 9, "sauvegarde toujours en version 9")
	check(save.write(data, PATH), "sauvegarde écrite")
	game.crown = []
	game.graft_inventory = []
	check(save.load_into(main, PATH), "sauvegarde relue")
	check(game.graft_of(last) == any_cycle and game.has_graft(any_cycle), "la greffe de cycle reste posée après rechargement")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

	print("ÉCHECS : %d" % failures if failures > 0 else "OK : tout passe")
	quit(1 if failures > 0 else 0)
