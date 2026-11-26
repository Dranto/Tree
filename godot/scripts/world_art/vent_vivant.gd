## Monde vivant des Plateaux (région vent, refonte du monde vague 2 P3) : réactions propres, ajoutées à
## celles de world_life.gd (contrat : world_art/spore_vivant.gd).
##   - une rafale qui passe arrache des plumets aux herbes hautes et des plumes aux arbres tordus, qui
##     filent avec elle ; les oiseaux posés sur son passage s'envolent ;
##   - un coup lourd près des herbes hautes en fait jaillir une gerbe de plumets ;
##   - au calme, de loin en loin, une plume se détache et dérive sous le vent dominant.
## Dessin seul : life.add_bit, life.push, life.scare, life.decor_near, life.col. Réduire les effets :
## quantités divisées par trois (life._qty).
extends RefCounted

const DecorPlateau = preload("res://scripts/decor_plateau.gd")
const SolVent = preload("res://scripts/world_bake/sol/vent.gd")

static var _clock := 0.0
static var _gust_clock := 0.0


static func _soft(t) -> bool:
	var s = t.get_script()
	return s == DecorPlateau.Grass or s == DecorPlateau.Twisted


static func _plume_col(life, t) -> Color:
	return life.col("vent", "plume" if t.alive else "plume_mort")


## Un coup près des herbes hautes : une gerbe de plumets qui s'envole.
static func react(life, kind: String, pos: Vector2, force: float) -> bool:
	if not (kind in ["heavy", "blast", "hit", "charge"]):
		return false
	var n := 0
	var many := kind in ["heavy", "blast"]
	for t in life.decor_near(pos, 130.0 if many else 80.0):
		if t.get_script() == DecorPlateau.Grass and n < (3 if many else 1):
			n += 1
			var away: Vector2 = (t.position - pos).normalized() if t.position.distance_squared_to(pos) > 1.0 else Vector2.UP
			_lift(life, t, life._qty(3 if many else 1), away * 90.0 * clampf(force, 0.6, 1.5))
	return false


## Chaque image dans la région : plumes arrachées par la rafale en cours, et une plume de temps en temps.
static func ambient(life, delta: float) -> void:
	var p = life.main.player
	if p == null:
		return
	if life.gust["force"] > 0.0:
		_gust_clock -= delta
		if _gust_clock <= 0.0:
			_gust_clock = 0.22
			var dir: Vector2 = life.gust_dir
			var front: float = life.gust["front"]
			var width: float = life.gust["width"]
			var n := 0
			for t in life.decor_near(p.position, 560.0):
				if n >= 2 or not _soft(t):
					continue
				if absf(t.position.dot(dir) - front) < width * 0.6 and life.rng.randf() < 0.45:
					n += 1
					_lift(life, t, 1, dir * life.rng.randf_range(200.0, 280.0))
					life.scare(t.position, 110.0)
		return
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = life.rng.randf_range(2.5, 4.5)
	var near: Array = life.decor_near(p.position, 420.0).filter(func(t): return _soft(t))
	if near.is_empty():
		return
	var t = near[life.rng.randi() % near.size()]
	_lift(life, t, 1, Vector2(SolVent.side() * life.rng.randf_range(40.0, 70.0), life.rng.randf_range(-10.0, 10.0)))


static func _lift(life, t, n: int, v: Vector2) -> void:
	var h := (30.0 if t.get_script() == DecorPlateau.Twisted else 14.0) * float(t.get("size") if t.get("size") != null else 1.0)
	for i in n:
		var at: Vector2 = t.position + Vector2(life.rng.randf_range(-10.0, 10.0), 0.0)
		life.add_bit("plume", at, h * life.rng.randf_range(0.6, 1.0), v + Vector2(life.rng.randf_range(-20, 20), life.rng.randf_range(-12, 12)),
			life.rng.randf_range(20.0, 40.0), _plume_col(life, t), life.rng.randf_range(0.7, 0.95), 3.2, 1.0)
