## Nuage de spores : un nuage toxique ronge les ennemis à l'endroit visé. Avec le réglage « follow »
## (nœud clé Brouillard vivant), il naît sur le joueur et le suit.
extends Skill


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("cloud")
	var follow: bool = k.get("follow", false) == true
	var target: Vector2 = p.aim_point
	var off: Vector2 = target - p.position
	if follow:
		target = p.position
	elif off.length() > k["range"]:
		target = p.position + off.normalized() * k["range"]
	var per_factor: float = p.current_damage() * p.skill_multiplier("cloud")
	Sfx.play("nuage")
	p.main.fx.cloud(target, k["radius"] * s["area"], k["duration"], per_factor * (k["damage"] + s["poison"]))
	if follow:
		p.main.fx.clouds[-1]["follow"] = p
	if "skill_fx" in p.main and p.main.skill_fx != null:
		p.main.fx.clouds[-1]["dessin"] = "skill_fx"   # le nuage est dessiné par sa signature
	var sig := {"pos": target, "r": k["radius"] * s["area"], "dur": float(k["duration"])}
	if follow:
		sig["follow"] = p
	p._sig("cloud", sig)
