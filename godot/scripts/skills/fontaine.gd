## Fontaine de sève : une source jaillit aux pieds du joueur pour « duration » secondes, dans
## « radius » × taille des zones. Tant que le joueur s'y tient, il régénère « regen » × sa vie maximale
## par seconde ; les ennemis dedans sont blessés par à-coups (« damage » par seconde, toutes les
## « tick » s). Mutations (data/skills.json) : « follow » (la source suit le joueur), « geyser »
## (à la fin, elle jaillit : « geyser » × dégâts de la compétence sur toute la zone).
extends Skill

const TornadeScript = preload("res://scripts/skills/tornade.gd")

## Sources en cours : {pos, left, r, tick, every, dmg, regen, follow, geyser, fx}.
var live: Array = []


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("fontaine")
	SeveFx.sound("seve_source", "floraison", p.position)
	var r: float = float(k["radius"]) * float(s.get("area", 1.0))
	var dur: float = float(k["duration"])
	var f := {"pos": p.position, "left": dur, "r": r, "tick": 0.0, "every": float(k["tick"]),
		"dmg": p.skill_damage("fontaine") * float(k["tick"]), "regen": float(k["regen"]),
		"follow": bool(k.get("follow", false)), "geyser": float(k.get("geyser", 0.0)) * p.skill_damage("fontaine")}
	# Une seule source à la fois : la nouvelle remplace l'ancienne.
	for old in live:
		if old.has("fx") and old["fx"] is Dictionary and not old["fx"].is_empty():
			old["fx"]["t"] = old["fx"]["dur"]
	live.clear()
	f["fx"] = TornadeScript.fx(p, "fontaine", {"pos": p.position, "r": r, "dur": dur, "follow": p if f["follow"] else null})
	live.append(f)
	p.main.ground.paint(p.position, r, 0.4)


## Vrai si le joueur se tient dans une source.
func inside() -> bool:
	if player == null:
		return false
	for f in live:
		if player.position.distance_to(f["pos"]) <= f["r"]:
			return true
	return false


func tick(delta: float) -> void:
	var p = player
	if live.is_empty() or p == null:
		return
	var i := 0
	while i < live.size():
		var f: Dictionary = live[i]
		if f["follow"]:
			f["pos"] = p.position
		f["left"] -= delta
		if f["left"] <= 0.0:
			live.remove_at(i)
			if f["geyser"] > 0.0:
				p.main.fx.shake(0.2)
				TornadeScript.fx(p, "fontaine_geyser", {"pos": f["pos"], "r": f["r"]})
				p.main.damage_area(f["pos"], f["r"], f["geyser"], 40.0, "seve")
			continue
		if p.position.distance_to(f["pos"]) <= f["r"]:
			p.heal(float(Game.stats["max_hp"]) * f["regen"] * delta)
		f["tick"] -= delta
		if f["tick"] <= 0.0:
			f["tick"] += f["every"]
			for e in p.main.enemies_near(f["pos"], f["r"]):
				p.main.player_hit_enemy(e, f["dmg"], false, "seve")
		if f.has("fx") and f["fx"] is Dictionary and not f["fx"].is_empty():
			f["fx"]["pos"] = f["pos"]
		i += 1
