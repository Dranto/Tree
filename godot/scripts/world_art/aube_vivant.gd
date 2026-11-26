## Monde vivant des Falaises (région aube, refonte du monde vague 2 P5) : réactions propres, ajoutées à
## celles de world_life.gd (contrat : voir spore_vivant.gd).
##   - reflets : au repos, les cristaux et les éclats proches du héros accrochent la lumière de loin en
##     loin (une lueur brève sur une arête ; sur la terre ravivée, plus souvent et dorée) ;
##   - un coup lourd ou une charge près des cristaux : ils tintent, des éclats de verre sautent et
##     retombent en scintillant ;
##   - les lucioles dorées et les papillons sont la faune de la région (data/feel.json, couleurs
##     Art.MONDE › vivant › aube).
## Dessin seul : life.add_bit, life.decor_near, life.col ; images cuites du monde vivant (« eclat »,
## « lueur »). Aucun chiffre de jeu, aucune collision.
extends RefCounted

const DecorFalaise = preload("res://scripts/decor_falaise.gd")

static var _clock := 0.0


## Cristaux et éclats (ce qui brille) parmi le décor.
static func _shiny(t) -> bool:
	var s = t.get_script()
	return s == DecorFalaise.Crystals or s == DecorFalaise.Cluster or s == DecorFalaise.Shards or s == DecorFalaise.Spire \
		or s == DecorFalaise.Arch or s == DecorFalaise.Cliff


## Hauteur approximative (px du monde) du sommet d'un élément brillant.
static func _top(t) -> float:
	var s = t.get_script()
	if s == DecorFalaise.Crystals:
		return float(t.radius) * 2.0
	if s == DecorFalaise.Cliff:
		return float(t.radius) * 1.0
	if s == DecorFalaise.Shards:
		return 4.0
	return 16.0 * float(t.size) * 0.7


## Coup lourd, charge ou souffle près des cristaux : éclats qui sautent et lueurs (s'ajoute au commun).
static func react(life, kind: String, pos: Vector2, force: float) -> bool:
	if not (kind in ["heavy", "blast", "charge"]):
		return false
	var n := 0
	for t in life.decor_near(pos, 150.0):
		if n >= 3 or not _shiny(t):
			continue
		n += 1
		_chime(life, t, 3 if kind != "charge" else 2, force)
	return false


## Au repos : un reflet bref sur un cristal ou un éclat proche, de loin en loin.
static func ambient(life, delta: float) -> void:
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = life.rng.randf_range(0.25, 0.55)
	var p = life.main.player
	var near: Array = life.decor_near(p.position, 420.0)
	near.shuffle()
	for t in near:
		if _shiny(t):
			_glint(life, t)
			return


static func _glint(life, t) -> void:
	var h := _top(t)
	var at: Vector2 = t.position + Vector2(life.rng.randf_range(-0.3, 0.3) * maxf(h, 12.0), 0.0)
	var c: Color = life.col("aube", "luciole") if t.alive else Color(0.82, 0.86, 0.95, 0.8)
	life.add_bit("lueur", at, h * life.rng.randf_range(0.4, 1.0), Vector2.ZERO, 12.0, c, 0.55 if t.alive else 0.4, 0.45, 0.01)


static func _chime(life, t, count: int, force: float) -> void:
	var h := _top(t)
	for i in life._qty(count):
		var a: float = life.rng.randf_range(PI * 1.15, PI * 1.85)
		var v: Vector2 = Vector2.from_angle(a) * life.rng.randf_range(30.0, 70.0) * clampf(force, 0.6, 1.4)
		var c: Color = life.col("aube", "bris_vif" if t.alive else "bris_mort")
		life.add_bit("eclat", t.position + Vector2(life.rng.randf_range(-8.0, 8.0), 0.0), h * life.rng.randf_range(0.4, 0.9),
			Vector2(v.x, v.y * 0.4), life.rng.randf_range(70.0, 120.0), c, life.rng.randf_range(0.55, 0.8), 1.6, 0.0)
	life.add_bit("lueur", t.position, h * 0.8, Vector2.ZERO, 20.0, life.col("aube", "luciole"), 0.8, 0.4, 0.01)
