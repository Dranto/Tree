## Test du sol en trois couches (refonte du monde, vague 1 S : world_bake/ground_layers.gd, par défaut)
## et du prototype du décor (vague 0 P) : décor cuit (world_bake/decor_bake.gd) et composé
## (world_bake/decor_compose.gd). Sol : chaque carré a son calque, tiré une fois ; une vague de vie et
## la purification ne refont que le rendu ; chaque région a sa palette. Décor : l'atlas couvre toutes
## les sortes, la composition laisse la clairière libre et n'ajoute aucun obstacle.
## Rendu réel : tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/paysages_proto_test.gd
extends SceneTree

const Ground = preload("res://scripts/ground.gd")
const GroundLayers = preload("res://scripts/world_bake/ground_layers.gd")
const Regions = preload("res://scripts/regions.gd")
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
	# Sol en couches (vague 1 S) : allumé par défaut, un calque par carré.
	var g = await _ground(center)
	_check(g.layered, "sol en couches éteint par défaut")
	_check(not g._tiles.is_empty(), "aucun carré de sol construit")
	var with_layer := 0
	for t in g._tiles.values():
		if t["layer"] != null:
			with_layer += 1
	_check(with_layer == g._tiles.size(), "carrés sans calque : %d sur %d" % [g._tiles.size() - with_layer, g._tiles.size()])
	var st := GroundLayers.stats()
	_check(st["draws"] >= with_layer and st["elements"] > with_layer * 5, "trop peu d'éléments dessinés : %s" % [st])
	# Monde tout mort : les calques ne tirent que la terre morte.
	for t in g._tiles.values():
		_check(t["layer"].mask == GroundLayers.DEAD, "carré mort avec des sortes vivantes : %d" % t["layer"].mask)
		break
	# La vie arrive : le carré tire une fois ses éléments vivants et ses pousses...
	g.paint(center, 200.0, 1.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var d1: int = GroundLayers.stats()["draws"]
	_check(d1 > st["draws"], "calque pas complété quand la vie arrive")
	var touched := 0
	for t in g._tiles.values():
		if (t["rect"] as Rect2).has_point(center):
			touched += 1
			_check(t["layer"].mask == GroundLayers.DEAD | GroundLayers.ALIVE | GroundLayers.FRONT, "carré ravivé sans toutes ses sortes")
	_check(touched == 1, "carré du centre introuvable")
	# ... puis une vague de vie ne refait que le rendu, pas le dessin.
	var r0: int = g.tiles_redrawn
	g.paint(center + Vector2(30, 0), 160.0, 1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	_check(g.tiles_redrawn > r0, "carrés pas refaits après la vie")
	_check(GroundLayers.stats()["draws"] == d1, "calque redessiné par une vague de vie")
	# Purification : la terre morte s'apaise dans le shader (tons mélangés), sans redessin.
	var reg: String = Regions.region_at(center)
	var dead0: PackedVector3Array = g.mat.get_shader_parameter("region_dead_mid")
	g.set_purified(reg, 1.0)
	var dead1: PackedVector3Array = g.mat.get_shader_parameter("region_dead_mid")
	var ri: int = Regions.ids().find(reg)
	_check(not dead0[ri].is_equal_approx(dead1[ri]), "la terre morte ne s'apaise pas")
	await process_frame
	await RenderingServer.frame_post_draw
	_check(GroundLayers.stats()["draws"] == d1, "calque redessiné par la purification")
	# Six régions : chacune a sa palette du monde, aux trois états.
	for id in Regions.ids():
		var pal := GroundLayers.world_palette(id)
		for etat in ["fletri", "apaise", "ravive"]:
			for k in ["sol", "sol_clair", "sol_sombre", "matiere", "touffe", "touffe_2", "fleur", "pierre"]:
				_check(pal[etat].has(k), "palette %s/%s sans « %s »" % [id, etat, k])
	var rv: PackedVector3Array = g.mat.get_shader_parameter("region_alive_mid")
	for i in rv.size():
		for j in range(i + 1, rv.size()):
			_check(not rv[i].is_equal_approx(rv[j]), "deux régions ravivées de même couleur : %s et %s" % [Regions.ids()[i], Regions.ids()[j]])
	# Décor cuit : un atlas pour toutes les sortes, vivantes et mortes.
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
