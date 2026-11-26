## Arène du Harfang en décor (refonte du monde, vague 3 A2) : l'aire de Vent, un cercle de pierres
## sèches et de menhirs hérissé de plumes, au fond l'aire (le nid) du Harfang sur sa pile de dalles.
## Style des « Paysages d'herbier » (trois quarts, encre fine, lumière haut-gauche, Art.MONDE.vent) ;
## mêmes outils que le décor des plateaux (decor_plateau.gd › P : plumes, membres effilés).
##
## Contrat du moteur (boss_arena.gd, region_art.gd) appelé par region_art/vent.gd :
##   - keys() / piece_box(key) / piece(ci, key, etat) : les pièces cuites (« m0 »… le mur, « r0 » l'aire) ;
##   - piece_live(ci, key, a, i) : runes de braise des menhirs et braises du nid pendant le combat ;
##   - ground(ci, a, etat) : l'aire de roche nue (dalles, spirale de vent gravée, plumes au sol), ou la
##     pelouse rase argentée après la victoire ;
##   - live(ci, a) : rafales qui tournent au pied du mur pendant le combat, sillons du mur resserré.
## Dessin seul : aucune collision, rien du combat ; le hasard est tiré de graines fixes.
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const Plateau = preload("res://scripts/decor_plateau.gd")
const SolVent = preload("res://scripts/world_bake/sol/vent.gd")

## Variantes du mur : les paires portent un menhir, les impaires une pile de pierres plus large.
const MUR_VARIANTES := 6
const REPERES := 1


static func _m(etat: String, key: String):
	return Art.mc("vent", etat, key)


static func keys() -> Array:
	var out := []
	for i in MUR_VARIANTES:
		out.append("m%d" % i)
	for i in REPERES:
		out.append("r%d" % i)
	return out


static func _rng(key: String, salt := 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(["vent", key, 7 + salt])
	return r


static func piece_box(key: String) -> Rect2:
	if key.begins_with("r"):
		return Rect2(-150, -300, 300, 342)
	return Rect2(-92, -150, 184, 178)


## Menhir d'une variante du mur : [pied, demi-largeur, hauteur, penchant] (tiré à part, pour que la
## rune animée tombe au même endroit que la rune cuite).
static func _menhir(v: int) -> Array:
	var r := _rng("m%d" % v, 1)
	var foot := Vector2(r.randf_range(-22.0, 22.0), -6.0)
	return [foot, r.randf_range(15.0, 19.0), r.randf_range(82.0, 104.0), r.randf_range(-9.0, 9.0)]


static func piece(ci: CanvasItem, key: String, etat: String) -> void:
	var r := _rng(key)
	var v := int(key.substr(1))
	if key.begins_with("r"):
		_aire(ci, r, etat)
	else:
		_mur(ci, r, v, etat)


# --- Le mur : pierres sèches et menhirs ---


## Pierre plate posée (dessus éclairé, tranche sombre), centre du dessus en c.
static func _dalle(ci: CanvasItem, c: Vector2, rx: float, ry: float, st: Dictionary, seed: float, rot := 0.0) -> void:
	# Tranche : la même forme, plus bas et plus sombre, puis le dessus.
	O.poly(ci, O.blob(c + Vector2(0, ry * 0.55), rx * 1.02, ry * 1.05, seed, 0.12, 14, rot), Ink.encre())
	O.poly(ci, O.blob(c + Vector2(0, ry * 0.45), rx, ry, seed, 0.12, 14, rot), st["ombre"])
	O.part(ci, O.blob(c, rx, ry, seed, 0.12, 14, rot), st, 1.0, 1.0, 0.5)


## Pan de mur : une pile de dalles de pierre sèche sur un bourrelet de terre, des plumes fichées
## dans les joints, l'herbe couchée par le vent au pied ; une variante sur deux porte un menhir
## gravé d'une rune. Flétri : ardoise, lichen gris, plumes d'ardoise, rune éteinte fendue de braise.
## Ravivé : pierre claire, lichen pâle, herbe argentée à plumets, plumes blanches, fleurs blanches.
static func _mur(ci: CanvasItem, r: RandomNumberGenerator, v: int, etat: String) -> void:
	var st: Dictionary = _m(etat, "pierre")
	var live := etat == "ravive"
	var side := SolVent.side()
	var lichen: Color = _m(etat, "lichen")
	var wide := 1.0 if v % 2 == 0 else 1.18
	O.cast_shadow(ci, Vector2.ZERO, 120.0 * wide, 46.0, 0.3)
	O.poly(ci, O.blob(Vector2(0, 3), 70.0 * wide, 13.0, float(v), 0.15, 24), Color(_m(etat, "sol_sombre"), 0.75))
	# Le menhir, derrière la pile (la pile cache son pied).
	if v % 2 == 0:
		var mh := _menhir(v)
		var foot: Vector2 = mh[0]
		var wid: float = mh[1]
		var hgt: float = mh[2]
		var lean: float = mh[3]
		var pts := _stone(foot, wid, hgt, lean)
		O.part(ci, pts, st, 1.5, 1.0, 0.6)
		# Strates et fissure.
		for i in 3:
			var y := -hgt * (0.3 + 0.2 * i)
			var x := foot.x + lean * (0.3 + 0.2 * i)
			O.brush(ci, PackedVector2Array([Vector2(x - wid * 0.7, y + 2.0), Vector2(x, y), Vector2(x + wid * 0.6, y + 3.0)]), 1.0, Color(st["ombre"], 0.75), 0.0, 0.0)
		# Rune en spirale (le souffle) gravée au milieu.
		var rune := foot + Vector2(lean * 0.55, -hgt * 0.58)
		var sp := PackedVector2Array()
		for j in 12:
			var u := j / 11.0
			sp.append(rune + Vector2.from_angle(u * 4.4 + 0.6) * (1.5 + 6.0 * u) * Vector2(0.9, 1.1))
		O.brush(ci, sp, 1.6, Color(st["ombre"].darkened(0.4), 0.9), 0.0, 0.3)
		if live:
			O.brush(ci, sp, 0.8, Color(_m("ravive", "lueur"), 0.8), 0.0, 0.3)
		else:
			ci.draw_circle(rune, 5.0, Color(Art.bc("braise"), 0.1))
			O.brush(ci, sp.slice(0, 5), 0.8, Color(Art.bc("braise"), 0.7), 0.0, 0.4)
		# Lichen sur le flanc éclairé.
		for i in 3:
			var p := foot + Vector2(-wid * 0.35 + lean * 0.5, -hgt * r.randf_range(0.3, 0.85))
			O.poly(ci, O.blob(p, 3.2, 2.0, p.y, 0.25, 10), Color(lichen, 0.8))
		# Plume fichée au sommet.
		var top := foot + Vector2(lean * 0.6, -hgt * 0.98)
		Plateau.P.feather(ci, top, -PI * 0.5 + side * 0.6, 22.0, etat, side * 0.15)
	# La pile : trois rangs de dalles, du bas vers le haut, de plus en plus courts.
	var y := 0.0
	for row in 3:
		var span := (116.0 - row * 30.0) * wide
		var count := 5 - row
		var ry := 7.5 - row * 0.8
		for k in count:
			var u := (k + 0.5) / count - 0.5
			var c := Vector2(u * span + r.randf_range(-4.0, 4.0), y - ry - r.randf_range(0.0, 2.5))
			var rx := span / count * 0.62 * r.randf_range(0.85, 1.1)
			if row == 2 and k == 1 and v % 3 != 0:
				# Une pierre posée de chant au sommet (le muret n'est pas une pile d'assiettes).
				O.part(ci, _stone(c + Vector2(0, ry), rx * 0.5, rx * 1.1, r.randf_range(-4.0, 4.0)), st, 1.2, 1.0, 0.5)
				continue
			_dalle(ci, c, rx, ry * r.randf_range(0.85, 1.15), st, float(row * 7 + k + v * 13), r.randf_range(-0.12, 0.12))
			if (k + row) % 2 == 0:
				O.poly(ci, O.blob(c + Vector2(-rx * 0.3, -ry * 0.2), rx * 0.28, ry * 0.4, c.x, 0.3, 8), Color(lichen, 0.75))
		y -= ry * 1.75
	# Plumes fichées dans les joints, couchées sous le vent.
	for i in 2 + v % 2:
		var p := Vector2(r.randf_range(-38.0, 38.0) * wide, r.randf_range(-24.0, -8.0))
		Plateau.P.feather(ci, p, -PI * 0.5 + side * r.randf_range(0.5, 0.9), r.randf_range(15.0, 21.0), etat, side * 0.18)
	# Au pied : herbe couchée (sèche), ou herbe argentée à plumets et fleurs blanches.
	var herbe: Dictionary = _m(etat, "herbe")
	for i in 3:
		var foot := Vector2((i - 1) * 52.0 * wide + r.randf_range(-6, 6), r.randf_range(2.0, 6.0))
		O.tuft(ci, foot, r.randf_range(11.0, 15.0), herbe["clair"], herbe["ombre"], v * 5 + i, not live)
	if live:
		for i in 3:
			var p := Vector2(r.randf_range(-0.4, 0.4) * 100.0 * wide, r.randf_range(-30.0, -18.0))
			O.tuft(ci, p, 9.0, herbe["clair"], herbe["reflet"], v * 9 + i)
		for i in 5:
			var p := Vector2(r.randf_range(-55.0, 55.0) * wide, r.randf_range(-32.0, 4.0))
			O.flower(ci, p, r.randf_range(2.6, 3.6), _m("ravive", "fleur" if i % 3 else "fleur_2"), _m("ravive", "fleur_coeur"), r.randf() * TAU)


## Pierre levée (polygone cassé) : pied en « p », demi-largeur wid, hauteur hgt, penchée de lean
## (la même forme que l'ancien mur de region_art/vent.gd).
static func _stone(p: Vector2, wid: float, hgt: float, lean := 0.0) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(-wid, 0), p + Vector2(-wid * 1.05 + lean * 0.5, -hgt * 0.55),
		p + Vector2(-wid * 0.6 + lean, -hgt), p + Vector2(wid * 0.35 + lean, -hgt * 1.04), p + Vector2(wid + lean * 0.6, -hgt * 0.7),
		p + Vector2(wid, 0)])


# --- L'aire du Harfang (repère) ---


## L'aire (repère de Vent) : une pile de grandes dalles, haute comme trois arbres, penchée sous le vent,
## et au sommet le nid du Harfang, un fagot de branches tordues hérissé de grandes plumes. Flétri :
## ardoise, branches mortes, éclats de l'œuf d'orage où couve la braise. Ravivé : pierre claire,
## herbe sur les corniches, nid plein de plumes blanches et de fleurs.
static func _aire(ci: CanvasItem, r: RandomNumberGenerator, etat: String) -> void:
	var st: Dictionary = _m(etat, "pierre")
	var bois: Dictionary = _m(etat, "bois")
	var live := etat == "ravive"
	var side := SolVent.side()
	var h := 236.0
	O.cast_shadow(ci, Vector2.ZERO, h * 0.55, h * 0.8, 0.34)
	# Éboulis au pied.
	for i in 6:
		var p := Vector2((i - 2.5) * h * 0.11 + r.randf_range(-4, 4), r.randf_range(-2.0, 8.0))
		_dalle(ci, p, h * r.randf_range(0.05, 0.075), h * 0.025, st, float(i) * 2.3)
	# La pile : sept dalles de plus en plus étroites, décalées sous le vent.
	var stack := _stack()
	for i in stack.size() - 1:
		var sl: Array = stack[i]
		var c: Vector2 = sl[0]
		var rx: float = sl[1]
		var ry: float = sl[2]
		var thick: float = sl[3]
		# Une dalle épaisse : la tranche haute fait la paroi.
		var face := PackedVector2Array()
		for j in 13:
			var a := PI * j / 12.0
			face.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		for j in 13:
			var a := PI - PI * j / 12.0
			face.append(c + Vector2(cos(a) * rx * 0.98, sin(a) * ry + thick))
		O.part(ci, face, {"clair": st["ombre"], "ombre": st["ombre"].darkened(0.3), "reflet": st["clair"]}, 1.3, 0.8, 0.2)
		O.part(ci, O.blob(c, rx, ry, float(i) * 3.7, 0.08, 20, r.randf_range(-0.05, 0.05)), st, 1.3, 1.0, 0.5)
		if i % 2 == 1:
			O.poly(ci, O.blob(c + Vector2(-rx * 0.35, 0), rx * 0.22, ry * 0.4, c.x, 0.3, 10), Color(_m(etat, "lichen"), 0.8))
		if live and i % 3 == 1:
			for k in 2:
				O.tuft(ci, c + Vector2((k * 2 - 1) * rx * 0.6, ry * 0.3), 12.0, _m(etat, "herbe")["clair"], _m(etat, "herbe")["ombre"], i * 3 + k)
	var top: Vector2 = stack[stack.size() - 1]
	# Le nid : un fagot de branches en couronne, l'arrière d'abord.
	var nest := top + Vector2(0, -h * 0.03)
	var nw := h * 0.24
	for pass_ in 2:
		for i in 9:
			var a0 := PI * (1.0 + i / 8.0) if pass_ == 0 else PI * (i / 8.0)
			var p0 := nest + Vector2(cos(a0) * nw, sin(a0) * nw * 0.32)
			var p1 := nest + Vector2(cos(a0 + 0.9) * nw * 1.05, sin(a0 + 0.9) * nw * 0.34 - h * 0.02)
			var mid := p0.lerp(p1, 0.5) + Vector2(0, -h * r.randf_range(0.02, 0.05))
			O.part(ci, Plateau.P.limb_poly(O.curve(p0, mid, p1, 5), h * 0.026, h * 0.012), bois, 0.9, 1.0, 0.2)
		if pass_ == 0:
			# Le creux du nid, puis ce qu'il garde.
			O.poly(ci, O.blob(nest + Vector2(0, -h * 0.01), nw * 0.8, nw * 0.22, 2.0, 0.1, 22), Color(Ink.encre(), 0.85))
			if live:
				for k in 5:
					Plateau.P.feather(ci, nest + Vector2((k - 2) * nw * 0.28, -h * 0.005), -PI * 0.5 + (k - 2) * 0.35 + side * 0.2, h * 0.14, etat, side * 0.1)
			else:
				var orage := {"clair": _m("fletri", "orage_reflet"), "ombre": _m("fletri", "orage"), "reflet": _m("fletri", "orage_reflet").lightened(0.2)}
				for k in 3:
					var p := nest + Vector2((k - 1) * nw * 0.42, -h * 0.02)
					var sh := PackedVector2Array([p + Vector2(-10, 4), p + Vector2(-6, -12), p + Vector2(0, -7), p + Vector2(5, -15), p + Vector2(9, 4)])
					O.part(ci, sh, orage, 1.0, 1.0, 0.6)
					ci.draw_circle(p + Vector2(0, -3), 9.0, Color(Art.bc("braise"), 0.12))
					ci.draw_line(p + Vector2(-2, -1), p + Vector2(2, -9), Art.bc("braise"), 1.4, true)
	# Grandes plumes fichées tout autour du nid, couchées sous le vent.
	for i in 7:
		var u := (i + 0.5) / 7.0 - 0.5
		var b := nest + Vector2(u * nw * 2.0, h * 0.01 - absf(u) * 4.0)
		Plateau.P.feather(ci, b, -PI * 0.5 + u * 1.6 + side * 0.35, h * r.randf_range(0.16, 0.22), etat, side * 0.15)
	if live:
		for i in 9:
			var p := Vector2(r.randf_range(-0.22, 0.22) * h, -h * r.randf_range(0.05, 0.8))
			O.flower(ci, p, r.randf_range(3.0, 4.2), _m("ravive", "fleur" if i % 3 else "fleur_2"), _m("ravive", "fleur_coeur"), r.randf() * TAU)
		for i in 4:
			O.tuft(ci, Vector2((i - 1.5) * h * 0.14, 4.0), 14.0, _m(etat, "herbe")["clair"], _m(etat, "herbe")["reflet"], 40 + i)
	else:
		for i in 4:
			O.tuft(ci, Vector2((i - 1.5) * h * 0.14, 4.0), 13.0, _m(etat, "herbe")["clair"], _m(etat, "herbe")["ombre"], 40 + i, true)


## La pile de l'aire : [[centre du dessus, demi-largeur, demi-hauteur, épaisseur]…, sommet], tirée à
## part (le nid animé tombe ainsi au même endroit que le nid cuit).
static func _stack() -> Array:
	var r := _rng("r0", 2)
	var h := 236.0
	var side := SolVent.side()
	var out := []
	var y := 0.0
	var top := Vector2.ZERO
	var n := 7
	for i in n:
		var u := float(i) / n
		var rx := h * (0.25 - 0.12 * u) * r.randf_range(0.8, 1.12)
		var ry := h * (0.056 - 0.014 * u) * r.randf_range(0.85, 1.15)
		var c := Vector2(side * h * 0.1 * u * u + r.randf_range(-0.04, 0.04) * h, y - ry)
		var thick := h * (0.075 - 0.025 * u) * r.randf_range(0.7, 1.3)
		out.append([c, rx, ry, thick])
		y -= ry * 1.2 + thick * 0.55
		top = c + Vector2(0, -ry)
	out.append(top)
	return out


## Le nid (haut de l'aire), pour les braises animées.
static func _nest_at() -> Vector2:
	var st := _stack()
	return st[st.size() - 1] + Vector2(0, -236.0 * 0.03)


# --- Ce qui bouge sur les pièces ---


## Pendant le combat : la rune des menhirs bat comme une braise, et des braises montent du nid.
## Une pièce sur trois seulement (redessinées 15 fois par seconde).
static func piece_live(ci: CanvasItem, key: String, a, i: int) -> void:
	if a.state != "combat" or i % 3 != 0:
		return
	var glow: Color = Art.ec("cendre", "clair")
	if key.begins_with("r"):
		var nest := _nest_at()
		for j in 5:
			var u := fposmod(a.t * 0.35 + j * 0.2, 1.0)
			var p := nest + Vector2(sin(a.t * 2.0 + j * 1.3) * 18.0 + (j - 2) * 14.0, -u * 70.0)
			ci.draw_circle(p, 2.0 + 1.5 * (1.0 - u), Color(Art.bc("braise"), 0.9 * (1.0 - u)))
		return
	var v := int(key.substr(1))
	if v % 2 != 0:
		return
	var mh := _menhir(v)
	var rune: Vector2 = mh[0] + Vector2(float(mh[3]) * 0.55, -float(mh[2]) * 0.58)
	var pulse := 0.5 + 0.5 * sin(a.t * 5.0 + i * 1.3)
	ci.draw_circle(rune, 12.0, Color(glow, 0.08 + 0.1 * pulse))
	var sp := PackedVector2Array()
	for j in 12:
		var u := j / 11.0
		sp.append(rune + Vector2.from_angle(u * 4.4 + 0.6) * (1.5 + 6.0 * u) * Vector2(0.9, 1.1))
	ci.draw_polyline(sp, Color(glow, 0.55 + 0.4 * pulse), 1.6, true)


# --- Sol ---


## L'aire de roche (fixe, redessinée quand l'état change) : une table de roche nue qui affleure, en
## dalles jointives, gravée d'une spirale de vent (les sillons que creusent les bourrasques du
## Harfang), semée de plumes et cernée d'un bourrelet d'herbe couchée et de cailloux au pied du mur.
## Ravivée : la roche s'éclaircit, l'herbe argentée gagne les joints, plumes blanches et fleurs.
static func ground(ci: CanvasItem, a, etat: String) -> void:
	var c: Vector2 = a.center
	var R: float = a.max_radius
	var r := RandomNumberGenerator.new()
	r.seed = hash(["vent", "sol"])
	var live := etat == "ravive"
	var sol: Color = _m(etat, "sol")
	var clair: Color = _m(etat, "sol_clair")
	var sombre: Color = _m(etat, "sol_sombre")
	var st: Dictionary = _m(etat, "pierre")
	# Une seule grande surface (le rendu logiciel paie chaque couche) : la table de roche, puis la
	# couronne d'herbe et de terre au pied du mur.
	O.poly(ci, O.blob(c, R * 0.96, R * 0.96, 5.0, 0.025, 96), Color(st["ombre"].lerp(sol, 0.45), 0.8) if not live else Color(sol.lerp(sombre, 0.3), 0.55))
	var band := O.blob(c, R * 1.0, R * 1.0, 3.0, 0.02, 96)
	band.append(band[0])
	ci.draw_polyline(band, Color(sombre.darkened(0.3), 0.32), 44.0)
	# Dalles : des plaques plates et cassées, éclairées en haut à gauche, joints sombres.
	for i in 30:
		var ang := r.randf() * TAU
		var d := R * sqrt(r.randf_range(0.0, 0.78))
		var p := c + Vector2.from_angle(ang) * d
		var rx := R * r.randf_range(0.06, 0.13)
		var pts := O.blob(p, rx, rx * r.randf_range(0.45, 0.7), float(i), 0.3, 6, r.randf() * PI)
		O.poly(ci, pts, Color(clair.lerp(st["clair"], 0.3), 0.16 if not live else 0.2))
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, Color(sombre.darkened(0.5), 0.3), 1.6, true)
		ci.draw_line(pts[3], pts[4], Color(st["reflet"], 0.14), 2.0, true)
	# La spirale de vent : trois bras de sillons clairs, du centre vers le mur.
	var air: Color = _m(etat, "cendre")
	for arm in 3:
		var pts := PackedVector2Array()
		for j in 40:
			var u := j / 39.0
			var ang := arm * TAU / 3.0 + u * 3.6
			pts.append(c + Vector2.from_angle(ang) * R * (0.05 + 0.8 * u))
		O.brush(ci, pts, 7.0, Color(sombre.darkened(0.45), 0.4), 0.6, 0.9)
		O.brush(ci, Transform2D(0.0, Vector2(-2, -3)) * pts, 3.0, Color(air, 0.22 if not live else 0.4), 0.6, 0.9)
	# Liseré du bord intérieur : on voit de loin où commence l'aire.
	var rim := O.blob(c, R * 0.96, R * 0.96, 5.0, 0.025, 96)
	rim.append(rim[0])
	ci.draw_polyline(rim, Color(sombre.darkened(0.45), 0.55), 5.0, true)
	# Herbe couchée et cailloux au pied du mur.
	var herbe: Dictionary = _m(etat, "herbe")
	var side := SolVent.side()
	for i in 70:
		var ang := TAU * i / 70.0 + r.randf_range(-0.03, 0.03)
		var p := c + Vector2.from_angle(ang) * R * r.randf_range(0.86, 0.95)
		if i % 3 == 0:
			O.pebble(ci, p, r.randf_range(4.0, 7.0), st, float(i))
		else:
			for k in 4:
				var b := p + Vector2(k * 3.0 - 4.5, 0)
				O.brush(ci, PackedVector2Array([b, b + Vector2(side * 9.0, -6.0), b + Vector2(side * 18.0, -4.0)]), 2.0, herbe["clair"] if k % 2 else herbe["ombre"], 0.0, 1.0)
	# Plumes au sol, et (ravivé) touffes argentées, fleurs blanches.
	for i in 34:
		var ang := r.randf() * TAU
		var p := c + Vector2.from_angle(ang) * R * sqrt(r.randf_range(0.02, 0.75))
		if i % 3 == 0:
			Plateau.P.feather(ci, p, r.randf() * TAU, r.randf_range(14.0, 22.0), etat, r.randf_range(-0.2, 0.2))
		elif live:
			if i % 2 == 0:
				O.tuft(ci, p, r.randf_range(12.0, 18.0), herbe["clair"], herbe["reflet"], i)
			else:
				for k in 3:
					O.flower(ci, p + Vector2(k * 7.0 - 7.0, (k % 2) * 4.0), 4.0, _m("ravive", "fleur" if k != 1 else "fleur_2"), _m("ravive", "fleur_coeur"), k * 1.7)
		else:
			O.pebble(ci, p, r.randf_range(3.0, 5.5), st, float(i) + 0.5)


## Ce qui bouge au sol : pendant le combat, des rafales qui tournent au pied du mur (le Harfang
## brasse l'air) et un liseré qui bat ; quand le mur s'est resserré, les sillons qu'il a laissés.
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
	var col: Color = Art.ec("vent", "clair")
	var pulse := 0.5 + 0.5 * sin(a.t * 3.0)
	var rr: float = a.radius - 14.0
	# Six rafales : des arcs effilés qui filent le long du mur.
	for k in 6:
		var a0: float = a.t * 1.3 + k * TAU / 6.0
		var pts := PackedVector2Array()
		for j in 10:
			var u := j / 9.0
			pts.append(c + Vector2.from_angle(a0 + u * 0.55) * (rr - 22.0 * sin(PI * u) - (k % 2) * 30.0))
		O.brush(ci, pts, 4.0, Color(col, 0.35 + 0.2 * pulse), 1.0, 0.0)
	ci.draw_arc(c, rr, 0.0, TAU, 72, Color(col, 0.12 + 0.12 * pulse), 2.0, true)
