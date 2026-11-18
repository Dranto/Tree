## Nid de ronces : immobile, fait naître des petits (« spawn ») quand le joueur approche, au plus
## max_young en même temps.
extends EnemyBehavior


func _init() -> void:
	anchored = true


func step(e, delta: float, _dir: Vector2, dist: float, _slow: float) -> void:
	var data: Dictionary = e.data
	e.young = e.young.filter(func(y): return is_instance_valid(y) and not y.dead)
	if e.state == "windup":
		e.state_t -= delta
		if e.state_t <= 0.0:
			e.state = ""
			e.cd = data["cooldown"]
			var a := randf() * TAU
			e.main.spawn_enemy_kind(data["spawn"], e.position + Vector2.from_angle(a) * (e.radius + 12.0), e.power, e)
		return
	e.cd -= delta
	if e.cd <= 0.0 and dist < float(data["range"]) and e.young.size() < int(data["max_young"]):
		e.state = "windup"
		e.state_t = data["windup"]
