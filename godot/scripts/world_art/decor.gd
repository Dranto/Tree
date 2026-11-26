## Décor des « Paysages d'herbier » : objets de trois quarts, encre fine, deux tons, ombre portée vers le
## bas à droite. Échelle commune avec les personnages (héros ≈ 56 px du jeu) : arbre 3 à 5 fois le héros,
## rocher 1 à 2 fois, touffe moins de la moitié.
##
## draw(ci, o, m) : o = {kind, at (pied, px du monde), size, seed, flip, fg (0 → 1 : premier plan plus
## sombre)} ; m : le paysage (région, état en chaque point).
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const Sol = preload("res://scripts/world_art/sol.gd")

## Hauteur de référence de chaque sorte (px du monde, size = 1) : sert à l'ombre et au tri.
## Réduite d'un quart après la première planche (Antoine, 25/11) : arbre ≈ 3 fois le héros.
const HEIGHT := {
	"arbre": 172.5, "haie": 71.25, "buisson": 43.5, "rocher": 52.5, "muret": 25.5, "ruine": 202.5,
	"champignon": 142.5, "chapeau_geant": 247.5, "tronc": 33.0, "roseaux": 58.5, "fougere": 39.0,
	"grand_arbre": 270.0,
}


static func draw(ci: CanvasItem, o: Dictionary, m) -> void:
	var at: Vector2 = o["at"]
	var reg: String = m.region_at(at)
	var etat: String = m.decor_etat_at(at)
	var k: float = o.get("fg", 0.0)
	var r := RandomNumberGenerator.new()
	r.seed = int(o.get("seed", 1))
	var s: float = o.get("size", 1.0)
	var fl := -1.0 if o.get("flip", false) else 1.0
	var h: float = HEIGHT.get(o["kind"], 60.0) * s
	if k < 0.5:
		O.cast_shadow(ci, at, h * 0.55 if o["kind"] not in ["haie", "muret", "tronc"] else h * 1.6, h * 0.6, 0.3 if etat == "ravive" else 0.36)
	var P := func(key: String) -> Dictionary:
		var src := "ravive" if etat == "ravive" else "fletri"
		var pal: Dictionary
		if Art.MONDE[reg][src].has(key):
			pal = Art.mc(reg, src, key)
		elif Art.MONDE["commun"].has(key):
			pal = Art.mc("commun", "", key)
		else:
			pal = Art.mc("ronce", src, key)
		if etat == "apaise":
			pal = _apaise(pal)
		return O.pal_fg(pal, k) if k > 0.0 else pal
	match o["kind"]:
		"arbre":
			_arbre(ci, at, h, fl, r, P, etat, reg, k)
		"grand_arbre":
			_grand_arbre(ci, at, h, fl, r, P, etat, reg, k)
		"haie":
			_haie(ci, at, h, fl, r, P, etat, reg, k)
		"buisson":
			_buisson(ci, at, h, r, P, etat, reg, k)
		"rocher":
			_rocher(ci, at, h, fl, r, P, etat, reg)
		"muret":
			_muret(ci, at, h, fl, r, P, etat, reg)
		"ruine":
			_ruine(ci, at, h, fl, r, P, etat, reg)
		"champignon":
			_champignon(ci, at, h, fl, r, P, etat, k, false)
		"chapeau_geant":
			_chapeau_geant(ci, at, h, fl, r, P, etat, k)
		"tronc":
			_tronc(ci, at, h, fl, r, P, etat)
		"roseaux":
			_roseaux(ci, at, h, r, P, etat, k)
		"fougere":
			_fougere(ci, at, h, r, P, etat, k)


## Décor apaisé : les formes mortes, un peu moins sombres et sans braise.
static func _apaise(pal: Dictionary) -> Dictionary:
	var out := {}
	for key in pal:
		out[key] = pal[key].lightened(0.1)
	return out


# --- Roncier ---


## Arbre : tronc évasé aux racines, branches qui se divisent (au pinceau, de plus en plus fines) ;
## houppier de masses feuillues piquées de fleurs d'églantier (ravivé), ou branches nues ligotées de
## ronce avec quelques grappes de feuilles sèches (flétri).
static func _arbre(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, P: Callable, etat: String, reg: String, k: float) -> void:
	var bois: Dictionary = P.call("bois")
	var w := h * 0.06
	var lean := r.randf_range(-0.06, 0.06) * fl
	var top := at + Vector2(lean * h, -h * 0.5)
	var trunk := PackedVector2Array([
		at + Vector2(-w * 2.4, 2), at + Vector2(-w * 1.0, -h * 0.07), top + Vector2(-w * 0.6, 0),
		top + Vector2(w * 0.55, 0), at + Vector2(w * 1.1, -h * 0.08), at + Vector2(w * 2.6, 2),
		at + Vector2(w * 0.7, -h * 0.02), at + Vector2(-w * 0.5, -h * 0.025)])
	O.part(ci, trunk, bois, 1.6, 1.0, 0.4)
	for i in 3:
		ci.draw_line(at.lerp(top, 0.2 + 0.22 * i) + Vector2(-w * 0.3, 0), at.lerp(top, 0.28 + 0.22 * i) + Vector2(w * 0.1, 0), Color(bois["ombre"], 0.7), 1.0, true)
	var tips := []
	_branch(ci, top, Vector2(0.15 * fl, -1).normalized(), h * 0.28, w * 1.1, 3, r, bois, tips)
	_branch(ci, at.lerp(top, 0.8), Vector2(-0.9, -0.7).normalized(), h * 0.22, w * 0.8, 2, r, bois, tips)
	_branch(ci, at.lerp(top, 0.9), Vector2(0.9, -0.6).normalized(), h * 0.22, w * 0.8, 2, r, bois, tips)
	if etat == "ravive":
		var leaf: Dictionary = P.call("feuillage")
		var crown := top + Vector2(0, -h * 0.2)
		var masses := []
		for i in 9:
			var a := -PI * 0.5 + (i - 4) * 0.42
			var c := crown + Vector2(cos(a) * h * 0.24, sin(a) * h * 0.12 + h * 0.06) + Vector2(r.randf_range(-8, 8), r.randf_range(-6, 6))
			masses.append([c, h * r.randf_range(0.11, 0.15)])
		masses.append([crown + Vector2(-h * 0.04, -h * 0.03), h * 0.17])
		masses.append([crown + Vector2(h * 0.08, h * 0.02), h * 0.15])
		masses.sort_custom(func(x, y): return x[0].y < y[0].y)
		for ms in masses:
			O.part(ci, O.Ink.lumpy(ms[0], ms[1], ms[1] * 0.85, 26, 0.1, 9.0, ms[0].x), leaf, 1.3, 1.0, 0.7)
		for i in 16:
			var ms: Array = masses[r.randi() % masses.size()]
			var p: Vector2 = ms[0] + Vector2(r.randf_range(-0.7, 0.5), r.randf_range(-0.7, 0.3)) * ms[1]
			if reg == "ronce":
				O.flower(ci, p, r.randf_range(2.4, 3.4), O.fg(Art.mc(reg, "ravive", "fleur" if i % 3 else "fleur_2"), k), O.fg(Art.mc(reg, "ravive", "fleur_coeur"), k), r.randf() * TAU)
	else:
		var leaf: Dictionary = P.call("feuillage")
		for i in tips.size():
			if i % 3 != 0:
				continue
			var tip: Vector2 = tips[i]
			for j in r.randi_range(2, 4):
				var p: Vector2 = tip + Vector2(r.randf_range(-6, 6), r.randf_range(-3, 6))
				O.part(ci, O.Ink.leaf(p, r.randf_range(1.0, 2.2), 7.0, 3.4, 0.15), leaf, 0.7, 1.0, 0.0)
		var ron: Dictionary = P.call("ronce")
		for i in 2:
			var pts := PackedVector2Array()
			for j in 11:
				var u := j / 10.0
				pts.append(at.lerp(top, u * 0.95) + Vector2(sin(u * 11.0 + i * 2.5) * w * (1.4 - 0.6 * u), 0))
			O.brush(ci, pts, 2.6, ron["ombre"], 0.5, 0.0)
			O.brush(ci, pts, 1.0, ron["clair"], 0.5, 0.0)
			for j in range(1, 10, 2):
				O.poly(ci, O.Ink.thorn(pts[j], -PI * 0.5 + (0.9 if j % 4 == 1 else -0.9) + PI * 0.5 * (1 if j % 4 == 1 else -1), 3.5, 1.6), ron["ombre"])


## Grand arbre (repère du Roncier) : un vieux chêne trapu, plus grand que tout le reste et d'une
## silhouette unique : contreforts de racines, tronc creux, houppier large et plat. Flétri : branches
## nues ligotées de grosses tiges de ronce, braise au fond du creux. Ravivé : houppier épais piqué
## d'églantines, mûres pendantes, et le creux devient un nid de lumière douce.
static func _grand_arbre(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, P: Callable, etat: String, reg: String, k: float) -> void:
	var bois: Dictionary = P.call("bois")
	var ron: Dictionary = P.call("ronce")
	var w := h * 0.085
	var top := at + Vector2(h * 0.03 * fl, -h * 0.42)
	# Contreforts : racines épaisses qui s'étalent à plat (vue de trois quarts).
	for i in 6:
		var a := PI * (0.02 + 0.96 * i / 5.0)
		var tip := at + Vector2(cos(a) * w * 4.2, sin(a) * w * 0.9 + 2.0) * Vector2(fl, 1.0)
		var base := at + Vector2(cos(a) * w * 0.8, -h * 0.05)
		O.part(ci, PackedVector2Array([base + Vector2(-w * 0.4, 0), tip + Vector2(0, -2), tip + Vector2(2, 1), base + Vector2(w * 0.4, h * 0.03)]), bois, 1.3, 1.0, 0.3)
	var trunk := PackedVector2Array([
		at + Vector2(-w * 2.0, 3), at + Vector2(-w * 1.4, -h * 0.12), top + Vector2(-w * 1.0, h * 0.04), top + Vector2(-w * 1.2, -h * 0.02),
		top + Vector2(w * 1.1, -h * 0.03), top + Vector2(w * 0.95, h * 0.05), at + Vector2(w * 1.5, -h * 0.12), at + Vector2(w * 2.1, 3)])
	O.part(ci, trunk, bois, 1.8, 1.0, 0.4)
	# Écorce : sillons verticaux sur le flanc à l'ombre.
	for i in 5:
		var x := -w * 0.9 + w * 0.45 * i
		var a0 := at + Vector2(x, -h * 0.04)
		var a1 := top + Vector2(x * 0.75 + r.randf_range(-2, 2), h * 0.03)
		ci.draw_line(a0, a1, Color(bois["ombre"], 0.55), 1.1, true)
	# Le creux : une ogive sombre au pied du tronc.
	var hc := at + Vector2(w * 0.15 * fl, -h * 0.13)
	var hollow := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		var y := -sin(a) * h * 0.075 - pow(sin(a), 6.0) * h * 0.03
		hollow.append(hc + Vector2(-cos(a) * w * 0.55 * (1.0 - 0.15 * sin(a)), y))
	hollow.append(hc + Vector2(w * 0.5, h * 0.06))
	hollow.append(hc + Vector2(-w * 0.5, h * 0.06))
	O.poly(ci, hollow, Art.mc("commun", "", "encre_decor"))
	if etat == "ravive":
		ci.draw_circle(hc + Vector2(0, h * 0.01), w * 0.5, Color(O.fg(Art.mc(reg, "ravive", "fleur_coeur"), k), 0.35))
		ci.draw_circle(hc + Vector2(0, h * 0.015), w * 0.22, O.fg(Art.mc(reg, "ravive", "fleur_coeur"), k))
	elif etat == "fletri":
		ci.draw_circle(hc + Vector2(0, h * 0.02), w * 0.5, Color(Art.bc("braise"), 0.16))
		ci.draw_circle(hc + Vector2(0, h * 0.03), w * 0.16, Art.bc("braise"))
	# Charpentières : grosses branches presque horizontales, qui se divisent.
	var tips := []
	_branch(ci, top, Vector2(-1.0 * fl, -0.45).normalized(), h * 0.3, w * 0.95, 3, r, bois, tips)
	_branch(ci, top, Vector2(1.0 * fl, -0.5).normalized(), h * 0.3, w * 0.95, 3, r, bois, tips)
	_branch(ci, top + Vector2(0, -h * 0.02), Vector2(0.1 * fl, -1.0).normalized(), h * 0.22, w * 0.8, 3, r, bois, tips)
	# Grosses tiges de ronce qui montent en spirale le long du tronc et retombent des branches.
	for i in 2:
		var pts := PackedVector2Array()
		for j in 15:
			var u := j / 14.0
			pts.append(at.lerp(top, u) + Vector2(sin(u * 9.0 + i * 3.1) * w * (1.5 - 0.5 * u), 0))
		O.brush(ci, pts, 4.2 if etat == "fletri" else 3.2, ron["ombre"], 0.6, 0.2)
		O.brush(ci, pts, 1.6, ron["clair"], 0.6, 0.2)
		for j in range(1, 14, 2):
			O.poly(ci, O.Ink.thorn(pts[j], PI * (0.0 if (j + i) % 4 < 2 else 1.0) + r.randf_range(-0.4, 0.4), 5.0, 2.2), ron["ombre"])
	if etat == "ravive":
		var leaf: Dictionary = P.call("feuillage")
		var crown := top + Vector2(0, -h * 0.26)
		var masses := []
		for i in 13:
			var a := -PI + PI * i / 12.0
			var c := crown + Vector2(cos(a) * h * 0.4, sin(a) * h * 0.18 + h * 0.08) + Vector2(r.randf_range(-8, 8), r.randf_range(-6, 6))
			masses.append([c, h * r.randf_range(0.1, 0.135)])
		for i in 5:
			masses.append([crown + Vector2(r.randf_range(-0.25, 0.25) * h, r.randf_range(-0.06, 0.08) * h), h * r.randf_range(0.12, 0.15)])
		masses.sort_custom(func(x, y): return x[0].y < y[0].y)
		for ms in masses:
			O.part(ci, O.Ink.lumpy(ms[0], ms[1], ms[1] * 0.8, 26, 0.1, 9.0, ms[0].x), leaf, 1.3, 1.0, 0.7)
		for i in 30:
			var ms: Array = masses[r.randi() % masses.size()]
			var p: Vector2 = ms[0] + Vector2(r.randf_range(-0.7, 0.6), r.randf_range(-0.6, 0.4)) * ms[1]
			O.flower(ci, p, r.randf_range(3.0, 4.2), O.fg(Art.mc(reg, "ravive", "fleur" if i % 3 else "fleur_2"), k), O.fg(Art.mc(reg, "ravive", "fleur_coeur"), k), r.randf() * TAU)
		# Mûres qui pendent sous le houppier.
		for i in 6:
			var ms: Array = masses[r.randi() % masses.size()]
			var p: Vector2 = ms[0] + Vector2(r.randf_range(-0.5, 0.5) * ms[1], ms[1] * 0.75)
			ci.draw_line(p, p + Vector2(0, 7), Color(ron["ombre"], 0.9), 1.0, true)
			for b in 3:
				ci.draw_circle(p + Vector2(b * 2.2 - 2.2, 8.0 + (b % 2) * 1.8), 2.0, O.fg(Art.mc(reg, "ravive", "fruit"), k))
	else:
		var leaf: Dictionary = P.call("feuillage")
		for i in tips.size():
			if i % 2 != 0:
				continue
			var tip: Vector2 = tips[i]
			for j in r.randi_range(1, 3):
				var p: Vector2 = tip + Vector2(r.randf_range(-6, 6), r.randf_range(-3, 6))
				O.part(ci, O.Ink.leaf(p, r.randf_range(1.0, 2.2), 7.0, 3.4, 0.15), leaf, 0.7, 1.0, 0.0)
		# Tiges qui retombent des charpentières, en guirlandes d'épines.
		for i in 4:
			var t0: Vector2 = tips[(i * 5) % tips.size()]
			var t1: Vector2 = tips[(i * 5 + 3) % tips.size()]
			var sag := O.curve(t0, t0.lerp(t1, 0.5) + Vector2(0, h * 0.12), t1, 10)
			O.brush(ci, sag, 2.4, ron["ombre"], 0.4, 0.4)
			for j in range(1, 10, 3):
				O.poly(ci, O.Ink.thorn(sag[j], PI * 0.5 + r.randf_range(-0.5, 0.5), 4.0, 1.8), ron["ombre"])


## Branche qui se divise : un coup de pinceau sombre, un filet clair sur le dessus (côté lumière).
static func _branch(ci: CanvasItem, from: Vector2, dir: Vector2, l: float, w: float, depth: int, r: RandomNumberGenerator, bois: Dictionary, tips: Array) -> void:
	var bend := dir.rotated(r.randf_range(-0.35, 0.35))
	var to := from + bend * l
	var mid := from.lerp(to, 0.5) + dir.orthogonal() * r.randf_range(-0.12, 0.12) * l
	var pts := O.curve(from, mid, to, 6)
	O.brush(ci, pts, w, bois["ombre"], 1.0, 0.0)
	O.brush(ci, O.curve(from + Vector2(-0.4, -0.5) * w * 0.3, mid + Vector2(-0.4, -0.5) * w * 0.3, to, 6), w * 0.4, bois["clair"], 1.0, 0.0)
	if depth <= 0:
		tips.append(to)
		return
	for s in [-1.0, 1.0]:
		_branch(ci, from.lerp(to, r.randf_range(0.65, 0.95)), dir.rotated(s * r.randf_range(0.35, 0.7)), l * r.randf_range(0.55, 0.72), w * 0.62, depth - 1, r, bois, tips)


## Haie de ronces : une masse basse de petites touffes serrées, traversée de tiges en arceaux hérissées
## d'épines. Ravivée : feuilles vertes, églantines et mûres ; flétrie : feuilles mortes et tiges sèches.
static func _haie(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, P: Callable, etat: String, reg: String, k: float) -> void:
	var ron: Dictionary = P.call("ronce")
	var leaf: Dictionary = P.call("feuillage")
	var w := h * 1.8
	var masses := []
	for i in 9:
		var u := r.randf_range(-1.0, 1.0)
		var c := at + Vector2(u * w * 0.42, -h * (0.18 + 0.32 * (1.0 - u * u)) - r.randf_range(0, h * 0.12))
		masses.append([c, h * r.randf_range(0.17, 0.25)])
	masses.sort_custom(func(x, y): return x[0].y < y[0].y)
	# Tiges de l'arrière (sous les touffes).
	_canes(ci, at, h, w, r, ron, 4)
	for ms in masses:
		O.part(ci, O.Ink.lumpy(ms[0], ms[1] * 1.2, ms[1], 22, 0.18, 9.0, ms[0].x * 0.1), leaf, 1.3, 1.0, 0.5)
		# Bord découpé : petites feuilles sur le contour éclairé.
		for j in 3:
			var a := PI * (1.1 + 0.3 * j)
			var p: Vector2 = ms[0] + Vector2(cos(a), sin(a)) * ms[1] * Vector2(1.15, 0.95)
			O.poly(ci, O.Ink.leaf(p, a, ms[1] * 0.45, ms[1] * 0.25), leaf["clair"])
	# Tiges de l'avant, par-dessus.
	_canes(ci, at, h, w, r, ron, 4)
	if etat == "ravive":
		for i in r.randi_range(8, 12):
			var ms: Array = masses[r.randi() % masses.size()]
			var p: Vector2 = ms[0] + Vector2(r.randf_range(-1.0, 1.0) * ms[1], r.randf_range(-0.8, 0.4) * ms[1])
			if i % 3 == 0:
				for b in 3:
					ci.draw_circle(p + Vector2(b * 2.2 - 2.2, (b % 2) * 1.8), 1.9, O.fg(Art.mc(reg, "ravive", "fruit"), k))
				ci.draw_circle(p + Vector2(-2.6, -0.8), 0.7, Color(1, 1, 1, 0.5))
			else:
				O.flower(ci, p, r.randf_range(2.8, 4.0), O.fg(Art.mc(reg, "ravive", "fleur" if i % 4 else "fleur_2"), k), O.fg(Art.mc(reg, "ravive", "fleur_coeur"), k), r.randf() * TAU)
	elif etat == "fletri" and k < 0.5 and r.randf() < 0.5:
		var ms: Array = masses[0]
		ci.draw_circle(ms[0], 5.0, Color(Art.bc("braise"), 0.12))
		ci.draw_circle(ms[0], 1.4, Art.bc("braise"))


## Tiges de ronce en arceaux, hérissées d'épines.
static func _canes(ci: CanvasItem, at: Vector2, h: float, w: float, r: RandomNumberGenerator, ron: Dictionary, n: int) -> void:
	for i in n:
		var a := at + Vector2(r.randf_range(-0.5, 0.5) * w, -h * r.randf_range(0.0, 0.2))
		var d := r.randf_range(0.4, 0.9) * (1.0 if r.randf() < 0.5 else -1.0)
		var top := a + Vector2(d * h * 0.5, -h * r.randf_range(0.6, 0.95))
		var end := a + Vector2(d * h * 1.05, -h * r.randf_range(0.0, 0.25))
		var pts := O.curve(a, top, end, 10)
		O.brush(ci, pts, 2.8, O.Ink.encre(), 0.6, 0.0)
		O.brush(ci, pts, 2.0, ron["ombre"], 0.6, 0.0)
		O.brush(ci, pts, 0.8, ron["clair"], 0.6, 0.0)
		for j in range(2, 10, 2):
			var t := (pts[j + 1] - pts[j - 1]).normalized()
			var nn := t.orthogonal() * (1.0 if j % 4 == 0 else -1.0)
			O.poly(ci, O.Ink.thorn(pts[j], nn.angle() - 0.4, 3.6, 1.6), O.Ink.encre())


## Buisson de mûres : boule feuillue (mûres mûres une fois ravivé, rameaux secs sinon).
static func _buisson(ci: CanvasItem, at: Vector2, h: float, r: RandomNumberGenerator, P: Callable, etat: String, reg: String, k: float) -> void:
	var leaf: Dictionary = P.call("feuillage")
	if reg == "spore":
		_fougere(ci, at, h, r, P, etat, k)
		return
	var c := at + Vector2(0, -h * 0.45)
	var bush := O.Ink.lumpy(c, h * 0.62, h * 0.48, 26, 0.16, 9.0, at.x)
	if etat == "ravive":
		O.part(ci, bush, leaf, 1.4, 1.0, 0.6)
		for i in 5:
			var p := c + Vector2(r.randf_range(-0.6, 0.6), r.randf_range(-0.5, 0.4)) * h * 0.55
			for b in 3:
				ci.draw_circle(p + Vector2(b * 2.0 - 2.0, (b % 2) * 1.7), 1.8, O.fg(Art.mc(reg, "ravive", "fruit"), k))
	else:
		var ron: Dictionary = P.call("ronce")
		O.part(ci, bush, leaf, 1.4, 0.8, 0.2)
		for i in 6:
			var a := c + Vector2(r.randf_range(-0.4, 0.4) * h, 0)
			O.brush(ci, O.curve(a, a + Vector2(r.randf_range(-12, 12), -h * 0.4), a + Vector2(r.randf_range(-22, 22), -h * 0.55)), 1.4, ron["ombre"], 0.5, 0.0)


## Rocher : bloc taillé à facettes (face éclairée en haut à gauche), mousse ou ronce sur le dessus.
static func _rocher(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, P: Callable, etat: String, reg: String) -> void:
	var st: Dictionary = P.call("pierre")
	var w := h * r.randf_range(0.8, 1.1)
	var pts := PackedVector2Array([
		at + Vector2(-w * 0.62, 0), at + Vector2(-w * 0.7, -h * 0.38), at + Vector2(-w * 0.38, -h * 0.86),
		at + Vector2(w * 0.05 * fl, -h), at + Vector2(w * 0.48, -h * 0.72), at + Vector2(w * 0.66, -h * 0.28),
		at + Vector2(w * 0.55, 0)])
	O.part(ci, pts, st, 1.6, 1.0, 0.5)
	# Arête : une facette d'ombre sur le flanc droit.
	O.poly(ci, PackedVector2Array([at + Vector2(w * 0.05 * fl, -h), at + Vector2(w * 0.48, -h * 0.72), at + Vector2(w * 0.66, -h * 0.28), at + Vector2(w * 0.55, 0), at + Vector2(w * 0.15, 0), at + Vector2(w * 0.12, -h * 0.55)]), Color(st["ombre"], 0.55))
	ci.draw_polyline(PackedVector2Array([at + Vector2(w * 0.05 * fl, -h), at + Vector2(w * 0.12, -h * 0.55), at + Vector2(w * 0.15, 0)]), Color(Art.mc("commun", "", "encre_decor"), 0.5), 0.9, true)
	var top := at + Vector2(-w * 0.1, -h * 0.9)
	var moss: Color = Art.mc(reg, "ravive", "touffe") if etat == "ravive" else Art.mc(reg, "fletri", "touffe_2")
	O.poly(ci, O.blob(top, w * 0.3, h * 0.08, at.x, 0.3, 16), Color(moss, 0.85))


## Muret de pierres sèches : un rang de pierres arrondies, quelques-unes tombées.
static func _muret(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, P: Callable, etat: String, reg: String) -> void:
	var st: Dictionary = P.call("pierre")
	var n := 5
	for row in 2:
		var x := -n * 0.5 * h * 0.8
		for i in n - row:
			var sw := h * r.randf_range(0.6, 1.0)
			var c := at + Vector2((x + sw * 0.5 + row * h * 0.35) * fl, -h * (0.26 + row * 0.42) + r.randf_range(-1.5, 1.5))
			x += sw * 0.95
			O.part(ci, O.Ink.lumpy(c, sw * 0.5, h * 0.24, 12, 0.1, 3.0, c.x), st, 1.2, 1.0, 0.3)
	if etat == "ravive":
		O.tuft(ci, at + Vector2(h * 1.2, 0), 14.0, Art.mc(reg, "ravive", "touffe"), Art.mc(reg, "ravive", "touffe_2"), r.randi())


## Ruine ligotée de ronce (repère du Roncier) : deux piliers brisés, un linteau tombé, un arbre mort qui
## pousse au travers et la ronce qui serre le tout. Visible de loin (4 à 5 fois le héros).
static func _ruine(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, P: Callable, etat: String, reg: String) -> void:
	var st: Dictionary = P.call("pierre")
	var ron: Dictionary = P.call("ronce")
	var pw := h * 0.16
	var pillars := [[at + Vector2(-h * 0.26 * fl, 0), h * 0.82], [at + Vector2(h * 0.24 * fl, 4), h * 0.55]]
	for pl in pillars:
		var b: Vector2 = pl[0]
		var hh: float = pl[1]
		var pts := PackedVector2Array([b + Vector2(-pw * 0.6, 0), b + Vector2(-pw * 0.5, -hh), b + Vector2(-pw * 0.1, -hh - 8), b + Vector2(pw * 0.2, -hh + 4), b + Vector2(pw * 0.5, -hh - 3), b + Vector2(pw * 0.6, 0)])
		O.part(ci, pts, st, 1.8, 1.0, 0.4)
		for j in range(1, 5):
			var y := b.y - hh * j / 5.0
			ci.draw_line(Vector2(b.x - pw * 0.55, y), Vector2(b.x + pw * 0.55, y + 1.5), Color(st["ombre"], 0.8), 1.0, true)
		# Chapiteau.
		O.part(ci, PackedVector2Array([b + Vector2(-pw * 0.8, -hh * 0.98), b + Vector2(-pw * 0.75, -hh * 1.04), b + Vector2(pw * 0.75, -hh * 1.04 + 3), b + Vector2(pw * 0.8, -hh * 0.98 + 3)]), st, 1.2, 1.0, 0.3)
	# Linteau tombé, appuyé contre le petit pilier.
	var l0 := at + Vector2(-h * 0.2 * fl, -h * 0.7)
	var l1 := at + Vector2(h * 0.44 * fl, -h * 0.04)
	var nn := (l1 - l0).normalized().orthogonal() * pw * 0.45
	O.part(ci, PackedVector2Array([l0 - nn, l1 - nn, l1 + nn, l0 + nn]), st, 1.6, 1.0, 0.3)
	# Ronce qui ligote : grosses tiges en spirale autour des piliers et du linteau.
	for pl in pillars:
		var b: Vector2 = pl[0]
		var hh: float = pl[1]
		var pts := PackedVector2Array()
		for j in 16:
			var u := j / 15.0
			pts.append(b + Vector2(sin(u * 14.0) * pw * 0.65, -hh * u * 0.95))
		O.brush(ci, pts, 4.0, ron["ombre"], 0.8, 0.0)
		O.brush(ci, pts, 1.6, ron["clair"], 0.8, 0.0)
		for j in range(1, 15, 2):
			O.poly(ci, O.Ink.thorn(pts[j], (-1.0 if j % 4 == 1 else 1.0) * 0.4 + (PI if pts[j].x < b.x else 0.0), 5.0, 2.2), ron["ombre"])
	var arc := O.curve(at + Vector2(-h * 0.45 * fl, 0), at + Vector2(0, -h * 1.15), at + Vector2(h * 0.5 * fl, -h * 0.1), 14)
	O.brush(ci, arc, 5.0, ron["ombre"], 1.0, 0.6)
	O.brush(ci, arc, 2.0, ron["clair"], 1.0, 0.6)
	if etat == "ravive":
		for i in 12:
			var p := arc[r.randi_range(2, 12)] + Vector2(r.randf_range(-8, 8), r.randf_range(-8, 8))
			O.flower(ci, p, r.randf_range(3.4, 4.6), Art.mc(reg, "ravive", "fleur" if i % 3 else "fleur_2"), Art.mc(reg, "ravive", "fleur_coeur"), r.randf() * TAU)
	elif etat == "fletri":
		for i in 3:
			var p := arc[r.randi_range(3, 11)]
			ci.draw_circle(p, 5.0, Color(Art.bc("braise"), 0.12))
			ci.draw_circle(p, 1.6, Art.bc("braise"))


# --- Marais ---


## Champignon géant : pied pâle, chapeau large en dôme, lamelles sombres dessous. Flétri : chapeau
## affaissé, troué, braise dans les lamelles. Ravivé : chapeau violet à pois lumineux, halo turquoise.
static func _champignon(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, P: Callable, etat: String, k: float, giant: bool) -> void:
	var pied: Dictionary = P.call("pied")
	var cap: Dictionary = P.call("chapeau").duplicate()
	# Chaque chapeau a sa teinte et sa forme (plus ou moins plat, plus ou moins large).
	var tint := r.randf_range(-0.12, 0.12)
	for key in cap:
		cap[key] = cap[key].lightened(tint) if tint > 0.0 else cap[key].darkened(-tint)
	var lean := r.randf_range(-0.12, 0.12) * fl
	var cw := h * (0.46 if giant else r.randf_range(0.3, 0.45))
	var dome_h := r.randf_range(0.45, 0.85) if not giant else 0.62
	var top := at + Vector2(lean * h, -h * 0.78)
	var sw := h * 0.07
	var stem := PackedVector2Array([at + Vector2(-sw * 1.6, 0), at + Vector2(-sw * 0.9, -h * 0.25), top + Vector2(-sw * 0.8, 0), top + Vector2(sw * 0.8, 0), at + Vector2(sw, -h * 0.25), at + Vector2(sw * 1.7, 0)])
	if etat == "ravive" and k < 0.5:
		ci.draw_circle(top, cw * 1.5, Color(Art.mc("spore", "ravive", "lueur"), 0.05))
		ci.draw_circle(top, cw * 1.05, Color(Art.mc("spore", "ravive", "lueur"), 0.06))
	O.part(ci, stem, pied, 1.5, 1.0, 0.5)
	# Anneau.
	O.part(ci, O.Ink.oval(at.lerp(top, 0.7), sw * 1.5, sw * 0.5, 14), pied, 1.0, 1.0, 0.3)
	var droop := 0.25 if etat != "ravive" else 0.0
	var dome := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		var y := sin(a) * cw * dome_h
		dome.append(top + Vector2(cos(a) * cw, y - h * 0.02))
	# Bord du chapeau (vu de trois quarts) : ourlet qui retombe.
	for i in range(16, -1, -1):
		var a := PI * i / 16.0
		dome.append(top + Vector2(cos(a) * cw, sin(a) * cw * 0.2 + droop * cw * (1.0 - absf(cos(a))) * 0.8))
	O.part(ci, dome, cap, 1.7, 0.55, 0.8)
	# Lamelles sous l'ourlet.
	var gill: Color = cap["ombre"].darkened(0.3)
	for i in 9:
		var a := PI * (0.12 + 0.76 * i / 8.0)
		var e := top + Vector2(cos(a) * cw * 0.95, sin(a) * cw * 0.18 + droop * cw * (1.0 - absf(cos(a))) * 0.75)
		ci.draw_line(top + Vector2(cos(a) * cw * 0.25, 2), e, Color(gill, 0.8), 1.0, true)
	if etat == "fletri":
		for i in 2:
			var p := top + Vector2(cos(PI * (0.3 + 0.35 * i)) * cw * 0.55, cw * 0.1)
			ci.draw_circle(p, 6.0, Color(Art.bc("braise"), 0.12))
			ci.draw_line(p - Vector2(4, 0), p + Vector2(4, 1), Art.bc("braise"), 1.2, true)
	# Pois ou trous.
	for i in r.randi_range(4, 7):
		var a := PI + r.randf_range(0.15, 0.85) * PI
		var p := top + Vector2(cos(a) * cw * r.randf_range(0.2, 0.8), sin(a) * cw * 0.5 * r.randf_range(0.3, 0.9))
		var rr := cw * r.randf_range(0.05, 0.1)
		if etat == "ravive":
			ci.draw_circle(p, rr * 2.2, Color(O.fg(Art.mc("spore", "ravive", "lueur"), k), 0.18))
			O.poly(ci, O.Ink.oval(p, rr, rr * 0.7, 12), O.fg(Art.mc("spore", "ravive", "fleur"), k))
		else:
			O.poly(ci, O.Ink.oval(p, rr, rr * 0.65, 12), Color(cap["ombre"].darkened(0.35), 0.9))


## Chapeau géant (repère du Marais) : un chapeau immense, deux plus petits blottis à son pied, des
## polypores en étagères sur le pied, et un voile de mycélium qui pend de l'ourlet. Flétri : affaissé,
## voile gris ; ravivé : voile qui luit, pois lumineux.
static func _chapeau_geant(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, P: Callable, etat: String, k: float) -> void:
	var r2 := RandomNumberGenerator.new()
	r2.seed = r.seed + 17
	# Le petit de derrière.
	_champignon(ci, at + Vector2(-h * 0.2 * fl, -h * 0.03), h * 0.36, -fl, r2, P, etat, k, false)
	_champignon(ci, at, h, fl, r, P, etat, k, true)
	# Polypores en étagères sur le pied (côté lumière).
	var pied: Dictionary = P.call("pied")
	var shelf: Dictionary = P.call("chapeau")
	for i in 3:
		var c := at + Vector2(-h * 0.045 * fl, -h * (0.18 + 0.12 * i))
		var sw := h * (0.07 - 0.012 * i)
		var pts := PackedVector2Array()
		for j in 9:
			var a := PI + PI * j / 8.0
			pts.append(c + Vector2(-fl * sw * 0.2 + cos(a) * sw, sin(a) * sw * 0.35))
		pts.append(c + Vector2(sw, sw * 0.12))
		pts.append(c + Vector2(-sw, sw * 0.12))
		O.part(ci, pts, shelf, 1.1, 1.0, 0.4)
		ci.draw_line(c + Vector2(-sw * 0.8, sw * 0.08), c + Vector2(sw * 0.8, sw * 0.08), Color(pied["ombre"], 0.8), 1.0, true)
	# Voile de mycélium qui pend de l'ourlet.
	var cw := h * 0.46
	var brim := at + Vector2(0, -h * 0.78)
	var veil: Color = Color(Art.mc("spore", "ravive", "lueur"), 0.55) if etat == "ravive" else Color(Art.mc("spore", "fletri", "cendre"), 0.32)
	veil = O.fg(veil, k)
	for i in 9:
		var u := -0.85 + 1.7 * i / 8.0
		var p0 := brim + Vector2(u * cw, cw * 0.14 + (0.0 if etat == "ravive" else 0.25 * cw * (1.0 - absf(u)) * 0.8))
		var l := h * r.randf_range(0.06, 0.16)
		var pts := O.curve(p0, p0 + Vector2(r.randf_range(-3, 3), l * 0.5), p0 + Vector2(r.randf_range(-5, 5), l), 4)
		ci.draw_polyline(pts, veil, 1.0, true)
		if etat == "ravive" and i % 2 == 0:
			ci.draw_circle(pts[-1], 2.4, Color(veil, 0.25))
			ci.draw_circle(pts[-1], 1.0, veil)
	# Le petit de devant.
	_champignon(ci, at + Vector2(h * 0.17 * fl, h * 0.02), h * 0.27, fl, r2, P, etat, k, false)


## Tronc couché : un tronc mort qui pourrit dans la vase, mousse et petits chapeaux dessus.
static func _tronc(ci: CanvasItem, at: Vector2, h: float, fl: float, r: RandomNumberGenerator, P: Callable, etat: String) -> void:
	var bois: Dictionary = P.call("bois")
	var l := h * 4.2
	var a := at + Vector2(-l * 0.5 * fl, 0)
	var b := at + Vector2(l * 0.5 * fl, -h * 0.15)
	var nn := Vector2(0, -h * 0.5)
	var pts := PackedVector2Array([a, a + nn * 1.6, b + nn * 1.4, b + nn * 0.1])
	pts = PackedVector2Array([a + Vector2(0, 2), a + nn * 1.7, a.lerp(b, 0.5) + nn * 1.85, b + nn * 1.5, b + Vector2(0, 2)])
	O.part(ci, pts, bois, 1.5, 1.0, 0.4)
	# Bout coupé (cernes).
	var end := a + nn * 0.85
	O.part(ci, O.Ink.oval(end, h * 0.25, h * 0.42, 16), {"clair": bois["reflet"], "ombre": bois["clair"]}, 1.2, 1.0, 0.0)
	ci.draw_arc(end, h * 0.15, 0, TAU, 14, Color(bois["ombre"], 0.8), 1.0, true)
	for i in 4:
		var u := 0.2 + 0.18 * i
		var p := a.lerp(b, u) + nn * (1.2 + r.randf_range(-0.2, 0.2))
		ci.draw_line(p, p + Vector2(l * 0.08 * fl, 1), Color(bois["ombre"], 0.8), 1.0, true)
	var moss: Color = Art.mc("spore", "ravive" if etat == "ravive" else "fletri", "touffe")
	O.poly(ci, O.blob(a.lerp(b, 0.55) + nn * 1.75, l * 0.22, h * 0.12, at.x, 0.3, 18), moss)
	for i in 3:
		Sol._petit_chapeau(ci, a.lerp(b, 0.3 + 0.15 * i) + nn * 1.7, 3.0 + i, etat == "ravive")


## Roseaux : touffe haute de tiges fines et de massettes, au bord de l'eau.
static func _roseaux(ci: CanvasItem, at: Vector2, h: float, r: RandomNumberGenerator, P: Callable, etat: String, k: float) -> void:
	var c1: Color = O.fg(Art.mc("spore", etat, "touffe"), k)
	var c2: Color = O.fg(Art.mc("spore", etat, "touffe_2"), k)
	var bois: Dictionary = P.call("bois")
	for i in r.randi_range(9, 13):
		var u := r.randf_range(-1.0, 1.0)
		var b := at + Vector2(u * h * 0.2, r.randf_range(-2, 2))
		var hh := h * r.randf_range(0.6, 1.0) * (1.0 - 0.3 * absf(u))
		var tip := b + Vector2(u * h * 0.25 + r.randf_range(-6, 6), -hh)
		O.brush(ci, O.curve(b, b + Vector2(0, -hh * 0.6), tip), 2.2, c1 if i % 2 else c2, 1.0, 0.0)
		if i % 3 == 0:
			var d := (tip - b).normalized()
			O.brush(ci, PackedVector2Array([tip - d * 4.0, tip - d * 14.0]), 4.5, bois["ombre"], 1.0, 1.0)


## Fougère du Marais : frondes en éventail (sèches et pâles flétries, vertes ravivées).
static func _fougere(ci: CanvasItem, at: Vector2, h: float, r: RandomNumberGenerator, P: Callable, etat: String, k: float) -> void:
	var leaf: Dictionary = P.call("feuillage")
	for i in 7:
		var a := -PI * 0.5 + (i - 3) * 0.32 + r.randf_range(-0.08, 0.08)
		var tip := at + Vector2.from_angle(a) * h * r.randf_range(0.85, 1.1) * Vector2(1.3, 1.0)
		var mid := at.lerp(tip, 0.5) + Vector2(0, -h * 0.15)
		var spine := O.curve(at, mid, tip, 8)
		O.brush(ci, spine, 1.4, leaf["ombre"], 1.0, 0.0)
		for j in range(1, 8):
			var t := (spine[j + 1] - spine[j - 1]).normalized()
			var l := h * 0.16 * (1.0 - j / 9.0)
			for sd in [-1.0, 1.0]:
				var pin := O.Ink.leaf(spine[j], (t.orthogonal() * sd + t * 0.4).angle(), l, l * 0.42)
				O.poly(ci, pin, leaf["clair"] if sd < 0 else leaf["ombre"])
