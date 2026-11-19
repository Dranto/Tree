## Aurore : une onde de lumière part du joueur, blesse les ennemis du « radius » et les éblouit
## (« dazzle » de chance de critique en plus contre eux pendant « dazzle_time » s). Mutations
## (data/skills.json) : « waves » (une seconde onde suit, moins forte), « heal » (soigne cette part
## de la vie maximale par ennemi touché, au plus 5 ennemis).
extends Skill

const TornadeScript = preload("res://scripts/skills/tornade.gd")
## Délai et force d'une onde suivante.
const NEXT_DELAY := 0.45
const NEXT_FACTOR := 0.6

## Ondes à venir : {left, factor}.
var pending: Array = []


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	_wave(p, s, 1.0)
	for i in range(1, int(p.skill("aurore").get("waves", 1))):
		pending.append({"left": NEXT_DELAY * i, "factor": NEXT_FACTOR})


func _wave(p, s: Dictionary, factor: float) -> void:
	var k: Dictionary = p.skill("aurore")
	var r: float = float(k["radius"]) * float(s.get("area", 1.0))
	Sfx.play("aube_nova")
	TornadeScript.fx(p, "aurore", {"pos": p.position, "r": r, "follow": p})
	p.main.fx.shake(0.15)
	var hits := 0
	for e in p.main.enemies_near(p.position, r):
		if e.dead:
			continue
		p.main.player_hit_enemy(e, p.skill_damage("aurore") * factor, true, "aube")
		hits += 1
		if not e.dead:
			e.apply_status("ebloui", float(k["dazzle"]), float(k["dazzle_time"]))
	var heal := float(k.get("heal", 0.0))
	if heal > 0.0 and hits > 0:
		p.heal(float(s.get("max_hp", 100.0)) * heal * mini(hits, 5))


func tick(delta: float) -> void:
	if pending.is_empty() or player == null:
		return
	var i := 0
	while i < pending.size():
		pending[i]["left"] -= delta
		if pending[i]["left"] <= 0.0:
			var w: Dictionary = pending[i]
			pending.remove_at(i)
			_wave(player, Game.stats, float(w["factor"]))
		else:
			i += 1
