## Éclosion : le poison des ennemis proches éclot d'un coup. Chaque ennemi empoisonné subit tout le
## poison qui lui restait (« burst » × dégâts restants) ; ses spores éclaboussent ses voisins, qui
## sont empoisonnés à leur tour (« splash », rayon en pixels). Tous les ennemis de la zone prennent
## aussi un petit coup de Spore.
extends Skill


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	Sfx.play("saignee")
	var k: Dictionary = p.skill("eclosion")
	var r: float = float(k["radius"]) * s["area"]
	var hit: float = p.skill_damage("eclosion")
	# Le multiplicateur des dégâts de zone et le bonus « chez soi » s'appliquent aussi à l'éclosion.
	var mult: float = float(k["burst"]) * p.skill_multiplier("eclosion")
	var keep := float(k.get("keep", 0.0))
	var bloomed: Array = []
	var spread: Array = []
	for e in p.main.enemies_near(p.position, r):
		if e.dead:
			continue
		if float(e.poison_time) > 0.0:
			var dps: float = e.poison_dps
			var amount: float = dps * e.poison_time * mult * p.main.branch_factor(e, "spore")
			# Le poison est consommé (sauf « keep », la part qui reste).
			e.poison_time *= keep
			if bloomed.size() < 12:
				bloomed.append(e.position)
			spread.append([e.position, dps])
			e.take_damage(amount, false)
		if not e.dead:
			p.main.player_hit_enemy(e, hit, true, "spore")
	var splash: float = float(k["splash"]) * float(s["area"])
	for sp in spread:
		for o in p.main.enemies_near(sp[0], splash):
			if not o.dead and o.position != sp[0]:
				o.apply_poison(float(sp[1]), 3.0)
	p._sig("eclosion", {"pos": p.position, "r": r, "targets": bloomed, "follow": p})
