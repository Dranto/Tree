## Test de la préparation du monde (world_preload.gd, gels aux changements de zone) :
##   - l'écran de chargement couvre le monde, met l'arbre en pause et finit ;
##   - toutes les sortes de Flétris ont leur atlas, le décor de chaque région est cuit, les Cœurs,
##     sanctuaires, autels et arènes ont leurs images, la faune est gardée, les fonds du bord sont faits ;
##   - ensuite, le héros posé dans chaque région ne déclenche plus aucune cuisson de Flétris, de lieux
##     ni de fond du bord (c'était la cause des gels à l'entrée d'une zone).
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 -s res://tests/preparation_test.gd
extends SceneTree

## Chargés au lancement (ils lisent Game, Music… des autoloads) : voir _run.
var WorldPreload
var LieuxBake
var DecorBake
var Vie
var Sprites
var Regions

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


func _run() -> void:
	WorldPreload = load("res://scripts/world_preload.gd")
	LieuxBake = load("res://scripts/world_bake/lieux_bake.gd")
	DecorBake = load("res://scripts/world_bake/decor_bake.gd")
	Vie = load("res://scripts/world_life_vie.gd")
	Sprites = load("res://scripts/sprite_bake.gd")
	Regions = load("res://scripts/regions.gd")
	WorldPreload.force = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(2)

	print("Écran de chargement")
	var prep = main.world_preload
	check(prep != null, "la partie est préparée")
	if prep == null:
		_end()
		return
	check(paused, "le monde est en pause pendant la préparation")
	var n := 0
	while not prep.done and n < 60 * 240:
		await process_frame
		n += 1
	check(prep.done, "la préparation finit (%d images)" % n)
	check(not paused, "le jeu reprend ensuite")

	print("Tout est cuit d'avance")
	var missing := []
	for kr in Sprites.all_kinds():
		if not Sprites.atlases.has(kr[0]):
			missing.append(kr[0])
	if not missing.is_empty():
		print("    atlas : ", Sprites.atlases.keys(), " ", Sprites.total_bytes() / 1048576.0, " Mo, rendus ", Sprites.evicted)
	check(missing.is_empty(), "un atlas par sorte de Flétri (%d, manquent : %s)" % [Sprites.all_kinds().size(), missing])
	var regs := {}
	for t in main.flora.trees:
		regs[DecorBake.region_of(t)] = true
	check(regs.keys().all(func(r): return DecorBake.atlases.has(r)), "le décor de chaque région (%d)" % regs.size())
	var lieux := []
	for h in main.all_hearts:
		if not LieuxBake.ready(h._bake_key()):
			lieux.append(h._bake_key())
	for s in main.sanctuaries:
		if not LieuxBake.ready(s._bake_key()):
			lieux.append(s._bake_key())
	for a in main.altars:
		if not LieuxBake.ready(a._bake_key()):
			lieux.append(a._bake_key())
	for id in main.arenas:
		var ar = main.arenas[id]
		if ar.baked and not LieuxBake.ready(ar.bake_key(ar._etat())):
			lieux.append(ar.bake_key(ar._etat()))
	check(lieux.is_empty(), "Cœurs, sanctuaires, autels et arènes cuits (manquent : %s)" % [lieux])
	check(Vie.pinned.size() == Regions.ids().size() + 1, "la faune de chaque région est gardée")
	var fields: int = main.world_edge.fields.size()
	check(not main.world_edge.prepare_fields(), "les fonds et voiles du bord sont construits (%d)" % fields)

	print("Changer de zone ne cuit plus rien")
	var lieux_before: int = LieuxBake.baked
	var sprites_before: int = Sprites.atlases.size()
	var fields_before: int = main.world_edge.fields.size()
	var wanted := 0
	for id in Regions.ids():
		main.player.position = Regions.center(id) * 0.8
		main.player.reset_physics_interpolation()
		main.camera.reset_smoothing()
		for i in 40:
			await process_frame
			wanted += Sprites._wanted.size()
	check(wanted == 0, "aucune sorte de Flétri demandée en route")
	check(Sprites.atlases.size() == sprites_before, "aucun atlas de Flétri en plus")
	check(LieuxBake.baked == lieux_before, "aucun lieu recuit (%d → %d)" % [lieux_before, LieuxBake.baked])
	check(main.world_edge.fields.size() == fields_before, "aucun fond du bord construit en route")
	_end()


func _end() -> void:
	WorldPreload.force = false
	print("")
	if failures == 0:
		print("PRÉPARATION : tout est bon")
	else:
		print("PRÉPARATION : %d échec(s)" % failures)
	if main != null:
		main.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
