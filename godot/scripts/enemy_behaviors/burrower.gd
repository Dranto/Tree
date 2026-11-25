## Mandragore (forêt pétrifiée, région de Racine) : elle marche vers le joueur, puis s'enfonce sous
## terre (« sous », au plus « burrow_time » secondes) et file vers lui (« burrow_speed ») ; on ne voit
## qu'un sillon de terre et de cailloux qui avance, et les coups directs ne l'atteignent pas (le
## poison et le saignement, si). Elle s'arrête sous le joueur et marque au sol le cercle où elle va
## jaillir (« windup ») ; elle jaillit en hurlant (« burst_radius », « burst_damage ») et reste à
## découvert un moment (« recover »), sonnée : c'est l'instant pour la frapper. Sous terre, elle ne
## blesse pas au contact. Sortir du cercle suffit.
extends EnemyBehavior

## Un « Sous terre » au plus toutes les DODGE_TEXT secondes par Mandragore.
const DODGE_TEXT := 0.8


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	match e.state:
		"sous":
			e.state_t -= delta
			# Sous terre, la terre vivante ne la gêne pas ; elle s'arrête sous le joueur.
			var step_len := float(data["burrow_speed"]) * delta
			if dist > step_len:
				e.position += dir * step_len
			else:
				e.position = e.main.player.position
			if e.state_t <= 0.0 or dist < 8.0:
				e.state = "windup"
				e.state_t = float(data["windup"])
				e.set_meta("cible", e.position)
		"windup":
			e.state_t -= delta
			if e.state_t <= 0.0:
				burst(e)
		"recover":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = ""
		_:
			if e.cd <= 0.0 and dist < float(data["range"]):
				e.state = "sous"
				e.state_t = float(data["burrow_time"])
				e.attack_dir = dir
				return
			e.position += dir * e.speed * slow * delta


## Elle jaillit : le joueur resté dans le cercle est blessé ; elle reste sonnée à découvert.
func burst(e) -> void:
	var data: Dictionary = e.data
	if e.main.get("flora"):
		e.position = e.main.flora.push_out(e.position, e.radius)
	e.state = "recover"
	e.state_t = float(data["recover"])
	e.cd = float(data["cooldown"]) * e.cd_mult
	e.strike_t = 0.0
	var p = e.main.player
	var r := float(data["burst_radius"])
	if p.position.distance_to(e.position) < r + p.radius * 0.5:
		p.take_hit(float(data["burst_damage"]) * e.damage_scale, e)
	RacineFx.sound("racine_mandragore_jaillit", "impact", e.position)
	if e.main.get("fx") != null:
		e.main.fx.ring(e.position, e.radius, r, 0.3, Color(Art.ec("racine", "clair"), 0.8), 3.0)


## Sous terre (et pendant qu'elle marque son cercle), hors d'atteinte des coups directs.
func dodge(e) -> bool:
	if not under(e):
		return false
	var now: float = e.t
	if now - float(e.get_meta("esquive", -10.0)) > DODGE_TEXT and e.main.get("fx") != null:
		e.set_meta("esquive", now)
		e.main.fx.text(e.position + Vector2(0, -e.radius * 2.4), Loc.t("Sous terre"), Art.ec("racine", "clair"), 14, 0.6)
	return true


func harmless(e) -> bool:
	return under(e)


## Sous terre, le tir automatique ne la vise pas (il tirerait dans le vide).
func hidden(e) -> bool:
	return under(e)


static func under(e) -> bool:
	return e.state == "sous" or e.state == "windup"


func draw_attack(e, k: float, hit: float) -> void:
	var r := float(e.data["burst_radius"])
	if e.state == "windup":
		Art.telegraph(e, {"type": "cercle", "centre": Vector2.ZERO, "rayon": r}, k, -1.0, e.t)
	elif hit >= 0.0:
		Art.telegraph(e, {"type": "cercle", "centre": Vector2.ZERO, "rayon": r}, 1.0, hit, e.t)


## Sous terre : la silhouette n'est plus qu'un sillon (« under » de 0 à 1), dessiné image par image.
func pose(e, o: Dictionary) -> void:
	if e.state == "sous":
		o["under"] = 1.0
		o["live"] = true
	elif e.state == "windup":
		o["under"] = 1.0
		o["rising"] = clampf(1.0 - e.state_t / float(e.data["windup"]), 0.0, 1.0)
		o["live"] = true
