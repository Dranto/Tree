## Racines voraces : à l'endroit visé, blessent et immobilisent les ennemis de la zone.
extends Skill


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	Sfx.play("racines")
	var k: Dictionary = p.skill("racines")
	var target: Vector2 = p.aim_point
	var off: Vector2 = target - p.position
	if off.length() > k["range"]:
		target = p.position + off.normalized() * k["range"]
	var r: float = k["radius"] * s["area"]
	var hold: float = minf(float(k["root_duration"]) * s["root_duration"], 3.0)
	p._sig("racines", {"pos": target, "r": r, "dur": 0.3 + hold + 0.35, "seed": int(p.t * 1000.0) + 1})
	var base: float = p.skill_damage("racines")
	p.main.root_hit_base = base
	for e in p.main.enemies_near(target, r):
		p.main.player_hit_enemy(e, base, true, "ronce")
		if not e.dead:
			e.apply_status("enracine", 1.0, k["root_duration"] * s["root_duration"])
	p.main.root_hit_base = 0.0
