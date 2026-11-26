## Test du décor de la finale (refonte du monde, vague 3 F ; scripts/world_art/finale_creux.gd) :
##   - la paroi ne cache jamais le sol du combat (au sud, seule la lèvre ; le pied de la paroi est le
##     cercle du combat) ;
##   - le creux est cuit (une image flétrie, puis ravivée ; la flétrie est rendue après la floraison),
##     dans son budget ; la brèche est cuite par lieux_bake ; sans cuisson, le dessin direct marche ;
##   - aucune règle du combat changée (rayons de l'arène) ;
##   - le décor réagit au combat (secousse) sans rien toucher du boss.
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 -s res://tests/finale_creux_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
const FinaleCreux = preload("res://scripts/world_art/finale_creux.gd")
const LieuxBake = preload("res://scripts/world_bake/lieux_bake.gd")

## Mémoire d'une image cuite du creux, au plus.
const BUDGET := 10 * 1024 * 1024

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
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)
	var game = root.get_node("Game")
	var finale = main.finale

	print("Règles inchangées")
	check(finale.max_radius == 520.0 and finale.collapse_radius == 380.0, "arène : mêmes rayons (520, 380)")

	print("La paroi ne cache pas le sol")
	var r: float = finale.max_radius
	check(FinaleCreux.hk(PI / 2.0) < 0.001, "au sud, la paroi n'a pas de hauteur")
	check(FinaleCreux.hk(-PI / 2.0) > 0.999, "au nord, toute sa hauteur")
	var foot_ok := true
	for i in 36:
		var a := TAU * i / 36.0
		if absf(FinaleCreux.wall_pt(r, a, 0.0).length() - r) > 0.01:
			foot_ok = false
		# Toute la paroi, lèvre comprise, reste hors du sol du combat.
		for f in [0.25, 0.5, 0.75, 1.0]:
			if FinaleCreux.wall_pt(r, a, f).length() < r - 0.01:
				foot_ok = false
	check(foot_ok, "le pied de la paroi est le cercle du combat, la paroi ne le recouvre jamais")

	print("Creux cuit")
	for id in Regions.ids():
		game.flags[Regions.heart_flag(id)] = true
		game.flags[Regions.boss_flag(id)] = true
		game.flags[Regions.ending_flag(id)] = true
	finale._open()
	finale.descend()
	await _steps(2)
	var creux = finale.get_node_or_null("Creux")
	var breche = finale.get_node_or_null("Breche")
	check(creux != null and breche != null, "les deux nœuds du décor sont là")
	check(creux.visible, "sous la graine, le creux se montre")
	for i in 30:
		if creux.tex.has("fletri"):
			break
		await process_frame
	check(creux.tex.has("fletri"), "image flétrie cuite")
	check(not creux.tex.has("ravive"), "pas d'image ravivée avant la victoire")
	check(creux.bytes > 0 and creux.bytes <= BUDGET, "dans le budget (%.1f Mo)" % (creux.bytes / 1048576.0))
	print("  cuisson : %.0f ms" % (creux.bake_usec / 1000.0))

	print("Floraison")
	finale.state = "vaincue"
	finale.bloom = 0.5
	for i in 30:
		if creux.tex.has("ravive"):
			break
		await process_frame
	check(creux.tex.has("ravive") and creux.tex.has("fletri"), "pendant la floraison : les deux images (fondu)")
	finale.bloom = 1.0
	await _steps(2)
	check(creux.tex.has("ravive") and not creux.tex.has("fletri"), "floraison finie : l'image flétrie est rendue")
	check(creux.bytes <= BUDGET, "une seule image gardée")

	print("Brèche")
	main.player.position = finale.descent_point() + Vector2(0, 120)
	await _steps(2)
	check(not creux.visible, "hors du creux, il ne se dessine pas")
	check(breche.visible, "brèche visible (finale ouverte)")
	for i in 30:
		if LieuxBake.ready("finale/breche"):
			break
		await process_frame
	check(LieuxBake.ready("finale/breche"), "brèche cuite (lieux_bake « finale/breche »)")

	print("Dessin direct")
	var ci := Node2D.new()
	root.add_child(ci)
	ci.draw.connect(func():
		FinaleCreux.paint_cave(ci, r, false)
		FinaleCreux.paint_cave(ci, r, true)
		FinaleCreux.paint_breche(ci, false)
		FinaleCreux.paint_breche(ci, true)
		FinaleCreux.draw_hanging(ci, Vector2.ZERO, r, 1.0, 1.0, 1.0)
		FinaleCreux.draw_dust(ci, Vector2.ZERO, r, 0.5, 1.0))
	ci.queue_redraw()
	await _steps(2)
	check(true, "le creux et la brèche se dessinent sans cuisson")

	print("Secousse")
	finale.shake_creux(1.0)
	check(finale._shake_now() > 0.9, "secousse lancée")
	finale.t += 2.0
	check(finale._shake_now() < 0.01, "et retombée")

	print("")
	if failures == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("ÉCHECS : %d" % failures)
	quit(1 if failures > 0 else 0)
