## Arène de l'Ancien en décor (refonte du monde, vague 3b A2) : la clairière de la Forêt pétrifiée, dans
## le style des « Paysages d'herbier » (trois quarts, encre fine, lumière haut-gauche, Art.MONDE › racine).
## Même contrat que world_art/arenes.gd (Roncier, Marais), appelé par region_art/racine.gd :
##   - le mur : des arceaux de racines pétrifiées qui sortent de terre et y replongent, entre des fûts
##     cassés net et des souches (« m0 »… : MUR_VARIANTES variantes) ;
##   - le repère « r0 » : un chêne de pierre immense au fond de la clairière, ses branches cassées ;
##   - le sol : la tranche d'une souche colossale, ses cernes de pierre en rond, des fentes qui partent du
##     cœur (flétri) ; le bois reprend son brun chaud, la mousse et les feuilles d'or (ravivé) ;
##   - ce qui bouge : la braise qui couve dans les fentes des racines pendant le combat, une lueur d'ambre
##     au pied du mur, les sillons du mur qui se resserre.
## Flétri : pierre grise et froide qui garde le grain du bois, veinée d'ocre. Ravivé : écorce brune,
## mousse olive, couronnes d'automne or et ocre, champignons.
##
## Dessin seul : aucune collision, rien du combat ; le hasard est tiré de graines fixes. Taille : une image
## de mur et le repère tiennent dans les boîtes du Roncier (budget lieux_bake partagé, voir arenes_test).
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

const REG := "racine"
const MUR_VARIANTES := 6
const REPERES := 1


static func _m(etat: String, key: String):
	return Art.mc(REG, "ravive" if etat == "ravive" else "fletri", key)


static func _encre_decor() -> Color:
	return Art.mc("commun", "", "encre_decor")


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


# --- Outils (les mêmes que decor_foret.gd › Petrified, en statique) ---


static func _moss(ci: CanvasItem, c: Vector2, rx: float, ry: float, seed: float) -> void:
	O.part(ci, Ink.lumpy(c, rx, ry, 16, 0.18, 7.0, seed), _m("ravive", "mousse"), 0.8, 1.0, 0.4)


static func _grain(ci: CanvasItem, a: Vector2, b: Vector2, w: float, n: int, col: Color, r: RandomNumberGenerator) -> void:
	for i in n:
		var x := (i + 0.5) / n * 2.0 - 1.0
		var pts := PackedVector2Array()
		for j in 6:
			var u := j / 5.0
			pts.append(a.lerp(b, u * r.randf_range(0.8, 1.0)) + Vector2(x * w * (1.0 - 0.35 * u) + sin(u * 6.0 + i) * w * 0.08, 0))
		O.brush(ci, pts, 0.9, col, 0.3, 0.3)


## Couronne d'automne : masses bosselées or et ocre (quelques-unes olive), du fond vers l'avant.
static func _crown(ci: CanvasItem, c: Vector2, rx: float, ry: float, n: int, mass: float, r: RandomNumberGenerator, tips := []) -> void:
	var leaf: Dictionary = _m("ravive", "feuillage")
	var mo: Dictionary = _m("ravive", "mousse")
	var masses := []
	for tp in tips:
		masses.append([tp, mass * r.randf_range(0.75, 0.95), false])
	for i in n:
		var a := r.randf() * TAU
		var d := sqrt(r.randf())
		masses.append([c + Vector2(cos(a) * rx * d, sin(a) * ry * d), mass * r.randf_range(0.75, 1.1) * (1.0 - 0.25 * d), r.randf() < 0.18])
	masses.sort_custom(func(x, y): return x[0].y < y[0].y)
	for ms in masses:
		O.poly(ci, Ink.lumpy(ms[0] + Vector2(0.6, 0.8), ms[1] + 1.2, (ms[1] + 1.2) * 0.84, 20, 0.12, 8.0, ms[0].x), _encre_decor())
	for ms in masses:
		var pal: Dictionary = mo if ms[2] else leaf
		var p: Vector2 = ms[0]
		var rr: float = ms[1]
		O.poly(ci, Ink.lumpy(p, rr, rr * 0.82, 20, 0.12, 8.0, p.x), pal["ombre"])
		O.poly(ci, Ink.lumpy(p + Vector2(-0.18, -0.22) * rr, rr * 0.8, rr * 0.62, 18, 0.14, 7.0, p.y), pal["clair"])
		O.poly(ci, Ink.lumpy(p + Vector2(-0.38, -0.42) * rr, rr * 0.32, rr * 0.22, 12, 0.2, 5.0, p.x), Color(pal["reflet"], 0.75))
	for i in n / 2 + 2:
		var ms: Array = masses[r.randi() % masses.size()]
		var p: Vector2 = ms[0] + Vector2(r.randf_range(-1.0, 1.0), r.randf_range(-0.6, 0.7)) * ms[1]
		O.poly(ci, Ink.leaf(p, r.randf_range(0.0, TAU), ms[1] * 0.45, ms[1] * 0.2, 0.2), _m("ravive", "feuille" if i % 2 else "feuille_2"))


## Branche de pierre ou de bois qui se divise ; broken : cassée net, la tranche claire au bout.
static func _branch(ci: CanvasItem, from: Vector2, dir: Vector2, l: float, w: float, depth: int, r: RandomNumberGenerator, bois: Dictionary, tips: Array, broken: bool) -> void:
	var to := from + dir.rotated(r.randf_range(-0.3, 0.3)) * l
	var mid := from.lerp(to, 0.5) + dir.orthogonal() * r.randf_range(-0.14, 0.14) * l
	var pts := O.curve(from, mid, to, 6)
	var end := 0.35 if broken and depth <= 0 else 0.75
	O.brush(ci, pts, w + 1.4, Ink.encre(), 0.0, end)
	O.brush(ci, pts, w, bois["ombre"], 0.0, end)
	var off := Vector2(-0.35, -0.45) * w * 0.3
	O.brush(ci, O.curve(from + off, mid + off, to, 6), w * 0.38, bois["clair"], 0.0, 0.6)
	if depth <= 0:
		if broken:
			O.poly(ci, Ink.oval(to, w * 0.42, w * 0.3, 10), bois["reflet"])
		tips.append(to)
		return
	for sgn in [-1.0, 1.0]:
		_branch(ci, from.lerp(to, r.randf_range(0.6, 0.95)), dir.rotated(sgn * r.randf_range(0.35, 0.7)), l * r.randf_range(0.5, 0.7), w * 0.6, depth - 1, r, bois, tips, broken)
	if not broken:
		tips.append(to)


# --- Mur : arceaux de racines, fûts cassés, souches ---


## Un arceau de racine de a à b, sommet tiré vers peak, épaisseur w : encre, ombre, filet clair ; ses
## deux pieds plongent dans un trou d'ombre. Flétri : une veine d'ocre ; ravivé : mousse et feuilles d'or
## sur le dos. Renvoie le dos de l'arceau.
static func _arceau(ci: CanvasItem, a: Vector2, peak: Vector2, b: Vector2, w: float, etat: String) -> Vector2:
	var bois: Dictionary = _m(etat, "bois")
	var line := O.curve(a, peak + (peak - a.lerp(b, 0.5)) * 0.9, b, 12)
	O.poly(ci, Ink.oval(a, w * 0.8, w * 0.28, 10), Color(_encre_decor(), 0.55))
	O.poly(ci, Ink.oval(b, w * 0.7, w * 0.25, 10), Color(_encre_decor(), 0.55))
	O.brush(ci, line, w + 1.8, Ink.encre(), 0.15, 0.4)
	O.brush(ci, line, w, bois["clair"].lerp(bois["ombre"], 0.45), 0.15, 0.4)
	var lit := PackedVector2Array()
	for q in line:
		lit.append(q + Vector2(-0.25, -0.3) * w)
	O.brush(ci, lit.slice(1, 11), w * 0.38, bois["reflet"].lerp(bois["clair"], 0.4), 0.3, 0.5)
	var top: Vector2 = line[6] + Vector2(0, -w * 0.4)
	if etat == "ravive":
		_moss(ci, top, w * 1.3, w * 0.4, top.x)
		O.poly(ci, Ink.leaf(top, -PI / 2.0 - 0.5, w * 1.3, w * 0.5, 0.1), _m("ravive", "feuille"))
		O.poly(ci, Ink.leaf(top, -PI / 2.0 + 0.6, w * 1.1, w * 0.45, 0.1), _m("ravive", "feuille_2"))
	else:
		O.brush(ci, line.slice(3, 9), 1.0, Color(_m("fletri", "veine"), 0.75), 0.3, 0.3)
	return top


## Fût pétrifié cassé net (pied at, hauteur h) : grain du bois, cassure aux cernes clairs, veines d'ocre
## et lichen (flétri) ; écorce brune, mousse, lierre et une jeune couronne d'automne (ravivé).
static func _fut(ci: CanvasItem, at: Vector2, h: float, r: RandomNumberGenerator, etat: String) -> void:
	var bois: Dictionary = _m(etat, "bois")
	var w := h * 0.1
	var lean := r.randf_range(-0.05, 0.05)
	var top := at + Vector2(lean * h, -h * 0.72)
	for sgn in [-1.0, 1.0, 0.35]:
		var a := at + Vector2(sgn * w * 0.6, -h * 0.04)
		var b := at + Vector2(sgn * w * 2.8 + r.randf_range(-2, 2), r.randf_range(1.0, 3.0))
		O.brush(ci, O.curve(a, a.lerp(b, 0.5) + Vector2(0, -w * 0.4), b, 5), w * 0.9, bois["ombre"], 0.0, 1.0)
	var jag := r.randf_range(0.05, 0.1) * h
	var fut := PackedVector2Array([
		at + Vector2(-w * 2.0, 2), at + Vector2(-w * 1.05, -h * 0.08), top + Vector2(-w * 0.8, 0),
		top + Vector2(-w * 0.55, -jag), top + Vector2(-w * 0.1, -jag * 0.3), top + Vector2(w * 0.25, -jag * 1.2),
		top + Vector2(w * 0.8, -jag * 0.2), at + Vector2(w * 1.1, -h * 0.09), at + Vector2(w * 2.1, 2),
		at + Vector2(w * 0.5, -h * 0.02), at + Vector2(-w * 0.4, -h * 0.025)])
	O.part(ci, fut, bois, 1.5, 1.0, 0.45)
	_grain(ci, at + Vector2(0, -h * 0.05), top + Vector2(0, h * 0.02), w * 0.8, 3, Color(bois["ombre"], 0.65), r)
	var cut := top + Vector2(w * 0.05, -jag * 0.55)
	O.poly(ci, Ink.oval(cut, w * 0.7, w * 0.22, 12), bois["reflet"].lerp(bois["clair"], 0.5))
	ci.draw_arc(cut, w * 0.35, 0.0, TAU, 12, Color(bois["ombre"], 0.6), 0.8, true)
	if etat != "ravive":
		var vein: Color = _m("fletri", "veine")
		for i in 2:
			var x := (i - 0.5) * w * 0.9
			O.brush(ci, O.curve(at + Vector2(x, -h * r.randf_range(0.12, 0.25)), at + Vector2(x + w * 0.5, -h * 0.4), at + Vector2(x + lean * h * 0.5, -h * r.randf_range(0.5, 0.62)), 5), 1.1, Color(vein, 0.75), 0.4, 0.4)
		# Une fente sombre du haut, où couve la braise pendant le combat (piece_live).
		O.brush(ci, PackedVector2Array([top + Vector2(w * 0.25, -jag), top + Vector2(w * 0.1, h * 0.14), top + Vector2(w * 0.3, h * 0.26)]), 1.6, _encre_decor(), 0.0, 1.0)
		for i in 3:
			var p := at + Vector2(r.randf_range(-0.6, 0.6) * w, -h * r.randf_range(0.1, 0.5))
			O.poly(ci, Ink.lumpy(p, w * 0.32, w * 0.18, 10, 0.2, 5.0, p.y), Color(bois["reflet"], 0.45))
		return
	_moss(ci, at + Vector2(-w * 0.3, -h * 0.02), w * 1.9, w * 0.55, h)
	var ivy: Dictionary = _m("ravive", "mousse")
	var prev := at + Vector2(-w * 0.6, -h * 0.03)
	for j in 7:
		var u := (j + 1) / 7.0
		var q := at + Vector2(-w * 0.6 + sin(u * 7.0) * w * 0.7, -h * 0.55 * u)
		ci.draw_line(prev, q, ivy["ombre"], 1.0, true)
		O.poly(ci, Ink.leaf(q, PI if j % 2 == 0 else 0.0, w * 0.8, w * 0.4, 0.1), ivy["clair"] if j % 2 else ivy["ombre"])
		prev = q
	_crown(ci, top + Vector2(0, -h * 0.12), h * 0.24, h * 0.12, 8, h * 0.09, r)


## Souche basse aux cernes de pierre (ou de bois moussu, un rejet et deux champignons ocre).
static func _souche(ci: CanvasItem, at: Vector2, s: float, r: RandomNumberGenerator, etat: String) -> void:
	var bois: Dictionary = _m(etat, "bois")
	var w := s * 0.4
	var h := s * r.randf_range(0.45, 0.6)
	for sgn in [-1.0, 1.0]:
		O.brush(ci, O.curve(at + Vector2(sgn * w * 0.7, -h * 0.2), at + Vector2(sgn * w * 1.1, -h * 0.05), at + Vector2(sgn * w * 1.6, 1.5), 4), w * 0.45, bois["ombre"], 0.0, 1.0)
	O.part(ci, PackedVector2Array([at + Vector2(-w, 0), at + Vector2(-w * 1.15, 2.0), at + Vector2(w * 1.15, 2.0), at + Vector2(w, 0), at + Vector2(w * 0.95, -h), at + Vector2(-w * 0.95, -h)]), bois, 1.3, 1.0, 0.3)
	O.part(ci, Ink.oval(at + Vector2(0, -h), w * 0.95, w * 0.38, 16), {"clair": bois["reflet"].lerp(bois["clair"], 0.4), "ombre": bois["clair"], "reflet": bois["reflet"]}, 0.9, 1.0, 0.2)
	for i in 2:
		var ring := Ink.oval(at + Vector2(0.6, -h), w * (0.3 + 0.28 * i), w * (0.12 + 0.1 * i), 12)
		ring.append(ring[0])
		ci.draw_polyline(ring, Color(bois["ombre"], 0.8), 0.8, true)
	if etat != "ravive":
		return
	_moss(ci, at + Vector2(-w * 0.35, -h - 0.5), w * 0.45, w * 0.16, s)
	var cap: Color = _m("ravive", "fleur_2")
	for sgn in [-1.0, 1.0]:
		var foot := at + Vector2(sgn * (w + 2.5), 1.5)
		var ct := foot + Vector2(0, -s * 0.16)
		ci.draw_line(foot, ct, _m("ravive", "cendre"), maxf(1.0, s * 0.05), true)
		O.part(ci, Ink.lumpy(ct, s * 0.11, s * 0.06, 10, 0.05, 3.0, sgn), {"clair": cap, "ombre": cap.darkened(0.3), "reflet": cap.lightened(0.4)}, 0.7, 1.0, 0.6)


## Pan de mur de la clairière : une dalle de roche basse, deux ou trois arceaux de racines entremêlés et,
## une variante sur deux, un fût cassé qui domine ; sinon une souche et des éboulis.
static func _mur(ci: CanvasItem, r: RandomNumberGenerator, v: int, etat: String) -> void:
	var h := 80.0 * r.randf_range(0.92, 1.08)
	var trunk := v % 2 == 0
	var st: Dictionary = _m(etat, "pierre")
	O.cast_shadow(ci, Vector2.ZERO, h * 1.1, h * (0.7 if trunk else 0.45), 0.32)
	# La dalle d'où sortent les racines.
	var pts := PackedVector2Array()
	var rot := r.randf() * 0.6
	for i in 9:
		var a := rot + TAU * i / 9.0
		var k := r.randf_range(0.85, 1.05)
		pts.append(Vector2(cos(a) * h * 0.5 * k, sin(a) * h * 0.13 * k - h * 0.05))
	O.part(ci, pts, st, 1.4, 1.0, 0.4)
	var arcs := []
	for i in 3:
		var x0 := -h * 0.75 + r.randf_range(-0.05, 0.2) * h + i * h * 0.32
		var x1 := x0 + h * r.randf_range(0.55, 0.85)
		var y0 := r.randf_range(-3.0, 3.0) + (i - 1) * 3.0
		var peak := Vector2((x0 + x1) * 0.5 + r.randf_range(-0.1, 0.1) * h, y0 - h * r.randf_range(0.45, 0.7) * (1.0 - 0.18 * i))
		arcs.append([Vector2(x0, y0), peak, Vector2(x1, y0 + r.randf_range(-2.0, 2.0)), h * r.randf_range(0.11, 0.15) * (1.0 - 0.12 * i)])
	arcs.sort_custom(func(a, b): return a[0].y < b[0].y)
	# Arceaux de l'arrière, le fût, puis l'arceau de devant.
	for i in arcs.size() - 1:
		var ac: Array = arcs[i]
		_arceau(ci, ac[0], ac[1], ac[2], ac[3], etat)
	if trunk:
		_fut(ci, Vector2(r.randf_range(-0.25, 0.25) * h, -2.0), h * r.randf_range(1.2, 1.4), r, etat)
	else:
		_souche(ci, Vector2(r.randf_range(-0.35, 0.35) * h, -1.0), h * 0.5, r, etat)
	var last: Array = arcs[arcs.size() - 1]
	_arceau(ci, last[0], last[1], last[2], last[3], etat)
	# Éboulis au pied, lichen ou mousse ; feuilles mortes ou d'or.
	for i in 4:
		var p := Vector2(r.randf_range(-0.6, 0.6) * h, r.randf_range(1.0, 5.0))
		O.pebble(ci, p, r.randf_range(2.5, 4.5), st, float(i + v))
		if etat == "ravive" and i % 2 == 0:
			_moss(ci, p + Vector2(0, -1.5), 4.0, 1.6, p.x)
	for i in 3:
		var p := Vector2(r.randf_range(-0.7, 0.7) * h, r.randf_range(-2.0, 4.0))
		O.poly(ci, Ink.leaf(p, r.randf() * TAU, 6.0, 2.6, 0.2), _m(etat, "feuille" if i % 2 else "feuille_2"))


## Le chêne de pierre (repère de la clairière) : contreforts larges, fût fendu, grandes branches cassées
## net ; ravivé, l'écorce brune, la mousse et le lierre, une couronne d'automne énorme ; entre ses
## contreforts, un arceau de racine.
static func _repere(ci: CanvasItem, r: RandomNumberGenerator, v: int, etat: String) -> void:
	var bois: Dictionary = _m(etat, "bois")
	var live := etat == "ravive"
	var h := 255.0
	var w := h * 0.085
	O.cast_shadow(ci, Vector2.ZERO, h * 0.55, h * 0.7, 0.34)
	for i in 6:
		var a := PI * (0.02 + 0.96 * i / 5.0)
		var tip := Vector2(cos(a) * w * r.randf_range(3.0, 4.2), sin(a) * w * 0.6 + 2.0)
		var from := Vector2(cos(a) * w * 0.6, -h * 0.06)
		var line := O.curve(from, from.lerp(tip, 0.5) + Vector2(0, -w * 0.6), tip, 6)
		O.brush(ci, line, w * 1.3 + 1.5, Ink.encre(), 0.0, 1.0)
		O.brush(ci, line, w * 1.3, bois["ombre"] if i > 2 else bois["clair"], 0.0, 1.0)
	var top := Vector2(w * 0.3, -h * 0.5)
	var fut := PackedVector2Array([
		Vector2(-w * 1.7, 2), Vector2(-w * 1.2, -h * 0.15), Vector2(-w * 0.95, -h * 0.35), top + Vector2(-w * 1.2, 0),
		top + Vector2(-w * 1.6, -h * 0.08), top + Vector2(-w * 0.4, -h * 0.03), top + Vector2(w * 0.3, -h * 0.07),
		top + Vector2(w * 1.5, -h * 0.06), top + Vector2(w * 1.0, 0), Vector2(w * 1.1, -h * 0.3), Vector2(w * 1.3, -h * 0.12), Vector2(w * 1.8, 2)])
	O.part(ci, fut, bois, 2.0, 1.0, 0.45)
	O.poly(ci, PackedVector2Array([Vector2(w * 0.1, -h * 0.1), Vector2(w * 0.45, -h * 0.28), Vector2(w * 0.2, -h * 0.42), Vector2(-w * 0.15, -h * 0.26)]), _encre_decor())
	for i in 5:
		var x := (i - 2) * w * 0.42
		O.brush(ci, O.curve(Vector2(x, -h * 0.03), Vector2(x + w * 0.2, -h * 0.25), Vector2(x * 0.9, -h * 0.46), 6), 1.0, Color(bois["ombre"], 0.6), 0.3, 0.3)
	if not live:
		for i in 3:
			var x := (i - 1) * w * 0.8
			O.brush(ci, O.curve(Vector2(x, -h * 0.08), Vector2(x - w * 0.3, -h * 0.2), Vector2(x + w * 0.1, -h * 0.36), 6), 1.3, Color(_m("fletri", "veine"), 0.75), 0.4, 0.4)
	var tips := []
	for lb in [[-0.85, 0.26, 1.0], [-0.3, 0.3, 1.1], [0.25, 0.28, 1.1], [0.8, 0.25, 0.95]]:
		var dir := Vector2.from_angle(-PI * 0.5 + lb[0] + r.randf_range(-0.08, 0.08))
		_branch(ci, top + Vector2(lb[0] * w * 0.7, h * 0.03), dir, h * lb[1] * (1.0 if live else 0.85), w * lb[2] * 0.75, 2 if live else 1, r, bois, tips, not live)
	# Un arceau de racine au pied, devant les contreforts.
	_arceau(ci, Vector2(-w * 4.6, 3), Vector2(-w * 3.0, -h * 0.1), Vector2(-w * 1.4, 4), w * 0.55, etat)
	if not live:
		for i in 5:
			var tp: Vector2 = tips[r.randi() % tips.size()]
			O.poly(ci, Ink.leaf(tp + Vector2(r.randf_range(-6, 6), r.randf_range(-2, 8)), r.randf_range(1.0, 2.2), w * 0.5, w * 0.22, 0.2), _m("fletri", "feuille"))
		for i in 4:
			var p := Vector2(r.randf_range(-1.0, 1.0) * w, -h * r.randf_range(0.08, 0.45))
			O.poly(ci, Ink.lumpy(p, w * 0.35, w * 0.18, 10, 0.2, 5.0, p.y), Color(bois["reflet"], 0.4))
		# Le cœur d'ambre éteint au fond de la fente (il luit pendant le combat : piece_live).
		ci.draw_circle(Vector2(w * 0.17, -h * 0.27), w * 0.18, Color(_m("fletri", "ambre"), 0.5))
		return
	var m: Dictionary = _m("ravive", "mousse")
	O.part(ci, Ink.lumpy(Vector2(-w * 0.4, -h * 0.01), w * 2.4, w * 0.6, 20, 0.2, 7.0, 1.0), m, 1.0, 1.0, 0.4)
	var prev := Vector2(-w * 0.9, -h * 0.03)
	for j in 10:
		var u := (j + 1) / 10.0
		var q := Vector2(-w * 0.9 + sin(u * 8.0) * w * 0.8, -h * 0.48 * u)
		ci.draw_line(prev, q, m["ombre"], 1.4, true)
		O.poly(ci, Ink.leaf(q, PI if j % 2 == 0 else 0.0, w * 0.7, w * 0.35, 0.1), m["clair"] if j % 2 else m["ombre"])
		prev = q
	_crown(ci, top + Vector2(0, -h * 0.26), h * 0.42, h * 0.2, 24, h * 0.085, r, tips)


# --- Ce qui bouge sur les pièces ---


## Pendant le combat : la braise couve dans les fentes des racines (une pièce sur trois) ; le chêne de
## pierre : son cœur d'ambre bat au fond de la fente.
static func piece_live(ci: CanvasItem, key: String, a, i: int) -> void:
	if a.state != "combat":
		return
	var col: Color = Art.bc("braise")
	if key.begins_with("r"):
		var h := 255.0
		var w := h * 0.085
		var pulse := 0.5 + 0.5 * sin(a.t * 3.2 + i)
		var p := Vector2(w * 0.17, -h * 0.27)
		ci.draw_circle(p, w * 0.9, Color(_m("fletri", "ambre"), 0.06 + 0.08 * pulse))
		ci.draw_circle(p, w * 0.22, Color(_m("ravive", "ambre"), 0.5 + 0.4 * pulse))
		return
	if i % 3 != 0:
		return
	var r := _rng(key, 7)
	var box := piece_box(key)
	for j in 3:
		var p := Vector2(r.randf_range(0.3, 0.7) * box.size.x + box.position.x, r.randf_range(0.15, 0.55) * box.position.y)
		var pulse := 0.5 + 0.5 * sin(a.t * 4.0 + i * 1.7 + j * 2.1)
		ci.draw_circle(p, 9.0, Color(col, 0.05 + 0.1 * pulse))
		ci.draw_line(p + Vector2(-1.5, -4.0), p + Vector2(1.5, 4.0), Color(col, 0.4 + 0.5 * pulse), 1.6, true)


# --- Sol : la tranche d'une souche colossale ---


## Sol de l'arène (fixe, redessiné quand l'état change), etat « fletri » ou « ravive ». La clairière est
## la tranche d'une souche immense : une aire de pierre (ou de bois) cernée de terre au pied du mur, des
## cernes en rond autour du cœur, des fentes qui en partent, des racines du mur qui rampent vers le
## dedans ; flétri : la pierre grise veinée d'ocre, la sciure, les éclats ; ravivé : le bois brun chaud,
## la mousse dans les fentes, les feuilles d'or, des champignons et des touffes.
static func ground(ci: CanvasItem, a, etat: String) -> void:
	var c: Vector2 = a.center
	var R: float = a.max_radius
	var r := RandomNumberGenerator.new()
	r.seed = hash([REG, "sol"])
	var live := etat == "ravive"
	var sol: Color = _m(etat, "sol")
	var clair: Color = _m(etat, "sol_clair")
	var sombre: Color = _m(etat, "sol_sombre")
	var bois: Dictionary = _m(etat, "bois")
	var band := PackedVector2Array(O.blob(c, R * 1.0, R * 1.0, 3.0, 0.02, 96))
	band.append(band[0])
	O.poly(ci, O.blob(c, R * 0.96, R * 0.96, 5.0, 0.025, 96), Color(sol.lerp(clair, 0.55), 0.72 if not live else 0.55))
	ci.draw_polyline(band, Color(sombre.darkened(0.3), 0.3), 44.0)
	# La tranche : un disque de bois (ou de pierre) un peu plus clair, bord d'écorce sombre.
	var slab := O.blob(c, R * 0.8, R * 0.78, 11.0, 0.03, 96)
	O.poly(ci, slab, Color(bois["clair"].lerp(sol, 0.55), 0.38 if not live else 0.32))
	var slab_edge := PackedVector2Array(slab)
	slab_edge.append(slab_edge[0])
	ci.draw_polyline(slab_edge, Color(bois["ombre"].darkened(0.3), 0.55), 7.0, true)
	ci.draw_polyline(slab_edge, Color(bois["reflet"], 0.16), 1.5, true)
	# Les cernes, de plus en plus serrés vers l'écorce, un peu décentrés (le cœur n'est pas au milieu).
	var heart := c + Vector2(-R * 0.06, -R * 0.04)
	for k in 9:
		var u := 1.0 - pow(1.0 - (k + 1) / 10.0, 1.4)
		var pts := PackedVector2Array()
		for i in 73:
			var ang := TAU * i / 72.0
			var rad := R * 0.76 * u * (1.0 + 0.025 * O.wave(ang * 3.0, float(k)))
			pts.append(heart.lerp(c, u) + Vector2.from_angle(ang) * rad * Vector2(1.0, 0.98))
		ci.draw_polyline(pts, Color(bois["ombre"], 0.22 + 0.05 * (k % 2)), 1.6 if k % 3 else 2.6, true)
	ci.draw_circle(heart, R * 0.03, Color(bois["ombre"], 0.5))
	# Fentes qui partent du cœur (rayons secs de la souche).
	var fente: Color = _m("fletri", "veine") if not live else _m("ravive", "mousse")["ombre"]
	for i in 9:
		var ang := TAU * i / 9.0 + r.randf_range(-0.2, 0.2)
		var p := heart + Vector2.from_angle(ang) * R * 0.05
		var pts := PackedVector2Array([p])
		var l := R * r.randf_range(0.28, 0.55)
		for j in 8:
			ang += r.randf_range(-0.12, 0.12)
			p += Vector2.from_angle(ang) * l / 8.0
			pts.append(p)
		O.brush(ci, pts, 3.2, Color(_encre_decor(), 0.55), 0.3, 1.0)
		O.brush(ci, pts.slice(1, 6), 1.3, Color(fente, 0.7), 0.2, 1.0)
	# Racines du mur qui rampent vers le dedans.
	for i in 22:
		var ang := TAU * i / 22.0 + r.randf_range(-0.05, 0.05)
		var a0 := c + Vector2.from_angle(ang) * R * 0.97
		var a1 := c + Vector2.from_angle(ang + r.randf_range(-0.08, 0.08)) * R * r.randf_range(0.82, 0.88)
		var pts := O.curve(a0, a0.lerp(a1, 0.5) + Vector2(r.randf_range(-10, 10), r.randf_range(-6, 6)), a1, 6)
		O.brush(ci, pts, 5.0, Color(bois["ombre"], 0.8), 0.0, 1.0)
		O.brush(ci, pts.slice(0, 4), 1.6, Color(bois["reflet"], 0.35), 0.0, 1.0)
	if live:
		_floor_vive(ci, c, R, r)
	else:
		_floor_morte(ci, c, R, r)


static func _floor_morte(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator) -> void:
	var st: Dictionary = _m("fletri", "pierre")
	for i in 46:
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * sqrt(r.randf_range(0.03, 0.88))
		if i % 3 == 0:
			O.pebble(ci, p, r.randf_range(2.5, 5.0), st, float(i))
		elif i % 3 == 1:
			O.poly(ci, Ink.leaf(p, r.randf() * TAU, r.randf_range(6.0, 9.0), 3.0, 0.2), Color(_m("fletri", "feuille" if i % 2 else "feuille_2"), 0.7))
		else:
			# Sciure de pierre.
			for j in 3:
				ci.draw_circle(p + Vector2(r.randf_range(-5, 5), r.randf_range(-2, 2)), r.randf_range(0.8, 1.6), Color(_m("fletri", "cendre"), 0.35))


static func _floor_vive(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator) -> void:
	var mo: Dictionary = _m("ravive", "mousse")
	# Mousse dans les fentes et le long des cernes : de petites plaques, pas de grandes taches.
	for i in 18:
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * sqrt(r.randf_range(0.05, 0.7))
		var rx := R * r.randf_range(0.018, 0.035)
		O.poly(ci, Ink.lumpy(p, rx, rx * 0.5, 22, 0.25, 9.0, p.x), Color(mo["ombre"], 0.4))
		O.poly(ci, Ink.lumpy(p + Vector2(-rx * 0.15, -rx * 0.1), rx * 0.7, rx * 0.32, 20, 0.25, 8.0, p.y), Color(mo["clair"], 0.35))
	var cap: Color = _m("ravive", "fleur_2")
	for i in 50:
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * sqrt(r.randf_range(0.03, 0.88))
		if i % 4 == 0:
			O.poly(ci, Ink.leaf(p, r.randf() * TAU, r.randf_range(7.0, 10.0), 3.4, 0.2), _m("ravive", "feuille" if i % 8 else "feuille_2"))
		elif i % 4 == 1:
			O.tuft(ci, p, r.randf_range(9.0, 14.0), _m("ravive", "touffe"), _m("ravive", "touffe_2"), i)
		elif i % 4 == 2:
			O.flower(ci, p, r.randf_range(3.0, 4.2), _m("ravive", "fleur"), _m("ravive", "fleur_coeur"), r.randf() * TAU)
		else:
			var ct := p + Vector2(0, -5.0)
			ci.draw_line(p, ct, _m("ravive", "cendre"), 1.4, true)
			O.part(ci, Ink.lumpy(ct, 4.0, 2.2, 10, 0.05, 3.0, float(i)), {"clair": cap, "ombre": cap.darkened(0.3), "reflet": cap.lightened(0.4)}, 0.7, 1.0, 0.6)


## Ce qui bouge au sol : pendant le combat, une lueur d'ambre qui court au pied du mur ; quand le mur
## s'est resserré, les sillons qu'il a laissés derrière lui.
static func live(ci: CanvasItem, a) -> void:
	var c: Vector2 = a.center
	if a.radius < a.max_radius - 2.0:
		var mat: Color = _m("fletri", "sol_sombre").darkened(0.35)
		for i in 40:
			var d := Vector2.from_angle(TAU * (i + 0.5) / 40.0)
			ci.draw_line(c + d * (a.radius + 18.0), c + d * (a.max_radius - 6.0), Color(mat, 0.55), 7.0, true)
			ci.draw_line(c + d * (a.radius + 18.0) + d.orthogonal() * 4.0, c + d * (a.max_radius - 6.0) + d.orthogonal() * 4.0, Color(_m("fletri", "sol_clair"), 0.25), 2.0, true)
	if a.state != "combat":
		return
	var col: Color = _m("fletri", "ambre")
	var pulse := 0.5 + 0.5 * sin(a.t * 3.0)
	var pts := PackedVector2Array()
	for i in 97:
		pts.append(c + Vector2.from_angle(TAU * i / 96.0) * (a.radius - 10.0))
	ci.draw_polyline(pts, Color(col, 0.08 + 0.08 * pulse), 26.0, true)
	ci.draw_polyline(pts, Color(col, 0.25 + 0.2 * pulse), 2.5, true)
