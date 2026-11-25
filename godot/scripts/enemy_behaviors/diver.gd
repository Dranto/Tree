## Piqueur (région de Vent) : tourne autour du joueur à distance (« orbit »), puis annonce un
## piqué (couloir au sol, « windup ») et fond sur lui en ligne droite (« dive_speed » sur
## « dive_dist »), le dépasse et remonte en glissant (« recover »). Il vole : ni la terre vivante
## ni les rochers ne l'arrêtent. Les dégâts du piqué sont « charge_damage » (lus par enemy.gd).
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	match e.state:
		"windup":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = "charge"
				e.travelled = 0.0
		"charge":
			var step_len: float = float(data["dive_speed"]) * delta
			e.position += e.attack_dir * step_len
			e.travelled += step_len
			if e.travelled >= float(data["dive_dist"]):
				e.state = "recover"
				e.state_t = float(data["recover"])
				e.cd = float(data["cooldown"]) * e.cd_mult
		"recover":
			e.state_t -= delta
			e.position += e.attack_dir * e.speed * 0.6 * delta
			if e.state_t <= 0.0:
				e.state = ""
		_:
			if e.cd <= 0.0 and dist < float(data["range"]):
				e.state = "windup"
				e.state_t = data["windup"]
				e.attack_dir = dir
				return
			# Ronde : se rapproche ou s'éloigne de l'orbite, en tournant autour du joueur.
			var orbit := float(data.get("orbit", 250.0))
			var radial := clampf((dist - orbit) / orbit * 2.5, -1.0, 1.0)
			var mv: Vector2 = dir * radial + dir.orthogonal() * e.strafe
			e.position += mv.normalized() * e.speed * lerpf(1.0, slow, 0.5) * delta


func draw_attack(e, k: float, _hit: float) -> void:
	var ln := float(e.data["dive_dist"])
	if e.state == "windup":
		Art.telegraph(e.gc, {"type": "ligne", "de": Vector2.ZERO, "a": e.attack_dir * ln, "largeur": e.radius * 2.2}, k, -1.0, e.t)
	elif e.state == "charge":
		var from: Vector2 = -e.attack_dir * e.travelled
		Art.telegraph(e.gc, {"type": "ligne", "de": from, "a": from + e.attack_dir * ln, "largeur": e.radius * 2.2}, 1.0, e.travelled / ln, e.t)
