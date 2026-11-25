## Souffleur (région de Vent) : garde ses distances (keep_min à keep_max), enfle en annonçant un
## cône au sol (« windup », ouverture « cone », portée « range »), puis souffle : le joueur pris dans
## le cône est blessé (« blow_damage ») et repoussé (« blow_push » px/s pendant « blow_time »).
## L'esquive passe au travers. Pendant le souffle, l'état est "recover" (et e.travelled vaut 1 si
## le joueur a été pris).
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	match e.state:
		"windup":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = "recover"
				e.state_t = float(data["blow_time"])
				e.strike_t = 0.0
				var p = e.main.player
				e.travelled = 0.0
				if p.invuln <= 0.0 and in_cone(e, p.position, p.radius):
					p.take_hit(float(data["blow_damage"]) * e.damage_scale, e)
					e.travelled = 1.0
			return
		"recover":
			e.state_t -= delta
			var p = e.main.player
			if e.travelled > 0.0 and p.dash_time <= 0.0:
				p.position += e.attack_dir * float(data["blow_push"]) * delta
			if e.state_t <= 0.0:
				e.state = ""
				e.cd = float(data["cooldown"]) * e.cd_mult
			return
	if e.cd <= 0.0 and dist < float(data["range"]) * 0.9:
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
		mv = dir.orthogonal() * e.strafe * 0.5
	e.position += mv * e.speed * slow * delta


## Vrai si un cercle (pos, rayon) est dans le cône du souffle.
func in_cone(e, pos: Vector2, r: float) -> bool:
	var to: Vector2 = pos - e.position
	var d := to.length()
	if d > float(e.data["range"]) + r:
		return false
	if d < e.radius + r:
		return true
	var half := float(e.data["cone"]) / 2.0 + asin(clampf(r / d, 0.0, 1.0))
	return absf(angle_difference(e.attack_dir.angle(), to.angle())) <= half


func draw_attack(e, k: float, hit: float) -> void:
	var cone := {"type": "cone", "centre": e.attack_dir * e.radius * 0.6, "direction": e.attack_dir.angle(), "ouverture": float(e.data["cone"]), "rayon": float(e.data["range"])}
	if e.state == "windup":
		Art.telegraph(e.gc, cone, k, -1.0, e.t)
	elif hit >= 0.0:
		Art.telegraph(e.gc, cone, 1.0, hit, e.t)
	if e.state == "recover":
		# Le souffle : traits clairs du vent qui filent dans le cône.
		var u := 1.0 - clampf(e.state_t / maxf(0.01, float(e.data["blow_time"])), 0.0, 1.0)
		var reach := float(e.data["range"])
		for i in 5:
			var a: float = e.attack_dir.angle() + (i - 2) * float(e.data["cone"]) / 5.0
			var d := Vector2.from_angle(a)
			var s := reach * (0.2 + 0.7 * fposmod(u + i * 0.17, 1.0))
			e.gc.draw_line(d * s, d * (s + 46.0), Color(Art.ec("vent", "clair"), 0.8 * (1.0 - u)), Art.TRAIT, true)
