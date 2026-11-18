## Floraison : soigne le joueur et fait renaître le sol autour de lui.
extends Skill


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("bloom")
	Sfx.play("floraison")
	p.heal(s["max_hp"] * k["heal"])
	var r: float = k["radius"] * s["area"]
	p._sig("bloom", {"pos": p.position, "r": r, "follow": p})
	p.main.fx.shake(0.3)
	p.main.damage_area(p.position, r, p.skill_damage("bloom"), k["knockback"])
	p.main.ground.paint(p.position, r, k["life"])
	p.main.flora.spawn_patch(p.position, r * 0.8, 10, Color(k["color"]))
