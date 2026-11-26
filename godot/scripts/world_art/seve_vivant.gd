## Monde vivant de la Vallée (région seve) : réactions propres, ajoutées à celles de world_life.gd
## (contrat : voir spore_vivant.gd ; dessin seul : life.add_bit, life.add_mark, life.push, life.splash).
##   - un coup près d'un saule ou d'une liane vivants secoue ses rideaux : des gouttes en tombent ;
##   - un coup lourd près d'une source l'éclabousse ;
##   - au repos, les saules vivants proches s'égouttent, et une goutte ride de loin en loin une source.
## Papillons et grenouilles : la faune commune de la région (data/feel.json › world › life › regions).
extends RefCounted

const DecorVallee = preload("res://scripts/decor_vallee.gd")

static var _clock := 0.0


static func _wet(t) -> bool:
	var s = t.get_script()
	return (s == DecorVallee.Willow or s == DecorVallee.Liana) and t.alive


static func react(life, kind: String, pos: Vector2, force: float) -> bool:
	if not (kind in ["heavy", "hit", "charge", "blast"]):
		return false
	var heavy := kind in ["heavy", "blast"]
	var n := 0
	for t in life.decor_near(pos, 160.0 if heavy else 110.0):
		if n >= 3:
			break
		if _wet(t):
			n += 1
			_drip(life, t, 4 if heavy else 2)
		elif heavy and t.get_script() == DecorVallee.Spring and life._ready_again(t, 0.4):
			n += 1
			life.splash(t.position, 1.2 * clampf(force, 0.6, 1.4))
	return false


static func ambient(life, delta: float) -> void:
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = 0.9
	var p = life.main.player
	for t in life.decor_near(p.position, 380.0):
		if _wet(t) and life.rng.randf() < 0.35:
			_drip(life, t, 1)
			return
		if t.get_script() == DecorVallee.Spring and t.alive and life.rng.randf() < 0.25:
			var at: Vector2 = t.position + Vector2(life.rng.randf_range(-12.0, 12.0), life.rng.randf_range(-5.0, 5.0)) * t.size
			life.add_mark("ride", at, 1.3, life.col("seve", "eau"), 0.4, 1.0)
			return


## Gouttes qui tombent des rideaux (sous la couronne, de part et d'autre du tronc).
static func _drip(life, t, n: int) -> void:
	var s := float(t.get("size") if t.get("size") != null else 1.0)
	var h := 30.0 * s
	var wd := 20.0 * s
	for i in life._qty(n):
		var at: Vector2 = t.position + Vector2(life.rng.randf_range(-wd, wd), life.rng.randf_range(-2.0, 4.0))
		life.add_bit("goutte", at, h * life.rng.randf_range(0.5, 0.9), Vector2(life.rng.randf_range(-8.0, 8.0), 0.0), -10.0, life.col("seve", "eau"), 0.7, 0.9)
