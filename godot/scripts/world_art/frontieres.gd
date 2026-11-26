## Frontières entre régions dans le monde (refonte du monde, vague 3 B). À ne pas confondre avec
## data/borders/ (frontières de l'ARBRE de compétences, jalon 9 A).
##
## Géométrie commune au sol (shaders/ground.gdshader), aux calques du sol (world_bake/ground_layers.gd),
## au décor (world_bake/decor_compose.gd) et au bord du monde (world_edge_painter.gd) :
##   - chaque frontière est une demi-droite partant de la graine (bord de deux secteurs voisins) ;
##     s = distance perpendiculaire signée à cette demi-droite (px du monde, comme
##     Regions.inside_distance : positive dans la région) ;
##   - la bande fait HALF px de part et d'autre (≈ 440 px) ;
##   - dans la bande, les deux sols ne se fondent pas : ils s'entremêlent en langues et en îlots. Chaque
##     point appartient à une seule région, choisie par v = s ± bruit (bruit nul hors de la bande, plus
##     fort au milieu) ; la part de la région voisine passe de 0 à 1 en traversant la bande ;
##   - weight() donne le même passage en fondu doux (sans îlots), pour qui n'a pas besoin des îlots.
## Le cercle intérieur (oasis de la graine) garde son passage, plus étroit (HALF_INNER).
## Le shader du sol refait exactement le même calcul (ground.gdshader › region_v).
extends RefCounted

const Regions = preload("res://scripts/regions.gd")

## Demi-largeur de la bande de frontière (px du monde), de part et d'autre de la demi-droite.
const HALF := 220.0
## Demi-largeur du passage entre l'oasis et une région.
const HALF_INNER := 120.0
## Amplitude du bruit des îlots (en fractions de la demi-largeur, au milieu de la bande).
const AMP := 1.25
## Bruit des îlots : canal R de la texture de bruit du sol (ground.gd › noise_texture), lu à une autre
## échelle et décalé (îlots d'environ 150 px, indépendants des plaques du lavis).
const NOISE_SCALE := 1.7
const NOISE_OFFSET := Vector2(0.37, 0.61)
const NOISE_PERIOD := 3000.0

static var _noise: Image
static var _nres := 0
## Normales des bords de chaque région (Regions.edge_normals), gardées tant que les régions ne changent pas.
static var _normals := {}
static var _ids: Array = []


## Régions et normales de leurs bords (en cache : appelé des milliers de fois à la composition).
static func _regions() -> Array:
	var ids := Regions.ids()
	if ids != _ids:
		_ids = ids.duplicate()
		_normals = {}
		for id in _ids:
			_normals[id] = Regions.edge_normals(id)
	return _ids


## Bruit des îlots en un point (0 à 1), même lecture bilinéaire que le shader.
static func noise(p: Vector2) -> float:
	if _noise == null:
		var G = load("res://scripts/ground.gd")
		_noise = G.noise_texture().get_image()
		if _noise.is_compressed():
			_noise.decompress()
		_nres = _noise.get_width()
	var uv := p * NOISE_SCALE / NOISE_PERIOD + NOISE_OFFSET
	var x := uv.x * _nres - 0.5
	var y := uv.y * _nres - 0.5
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	var a := _noise.get_pixel(posmod(x0, _nres), posmod(y0, _nres)).r
	var b := _noise.get_pixel(posmod(x0 + 1, _nres), posmod(y0, _nres)).r
	var c := _noise.get_pixel(posmod(x0, _nres), posmod(y0 + 1, _nres)).r
	var d := _noise.get_pixel(posmod(x0 + 1, _nres), posmod(y0 + 1, _nres)).r
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Décalage des îlots pour une distance s au bord (nul hors de la bande).
static func shift(s: float, half: float, n: float) -> float:
	var t := clampf(s / half, -1.0, 1.0)
	return (n - 0.5) * 2.0 * AMP * half * (1.0 - t * t)


## Appartenance (px du monde, positive dedans) d'un point à une région, avec les îlots de la bande.
## Deux régions voisines ont des valeurs opposées sur leur bord commun : chaque point est à une seule.
static func inside(p: Vector2, id: String, n := -1.0) -> float:
	if n < 0.0:
		n = noise(p)
	_regions()
	var nn: Array = _normals[id] if _normals.has(id) else Regions.edge_normals(id)
	var s1 := p.dot(nn[0])
	var s2 := p.dot(nn[1])
	var s3 := p.length() - Regions.INNER
	return minf(minf(s1 + shift(s1, HALF, n), s2 - shift(s2, HALF, n)), s3 + shift(s3, HALF_INNER, n))


## Région d'un point avec les îlots de la bande ("" : oasis et hors du monde).
static func region_at(p: Vector2) -> String:
	if absf(p.x) > Regions.WORLD_HALF or absf(p.y) > Regions.WORLD_HALF:
		return ""
	var n := noise(p)
	for id in _regions():
		if inside(p, id, n) > 0.0:
			return id
	return ""


## Frontière la plus proche d'un point : {a: région où il est (sans îlots), b: région voisine de
## l'autre côté (ou "" : oasis), s: distance à la frontière (positive dans a), w: part de b en fondu
## doux (0 → 1, 0,5 sur la demi-droite)}. Vide hors des régions.
static func mix(p: Vector2) -> Dictionary:
	if p.length() <= Regions.INNER or absf(p.x) > Regions.WORLD_HALF or absf(p.y) > Regions.WORLD_HALF:
		return {}
	# Région du secteur (sur la demi-droite même, celle dont on est le moins loin).
	var a := ""
	var best := -INF
	for id in _regions():
		var d := Regions.inside_distance(p, id)
		if d > best:
			best = d
			a = id
	if a == "":
		return {}
	var nn: Array = _normals[a]
	var s1 := p.dot(nn[0])
	var s2 := p.dot(nn[1])
	var s3 := p.length() - Regions.INNER
	var s := minf(minf(s1, s2), s3)
	var b := ""
	var half := HALF
	if s == s3:
		half = HALF_INNER
	else:
		b = neighbour(a, s == s1)
	return {"a": a, "b": b, "s": s, "w": weight_s(s, half)}


## Part de la région voisine en fondu doux, pour une distance s au bord.
static func weight_s(s: float, half := HALF) -> float:
	return 1.0 - smoothstep(-half, half, s)


## Région voisine de « id » de l'autre côté de son premier bord (first) ou du second.
static func neighbour(id: String, first: bool) -> String:
	var a := Regions.angle_of(id) + (-1.0 if first else 1.0) * Regions.half_width() * 2.0
	var q := Vector2.from_angle(a) * (Regions.INNER + 400.0)
	return Regions.region_at(q)


## Les frontières : [a, b, angle de la demi-droite] pour chaque paire de régions voisines.
static func pairs() -> Array:
	var out := []
	for id in Regions.ids():
		var b := neighbour(id, false)
		if b != "" and b != id:
			out.append([id, b, Regions.angle_of(id) + Regions.half_width()])
	return out


# --- Éléments de passage (un par paire de régions, data/world_borders.json) ---
# Dessin seul, sans collision : posés par world_bake/decor_compose.gd (frontier_passages) dans les zones
# déjà libres de la bande, cuits avec le reste du décor (classe decor_compose.Passage). Chacun mêle les
# matières des deux régions, chacune dans sa palette (Art.MONDE), flétries ou ravivées ensemble.

const Decor = preload("res://scripts/world_art/decor.gd")
const O = preload("res://scripts/world_art/outils.gd")
const DATA := "res://data/world_borders.json"

## Hauteur de référence d'un élément de passage (px du monde, size = 1) : ≈ 2 fois le héros.
const PASSAGE_H := 110.0

static var _data := {}


## Contenu de data/world_borders.json ({pairs: {"a-b": {passage, spots, size}}}).
static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA, FileAccess.READ)
		if f != null:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				_data = j
	return _data


## Fiche de la paire (dans un sens ou dans l'autre), vide si elle n'a pas d'élément.
static func pair_def(a: String, b: String) -> Dictionary:
	var p: Dictionary = data().get("pairs", {})
	return p.get(a + "-" + b, p.get(b + "-" + a, {}))


## Palette d'une région dans un état, avec les mêmes replis que world_art/decor.gd.
static func _P(reg: String, etat: String) -> Callable:
	return func(key: String) -> Dictionary:
		if Art.MONDE.get(reg, {}).get(etat, {}).has(key):
			return Art.mc(reg, etat, key)
		if Art.MONDE["commun"].has(key):
			return Art.mc("commun", "", key)
		return Art.mc("ronce", etat, key)


## Dessine l'élément « kind » (pied en at, taille size, germe seed) dans l'état etat (fletri/ravive).
static func draw_passage(ci: CanvasItem, kind: String, at: Vector2, size: float, seed: int, etat: String, flip := false) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var h := PASSAGE_H * size
	var fl := -1.0 if flip else 1.0
	O.cast_shadow(ci, at, h * 1.1, h * 0.6, 0.3 if etat == "ravive" else 0.36)
	match kind:
		"ronces_chapeaux":
			_ronces_chapeaux(ci, at, h, fl, r, etat)
		"saule_chapeaux":
			_saule_chapeaux(ci, at, h, fl, r, etat)
		"saule_plumes":
			_saule_plumes(ci, at, h, fl, r, etat)
		"cairn_cristal":
			_cairn_cristal(ci, at, h, fl, r, etat)
		"souche_cristal":
			_souche_cristal(ci, at, h, fl, r, etat)
		"arceau_ronce":
			_arceau_ronce(ci, at, h, fl, r, etat)


## Roncier × Marais : un roncier envahi de champignons ; les chapeaux percent la haie, les tiges les
## reprennent par-dessus.
static func _ronces_chapeaux(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, etat: String) -> void:
	var Pr := _P("ronce", etat)
	var Ps := _P("spore", etat)
	var hh := h * 0.72
	Decor._champignon(ci, at + Vector2(h * 0.42 * fl, -h * 0.12), h * 0.95, fl, r, Ps, etat, 0.0, false)
	Decor._haie(ci, at, hh, fl, r, Pr, etat, "ronce", 0.0)
	Decor._champignon(ci, at + Vector2(-h * 0.5 * fl, 4.0), h * 0.55, -fl, r, Ps, etat, 0.0, false)
	Decor._champignon(ci, at + Vector2(-h * 0.1 * fl, 6.0), h * 0.38, fl, r, Ps, etat, 0.0, false)
	Decor._canes(ci, at + Vector2(0, 2), hh * 0.9, hh * 1.6, r, Pr.call("ronce"), 3)


## Saule de la Vallée (tronc trapu, rideau de branches qui retombe), penché de lean.
static func _saule(ci: CanvasItem, at: Vector2, h: float, lean: float, r: RandomNumberGenerator, P: Callable, etat: String) -> Vector2:
	var bois: Dictionary = P.call("bois")
	var saule: Dictionary = P.call("saule")
	var top := at + Vector2(lean * h * 0.45, -h * 0.62)
	var w := h * 0.11
	var trunk := PackedVector2Array([at + Vector2(-w * 1.9, 0), at + Vector2(-w * 0.9, -h * 0.15), top + Vector2(-w * 0.8, 0),
		top + Vector2(-w * 0.2, -h * 0.06), top + Vector2(w * 0.9, 0), at + Vector2(w, -h * 0.18), at + Vector2(w * 2.0, 0)])
	O.part(ci, trunk, bois, 1.5, 1.0, 0.4)
	# Couronne : masses en dôme, puis le rideau de branches qui pend (penché comme le tronc).
	var crown := top + Vector2(lean * h * 0.08, -h * 0.12)
	for i in 4:
		var c := crown + Vector2((i - 1.5) * h * 0.16, -h * 0.05 * (1.0 - absf(i - 1.5) * 0.5))
		O.part(ci, O.Ink.lumpy(c, h * 0.17, h * 0.12, 18, 0.15, 7.0, c.x), saule, 1.2, 1.0, 0.4)
	var dead := etat != "ravive"
	for i in 13:
		var u := (i / 12.0) * 2.0 - 1.0
		var a := crown + Vector2(u * h * 0.34, -h * 0.02 + absf(u) * h * 0.08)
		var len := h * r.randf_range(0.38, 0.6) * (0.6 if dead else 1.0)
		var b := a + Vector2(lean * len * 0.45 + u * h * 0.05, len)
		O.brush(ci, O.curve(a, a + Vector2(u * h * 0.08, len * 0.3), b, 6), 1.8, saule["ombre"] if i % 2 else saule["clair"], 0.3, 1.0)
	return crown


## Marais × Vallée : un saule couché au bord d'une mare, des chapeaux du Marais sur ses racines.
static func _saule_chapeaux(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, etat: String) -> void:
	var Pv := _P("seve", etat)
	var Ps := _P("spore", etat)
	var eau: Color = Art.mc("seve", etat, "eau")
	O.poly(ci, O.blob(at + Vector2(h * 0.25 * fl, 6.0), h * 0.6, h * 0.14, at.x, 0.12, 30), eau)
	O.poly(ci, O.blob(at + Vector2(h * 0.15 * fl, 4.0), h * 0.32, h * 0.04, at.y, 0.2, 20), Color(Art.mc("seve", etat, "eau_reflet"), 0.5))
	_saule(ci, at + Vector2(-h * 0.15 * fl, 0), h * 1.05, 0.25 * fl, r, Pv, etat)
	for i in 3:
		var p := at + Vector2((-h * 0.42 + i * h * 0.17) * fl, 2.0 + (i % 2) * 4.0)
		Decor._champignon(ci, p, h * (0.36 - i * 0.06), fl, r, Ps, etat, 0.0, false)


## Vallée × Plateaux : un saule couché par le vent des plateaux, des plumes prises dans son rideau,
## l'herbe haute des plateaux à son pied.
static func _saule_plumes(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, etat: String) -> void:
	var Pv := _P("seve", etat)
	var herbe: Dictionary = _P("vent", etat).call("herbe")
	var crown := _saule(ci, at, h * 1.1, 0.75 * fl, r, Pv, etat)
	var plume: Color = Art.mc("vent", etat, "plume")
	var pombre: Color = Art.mc("vent", etat, "plume_ombre")
	for i in 5:
		var p := crown + Vector2(r.randf_range(-0.3, 0.45) * h * fl, r.randf_range(0.05, 0.4) * h)
		var a := r.randf_range(0.2, 1.2) * fl + (0.0 if fl > 0.0 else PI)
		O.poly(ci, O.Ink.leaf(p, a, h * 0.13, h * 0.045, 0.1), pombre)
		O.poly(ci, O.Ink.leaf(p + Vector2(-0.6, -0.6), a, h * 0.12, h * 0.03, 0.1), plume)
	for i in 3:
		O.tuft(ci, at + Vector2((-0.45 + i * 0.4) * h * fl, 3.0 + i), h * 0.3, herbe["clair"], herbe["ombre"], r.randi(), etat != "ravive")


## Éclat de cristal (prisme) de l'Aube : base b, hauteur l, penché de a (radians depuis la verticale).
static func _cristal(ci: CanvasItem, b: Vector2, l: float, a: float, verre: Dictionary, glow: bool) -> void:
	var w := l * 0.2
	var pts := PackedVector2Array([Vector2(-w, 0), Vector2(-w * 0.85, -l * 0.72), Vector2(0, -l), Vector2(w * 0.85, -l * 0.72), Vector2(w, 0)])
	for i in pts.size():
		pts[i] = b + pts[i].rotated(a)
	if glow:
		ci.draw_circle(b + Vector2(0, -l * 0.6).rotated(a), l * 0.5, Color(verre["reflet"], 0.08))
	O.part(ci, pts, verre, 1.1, 1.0, 0.9)
	# Facette d'ombre à droite, arête claire au milieu.
	O.poly(ci, PackedVector2Array([pts[2], pts[3], pts[4], b + Vector2(w * 0.1, 0).rotated(a)]), Color(verre["ombre"], 0.45))
	ci.draw_line(b + Vector2(w * 0.1, 0).rotated(a), pts[2], Color(verre["reflet"], 0.7), 1.0, true)


## Plateaux × Falaises : un cairn de pierres des plateaux où pousse le cristal de l'Aube.
static func _cairn_cristal(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, etat: String) -> void:
	var st: Dictionary = _P("vent", etat).call("pierre")
	var verre: Dictionary = _P("aube", etat).call("verre")
	var glow := etat == "ravive"
	_cristal(ci, at + Vector2(h * 0.3 * fl, -2.0), h * 0.55, 0.35 * fl, verre, glow)
	var y := 0.0
	var sw := h * 0.36
	for i in 5:
		var c := at + Vector2(r.randf_range(-0.06, 0.06) * h, -y - sw * 0.28)
		O.part(ci, O.Ink.lumpy(c, sw * 0.55, sw * 0.3, 16, 0.12, 4.0, c.x), st, 1.3, 1.0, 0.4)
		y += sw * 0.48
		sw *= 0.8
	_cristal(ci, at + Vector2(-h * 0.22 * fl, 0.0), h * 0.38, -0.45 * fl, verre, glow)
	_cristal(ci, at + Vector2(h * 0.05 * fl, -y + 4.0), h * 0.3, 0.1 * fl, verre, glow)
	_cristal(ci, at + Vector2(-h * 0.08 * fl, -h * 0.25), h * 0.2, -0.9 * fl, verre, glow)
	var lichen: Color = Art.mc("vent", etat, "lichen")
	O.poly(ci, O.blob(at + Vector2(-h * 0.05, -h * 0.18), h * 0.08, h * 0.03, at.x, 0.3, 12), Color(lichen, 0.8))


## Falaises × Forêt : une souche pétrifiée dont le cœur fendu éclate en cristal.
static func _souche_cristal(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, etat: String) -> void:
	var st: Dictionary = _P("racine", etat).call("pierre")
	var verre: Dictionary = _P("aube", etat).call("verre")
	var w := h * 0.34
	var top := -h * 0.55
	# Racines pétrifiées qui s'étalent.
	for s in [-1.0, 1.0]:
		var a := at + Vector2(s * w * 0.6, -h * 0.08)
		O.part(ci, PackedVector2Array([a + Vector2(0, -h * 0.1), a + Vector2(s * w * 0.9, h * 0.02), a + Vector2(s * w * 1.05, h * 0.06), a + Vector2(0, h * 0.06)]), st, 1.1, 1.0, 0.3)
	var stump := PackedVector2Array([at + Vector2(-w, 0), at + Vector2(-w * 0.85, top * 0.6), at + Vector2(-w * 0.75, top),
		at + Vector2(-w * 0.3, top * 0.86), at + Vector2(0, top * 1.12), at + Vector2(w * 0.35, top * 0.8), at + Vector2(w * 0.8, top * 1.04),
		at + Vector2(w * 0.9, top * 0.5), at + Vector2(w * 1.05, 0)])
	O.part(ci, stump, st, 1.5, 1.0, 0.4)
	for i in 4:
		var x := (-0.6 + i * 0.4) * w
		ci.draw_line(at + Vector2(x, -4.0), at + Vector2(x + r.randf_range(-3, 3), top * r.randf_range(0.5, 0.8)), Color(st["ombre"], 0.7), 1.0, true)
	var glow := etat == "ravive"
	for i in 5:
		var u := (i - 2) * 0.22
		_cristal(ci, at + Vector2(u * w * 1.6 * fl, top * 0.85), h * (0.5 - absf(u) * 0.9), u * 1.4 * fl, verre, glow)
	if etat == "ravive":
		var moss: Dictionary = _P("racine", etat).call("mousse")
		O.poly(ci, O.blob(at + Vector2(-w * 0.55, top * 0.45), w * 0.4, h * 0.05, at.x, 0.3, 14), moss["clair"])


## Forêt × Roncier : une arche de racines pétrifiées, reprise par la ronce (églantines une fois ravivée).
static func _arceau_ronce(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, etat: String) -> void:
	var st: Dictionary = _P("racine", etat).call("pierre")
	var bois: Dictionary = _P("racine", etat).call("bois")
	var ron: Dictionary = _P("ronce", etat).call("ronce")
	var span := h * 0.75
	var a := at + Vector2(-span * fl, 0)
	var b := at + Vector2(span * 0.8 * fl, 2.0)
	var c := at + Vector2(-span * 0.2 * fl, -h * 1.35)
	var arc := O.curve(a, c, b, 14)
	# L'arche : un ruban épais (deux bords de la courbe).
	var band := PackedVector2Array()
	var back := PackedVector2Array()
	for i in arc.size():
		var t := (arc[mini(i + 1, arc.size() - 1)] - arc[maxi(i - 1, 0)]).normalized()
		var th := h * (0.13 - 0.05 * sin(PI * i / (arc.size() - 1.0)))
		band.append(arc[i] + t.orthogonal() * th)
		back.append(arc[i] - t.orthogonal() * th)
	back.reverse()
	band.append_array(back)
	O.part(ci, band, st, 1.4, 1.0, 0.4)
	# Une racine plus fine qui croise l'arche.
	O.brush(ci, O.curve(at + Vector2(-span * 0.5 * fl, 2), at + Vector2(span * 0.1 * fl, -h * 0.75), at + Vector2(span * 0.55 * fl, -h * 0.2), 10), h * 0.07, bois["ombre"], 0.2, 0.6)
	O.brush(ci, O.curve(at + Vector2(-span * 0.5 * fl, 1), at + Vector2(span * 0.1 * fl, -h * 0.76), at + Vector2(span * 0.55 * fl, -h * 0.21), 10), h * 0.035, st["reflet"], 0.2, 0.6)
	# La ronce s'enroule autour de l'arche.
	for k in 3:
		var pts := PackedVector2Array()
		var phase := r.randf() * TAU
		for i in arc.size():
			var t := (arc[mini(i + 1, arc.size() - 1)] - arc[maxi(i - 1, 0)]).normalized()
			pts.append(arc[i] + t.orthogonal() * sin(i * 1.3 + phase + k * 2.0) * h * 0.16)
		var part := pts.slice(k * 3, arc.size() - (2 - k) * 2)
		O.brush(ci, part, 2.6, O.Ink.encre(), 0.5, 0.3)
		O.brush(ci, part, 1.8, ron["ombre"], 0.5, 0.3)
		O.brush(ci, part, 0.7, ron["clair"], 0.5, 0.3)
		for j in range(1, part.size() - 1, 2):
			var t := (part[j + 1] - part[j - 1]).normalized()
			O.poly(ci, O.Ink.thorn(part[j], (t.orthogonal() * (1.0 if j % 4 == 1 else -1.0)).angle() - 0.4, 3.4, 1.5), O.Ink.encre())
		if etat == "ravive":
			var p: Vector2 = part[part.size() / 2]
			O.flower(ci, p, 3.6, Art.mc("ronce", "ravive", "fleur"), Art.mc("ronce", "ravive", "fleur_coeur"), r.randf() * TAU)
