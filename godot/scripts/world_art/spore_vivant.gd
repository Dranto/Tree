## Monde vivant du Marais (région spore) : réactions propres, ajoutées à celles de world_life.gd.
##
## Exemple du contrat d'une région (aucun registre : world_life.gd charge
## res://scripts/world_art/<région>_vivant.gd s'il existe) :
##   static func react(life, kind, pos, force) -> bool : appelée avant la réaction commune ; vrai la
##     remplace, faux s'y ajoute ;
##   static func ambient(life, delta) : chaque image, quand le héros est dans la région.
## Dessin seul : life.add_bit, life.add_mark, life.push, life.decor_near, life.col.
extends RefCounted

const DecorMarais = preload("res://scripts/decor_marais.gd")

static var _clock := 0.0


## Un coup ou une charge près des champignons : une bouffée de spores qui monte.
static func react(life, kind: String, pos: Vector2, force: float) -> bool:
	if not (kind in ["heavy", "hit", "charge", "blast"]):
		return false
	var n := 0
	for t in life.decor_near(pos, 120.0):
		if t.get_script() == DecorMarais.DecorMushroom and n < 3:
			n += 1
			_puff(life, t, 3 if kind == "heavy" else 2)
	return false


## Au repos, les champignons vivants proches lâchent de loin en loin quelques spores luisantes.
static func ambient(life, delta: float) -> void:
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = 1.4
	var p = life.main.player
	for t in life.decor_near(p.position, 360.0):
		if t.get_script() == DecorMarais.DecorMushroom and t.alive and life.rng.randf() < 0.5:
			_puff(life, t, 1)
			return


static func _puff(life, t, n: int) -> void:
	var h := 26.0 * float(t.get("size") if t.get("size") != null else 1.0)
	for i in life._qty(n):
		var v := Vector2(life.rng.randf_range(-22.0, 22.0), life.rng.randf_range(-8.0, 6.0))
		life.add_bit("spore", t.position + Vector2(life.rng.randf_range(-8.0, 8.0), 0.0), h, v, 14.0, life.col("spore", "spore"), 0.7, 2.8, 0.6)
