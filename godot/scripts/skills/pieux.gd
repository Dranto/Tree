## Pieux : « count » pieux de bois jaillissent du sol l'un après l'autre (« gap » s d'écart), en ligne
## du joueur vers l'endroit visé (au plus « range » px). Chaque pieu blesse les ennemis dans
## « radius » × taille des zones et les cloue un instant (« root_duration » × durée d'immobilisation ;
## un ennemi "no_root": true est blessé sans être retenu). Mutations (data/skills.json) : « ring »
## (les pieux jaillissent en cercle autour du joueur), « stay » (les pieux restent « stay » s et
## blessent par à-coups les ennemis qui les frôlent : STAY_PART × dégâts toutes les STAY_TICK s).
extends Skill

const TornadeScript = preload("res://scripts/skills/tornade.gd")
const RING_RADIUS := 120.0
const STAY_TICK := 0.5
const STAY_PART := 0.35

## Pieux à venir : {pos, wait, dmg, r, hold, stay}.
var queue: Array = []
## Pieux restés plantés (Palissade) : {pos, left, tick, dmg, r, fx}.
var standing: Array = []


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("pieux")
	RacineFx.sound("racine_pieux", "racines", p.position)
	var n: int = maxi(1, int(round(float(k["count"]))))
	var r: float = float(k["radius"]) * float(s.get("area", 1.0))
	var dmg: float = p.skill_damage("pieux")
	var hold: float = float(k["root_duration"]) * float(s.get("root_duration", 1.0))
	var gap := float(k.get("gap", 0.05))
	var stay := float(k.get("stay", 0.0))
	var at: Array = spots(p.position, p.aim_point, k, n, r)
	for pos in at:
		queue.append({"pos": pos, "wait": gap * queue.size(), "dmg": dmg, "r": r, "hold": hold, "stay": stay})
	# Signature : la fente court sous le sol vers chaque point (purement visuel).
	TornadeScript.fx(p, "pieux_fissure", {"pos": p.position, "spots": at, "gap": gap, "r": r,
		"ring": bool(k.get("ring", false)), "dur": gap * maxf(n - 1, 0) + 0.45})


## Points où jaillissent les pieux : une ligne vers « to » (au plus « range »), ou un cercle.
static func spots(from: Vector2, to: Vector2, k: Dictionary, n: int, r: float) -> Array:
	var out: Array = []
	if k.get("ring", false):
		var rr := maxf(RING_RADIUS, r * 2.2)
		for i in n:
			out.append(from + Vector2.from_angle(TAU * i / n) * rr)
		return out
	var off := to - from
	var dir := off.normalized() if off.length() > 1.0 else Vector2.RIGHT
	var length := clampf(off.length(), r * 2.0 * n, float(k["range"]))
	var first := r * 1.1
	var step := (length - first) / maxf(n - 1, 1)
	for i in n:
		out.append(from + dir * (first + step * i))
	return out


func tick(delta: float) -> void:
	if player == null:
		return
	var i := 0
	while i < queue.size():
		var q: Dictionary = queue[i]
		q["wait"] -= delta
		if q["wait"] <= 0.0:
			queue.remove_at(i)
			_erupt(q)
			continue
		i += 1
	i = 0
	while i < standing.size():
		var st: Dictionary = standing[i]
		st["left"] -= delta
		if st["left"] <= 0.0:
			standing.remove_at(i)
			continue
		st["tick"] -= delta
		if st["tick"] <= 0.0:
			st["tick"] += STAY_TICK
			for e in player.main.enemies_near(st["pos"], st["r"]):
				if not e.dead:
					player.main.player_hit_enemy(e, st["dmg"], false, "racine")
		i += 1


func _erupt(q: Dictionary) -> void:
	var main = player.main
	var stay: float = q["stay"]
	var fx := TornadeScript.fx(player, "pieu", {"pos": q["pos"], "r": q["r"], "dur": 0.55 + stay,
		"seed": int(q["pos"].x * 7.0 + q["pos"].y * 13.0) % 997})
	main.root_hit_base = q["dmg"]
	for e in main.enemies_near(q["pos"], q["r"]):
		if e.dead:
			continue
		main.player_hit_enemy(e, q["dmg"], true, "racine")
		if not e.dead:
			e.apply_status("enracine", 1.0, q["hold"])
	main.root_hit_base = 0.0
	if stay > 0.0:
		standing.append({"pos": q["pos"], "left": stay, "tick": STAY_TICK, "dmg": q["dmg"] * STAY_PART, "r": q["r"] * 0.8, "fx": fx})
