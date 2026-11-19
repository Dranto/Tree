## Prismeur (région d'Aube) : garde ses distances (keep_min à keep_max, fuit à « flee » fois sa
## vitesse s'il est serré), vise en annonçant un couloir au sol (« windup », largeur « beam_width »,
## portée « range ») puis tire un rayon de lumière instantané : le joueur dans le couloir à cet
## instant est blessé (« beam_damage »). Le rayon reste visible « beam_time » secondes (état
## "recover"). L'esquive passe au travers.
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	match e.state:
		"windup":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = "recover"
				e.state_t = float(data.get("beam_time", 0.3))
				e.strike_t = 0.0
				var p = e.main.player
				if p.invuln <= 0.0 and in_beam(e, p.position, p.radius):
					p.take_hit(float(data["beam_damage"]) * e.damage_scale, e)
			return
		"recover":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = ""
				e.cd = float(data["cooldown"]) * e.cd_mult
			return
	if e.cd <= 0.0 and dist < float(data["range"]) * 0.9 and dist > float(data["keep_min"]) * 0.6:
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


## Vrai si un cercle (pos, rayon) est dans le couloir du rayon.
func in_beam(e, pos: Vector2, r: float) -> bool:
	var to: Vector2 = pos - e.position
	var along := to.dot(e.attack_dir)
	if along < 0.0 or along > float(e.data["range"]) + r:
		return false
	return absf(to.dot(e.attack_dir.orthogonal())) < float(e.data["beam_width"]) / 2.0 + r


func draw_attack(e, k: float, hit: float) -> void:
	var ln := float(e.data["range"])
	var w := float(e.data["beam_width"])
	var line := {"type": "ligne", "de": e.attack_dir * e.radius, "a": e.attack_dir * ln, "largeur": w}
	if e.state == "windup":
		Art.telegraph(e, line, k, -1.0, e.t)
	elif hit >= 0.0:
		Art.telegraph(e, line, 1.0, hit, e.t)
	if e.state == "recover":
		# Le rayon : un trait de lumière blanche cerclé d'or, qui s'amincit.
		var u := clampf(e.state_t / maxf(0.01, float(e.data.get("beam_time", 0.3))), 0.0, 1.0)
		var a: Vector2 = e.attack_dir * e.radius
		var b: Vector2 = e.attack_dir * ln
		e.draw_line(a, b, Color(0.95, 0.82, 0.42, 0.55 * u), w * (0.6 + 0.4 * u), true)
		e.draw_line(a, b, Color(1.0, 0.98, 0.9, 0.9 * u), w * 0.3 * u + 1.5, true)
