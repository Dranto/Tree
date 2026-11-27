## Les abords du creux de la finale (world_art/finale_creux.gd) : la terre tout autour du puits, que la
## caméra montre pendant tout le combat. Dessinés par le code (« Paysages d'herbier »), puis cuits en
## carreaux opaques par finale_creux.gd : rien de plus n'est dessiné en direct, hors les braises.
##
## Vu d'en haut, de trois quarts, autour de la lèvre :
##   - la terre affaissée vers le creux : des failles concentriques, des plaques soulevées ;
##   - les racines de la graine, énormes, qui convergent vers le puits (certaines en arche, leur ombre
##     dessous) ; et les veines noires de la Flétrissure qui en sortent, fendues de braise ;
##   - un cercle de menhirs gravés, le sceau qui la tenait, à moitié renversé, pris dans les racines ;
##   - six secteurs, un par région, où la terre garde ce que la Flétrissure a bu : ronciers fossiles
##     (ouest), mycélium et chapeaux (nord-ouest), ardoises et plumes (nord), lits de sève figée et
##     lianes (nord-est), cristaux (est), troncs pétrifiés et ambre (sud-est) ; au sud, la lumière du
##     puits et les éboulis de la chute ; au sud-ouest, le squelette d'un ancien colosse ;
##   - le menu : cendre, galets, feuilles mortes de la région voisine, herbe sèche, os.
## Tout est tiré une fois (graines fixes), en liste d'éléments avec leur boîte : chaque carreau ne
## dessine que ceux qui le touchent.
##
## Repère : centre du creux en (0, 0), px du monde. Dessin seul : aucune collision, aucun réglage.
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

## Mêmes mesures que finale_creux.gd (largeur de la lèvre, hauteur de la paroi au nord).
const T := 38.0
const H := 200.0
## Les six secteurs autour du creux (angle en degrés, 0 : est, 90 : sud).
const SECTEURS := {"ronce": 180.0, "spore": -138.0, "vent": -96.0, "seve": -50.0, "aube": -4.0, "racine": 42.0}
## Le puits de lumière (sud) et l'ossuaire (sud-ouest).
const PUITS := 90.0
const OSSUAIRE := 136.0
## Distance au-delà de la lèvre jusqu'où l'on dessine (px) : l'écran le plus large n'en voit pas plus.
const PORTEE := 1500.0

static var _items: Array = []
static var _items_r := -1.0
static var _glows: Array = []


# --- Géométrie ---

static func hk(a: float) -> float:
	return pow(0.5 - 0.5 * sin(a), 1.5)


## Point de la lèvre à l'angle a (radians), poussé de d px vers l'extérieur.
static func at(rr: float, a: float, d: float) -> Vector2:
	return Vector2.from_angle(a) * (rr + T + d) - Vector2(0.0, H * hk(a))


static func atd(rr: float, deg: float, d: float) -> Vector2:
	return at(rr, deg_to_rad(deg), d)


static func _box(pts: PackedVector2Array, m: float) -> Rect2:
	var b := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		b = b.expand(p)
	return b.grow(m)


## Plus c'est loin du creux, plus c'est sombre (0 : sur la lèvre, 1 : au bord de l'écran).
static func far_k(d: float) -> float:
	return clampf(d / 1000.0, 0.0, 1.0)


static func dim(col: Color, k: float) -> Color:
	return col.darkened(0.12 + 0.38 * k)


static func dpal(pal: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in pal:
		out[key] = dim(pal[key], k)
	return out


static func cc(key: String) -> Color:
	return Art.MONDE["commun"]["creux"][key]


static func fc(reg: String, key: String):
	return Art.mc(reg, "fletri", key)


# --- Liste des éléments ---

## Les éléments des abords, dans l'ordre du dessin : [boîte (Rect2), Callable(ci)].
static func items(rr: float) -> Array:
	if rr == _items_r and not _items.is_empty():
		return _items
	_items = []
	_glows = []
	_items_r = rr
	_wash(rr)
	_faults(rr)
	_light(rr)
	_veins(rr)
	_roots(rr)
	_sector_ronce(rr)
	_sector_spore(rr)
	_sector_vent(rr)
	_sector_seve(rr)
	_sector_aube(rr)
	_sector_racine(rr)
	_sector_puits(rr)
	_ossuary(rr)
	_seal(rr)
	_scatter(rr)
	return _items


## Points chauds des veines de la Flétrissure (braises animées par l'arène), centre du creux en (0, 0).
static func glows(rr: float) -> Array:
	items(rr)
	return _glows


static func _add(box: Rect2, fn: Callable) -> void:
	_items.append([box, fn])


## Dessine un carreau des abords (rect : px du monde autour du centre du creux).
static func paint_tile(ci: CanvasItem, rect: Rect2, rr: float) -> void:
	ci.draw_rect(rect.grow(4.0), cc("terre"))
	for it in items(rr):
		if (it[0] as Rect2).intersects(rect):
			(it[1] as Callable).call(ci)


## Tout, sans carreaux (repli sans cuisson).
static func paint_all(ci: CanvasItem, rr: float) -> void:
	for it in items(rr):
		(it[1] as Callable).call(ci)


# --- Couche 1 : la terre ---

## Lavis : grandes taches de terre plus claire ou plus sombre, plus claires près du creux.
static func _wash(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var light: Color = cc("croute")
	var dark: Color = cc("terre").darkened(0.35)
	# Un halo de terre remuée autour de la lèvre, en anneaux.
	for i in 5:
		var d := 60.0 + i * 95.0
		var pts := PackedVector2Array()
		for j in 120:
			var a := TAU * j / 120.0
			pts.append(at(rr, a, d + 22.0 * O.wave(a * 5.0, 3.0 + i)))
		var col := Color(light, 0.16 - 0.025 * i)
		_add(_box(pts, 2.0), func(ci): O.poly(ci, pts, col))
	for i in 46:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, PORTEE)
		var c := at(rr, a, d)
		var rx := rng.randf_range(140.0, 380.0)
		var ry := rx * rng.randf_range(0.45, 0.7)
		var col := Color(light if i % 3 else dark, rng.randf_range(0.12, 0.22) * (1.0 - 0.5 * far_k(d)))
		var pts := O.blob(c, rx, ry, i * 1.3, 0.22, 36, rng.randf_range(-0.4, 0.4))
		_add(_box(pts, 2.0), func(ci): O.poly(ci, pts, col))


## La terre affaissée : failles concentriques autour du creux (fente noire, bord soulevé plus clair
## du côté du creux), coupées de fentes qui rayonnent ; des plaques soulevées entre elles.
static func _faults(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var crack: Color = cc("fissure")
	var lip: Color = cc("croute").lightened(0.06)
	for ring: float in [150.0, 390.0, 700.0, 1050.0]:
		var a := rng.randf() * TAU
		var end := a + TAU
		while a < end:
			var span := rng.randf_range(0.35, 0.9) * (520.0 / (ring + 300.0))
			var pts := PackedVector2Array()
			var n := 14
			for j in n + 1:
				var u := a + span * j / n
				pts.append(at(rr, u, ring + 26.0 * O.wave(u * 9.0, ring) + rng.randf_range(-4.0, 4.0)))
			var k := far_k(ring)
			var w := rng.randf_range(8.0, 15.0) * (1.0 - 0.3 * k)
			var lipc := Color(dim(lip, k), 0.7)
			var cr := Color(crack, 0.9)
			# Le bord soulevé (vers le creux, la lumière du puits), puis la fente.
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(p - (p - Vector2(0, -H * 0.3)).normalized() * (w * 0.6 + 2.0))
			_add(_box(pts, 30.0), func(ci):
				O.brush(ci, inner, w * 0.5, lipc, 0.8, 0.8)
				O.brush(ci, pts, w, cr, 0.9, 0.9)
				O.brush(ci, pts, w * 0.35, Color(0, 0, 0, 0.8), 0.9, 0.9))
			# Fentes qui rayonnent depuis la faille.
			if rng.randf() < 0.8:
				var from := pts[rng.randi_range(3, n - 3)]
				var dir := (from - Vector2(0, -H * 0.3)).normalized().rotated(rng.randf_range(-0.5, 0.5)) * (1.0 if rng.randf() < 0.5 else -1.0)
				var q := PackedVector2Array([from])
				for j in 4:
					q.append(q[q.size() - 1] + dir.rotated(rng.randf_range(-0.5, 0.5)) * rng.randf_range(18.0, 40.0))
				var cw := w * 0.6
				_add(_box(q, 8.0), func(ci): O.brush(ci, q, cw, cr, 0.0, 1.0))
			a += span + rng.randf_range(0.05, 0.3) * (520.0 / (ring + 300.0))
	# Plaques soulevées : de grandes dalles de terre, leur tranche sombre au sud.
	for i in 34:
		var aa := rng.randf() * TAU
		var d := rng.randf_range(60.0, 1100.0)
		var c := at(rr, aa, d)
		var k := far_k(d)
		var w := rng.randf_range(50.0, 110.0)
		var top := O.blob(c, w, w * 0.45, i * 2.1, 0.14, 9, rng.randf_range(-0.5, 0.5))
		var edge := Transform2D(0.0, Vector2(0, 7)) * top
		var tc := Color(dim(cc("croute"), k), 0.55)
		var ec := Color(crack, 0.8)
		_add(_box(edge, 4.0), func(ci):
			O.poly(ci, edge, ec)
			O.poly(ci, top, tc)
			ci.draw_polyline(top + PackedVector2Array([top[0]]), Color(crack, 0.6), 1.2, true))


## La lumière du puits (au sud) qui déborde sur la terre, et un reflet chaud de braise ailleurs.
static func _light(rr: float) -> void:
	var lc: Color = cc("lumiere")
	var base := atd(rr, PUITS, 40.0)
	for i in 8:
		var k := 1.0 - i * 0.11
		var pts := O.blob(base + Vector2(0, 40.0 + 12.0 * i), 520.0 * k, 260.0 * k, 3.0 + i * 0.4, 0.12, 48)
		var col := Color(lc, 0.025)
		_add(_box(pts, 2.0), func(ci): O.poly(ci, pts, col))
	var ember := Art.bc("braise")
	for spot in [[-30.0, 260.0], [160.0, 420.0], [-150.0, 520.0], [20.0, 600.0], [110.0, 200.0]]:
		var c := atd(rr, float(spot[0]), float(spot[1]))
		for i in 4:
			var k := 1.0 - i * 0.2
			var pts := O.blob(c, 260.0 * k, 150.0 * k, spot[0] + i, 0.15, 36)
			var col := Color(ember, 0.018)
			_add(_box(pts, 2.0), func(ci): O.poly(ci, pts, col))


# --- Couche 2 : veines de la Flétrissure et racines de la graine ---

## Les veines noires de la Flétrissure : elles sortent du creux, se ramifient en éclairs, fendues de
## braise par endroits (ces points chauds sont animés en direct par l'arène).
static func _veins(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6660
	var black := Art.bc("ronge").darkened(0.35)
	var ember := Art.bc("braise")
	var hot := Art.bc("braise_coeur")
	for i in 18:
		var a := TAU * i / 18.0 + rng.randf_range(-0.12, 0.12)
		var pts := PackedVector2Array([at(rr, a, -6.0)])
		var dir := Vector2.from_angle(a)
		var len := rng.randf_range(500.0, 1250.0)
		var step := 34.0
		var n := int(len / step)
		for j in n:
			dir = dir.rotated(rng.randf_range(-0.38, 0.38)).lerp(Vector2.from_angle(a), 0.25).normalized()
			pts.append(pts[pts.size() - 1] + dir * step * rng.randf_range(0.8, 1.2))
		var w := rng.randf_range(9.0, 15.0)
		_add_vein(pts, w, black, ember, hot, rng)
		# Branches, et leurs brindilles.
		for b in rng.randi_range(2, 4):
			var k := rng.randi_range(2, n - 3)
			var bd := (pts[k + 1] - pts[k]).normalized().rotated(rng.randf_range(0.5, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0))
			var bp := PackedVector2Array([pts[k]])
			for j in rng.randi_range(4, 9):
				bd = bd.rotated(rng.randf_range(-0.45, 0.45))
				bp.append(bp[bp.size() - 1] + bd * rng.randf_range(20.0, 34.0))
			_add_vein(bp, w * 0.55, black, ember, hot, rng)


static func _add_vein(pts: PackedVector2Array, w: float, black: Color, ember: Color, hot: Color, rng: RandomNumberGenerator) -> void:
	var halo := Color(black, 0.35)
	var core := Color(black, 0.95)
	var line := Color(ember, 0.55)
	# La braise court dans une partie de la veine seulement.
	var i0 := rng.randi_range(0, maxi(0, pts.size() / 3))
	var i1 := mini(pts.size(), i0 + rng.randi_range(3, maxi(4, pts.size() / 2)))
	var fire := pts.slice(i0, i1)
	_add(_box(pts, w * 2.0), func(ci):
		O.brush(ci, pts, w * 2.2, halo, 0.2, 1.0)
		O.brush(ci, pts, w, core, 0.1, 1.0)
		if fire.size() >= 2:
			O.brush(ci, fire, w * 0.32, line, 1.0, 1.0)
			ci.draw_polyline(fire, Color(hot, 0.35), 1.0, true))
	if fire.size() >= 2 and w > 6.0:
		_glows.append(fire[fire.size() / 2])


## Les racines de la graine qui convergent vers le creux : écorce en trois tons et encre, nœuds,
## radicelles ; certaines sortent de terre en arche (ombre portée dessous).
static func _roots(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1717
	var bark: Dictionary = Art.mc("commun", "", "ecorce")
	for i in 15:
		var a := TAU * (i + 0.5) / 15.0 + rng.randf_range(-0.1, 0.1)
		var bend := rng.randf_range(-0.22, 0.22)
		var pts := PackedVector2Array()
		var n := 10
		for j in n + 1:
			var u := float(j) / n
			# De loin (u = 0) jusqu'à la lèvre, où elle plonge.
			var d := lerpf(PORTEE * rng.randf_range(0.8, 1.0), -4.0, u)
			pts.append(at(rr, a + bend * (1.0 - u) * (1.0 - u) + 0.04 * sin(u * 9.0 + i), d))
		var k := 0.25
		var pal := dpal(bark, k)
		var w := rng.randf_range(34.0, 62.0)
		var arch := i % 4 == 1
		var lift := rng.randi_range(3, 6)
		_add(_box(pts, w + 30.0), func(ci): _big_root(ci, pts, w, pal, lift if arch else -1))
		# Racines filles : elles se détachent et filent de côté.
		for b in rng.randi_range(2, 3):
			var kk := rng.randi_range(1, n - 3)
			var dir := (pts[kk + 1] - pts[kk]).normalized().rotated(rng.randf_range(0.6, 1.1) * (1.0 if b % 2 else -1.0))
			var bp := PackedVector2Array([pts[kk]])
			for j in 5:
				dir = dir.rotated(rng.randf_range(-0.25, 0.25))
				bp.append(bp[bp.size() - 1] + dir * rng.randf_range(45.0, 80.0))
			var bw := w * rng.randf_range(0.3, 0.45)
			_add(_box(bp, bw + 10.0), func(ci): _big_root(ci, bp, bw, pal, -1))


## Une grosse racine vue d'en haut : ombre, encre, ombre propre, face éclairée, reflet, rides et
## nœuds. lift >= 0 : elle sort de terre en arche autour du point lift (ombre portée décalée).
static func _big_root(ci: CanvasItem, pts: PackedVector2Array, w: float, pal: Dictionary, lift: int) -> void:
	var sh := Transform2D(0.0, O.SHADOW_DIR * w * 0.35) * pts
	O.brush(ci, sh, w * 1.15, Color(0.02, 0.01, 0.01, 0.45), 0.6, 0.1)
	if lift >= 0 and lift + 2 < pts.size():
		var arch := pts.slice(lift - 1, lift + 3)
		O.brush(ci, Transform2D(0.0, O.SHADOW_DIR * w * 1.6) * arch, w * 1.1, Color(0.02, 0.01, 0.01, 0.4), 1.0, 1.0)
	O.brush(ci, pts, w + 4.0, Ink.encre(), 0.6, 0.1)
	O.brush(ci, pts, w, pal["ombre"], 0.6, 0.1)
	var lit := Transform2D(0.0, Vector2(-w * 0.16, -w * 0.2)) * pts
	O.brush(ci, lit, w * 0.6, pal["clair"], 0.6, 0.1)
	var hi := Transform2D(0.0, Vector2(-w * 0.26, -w * 0.3)) * pts
	O.brush(ci, hi, w * 0.14, Color(pal["reflet"], 0.6), 0.5, 0.2)
	# Rides de l'écorce : de courts traits en travers.
	for j in range(1, pts.size() - 1):
		var d := (pts[j + 1] - pts[j - 1]).normalized()
		var nrm := d.orthogonal()
		for s in 2:
			var q := pts[j].lerp(pts[j + 1], 0.25 + 0.5 * s)
			var ww := w * (0.6 - 0.04 * j) * 0.5
			ci.draw_line(q + nrm * ww - d * 3.0, q - nrm * ww * 0.3 + d * 2.0, Color(pal["ombre"].darkened(0.4), 0.7), 1.4, true)
	# Un nœud.
	if pts.size() > 4:
		var q := pts[pts.size() / 3]
		O.poly(ci, O.blob(q, w * 0.32, w * 0.22, q.x, 0.15, 14), pal["ombre"].darkened(0.3))
		ci.draw_arc(q, w * 0.18, 0.0, TAU, 14, Color(pal["clair"], 0.6), 1.2, true)


# --- Couche 3 : les secteurs des régions ---

static func _spread(rng: RandomNumberGenerator, deg: float, span: float, d0: float, d1: float, rr: float) -> Vector2:
	return atd(rr, deg + rng.randf_range(-span, span), rng.randf_range(d0, d1))


## Dist. d'un point à la lèvre (approchée), pour l'assombrir avec l'éloignement.
static func _d_of(p: Vector2, rr: float) -> float:
	return maxf(0.0, (p + Vector2(0, H * 0.4)).length() - rr - T)


## Ouest : des ronciers fossiles, masses de tiges noueuses hérissées d'épines, baies séchées.
static func _sector_ronce(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var deg: float = SECTEURS["ronce"]
	for i in 13:
		var c := _spread(rng, deg, 28.0, 30.0 + i * 70.0, 130.0 + i * 85.0, rr)
		var s := rng.randf_range(0.8, 1.5) * (1.25 if i < 3 else 1.0)
		var k := far_k(_d_of(c, rr))
		var seed := rng.randi()
		_add(Rect2(c - Vector2(130, 110) * s, Vector2(260, 200) * s), func(ci): _bramble(ci, c, s, k, seed))


static func _bramble(ci: CanvasItem, c: Vector2, s: float, k: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pal := dpal(fc("ronce", "ronce"), k)
	var berry: Color = dim(fc("ronce", "fruit"), k)
	var leaf: Color = dim(fc("ronce", "feuille"), k)
	O.cast_shadow(ci, c + Vector2(0, 30) * s, 200.0 * s, 40.0 * s, 0.3)
	for i in 14:
		var a := rng.randf_range(-PI, 0.2)
		var l := rng.randf_range(60.0, 120.0) * s
		var from := c + Vector2(rng.randf_range(-60, 60), rng.randf_range(-10, 30)) * s
		var to := from + Vector2.from_angle(a) * l
		var mid := from.lerp(to, 0.5) + Vector2.from_angle(a + PI / 2.0) * rng.randf_range(-30.0, 30.0) * s
		var pts := O.curve(from, mid, to, 10)
		var w := rng.randf_range(4.0, 7.0) * s
		O.brush(ci, pts, w + 2.5, Ink.encre(), 1.0, 0.2)
		O.brush(ci, pts, w, pal["ombre"], 1.0, 0.2)
		O.brush(ci, Transform2D(0.0, Vector2(-0.6, -0.8) * s) * pts, w * 0.4, pal["clair"], 1.0, 0.2)
		for j in range(1, 10, 2):
			var q := pts[j]
			var d := (pts[j + 1] - pts[j - 1]).normalized()
			var nrm := d.orthogonal() * (1.0 if j % 4 == 1 else -1.0)
			O.poly(ci, PackedVector2Array([q - d * 2.6 * s, q + d * 2.6 * s, q + (nrm * 7.0 + d * 2.5) * s]), pal["ombre"].darkened(0.35))
		if i % 3 == 0:
			O.poly(ci, O.blob(to, 6.0 * s, 3.0 * s, i, 0.2, 10, a), leaf)
		if i % 4 == 1:
			ci.draw_circle(to + Vector2(2, 2) * s, 3.0 * s, berry)
			ci.draw_circle(to + Vector2(-3, 4) * s, 2.4 * s, berry.darkened(0.2))


## Nord-ouest : le mycélium (fils pâles qui courent sous la cendre) et des chapeaux en grappes.
static func _sector_spore(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var deg: float = SECTEURS["spore"]
	var thread := Color(fc("spore", "chapeau")["clair"].darkened(0.3), 0.28)
	var nodes := []
	for i in 34:
		nodes.append(_spread(rng, deg, 26.0, 20.0, 950.0, rr))
	for i in nodes.size():
		var p: Vector2 = nodes[i]
		var best := -1
		var bd := 1e9
		for j in nodes.size():
			var dd := p.distance_squared_to(nodes[j])
			if j != i and dd < bd:
				bd = dd
				best = j
		var q: Vector2 = nodes[best]
		var pts := O.curve(p, p.lerp(q, 0.5) + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)), q, 8)
		_add(_box(pts, 4.0), func(ci): ci.draw_polyline(pts, thread, 1.6, true))
		var tw := PackedVector2Array([p, p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 70.0)])
		_add(_box(tw, 4.0), func(ci): ci.draw_polyline(tw, thread, 1.0, true))
	for i in 15:
		var c := _spread(rng, deg, 27.0, 20.0 + i * 50.0, 110.0 + i * 65.0, rr)
		var k := far_k(_d_of(c, rr))
		var seed := rng.randi()
		var s := rng.randf_range(0.8, 1.4)
		_add(Rect2(c - Vector2(80, 90) * s, Vector2(160, 130) * s), func(ci): _mushrooms(ci, c, s, k, seed))


static func _mushrooms(ci: CanvasItem, c: Vector2, s: float, k: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cap := dpal(fc("spore", "chapeau"), k)
	var foot := dpal(fc("spore", "pied"), k)
	var glow: Color = fc("spore", "lueur")
	O.cast_shadow(ci, c + Vector2(0, 14) * s, 120.0 * s, 50.0 * s, 0.3)
	var n := rng.randi_range(3, 6)
	var caps := []
	for i in n:
		caps.append([c + Vector2(rng.randf_range(-45, 45), rng.randf_range(-20, 20)) * s, rng.randf_range(12.0, 30.0) * s, rng.randf_range(12.0, 40.0) * s])
	caps.sort_custom(func(x, y): return x[0].y < y[0].y)
	for cp in caps:
		var base: Vector2 = cp[0]
		var w: float = cp[1]
		var h: float = cp[2]
		var top := base + Vector2(0, -h)
		# Pied, puis chapeau vu de trois quarts : dessus bombé, rebord, lames dessous.
		O.part(ci, PackedVector2Array([base + Vector2(-w * 0.22, 0), top + Vector2(-w * 0.16, 0), top + Vector2(w * 0.16, 0), base + Vector2(w * 0.22, 0)]), foot, 1.4, 1.0, 0.4)
		O.poly(ci, O.blob(top + Vector2(0, w * 0.12), w * 0.95, w * 0.3, w, 0.05, 18), foot["ombre"].darkened(0.3))
		var dome := PackedVector2Array()
		for j in 13:
			var u := PI + PI * j / 12.0
			dome.append(top + Vector2(cos(u) * w, sin(u) * w * 0.62))
		for j in 7:
			var u := PI * j / 6.0
			dome.append(top + Vector2(cos(u) * w, sin(u) * w * 0.22))
		O.part(ci, dome, cap, 1.6, 1.0, 0.7)
		for j in 3:
			ci.draw_circle(top + Vector2((j - 1) * w * 0.4, -w * 0.32 + 3.0 * (j % 2)), 2.0 * s, Color(cap["reflet"], 0.8))
		ci.draw_circle(top + Vector2(w * 0.2, -w * 0.7), 1.6 * s, Color(glow, 0.5 * (1.0 - k)))


## Nord : affleurements d'ardoise en lits penchés, et des plumes fossiles imprimées dans la pierre.
static func _sector_vent(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	var deg: float = SECTEURS["vent"]
	for i in 12:
		var c := _spread(rng, deg, 32.0, 20.0 + i * 40.0, 110.0 + i * 60.0, rr)
		var k := far_k(_d_of(c, rr))
		var seed := rng.randi()
		var s := rng.randf_range(0.9, 1.6)
		_add(Rect2(c - Vector2(110, 80) * s, Vector2(220, 150) * s), func(ci): _slates(ci, c, s, k, seed))
	for i in 7:
		var c := _spread(rng, deg, 34.0, 40.0, 520.0, rr)
		var k := far_k(_d_of(c, rr))
		var ang := rng.randf_range(-1.2, 1.2)
		var s := rng.randf_range(1.2, 2.2)
		_add(Rect2(c - Vector2(80, 80) * s, Vector2(160, 160) * s), func(ci): _fossil_feather(ci, c, s, ang, k))


static func _slates(ci: CanvasItem, c: Vector2, s: float, k: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pal := dpal(fc("vent", "pierre"), k)
	O.cast_shadow(ci, c + Vector2(0, 20) * s, 160.0 * s, 50.0 * s, 0.35)
	var tilt := rng.randf_range(-0.4, -0.1)
	for i in rng.randi_range(3, 5):
		var cc2 := c + Vector2(-30 + 18 * i, -14 * i + rng.randf_range(-4, 4)) * s
		var w := rng.randf_range(40.0, 70.0) * s
		var h := rng.randf_range(9.0, 15.0) * s
		var slab := PackedVector2Array()
		for v in 7:
			slab.append(cc2 + Vector2(lerpf(-w, w, v / 6.0), -h * (0.6 + 0.4 * rng.randf())).rotated(tilt))
		for v in 6:
			slab.append(cc2 + Vector2(lerpf(w, -w, (v + 0.5) / 6.0), h * (0.6 + 0.4 * rng.randf())).rotated(tilt))
		# La tranche (en dessous), puis le dessus de la dalle.
		O.poly(ci, Transform2D(0.0, Vector2(0, h * 0.9)) * slab, pal["ombre"].darkened(0.4))
		O.part(ci, slab, pal, 1.3, 1.0, 0.5)
		ci.draw_line(cc2 + Vector2(-w * 0.7, -h * 0.1).rotated(tilt), cc2 + Vector2(w * 0.6, -h * 0.3).rotated(tilt), Color(pal["reflet"], 0.45), 1.0, true)


static func _fossil_feather(ci: CanvasItem, c: Vector2, s: float, ang: float, k: float) -> void:
	var pal := dpal(fc("vent", "pierre"), k + 0.1)
	var imp := Color(pal["reflet"], 0.7)
	var dir := Vector2.from_angle(ang)
	var nrm := dir.orthogonal()
	var l := 62.0 * s
	# Une dalle d'ardoise, sa tranche, et la plume imprimée dedans.
	var slab := O.blob(c, l * 0.95, l * 0.55, c.x, 0.12, 10, ang * 0.3)
	O.cast_shadow(ci, c + Vector2(0, l * 0.3), l * 1.8, 12.0, 0.3)
	O.poly(ci, Transform2D(0.0, Vector2(0, 8)) * slab, pal["ombre"].darkened(0.45))
	O.part(ci, slab, pal, 1.4, 1.0, 0.4)
	var a := c - dir * l * 0.7
	var b := c + dir * l * 0.7
	ci.draw_line(a, b, imp, 2.0 * s, true)
	for i in 14:
		var u := (i + 1) / 15.0
		var q := a.lerp(b, u)
		var bw := l * 0.3 * sin(PI * minf(1.0, u * 1.15))
		for side: float in [-1.0, 1.0]:
			ci.draw_line(q, q + (nrm * side * bw + dir * bw * 0.45), Color(imp, 0.5), 1.2, true)


## Nord-est : des lits de sève figée (rivières vitreuses), des flaques, des lianes mortes couchées.
static func _sector_seve(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var deg: float = SECTEURS["seve"]
	var sap: Dictionary = fc("seve", "seve")
	for i in 3:
		var a := deg + rng.randf_range(-22.0, 22.0)
		var pts := PackedVector2Array()
		var n := 18
		for j in n + 1:
			var u := float(j) / n
			pts.append(atd(rr, a + 9.0 * sin(u * 7.0 + i * 2.0), lerpf(1100.0, -10.0, u)))
		var w := rng.randf_range(18.0, 30.0)
		_add(_box(pts, w + 6.0), func(ci): _sap_river(ci, pts, w, sap, rr))
	for i in 11:
		var c := _spread(rng, deg, 28.0, 30.0, 950.0, rr)
		var k := far_k(_d_of(c, rr))
		var rx := rng.randf_range(30.0, 70.0)
		var seed := float(i)
		_add(Rect2(c - Vector2(rx + 8, rx), Vector2(rx * 2 + 16, rx * 2)), func(ci): _sap_pool(ci, c, rx, sap, k, seed))
	var liane: Dictionary = fc("seve", "liane")
	var leaf: Color = fc("seve", "feuille")
	for i in 18:
		var c := _spread(rng, deg, 30.0, 20.0, 1000.0, rr)
		var k := far_k(_d_of(c, rr))
		var a := rng.randf() * TAU
		var l := rng.randf_range(120.0, 240.0)
		var to := c + Vector2.from_angle(a) * l
		var pts := O.curve(c, c.lerp(to, 0.5) + Vector2.from_angle(a + PI / 2.0) * rng.randf_range(-60.0, 60.0), to, 12)
		var pal := dpal(liane, k)
		var lf := dim(leaf, k)
		_add(_box(pts, 14.0), func(ci):
			O.brush(ci, Transform2D(0.0, O.SHADOW_DIR * 6.0) * pts, 7.0, Color(0, 0, 0, 0.3), 0.2, 0.2)
			O.brush(ci, pts, 7.0, Ink.encre(), 0.2, 0.6)
			O.brush(ci, pts, 5.0, pal["ombre"], 0.2, 0.6)
			O.brush(ci, Transform2D(0.0, Vector2(-1, -1)) * pts, 2.0, pal["clair"], 0.2, 0.6)
			for j in range(2, 12, 3):
				var side := 1.0 if j % 2 else -1.0
				var d := (pts[j + 1] - pts[j - 1]).normalized()
				O.poly(ci, O.blob(pts[j] + d.orthogonal() * side * 7.0, 7.0, 3.0, j, 0.1, 10, d.angle() + side * 0.6), lf))


static func _sap_river(ci: CanvasItem, pts: PackedVector2Array, w: float, sap: Dictionary, rr: float) -> void:
	O.brush(ci, pts, w + 10.0, Color(0.02, 0.02, 0.015, 0.55), 0.3, 0.0)
	var n := pts.size()
	for j in n - 1:
		var k := far_k(_d_of(pts[j], rr))
		var seg := pts.slice(j, j + 2)
		O.brush(ci, seg, w, dim(sap["ombre"], k + 0.15), 0.0, 0.0)
		O.brush(ci, Transform2D(0.0, Vector2(-w * 0.12, -w * 0.12)) * seg, w * 0.5, dim(sap["clair"], k + 0.25), 0.0, 0.0)
	O.brush(ci, Transform2D(0.0, Vector2(-w * 0.2, -w * 0.25)) * pts, 1.6, Color(sap["reflet"], 0.35), 0.4, 0.4)


static func _sap_pool(ci: CanvasItem, c: Vector2, rx: float, sap: Dictionary, k: float, seed: float) -> void:
	var rim := O.blob(c, rx + 6.0, rx * 0.5 + 4.0, seed, 0.2, 24)
	O.poly(ci, rim, Color(0.03, 0.02, 0.015, 0.7))
	O.poly(ci, O.blob(c, rx, rx * 0.5, seed, 0.2, 24), dim(sap["ombre"], k + 0.15))
	O.poly(ci, O.blob(c + Vector2(-rx * 0.15, -rx * 0.08), rx * 0.6, rx * 0.25, seed + 1.0, 0.2, 20), dim(sap["clair"], k + 0.3))
	ci.draw_line(c + Vector2(-rx * 0.5, -rx * 0.18), c + Vector2(-rx * 0.1, -rx * 0.24), Color(sap["reflet"], 0.45), 1.6, true)


## Est : des cristaux qui percent la terre en gerbes, des géodes ouvertes, des éclats de verre.
static func _sector_aube(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var deg: float = SECTEURS["aube"]
	for i in 17:
		var c := _spread(rng, deg, 28.0, 20.0 + i * 40.0, 100.0 + i * 60.0, rr)
		var k := far_k(_d_of(c, rr))
		var seed := rng.randi()
		var s := rng.randf_range(0.8, 1.7) * (1.3 if i == 1 or i == 4 else 1.0)
		_add(Rect2(c - Vector2(80, 130) * s, Vector2(160, 160) * s), func(ci): _crystals(ci, c, s, k, seed))
	var glass: Dictionary = fc("aube", "verre")
	for i in 60:
		var c := _spread(rng, deg, 30.0, 20.0, 1000.0, rr)
		var k := far_k(_d_of(c, rr))
		var r := rng.randf_range(3.0, 7.0)
		var a := rng.randf() * TAU
		var col := dim(glass["clair"], k + 0.1)
		var tri := PackedVector2Array([c + Vector2.from_angle(a) * r, c + Vector2.from_angle(a + 2.3) * r * 0.6, c + Vector2.from_angle(a + 3.9) * r * 0.8])
		_add(_box(tri, 2.0), func(ci): O.poly(ci, tri, col))


static func _crystals(ci: CanvasItem, c: Vector2, s: float, k: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pal := dpal(fc("aube", "verre"), k)
	var nacre := dpal(fc("aube", "nacre"), k)
	var rock := dpal(fc("aube", "roche"), k)
	O.cast_shadow(ci, c, 110.0 * s, 90.0 * s, 0.35)
	O.part(ci, O.blob(c + Vector2(0, 4) * s, 52.0 * s, 18.0 * s, seed % 7, 0.2, 20), rock, 1.3, 1.0, 0.4)
	O.poly(ci, O.blob(c + Vector2(0, 2) * s, 36.0 * s, 11.0 * s, seed % 5, 0.2, 18), nacre["clair"])
	var n := rng.randi_range(4, 7)
	var spikes := []
	for i in n:
		spikes.append([rng.randf_range(-32.0, 32.0), rng.randf_range(30.0, 95.0) * (1.4 if i == 0 else 1.0), rng.randf_range(-0.55, 0.55)])
	spikes.sort_custom(func(x, y): return x[1] < y[1])
	for sp in spikes:
		var b := c + Vector2(float(sp[0]), 0.0) * s
		var h: float = float(sp[1]) * s
		var dir := Vector2.UP.rotated(float(sp[2]) + float(sp[0]) * 0.008)
		var side := dir.orthogonal() * h * 0.16
		var pr := PackedVector2Array([b - side, b - side + dir * h * 0.78, b + dir * h, b + side + dir * h * 0.78, b + side])
		O.part(ci, pr, pal, 1.3, 1.0, 0.9)
		# Facette : la moitié éclairée, une arête claire.
		O.poly(ci, PackedVector2Array([b - side, b - side + dir * h * 0.78, b + dir * h, b + dir * h * 0.1]), Color(pal["reflet"], 0.25))
		ci.draw_line(b + dir * h * 0.05, b + dir * h * 0.92, Color(pal["reflet"], 0.75), 1.3, true)


## Sud-est : des troncs pétrifiés couchés (cernes à la coupe), des souches, des larmes d'ambre.
static func _sector_racine(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	var deg: float = SECTEURS["racine"]
	for i in 8:
		var c := _spread(rng, deg, 26.0, 40.0 + i * 100.0, 160.0 + i * 120.0, rr)
		var k := far_k(_d_of(c, rr))
		var ang := rng.randf_range(-0.7, 0.7) + (PI if i % 2 else 0.0)
		var l := rng.randf_range(160.0, 300.0)
		var w := rng.randf_range(34.0, 52.0)
		var seed := rng.randi()
		_add(Rect2(c - Vector2.ONE * (l * 0.6 + w), Vector2.ONE * (l * 1.2 + w * 2.0)), func(ci): _trunk(ci, c, ang, l, w, k, seed))
	for i in 11:
		var c := _spread(rng, deg, 30.0, 20.0, 1000.0, rr)
		var k := far_k(_d_of(c, rr))
		var s := rng.randf_range(0.8, 1.5)
		var seed := rng.randi()
		_add(Rect2(c - Vector2(60, 70) * s, Vector2(120, 100) * s), func(ci): _stump(ci, c, s, k, seed))


static func _trunk(ci: CanvasItem, c: Vector2, ang: float, l: float, w: float, k: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pal := dpal(fc("racine", "bois"), k)
	var amber: Color = fc("racine", "ambre")
	var dir := Vector2.from_angle(ang)
	var a := c - dir * l * 0.5
	var b := c + dir * l * 0.5
	var pts := PackedVector2Array([a, a.lerp(b, 0.33) + dir.orthogonal() * 6.0, a.lerp(b, 0.66) - dir.orthogonal() * 4.0, b])
	O.brush(ci, Transform2D(0.0, O.SHADOW_DIR * w * 0.6) * pts, w * 1.1, Color(0.02, 0.01, 0.01, 0.4), 0.0, 0.0)
	O.brush(ci, pts, w + 4.0, Ink.encre(), 0.0, 0.0)
	O.brush(ci, pts, w, pal["ombre"], 0.0, 0.0)
	O.brush(ci, Transform2D(0.0, Vector2(-w * 0.14, -w * 0.2)) * pts, w * 0.55, pal["clair"], 0.0, 0.0)
	# Fentes de l'écorce pétrifiée, dans le sens du tronc.
	for i in 6:
		var off := dir.orthogonal() * rng.randf_range(-w * 0.35, w * 0.25)
		var u0 := rng.randf_range(0.05, 0.6)
		ci.draw_line(a.lerp(b, u0) + off, a.lerp(b, u0 + rng.randf_range(0.15, 0.35)) + off, Color(pal["ombre"].darkened(0.4), 0.8), 1.4, true)
	# La coupe : cernes, cassure.
	var cut := b + dir * 2.0
	O.part(ci, O.blob(cut, w * 0.42, w * 0.5, seed % 11, 0.1, 18, ang), {"clair": pal["reflet"].darkened(0.2), "ombre": pal["ombre"], "reflet": pal["reflet"]}, 1.3, 1.0, 0.3)
	for i in 3:
		ci.draw_arc(cut, w * (0.1 + 0.11 * i), 0.0, TAU, 18, Color(pal["ombre"], 0.7), 1.1, true)
	# Larmes d'ambre.
	for i in 3:
		var q := a.lerp(b, rng.randf_range(0.2, 0.8)) + dir.orthogonal() * w * 0.4
		O.poly(ci, O.blob(q, 5.0, 6.0, i, 0.1, 10), dim(amber, k).darkened(0.25))
		ci.draw_circle(q - Vector2(1.5, 2.0), 2.0, Color(dim(amber, k).lightened(0.25), 0.9))


static func _stump(ci: CanvasItem, c: Vector2, s: float, k: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pal := dpal(fc("racine", "bois"), k)
	var w := 34.0 * s
	var h := rng.randf_range(20.0, 44.0) * s
	O.cast_shadow(ci, c, w * 2.0, h, 0.35)
	# Racines du pied.
	for i in 4:
		var a := PI * (0.1 + 0.27 * i)
		var p := PackedVector2Array([c + Vector2(cos(a) * w * 0.7, -2), c + Vector2(cos(a) * w * 1.4, sin(a) * 6.0 + 4.0)])
		O.brush(ci, p, 10.0 * s, Ink.encre(), 0.0, 1.0)
		O.brush(ci, p, 7.0 * s, pal["ombre"], 0.0, 1.0)
	var body := PackedVector2Array([c + Vector2(-w, 0), c + Vector2(-w * 0.85, -h), c + Vector2(w * 0.85, -h), c + Vector2(w, 0)])
	O.part(ci, body, pal, 1.4, 1.0, 0.4)
	var top := O.blob(c + Vector2(0, -h), w * 0.86, w * 0.34, seed % 9, 0.12, 20)
	O.part(ci, top, {"clair": pal["reflet"].darkened(0.25), "ombre": pal["ombre"], "reflet": pal["reflet"]}, 1.3, 1.0, 0.3)
	for i in 3:
		ci.draw_arc(c + Vector2(0, -h), w * (0.18 + 0.2 * i), 0.0, TAU, 20, Color(pal["ombre"], 0.6), 1.0, true)


## Sud : sous le puits de lumière, les éboulis de la chute (blocs de terre et de strates, racines
## arrachées), et le cercle de lumière qui déborde de la lèvre.
static func _sector_puits(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	var strata := [cc("strate_haut"), cc("croute"), cc("strate_bas").lightened(0.1)]
	for i in 9:
		var c := _spread(rng, PUITS, 30.0, 30.0, 520.0, rr)
		if absf(c.x) < 120.0 and _d_of(c, rr) < 140.0:
			c.x += 180.0 * signf(c.x + 0.1)
		var k := far_k(_d_of(c, rr))
		var seed := rng.randi()
		var s := rng.randf_range(0.8, 1.4)
		var col: Color = strata[i % 3]
		_add(Rect2(c - Vector2(90, 70) * s, Vector2(180, 110) * s), func(ci): _rubble(ci, c, s, col, k, seed))
	var bark: Dictionary = Art.mc("commun", "", "ecorce")
	for i in 4:
		var c := _spread(rng, PUITS, 36.0, 120.0, 600.0, rr)
		var a := rng.randf() * TAU
		var to := c + Vector2.from_angle(a) * rng.randf_range(90.0, 160.0)
		var pts := O.curve(c, c.lerp(to, 0.5) + Vector2(0, -20), to, 6)
		var pal := dpal(bark, far_k(_d_of(c, rr)))
		_add(_box(pts, 30.0), func(ci):
			_big_root(ci, pts, 18.0, pal, -1)
			# Le bout arraché : des fibres.
			for j in 5:
				var q := pts[0]
				var d := (pts[0] - pts[1]).normalized().rotated((j - 2) * 0.25)
				ci.draw_line(q, q + d * (10.0 + 4.0 * (j % 3)), pal["ombre"], 1.6, true))


static func _rubble(ci: CanvasItem, c: Vector2, s: float, col: Color, k: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	O.cast_shadow(ci, c + Vector2(0, 10) * s, 150.0 * s, 30.0 * s, 0.35)
	O.poly(ci, O.blob(c + Vector2(0, 6) * s, 86.0 * s, 30.0 * s, seed % 13, 0.25, 22), Color(dim(cc("croute"), k), 0.85))
	var n := rng.randi_range(6, 11)
	var blocks := []
	for i in n:
		blocks.append(c + Vector2(rng.randf_range(-62, 62), rng.randf_range(-26, 12)) * s)
	blocks.sort_custom(func(x, y): return x.y < y.y)
	for i in n:
		var q: Vector2 = blocks[i]
		var w := rng.randf_range(10.0, 28.0) * s
		var h := rng.randf_range(7.0, 16.0) * s
		var base := dim(col.lerp(cc("croute"), rng.randf_range(0.0, 0.5)), k)
		var pal := {"clair": base.lightened(0.14), "ombre": base.darkened(0.4), "reflet": base.lightened(0.3)}
		# Un bloc de terre : dessus irrégulier, et sa face tournée vers nous.
		var top := O.blob(q - Vector2(0, h), w, w * 0.45, seed + i, 0.3, 7, rng.randf_range(-0.5, 0.5))
		var face := PackedVector2Array()
		for p in top:
			face.append(p + Vector2(0, h))
		O.poly(ci, face, pal["ombre"])
		for j in top.size():
			var p0 := top[j]
			var p1 := top[(j + 1) % top.size()]
			if p0.x > p1.x:
				O.poly(ci, PackedVector2Array([p0, p1, p1 + Vector2(0, h), p0 + Vector2(0, h)]), pal["ombre"].lightened(0.06 * (j % 3)))
		O.part(ci, top, pal, 1.2, 1.0, 0.3)
		ci.draw_line(q + Vector2(-w * 0.7, -h * 0.45), q + Vector2(w * 0.6, -h * 0.5), Color(pal["ombre"].darkened(0.3), 0.7), 1.1, true)


## Sud-ouest : le squelette d'un ancien colosse, à moitié enterré : échine, côtes en arceaux, crâne à
## ramure. La Flétrissure l'a bu jusqu'à l'os.
static func _ossuary(rr: float) -> void:
	var c := atd(rr, OSSUAIRE, 300.0)
	var k := far_k(_d_of(c, rr))
	_add(Rect2(c - Vector2(420, 330), Vector2(840, 620)), func(ci): _skeleton(ci, c, k))
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var bone := Art.bc("os")
	for i in 16:
		var q := _spread(rng, OSSUAIRE, 30.0, 40.0, 900.0, rr)
		var kk := far_k(_d_of(q, rr))
		var a := rng.randf() * TAU
		var l := rng.randf_range(16.0, 34.0)
		var col := dim(bone, kk + 0.35)
		_add(Rect2(q - Vector2.ONE * (l + 6), Vector2.ONE * (l * 2 + 12)), func(ci): _bone(ci, q, a, l, col))


static func _bone(ci: CanvasItem, q: Vector2, a: float, l: float, col: Color) -> void:
	var d := Vector2.from_angle(a) * l * 0.5
	ci.draw_line(q - d, q + d, Ink.encre(), 6.0, true)
	ci.draw_line(q - d, q + d, col, 4.0, true)
	for e in [q - d, q + d]:
		ci.draw_circle(e + d.orthogonal().normalized() * 2.0, 3.6, Ink.encre())
		ci.draw_circle(e - d.orthogonal().normalized() * 2.0, 3.6, Ink.encre())
		ci.draw_circle(e + d.orthogonal().normalized() * 2.0, 2.6, col)
		ci.draw_circle(e - d.orthogonal().normalized() * 2.0, 2.6, col)


static func _skeleton(ci: CanvasItem, c: Vector2, k: float) -> void:
	var bone := Art.bc("os")
	var pal := {"clair": dim(bone, k + 0.3), "ombre": dim(bone.darkened(0.45), k + 0.3), "reflet": dim(bone.lightened(0.2), k + 0.3)}
	var far := {"clair": pal["clair"].darkened(0.35), "ombre": pal["ombre"].darkened(0.35), "reflet": pal["reflet"].darkened(0.35)}
	var hole := Color(0.03, 0.02, 0.02, 0.85)
	var shade := Color(0.02, 0.01, 0.01, 0.4)
	# La terre retournée autour, plus sombre.
	O.poly(ci, O.blob(c + Vector2(0, 60), 400.0, 150.0, 7.0, 0.2, 40, -0.2), Color(0.02, 0.015, 0.012, 0.35))
	# L'échine, couchée de biais (tête à l'ouest) : elle tient en l'air sur les côtes, son ombre au sol.
	var n := 24
	var spine := PackedVector2Array()
	var lift := PackedFloat32Array()
	for i in n:
		var u := float(i) / (n - 1)
		spine.append(c + Vector2(lerpf(-260.0, 330.0, u), lerpf(-10.0, -70.0, u) - 50.0 * sin(PI * u)))
		lift.append(lerpf(12.0, 90.0, sin(PI * minf(1.0, u * 1.25))) * (1.0 - 0.75 * u * u))
	var ground := PackedVector2Array()
	for i in n:
		ground.append(spine[i] + Vector2(0, lift[i]))
	O.brush(ci, Transform2D(0.0, O.SHADOW_DIR * 20.0) * ground, 34.0, shade, 0.3, 1.0)
	# Côtes : de l'échine au sol, de part et d'autre (les lointaines derrière, plus sombres).
	for side in 2:
		for i in range(3, 17):
			var q := spine[i]
			var h := lift[i]
			var wv := 80.0 * sin(PI * clampf((i - 2.0) / 15.0, 0.0, 1.0)) + 20.0
			if (i * 7 + side * 3) % 11 == 0:
				continue  # une côte manque (cassée, enterrée)
			var foot: Vector2
			var ctrl: Vector2
			if side == 0:
				foot = q + Vector2(-18.0, h - wv * 0.45)
				ctrl = q + Vector2(26.0, -wv * 0.35)
			else:
				foot = q + Vector2(-26.0, h + wv * 0.55)
				ctrl = q + Vector2(46.0, h * 0.2 + wv * 0.25)
			var rib := O.curve(q, ctrl, foot, 12)
			var pp: Dictionary = far if side == 0 else pal
			var w := 9.0 if side == 1 else 7.0
			if side == 1:
				O.brush(ci, Transform2D(0.0, O.SHADOW_DIR * 18.0 + Vector2(0, 10)) * rib, w, shade, 0.2, 0.9)
			O.brush(ci, rib, w + 3.0, Ink.encre(), 0.2, 0.9)
			O.brush(ci, rib, w, pp["ombre"], 0.2, 0.9)
			O.brush(ci, Transform2D(0.0, Vector2(-1.5, -1.5)) * rib, w * 0.4, pp["clair"], 0.2, 0.9)
			if side == 1:
				O.poly(ci, O.blob(foot + Vector2(0, 3), 9.0, 4.0, i, 0.2, 10), Color(cc("croute"), 0.9))
		if side == 0:
			# Les vertèbres, par-dessus les côtes lointaines.
			for i in n:
				var q := spine[i]
				var rx := 15.0 * (1.0 - absf(i - 8.0) / 26.0) + 4.0
				O.part(ci, O.blob(q, rx, rx * 0.62, i, 0.1, 14), pal, 1.3, 1.0, 0.5)
				ci.draw_line(q + Vector2(0, -rx * 0.5), q + Vector2(3, -rx * 1.5), pal["ombre"], 3.5, true)
	# Le crâne, tête basse au bout de l'échine, et sa ramure (comme des bois de cerf, en branches mortes).
	var head := spine[0] + Vector2(-70, 40)
	O.cast_shadow(ci, head + Vector2(0, 34), 190.0, 50.0, 0.4)
	var skull := PackedVector2Array()
	for j in 28:
		var a := TAU * j / 28.0
		var rx := 62.0 if cos(a) > 0.0 else 96.0
		var ry := 44.0 - 18.0 * maxf(0.0, -cos(a)) * (1.0 if sin(a) < 0.0 else 0.6)
		skull.append(head + Vector2(cos(a) * rx, sin(a) * ry))
	O.part(ci, skull, pal, 1.8, 1.0, 0.6)
	O.poly(ci, O.blob(head + Vector2(-18, -10), 17.0, 12.0, 1.0, 0.15, 14), hole)
	O.poly(ci, O.blob(head + Vector2(-82, 4), 8.0, 5.0, 3.0, 0.15, 10), hole)
	ci.draw_polyline(PackedVector2Array([head + Vector2(-90, 22), head + Vector2(-40, 30), head + Vector2(10, 26)]), Color(pal["ombre"], 0.9), 2.0, true)
	for j in 8:
		var q := head + Vector2(-86 + j * 11, 30 - absf(j - 3.5) * 1.5)
		O.poly(ci, PackedVector2Array([q + Vector2(-3.5, 0), q + Vector2(3.5, 0), q + Vector2(0, 11)]), pal["clair"])
	for side: float in [-1.0, 1.0]:
		var root := head + Vector2(26, -30 - 8 * side)
		var pts := PackedVector2Array([root, root + Vector2(46, -54 + 20 * side), root + Vector2(110, -90 + 30 * side), root + Vector2(190, -86 + 36 * side)])
		var pp: Dictionary = pal if side > 0 else far
		_antler(ci, pts, 13.0, pp)
		for b in 3:
			var from := pts[b + 1]
			var to := from + Vector2(16 + 12 * b, -50 - 14 * b)
			_antler(ci, PackedVector2Array([from, from.lerp(to, 0.5) + Vector2(-8, 0), to]), 6.5, pp)
	# Des veines de la Flétrissure dans l'os.
	var vein := Color(Art.bc("ronge").darkened(0.3), 0.85)
	ci.draw_polyline(PackedVector2Array([head + Vector2(40, -24), head + Vector2(16, 0), head + Vector2(34, 20), head + Vector2(12, 36)]), vein, 2.4, true)
	ci.draw_polyline(PackedVector2Array([spine[6], spine[6] + Vector2(10, 30), spine[6] + Vector2(-4, 60)]), vein, 2.0, true)


static func _antler(ci: CanvasItem, pts: PackedVector2Array, w: float, pal: Dictionary) -> void:
	O.brush(ci, Transform2D(0.0, O.SHADOW_DIR * 22.0 + Vector2(0, 12)) * pts, w, Color(0.02, 0.01, 0.01, 0.3), 0.0, 1.0)
	O.brush(ci, pts, w + 3.0, Ink.encre(), 0.0, 1.0)
	O.brush(ci, pts, w, pal["ombre"], 0.0, 1.0)
	O.brush(ci, Transform2D(0.0, Vector2(-1, -1.5)) * pts, w * 0.45, pal["clair"], 0.0, 1.0)


# --- Couche 4 : le sceau ---

## Le cercle de menhirs gravés qui tenait la Flétrissure : onze pierres autour de la lèvre, certaines
## renversées ou brisées, prises dans les racines ; leurs gravures sont éteintes.
static func _seal(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1111
	for i in 12:
		var deg := -90.0 + 360.0 * i / 12.0 + rng.randf_range(-6.0, 6.0)
		if absf(wrapf(deg - PUITS, -180.0, 180.0)) < 14.0:
			deg += 18.0
		var d := rng.randf_range(110.0, 170.0) + (40.0 if absf(wrapf(deg + 90.0, -180.0, 180.0)) < 40.0 else 0.0)
		var state: String = ["debout", "debout", "penche", "renverse", "brise"][rng.randi() % 5] if i % 3 else "debout"
		var h := rng.randf_range(150.0, 230.0)
		var w := rng.randf_range(48.0, 70.0)
		# Au sud, une pierre debout monterait sur la lèvre (le creux la cacherait) : plus loin.
		d += maxf(0.0, sin(deg_to_rad(deg))) * h * 0.9
		var c := atd(rr, deg, d)
		var seed := rng.randi()
		var k := far_k(d) * 0.4
		_add(Rect2(c - Vector2(h + w, h + 30), Vector2((h + w) * 2.0, h * 1.6 + 60)), func(ci): _menhir(ci, c, w, h, state, k, seed))


static func _menhir(ci: CanvasItem, c: Vector2, w: float, h: float, state: String, k: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pal := dpal(Art.mc("commun", "", "pierre"), k + 0.35)
	var glyph := Color(Art.bc("braise").darkened(0.55), 0.7)
	var bark := dpal(Art.mc("commun", "", "ecorce"), k + 0.1)
	if state == "renverse":
		# Couché : on voit sa face gravée vers le haut et sa base arrachée.
		var dir := Vector2.from_angle(rng.randf_range(-0.6, 0.6) + (PI if rng.randf() < 0.5 else 0.0))
		var nrm := dir.orthogonal()
		var a := c - dir * h * 0.5
		var b := c + dir * h * 0.5
		var body := PackedVector2Array([a - nrm * w * 0.5, b - nrm * w * 0.4, b + dir * 10.0, b + nrm * w * 0.4, a + nrm * w * 0.5])
		O.cast_shadow(ci, c + Vector2(0, 8), h, 20.0, 0.4)
		O.poly(ci, Transform2D(0.0, Vector2(0, 12)) * body, pal["ombre"].darkened(0.45))
		O.part(ci, body, pal, 1.6, 1.0, 0.5)
		_glyphs(ci, c, dir, nrm, h * 0.35, w * 0.25, glyph)
		O.poly(ci, O.blob(a, 18.0, 10.0, seed % 7, 0.3, 12), Color(cc("croute"), 0.9))
		return
	var tilt := 0.0
	if state == "penche":
		tilt = rng.randf_range(0.22, 0.4) * (1.0 if rng.randf() < 0.5 else -1.0)
	var hh := h * (0.55 if state == "brise" else 1.0)
	O.cast_shadow(ci, c, w * 2.0, hh, 0.42)
	var up := Vector2.UP.rotated(tilt)
	var side := up.orthogonal()
	var pts := PackedVector2Array([c - side * w * 0.5, c - side * w * 0.42 + up * hh * 0.75, c - side * w * 0.2 + up * hh, c + side * w * 0.25 + up * hh * 0.97, c + side * w * 0.45 + up * hh * 0.7, c + side * w * 0.5])
	if state == "brise":
		pts[2] = c - side * w * 0.3 + up * hh * 1.05
		pts[3] = c + side * w * 0.1 + up * hh * 0.85
	# Le flanc droit (dans l'ombre), puis la face.
	O.poly(ci, PackedVector2Array([c + side * w * 0.5, c + side * w * 0.45 + up * hh * 0.7, c + side * w * 0.62 + up * hh * 0.66 + Vector2(0, 6), c + side * w * 0.66 + Vector2(0, 6)]), pal["ombre"].darkened(0.4))
	O.part(ci, pts, pal, 1.8, 1.0, 0.55)
	_glyphs(ci, c + up * hh * 0.5, up, side, hh * 0.3, w * 0.22, glyph)
	# Lichen et racines qui l'enserrent.
	O.poly(ci, O.blob(c + up * hh * 0.18 - side * w * 0.2, w * 0.2, w * 0.1, seed % 5, 0.3, 10), Color(dim(fc("vent", "lichen"), k + 0.2), 0.8))
	var r0 := c - side * w * 0.9 + Vector2(0, 4)
	var r1 := c + up * hh * 0.38 - side * w * 0.1
	var r2 := c + side * w * 0.8 + up * hh * 0.2
	_big_root(ci, PackedVector2Array([r0, r1, r2, c + side * w * 1.1 + Vector2(0, 8)]), 8.0, bark, -1)
	if state == "brise":
		var frag := c + side * w * 1.4 + Vector2(10, 10)
		O.part(ci, O.blob(frag, w * 0.45, w * 0.25, seed % 3, 0.25, 9, 0.4), pal, 1.4, 1.0, 0.5)


## Gravures d'un menhir : une spirale de graine et des traits, éteints (braise morte).
static func _glyphs(ci: CanvasItem, c: Vector2, up: Vector2, side: Vector2, h: float, w: float, col: Color) -> void:
	var sp := PackedVector2Array()
	for i in 18:
		var a := i * 0.62
		sp.append(c + (side * cos(a) + up * sin(a)) * (2.0 + i * 0.6) * (w / 10.0))
	ci.draw_polyline(sp, col, 1.6, true)
	for i in 3:
		var q := c - up * h * (0.55 + 0.25 * i)
		ci.draw_line(q - side * w, q + side * w, col, 1.4, true)
	ci.draw_line(c + up * h * 0.7 - side * w * 0.6, c + up * h * 1.0, col, 1.4, true)
	ci.draw_line(c + up * h * 0.7 + side * w * 0.6, c + up * h * 1.0, col, 1.4, true)


# --- Couche 5 : le menu ---

## Cendre, galets, feuilles mortes (de la région la plus proche), herbe sèche, petits os.
static func _scatter(rr: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var peb: Dictionary = Art.mc("commun", "", "pierre")
	var ash: Color = cc("cendre")
	for i in 70:
		var a := rng.randf() * TAU
		var d := rng.randf_range(10.0, PORTEE)
		var c := at(rr, a, d)
		var pts := O.blob(c, rng.randf_range(20.0, 60.0), rng.randf_range(8.0, 20.0), i, 0.3, 16, rng.randf_range(-0.3, 0.3))
		var col := Color(ash, 0.09 * (1.0 - 0.5 * far_k(d)))
		_add(_box(pts, 2.0), func(ci): O.poly(ci, pts, col))
	for g in 60:
		var a := rng.randf() * TAU
		var d := rng.randf_range(10.0, PORTEE)
		var gc := at(rr, a, d)
		var pal := dpal(peb, far_k(d) + 0.3)
		var stones := []
		for j in rng.randi_range(2, 5):
			stones.append([gc + Vector2(rng.randf_range(-24, 24), rng.randf_range(-12, 12)), rng.randf_range(3.0, 8.0), g * 10.0 + j])
		_add(Rect2(gc - Vector2(40, 30), Vector2(80, 60)), func(ci):
			for st in stones:
				O.pebble(ci, st[0], st[1], pal, st[2]))
	var regs := SECTEURS.keys()
	for i in 520:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, PORTEE)
		var c := at(rr, a, d)
		var deg := rad_to_deg(a)
		var reg := str(regs[0])
		var bd := 999.0
		for rg in regs:
			var dd := absf(wrapf(deg - float(SECTEURS[rg]), -180.0, 180.0))
			if dd < bd:
				bd = dd
				reg = str(rg)
		var k := far_k(d)
		if i % 4 == 0:
			var t1: Color = dim(fc(reg, "touffe"), k + 0.1)
			var t2: Color = dim(fc(reg, "touffe_2"), k + 0.1)
			var hh := rng.randf_range(8.0, 15.0)
			var seed := i
			_add(Rect2(c - Vector2(16, 20), Vector2(32, 24)), func(ci): O.tuft(ci, c, hh, t1, t2, seed, true))
		else:
			var col: Color = dim(fc(reg, "feuille" if i % 2 else "feuille_2"), k + 0.15)
			var rot := rng.randf() * TAU
			var pts := O.blob(c, rng.randf_range(3.5, 7.0), rng.randf_range(1.8, 3.2), i, 0.3, 9, rot)
			_add(_box(pts, 2.0), func(ci): O.poly(ci, pts, col))
