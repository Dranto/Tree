## Crapaud des sources (vallée de Sève) : s'approche, puis se ramasse (« windup ») en marquant au
## sol le cercle où il va retomber, là où se tenait le joueur ; il bondit (« leap_time »), retombe
## dans une gerbe d'eau (« splash_radius », « splash_damage ») et reste un instant sonné
## (« recover »). En l'air, il passe par-dessus le décor. Sortir du cercle suffit.
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	match e.state:
		"windup":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = "leap"
				e.state_t = float(data["leap_time"])
				e.set_meta("from", e.position)
		"leap":
			e.state_t -= delta
			var from: Vector2 = e.get_meta("from", e.position)
			var u := clampf(1.0 - e.state_t / float(data["leap_time"]), 0.0, 1.0)
			e.position = from.lerp(target(e), u)
			if e.state_t <= 0.0:
				land(e)
		"recover":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = ""
		_:
			if e.cd <= 0.0 and dist < float(data["range"]):
				e.state = "windup"
				e.state_t = data["windup"]
				e.attack_dir = dir
				e.set_meta("cible", e.main.player.position)
				return
			# Petits sauts : il avance par à-coups.
			var hop := 0.4 + 0.9 * maxf(0.0, sin(e.t * 6.0))
			e.position += dir * e.speed * hop * slow * delta


## Où il retombe : la place du joueur au début de l'annonce (en monde).
static func target(e) -> Vector2:
	return e.get_meta("cible", e.position)


func land(e) -> void:
	var data: Dictionary = e.data
	e.position = target(e)
	if e.main.get("flora"):
		e.position = e.main.flora.push_out(e.position, e.radius)
	e.state = "recover"
	e.state_t = float(data["recover"])
	e.cd = float(data["cooldown"]) * e.cd_mult
	e.strike_t = 0.0
	var p = e.main.player
	var r := float(data["splash_radius"])
	if p.position.distance_to(e.position) < r + p.radius * 0.5:
		p.take_hit(float(data["splash_damage"]) * e.damage_scale, e)
	if e.main.get("fx") != null:
		e.main.fx.ring(e.position, e.radius, r, 0.3, Color(Art.ec("seve", "clair"), 0.8), 3.0)


## Hauteur du bond (0 au sol, 1 au sommet), pour le dessin.
static func height(e) -> float:
	if e.state != "leap":
		return 0.0
	var u := clampf(1.0 - e.state_t / float(e.data["leap_time"]), 0.0, 1.0)
	return sin(PI * u)


func draw_attack(e, k: float, hit: float) -> void:
	var r := float(e.data["splash_radius"])
	if e.state == "windup":
		Art.telegraph(e, {"type": "cercle", "centre": target(e) - e.position, "rayon": r}, k, -1.0, e.t)
	elif e.state == "leap":
		var u := clampf(1.0 - e.state_t / float(e.data["leap_time"]), 0.0, 1.0)
		Art.telegraph(e, {"type": "cercle", "centre": target(e) - e.position, "rayon": r}, 1.0, -1.0, e.t)
		# L'ombre du crapaud file vers le point de chute.
		e.draw_colored_polygon(Art.ellipse(Vector2.ZERO, e.radius * (1.0 - 0.3 * sin(PI * u)), e.radius * 0.5, 12), Color(Art.c("ombre"), 0.5))
	elif hit >= 0.0:
		Art.telegraph(e, {"type": "cercle", "centre": Vector2.ZERO, "rayon": r}, 1.0, hit, e.t)


## En l'air : hauteur du bond (« lift », de 0 à 1), pour le dessin.
func pose(e, o: Dictionary) -> void:
	if e.state == "leap":
		o["lift"] = height(e)
		o["live"] = true
