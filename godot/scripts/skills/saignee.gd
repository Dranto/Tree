## Saignée : chaque ennemi proche qui saigne voit ses saignements éclater d'un coup
## (burst × dégâts restants) ; une part de ces dégâts soigne le joueur.
extends Skill


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	Sfx.play("saignee")
	var k: Dictionary = p.skill("saignee")
	var r: float = k["radius"] * s["area"]
	var hit: float = p.skill_damage("saignee")
	# Le multiplicateur des dégâts de zone et le bonus « chez soi » s'appliquent aussi à l'éclatement.
	var mult: float = float(k["burst"]) * p.skill_multiplier("saignee")
	var total := 0.0
	var bled: Array = []
	for e in p.main.enemies_near(p.position, r):
		# L'éclatement est un coup de Ronce : les ennemis du roncier y résistent aussi.
		var amount: float = e.burst_bleed(mult) * p.main.branch_factor(e, "ronce")
		if amount > 0.0:
			if bled.size() < 12:
				bled.append(e.position)
			e.take_damage(amount, false)
			total += amount
			p.main.on_bleed_tick(e, amount)
		if not e.dead:
			p.main.player_hit_enemy(e, hit, true, "ronce")
	p._sig("saignee", {"pos": p.position, "r": r, "targets": bled, "follow": p})
	if total > 0.0:
		p.heal(total * float(k["heal"]))
