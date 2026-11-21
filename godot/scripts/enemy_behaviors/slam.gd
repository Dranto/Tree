## Tertre de pierre (forêt pétrifiée, région de Racine) : un colosse lent qui marche droit sur le
## joueur. À portée (« range »), il lève ses deux poings de roche et marque au sol un grand cercle
## autour de lui (« windup ») ; il frappe le sol (« slam_radius », « slam_damage ») et reste un
## moment immobile (« recover »). Rien ne le pousse, et l'enracinement ne le tient pas (« no_root »).
## Sortir du cercle suffit ; il est lent : on peut le tenir à distance.
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	match e.state:
		"windup":
			e.state_t -= delta
			if e.state_t <= 0.0:
				slam(e)
		"recover":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = ""
		_:
			if e.cd <= 0.0 and dist < float(data["range"]):
				e.state = "windup"
				e.state_t = float(data["windup"])
				e.attack_dir = dir
				return
			e.position += dir * e.speed * slow * delta


func slam(e) -> void:
	var data: Dictionary = e.data
	e.state = "recover"
	e.state_t = float(data["recover"])
	e.cd = float(data["cooldown"]) * e.cd_mult
	e.strike_t = 0.0
	var p = e.main.player
	var r := float(data["slam_radius"])
	if p.position.distance_to(e.position) < r + p.radius * 0.5:
		p.take_hit(float(data["slam_damage"]) * e.damage_scale, e)
	if e.main.get("fx") != null:
		e.main.fx.ring(e.position, e.radius, r, 0.35, Color(Art.ec("racine", "clair"), 0.8), 4.0)
		e.main.fx.shake(2.5)


func draw_attack(e, k: float, hit: float) -> void:
	var r := float(e.data["slam_radius"])
	if e.state == "windup":
		Art.telegraph(e, {"type": "cercle", "centre": Vector2.ZERO, "rayon": r}, k, -1.0, e.t)
	elif hit >= 0.0:
		Art.telegraph(e, {"type": "cercle", "centre": Vector2.ZERO, "rayon": r}, 1.0, hit, e.t)
