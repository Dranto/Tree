## Test du prototype technique de la refonte du monde (vague 0 P) : sol en trois couches
## (world_bake/ground_layers.gd), décor cuit (world_bake/decor_bake.gd) et composé
## (world_bake/decor_compose.gd). Réglages éteints : le sol de develop, sans calque. Allumés : chaque
## carré a son calque dessiné, l'atlas du décor couvre toutes les sortes, la composition laisse la
## clairière libre et n'ajoute aucun obstacle.
## Rendu réel : tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/paysages_proto_test.gd
extends SceneTree

const Ground = preload("res://scripts/ground.gd")
const GroundLayers = preload("res://scripts/world_bake/ground_layers.gd")
# flora.gd nomme l'autoload Game : chargé à l'exécution (un préchargement ne compile pas avec -s).
var Flora
var DecorBake
var DecorCompose

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("PAYSAGES ÉCHEC : ", what)


func _initialize() -> void:
	_run.call_deferred()


func _ground(center: Vector2):
	var g = Ground.new()
	root.add_child(g)
	var cam := Camera2D.new()
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cam.position = center
	g.add_child(cam)
	cam.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	return g


func _run() -> void:
	Flora = load("res://scripts/flora.gd")
	DecorBake = load("res://scripts/world_bake/decor_bake.gd")
	DecorCompose = load("res://scripts/world_bake/decor_compose.gd")
	var center: Vector2 = DecorCompose.test_center()
	# Éteint : le sol de develop.
	var g = await _ground(center)
	_check(not g.layered, "sol en couches allumé par défaut")
	_check(not g._tiles.is_empty(), "aucun carré de sol construit")
	for t in g._tiles.values():
		_check(t["layer"] == null, "calque sur un carré, réglage éteint")
		break
	var wr = g.mat.get_shader_parameter("wash_region")
	_check(wr == null or int(wr) == -1, "lavis actif, réglage éteint")
	_check(Flora.DecorTree.baker == null, "décor cuit branché par défaut")
	g.queue_free()
	await process_frame
	# Allumé : un calque par carré, des éléments dessinés dans le Roncier.
	GroundLayers.enabled = true
	GroundLayers.reset_stats()
	g = await _ground(center)
	_check(g.layered, "sol en couches pas branché")
	var wr2 = g.mat.get_shader_parameter("wash_region")
	_check(wr2 != null and int(wr2) >= 0, "lavis sans région")
	var with_layer := 0
	for t in g._tiles.values():
		if t["layer"] != null:
			with_layer += 1
	_check(with_layer == g._tiles.size(), "carrés sans calque : %d sur %d" % [g._tiles.size() - with_layer, g._tiles.size()])
	var st := GroundLayers.stats()
	_check(st["draws"] >= with_layer and st["elements"] > with_layer * 5, "trop peu d'éléments dessinés : %s" % [st])
	# Un carré refait (vague de vie) redessine son calque.
	var d0: int = st["draws"]
	g.paint(center, 200.0, 1.5)
	await process_frame
	await RenderingServer.frame_post_draw
	_check(GroundLayers.stats()["draws"] > d0, "calque pas redessiné après la vie")
	GroundLayers.enabled = false
	# Décor cuit : un atlas pour toutes les sortes, vivantes et mortes.
	# Atlas réduit (×1, 2 variantes) : le test reste léger pour les tests lancés en parallèle (la
	# musique des boss, boss_track_test, est mesurée en temps réel).
	DecorBake.scale = 1.0
	DecorBake.ss = 1
	DecorBake.variants = 2
	await DecorBake.bake(root)
	_check(DecorBake.tex != null, "pas d'atlas du décor")
	var expected := 0
	for sd in DecorBake.sorts():
		expected += (DecorBake.variants if sd[2][0] == "" else sd[2].size()) * sd[1].size() * 2
	_check(DecorBake.cells.size() == expected, "atlas : %d images sur %d" % [DecorBake.cells.size(), expected])
	var img: Image = DecorBake.tex.get_image()
	_check(img.get_height() > 64 and img.is_invisible() == false, "atlas vide")
	# Composition : clairière libre, aucun obstacle, éléments cuits.
	var flora = Flora.new()
	flora.ground = g
	var layer := Node2D.new()
	root.add_child(layer)
	flora.trees_parent = layer
	var placed: Array = DecorCompose.spawn(flora, center)
	_check(placed.size() > 60, "composition trop pauvre : %d éléments" % placed.size())
	_check(flora.bushes.is_empty(), "la composition ajoute des obstacles")
	var inside := 0
	for t in placed:
		if t.position.distance_to(center) < DecorCompose.CLEAR - 1.0:
			inside += 1
	_check(inside == 0, "%d éléments dans la clairière" % inside)
	DecorBake.install(flora)
	await process_frame
	await RenderingServer.frame_post_draw
	_check(DecorBake.drawn > 0, "aucun élément dessiné depuis l'atlas")
	var grow = placed[1]
	grow.revive(true)
	_check(not DecorBake.draw(grow), "un arbre qui pousse doit rester dessiné en direct")
	Flora.DecorTree.baker = null
	flora.free()
	print("PAYSAGES %s" % ("réussi" if failures == 0 else "%d échecs" % failures))
	quit(1 if failures > 0 else 0)
