## Gardien d'écorce : avance sans se jeter sur le joueur et protège les ennemis autour de lui (ils
## perdent « guard » de chaque coup tant qu'il est là).
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	if dist > float(data.get("keep_back", 0.0)):
		e.position += dir * e.speed * slow * delta
	var cut := float(data.get("guard", 0.5))
	for o in e.main.enemies_near(e.position, float(data.get("aura", 160.0)), false):
		if o != e and not o.dead and "guard_cut" in o and o.behavior != "guard":
			o.guard_cut = cut
			o.guard_time = 0.25
			o.guard_from = e.position
