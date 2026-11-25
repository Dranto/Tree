## Tireur d'épines : garde ses distances (keep_min à keep_max), vise (windup) puis tire une épine.
extends EnemyBehavior

const Thorn = preload("res://scripts/enemy_thorn.gd")


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	if e.state == "windup":
		e.state_t -= delta
		if e.state_t <= 0.0:
			e.state = ""
			e.cd = float(data["cooldown"]) * e.cd_mult
			var th = Thorn.new()
			th.main = e.main
			th.position = e.position + e.attack_dir * (e.radius + 6.0)
			th.vel = e.attack_dir * float(data["shot_speed"])
			th.damage = float(data["shot_damage"]) * e.damage_scale
			th.life = data["shot_life"]
			e.main.projectiles_layer.add_child(th)
			e.strike_t = 0.0
		return
	if e.cd <= 0.0 and dist < float(data["range"]):
		e.state = "windup"
		e.state_t = data["windup"]
		e.attack_dir = dir
		return
	var mv := Vector2.ZERO
	if dist > float(data["keep_max"]):
		mv = dir
	elif dist < float(data["keep_min"]):
		mv = -dir
	else:
		mv = dir.orthogonal() * e.strafe * 0.6
	e.position += mv * e.speed * slow * delta


func draw_attack(e, k: float, hit: float) -> void:
	if e.state == "windup" or hit >= 0.0:
		var reach := minf(float(e.data["range"]), 440.0)
		Art.telegraph(e.gc, {"type": "ligne", "de": e.attack_dir * (e.radius + 4.0), "a": e.attack_dir * reach, "largeur": 10.0}, k, hit, e.t)
