## Test du prototype technique de la refonte du monde (vague 0 P) : sol en trois couches
## (world_bake/ground_layers.gd). Réglage éteint : le sol de develop, sans calque. Allumé : chaque
## carré a son calque dessiné. Le décor composé et cuit (vague 1 D) a son test : tests/decor_test.gd.
## Rendu réel : tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/paysages_proto_test.gd
extends SceneTree

const Ground = preload("res://scripts/ground.gd")
const GroundLayers = preload("res://scripts/world_bake/ground_layers.gd")
# decor_compose.gd charge flora.gd, qui nomme l'autoload Game : chargé à l'exécution (pas de préchargement avec -s).
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
	print("PAYSAGES %s" % ("réussi" if failures == 0 else "%d échecs" % failures))
	quit(1 if failures > 0 else 0)
