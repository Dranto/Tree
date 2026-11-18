## Traîne-vase (marais de Spore) : rampe vers le joueur et, toutes les « cooldown » secondes, se
## ramasse (cercle annoncé sous lui) puis répand une flaque de vase toxique qui reste « puddle_life »
## secondes et blesse qui s'y tient (marsh_puddles.gd). Au plus « max_puddles » flaques à lui.
## Réponse : ne pas le suivre dans sa traînée, le tuer avant qu'il ne couvre le terrain.
extends EnemyBehavior

const Puddles = preload("res://scripts/marsh_puddles.gd")


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	if e.state == "windup":
		e.state_t -= delta
		if e.state_t <= 0.0:
			e.state = ""
			e.cd = float(data["cooldown"]) * e.cd_mult
			Puddles.of(e.main).add(e, e.position, float(data["puddle_radius"]), float(data["puddle_life"]),
				float(data["puddle_dps"]) * e.damage_scale, int(data.get("max_puddles", 4)))
		return
	# Il ne répand sa vase que près du joueur (à l'écran) : loin, il rampe seulement.
	if e.cd <= 0.0 and dist < 700.0:
		e.state = "windup"
		e.state_t = data["windup"]
		e.attack_dir = dir
		return
	e.position += dir * e.speed * slow * delta


func draw_attack(e, k: float, _hit: float) -> void:
	if e.state == "windup":
		Art.telegraph(e, {"type": "cercle", "centre": Vector2.ZERO, "rayon": float(e.data["puddle_radius"])}, k, -1.0, e.t)
