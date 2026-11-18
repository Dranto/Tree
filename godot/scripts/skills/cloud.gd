## Nuage de spores : un nuage toxique ronge les ennemis à l'endroit visé.
extends Skill


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("cloud")
	var target: Vector2 = p.aim_point
	var off: Vector2 = target - p.position
	if off.length() > k["range"]:
		target = p.position + off.normalized() * k["range"]
	var per_factor: float = p.current_damage() * p.skill_multiplier("cloud")
	Sfx.play("nuage")
	p.main.fx.cloud(target, k["radius"] * s["area"], k["duration"], per_factor * (k["damage"] + s["poison"]))
	if "skill_fx" in p.main and p.main.skill_fx != null:
		p.main.fx.clouds[-1]["dessin"] = "skill_fx"   # le nuage est dessiné par sa signature
	p._sig("cloud", {"pos": target, "r": k["radius"] * s["area"], "dur": float(k["duration"])})
