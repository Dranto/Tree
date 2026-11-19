## Prisme : un cristal se pose à l'endroit visé (au plus « range » px) et vit « life » s ; toutes les
## « every » s, il tire « beams » rayon(s) vers les ennemis les plus proches à moins de « reach » px.
## « max » prismes à la fois. Mutations (data/skills.json) : « beams », « dazzle » (les rayons
## éblouissent), « follow » (le prisme flotte au-dessus du joueur).
extends Skill

const AttackScript = preload("res://scripts/attack.gd")
const TornadeScript = preload("res://scripts/skills/tornade.gd")

## Prismes posés : {pos, left, clock, dmg, fx}.
var live: Array = []


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("prisme")
	Sfx.play("aube_cloche")
	var at: Vector2 = p.aim_point
	var off: Vector2 = at - p.position
	if off.length() > float(k["range"]):
		at = p.position + off.normalized() * float(k["range"])
	if bool(k.get("follow", false)):
		at = p.position + Vector2(0, -70)
	while live.size() >= maxi(1, int(k["max"])):
		var old: Dictionary = live.pop_front()
		if old["fx"] is Dictionary and old["fx"].has("dur"):
			old["fx"]["t"] = old["fx"]["dur"]
	var life := float(k["life"])
	live.append({"pos": at, "left": life, "clock": 0.1, "dmg": p.skill_damage("prisme"),
		"fx": TornadeScript.fx(p, "prisme", {"pos": at, "dur": life})})


func tick(delta: float) -> void:
	if live.is_empty() or player == null:
		return
	var p = player
	var k: Dictionary = p.skill("prisme")
	var reach := float(k["reach"])
	var i := 0
	while i < live.size():
		var pr: Dictionary = live[i]
		pr["left"] -= delta
		if pr["left"] <= 0.0:
			live.remove_at(i)
			continue
		if bool(k.get("follow", false)):
			pr["pos"] = p.position + Vector2(0, -70)
			if pr["fx"] is Dictionary:
				pr["fx"]["pos"] = pr["pos"]
		pr["clock"] -= delta
		if pr["clock"] <= 0.0:
			pr["clock"] += float(k["every"])
			_fire(p, pr, k, reach)
		i += 1


## Tire vers les « beams » ennemis les plus proches du prisme.
func _fire(p, pr: Dictionary, k: Dictionary, reach: float) -> void:
	var c: Vector2 = pr["pos"]
	var near: Array = p.main.enemies_near(c, reach).filter(func(e): return not e.dead)
	if near.is_empty():
		return
	near.sort_custom(func(a, b): return a.position.distance_squared_to(c) < b.position.distance_squared_to(c))
	var m := {"form": "prisme"}
	if float(k.get("dazzle", 0.0)) > 0.0:
		m["eblouit"] = float(k["dazzle"])
	for j in mini(int(k["beams"]), near.size()):
		var dir: Vector2 = (near[j].position - c).normalized()
		AttackScript.beam_line(p.main, c, dir, reach, float(k["width"]), pr["dmg"], m, "aube")
