## Essaim : une spore vivante file vers l'ennemi le plus proche du point visé, le blesse et
## l'empoisonne, puis saute d'ennemi en ennemi (le plus proche qu'elle n'a pas encore touché),
## « jumps » fois au plus. Mutation « split » : au premier ennemi, l'essaim se divise en deux.
extends Skill

## Essaims en vol : {"last" (position), "hit" (ids touchés), "left" (sauts restants), "clock"}.
var chains: Array = []


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("essaim")
	var aim: Vector2 = p.aim_point
	var first = null
	var best := INF
	for e in p.main.enemies_near(p.position, float(k["range"])):
		if e.dead:
			continue
		var d: float = e.position.distance_squared_to(aim)
		if d < best:
			best = d
			first = e
	Sfx.play("spore_propage")
	if first == null:
		_sig(p.position + (aim - p.position).limit_length(120.0), p.position)
		return
	var hit := {}
	_strike(first, p.position, hit)
	var ways := 2 if k.get("split", false) else 1
	for i in ways:
		chains.append({"last": first.position, "hit": hit if i == 0 else hit.duplicate(), "left": int(k["jumps"]),
			"clock": float(k["hop"]) * (1.0 + 0.3 * i)})


func tick(delta: float) -> void:
	if chains.is_empty() or player == null:
		return
	var k: Dictionary = player.skill("essaim")
	var i := 0
	while i < chains.size():
		var c: Dictionary = chains[i]
		c["clock"] -= delta
		if c["clock"] > 0.0:
			i += 1
			continue
		var next = null
		if int(c["left"]) > 0:
			var best := INF
			for e in player.main.enemies_near(c["last"], float(k["reach"])):
				if e.dead or c["hit"].has(e.get_instance_id()):
					continue
				var d: float = e.position.distance_squared_to(c["last"])
				if d < best:
					best = d
					next = e
		if next == null:
			chains.remove_at(i)
			continue
		_strike(next, c["last"], c["hit"])
		c["last"] = next.position
		c["left"] = int(c["left"]) - 1
		c["clock"] = float(k["hop"])
		i += 1


## L'essaim touche e (venu de « from ») : coup de Spore et poison (part des dégâts par seconde).
func _strike(e, from: Vector2, hit: Dictionary) -> void:
	var p = player
	var k: Dictionary = p.skill("essaim")
	hit[e.get_instance_id()] = true
	var dmg: float = p.skill_damage("essaim")
	var per_factor: float = p.current_damage() * p.skill_multiplier("essaim")
	p.main.player_hit_enemy(e, dmg, true, "spore")
	if not e.dead:
		e.apply_poison(per_factor * (float(k["poison"]) + float(Game.stats["poison"])), float(k["duration"]))
	_sig(e.position, from)


func _sig(to: Vector2, from: Vector2) -> void:
	if player != null:
		# Le premier bond part du héros : sa signature a son anticipation (skill_fx.gd › _essaim).
		player._sig("essaim", {"pos": from, "to": to, "first": from == player.position})
