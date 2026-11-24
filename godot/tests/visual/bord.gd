## Scénario « bord » du banc visuel (runner.gd) : le décor du bord du monde de chaque région, vu depuis
## le bord du monde, puis une frontière entre deux régions, un coin et la carte du monde (son cadre
## montre aussi le bord). Jeu figé.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")

var r
var main


func run(runner) -> void:
	r = runner
	main = r.main
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	main.hud.hint_time = 0.0
	for id in Regions.ids():
		await _look("bord_" + id, _edge_point(Regions.angle_of(id)))
	# Frontière entre deux régions (le bord se mêle) et un coin du monde.
	var ids := Regions.ids()
	await _look("bord_frontiere", _edge_point(Regions.angle_of(ids[0]) + Regions.half_width()))
	await _look("bord_coin", Vector2(1, 1) * (Regions.WORLD_HALF - 60.0))
	# Régions purifiées : le bord reverdit (deux régions, les autres restent mortes).
	for id in ["ronce", "spore", "aube"]:
		Game.flags[Regions.heart_flag(id)] = true
	await r._frames(240)
	for id in ["ronce", "spore", "aube"]:
		await _look("bord_vivant_" + id, _edge_point(Regions.angle_of(id)))
	await r._frames(5)
	main.player.position = Vector2(0, 600)
	main.quest_ui.toggle("carte")
	await r._frames(3)
	await r._shot("bord_carte", "carte")
	main.quest_ui.close()
	await r._frames(2)


## Point du bord du monde (à 60 px à l'intérieur) dans la direction « angle ».
func _edge_point(angle: float) -> Vector2:
	var d := Vector2.from_angle(angle)
	var k := (Regions.WORLD_HALF - 60.0) / maxf(absf(d.x), absf(d.y))
	return d * k


func _look(shot: String, pos: Vector2) -> void:
	await r._place_player(pos)
	main.world_edge.ensure(Rect2(pos - Vector2(3000, 3000), Vector2(6000, 6000)))
	main.hud.banner_time = 0.0
	await r._frames(4)
	await r._shot(shot, "jeu")
