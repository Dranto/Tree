## Appel d'air : un tourbillon s'ouvre à l'endroit visé et aspire les ennemis autour vers son centre
## pendant « pull_time » secondes, puis éclate et blesse tout ce qu'il a regroupé. Mutations
## (data/skills.json) : « root » (les ennemis regroupés sont immobilisés « root » secondes).
extends Skill

const VentScript = preload("res://scripts/vent.gd")
const TornadeScript = preload("res://scripts/skills/tornade.gd")

## Appels en cours : {pos, left, r, dmg, root, hit_r}.
var live: Array = []


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	Sfx.play("vent_appel")
	var k: Dictionary = p.skill("appel_air")
	var target: Vector2 = p.aim_point
	var off: Vector2 = target - p.position
	if off.length() > float(k["range"]):
		target = p.position + off.normalized() * float(k["range"])
	var r: float = float(k["radius"]) * s["area"]
	var pull: float = float(k["pull_time"])
	live.append({"pos": target, "left": pull, "pull": pull, "r": r, "dmg": p.skill_damage("appel_air"),
		"root": float(k.get("root", 0.0)) * float(s.get("root_duration", 1.0))})
	TornadeScript.fx(p, "appel_air", {"pos": target, "r": r, "dur": pull + 0.35, "pull": pull})


func tick(delta: float) -> void:
	var p = player
	if live.is_empty() or p == null:
		return
	var i := 0
	while i < live.size():
		var a: Dictionary = live[i]
		var c: Vector2 = a["pos"]
		var r: float = a["r"]
		a["left"] -= delta
		# Plus l'ennemi est loin, plus il glisse vite : tous arrivent ensemble près du centre.
		for e in p.main.enemies_near(c, r, false):
			var d: float = e.position.distance_to(c)
			VentScript.pull(e, c, maxf(d, 40.0) / maxf(a["left"] + delta, delta) * delta, r * 0.18)
		if a["left"] > 0.0:
			i += 1
			continue
		live.remove_at(i)
		p.main.fx.shake(0.15)
		for e in p.main.enemies_near(c, r * 0.45):
			p.main.player_hit_enemy(e, a["dmg"], true, "vent")
			if not e.dead and a["root"] > 0.0:
				e.apply_status("enracine", 1.0, a["root"])
