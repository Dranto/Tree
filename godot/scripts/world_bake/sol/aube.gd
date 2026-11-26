## Matière du sol de la région « aube » (Falaises), refonte du monde vague 2 P5 (ground_layers.gd › SOL_REGION).
##
## Flétri : calcaire froid en strates (lignes d'encre fines, liseré clair au-dessus, lumière d'en haut à
## gauche), éclats de verre fumé couchés, pierres plates anguleuses, poussière de verre.
## Ravivé : prairie de miel semée d'éclats de nacre qui accrochent la lumière et de poussière dorée ;
## fleurs d'aube en étoile (nacre, cœur d'or) et petits quartz clairs dans les grappes.
##
## Chaque fonction dessine un élément du calque d'un carré de sol à la place de la matière provisoire
## commune, et rend true ; elle rend false pour garder le dessin commun, **sans avoir tiré e** (les
## tirages suivants doivent rester les mêmes). L : le calque (ground_layers.gd › TileLayer), dont on
## appelle les primitives : L._tri, L._fan, L._oval, L._line, L._polyline, L._blade, L._leaf,
## L._pebble, L._tuft, L._flower ; L._p : palette de la région (fletri, apaise, ravive) ; e : le tirage
## de l'élément (RandomNumberGenerator), le même à chaque construction du carré.
## La géométrie ne dépend pas de la vie : le shader du calque choisit quoi montrer (mort, ravivé, front).
## Couleurs depuis Art.MONDE (palette de la région) ou pal ; aucune collision, aucun texte.
extends RefCounted


static func _m(etat: String, key: String):
	return Art.mc("aube", etat, key)


## Éclat plat couché au sol : un losange effilé, face sombre et face claire, arête lumineuse.
static func _shard(L, c: Vector2, l: float, a: float, glass: Dictionary, glint: float) -> void:
	var d := Vector2.from_angle(a) * Vector2(1.0, 0.55)
	var n := Vector2(-d.y, d.x).normalized() * l * 0.22 * Vector2(1.0, 0.6)
	var p0 := c - d * l * 0.5
	var p1 := c + d * l * 0.5
	L._tri(p0, c + n, p1, glass["clair"])
	L._tri(p0, p1, c - n, glass["ombre"])
	if glint > 0.0:
		L._line(p0.lerp(c + n, 0.5), p1.lerp(c + n, 0.3), 0.8, Color(glass["reflet"], glint))


## Petite étincelle en croix (reflet qui accroche la lumière).
static func _spark(L, c: Vector2, r: float, col: Color) -> void:
	L._line(c - Vector2(r, 0), c + Vector2(r, 0), 0.7, col)
	L._line(c - Vector2(0, r * 1.3), c + Vector2(0, r * 1.3), 0.7, col)


## Terre morte, matière (couche 2) en p ; i : 0 ou 1 (deux tirages par case), sd : graine de e.
static func dead_matter(L, p: Vector2, i: int, _sd: int, e: RandomNumberGenerator) -> bool:
	var pal: Dictionary = L._p["fletri"]
	if i == 0:
		# Strates du calcaire : deux ou trois lignes presque horizontales, empilées, liseré clair dessus.
		var ink: Color = pal["matiere"]
		var lite: Color = pal["pierre"]["reflet"]
		var len := e.randf_range(26.0, 46.0)
		var tilt := e.randf_range(-0.12, 0.12)
		for k in 2:
			var y := k * e.randf_range(4.5, 6.5)
			var x0 := e.randf_range(-6.0, 6.0) - len * 0.5 + k * 3.0
			var l := len * e.randf_range(0.55, 1.0)
			var pts := PackedVector2Array()
			for j in 4:
				var u := j / 3.0
				pts.append(p + Vector2(x0 + l * u, y + tilt * l * u + sin(u * 5.0 + k) * 0.8))
			if k == 0:
				L._line(pts[0] + Vector2(0.4, -1.3), pts[2] + Vector2(0.4, -1.3), 0.7, Color(lite, 0.22))
			L._polyline(pts, 1.0, Color(ink, 0.5 - k * 0.08))
		return true
	# Éclats de verre fumé couchés, deux à quatre.
	var glass: Dictionary = _m("fletri", "verre")
	for k in e.randi_range(1, 3):
		var q := p + Vector2(e.randf_range(-14.0, 14.0), e.randf_range(-6.0, 6.0))
		_shard(L, q, e.randf_range(5.0, 9.0), e.randf() * PI, glass, 0.4)
	return true


## Terre ravivée, matière vivante (couche 2) en p : éclats de nacre qui brillent, poussière d'or.
static func alive_matter(L, p: Vector2, e: RandomNumberGenerator) -> bool:
	var nacre: Dictionary = _m("ravive", "nacre")
	var gold: Color = _m("ravive", "lueur")
	for k in e.randi_range(1, 3):
		var q := p + Vector2(e.randf_range(-16.0, 16.0), e.randf_range(-7.0, 7.0))
		_shard(L, q, e.randf_range(4.0, 7.5), e.randf() * PI, nacre, 0.8)
	for k in e.randi_range(3, 5):
		var q := p + Vector2(e.randf_range(-22.0, 22.0), e.randf_range(-10.0, 10.0))
		L._tri(q + Vector2(-1.0, 0.5), q + Vector2(0.0, -1.0), q + Vector2(1.0, 0.5), Color(gold, 0.75))
	if e.randf() < 0.5:
		_spark(L, p + Vector2(e.randf_range(-8.0, 8.0), e.randf_range(-6.0, 2.0)), 2.6, Color(nacre["reflet"], 0.85))
	return true


## Un objet d'une grappe de la terre morte (couche 3) ; big : 1 pour le plus grand, 0,45-0,8 sinon ;
## kind : 0 touffes, 1 cailloux, 2 cendre (choisi une fois par grappe) ; pal : L._p["fletri"].
static func dead_item(L, p: Vector2, big: float, kind: int, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if kind == 0:
		return false
	if kind == 1:
		# Pierre plate de calcaire, anguleuse : ombre, flanc sombre, dessus clair, une strate.
		var st: Dictionary = pal["pierre"]
		var rx := 3.0 + 4.6 * big
		var pts := PackedVector2Array()
		var rot := e.randf() * 0.6
		for j in 6:
			var a := rot + TAU * j / 6.0
			pts.append(p + Vector2(cos(a) * rx, sin(a) * rx * 0.55) * e.randf_range(0.82, 1.1))
		var side := PackedVector2Array()
		for q in pts:
			side.append(q + Vector2(0, rx * 0.28))
		L._fan(side, st["ombre"])
		L._fan(pts, st["clair"])
		if rx > 4.5:
			L._line(pts[3].lerp(pts[4], 0.5), pts[0].lerp(pts[5], 0.5), 0.8, Color(st["ombre"], 0.6))
			L._tri(pts[3], pts[2], p, Color(st["reflet"], 0.7))
		return true
	# Verre fumé : un éclat debout et deux couchés.
	var glass: Dictionary = _m("fletri", "verre")
	_shard(L, p, 4.0 + 5.0 * big, e.randf() * PI, glass, 0.45)
	if big > 0.9:
		var h := 7.0 + 3.0 * e.randf()
		L._tri(p + Vector2(-2.2, 0), p + Vector2(0.6, -h), p + Vector2(2.4, 0.4), glass["clair"])
		L._tri(p + Vector2(-2.2, 0), p + Vector2(0.6, -h), p + Vector2(-0.4, 0.8), glass["ombre"])
	return true


## Un objet d'une grappe de la terre ravivée (couche 3) ; k dans [0, 1) : < 0,55 touffe, < 0,85 fleur,
## sinon caillou ou baie ; pal : L._p["ravive"].
static func alive_item(L, p: Vector2, big: float, k: float, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if k < 0.55:
		return false
	if k < 0.85:
		# Fleur d'aube : une touffe dorée, une étoile de nacre à six pointes, un cœur d'or.
		L._tuft(p, 8.0 * big, pal["touffe"], pal["touffe_2"])
		_star(L, p + Vector2(e.randf_range(-1.5, 1.5), -7.5 * big), 2.4 + 2.2 * big, pal["fleur"], pal["fleur_coeur"])
		return true
	# Petit quartz clair : deux ou trois aiguilles de nacre et de verre, une étincelle au sommet.
	var nacre: Dictionary = _m("ravive", "nacre")
	var glass: Dictionary = _m("ravive", "verre")
	var n := 2 + e.randi() % 2
	L._oval(p + Vector2(1.5, 1.0), 5.0 * big + 2.0, 1.8 * big + 1.0, Color(pal["matiere"], 0.4), 6)
	var top := p
	for j in n:
		var g: Dictionary = nacre if j % 2 == 0 else glass
		var x := (j - (n - 1) * 0.5) * 3.2 * big
		var h := (7.0 + 6.0 * e.randf()) * big * (1.2 if j == n / 2 else 0.85)
		var tip := p + Vector2(x + (x * 0.25), -h)
		L._tri(p + Vector2(x - 1.8 * big - 0.6, 0), tip, p + Vector2(x, 0.8), g["ombre"])
		L._tri(p + Vector2(x, 0.8), tip, p + Vector2(x + 1.8 * big + 0.6, 0), g["clair"])
		if tip.y < top.y:
			top = tip
	_spark(L, top + Vector2(0.5, -0.5), 2.2, Color(nacre["reflet"], 0.9))
	return true


## Une fleur du bord de vie, juste derrière le front, en p (rayon r) ; pal : L._p.
static func flower(L, p: Vector2, r: float, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	var rv: Dictionary = pal["ravive"]
	_star(L, p, r, _m("ravive", "fleur_2") if e.randf() < 0.4 else rv["fleur"], rv["fleur_coeur"])
	return true


## Étoile à six pointes arrondies (douze points) et son cœur.
static func _star(L, q: Vector2, r0: float, petal: Color, heart: Color) -> void:
	var pts := PackedVector2Array([q])
	for k in 13:
		pts.append(q + Vector2.from_angle(TAU * k / 12.0 - PI / 2.0) * r0 * (1.3 if k % 2 == 0 else 0.6) * Vector2(1.0, 0.8))
	L._fan(pts, petal.darkened(0.08))
	L._oval(q + Vector2(-0.2, -0.3), r0 * 0.45, r0 * 0.38, heart, 5)
