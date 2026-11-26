## Arène du Saule exsangue en décor (refonte du monde, vague 3b A2) : l'étang de la Vallée de Sève, dans
## le style des « Paysages d'herbier » (trois quarts, encre fine, lumière haut-gauche, Art.MONDE › seve).
## Même contrat que world_art/arenes.gd (Roncier, Marais), appelé par region_art/seve.gd :
##   - le mur : une berge de vase où pousse une ceinture de saules en rideau, de roseaux et de massettes
##     (« m0 »… : MUR_VARIANTES variantes, une sur deux porte un saule) ;
##   - le repère « r0 » : le grand saule, au fond de l'étang, son rideau qui touche l'eau ;
##   - le sol : l'étang lui-même, une eau basse sur un fond de limon, des îlots de vase et des coulées de
##     sève figée (flétri) ; une eau claire, des nénuphars et des myosotis d'eau (ravivé) ;
##   - ce qui bouge : la sève qui suinte des saules pendant le combat, une lueur ambrée au pied de la
##     berge, les sillons du mur qui se resserre.
## Flétri : fils gris et nus qui pendent, roseaux secs, sève figée en coulées ambrées. Ravivé : rideaux
## vert d'eau, massettes brunes, myosotis et fleurs d'eau.
##
## Dessin seul : aucune collision, rien du combat ; le hasard est tiré de graines fixes. Taille : une image
## de mur et le repère tiennent dans les boîtes du Roncier (budget lieux_bake partagé, voir arenes_test).
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

const REG := "seve"
const MUR_VARIANTES := 6
const REPERES := 1


static func _m(etat: String, key: String):
	return Art.mc(REG, "ravive" if etat == "ravive" else "fletri", key)


static func keys() -> Array:
	var out := []
	for i in MUR_VARIANTES:
		out.append("m%d" % i)
	for i in REPERES:
		out.append("r%d" % i)
	return out


static func _rng(key: String, salt := 3) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([REG, key, salt])
	return r


static func piece_box(key: String) -> Rect2:
	if key.begins_with("r"):
		return Rect2(-176, -288, 352, 330)
	return Rect2(-116, -160, 232, 190)


static func piece(ci: CanvasItem, key: String, etat: String) -> void:
	var r := _rng(key)
	var v := int(key.substr(1))
	if key.begins_with("r"):
		_repere(ci, r, v, etat)
	else:
		_mur(ci, r, v, etat)


# --- Saule pleureur (le même que celui de la Vallée, decor_vallee.gd › Willow, en statique) ---


## Mèche qui pend (rideau du saule) : de a vers le bas, longueur l ; vivante, des feuilles étroites de
## part et d'autre ; morte, un fil nu, parfois cassé.
static func _strand(ci: CanvasItem, a: Vector2, l: float, sway: float, w: float, col: Color, leaf_col: Color, live: bool, sd: int) -> void:
	var pts := PackedVector2Array()
	var n := 7
	for i in n:
		var u := float(i) / (n - 1)
		pts.append(a + Vector2(sway * u * u * l + sin(u * 4.0 + sd) * w * 0.6, l * u))
	if not live:
		if sd % 3 == 0:
			pts = pts.slice(0, 4)
		O.brush(ci, pts, maxf(0.8, w * 0.4), col, 0.0, 1.0)
		return
	O.brush(ci, pts, maxf(0.9, w * 0.45), col, 0.0, 0.6)
	for i in range(1, n):
		var q: Vector2 = pts[i]
		var side := 1.0 if (i + sd) % 2 == 0 else -1.0
		O.poly(ci, Ink.leaf(q, PI * 0.5 + side * 0.55, w * 2.0, w * 0.75, 0.05 * side), leaf_col if i % 3 != 1 else col)


## Saule pleureur au pied en « at », hauteur h : tronc court et noueux, maîtresses branches en éventail,
## rideau qui retombe. great : le grand saule (repère), plus large, plus de branches et de mèches.
static func _saule(ci: CanvasItem, at: Vector2, h: float, r: RandomNumberGenerator, etat: String, great: bool) -> void:
	var live := etat == "ravive"
	var w := h * (0.075 if great else 0.068)
	var bois: Dictionary = _m(etat, "bois")
	var saule: Dictionary = _m(etat, "saule")
	var lean := r.randf_range(-0.08, 0.08)
	var top := at + Vector2(lean * h, -h * 0.42)
	for i in (7 if great else 3):
		var a := PI * (0.08 + 0.84 * (i + 0.5) / (7.0 if great else 3.0))
		var e := at + Vector2(cos(a) * w * (5.0 if great else 2.6), sin(a) * w * 0.6 + 2.0)
		O.brush(ci, O.curve(at + Vector2(cos(a) * w * 0.6, -w * 0.4), at + Vector2(cos(a) * w * 2.0, -w * 0.6), e, 5), w * 0.55, bois["ombre"], 0.0, 1.0)
	var trunk := PackedVector2Array([
		at + Vector2(-w * 1.7, 2), at + Vector2(-w * 0.95, -h * 0.06), at + Vector2(-w * 0.85, -h * 0.2), top + Vector2(-w * 0.75, h * 0.06),
		top + Vector2(-w * 0.9, -h * 0.02), top + Vector2(-w * 0.2, -h * 0.05), top + Vector2(w * 0.5, -h * 0.03),
		top + Vector2(w * 0.7, h * 0.07), at + Vector2(w * 0.9, -h * 0.2), at + Vector2(w * 0.85, -h * 0.07), at + Vector2(w * 1.9, 2),
		at + Vector2(w * 0.4, -h * 0.01), at + Vector2(-w * 0.5, -h * 0.015)])
	O.part(ci, trunk, bois, 1.6, 1.0, 0.4)
	for i in 3:
		ci.draw_arc(at + Vector2(r.randf_range(-0.4, 0.4) * w, -h * (0.08 + 0.1 * i)), w * 0.32, PI * 1.1, PI * 1.9, 6, Color(bois["ombre"], 0.8), 1.0, true)
	if not live:
		# Sève figée qui a coulé d'une blessure de l'écorce.
		var sv: Dictionary = _m("fletri", "seve")
		var wound := at + Vector2(w * 0.15, -h * 0.28)
		O.poly(ci, Ink.oval(wound, w * 0.22, w * 0.36, 10), Ink.encre())
		O.brush(ci, PackedVector2Array([wound, wound + Vector2(w * 0.08, h * 0.06), wound + Vector2(-w * 0.04, h * 0.12)]), w * 0.28, sv["ombre"], 0.0, 0.5)
		ci.draw_circle(wound + Vector2(-w * 0.04, h * 0.125), w * 0.16, sv["clair"].darkened(0.2))
	var crowns: Array = []
	var nb := 6 if great else 4
	for i in nb:
		var u := (i - (nb - 1) * 0.5) / maxf(1.0, (nb - 1) * 0.5)
		var tip := top + Vector2(u * h * 0.36, -h * (0.42 + 0.12 * (1.0 - absf(u))) + r.randf_range(-0.04, 0.04) * h)
		var mid := top.lerp(tip, 0.5) + Vector2(u * h * 0.02, -h * 0.1)
		var br := O.curve(top + Vector2(u * w * 0.5, 0), mid, tip, 7)
		O.brush(ci, br, w * 0.75, Ink.encre(), 0.0, 0.8)
		O.brush(ci, br, w * 0.55, bois["clair"], 0.0, 0.8)
		crowns.append(tip)
	var curtain_len := h * (0.52 if great else 0.5)
	if not live:
		for i in crowns.size():
			var c: Vector2 = crowns[i]
			var sgn := signf(c.x - top.x)
			var arc := O.curve(c, c + Vector2(sgn * h * 0.1, -h * 0.02), c + Vector2(sgn * h * 0.16, h * 0.08), 5)
			O.brush(ci, arc, w * 0.3, bois["ombre"], 0.0, 1.0)
			for j in (7 if great else 5):
				var a: Vector2 = arc[mini(j % arc.size(), arc.size() - 1)] + Vector2(r.randf_range(-3, 3), 0)
				_strand(ci, a, curtain_len * r.randf_range(0.5, 0.95), r.randf_range(-0.08, 0.08), w * 0.45, saule["ombre"] if j % 2 else saule["clair"], saule["clair"], false, j + i * 7)
		return
	var crown := top + Vector2(0, -h * 0.47)
	var cw := h * (0.46 if great else 0.4)
	for i in (22 if great else 12):
		var u := r.randf_range(-1.0, 1.0)
		_strand(ci, crown + Vector2(u * cw, h * 0.06 - absf(u) * h * 0.02), curtain_len * r.randf_range(0.75, 1.05), u * 0.1, w * 0.55, saule["ombre"], saule["ombre"].darkened(0.08), true, i)
	var masses := []
	var nm := 9 if great else 6
	for i in nm:
		var u := (i - (nm - 1) * 0.5) / ((nm - 1) * 0.5)
		masses.append([crown + Vector2(u * cw * 0.85, -h * 0.05 * (1.0 - u * u) + r.randf_range(-3, 3)), h * r.randf_range(0.1, 0.13)])
	masses.append([crown + Vector2(-cw * 0.15, -h * 0.08), h * 0.15])
	masses.sort_custom(func(x, y): return x[0].y < y[0].y)
	for ms in masses:
		O.part(ci, Ink.lumpy(ms[0], ms[1] * 1.3, ms[1] * 0.8, 24, 0.12, 10.0, ms[0].x), saule, 1.2, 1.0, 0.7)
	for i in (18 if great else 10):
		var u := r.randf_range(-1.0, 1.0)
		_strand(ci, crown + Vector2(u * cw * 0.95, h * 0.04), curtain_len * r.randf_range(0.6, 0.95), u * 0.12, w * 0.5, saule["clair"], saule["reflet"], true, i + 31)
	for i in (7 if great else 3):
		var q: Vector2 = crown + Vector2(r.randf_range(-0.8, 0.6) * cw, r.randf_range(-0.12, 0.05) * h)
		O.flower(ci, q, r.randf_range(2.0, 2.8) * (1.3 if great else 1.0), _m("ravive", "fleur"), _m("ravive", "fleur_coeur"), r.randf() * TAU)


# --- Berge : roseaux, massettes, fougères ---


## Roseau ou massette (pied p, hauteur h, penché de lean) ; massette : l'épi brun au bout (vivant) ou
## défait en bourre grise (flétri).
static func _roseau(ci: CanvasItem, p: Vector2, h: float, lean: float, etat: String, massette: bool, col: Color) -> void:
	O.blade(ci, p, h, lean, maxf(1.4, h * 0.035), col)
	if not massette:
		return
	var tip := p + Vector2(lean * h, -h)
	var spike := p.lerp(tip, 0.82) + Vector2(lean * h * 0.05, 0)
	if etat == "ravive":
		var brun: Dictionary = _m("ravive", "bois")
		O.part(ci, Ink.oval(spike, h * 0.04, h * 0.1, 10, lean), brun, 0.9, 1.0, 0.5)
	else:
		var cendre: Color = _m("fletri", "cendre")
		O.poly(ci, Ink.lumpy(spike, h * 0.05, h * 0.09, 12, 0.3, 5.0, h), Color(cendre, 0.55))
		O.poly(ci, Ink.oval(spike, h * 0.025, h * 0.07, 8, lean), _m("fletri", "bois")["ombre"])


## Fronde de fougère d'eau : recroquevillée et brune (flétri), déployée (ravivé).
static func _fougere(ci: CanvasItem, p: Vector2, h: float, side: float, etat: String) -> void:
	var pal: Dictionary = _m(etat, "fougere")
	var live := etat == "ravive"
	var tip := p + Vector2(side * h * (0.55 if live else 0.25), -h * (0.85 if live else 0.6))
	var rib := O.curve(p, p + Vector2(side * h * 0.1, -h * 0.75), tip, 8)
	O.brush(ci, rib, 1.4, pal["ombre"], 0.0, 1.0)
	for j in range(1, rib.size() - 1):
		var d := (rib[j + 1] - rib[j - 1]).normalized()
		var l := h * 0.22 * (1.0 - float(j) / rib.size())
		for s in [-1.0, 1.0]:
			O.poly(ci, Ink.leaf(rib[j], d.angle() + s * (1.1 if live else 0.6), l, l * 0.35, 0.1 * s), pal["clair"] if (j + int(s)) % 2 else pal["ombre"])
	if not live:
		ci.draw_arc(tip + Vector2(side * 2.0, 2.0), h * 0.06, 0.0, TAU * 0.8, 8, pal["ombre"], 1.4, true)


## Bourrelet de berge (vase et eau au pied) : le pied du mur, plus sombre côté étang.
static func _berge(ci: CanvasItem, w: float, v: int, etat: String) -> void:
	O.poly(ci, O.blob(Vector2(0, 4), w * 0.62, w * 0.12, float(v), 0.18, 26), Color(_m(etat, "eau"), 0.75))
	O.poly(ci, O.blob(Vector2(-2, -1), w * 0.55, w * 0.1, float(v) + 2.0, 0.22, 26), _m(etat, "sol_sombre"))
	O.poly(ci, O.blob(Vector2(-6, -3), w * 0.36, w * 0.05, float(v) + 5.0, 0.2, 20), Color(_m(etat, "sol_clair"), 0.6))


## Pan de mur de l'étang : une berge, un saule en rideau (une variante sur deux) entouré de roseaux,
## ou une roselière serrée de massettes et de fougères.
static func _mur(ci: CanvasItem, r: RandomNumberGenerator, v: int, etat: String) -> void:
	var live := etat == "ravive"
	var h := 80.0 * r.randf_range(0.92, 1.08)
	var willow := v % 2 == 0
	O.cast_shadow(ci, Vector2.ZERO, h * (1.0 if willow else 0.9), h * (0.8 if willow else 0.4), 0.3)
	_berge(ci, h * 1.6, v, etat)
	var reed_a: Color = _m(etat, "touffe")
	var reed_b: Color = _m(etat, "touffe_2")
	var stems := []
	var n := 9 if willow else 16
	for i in n:
		var u := r.randf_range(-1.0, 1.0)
		var back := r.randf() < 0.5
		stems.append([Vector2(u * h * (0.62 if willow else 0.55), r.randf_range(-6.0, -1.0) if back else r.randf_range(-1.0, 4.0)),
			h * r.randf_range(0.55, 0.95) * (1.0 - 0.35 * absf(u)), u * 0.25 + r.randf_range(-0.12, 0.12), r.randf() < (0.3 if live else 0.22), i % 2 == 0])
	stems.sort_custom(func(x, y): return x[0].y < y[0].y)
	# Roseaux de l'arrière, puis le saule, puis ceux de l'avant.
	for s in stems:
		if s[0].y < -1.0:
			_roseau(ci, s[0], s[1], s[2], etat, s[3], reed_a if s[4] else reed_b)
	if willow:
		_saule(ci, Vector2(r.randf_range(-0.12, 0.12) * h, -2.0), h * r.randf_range(1.02, 1.14), r, etat, false)
	else:
		for i in 2:
			var side := -1.0 if i == 0 else 1.0
			_fougere(ci, Vector2(side * h * r.randf_range(0.2, 0.45), -1.0), h * r.randf_range(0.35, 0.5), side, etat)
	for s in stems:
		if s[0].y >= -1.0:
			_roseau(ci, s[0], s[1] * 0.85, s[2], etat, s[3], reed_a if s[4] else reed_b)
	if live:
		# Myosotis d'eau et une fleur d'eau blanche au pied.
		for i in 4:
			O.flower(ci, Vector2(r.randf_range(-0.55, 0.55) * h, r.randf_range(-3.0, 3.0)), r.randf_range(2.4, 3.4), _m("ravive", "fleur" if i % 3 else "fleur_2"), _m("ravive", "fleur_coeur"), r.randf() * TAU)
		var lily := Vector2(r.randf_range(-0.4, 0.4) * h, 7.0)
		O.poly(ci, Ink.oval(lily, 9.0, 3.4, 12), _m("ravive", "feuillage")["clair"])
		ci.draw_line(lily, lily + Vector2(6.0, -1.5), _m("ravive", "feuillage")["ombre"], 1.0, true)
	elif not willow:
		# Une flaque de sève figée au pied des roseaux (les saules ont déjà leur coulée).
		var sv: Dictionary = _m("fletri", "seve")
		var p := Vector2(r.randf_range(-0.35, 0.35) * h, 2.0)
		O.poly(ci, O.blob(p, 11.0, 3.5, float(v), 0.25, 14), sv["ombre"])
		O.poly(ci, O.blob(p + Vector2(-2, -0.8), 6.0, 1.6, float(v) + 1.0, 0.2, 10), sv["clair"].darkened(0.25))


## Le grand saule (repère de l'étang) : immense, son rideau retombe jusqu'à l'eau ; à son pied, une mare
## (croupie et figée de sève, ou claire et fleurie), une roselière de part et d'autre.
static func _repere(ci: CanvasItem, r: RandomNumberGenerator, v: int, etat: String) -> void:
	var live := etat == "ravive"
	var h := 236.0
	O.cast_shadow(ci, Vector2.ZERO, h * 0.75, h * 0.6, 0.32)
	var c := Vector2(h * 0.04, h * 0.05)
	O.poly(ci, O.blob(c + Vector2(2, 2), h * 0.55, h * 0.12, 3.0, 0.1, 30), Color(Ink.encre(), 0.45))
	O.poly(ci, O.blob(c, h * 0.53, h * 0.11, 3.0, 0.1, 30), _m(etat, "eau"))
	ci.draw_line(c + Vector2(-h * 0.32, -h * 0.03), c + Vector2(-h * 0.12, -h * 0.045), Color(_m(etat, "eau_reflet"), 0.7), 1.6, true)
	for side in [-1.0, 1.0]:
		for i in 6:
			var p := Vector2(side * h * r.randf_range(0.28, 0.5), r.randf_range(-4.0, 2.0))
			_roseau(ci, p, h * r.randf_range(0.16, 0.26), side * 0.2 + r.randf_range(-0.1, 0.1), etat, i % 3 == 0, _m(etat, "touffe" if i % 2 else "touffe_2"))
	_saule(ci, Vector2(-h * 0.02, -h * 0.02), h, r, etat, true)
	if live:
		for i in 4:
			var q := c + Vector2(r.randf_range(-0.42, 0.42) * h, r.randf_range(-0.04, 0.06) * h)
			O.poly(ci, Ink.oval(q, h * 0.04, h * 0.016, 10), _m("ravive", "feuillage")["clair"])
			O.flower(ci, q + Vector2(0, -2), h * 0.013, _m("ravive", "fleur_2"), _m("ravive", "fleur_coeur"))
	else:
		var sv: Dictionary = _m("fletri", "seve")
		O.poly(ci, O.blob(c + Vector2(h * 0.22, h * 0.02), h * 0.12, h * 0.03, 7.0, 0.2, 16), Color(sv["ombre"], 0.9))
		O.poly(ci, O.blob(c + Vector2(h * 0.2, h * 0.012), h * 0.06, h * 0.012, 8.0, 0.2, 12), sv["clair"])


# --- Ce qui bouge sur les pièces ---


## Pendant le combat : la sève suinte des saules et des roseaux en gouttes ambrées qui luisent (une pièce
## sur trois). a : l'arène (t, state), i : rang de la pièce.
static func piece_live(ci: CanvasItem, key: String, a, i: int) -> void:
	if a.state != "combat" or i % 3 != 0:
		return
	var r := _rng(key, 7)
	var box := piece_box(key)
	var col: Color = _seve_vive()
	var n := 3 if key.begins_with("m") else 6
	for j in n:
		var p := Vector2(r.randf_range(0.3, 0.7) * box.size.x + box.position.x, r.randf_range(0.25, 0.7) * box.position.y)
		var k := fmod(a.t * 0.6 + j * 0.37 + i * 0.13, 1.0)
		var drop := p + Vector2(0, k * 26.0)
		var pulse := 0.5 + 0.5 * sin(a.t * 4.0 + i * 1.7 + j * 2.1)
		ci.draw_circle(drop, 8.0, Color(col, (0.05 + 0.08 * pulse) * (1.0 - k)))
		ci.draw_circle(drop, 2.0, Color(col, (0.45 + 0.4 * pulse) * (1.0 - k * 0.6)))


## Lueur de la sève malade (combat) : l'ambre de la sève figée, avivé.
static func _seve_vive() -> Color:
	return Color(_m("fletri", "seve")["reflet"]).lightened(0.35)


# --- Sol : l'étang ---


## Sol de l'arène (fixe, redessiné quand l'état change), etat « fletri » ou « ravive ». Une eau basse sur
## un fond de limon, cernée d'une berge de vase au pied du mur ; flétri : l'eau croupie, des îlots de
## vase, des coulées de sève figée qui rampent depuis la berge, des feuilles mortes qui flottent ;
## ravivé : une eau claire, des rides, des nénuphars, des myosotis et des touffes sur les îlots.
static func ground(ci: CanvasItem, a, etat: String) -> void:
	var c: Vector2 = a.center
	var R: float = a.max_radius
	var r := RandomNumberGenerator.new()
	r.seed = hash([REG, "sol"])
	var live := etat == "ravive"
	var sol: Color = _m(etat, "sol")
	var clair: Color = _m(etat, "sol_clair")
	var sombre: Color = _m(etat, "sol_sombre")
	var eau: Color = _m(etat, "eau")
	var reflet: Color = _m(etat, "eau_reflet")
	# La berge (une couronne de vase), puis l'eau, d'une seule grande surface chacune.
	var band := PackedVector2Array(O.blob(c, R * 1.0, R * 1.0, 3.0, 0.02, 96))
	band.append(band[0])
	O.poly(ci, O.blob(c, R * 0.97, R * 0.97, 5.0, 0.025, 96), Color(sombre.lerp(sol, 0.4), 0.7 if not live else 0.55))
	ci.draw_polyline(band, Color(sombre.darkened(0.3), 0.3), 44.0)
	O.poly(ci, O.blob(c, R * 0.86, R * 0.84, 9.0, 0.035, 96), Color(eau.lerp(sol, 0.35), 0.62) if not live else Color(eau.lerp(sol, 0.12), 0.78))
	var edge := PackedVector2Array(O.blob(c, R * 0.86, R * 0.84, 9.0, 0.035, 96))
	edge.append(edge[0])
	ci.draw_polyline(edge, Color(sombre.darkened(0.45), 0.5), 4.0, true)
	ci.draw_polyline(edge, Color(reflet, 0.18), 1.5, true)
	# Îlots de limon dans l'eau basse.
	for i in 6:
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * sqrt(r.randf_range(0.05, 0.5))
		var rx := R * r.randf_range(0.05, 0.1)
		O.poly(ci, O.blob(p, rx, rx * 0.5, float(i), 0.25, 20, r.randf() * PI), Color(clair, 0.32))
		if live:
			for j in 3:
				O.tuft(ci, p + Vector2(r.randf_range(-0.5, 0.5) * rx, r.randf_range(-0.2, 0.2) * rx), r.randf_range(8.0, 12.0), _m("ravive", "touffe"), _m("ravive", "touffe_2"), i * 5 + j)
	# Rides et reflets (longs traits clairs couchés, à la lumière d'en haut à gauche).
	for i in 18:
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * sqrt(r.randf_range(0.0, 0.7))
		var l := r.randf_range(18.0, 46.0)
		ci.draw_line(p, p + Vector2(l, -l * 0.08), Color(reflet, 0.16 if not live else 0.26), 1.4, true)
	if live:
		_floor_vive(ci, c, R, r)
	else:
		_floor_morte(ci, c, R, r)


static func _floor_morte(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator) -> void:
	var sv: Dictionary = _m("fletri", "seve")
	# Coulées de sève figée qui partent de la berge vers le milieu.
	for i in 11:
		var ang := TAU * i / 11.0 + r.randf_range(-0.15, 0.15)
		var p := c + Vector2.from_angle(ang) * R * 0.95
		var pts := PackedVector2Array([p])
		var l := R * r.randf_range(0.22, 0.42)
		var dir := ang + PI
		for j in 8:
			dir += r.randf_range(-0.35, 0.35)
			p += Vector2.from_angle(dir) * l / 8.0
			pts.append(p)
		O.brush(ci, pts, r.randf_range(4.0, 6.5), Color(sv["ombre"], 0.7), 0.3, 1.0)
		O.brush(ci, pts.slice(0, 5), 1.6, Color(sv["clair"], 0.6), 0.2, 1.0)
		O.poly(ci, O.blob(pts[pts.size() - 1], 6.0, 2.6, float(i), 0.2, 12), Color(sv["ombre"], 0.75))
	# Feuilles mortes qui flottent, galets de la berge, bulles de vase.
	for i in 40:
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * sqrt(r.randf_range(0.02, 0.8))
		if i % 3 == 0:
			O.poly(ci, Ink.leaf(p, r.randf() * TAU, r.randf_range(6.0, 9.0), 3.0, 0.2), Color(_m("fletri", "feuille"), 0.75))
		elif i % 3 == 1:
			ci.draw_arc(p, r.randf_range(2.0, 4.0), 0.0, TAU, 10, Color(_m("fletri", "eau_reflet"), 0.3), 1.0, true)
		else:
			O.pebble(ci, c + Vector2.from_angle(r.randf() * TAU) * R * r.randf_range(0.87, 0.93), r.randf_range(2.5, 4.5), _m("fletri", "pierre"), float(i))


static func _floor_vive(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator) -> void:
	var leaf: Dictionary = _m("ravive", "feuillage")
	# Nénuphars : des feuilles rondes fendues, quelques fleurs blanches et jaunes.
	for i in 16:
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * sqrt(r.randf_range(0.05, 0.62))
		var s := r.randf_range(9.0, 15.0)
		var rot := r.randf() * TAU
		O.poly(ci, Ink.oval(p + Vector2(1.5, 1.5), s, s * 0.42, 14), Color(Ink.encre(), 0.3))
		O.part(ci, Ink.oval(p, s, s * 0.42, 14), leaf, 0.8, 1.0, 0.5)
		ci.draw_line(p, p + Vector2.from_angle(rot) * Vector2(s, s * 0.42), leaf["ombre"], 1.2, true)
		if i % 3 == 0:
			O.flower(ci, p + Vector2(-s * 0.2, -s * 0.2), s * 0.38, _m("ravive", "fleur_2"), _m("ravive", "fleur_coeur"), rot)
	# Myosotis et touffes sur la berge, rides claires.
	for i in 44:
		var p := c + Vector2.from_angle(TAU * i / 44.0 + r.randf_range(-0.05, 0.05)) * R * r.randf_range(0.87, 0.95)
		if i % 2 == 0:
			O.flower(ci, p, r.randf_range(2.6, 3.6), _m("ravive", "fleur"), _m("ravive", "fleur_coeur"), r.randf() * TAU)
		else:
			O.tuft(ci, p, r.randf_range(9.0, 14.0), _m("ravive", "touffe"), _m("ravive", "touffe_2"), i)
	for i in 6:
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * sqrt(r.randf_range(0.05, 0.5))
		for k in 2:
			ci.draw_arc(p, 8.0 + 9.0 * k, 0.0, TAU, 20, Color(_m("ravive", "eau_reflet"), 0.25 - 0.08 * k), 1.2, true)


## Ce qui bouge au sol : pendant le combat, une lueur de sève malade qui court au pied de la berge ;
## quand le mur s'est resserré, les sillons de vase qu'il a laissés derrière lui.
static func live(ci: CanvasItem, a) -> void:
	var c: Vector2 = a.center
	if a.radius < a.max_radius - 2.0:
		var mat: Color = _m("fletri", "sol_sombre").darkened(0.35)
		for i in 40:
			var d := Vector2.from_angle(TAU * (i + 0.5) / 40.0)
			ci.draw_line(c + d * (a.radius + 18.0), c + d * (a.max_radius - 6.0), Color(mat, 0.55), 7.0, true)
			ci.draw_line(c + d * (a.radius + 18.0) + d.orthogonal() * 4.0, c + d * (a.max_radius - 6.0) + d.orthogonal() * 4.0, Color(_m("fletri", "eau_reflet"), 0.22), 2.0, true)
	if a.state != "combat":
		return
	var col := _seve_vive()
	var pulse := 0.5 + 0.5 * sin(a.t * 3.0)
	var pts := PackedVector2Array()
	for i in 97:
		pts.append(c + Vector2.from_angle(TAU * i / 96.0) * (a.radius - 10.0))
	ci.draw_polyline(pts, Color(col, 0.07 + 0.07 * pulse), 26.0, true)
	ci.draw_polyline(pts, Color(col, 0.22 + 0.2 * pulse), 2.5, true)
