## Monde vivant du Marais (région spore) : réactions propres, ajoutées à celles de world_life.gd.
##
## Exemple du contrat d'une région (aucun registre : world_life.gd charge
## res://scripts/world_art/<région>_vivant.gd s'il existe) :
##   static func react(life, kind, pos, force) -> bool : appelée avant la réaction commune ; vrai la
##     remplace, faux s'y ajoute ;
##   static func ambient(life, delta) : chaque image, quand le héros est dans la région.
## Dessin seul : life.add_bit, life.add_mark, life.push, life.decor_near, life.col.
##
## Marais : bouffées de spores des champignons secoués (coups, charges) ; un coup lourd ou une ruée
## soulève aussi les spores du sol ; un coup près d'une mare l'éclabousse ; au repos, les champignons
## vivants lâchent quelques spores luisantes et les mares croupies remontent des bulles.
extends RefCounted

const DecorMarais = preload("res://scripts/decor_marais.gd")

static var _clock := 0.0
static var _bubble_clock := 0.0
static var _dash_clock := 0.0


## Un coup ou une charge près des champignons : une bouffée de spores qui monte.
static func react(life, kind: String, pos: Vector2, force: float) -> bool:
	if not (kind in ["heavy", "hit", "charge", "blast"]):
		return false
	var n := 0
	var pooled := false
	for t in life.decor_near(pos, 120.0):
		if _is_mushroom(t) and n < 3:
			n += 1
			_puff(life, t, 3 if kind == "heavy" else 2)
		elif not pooled and t.get_script() == DecorMarais.DecorPool and kind != "charge":
			pooled = true
			life.splash(t.position.lerp(pos, 0.5), 0.8 * force)
	if kind == "heavy" or kind == "blast":
		_ground_puff(life, pos, 4)
	return false


## Au repos, les champignons vivants proches lâchent de loin en loin quelques spores luisantes ; les
## mares flétries remontent des bulles ; la ruée soulève les spores du sol.
static func ambient(life, delta: float) -> void:
	var p = life.main.player
	_clock -= delta
	_bubble_clock -= delta
	_dash_clock -= delta
	if p.dash_time > 0.0 and _dash_clock <= 0.0:
		_dash_clock = 0.12
		_ground_puff(life, p.position + Vector2(0.0, p.radius * 0.8), 1)
	if _bubble_clock <= 0.0:
		_bubble_clock = 0.9
		for t in life.decor_near(p.position, 420.0):
			if t.get_script() == DecorMarais.DecorPool and not t.alive and life.rng.randf() < 0.45:
				var sz := float(t.get("size") if t.get("size") != null else 1.0)
				var at: Vector2 = t.position + Vector2(life.rng.randf_range(-16.0, 16.0), life.rng.randf_range(-4.0, 4.0)) * sz
				life.add_mark("ride", at, 0.9, life.col("spore", "eau"), 0.3, 0.8)
				life.add_bit("goutte", at, 2.0, Vector2.ZERO, 30.0, Color(life.col("spore", "spore"), 0.7), 0.5, 0.5)
				break
	if _clock > 0.0:
		return
	_clock = 1.4
	for t in life.decor_near(p.position, 360.0):
		if _is_mushroom(t) and t.alive and life.rng.randf() < 0.5:
			_puff(life, t, 1)
			return


## Champignon du Marais : l'ancien dessin (DecorMarais.DecorMushroom) ou un objet de la planche W.
static func _is_mushroom(t) -> bool:
	if t.get_script() == DecorMarais.DecorMushroom:
		return true
	var k = t.get("kind")
	return k != null and str(k) in ["champignon", "chapeau_geant"]


static func _puff(life, t, n: int) -> void:
	var h := 26.0 * float(t.get("size") if t.get("size") != null else 1.0)
	if t.get("kind") != null:
		h *= 3.0
	for i in life._qty(n):
		var v: Vector2 = Vector2(life.rng.randf_range(-22.0, 22.0), life.rng.randf_range(-8.0, 6.0))
		life.add_bit("spore", t.position + Vector2(life.rng.randf_range(-8.0, 8.0), 0.0), h, v, 14.0, life.col("spore", "spore"), 0.7, 2.8, 0.6)


## Spores soulevées du sol (coup lourd, ruée) : basses, qui retombent lentement.
static func _ground_puff(life, pos: Vector2, n: int) -> void:
	for i in life._qty(n):
		var v: Vector2 = Vector2.from_angle(life.rng.randf() * TAU) * life.rng.randf_range(18.0, 46.0)
		life.add_bit("spore", pos + v * 0.2, 3.0, v, life.rng.randf_range(24.0, 40.0), life.col("spore", "spore"), 0.6, 2.4, 0.8)
