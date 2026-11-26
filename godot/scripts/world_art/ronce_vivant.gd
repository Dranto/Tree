## Monde vivant du Roncier (région ronce) : réactions propres, ajoutées à celles de world_life.gd
## (contrat : voir spore_vivant.gd).
##   - les ronces s'écartent au passage du héros : haies, buissons et arbres proches se couchent loin
##     de lui (plus fort à la ruée) et lâchent une feuille, ou un pétale d'églantine sur la terre ravivée ;
##   - les épines frémissent à l'annonce d'une attaque lourde : autour d'un Flétri qui arme son coup
##     (élite ou gros), le décor proche se tord par à-coups ;
##   - un coup lourd fait pleuvoir des pétales des haies en fleur.
## Dessin seul : balancement (life.push) et débris cuits (life.add_bit) ; rien n'est lu du hasard du jeu.
extends RefCounted

## Sortes du Roncier qui s'écartent (objets de world_art/decor.gd posés par decor_compose.gd).
const SOUPLES := ["haie", "buisson", "arbre", "grand_arbre"]

static var _clock := 0.0
static var _warn_clock := 0.0


static func react(life, kind: String, pos: Vector2, force: float) -> bool:
	if kind != "heavy" and kind != "blast":
		return false
	# Pétales qui tombent des haies en fleur secouées par le coup.
	var n := 0
	for t in life.decor_near(pos, 160.0):
		if n >= 3 or not _souple(t) or not t.alive:
			continue
		n += 1
		_shed(life, t, 2 if kind == "heavy" else 1, true)
	return false


static func ambient(life, delta: float) -> void:
	var p = life.main.player
	_clock -= delta
	_warn_clock -= delta
	if _clock <= 0.0 and p.walk > 0.12:
		_clock = 0.12
		var dash: bool = p.dash_time > 0.0
		var feet: Vector2 = p.position + Vector2(0.0, p.radius * 0.8)
		var r := 95.0 if dash else 64.0
		var near := false
		for t in life.decor_near(feet, r + 40.0):
			if _souple(t):
				near = true
				if life._ready_again(t, 0.9):
					_shed(life, t, 1, t.alive)
		if near:
			# Plus large et plus fort que le froissement commun : la ronce s'ouvre devant le héros.
			life.push(feet + p.move_dir * 18.0, r + 50.0, 1.5 if dash else 1.0)
	if _warn_clock <= 0.0:
		_warn_clock = 0.22
		var n := 0
		for e in life.main.enemies_near(p.position, 620.0, false):
			if n >= 2:
				break
			var st := str(e.get("state") if e.get("state") != null else "")
			if st != "windup":
				continue
			var er := float(e.get("radius") if e.get("radius") != null else 14.0)
			if e.get("elite") != true and er < 16.0:
				continue
			n += 1
			# Torsion brève, renouvelée tant que dure l'annonce : les épines frémissent.
			life.push(e.position, 90.0 + er * 3.0, -0.5 if n == 1 else -0.35)


static func _souple(t) -> bool:
	var k = t.get("kind")
	return k != null and str(k) in SOUPLES


static func _shed(life, t, n: int, alive: bool) -> void:
	var h := 40.0 * float(t.get("size") if t.get("size") != null else 1.0)
	var f := "petale" if alive and life.rng.randf() < 0.6 else "feuille"
	var c: Color = life.col("ronce", "pas") if f == "petale" else life.col("ronce", "bris_vif" if alive else "bris_mort")
	for i in life._qty(n):
		var at: Vector2 = t.position + Vector2(life.rng.randf_range(-16.0, 16.0), 0.0)
		life.add_bit(f, at, h * life.rng.randf_range(0.6, 1.1), Vector2(life.rng.randf_range(-26.0, 26.0), life.rng.randf_range(-4.0, 10.0)), 20.0, c, 0.75, 2.8, 1.0)
