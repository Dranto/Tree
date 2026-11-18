## Ruée : le Porte-Graine fend l'air vers le point visé et frappe tout sur son passage (une fois par
## ennemi), qu'il écarte de sa route. Il est intouchable pendant la ruée. Mutations (data/skills.json) :
## « dash » (la ruée compte comme une esquive : évènement « dash »), « wake » (une tornade naît au
## point d'arrivée, « wake » × ses dégâts et sa durée).
extends Skill

const VentScript = preload("res://scripts/vent.gd")
const TornadeScript = preload("res://scripts/skills/tornade.gd")

## Distance qui reste à parcourir, direction, dégâts, ennemis déjà frappés.
var left := 0.0
var dir := Vector2.RIGHT
var dmg := 0.0
var hit := {}
var _fx: Dictionary = {}


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	Sfx.play("ruee")
	var k: Dictionary = p.skill("ruee")
	dir = p.aim
	left = float(k["length"])
	dmg = p.skill_damage("ruee")
	hit.clear()
	p.invuln = maxf(p.invuln, left / float(k["speed"]) + 0.12)
	if p.has_dest:
		p.clear_destination()
	_fx = TornadeScript.fx(p, "ruee", {"pos": p.position, "from": p.position, "dir": dir, "w": float(k["width"]), "dur": left / float(k["speed"]) + 0.3})
	if bool(k.get("dash", false)):
		Game.fire("dash", {"main": p.main})


func tick(delta: float) -> void:
	var p = player
	if p == null:
		return
	if left <= 0.0:
		return
	var k: Dictionary = p.skill("ruee")
	var stepped: float = minf(float(k["speed"]) * delta, left)
	left -= stepped
	p.position += dir * stepped
	var h: float = p.main.world_half
	p.position = p.position.clamp(Vector2(-h, -h), Vector2(h, h))
	var w: float = float(k["width"])
	var kb: float = float(k["knockback"])
	for e in p.main.enemies_near(p.position, w):
		var id: int = e.get_instance_id()
		if hit.has(id):
			continue
		hit[id] = true
		p.main.player_hit_enemy(e, dmg, true, "vent")
		if e.dead:
			continue
		# Écarté sur le côté de la route, du côté où il se trouve.
		var side: Vector2 = dir.orthogonal()
		if side.dot(e.position - p.position) < 0.0:
			side = -side
		VentScript.push(e, side * kb)
		p.main.on_melee_hit(e, dmg)
	if _fx.has("pos"):
		_fx["pos"] = p.position
	if left <= 0.0:
		var wake: float = float(k.get("wake", 0.0))
		if wake > 0.0:
			var tor = p.skill_object("tornade")
			if tor != null:
				tor.spawn(p, p.position, dir, p.skill("tornade"), Game.stats, 0.0, wake)
