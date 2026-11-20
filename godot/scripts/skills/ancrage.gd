## Ancrage : le joueur prend racine pendant « duration » secondes (player.gd › take_root) : il ne
## marche plus (« walk » : part de sa vitesse gardée, mutation Racines traçantes), et l'état
## « enracine » des conditions est vrai (le nœud de la compétence y attache son armure). Ses racines
## courent dans « radius » × taille des zones autour de lui : toutes les « tick » s, elles blessent
## (« damage » par seconde) et immobilisent les ennemis (« root_duration » × durée d'immobilisation ;
## un ennemi "no_root": true dans enemies.json est blessé sans être retenu).
## L'esquive arrache les racines (player.gd › uproot). Mutations (data/skills.json) : « heal » (part
## de la vie maximale rendue par ennemi tenu à chaque à-coup, HEAL_MAX ennemis au plus), « uproot »
## (à la fin, les racines s'arrachent : « uproot » × dégâts de la compétence sur toute la zone).
extends Skill

const TornadeScript = preload("res://scripts/skills/tornade.gd")
const HEAL_MAX := 10

var active := false
var _tick := 0.0
var _fx := {}


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("ancrage")
	RacineFx.sound("racine_ancrage", "racines", p.position)
	var dur := float(k["duration"])
	p.take_root(dur, float(k.get("walk", 0.0)))
	active = true
	_tick = 0.0
	if not _fx.is_empty():
		_fx["t"] = _fx["dur"]
	_fx = TornadeScript.fx(p, "ancrage", {"pos": p.position, "follow": p, "dur": dur + 0.35, "r": radius(),
		"seed": int(p.t * 1000.0) % 997})
	p.main.fx.shake(0.1)


## Rayon des racines (taille des zones comprise).
func radius() -> float:
	return float(player.skill("ancrage")["radius"]) * float(Game.stats.get("area", 1.0))


func tick(delta: float) -> void:
	if not active or player == null:
		return
	if player.rooted <= 0.0:
		release()
		return
	if not _fx.is_empty():
		_fx["pos"] = player.position
	_tick -= delta
	if _tick > 0.0:
		return
	var k: Dictionary = player.skill("ancrage")
	var every := maxf(0.05, float(k["tick"]))
	_tick += every
	var r := radius()
	var dmg: float = player.skill_damage("ancrage") * every
	var hold: float = float(k["root_duration"]) * float(Game.stats.get("root_duration", 1.0))
	var held := 0
	player.main.root_hit_base = dmg
	for e in player.main.enemies_near(player.position, r):
		if e.dead:
			continue
		player.main.player_hit_enemy(e, dmg, false, "racine")
		if not e.dead:
			e.apply_status("enracine", 1.0, hold)
			held += 1
	player.main.root_hit_base = 0.0
	var heal := float(k.get("heal", 0.0))
	if heal > 0.0 and held > 0:
		player.heal(float(Game.stats["max_hp"]) * heal * mini(held, HEAL_MAX))


## Fin de l'ancrage (temps écoulé, esquive, mort) : les racines se retirent, ou s'arrachent.
func release() -> void:
	if not active:
		return
	active = false
	if player == null:
		return
	player.rooted = 0.0
	if not _fx.is_empty():
		_fx["t"] = maxf(float(_fx["t"]), float(_fx["dur"]) - 0.35)
	_fx = {}
	var k: Dictionary = player.skill("ancrage")
	var up := float(k.get("uproot", 0.0))
	if up > 0.0 and player.main != null:
		var r := radius()
		player.main.fx.shake(0.2)
		TornadeScript.fx(player, "ancrage_arrache", {"pos": player.position, "r": r, "seed": int(player.t * 1000.0) % 997})
		player.main.damage_area(player.position, r, player.skill_damage("ancrage") * up, 30.0, "racine")
