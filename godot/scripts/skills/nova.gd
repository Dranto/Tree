## Couronne d'épines : une onde d'épines blesse et repousse les ennemis autour du joueur.
extends Skill


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("nova")
	var r: float = k["radius"] * s["area"]
	Sfx.play("nova")
	p._sig("nova", {"pos": p.position, "r": r})
	p.main.fx.shake(0.25)
	p.main.damage_area(p.position, r, p.skill_damage("nova"), k["knockback"], "ronce")
