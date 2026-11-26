## Scénario « demo » du banc visuel (runner.gd), joué en démo (Demo.forced = 1, posé par runner.gd
## avant la création du jeu) : la ronce épaisse qui ferme les autres régions (au bord du secteur de
## Ronce et autour de l'oasis), l'arbre avec un nœud que seul le jeu complet ouvre, la carte, puis la
## fin de la démo : la Mère-Ronce vaincue, le sceau de la graine qui pulse et la ligne dans l'herbe.
## L'arbre : les nœuds hors démo sous une ronce épaisse, de près et en vue d'ensemble.
## Joué à 1280x720 et 1280x800 (captures suffixées de la résolution). Jeu figé.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const Demo = preload("res://scripts/demo.gd")

var r
var main


func run(runner) -> void:
	r = runner
	main = r.main
	var tag: String = r._res_tag()
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	main.hud.glyphs.hide()
	var a := Regions.angle_of("ronce")
	var h := Regions.half_width()
	# Le bord du secteur de Ronce, côté Spore, puis côté Racine (la haie et la région fermée au-delà).
	await _look("demo_haie_" + tag, Vector2.from_angle(a + h - 0.12) * 1300.0)
	await _look("demo_haie_racine_" + tag, Vector2.from_angle(a - h + 0.1) * 2100.0)
	# L'oasis de la graine : la haie en arc devant les autres régions.
	await _look("demo_oasis_" + tag, Vector2(-120.0, 160.0))
	# L'arbre : un nœud flétri d'une autre région, cerclé de ronce, et son infobulle.
	var closed := -1
	for n in Game.tree.nodes:
		if n["type"] == "withered" and Demo.node_closed(n):
			closed = int(n["id"])
			break
	main.tree_ui.toggle()
	main.tree_ui.zoom = 0.9
	main.tree_ui.cam = Game.tree.nodes[closed]["pos"] + Vector2(0, 200.0 / 0.9)
	await r._frames(4)
	r._hover(closed)
	await r._frames(3)
	await r._shot("demo_arbre_" + tag, "arbre")
	r._hover(-1)
	# Vue d'ensemble : les parties fermées de l'arbre sous la ronce.
	main.tree_ui.zoom = 0.3
	main.tree_ui.cam = Game.tree.nodes[closed]["pos"] * 0.6
	await r._frames(4)
	await r._shot("demo_arbre_ensemble_" + tag, "arbre")
	main.tree_ui.toggle()
	await r._frames(2)
	# La carte : les régions fermées voilées, bordées de ronce.
	main.quest_ui.toggle("carte")
	await r._frames(3)
	await r._shot("demo_carte_" + tag, "carte")
	main.quest_ui.close()
	await r._frames(2)
	# Fin de la démo : la Mère-Ronce vaincue (reverdie déjà vue), le sceau bat, la ligne s'écrit.
	for i in Regions.heart_count("ronce"):
		Game.flags[Regions.heart_part_flag("ronce", i)] = true
	Game.flags[Regions.heart_flag("ronce")] = true
	Game.flags[Regions.boss_flag("ronce")] = true
	Game.flags[Regions.ending_flag("ronce")] = true
	await _look("demo_fin_roncier_" + tag, Vector2.from_angle(a) * 900.0, 30)
	await _look("demo_fin_sceau_" + tag, Vector2(40.0, 330.0), 120)


func _look(shot: String, pos: Vector2, frames := 4) -> void:
	await r._place_player(pos)
	main.demo_wall.ensure(Rect2(pos - Vector2(2500, 2500), Vector2(5000, 5000)))
	main.world_edge.ensure(Rect2(pos - Vector2(1500, 1000), Vector2(3000, 2000)))
	main.hud.banner_time = 0.0
	await main.world_edge.settle()
	await r._frames(frames)
	await r._shot(shot, "jeu")
