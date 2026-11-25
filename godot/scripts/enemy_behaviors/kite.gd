## Cracheur de cendre : fuit le joueur trop proche, puis s'arrête et crache un éventail de cendre.
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	if e.state == "windup":
		e.state_t -= delta
		if e.state_t <= 0.0:
			e.state = ""
			e.cd = float(data["cooldown"]) * e.cd_mult
			var n := int(data.get("shots", 3))
			var spread := float(data.get("spread", 0.3))
			for i in n:
				var a: float = e.attack_dir.angle() + (i - (n - 1) / 2.0) * spread
				e._shoot(Vector2.from_angle(a), float(data["shot_speed"]), float(data["shot_damage"]), float(data["shot_life"]), "cendre")
			e.strike_t = 0.0
		return
	if e.cd <= 0.0 and dist < float(data["range"]) and dist > float(data["keep_min"]) * 0.7:
		e.state = "windup"
		e.state_t = data["windup"]
		e.attack_dir = dir
		return
	var mv := Vector2.ZERO
	if dist < float(data["keep_min"]):
		mv = -dir * float(data.get("flee", 1.3))
	elif dist > float(data["keep_max"]):
		mv = dir
	else:
		mv = dir.orthogonal() * e.strafe * 0.45
	e.position += mv * e.speed * slow * delta


func draw_attack(e, k: float, hit: float) -> void:
	if e.state == "windup" or hit >= 0.0:
		var n := int(e.data.get("shots", 3))
		var spread := float(e.data.get("spread", 0.3))
		Art.telegraph(e.gc, {"type": "cone", "centre": e.attack_dir * e.radius * 0.5, "direction": e.attack_dir.angle(), "ouverture": spread * (n - 1) + 0.22, "rayon": 240.0}, k, hit, e.t)
