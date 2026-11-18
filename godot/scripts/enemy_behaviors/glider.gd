## Planeur de cendre (région de Vent) : plane loin du joueur (keep_min à keep_max) et lui crache
## des plumes de cendre (« shots » en éventail, vent_feather.gd). Quand le joueur approche à moins
## de « reach », il prend de la hauteur (état "vol") et fuit : là-haut, les coups directs ne le
## touchent plus (le poison et le saignement, si) ; il faut le frapper de loin. Il redescend une fois
## le joueur à plus de « reach » × 1,25.
extends EnemyBehavior

const Feather = preload("res://scripts/vent_feather.gd")
## Un « Hors d'atteinte ! » au plus toutes les DODGE_TEXT secondes par Planeur.
const DODGE_TEXT := 0.7


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	var reach := float(data["reach"])
	e.cd -= delta
	if dist < reach or (e.state == "vol" and dist < reach * 1.25):
		e.state = "vol"
		e.attack_dir = -dir
		e.position += (-dir + dir.orthogonal() * e.strafe * 0.4).normalized() * e.speed * float(data.get("flee", 1.5)) * delta
		return
	if e.state == "vol":
		e.state = ""
	if e.state == "windup":
		e.state_t -= delta
		if e.state_t <= 0.0:
			e.state = ""
			e.cd = float(data["cooldown"]) * e.cd_mult
			var n := int(data.get("shots", 2))
			var spread := float(data.get("spread", 0.2))
			for i in n:
				var a: float = e.attack_dir.angle() + (i - (n - 1) / 2.0) * spread
				var f = Feather.new()
				f.main = e.main
				f.position = e.position + Vector2.from_angle(a) * (e.radius + 6.0) + Vector2(0, -e.radius * 0.55)
				f.vel = Vector2.from_angle(a) * float(data["shot_speed"])
				f.damage = float(data["shot_damage"]) * e.damage_scale
				f.life = data["shot_life"]
				e.main.projectiles_layer.add_child(f)
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
		mv = dir.orthogonal() * e.strafe * 0.7
	# Il plane : la terre vivante le ralentit moins que les autres.
	e.position += mv * e.speed * lerpf(1.0, slow, 0.4) * delta


## En vol haut, il esquive les coups directs (et le montre).
func dodge(e) -> bool:
	if e.state != "vol":
		return false
	var now: float = e.t
	if now - float(e.get_meta("esquive", -10.0)) > DODGE_TEXT and e.main.get("fx") != null:
		e.set_meta("esquive", now)
		e.main.fx.text(e.position + Vector2(0, -e.radius * 3.2), "Hors d'atteinte", Art.ec("vent", "clair"), 14, 0.6)
	return true


func draw_attack(e, k: float, hit: float) -> void:
	if e.state == "windup" or hit >= 0.0:
		var n := int(e.data.get("shots", 2))
		var spread := float(e.data.get("spread", 0.2))
		Art.telegraph(e, {"type": "cone", "centre": Vector2.ZERO, "direction": e.attack_dir.angle(), "ouverture": spread * (n - 1) + 0.18, "rayon": 260.0}, k, hit, e.t)
