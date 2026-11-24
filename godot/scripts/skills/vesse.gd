## Vesse-de-loup : un champignon-piège pousse à l'endroit visé. Une fois armé, il éclate dès qu'un
## ennemi s'approche (ou au bout de sa vie) : un coup de zone, puis un nuage de spores qui ronge
## et empoisonne. Au plus « max » champignons à la fois : en planter un de plus fait éclater le
## plus ancien.
extends Skill

const AttackScript = preload("res://scripts/attack.gd")

## Champignons plantés : {"pos", "t" (âge), "fx" (signature, ou {})}.
var shrooms: Array = []


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("vesse")
	var target: Vector2 = p.aim_point
	var off: Vector2 = target - p.position
	if off.length() > float(k["range"]):
		target = p.position + off.normalized() * float(k["range"])
	while shrooms.size() >= maxi(1, int(k["max"])):
		_burst(shrooms.pop_front())
	Sfx.play("spore_piege")
	var fx := {}
	if "skill_fx" in p.main and p.main.skill_fx != null:
		fx = p.main.skill_fx.play("vesse", {"pos": target, "r": float(k["radius"]) * s["area"],
			"arm": float(k["arm"]), "dur": float(k["life"]) + 1.0})
	shrooms.append({"pos": target, "t": 0.0, "fx": fx})


func tick(delta: float) -> void:
	if shrooms.is_empty() or player == null:
		return
	var k: Dictionary = player.skill("vesse")
	var i := 0
	while i < shrooms.size():
		var sh: Dictionary = shrooms[i]
		sh["t"] += delta
		var go: bool = sh["t"] >= float(k["life"])
		if not go and sh["t"] >= float(k["arm"]):
			for e in player.main.enemies_near(sh["pos"], float(k["trigger"])):
				if not e.dead:
					go = true
					break
		if go:
			shrooms.remove_at(i)
			_burst(sh)
		else:
			i += 1


## Le champignon éclate : coup de zone (coup de Spore), puis nuage de spores au même endroit.
func _burst(sh: Dictionary) -> void:
	var p = player
	var s: Dictionary = Game.stats
	var k: Dictionary = p.skill("vesse")
	var r: float = float(k["radius"]) * s["area"]
	var hit: float = p.skill_damage("vesse")
	var pos: Vector2 = sh["pos"]
	Sfx.play("spore_eclat", pos)
	var venom := float(k.get("poison", 0.0))
	for e in p.main.enemies_near(pos, r):
		if e.dead:
			continue
		p.main.player_hit_enemy(e, hit, true, "spore")
		if venom > 0.0 and not e.dead:
			e.apply_poison(hit * venom, 4.0)
	var per_factor: float = p.current_damage() * p.skill_multiplier("vesse")
	var tick := 0.5
	AttackScript.cloud(p.main, pos, r * 0.9, float(k["cloud_duration"]), tick,
		per_factor * (float(k["cloud_damage"]) + float(s["poison"])) * tick, 12, "vesse")
	var fx: Dictionary = sh.get("fx", {})
	if not fx.is_empty():
		# La signature passe à l'éclatement (0,45 s).
		fx["burst"] = fx["t"]
		fx["dur"] = float(fx["t"]) + 0.45
