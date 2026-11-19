## Liane buveuse : des lianes partent du joueur et s'accrochent aux « count » ennemis les plus proches
## de l'endroit visé (dans « radius » autour de ce point, au plus à « range » du joueur). Pendant
## « duration » secondes, chaque liane blesse son ennemi par à-coups (« damage » par seconde) et rend
## au joueur « drain » × les dégâts infligés. Une liane casse si son ennemi meurt ou s'éloigne de plus
## de « leash » pixels. Mutations (data/skills.json) : « jump » (une liane dont l'ennemi meurt saute
## au plus proche), « root » (les ennemis pris sont immobilisés « root » secondes).
## Un ennemi marqué "no_drain": true (enemies.json, ou variable du script d'un boss) est blessé sans
## rien rendre.
extends Skill

const TornadeScript = preload("res://scripts/skills/tornade.gd")
## Au plus autant de lianes à la fois (budget de dessin).
const MAX := 10

## Lianes accrochées : {e, left, tick, every, dmg, drain, fx}.
var live: Array = []


## Vrai si l'ennemi rend de la vie quand on le draine.
static func can_drain(e) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	if e.get("no_drain") == true:
		return false
	var d = e.get("data")
	return not (d is Dictionary and d.get("no_drain", false))


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("liane")
	SeveFx.sound("seve_lien", "saignee", p.position)
	var target: Vector2 = p.aim_point
	var off: Vector2 = target - p.position
	if off.length() > float(k["range"]):
		target = p.position + off.normalized() * float(k["range"])
	var r: float = float(k["radius"]) * float(s.get("area", 1.0))
	var found: Array = p.main.enemies_near(target, r)
	found = found.filter(func(e): return not e.dead and not _held(e))
	found.sort_custom(func(a, b): return a.position.distance_squared_to(target) < b.position.distance_squared_to(target))
	var n: int = mini(int(k["count"]), found.size())
	for i in n:
		_grab(p, found[i], k, s, float(k["duration"]))
	TornadeScript.fx(p, "liane_jet", {"pos": target, "r": r, "from": p.position})


func _held(e) -> bool:
	for l in live:
		if l["e"] == e:
			return true
	return false


func _grab(p, e, k: Dictionary, s: Dictionary, left: float) -> void:
	while live.size() >= MAX:
		var old: Dictionary = live.pop_front()
		_end_fx(old)
	var tick := float(k["tick"])
	var l := {"e": e, "left": left, "tick": 0.0, "every": tick,
		"dmg": p.skill_damage("liane") * tick, "drain": float(k["drain"]), "at": e.position}
	l["fx"] = TornadeScript.fx(p, "liane", {"pos": p.position, "to": e.position, "follow": p, "dur": left + 0.25, "seed": live.size() + int(p.t * 5.0)})
	live.append(l)
	var root := float(k.get("root", 0.0))
	if root > 0.0:
		e.apply_status("enracine", 1.0, root * float(s.get("root_duration", 1.0)))


func _end_fx(l: Dictionary) -> void:
	if l.has("fx") and l["fx"] is Dictionary and not l["fx"].is_empty():
		l["fx"]["t"] = maxf(float(l["fx"]["t"]), float(l["fx"]["dur"]) - 0.25)


func tick(delta: float) -> void:
	var p = player
	if live.is_empty() or p == null:
		return
	var k: Dictionary = p.skill("liane")
	var leash: float = float(k["leash"])
	var i := 0
	while i < live.size():
		var l: Dictionary = live[i]
		var e = l["e"]
		l["left"] -= delta
		var gone: bool = not is_instance_valid(e) or e.dead
		if gone or l["left"] <= 0.0 or e.position.distance_to(p.position) > leash:
			live.remove_at(i)
			_end_fx(l)
			# Mutation « jump » : la liane saute vers l'ennemi libre le plus proche de celui qui est tombé.
			if gone and l["left"] > 0.0 and bool(k.get("jump", false)) and l.has("at"):
				var next = _nearest_free(p, l["at"], 220.0)
				if next != null:
					_grab(p, next, k, Game.stats, l["left"])
			continue
		l["tick"] -= delta
		if l["tick"] <= 0.0:
			l["tick"] += l["every"]
			var hp0: float = e.hp
			p.main.player_hit_enemy(e, l["dmg"], false, "seve")
			if can_drain(e):
				p.heal(maxf(0.0, hp0 - maxf(e.hp, 0.0)) * l["drain"])
		l["at"] = e.position
		if l.has("fx") and l["fx"] is Dictionary and not l["fx"].is_empty():
			l["fx"]["to"] = e.position
		i += 1


func _nearest_free(p, at: Vector2, r: float):
	var best = null
	var bd := INF
	for o in p.main.enemies_near(at, r):
		if o.dead or _held(o):
			continue
		var d: float = o.position.distance_squared_to(at)
		if d < bd:
			bd = d
			best = o
	return best
