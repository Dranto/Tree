## Miroitier (région d'Aube) : garde ses distances (keep_min à keep_max), tourne son miroir vers le
## joueur en annonçant un cône au sol (« windup », ouverture « cone », portée « range »), puis jette
## un éclair de lumière crue : le joueur pris dans le cône est blessé (« flash_damage ») et ébloui
## « dazzle » secondes (player.gd › apply_dazzle : il marche plus lentement, l'écran blanchit).
## L'esquive passe au travers. Pendant l'éclair, l'état est "recover" (e.travelled vaut 1 si le
## joueur a été pris).
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	match e.state:
		"windup":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = "recover"
				e.state_t = float(data.get("flash_time", 0.3))
				e.strike_t = 0.0
				e.travelled = 0.0
				var p = e.main.player
				if p.invuln <= 0.0 and in_cone(e, p.position, p.radius):
					p.take_hit(float(data["flash_damage"]) * e.damage_scale, e)
					p.apply_dazzle(float(data["dazzle"]))
					e.travelled = 1.0
			return
		"recover":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = ""
				e.cd = float(data["cooldown"]) * e.cd_mult
			return
	if e.cd <= 0.0 and dist < float(data["range"]) * 0.85:
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


## Vrai si un cercle (pos, rayon) est dans le cône de l'éclair.
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
		Art.telegraph(e, cone, k, -1.0, e.t)
	elif hit >= 0.0:
		Art.telegraph(e, cone, 1.0, hit, e.t)
	if e.state == "recover":
		# L'éclair : un éventail de lumière blanche qui s'éteint.
		var u := 1.0 - clampf(e.state_t / maxf(0.01, float(e.data.get("flash_time", 0.3))), 0.0, 1.0)
		var reach := float(e.data["range"])
		var half := float(e.data["cone"]) / 2.0
		var a0: float = e.attack_dir.angle()
		var pts := PackedVector2Array([e.attack_dir * e.radius * 0.6])
		for i in 9:
			pts.append(Vector2.from_angle(a0 - half + 2.0 * half * i / 8.0) * reach * (0.4 + 0.6 * u))
		e.draw_colored_polygon(pts, Color(1.0, 0.97, 0.85, 0.45 * (1.0 - u)))
