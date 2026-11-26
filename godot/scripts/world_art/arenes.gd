## Arènes des boss en décor (refonte du monde, vague 3 A) : le mur, le sol et le repère de l'arène du
## Roncier (la Mère-Ronce) et de celle du Marais (l'Amanite-Mère), dans le style des « Paysages
## d'herbier » (trois quarts, encre fine, lumière haut-gauche, palettes Art.MONDE).
##
## Le moteur (boss_arena.gd) pose le mur en pièces dans le calque trié en profondeur (comme les pierres
## du sanctuaire) et les fait cuire par lieux_bake.gd (jeux « arene/<région>/<état> ») ; il demande ici :
##   - piece(ci, reg, key, etat)   : une pièce, pied en (0, 0), « fletri » ou « ravive » (partie cuite) ;
##   - piece_box(reg, key)         : sa place autour du pied (pixels du monde) ;
##   - piece_live(ci, reg, key, a, i) : ce qui bouge sur la pièce (braises ou poison pendant le combat) ;
##   - ground(ci, a, reg, etat)    : le sol de l'arène (redessiné seulement quand l'état change) ;
##   - live(ci, a, reg)            : ce qui bouge au sol (lueurs du combat, sillons du mur qui se resserre).
## Clés des pièces : « m0 »… (le mur, MUR_VARIANTES variantes, retournées au hasard) et « r0 »… (le repère
## qui dépasse du mur, au fond de l'arène, pour l'annoncer de loin).
##
## Dessin seul : aucune collision, rien du combat ; le hasard est tiré de graines fixes.
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const Decor = preload("res://scripts/world_art/decor.gd")

const MUR_VARIANTES := 6
const REPERES := 1


## Palette du décor d'une région dans un état (comme Decor.draw : la région, sinon commun, sinon ronce).
static func _P(reg: String, etat: String) -> Callable:
	return func(key: String) -> Dictionary:
		var src := "ravive" if etat == "ravive" else "fletri"
		if Art.MONDE[reg][src].has(key):
			return Art.mc(reg, src, key)
		if Art.MONDE["commun"].has(key):
			return Art.mc("commun", "", key)
		return Art.mc("ronce", src, key)


static func keys(reg: String) -> Array:
	var out := []
	for i in MUR_VARIANTES:
		out.append("m%d" % i)
	for i in REPERES:
		out.append("r%d" % i)
	return out


static func _rng(reg: String, key: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([reg, key, 3])
	return r


static func piece_box(reg: String, key: String) -> Rect2:
	var repere := key.begins_with("r")
	if reg == "spore":
		return Rect2(-160, -275, 320, 345) if repere else Rect2(-92, -130, 190, 166)
	return Rect2(-178, -288, 356, 340) if repere else Rect2(-118, -160, 236, 196)


static func piece(ci: CanvasItem, reg: String, key: String, etat: String) -> void:
	var r := _rng(reg, key)
	var v := int(key.substr(1))
	if reg == "spore":
		if key.begins_with("r"):
			_spore_repere(ci, r, v, etat)
		else:
			_spore_mur(ci, r, v, etat)
	else:
		if key.begins_with("r"):
			_ronce_repere(ci, r, v, etat)
		else:
			_ronce_mur(ci, r, v, etat)


# --- Roncier : un mur de ronces vivant ---


## Grosse tige de ronce en arceau : encre, ombre, filet clair, épines larges ; t0/t1 : effilée aux bouts.
static func _cane(ci: CanvasItem, pts: PackedVector2Array, w: float, ron: Dictionary, thorn: float, r: RandomNumberGenerator, t1 := 0.8) -> void:
	O.brush(ci, pts, w + 2.2, Ink.encre(), 0.0, t1)
	O.brush(ci, pts, w, ron["ombre"], 0.0, t1)
	O.brush(ci, pts, w * 0.38, ron["clair"], 0.0, t1)
	var n := pts.size()
	for j in range(1, n - 1, 2):
		var d := (pts[j + 1] - pts[j - 1]).normalized()
		var side := 1.0 if (j + int(r.randi() % 2)) % 2 == 0 else -1.0
		var sz := thorn * (1.0 - 0.5 * float(j) / n)
		O.poly(ci, Ink.thorn(pts[j], d.angle() + side * (PI * 0.5 - 0.5), sz, sz * 0.45), Ink.encre())


## Arceau de a à b, sommet à « hauteur » h au-dessus du plus haut des deux, penché de lean.
static func _arch(a: Vector2, b: Vector2, h: float, lean := 0.0, n := 12) -> PackedVector2Array:
	var top := a.lerp(b, 0.45 + lean) + Vector2(0, -h)
	return O.curve(a, top, b, n)


## Pan de mur du Roncier : un bourrelet de terre retournée, une haie de ronces serrées (Decor._haie,
## le même dessin que les lisières) et de grosses tiges en arceaux qui la dominent, hérissées d'épines.
## Flétri : tiges noires et rouge sombre, feuilles mortes, braise au creux. Ravivé : tiges vertes,
## feuilles, églantines et mûres.
static func _ronce_mur(ci: CanvasItem, r: RandomNumberGenerator, v: int, etat: String) -> void:
	var P := _P("ronce", etat)
	var ron: Dictionary = P.call("ronce")
	var h := 80.0 * r.randf_range(0.92, 1.08)
	O.cast_shadow(ci, Vector2.ZERO, h * 0.9, h * 0.4, 0.3)
	# Tiges de l'arrière : de grands arceaux qui montent au-dessus de la haie.
	for i in 2:
		var a := Vector2(r.randf_range(-0.62, -0.15) * h, r.randf_range(-4, 0))
		var b := Vector2(r.randf_range(0.2, 0.62) * h, r.randf_range(-6, 0))
		_cane(ci, _arch(a, b, h * r.randf_range(1.0, 1.25), r.randf_range(-0.15, 0.15)), 4.2, ron, 7.0, r)
	_masse(ci, h, r, P, etat)
	# Tiges de l'avant : un arceau bas, une pousse dressée.
	var a2 := Vector2(r.randf_range(-0.6, -0.1) * h, 2)
	_cane(ci, _arch(a2, a2 + Vector2(h * r.randf_range(0.55, 0.75), -h * 0.1), h * 0.7, 0.1), 3.6, ron, 6.0, r)
	var b2 := Vector2(r.randf_range(-0.3, 0.4) * h, 0)
	var tip := b2 + Vector2(r.randf_range(-0.3, 0.3) * h, -h * r.randf_range(1.25, 1.45))
	_cane(ci, O.curve(b2, b2.lerp(tip, 0.5) + Vector2(r.randf_range(-12, 12), 0), tip, 10), 3.4, ron, 6.0, r, 1.0)
	if etat == "ravive":
		var leaf: Dictionary = P.call("feuillage")
		for i in 6:
			var p := tip.lerp(b2, r.randf_range(0.1, 0.7)) + Vector2(r.randf_range(-6, 6), 0)
			O.part(ci, Ink.leaf(p, r.randf_range(-PI, 0.0), 11.0, 5.0, 0.12), leaf, 0.8, 1.0, 0.5)
		O.flower(ci, tip + Vector2(0, 3), 6.5, Art.mc("ronce", "ravive", "fleur"), Art.mc("ronce", "ravive", "fleur_coeur"), float(v))
		for i in 3:
			var p := Vector2(r.randf_range(-0.6, 0.6) * h, -h * r.randf_range(0.4, 0.8))
			O.flower(ci, p, r.randf_range(4.5, 6.0), Art.mc("ronce", "ravive", "fleur_2" if i == 1 else "fleur"), Art.mc("ronce", "ravive", "fleur_coeur"), r.randf() * TAU)
	else:
		# Feuilles mortes accrochées aux tiges et une braise au creux de la haie.
		for i in 4:
			var p := tip.lerp(b2, r.randf_range(0.2, 0.8))
			O.part(ci, Ink.leaf(p, r.randf_range(0.6, 2.4), 8.0, 3.6, 0.2), {"clair": Art.mc("ronce", "fletri", "feuille"), "ombre": Art.mc("ronce", "fletri", "feuille").darkened(0.35)}, 0.6, 1.0, 0.0)
		var e := Vector2(r.randf_range(-0.3, 0.3) * h, -h * 0.28)
		ci.draw_circle(e, 7.0, Color(Art.bc("braise"), 0.14))
		ci.draw_circle(e, 2.0, Art.bc("braise"))


## Masse feuillue serrée de la haie (comme Decor._haie, sans ses longues tiges qui débordent : le mur
## en a déjà, et chaque pixel de large compte au rendu).
static func _masse(ci: CanvasItem, h: float, r: RandomNumberGenerator, P: Callable, etat: String) -> void:
	var leaf: Dictionary = P.call("feuillage")
	var w := h * 1.35
	var masses := []
	for i in 8:
		var u := r.randf_range(-1.0, 1.0)
		var c := Vector2(u * w * 0.4, -h * (0.16 + 0.3 * (1.0 - u * u)) - r.randf_range(0, h * 0.1))
		masses.append([c, h * r.randf_range(0.17, 0.24)])
	masses.sort_custom(func(x, y): return x[0].y < y[0].y)
	for ms in masses:
		O.part(ci, Ink.lumpy(ms[0], ms[1] * 1.2, ms[1], 22, 0.18, 9.0, ms[0].x * 0.1), leaf, 1.3, 1.0, 0.5)
		for j in 3:
			var a := PI * (1.1 + 0.3 * j)
			var p: Vector2 = ms[0] + Vector2(cos(a), sin(a)) * ms[1] * Vector2(1.15, 0.95)
			O.poly(ci, Ink.leaf(p, a, ms[1] * 0.45, ms[1] * 0.25), leaf["clair"])
	if etat == "ravive":
		for i in 9:
			var ms: Array = masses[r.randi() % masses.size()]
			var p: Vector2 = ms[0] + Vector2(r.randf_range(-1.0, 1.0) * ms[1], r.randf_range(-0.8, 0.4) * ms[1])
			if i % 3 == 0:
				for b in 3:
					ci.draw_circle(p + Vector2(b * 2.2 - 2.2, (b % 2) * 1.8), 1.9, Art.mc("ronce", "ravive", "fruit"))
				ci.draw_circle(p + Vector2(-2.6, -0.8), 0.7, Color(1, 1, 1, 0.5))
			else:
				O.flower(ci, p, r.randf_range(2.8, 4.0), Art.mc("ronce", "ravive", "fleur" if i % 4 else "fleur_2"), Art.mc("ronce", "ravive", "fleur_coeur"), r.randf() * TAU)


## La ronce-mère (repère du Roncier) : un nœud de tiges énormes qui montent en spirale bien au-dessus du
## mur et retombent en arceaux, un gros bouton fendu de braise à la pointe (une églantine ouverte une
## fois l'arène vaincue). On la voit de loin.
static func _ronce_repere(ci: CanvasItem, r: RandomNumberGenerator, v: int, etat: String) -> void:
	var P := _P("ronce", etat)
	var ron: Dictionary = P.call("ronce")
	var h := 250.0 * (1.0 if v == 0 else 0.82)
	O.cast_shadow(ci, Vector2.ZERO, h * 0.5, h * 0.35, 0.34)
	# Arceaux qui retombent de part et d'autre.
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var a := Vector2(side * r.randf_range(0.04, 0.12) * h, 0)
		var b := Vector2(side * r.randf_range(0.42, 0.62) * h, r.randf_range(-4, 4))
		_cane(ci, _arch(a, b, h * r.randf_range(0.42, 0.62), -0.1 * side), 6.0, ron, 10.0, r)
	Decor._haie(ci, Vector2(0, 4), h * 0.4, 1.0, r, P, etat, "ronce", 0.0)
	# Trois tiges maîtresses qui s'enroulent et montent.
	var top := Vector2(h * 0.04 * (1 if v == 0 else -1), -h)
	var tops := []
	for i in 3:
		var pts := PackedVector2Array()
		var a0 := TAU * i / 3.0
		var end := top + Vector2((i - 1) * h * 0.11, h * 0.08 * absf(i - 1))
		for j in 17:
			var u := j / 16.0
			var rad := h * (0.09 - 0.05 * u)
			var ang := a0 + u * 4.2
			pts.append(Vector2.ZERO.lerp(end, u) + Vector2(cos(ang) * rad, sin(ang) * rad * 0.3))
		_cane(ci, pts, 10.0 - 2.0 * i, ron, 13.0, r, 0.7)
		tops.append(end)
	# La pointe : le bouton (cynorhodon) fendu de braise, ou l'églantine ouverte.
	var bud := top + Vector2(0, -h * 0.04)
	if etat == "ravive":
		var leaf: Dictionary = P.call("feuillage")
		for i in 6:
			var a := PI * (1.0 + i / 5.0)
			O.part(ci, Ink.leaf(bud + Vector2(0, h * 0.02), a, h * 0.1, h * 0.05, 0.1), leaf, 1.0, 1.0, 0.6)
		var petal := {"clair": Art.mc("ronce", "ravive", "fleur"), "ombre": Art.mc("ronce", "ravive", "fleur").darkened(0.25), "reflet": Color("fff0f2")}
		for i in 5:
			var a := -PI * 0.5 + TAU * i / 5.0
			var p := bud + Vector2(cos(a) * h * 0.06, sin(a) * h * 0.035)
			O.part(ci, Ink.lumpy(p, h * 0.06, h * 0.043, 16, 0.12, 2.0, a), petal, 1.0, 1.0, 0.9)
		ci.draw_circle(bud, h * 0.025, Art.mc("ronce", "ravive", "fleur_coeur"))
		for i in 14:
			var p := Vector2(r.randf_range(-0.5, 0.5) * h, -h * r.randf_range(0.15, 0.6))
			O.flower(ci, p, r.randf_range(5.0, 7.5), Art.mc("ronce", "ravive", "fleur" if i % 3 else "fleur_2"), Art.mc("ronce", "ravive", "fleur_coeur"), r.randf() * TAU)
	else:
		var pal := {"clair": Art.bc("ronce", "clair"), "ombre": Art.bc("ronce", "ombre"), "reflet": Art.bc("ronce", "reflet")}
		O.part(ci, Ink.lumpy(bud, h * 0.07, h * 0.085, 26, 0.06, 6.0), pal, 1.6, 1.0, 1.0)
		for i in 5:
			var a := -PI * 0.5 + (i - 2) * 0.45
			O.part(ci, Ink.leaf(bud + Vector2(0, -h * 0.075), a, h * 0.05, h * 0.02, 0.15), {"clair": Color("5a4a2e"), "ombre": Color("33281a")}, 0.8, 1.0, 0.0)
		for i in 2:
			var from := bud + Vector2((i - 0.5) * h * 0.04, -h * 0.05)
			var pts := PackedVector2Array([from])
			var p := from
			for j in 4:
				p += Vector2(r.randf_range(-3, 3), h * 0.025)
				pts.append(p)
			ci.draw_polyline(pts, Color(Art.bc("braise"), 0.3), 4.0, true)
			ci.draw_polyline(pts, Art.bc("braise"), 1.5, true)
		# Feuilles mortes et braises piquées dans le nœud.
		for i in 6:
			var p := Vector2(r.randf_range(-0.3, 0.3) * h, -h * r.randf_range(0.15, 0.75))
			ci.draw_circle(p, 6.0, Color(Art.bc("braise"), 0.12))
			ci.draw_circle(p, 1.8, Art.bc("braise"))


# --- Marais : un rond de sorcière ---


## Vesse-de-loup : boule gonflée sur le mycélium (craquelée de braise flétrie, pâle et piquée de lueurs
## ravivée).
static func _vesse(ci: CanvasItem, p: Vector2, s: float, etat: String, seed: float) -> void:
	var pal: Dictionary = Art.mc("spore", etat if etat == "ravive" else "fletri", "pied" if etat == "ravive" else "chapeau")
	O.poly(ci, O.blob(p + Vector2(s * 0.35, s * 0.15), s * 1.1, s * 0.35, seed, 0.1, 14), Color(0, 0, 0, 0.25))
	O.part(ci, Ink.lumpy(p + Vector2(0, -s * 0.8), s, s * 0.85, 22, 0.05, 5.0, seed), pal, 1.2, 1.0, 0.7)
	if etat == "ravive":
		for i in 4:
			var a := PI * (1.15 + 0.2 * i)
			ci.draw_circle(p + Vector2(cos(a) * s * 0.55, -s * 0.8 + sin(a) * s * 0.4), 1.4, Color(Art.mc("spore", "ravive", "lueur"), 0.9))
	else:
		var top := p + Vector2(-s * 0.2, -s * 1.3)
		ci.draw_polyline(PackedVector2Array([top, top + Vector2(s * 0.2, s * 0.4), top + Vector2(s * 0.1, s * 0.8)]), Art.bc("braise"), 1.2, true)


## Pan de mur du Marais : un tapis de mycélium au sol d'où sort une touffe de champignons de toutes
## tailles (Decor._champignon, le même dessin que le décor) et deux ou trois vesses-de-loup.
static func _spore_mur(ci: CanvasItem, r: RandomNumberGenerator, v: int, etat: String) -> void:
	var P := _P("spore", etat)
	var myc: Color = Art.mc("spore", etat, "cendre")
	O.cast_shadow(ci, Vector2.ZERO, 90.0, 50.0, 0.28)
	O.poly(ci, O.blob(Vector2(0, 1), 60.0, 8.0, float(v), 0.2, 26), Color(Art.mc("spore", etat, "sol_sombre"), 0.6))
	for i in 9:
		var a := r.randf_range(-PI, PI)
		var p0 := Vector2(r.randf_range(-40, 40), r.randf_range(-3, 4))
		var p1 := p0 + Vector2(cos(a) * 38.0, sin(a) * 9.0)
		ci.draw_polyline(O.curve(p0, p0.lerp(p1, 0.5) + Vector2(0, r.randf_range(-5, 5)), p1, 6), Color(myc, 0.45), 1.1, true)
	var stems := []
	var n := 3 + v % 2
	for i in n:
		var u := (float(i) / maxf(1.0, n - 1)) * 2.0 - 1.0
		stems.append([Vector2(u * 34.0 + r.randf_range(-8, 8), r.randf_range(-6, 3)), r.randf_range(48.0, 92.0) * (1.0 - 0.3 * absf(u))])
	stems.sort_custom(func(x, y): return x[0].y < y[0].y)
	for s in stems:
		var rr := RandomNumberGenerator.new()
		rr.seed = r.randi()
		Decor._champignon(ci, s[0], s[1], 1.0 if rr.randf() < 0.5 else -1.0, rr, P, etat, 0.0, false)
	for i in 2 + v % 2:
		_vesse(ci, Vector2(r.randf_range(-55, 55), r.randf_range(2, 9)), r.randf_range(7.0, 12.0), etat, float(i + v))


## Le chapeau géant (repère du Marais), au fond du rond : le même que celui des lisières (Decor), plus
## grand et cerné de petits chapeaux.
static func _spore_repere(ci: CanvasItem, r: RandomNumberGenerator, v: int, etat: String) -> void:
	var P := _P("spore", etat)
	var h := 250.0 if v == 0 else 190.0
	O.cast_shadow(ci, Vector2.ZERO, h * 0.5, h * 0.45, 0.34)
	Decor._chapeau_geant(ci, Vector2.ZERO, h, 1.0 if v == 0 else -1.0, r, P, etat, 0.0)
	for i in 3:
		var rr := RandomNumberGenerator.new()
		rr.seed = r.randi()
		Decor._champignon(ci, Vector2((i - 1) * h * 0.32, h * 0.03 + (i % 2) * 6.0), h * rr.randf_range(0.14, 0.22), 1.0, rr, P, etat, 0.0, false)


# --- Ce qui bouge sur les pièces ---


## Pendant le combat : braises au creux des ronces, ou poison
## qui luit sous les chapeaux. a : l'arène (t, state), i : rang de la pièce.
static func piece_live(ci: CanvasItem, reg: String, key: String, a, i: int) -> void:
	# Une pièce sur trois seulement (redessinées 15 fois par seconde pendant le combat).
	if a.state != "combat" or i % 3 != 0:
		return
	var fight := true
	var r := _rng(reg, key + "live")
	var box := piece_box(reg, key)
	var n := 3 if key.begins_with("m") else 6
	var col: Color = Art.ec("poison", "clair") if reg == "spore" else Art.bc("braise")
	var k := 1.0 if fight else 0.35
	for j in n:
		var p := Vector2(r.randf_range(0.25, 0.75) * box.size.x + box.position.x, r.randf_range(0.35, 0.8) * box.position.y)
		var pulse := 0.5 + 0.5 * sin(a.t * (4.0 if fight else 1.6) + i * 1.7 + j * 2.1)
		ci.draw_circle(p, 9.0, Color(col, (0.05 + 0.1 * pulse) * k))
		ci.draw_circle(p, 2.2, Color(col, (0.4 + 0.5 * pulse) * k))


# --- Sol ---


## Sol de l'arène (fixe, redessiné quand l'état change) : etat « fletri » (fermée, ouverte, combat) ou
## « ravive » (vaincue). Roncier : une aire de terre battue, cernée de terre retournée au pied du mur,
## des sentiers usés en rond, des fentes de braise qui partent du centre. Marais : une vase sombre en
## rond de sorcière, des flaques, un cercle de poussière de spores. Ravivés : prairie fleurie, mousse
## turquoise et petits chapeaux.
static func ground(ci: CanvasItem, a, reg: String, etat: String) -> void:
	var c: Vector2 = a.center
	var R: float = a.max_radius
	var r := RandomNumberGenerator.new()
	r.seed = hash([reg, "sol"])
	var live := etat == "ravive"
	var sol: Color = Art.mc(reg, etat, "sol")
	var clair: Color = Art.mc(reg, etat, "sol_clair")
	var sombre: Color = Art.mc(reg, etat, "sol_sombre")
	# Une seule grande surface (le rendu logiciel paie chaque couche à plein écran) : l'aire, puis la terre
	# retournée (ou la vase) au pied du mur en couronne, et un peu de lavis.
	var band := PackedVector2Array(O.blob(c, R * 1.0, R * 1.0, 3.0, 0.02, 96))
	band.append(band[0])
	if reg == "spore":
		O.poly(ci, O.blob(c, R * 0.97, R * 0.97, 5.0, 0.025, 96), Color(sombre.lerp(Art.mc("spore", etat, "eau"), 0.5).lerp(sol, 0.35), 0.78 if not live else 0.62))
	else:
		O.poly(ci, O.blob(c, R * 0.96, R * 0.96, 5.0, 0.025, 96), Color(sol.lerp(clair, 0.6), 0.75 if not live else 0.55))
	ci.draw_polyline(band, Color(sombre.darkened(0.3), 0.3), 44.0)
	for i in 8:
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * sqrt(r.randf_range(0.0, 0.6))
		var rx := R * r.randf_range(0.06, 0.13)
		O.poly(ci, O.blob(p, rx, rx * 0.6, float(i), 0.25, 20, r.randf() * PI), Color(clair if i % 2 else sombre, 0.14))
	# Bord intérieur : un liseré sombre (on voit de loin où commence l'aire).
	var rim := PackedVector2Array(O.blob(c, R * 0.96, R * 0.96, 5.0, 0.025, 96))
	rim.append(rim[0])
	ci.draw_polyline(rim, Color(sombre.darkened(0.45), 0.55), 5.0, true)
	if reg == "spore":
		_floor_spore(ci, c, R, r, etat)
	else:
		_floor_ronce(ci, c, R, r, etat)


static func _floor_ronce(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator, etat: String) -> void:
	var live := etat == "ravive"
	var mat: Color = Art.mpc("ronce", "encre_vive" if live else "fissure")
	# Sentiers usés en rond (la Mère-Ronce tourne, les fouets balaient).
	for k in [0.5, 0.78]:
		var w := 22.0
		var pts := PackedVector2Array()
		for i in 73:
			var ang := TAU * i / 72.0
			pts.append(c + Vector2.from_angle(ang) * R * k * (1.0 + 0.015 * O.wave(ang * 3.0, k * 10.0)))
		ci.draw_polyline(pts, Color(Art.mc("ronce", etat, "sol_clair").lightened(0.08), 0.22), w * 0.7)
	if not live:
		# Fentes qui partent du centre, braise au fond.
		for i in 9:
			var ang := TAU * i / 9.0 + r.randf_range(-0.2, 0.2)
			var p := c + Vector2.from_angle(ang) * R * 0.12
			var pts := PackedVector2Array([p])
			var l := R * r.randf_range(0.18, 0.34)
			for j in 7:
				ang += r.randf_range(-0.45, 0.45)
				p += Vector2.from_angle(ang) * l / 7.0
				pts.append(p)
			O.brush(ci, pts, 2.6, Color(mat, 0.6), 0.2, 1.0)
			if i % 2 == 0:
				ci.draw_polyline(pts.slice(1, 4), Color(Art.bc("braise"), 0.3), 1.0, true)
	# Racines du mur qui rampent vers l'intérieur.
	var ron: Dictionary = Art.mc("ronce", etat, "ronce")
	for i in 22:
		var ang := TAU * i / 22.0 + r.randf_range(-0.05, 0.05)
		var a0 := c + Vector2.from_angle(ang) * R * 0.97
		var a1 := c + Vector2.from_angle(ang + r.randf_range(-0.08, 0.08)) * R * r.randf_range(0.86, 0.91)
		var pts := O.curve(a0, a0.lerp(a1, 0.5) + Vector2(r.randf_range(-10, 10), r.randf_range(-6, 6)), a1, 6)
		O.brush(ci, pts, 2.4, Color(ron["ombre"], 0.8), 0.0, 1.0)
		for j in [2, 4]:
			var d := (pts[j + 1] - pts[j - 1]).normalized()
			O.poly(ci, Ink.thorn(pts[j], d.angle() + (1.0 if j == 2 else -1.0) * 1.1, 4.0, 1.8), ron["ombre"])
	# Détails : cailloux, brindilles à épines (flétri) ; herbe, églantines, mûres (ravivé).
	var pierre: Dictionary = Art.mc("ronce", etat, "pierre")
	for i in 46:
		var ang := r.randf() * TAU
		var d := R * sqrt(r.randf_range(0.03, 0.85))
		var p := c + Vector2.from_angle(ang) * d
		if live:
			if i % 3 == 0:
				O.flower(ci, p, r.randf_range(3.0, 4.5), Art.mc("ronce", "ravive", "fleur" if i % 2 else "fleur_2"), Art.mc("ronce", "ravive", "fleur_coeur"), r.randf() * TAU)
			else:
				O.tuft(ci, p, r.randf_range(9.0, 15.0), Art.mc("ronce", "ravive", "touffe"), Art.mc("ronce", "ravive", "touffe_2"), i)
		elif i % 3 == 0:
			O.pebble(ci, p, r.randf_range(2.5, 5.0), pierre, float(i))
		else:
			var dir := Vector2.from_angle(r.randf() * TAU)
			ci.draw_line(p, p + dir * r.randf_range(8, 14), Color(Art.mc("ronce", "fletri", "feuille"), 0.6), 1.3, true)


static func _floor_spore(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator, etat: String) -> void:
	var live := etat == "ravive"
	var eau: Color = Art.mc("spore", etat, "eau")
	var reflet: Color = Art.mc("spore", etat, "eau_reflet")
	# Flaques de vase.
	for i in 7:
		var ang := r.randf() * TAU
		var p := c + Vector2.from_angle(ang) * R * r.randf_range(0.2, 0.7)
		var rx := r.randf_range(26.0, 52.0)
		O.poly(ci, O.blob(p, rx, rx * 0.45, float(i), 0.2, 22), Color(eau, 0.85))
		ci.draw_line(p + Vector2(-rx * 0.45, -rx * 0.12), p + Vector2(-rx * 0.1, -rx * 0.18), Color(reflet, 0.6), 1.6, true)
	# Le rond de sorcière : un cercle de poussière de spores au pied du mur.
	var dust: Color = Art.mc("spore", etat, "cendre")
	for i in 140:
		var ang := TAU * i / 140.0 + r.randf_range(-0.02, 0.02)
		var p := c + Vector2.from_angle(ang) * R * r.randf_range(0.86, 0.94)
		ci.draw_circle(p, r.randf_range(1.0, 2.4), Color(dust, 0.35 if not live else 0.5))
	# Filaments de mycélium qui partent du mur vers le centre.
	for i in 36:
		var ang := TAU * i / 36.0 + r.randf_range(-0.04, 0.04)
		var a0 := c + Vector2.from_angle(ang) * R * 0.98
		var a1 := c + Vector2.from_angle(ang + r.randf_range(-0.15, 0.15)) * R * r.randf_range(0.6, 0.8)
		ci.draw_polyline(O.curve(a0, a0.lerp(a1, 0.5) + Vector2(r.randf_range(-14, 14), r.randf_range(-8, 8)), a1, 8), Color(dust, 0.22), 1.2, true)
	for i in 40:
		var ang := r.randf() * TAU
		var p := c + Vector2.from_angle(ang) * R * sqrt(r.randf_range(0.03, 0.8))
		if live:
			if i % 2 == 0:
				ci.draw_circle(p, 6.0, Color(Art.mc("spore", "ravive", "lueur"), 0.12))
				O.poly(ci, Ink.oval(p + Vector2(0, -3), 3.5, 2.2, 10), Art.mc("spore", "ravive", "fleur" if i % 4 else "fleur_2"))
				ci.draw_line(p, p + Vector2(0, -3), Art.mc("spore", "ravive", "pied")["clair"], 1.0)
			else:
				O.tuft(ci, p, r.randf_range(8.0, 13.0), Art.mc("spore", "ravive", "touffe"), Art.mc("spore", "ravive", "touffe_2"), i)
		elif i % 2 == 0:
			O.pebble(ci, p, r.randf_range(2.0, 4.0), Art.mc("spore", "fletri", "pierre"), float(i))
		else:
			ci.draw_circle(p, r.randf_range(1.5, 3.0), Color(Art.mc("spore", "fletri", "cendre"), 0.25))


## Ce qui bouge au sol : pendant le combat, une lueur qui court le long du pied du mur (braise au
## Roncier, poison au Marais) ; quand le mur s'est resserré, les sillons qu'il a laissés derrière lui.
static func live(ci: CanvasItem, a, reg: String) -> void:
	var c: Vector2 = a.center
	if a.radius < a.max_radius - 2.0:
		var mat: Color = Art.mc(reg, "fletri", "sol_sombre").darkened(0.35)
		for i in 40:
			var ang := TAU * (i + 0.5) / 40.0
			var d := Vector2.from_angle(ang)
			ci.draw_line(c + d * (a.radius + 18.0), c + d * (a.max_radius - 6.0), Color(mat, 0.55), 7.0, true)
			ci.draw_line(c + d * (a.radius + 18.0) + d.orthogonal() * 4.0, c + d * (a.max_radius - 6.0) + d.orthogonal() * 4.0, Color(Art.mc(reg, "fletri", "sol_clair"), 0.25), 2.0, true)
	if a.state != "combat":
		return
	var col: Color = Art.ec("poison", "clair") if reg == "spore" else Art.bc("braise")
	var pulse := 0.5 + 0.5 * sin(a.t * 3.0)
	var pts := PackedVector2Array()
	for i in 97:
		pts.append(c + Vector2.from_angle(TAU * i / 96.0) * (a.radius - 10.0))
	ci.draw_polyline(pts, Color(col, 0.08 + 0.08 * pulse), 26.0, true)
	ci.draw_polyline(pts, Color(col, 0.25 + 0.2 * pulse), 2.5, true)
