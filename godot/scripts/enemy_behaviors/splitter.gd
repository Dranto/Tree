## Scissipore (marais de Spore) : marche sur le joueur ; au contact, il gonfle (cercle annoncé au
## sol) puis souffle une bouffée de spores autour de lui. À sa mort, il se divise en « split_count »
## petits de la sorte « split » (Sporules), qui foncent sur le joueur : les zones et les coups qui
## traversent répondent mieux que les coups uniques.
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	if e.state == "windup":
		e.state_t -= delta
		if e.state_t <= 0.0:
			e.state = ""
			e.cd = float(data["cooldown"]) * e.cd_mult
			var p = e.main.player
			if p.position.distance_to(e.position) < float(data["puff_radius"]) + p.radius * 0.5:
				p.take_hit(float(data["puff_damage"]) * e.damage_scale, e)
			e.strike_t = 0.0
		return
	if e.cd <= 0.0 and dist < float(data["range"]):
		e.state = "windup"
		e.state_t = data["windup"]
		e.attack_dir = dir
		return
	e.position += dir * e.speed * slow * delta


func draw_attack(e, k: float, hit: float) -> void:
	if e.state == "windup" or hit >= 0.0:
		Art.telegraph(e.gc, {"type": "cercle", "centre": Vector2.ZERO, "rayon": float(e.data["puff_radius"])}, k, hit, e.t)


## Division : les petits naissent au pas suivant (la mort arrive pendant le parcours des ennemis).
func on_death(e) -> void:
	var n := int(e.data.get("split_count", 2))
	var kind := str(e.data.get("split", "sporule"))
	var a0 := randf() * TAU
	for i in n:
		var at: Vector2 = e.position + Vector2.from_angle(a0 + TAU * i / n) * e.radius * 0.8
		e.main.call_deferred("spawn_enemy_kind", kind, at, e.power)
