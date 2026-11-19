## Lance d'aube : après « windup » s (la lumière se concentre devant le joueur), un grand rayon part
## vers l'endroit visé, long de « length » et large de « width », et frappe tout ce qu'il traverse.
## Contre un ennemi ébloui, « crit_dazzled » de chance de critique en plus (1 : toujours critique).
## Mutations (data/skills.json) : « dazzle » (éblouit ce qu'elle touche, secondes), « repeat » (une
## seconde lance part juste après, à 70 % des dégâts).
extends Skill

const AttackScript = preload("res://scripts/attack.gd")
const TornadeScript = preload("res://scripts/skills/tornade.gd")
const REPEAT_GAP := 0.25
const REPEAT_FACTOR := 0.7

## Lances en préparation : {left, dir, factor}.
var pending: Array = []


func cast(p, s := {}) -> void:
	var k: Dictionary = p.skill("lance_aube")
	var dir: Vector2 = p.aim
	var off: Vector2 = p.aim_point - p.position
	if off.length() > 1.0:
		dir = off.normalized()
	var wind := float(k["windup"])
	pending.append({"left": wind, "dir": dir, "factor": 1.0})
	for i in int(k.get("repeat", 0)):
		pending.append({"left": wind + REPEAT_GAP * (i + 1), "dir": dir, "factor": REPEAT_FACTOR})
	TornadeScript.fx(p, "lance_charge", {"pos": p.position, "dir": dir, "dur": wind, "follow": p})


func tick(delta: float) -> void:
	if pending.is_empty() or player == null:
		return
	var i := 0
	while i < pending.size():
		pending[i]["left"] -= delta
		if pending[i]["left"] <= 0.0:
			var l: Dictionary = pending[i]
			pending.remove_at(i)
			strike(player, l["dir"], float(l["factor"]))
		else:
			i += 1


## Le rayon part : renvoie les ennemis touchés (tests).
func strike(p, dir: Vector2, factor := 1.0) -> Array:
	var k: Dictionary = p.skill("lance_aube")
	var main = p.main
	var from: Vector2 = p.position + dir * 20.0
	var length := float(k["length"])
	var width := float(k["width"]) * float(Game.stats.get("area", 1.0))
	var dmg: float = p.skill_damage("lance_aube") * factor
	Sfx.play("aube_levant")
	TornadeScript.fx(p, "lance_aube", {"pos": from, "dir": dir, "len": length, "w": width})
	main.fx.shake(0.2)
	var out: Array = AttackScript.beam_targets(main, from, dir, length, width)
	for e in out:
		if e.dead:
			continue
		var tuned: bool = "hit_crit_bonus" in main
		if tuned and main.dazzle_of(e) > 0.0:
			main.hit_crit_bonus = float(k["crit_dazzled"])
		main.player_hit_enemy(e, dmg, true, "aube")
		if tuned:
			main.hit_crit_bonus = 0.0
		var dz := float(k.get("dazzle", 0.0))
		if dz > 0.0 and not e.dead:
			e.apply_status("ebloui", 0.3, dz)
	return out
