## Monde vivant de la Forêt pétrifiée (région racine), refonte du monde vague 2 (P6) : réactions propres,
## ajoutées à celles de world_life.gd (contrat : voir spore_vivant.gd).
##   - coup lourd ou souffle près d'un arbre de pierre, d'une souche ou d'une racine : la pierre craque
##     (une étoile de fêlures sombres au pied), des éclats et de la sciure tombent ; ravivé, des feuilles
##     d'or tombent aussi ;
##   - coup ou charge : un peu de sciure qui tombe du décor touché ;
##   - au repos : des feuilles d'or qui se détachent des arbres ravivés proches, de la poussière de
##     pierre qui s'écoule des arbres flétris.
## Dessin seul : life.add_bit, life.add_mark, life.push, life.decor_near, life.col.
extends RefCounted

const DecorForet = preload("res://scripts/decor_foret.gd")

static var _clock := 0.0


static func _stony(t) -> bool:
	return t is DecorForet.Petrified or t is DecorForet.Ancient


static func _height(t) -> float:
	var s := float(t.get("size") if t.get("size") != null else 1.0)
	if t is DecorForet.StoneTree:
		return 52.0 * s * 0.6
	if t is DecorForet.Ancient or t is DecorForet.RootArch:
		return 16.0 * s * 0.6
	return 20.0 * s


static func react(life, kind: String, pos: Vector2, force: float) -> bool:
	if not (kind in ["heavy", "blast", "hit", "charge"]):
		return false
	var heavy := kind in ["heavy", "blast"]
	var n := 0
	for t in life.decor_near(pos, 150.0 if heavy else 90.0):
		if not _stony(t) or n >= (3 if heavy else 1):
			continue
		n += 1
		var top: Vector2 = t.position
		var h := _height(t)
		var alive: bool = t.get("alive") == true
		for i in life._qty(3 if heavy else 1):
			var v := Vector2(life.rng.randf_range(-30.0, 30.0), life.rng.randf_range(-6.0, 10.0))
			life.add_bit("sciure", top + Vector2(life.rng.randf_range(-8.0, 8.0), 0.0), h * life.rng.randf_range(0.5, 1.0), v, 40.0, life.col("racine", "bris_mort" if not alive else "bris_vif"), 0.8, 1.6)
		if heavy:
			# La pierre craque : fêlures sombres au pied, éclats.
			life.add_mark("eclabous", top + Vector2(0, 2), 0.9, Color(Art.mc("commun", "", "encre_decor"), 0.55), 1.2 + 0.3 * force, 0.15)
			for i in life._qty(2):
				var a: float = life.rng.randf_range(PI * 1.1, PI * 1.9)
				life.add_bit("caillou", top + Vector2(0, -h * 0.4), h * 0.4, Vector2.from_angle(a) * life.rng.randf_range(30.0, 70.0), 90.0, life.col("racine", "bris_mort"), 0.7, 1.2)
			if alive:
				for i in life._qty(3):
					life.add_bit("feuille", top + Vector2(life.rng.randf_range(-20.0, 20.0), 0.0), h * life.rng.randf_range(0.8, 1.3), Vector2(life.rng.randf_range(-25.0, 25.0), 6.0), 20.0, Art.mc("racine", "ravive", "feuille" if i % 2 else "feuille_2"), 0.8, 3.0, 1.0)
	return false


static func ambient(life, delta: float) -> void:
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = 1.1
	var p = life.main.player
	var near: Array = life.decor_near(p.position, 380.0)
	near.shuffle()
	for t in near:
		if not (t is DecorForet.StoneTree or t is DecorForet.Ancient):
			continue
		var h := _height(t)
		var at: Vector2 = t.position + Vector2(life.rng.randf_range(-16.0, 16.0), 0.0)
		if t.alive:
			life.add_bit("feuille", at, h * life.rng.randf_range(1.0, 1.4), Vector2(life.rng.randf_range(-18.0, 18.0), 4.0), 10.0, Art.mc("racine", "ravive", "feuille" if life.rng.randf() < 0.6 else "feuille_2"), 0.75, 3.6, 1.0)
		else:
			life.add_bit("sciure", at, h * life.rng.randf_range(0.6, 1.0), Vector2(life.rng.randf_range(-6.0, 6.0), 2.0), 5.0, life.col("racine", "bris_mort"), 0.6, 1.8)
		return
