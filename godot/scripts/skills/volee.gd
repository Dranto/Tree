## Volée d'épines : un éventail d'épines perforantes, chacune fait saigner ce qu'elle touche.
extends Skill


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	Sfx.play("volee")
	var k: Dictionary = p.skill("volee")
	var n: int = maxi(1, int(k["count"]))
	var spread: float = k["spread"]
	var dmg: float = p.skill_damage("volee")
	var aim: Vector2 = p.aim
	p._sig("volee", {"pos": p.position, "dir": aim, "spread": spread, "count": n})
	for i in n:
		var a: float = aim.angle()
		if n > 1:
			a += (i / float(n - 1) - 0.5) * spread
		var dir := Vector2.from_angle(a)
		var pr = p.main.spawn_projectile(p.position + dir * 18.0, dir * float(k["speed"]), dmg, int(k["pierce"]) + int(s["pierce"]), s["projectile_size"])
		pr.thorn = true
		pr.color = Color(k["color"])
		pr.bleed = float(k["bleed"])
		pr.bleed_duration = float(k["bleed_duration"]) * s["bleed_duration"]
