## Fouet de ronce : arc devant le joueur. Chaque ennemi touché saigne et déclenche « melee_hit ».
extends Skill


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	Sfx.play("fouet")
	var k: Dictionary = p.skill("fouet")
	var reach: float = k["range"] * s["area"]
	var half_arc: float = k["arc"] / 2.0
	var aim: Vector2 = p.aim
	p._sig("fouet", {"pos": p.position, "dir": aim, "r": reach, "arc": float(k["arc"]), "follow": p})
	var base: float = p.skill_damage("fouet")
	for e in p.main.enemies_near(p.position, reach):
		var d: Vector2 = e.position - p.position
		if d.length() > 1.0 and absf(aim.angle_to(d)) > half_arc + e.radius / maxf(d.length(), 1.0):
			continue
		# Le fouet tranche (mort « tranche », enemy_remains.gd) : apparence seulement.
		var fx = p.main.get("fx")
		if fx != null:
			fx.hit_form = "fouet"
		p.main.player_hit_enemy(e, base, true, "ronce")
		if fx != null:
			fx.hit_form = ""
		if e.dead:
			continue
		e.apply_status("saignement", base * k["bleed"], k["bleed_duration"] * s["bleed_duration"])
		if d.length() > 0.1:
			e.position += d.normalized() * k["knockback"]
		p.main.on_melee_hit(e, base)
