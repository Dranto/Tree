## Lichen cuirassé (marais de Spore) : lent et couvert d'une croûte qui boit le poison
## (« poison_resist » dans enemies.json) et une part des coups de Spore. Près du joueur, il se
## dresse (cercle annoncé au sol) puis s'abat de tout son poids. Il oblige à varier : coups directs,
## autre branche, ou le tenir à distance.
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	if e.state == "windup":
		e.state_t -= delta
		if e.state_t <= 0.0:
			e.state = ""
			e.cd = float(data["cooldown"]) * e.cd_mult
			var p = e.main.player
			if p.position.distance_to(e.position) < float(data["slam_radius"]) + p.radius * 0.5:
				p.take_hit(float(data["slam_damage"]) * e.damage_scale, e)
			e.strike_t = 0.0
			if e.main.get("fx") != null:
				e.main.fx.shake(2.5)
		return
	if e.cd <= 0.0 and dist < float(data["range"]):
		e.state = "windup"
		e.state_t = data["windup"]
		e.attack_dir = dir
		return
	e.position += dir * e.speed * slow * delta


func draw_attack(e, k: float, hit: float) -> void:
	if e.state == "windup" or hit >= 0.0:
		Art.telegraph(e.gc, {"type": "cercle", "centre": Vector2.ZERO, "rayon": float(e.data["slam_radius"])}, k, hit, e.t)
