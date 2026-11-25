## Chargeur : marque son couloir au sol (windup), charge en ligne droite, puis se remet (recover).
## Un buisson d'épines arrête la charge net.
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
			var step_len: float = float(data["charge_speed"]) * delta
			var before: Vector2 = e.position
			e.position += e.attack_dir * step_len
			e.travelled += step_len
			# Un buisson d'épines arrête la charge net (et l'étourdit un peu plus longtemps).
			var pushed: Vector2 = e.main.flora.push_out(e.position, e.radius) if e.main.flora else e.position
			if pushed.distance_squared_to(e.position) > 0.5:
				e.position = pushed
				end_charge(e, 1.6)
			elif e.travelled >= float(data["charge_dist"]) or before == e.position:
				end_charge(e, 1.0)
		"recover":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = ""
		_:
			if e.cd <= 0.0 and dist < float(data["range"]):
				e.state = "windup"
				e.state_t = data["windup"]
				e.attack_dir = dir
			else:
				e.position += dir * e.speed * slow * delta


func end_charge(e, factor: float) -> void:
	e.state = "recover"
	e.state_t = float(e.data["recover"]) * factor
	e.cd = float(e.data["cooldown"]) * e.cd_mult


func draw_attack(e, k: float, _hit: float) -> void:
	var ln := float(e.data["charge_dist"])
	if e.state == "windup":
		Art.telegraph(e.gc, {"type": "ligne", "de": Vector2.ZERO, "a": e.attack_dir * ln, "largeur": e.radius * 2.0}, k, -1.0, e.t)
	elif e.state == "charge":
		var from: Vector2 = -e.attack_dir * e.travelled
		Art.telegraph(e.gc, {"type": "ligne", "de": from, "a": from + e.attack_dir * ln, "largeur": e.radius * 2.0}, 1.0, e.travelled / ln, e.t)
