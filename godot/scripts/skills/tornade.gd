## Tornade : une tornade part vers le point visé et avance, aspire les ennemis qu'elle croise et les
## blesse par à-coups. Mutations (data/skills.json, réglages lus au lancer) :
## « count » tornades en éventail, « speed » 0 (elle reste sur place), « orbit » (elle tourne autour
## du joueur au lieu d'avancer). spawn() sert aussi aux autres effets de Vent (ruée, greffes).
extends Skill

const VentScript = preload("res://scripts/vent.gd")
## Au plus autant de tornades à la fois (budget de dessin : une signature chacune).
const MAX := 6

## Tornades en vol : {pos, dir, speed, left, tick, every, r, pull, dmg, orbit, ang, fx}.
var live: Array = []


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	Sfx.play("tornade")
	var k: Dictionary = p.skill("tornade")
	var n: int = maxi(1, int(k["count"]))
	for i in n:
		var a: float = p.aim.angle()
		if n > 1:
			a += (i / float(n - 1) - 0.5) * 0.7
		spawn(p, p.position + Vector2.from_angle(a) * 30.0, Vector2.from_angle(a), k, s, i * TAU / n)


## Fait naître une tornade à « at », lancée vers « dir », avec les réglages k (ceux de skills.json
## › tornade, éventuellement modifiés) ; « factor » multiplie ses dégâts et sa durée.
func spawn(p, at: Vector2, dir: Vector2, k: Dictionary, s: Dictionary, ang := 0.0, factor := 1.0) -> void:
	while live.size() >= MAX:
		var old: Dictionary = live.pop_front()
		if old.has("fx"):
			old["fx"]["t"] = old["fx"]["dur"]
	var r: float = float(k["radius"]) * float(s.get("area", 1.0))
	var dur: float = float(k["duration"]) * factor
	var tw := {
		"pos": at, "dir": dir, "speed": float(k["speed"]), "left": dur, "tick": 0.0,
		"every": float(k["tick"]), "r": r, "pull": float(k["pull"]),
		"dmg": p.skill_damage("tornade") * float(k.get("tick", 0.3)) * factor,
		"orbit": bool(k.get("orbit", false)), "ang": ang,
	}
	if tw["orbit"]:
		tw["pos"] = p.position + Vector2.from_angle(ang) * float(k.get("orbit_radius", 130.0))
	tw["fx"] = fx(p, "tornade", {"pos": tw["pos"], "r": r, "dur": dur, "seed": live.size() + int(p.t * 7.0)})
	live.append(tw)


func tick(delta: float) -> void:
	if live.is_empty() or player == null:
		return
	var p = player
	var k: Dictionary = p.skill("tornade")
	var i := 0
	while i < live.size():
		var tw: Dictionary = live[i]
		tw["left"] -= delta
		if tw["left"] <= 0.0:
			live.remove_at(i)
			continue
		if tw["orbit"]:
			tw["ang"] += float(k.get("orbit_speed", 2.6)) * delta
			tw["pos"] = p.position + Vector2.from_angle(tw["ang"]) * float(k.get("orbit_radius", 130.0))
		else:
			tw["pos"] += tw["dir"] * tw["speed"] * delta
		var c: Vector2 = tw["pos"]
		var r: float = tw["r"]
		# Aspiration : les ennemis autour glissent vers l'œil de la tornade.
		for e in p.main.enemies_near(c, r * 1.5, false):
			VentScript.pull(e, c, tw["pull"] * delta, r * 0.2)
		tw["tick"] -= delta
		if tw["tick"] <= 0.0:
			tw["tick"] += tw["every"]
			for e in p.main.enemies_near(c, r):
				p.main.player_hit_enemy(e, tw["dmg"], false, "vent")
		if tw.has("fx") and tw["fx"] is Dictionary:
			tw["fx"]["pos"] = c
		i += 1


## Signature visuelle (skill_fx.gd) gardée pour la faire suivre ; {} sans dessin (bancs, tests).
static func fx(p, id: String, d: Dictionary) -> Dictionary:
	if p.main != null and "skill_fx" in p.main and p.main.skill_fx != null:
		return p.main.skill_fx.play(id, d)
	return {}
