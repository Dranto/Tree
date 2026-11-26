## Matière du sol de la région « vent » (Plateaux), refonte du monde vague 2 (ground_layers.gd › SOL_REGION).
##
## Chaque fonction dessine un élément du calque d'un carré de sol à la place de la matière provisoire
## commune, et rend true ; elle rend false pour garder le dessin commun, **sans avoir tiré e** (les
## tirages suivants doivent rester les mêmes). L : le calque (ground_layers.gd › TileLayer), dont on
## appelle les primitives : L._tri, L._fan, L._oval, L._line, L._polyline, L._blade, L._leaf,
## L._pebble, L._tuft, L._flower ; L._p : palette de la région (fletri, apaise, ravive) ; e : le tirage
## de l'élément (RandomNumberGenerator), le même à chaque construction du carré.
## La géométrie ne dépend pas de la vie : le shader du calque choisit quoi montrer (mort, ravivé, front).
## Couleurs depuis Art.MONDE (palette de la région) ou pal ; aucune collision, aucun texte.
##
## Plateaux (P3) : un pays ouvert que le vent peigne toujours du même côté.
##   - terre morte : dalles de pierre plate à demi enterrées, mouchetées de lichen gris ; herbe sèche
##     grège couchée par le vent ; plumes grises tombées ;
##   - terre ravivée : herbe argentée couchée en longues mèches, touffes à plumets (stipe) penchées sous
##     le vent, petites fleurs blanches et bleu pâle, plumes blanches ;
##   - bord de vie : fleurs blanches en étoile et petits plumets.
## Tout penche du côté du vent dominant (data/regions/vent.json › wind, comme decor_plateau.gd).
extends RefCounted

const Regions = preload("res://scripts/regions.gd")

static var _side := 0.0


## Côté où le vent couche l'herbe à l'écran (-1 ou 1), comme le décor (decor_compose.gd › _wind_lean).
static func side() -> float:
	if _side == 0.0:
		var w := Regions.section("vent", "wind")
		var d := Vector2.from_angle(Regions.angle_of("vent") + float(w.get("angle", 0.0)))
		_side = 1.0 if d.x >= 0.0 else -1.0
	return _side


static func _c(etat: String, key: String):
	return Art.mc("vent", etat, key)


## Brin couché par le vent : part de b, monte à peine (rise) et file sur « len » du côté du vent.
static func _laid(L, b: Vector2, len: float, rise: float, w: float, col: Color) -> void:
	var s := side()
	var tip := b + Vector2(s * len * (1.0 - rise * 0.4), -len * rise)
	var mid := b.lerp(tip, 0.45) + Vector2(0, -len * 0.08)
	var n := (tip - b).orthogonal().normalized()
	L._fan(PackedVector2Array([b - n * w * 0.5, mid - n * w * 0.35, tip, mid + n * w * 0.35, b + n * w * 0.5]), col)


## Plume posée au sol : un vane asymétrique et son rachis, couchée selon a.
static func _feather(L, q: Vector2, a: float, l: float, vane: Color, rachis: Color) -> void:
	var d := Vector2.from_angle(a)
	var n := d.orthogonal()
	L._fan(PackedVector2Array([q, q + d * l * 0.35 + n * l * 0.2, q + d * l * 0.8 + n * l * 0.12, q + d * l, q + d * l * 0.6 - n * l * 0.15, q + d * l * 0.25 - n * l * 0.12]), vane)
	L._line(q - d * l * 0.12, q + d * l * 0.92, maxf(0.6, l * 0.06), rachis)


## Dalle de pierre plate à demi enterrée : ombre, face, arête claire côté lumière, fissure, lichen.
static func _slab(L, c: Vector2, r: float, e: RandomNumberGenerator, etat: String) -> void:
	var st: Dictionary = _c(etat, "pierre")
	var pts := PackedVector2Array()
	var n := 7
	var rot := e.randf() * 0.8
	for i in n:
		var a := rot + TAU * i / n
		var k := e.randf_range(0.78, 1.08)
		pts.append(c + Vector2(cos(a) * r * k, sin(a) * r * 0.48 * k))
	var sh := PackedVector2Array()
	for q in pts:
		sh.append(q + Vector2(1.2, 1.6))
	L._fan(sh, Color(st["ombre"].darkened(0.45), 0.4))
	L._fan(pts, Color(st["clair"], 0.62 if etat == "fletri" else 0.7))
	L._polyline(PackedVector2Array([pts[3], pts[4], pts[5]]), 1.0, Color(st["reflet"], 0.35))
	if e.randf() < 0.6:
		L._line(c + Vector2(-r * 0.4, -r * 0.05), c + Vector2(r * 0.15, r * 0.12), 0.8, Color(_c(etat, "matiere"), 0.45))
	for i in e.randi_range(1, 3):
		var q := c + Vector2(e.randf_range(-0.55, 0.55) * r, e.randf_range(-0.25, 0.15) * r)
		L._oval(q, e.randf_range(1.6, 3.0), e.randf_range(1.0, 1.8), Color(_c(etat, "lichen"), 0.55), 6)


## Touffe penchée sous le vent (plumets clairs au bout des brins quand plume est vrai).
static func _bent_tuft(L, q: Vector2, h: float, c1: Color, c2: Color, e: RandomNumberGenerator, plume: Color = Color.TRANSPARENT) -> void:
	var s := side()
	var n := 4 + (e.randi() % 3)
	for j in n:
		var x := (j - (n - 1) * 0.5) * h * 0.14
		var hh := h * (0.6 + 0.4 * e.randf()) * (1.0 if j == n / 2 else 0.85)
		var lean := s * (0.55 + 0.35 * e.randf()) + x / h * 0.6
		L._blade(q + Vector2(x, 0), hh, lean, h * 0.12 + 0.6, c1 if j % 2 == 0 else c2)
		if plume.a > 0.0 and j % 2 == 0:
			var tip := q + Vector2(x + lean * hh, -hh)
			L._oval(tip + Vector2(s * 1.4, 0.3), 2.2 + h * 0.06, 1.0 + h * 0.02, plume, 5)


## Terre morte, matière (couche 2) en p ; i : 0 ou 1 (deux tirages par case), sd : graine de e.
static func dead_matter(L, p: Vector2, i: int, _sd: int, e: RandomNumberGenerator) -> bool:
	if i == 0:
		if e.randf() < 0.62:
			_slab(L, p, e.randf_range(9.0, 17.0), e, "fletri")
		else:
			# Lichen gris en rosettes sur la roche affleurante.
			for k in e.randi_range(3, 6):
				var q := p + Vector2(e.randf_range(-14, 14), e.randf_range(-6, 6))
				var r := e.randf_range(1.8, 3.6)
				L._oval(q, r, r * 0.6, Color(_c("fletri", "lichen"), 0.4), 7)
				L._oval(q + Vector2(-0.4, -0.3), r * 0.45, r * 0.3, Color(_c("fletri", "cendre"), 0.35), 5)
	else:
		# Herbe sèche couchée : une mèche de brins grèges, tous du même côté.
		var f: Dictionary = L._p["fletri"]
		for k in e.randi_range(4, 7):
			var b := p + Vector2(e.randf_range(-6, 6), e.randf_range(-4, 4))
			_laid(L, b, e.randf_range(10.0, 17.0), e.randf_range(0.12, 0.26), 1.5, Color(f["touffe" if k % 2 == 0 else "touffe_2"], 0.8))
	return true


## Terre ravivée, matière vivante (couche 2) en p.
static func alive_matter(L, p: Vector2, e: RandomNumberGenerator) -> bool:
	var herbe: Dictionary = _c("ravive", "herbe")
	if e.randf() < 0.22:
		_feather(L, p, e.randf_range(-0.5, 0.5) + (0.0 if side() > 0.0 else PI), e.randf_range(7.0, 10.0), Color(_c("ravive", "plume"), 0.9), Color(_c("ravive", "plume_ombre"), 0.9))
		return true
	# Herbe argentée couchée en longue mèche : brins clairs et ombrés mêlés.
	for k in e.randi_range(5, 8):
		var b := p + Vector2(e.randf_range(-9, 9), e.randf_range(-4, 4))
		var col: Color = herbe["clair"] if k % 3 == 0 else (herbe["ombre"] if k % 3 == 1 else herbe["reflet"])
		_laid(L, b, e.randf_range(13.0, 22.0), e.randf_range(0.14, 0.3), 1.6, Color(col, 0.78))
	return true


## Un objet d'une grappe de la terre morte (couche 3) ; big : 1 pour le plus grand, 0,45-0,8 sinon ;
## kind : 0 touffes, 1 cailloux, 2 cendre (choisi une fois par grappe) ; pal : L._p["fletri"].
static func dead_item(L, p: Vector2, big: float, kind: int, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	match kind:
		0:
			_bent_tuft(L, p, 11.0 * big, pal["touffe"], pal["touffe_2"], e)
		1:
			# Pierres plates (plus larges que hautes), une moucheture de lichen sur les grandes.
			var st: Dictionary = pal["pierre"]
			var rx := 2.6 + 4.2 * big
			L._oval(p + Vector2(1.0, 1.2), rx, rx * 0.45, Color(st["ombre"].darkened(0.4), 0.55), 6)
			L._oval(p, rx, rx * 0.45, st["clair"], 6)
			L._tri(p + Vector2(-0.8, -0.1) * rx, p + Vector2(-0.1, -0.42) * rx, p + Vector2(0.3, -0.2) * rx, st["reflet"])
			if big > 0.9:
				L._oval(p + Vector2(rx * 0.25, -rx * 0.12), 1.6, 1.0, Color(_c("fletri", "lichen"), 0.7), 5)
		_:
			# Plume grise tombée, ou cendre balayée en traînée sous le vent.
			if e.randf() < 0.45:
				_feather(L, p, e.randf_range(-0.7, 0.7) + (0.0 if side() > 0.0 else PI), 5.0 + 4.0 * big, Color(_c("fletri", "plume"), 0.85), Color(_c("fletri", "plume_ombre"), 0.85))
			else:
				L._oval(p + Vector2(side() * 2.0 * big, 0), 4.5 + 5.0 * big, 1.5 + 1.4 * big, Color(pal["cendre"], 0.35), 6)
	return true


## Un objet d'une grappe de la terre ravivée (couche 3) ; k dans [0, 1) : < 0,55 touffe, < 0,85 fleur,
## sinon caillou ou baie ; pal : L._p["ravive"].
static func alive_item(L, p: Vector2, big: float, k: float, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	var herbe: Dictionary = _c("ravive", "herbe")
	if k < 0.55:
		# Stipe : touffe argentée penchée, plumets blancs au bout des brins.
		_bent_tuft(L, p, 14.0 * big, herbe["clair"], herbe["ombre"], e, Color(_c("ravive", "plume"), 0.9))
	elif k < 0.85:
		# Petites fleurs blanches (parfois bleu pâle) sur une tige courbée par le vent.
		var s := side()
		var top := p + Vector2(s * 3.0 * big, -9.0 * big)
		L._line(p, top, 0.9, herbe["ombre"])
		var petal: Color = _c("ravive", "fleur_2" if e.randf() < 0.3 else "fleur")
		L._flower(top, 2.0 + 1.8 * big, petal, _c("ravive", "fleur_coeur"))
		if big > 0.6:
			L._flower(top + Vector2(-s * 4.0, 3.5) * big, 1.6 + big, petal, _c("ravive", "fleur_coeur"))
	elif e.randf() < 0.5:
		_feather(L, p, e.randf_range(-0.6, 0.6) + (0.0 if side() > 0.0 else PI), 6.0 + 4.0 * big, _c("ravive", "plume"), _c("ravive", "plume_ombre"))
	else:
		var st: Dictionary = pal["pierre"]
		var rx := 2.4 + 3.2 * big
		L._oval(p + Vector2(1.0, 1.2), rx, rx * 0.45, Color(st["ombre"].darkened(0.4), 0.5), 6)
		L._oval(p, rx, rx * 0.45, st["clair"], 6)
		L._oval(p + Vector2(-rx * 0.2, -rx * 0.15), rx * 0.4, rx * 0.2, Color(_c("ravive", "lichen"), 0.85), 5)
	return true


## Une fleur du bord de vie, juste derrière le front, en p (rayon r) ; pal : L._p.
static func flower(L, p: Vector2, r: float, _pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if e.randf() < 0.3:
		# Petit plumet couché.
		var s := side()
		var herbe: Dictionary = _c("ravive", "herbe")
		L._blade(p + Vector2(0, r * 1.6), r * 2.6, s * 0.7, 1.2, herbe["ombre"])
		L._oval(p + Vector2(s * r * 1.6, -r * 0.6), r * 0.9, r * 0.4, _c("ravive", "plume"), 6)
	else:
		L._flower(p, r * 0.85, _c("ravive", "fleur_2" if e.randf() < 0.25 else "fleur"), _c("ravive", "fleur_coeur"))
	return true
