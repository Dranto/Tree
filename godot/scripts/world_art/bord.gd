## Bord du monde, style « Paysages d'herbier » (refonte du monde, vague 3 K) : ce qui se dessine au-delà
## du carré du monde, région par région, flétri ou ravivé. world_edge_painter.gd décide où (champ de
## distance au bord, régions, tuiles) ; ce fichier dit quoi et comment.
##
##   - Roncier : le sol se défait en ronces, puis un mur de ronces en arceaux, de plus en plus haut ;
##   - Marais : une berge de vase et de roseaux, puis l'eau (nénuphars, chapeaux géants) ;
##   - Plateaux : des dalles au ras du vide, la falaise (vue de face au sud), une mer de nuages ;
##   - Vallée : un talus moussu et ses fougères, puis la vallée vue d'en haut (cimes de saules, ruisseaux) ;
##   - Falaises : une arête de calcaire hérissée de cristaux, puis un ciel doré semé d'éclats qui flottent ;
##   - Forêt : des arceaux de racines, puis une futaie de troncs de pierre qui se resserre.
##
## Grammaire commune (world_art/outils.gd, creature_art/ink.gd lu sans le modifier) : lumière d'en haut à
## gauche, deux tons et un reflet, encre fine, ombre portée vers le bas à droite ; couleurs de Art.MONDE.
## « etat » vaut "fletri" (le Cœur de la région vit) ou "ravive" (purifiée : le bord reverdit).
## Aucun texte, aucune collision : dessin seul.
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const FO = preload("res://scripts/world_art/falaise_outils.gd")
const Decor = preload("res://scripts/world_art/decor.gd")

## Sortes d'éléments : région, bande de distance au bord [e0, e1] (px, négatif dans le monde), nombre
## de tirages par tuile de 1000 px, « detail » (omis sur la carte), « bias » (tirage resserré vers e0).
const KINDS := [
	# Communs : le sol qui se défait vers le bord (miettes, touffes), pour chaque région.
	{"id": "miettes", "region": "*", "e0": -160.0, "e1": -6.0, "n": 46, "detail": true, "bias": 0.7},
	{"id": "touffe", "region": "*", "e0": -130.0, "e1": -4.0, "n": 16, "detail": true, "bias": 0.8},
	# Roncier.
	{"id": "ronce_rampe", "region": "ronce", "e0": -90.0, "e1": 10.0, "n": 22, "detail": true, "bias": 0.6},
	{"id": "ronce_haie", "region": "ronce", "e0": 10.0, "e1": 150.0, "n": 26},
	{"id": "ronce_masse", "region": "ronce", "e0": 110.0, "e1": 1500.0, "n": 46, "bias": 1.5},
	{"id": "ronce_arceau", "region": "ronce", "e0": 140.0, "e1": 1100.0, "n": 12, "bias": 1.3},
	{"id": "ronce_arbre", "region": "ronce", "e0": 260.0, "e1": 1000.0, "n": 2},
	# Marais.
	{"id": "roseaux", "region": "spore", "e0": -30.0, "e1": 45.0, "n": 20},
	{"id": "nenuphar", "region": "spore", "e0": 40.0, "e1": 1300.0, "n": 46, "bias": 1.4},
	{"id": "reflet", "region": "spore", "e0": 30.0, "e1": 1500.0, "n": 60, "detail": true},
	{"id": "souche", "region": "spore", "e0": 120.0, "e1": 800.0, "n": 2},
	{"id": "chapeau_geant", "region": "spore", "e0": 260.0, "e1": 1400.0, "n": 4},
	{"id": "champignon", "region": "spore", "e0": 60.0, "e1": 700.0, "n": 6},
	# Plateaux.
	{"id": "dalle", "region": "vent", "e0": -46.0, "e1": 2.0, "n": 30},
	{"id": "herbe_vent", "region": "vent", "e0": -130.0, "e1": 0.0, "n": 26, "detail": true},
	{"id": "nuage", "region": "vent", "e0": 150.0, "e1": 2000.0, "n": 32, "bias": 1.3},
	{"id": "ile", "region": "vent", "e0": 360.0, "e1": 1500.0, "n": 3},
	{"id": "plume", "region": "vent", "e0": 60.0, "e1": 900.0, "n": 10, "detail": true},
	# Vallée.
	{"id": "fougere", "region": "seve", "e0": -60.0, "e1": 6.0, "n": 22},
	{"id": "mousse", "region": "seve", "e0": -140.0, "e1": -4.0, "n": 18, "detail": true},
	{"id": "cime", "region": "seve", "e0": 190.0, "e1": 1900.0, "n": 72, "bias": 1.15},
	{"id": "ruisseau", "region": "seve", "e0": 260.0, "e1": 1500.0, "n": 4},
	# Falaises.
	{"id": "bloc", "region": "aube", "e0": -40.0, "e1": 8.0, "n": 14},
	{"id": "cristaux", "region": "aube", "e0": -60.0, "e1": 20.0, "n": 9},
	{"id": "eclat", "region": "aube", "e0": 140.0, "e1": 1800.0, "n": 34, "bias": 1.2},
	{"id": "rayon", "region": "aube", "e0": 60.0, "e1": 500.0, "n": 6, "detail": true},
	{"id": "brume", "region": "aube", "e0": 100.0, "e1": 1600.0, "n": 14},
	# Forêt.
	{"id": "racines", "region": "racine", "e0": -40.0, "e1": 70.0, "n": 12},
	{"id": "feuilles", "region": "racine", "e0": -150.0, "e1": 30.0, "n": 30, "detail": true},
	{"id": "tronc", "region": "racine", "e0": 60.0, "e1": 1500.0, "n": 30, "bias": 1.3},
	{"id": "fut_mort", "region": "racine", "e0": -60.0, "e1": 0.0, "n": 4},
]

## Hauteur de la falaise vue de face (px), quand le bord regarde vers le bas de l'écran.
const FACE := {"vent": 230.0, "seve": 170.0, "aube": 210.0}


# --- Couleurs ---

static func pal(rid: String, etat: String, key: String) -> Dictionary:
	var m: Dictionary = Art.MONDE.get(rid, {})
	var src: Dictionary = m.get(etat, {})
	if src.has(key):
		return src[key]
	if Art.MONDE["commun"].has(key):
		return Art.MONDE["commun"][key]
	return Art.MONDE["ronce"][etat if Art.MONDE["ronce"].has(etat) else "fletri"].get(key, Art.MONDE["ronce"]["fletri"]["pierre"])


static func col(rid: String, etat: String, key: String) -> Color:
	var m: Dictionary = Art.MONDE.get(rid, {})
	var src: Dictionary = m.get(etat, {})
	if src.has(key) and src[key] is Color:
		return src[key]
	var f: Dictionary = m.get("fletri", {})
	if f.has(key) and f[key] is Color:
		return f[key]
	return Art.MONDE["ronce"]["fletri"].get(key, Color(0.3, 0.25, 0.25))


## Fond au-delà du bord : [près du bord, au loin]. Tons de la région (Art.MONDE), assombris.
static func wash(rid: String, etat: String) -> Array:
	var v := etat == "ravive"
	match rid:
		"spore":
			var eau := col(rid, etat, "eau")
			if etat != "ravive":
				eau = eau.lerp(Color("1c2636"), 0.45)
			return [eau, eau.darkened(0.55)]
		"vent":
			return [Color("8798ab") if v else Color("3a414d"), Color("4a5f74") if v else Color("12161d")]
		"seve":
			return [pal(rid, etat, "feuillage")["ombre"].darkened(0.35), Color("0f2a22") if v else Color("0c1511")]
		"aube":
			return [Color("c9a050") if v else Color("645b52"), Color("6e4a14") if v else Color("1c1714")]
		"racine":
			return [pal(rid, etat, "bois")["ombre"].darkened(0.3), Color("2a1c10") if v else Color("100c0a")]
		_:
			var ron: Dictionary = pal("ronce", etat, "ronce")
			return [ron["ombre"].darkened(0.3), Color("1c2412") if v else Color("0e0709")]


## Couleur du fond à la distance e du bord (e < 0 : dans le monde, un voile qui assombrit le sol vers le
## bord ; e ≥ 0 : le fond, opaque).
static func base(rid: String, etat: String, e: float) -> Color:
	var w := wash(rid, etat)
	if e < 0.0:
		var dark: Color = col(rid, etat, "sol_sombre").darkened(0.35)
		return Color(dark, 0.5 * smoothstep(-160.0, -4.0, e))
	return (w[0] as Color).lerp(w[1], smoothstep(0.0, 1500.0, e))


## Voile de profondeur posé sur le décor : le loin se perd dans le ton du fond.
static func veil(rid: String, etat: String, e: float) -> Color:
	var w := wash(rid, etat)
	var k := 0.92 if rid != "aube" else 0.8
	return Color(w[1], k * smoothstep(160.0, 1700.0, e))


# --- Le bord lui-même (bande continue le long du bord) ---

## Un pas du bord, de a à b (points du bord, px du monde), normale sortante na/nb. Dessiné tuile par tuile
## avec un léger recouvrement : aucune couture.
static func strip(ci: CanvasItem, rid: String, etat: String, a: Vector2, b: Vector2, na: Vector2, nb: Vector2, lod: int) -> void:
	var h: float = FACE.get(rid, 0.0)
	var fa := h * clampf((na.y - 0.15) / 0.85, 0.0, 1.0)
	var fb := h * clampf((nb.y - 0.15) / 0.85, 0.0, 1.0)
	match rid:
		"spore":
			# Berge : bande de vase, puis le liseré de l'eau.
			var mud := col(rid, etat, "sol_sombre")
			O.poly(ci, PackedVector2Array([a - na * 22.0, b - nb * 22.0, b + nb * 6.0, a + na * 6.0]), mud.darkened(0.15))
			O.poly(ci, PackedVector2Array([a - na * 10.0, b - nb * 10.0, b + nb * 2.0, a + na * 2.0]), mud.darkened(0.35))
			if lod == 0:
				ci.draw_line(a + na * 5.0, b + nb * 5.0, Color(col(rid, etat, "eau_reflet"), 0.55), 1.6, true)
				ci.draw_line(a + na * 13.0, b + nb * 13.0, Color(col(rid, etat, "eau_reflet"), 0.18), 1.0, true)
		"vent", "seve", "aube":
			var rock: Dictionary = pal(rid, etat, "pierre" if rid != "aube" else "roche")
			if rid == "seve":
				rock = {"clair": col(rid, etat, "sol"), "ombre": col(rid, etat, "sol_sombre"), "reflet": col(rid, etat, "sol_clair")}
			if fa > 1.0 or fb > 1.0:
				var face := PackedVector2Array([a, b, b + Vector2(0, fb), a + Vector2(0, fa)])
				O.poly(ci, face, rock["ombre"].darkened(0.2))
				# Strates (ou racines pendantes dans la Vallée), qui se perdent vers le bas.
				for k in 4:
					var t := (k + 1) / 5.0
					var c := Color(rock["ombre"].darkened(0.45), 0.55 * (1.0 - t * 0.6))
					ci.draw_line(a + Vector2(0, fa * t), b + Vector2(0, fb * t), c, 1.4, true)
				O.poly(ci, PackedVector2Array([a, b, b + Vector2(0, fb * 0.18), a + Vector2(0, fa * 0.18)]), Color(rock["clair"], 0.35))
				# Bas de la falaise : le vide ou la vallée la mangent.
				var bot := Color(wash(rid, etat)[0], 0.0)
				var bc := wash(rid, etat)[0] as Color
				ci.draw_polygon(PackedVector2Array([a + Vector2(0, fa * 0.55), b + Vector2(0, fb * 0.55), b + Vector2(0, fb + 2.0), a + Vector2(0, fa + 2.0)]), PackedColorArray([bot, bot, bc, bc]))
			# Rebord vu de côté (falaise qui ne regarde pas vers le bas) : une bande de roche striée.
			if fa <= 1.0 and fb <= 1.0:
				O.poly(ci, PackedVector2Array([a, b, b + nb * 14.0, a + na * 14.0]), rock["ombre"].darkened(0.1))
				ci.draw_line(a + na * 7.0, b + nb * 7.0, Color(rock["ombre"].darkened(0.4), 0.6), 1.2, true)
				ci.draw_line(a + na * 14.0, b + nb * 14.0, Color(0, 0, 0, 0.35), 2.0, true)
			# Arête : ligne d'encre et liseré clair.
			ci.draw_line(a + na * 1.5, b + nb * 1.5, Ink.encre(), 2.0, true)
			ci.draw_line(a - na * 1.0, b - nb * 1.0, Color(rock["reflet"], 0.8), 1.6, true)
		"racine":
			O.poly(ci, PackedVector2Array([a - na * 8.0, b - nb * 8.0, b + nb * 30.0, a + na * 30.0]), pal(rid, etat, "bois")["ombre"].darkened(0.4))
		_:
			O.poly(ci, PackedVector2Array([a - na * 6.0, b - nb * 6.0, b + nb * 26.0, a + na * 26.0]), pal("ronce", etat, "ronce")["ombre"].darkened(0.35))


# --- Les éléments ---

## Dessine l'élément « kind » au pied p (px du monde). r : son tirage ; nrm : normale sortante du bord ;
## cap : hauteur à ne pas dépasser (près du bord sud, rien de haut ne doit monter devant le héros) ;
## lod : 0 en jeu, 1 sur la carte (formes simples).
static func draw(ci: CanvasItem, kind: String, p: Vector2, r: RandomNumberGenerator, rid: String, etat: String, e: float, nrm: Vector2, cap: float, lod: int) -> void:
	var v := etat == "ravive"
	match kind:
		"miettes":
			_miettes(ci, p, r, rid, etat, e)
		"touffe":
			var h := minf(r.randf_range(9.0, 17.0), cap)
			O.tuft(ci, p, h, col(rid, etat, "touffe"), col(rid, etat, "touffe_2"), r.randi(), not v)
			if v and r.randf() < 0.4:
				O.flower(ci, p + Vector2(r.randf_range(-6, 6), -h * 0.6), 2.4, col(rid, "ravive", "fleur"), col(rid, "ravive", "fleur_coeur") if Art.MONDE.get(rid, {}).get("ravive", {}).has("fleur_coeur") else Color("ffe2a0"), r.randf() * TAU)
		"ronce_rampe":
			_rampe(ci, p, r, etat)
		"ronce_haie":
			_masse(ci, p, r, etat, -420.0 if cap > 200.0 else -650.0, lod)
		"ronce_masse":
			_masse(ci, p, r, etat, e, lod)
		"ronce_arceau":
			_arceau(ci, p, r, etat, minf(r.randf_range(170.0, 320.0), cap), lod)
		"ronce_arbre":
			_decor(ci, "arbre", p, r, "ronce", etat, minf(r.randf_range(1.1, 1.5), cap / 172.5), lod)
		"roseaux":
			_decor(ci, "roseaux", p, r, "spore", etat, minf(r.randf_range(0.8, 1.2), cap / 58.5), lod)
		"nenuphar":
			_nenuphar(ci, p, r, etat, e, lod)
		"reflet":
			var l := r.randf_range(40.0, 140.0)
			var ra := Color(col("spore", etat, "eau_reflet"), 0.26)
			O.brush(ci, PackedVector2Array([p - Vector2(l, 0), p + Vector2(0, r.randf_range(-2, 2)), p + Vector2(l, 0)]), 1.8, ra, 0.0, 0.0)
			if r.randf() < 0.5:
				O.brush(ci, PackedVector2Array([p + Vector2(-l * 0.5, 6), p + Vector2(l * 0.4, 7)]), 1.2, Color(ra, 0.14), 0.0, 0.0)
		"souche":
			_decor(ci, "tronc", p, r, "spore", etat, minf(r.randf_range(0.55, 0.8), cap / 33.0), lod)
		"chapeau_geant":
			_reflet_eau(ci, p, r.randf_range(70.0, 110.0), etat)
			_decor(ci, "chapeau_geant", p, r, "spore", etat, minf(r.randf_range(0.9, 1.4), cap / 247.5), lod)
		"champignon":
			_reflet_eau(ci, p, 30.0, etat)
			_decor(ci, "champignon", p, r, "spore", etat, minf(r.randf_range(0.35, 0.6), cap / 142.5), lod)
		"dalle":
			_dalle(ci, p, r, etat)
		"herbe_vent":
			_herbe_vent(ci, p, r, etat, minf(r.randf_range(12.0, 22.0), cap))
		"nuage":
			_nuage(ci, p, r, etat, e, lod)
		"ile":
			_ile(ci, p, r, etat, lod)
		"plume":
			if v:
				_plume(ci, p, r)
		"fougere":
			_decor(ci, "fougere", p, r, "seve", etat, minf(r.randf_range(0.8, 1.3), cap / 39.0), lod)
		"mousse":
			var sc: Dictionary = Art.MONDE["seve"]["sol_couches"]
			var c1: Color = sc["mousse"] if v else sc["vase"]
			var c2: Color = sc["mousse_claire"] if v else sc["croute"]
			O.poly(ci, O.blob(p, r.randf_range(10, 22), r.randf_range(5, 9), p.x, 0.25, 16), c1)
			O.poly(ci, O.blob(p + Vector2(-2, -2), r.randf_range(5, 10), r.randf_range(3, 5), p.y, 0.25, 12), c2)
		"cime":
			_cime(ci, p, r, etat, e, lod)
		"ruisseau":
			_ruisseau(ci, p, r, etat)
		"bloc":
			FO.block(ci, p, r.randf_range(18.0, 34.0), minf(r.randf_range(16.0, 30.0), cap), r, etat)
		"cristaux":
			if cap > 30.0:
				FO.crystal_group(ci, p, r.randf_range(30.0, 60.0), minf(r.randf_range(50.0, 100.0), cap), r.randi_range(3, 6), r, etat)
			else:
				FO.block(ci, p, 22.0, minf(20.0, cap), r, etat)
		"eclat":
			_eclat(ci, p, r, etat, e, lod)
		"brume":
			# Bancs de brume dorée qui flottent sous la falaise.
			var w := r.randf_range(220.0, 460.0)
			var c1 := Color("fff1c2") if v else Color("8c8276")
			O.poly(ci, O.blob(p, w, w * 0.16, p.x, 0.25, 22), Color(c1, 0.16 if v else 0.13))
			O.poly(ci, O.blob(p + Vector2(-w * 0.1, -w * 0.03), w * 0.6, w * 0.08, p.y, 0.25, 18), Color(c1, 0.2 if v else 0.15))
		"rayon":
			var l := r.randf_range(400.0, 800.0)
			var s := r.randf_range(40.0, 110.0)
			var dir := (nrm + Vector2(r.randf_range(-0.3, 0.3), r.randf_range(-0.3, 0.3))).normalized()
			var side := dir.orthogonal()
			var c := Color(col("aube", "ravive", "lueur") if v else Color("b0a090"), 0.09 if v else 0.05)
			O.poly(ci, PackedVector2Array([p - side * 4.0, p + side * 4.0, p + dir * l + side * s, p + dir * l - side * s]), c)
		"racines":
			_racines(ci, p, r, etat, nrm, minf(r.randf_range(40.0, 90.0), cap), lod)
		"feuilles":
			for i in r.randi_range(2, 4):
				var q := p + Vector2(r.randf_range(-10, 10), r.randf_range(-5, 5))
				O.poly(ci, Ink.leaf(q, r.randf() * TAU, r.randf_range(6.0, 9.0), 3.6), col("racine", etat, "feuille" if i % 2 else "feuille_2"))
		"tronc":
			_tronc_pierre(ci, p, r, etat, e, minf(r.randf_range(230.0, 420.0), cap), lod)
		"fut_mort":
			_tronc_pierre(ci, p, r, etat, e, minf(r.randf_range(24.0, 46.0), cap), lod, true)


## Une sorte du décor du monde (world_art/decor.gd), dans l'état voulu.
class M:
	var rid := ""
	var etat := ""

	func region_at(_p: Vector2) -> String:
		return rid

	func decor_etat_at(_p: Vector2) -> String:
		return etat


static func _decor(ci: CanvasItem, kind: String, p: Vector2, r: RandomNumberGenerator, rid: String, etat: String, size: float, lod: int) -> void:
	if size < 0.2:
		return
	var m := M.new()
	m.rid = rid
	m.etat = etat
	if lod > 0:
		var h: float = Decor.HEIGHT.get(kind, 60.0) * size
		O.poly(ci, O.blob(p + Vector2(0, -h * 0.4), h * 0.4, h * 0.4, p.x, 0.2, 12), pal(rid, etat, "feuillage")["ombre"])
		return
	Decor.draw(ci, {"kind": kind, "at": p, "size": size, "seed": r.randi(), "flip": r.randf() < 0.5}, m)


static func _miettes(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, rid: String, etat: String, e: float) -> void:
	var k := r.randi() % 3
	# Plus on approche du bord, plus le sol se fend.
	if k == 0 or (k == 1 and e > -60.0):
		var a := p
		var pts := PackedVector2Array([a])
		var dir := Vector2.from_angle(r.randf() * TAU)
		for i in 4:
			a += (dir + Vector2(r.randf_range(-0.6, 0.6), r.randf_range(-0.6, 0.6))).normalized() * r.randf_range(8.0, 16.0)
			pts.append(a)
		O.brush(ci, pts, r.randf_range(1.4, 2.4), col(rid, etat, "matiere"), 0.3, 0.0)
	elif k == 1:
		O.pebble(ci, p, r.randf_range(2.5, 5.5), pal(rid, etat, "pierre"), p.x)
	else:
		O.poly(ci, Ink.leaf(p, r.randf() * TAU, r.randf_range(5.0, 8.0), 3.0), col(rid, etat, "feuille" if r.randf() < 0.5 else "feuille_2"))


# --- Roncier ---

## Tige de ronce qui rampe sur le sol, vers le monde.
static func _rampe(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String) -> void:
	var ron: Dictionary = pal("ronce", etat, "ronce")
	var a := p
	var b := p + Vector2.from_angle(r.randf() * TAU) * r.randf_range(40.0, 90.0)
	var pts := O.curve(a, a.lerp(b, 0.5) + Vector2(r.randf_range(-20, 20), r.randf_range(-12, 12)), b, 8)
	O.brush(ci, pts, 3.6, Ink.encre(), 1.0, 0.0)
	O.brush(ci, pts, 2.6, ron["ombre"], 1.0, 0.0)
	O.brush(ci, pts, 1.0, ron["clair"], 1.0, 0.0)
	for j in range(1, 8, 2):
		var t := (pts[j + 1] - pts[j - 1]).normalized()
		var nn := t.orthogonal() * (1.0 if j % 4 == 1 else -1.0)
		O.poly(ci, Ink.thorn(pts[j], (nn + t * 0.5).angle(), 4.0, 1.8), Ink.encre())
	if etat == "ravive" and r.randf() < 0.5:
		O.poly(ci, Ink.leaf(pts[4], r.randf() * TAU, 8.0, 4.0), col("ronce", "ravive", "feuille_2"))


## Masse du mur de ronces : un fourré de feuillage serré, hérissé de tiges ; plus loin, plus haut.
static func _masse(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String, e: float, lod: int) -> void:
	var ron: Dictionary = pal("ronce", etat, "ronce")
	var leaf: Dictionary = pal("ronce", etat, "feuillage")
	var s := r.randf_range(80.0, 140.0) * (1.0 + e / 1000.0)
	var c := p + Vector2(0, -s * 0.55)
	var mixk := 0.5 if etat == "ravive" else 0.2
	var dark := {"clair": ron["clair"].lerp(leaf["clair"], mixk), "ombre": ron["ombre"].lerp(leaf["ombre"], mixk).darkened(0.1), "reflet": ron["reflet"].lerp(leaf["reflet"], mixk).darkened(0.15)}
	if lod > 0:
		O.poly(ci, Ink.lumpy(c, s * 1.2, s * 0.8, 18, 0.15, 9.0, p.x), dark["ombre"])
		return
	O.cast_shadow(ci, p, s * 1.8, s * 0.8, 0.3)
	O.part(ci, Ink.lumpy(c, s * 1.25, s * 0.85, 30, 0.16, 11.0, p.x * 0.01), dark, 1.4, 1.0, 0.35)
	# Tiges qui sortent du fourré.
	for i in r.randi_range(3, 5):
		var a := c + Vector2(r.randf_range(-0.9, 0.9) * s, r.randf_range(-0.3, 0.5) * s)
		var d := r.randf_range(0.5, 1.0) * (1.0 if r.randf() < 0.5 else -1.0)
		var top := a + Vector2(d * s * 0.4, -s * r.randf_range(0.5, 0.9))
		var end := a + Vector2(d * s * 0.95, -s * r.randf_range(0.0, 0.3))
		_cane(ci, O.curve(a, top, end, 10), 3.0, ron)
	if etat == "ravive":
		for i in r.randi_range(4, 8):
			var q := c + Vector2(r.randf_range(-1.0, 1.0) * s, r.randf_range(-0.7, 0.4) * s * 0.85)
			if i % 3 == 0:
				for b in 3:
					ci.draw_circle(q + Vector2(b * 2.4 - 2.4, (b % 2) * 2.0), 2.1, col("ronce", "ravive", "fruit"))
			else:
				O.flower(ci, q, r.randf_range(3.0, 4.4), col("ronce", "ravive", "fleur" if i % 4 else "fleur_2"), col("ronce", "ravive", "fleur_coeur"), r.randf() * TAU)
	elif r.randf() < 0.35:
		var q := c + Vector2(r.randf_range(-0.5, 0.5) * s, r.randf_range(-0.2, 0.3) * s)
		ci.draw_circle(q, 6.0, Color(Art.bc("braise"), 0.12))
		ci.draw_circle(q, 1.6, Art.bc("braise"))


## Une tige de ronce (encre, deux tons) hérissée d'épines.
static func _cane(ci: CanvasItem, pts: PackedVector2Array, w: float, ron: Dictionary) -> void:
	O.brush(ci, pts, w + 1.6, Ink.encre(), 0.7, 0.0)
	O.brush(ci, pts, w, ron["ombre"], 0.7, 0.0)
	O.brush(ci, pts, w * 0.4, ron["clair"], 0.7, 0.0)
	var n := pts.size()
	for j in range(2, n - 1, 2):
		var t := (pts[j + 1] - pts[j - 1]).normalized()
		var nn := t.orthogonal() * (1.0 if j % 4 == 0 else -1.0)
		O.poly(ci, Ink.thorn(pts[j], (nn + t * 0.45).angle(), w * 1.7, w * 0.8), Ink.encre())


## Grand arceau de ronce : une tige énorme qui monte et retombe, le mur vu de loin.
static func _arceau(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String, h: float, lod: int) -> void:
	if h < 40.0:
		return
	var ron: Dictionary = pal("ronce", etat, "ronce")
	var d := r.randf_range(0.5, 0.9) * (1.0 if r.randf() < 0.5 else -1.0)
	var top := p + Vector2(d * h * 0.35, -h)
	var end := p + Vector2(d * h * 0.95, -h * r.randf_range(0.1, 0.35))
	var pts := O.curve(p, top, end, 14)
	if lod > 0:
		O.brush(ci, pts, 10.0, ron["ombre"], 0.8, 0.0)
		return
	_cane(ci, pts, r.randf_range(8.0, 12.0), ron)
	if etat == "ravive":
		for j in range(3, 13, 3):
			O.part(ci, Ink.leaf(pts[j], r.randf() * TAU, 14.0, 7.0, 0.1), pal("ronce", "ravive", "feuillage"), 0.8, 1.0, 0.0)
		O.flower(ci, pts[12], 5.0, col("ronce", "ravive", "fleur"), col("ronce", "ravive", "fleur_coeur"), r.randf() * TAU)


# --- Marais ---

static func _reflet_eau(ci: CanvasItem, p: Vector2, w: float, etat: String) -> void:
	O.poly(ci, O.blob(p + Vector2(w * 0.1, w * 0.12), w * 0.75, w * 0.18, p.x, 0.25, 18), Color(0.02, 0.02, 0.05, 0.35))
	ci.draw_arc(p + Vector2(0, 4), w * 0.7, 0.2, PI - 0.2, 14, Color(col("spore", etat, "eau_reflet"), 0.35), 1.2, true)


static func _nenuphar(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String, e: float, lod: int) -> void:
	var leaf: Dictionary = pal("spore", etat, "feuillage")
	var rx := r.randf_range(11.0, 26.0) * (1.0 + e / 1600.0)
	var rot := r.randf_range(-0.3, 0.3)
	var pts := PackedVector2Array()
	var notch := r.randf() * TAU
	for i in 22:
		var a := TAU * i / 22.0
		var dd := absf(fposmod(a - notch + PI, TAU) - PI)
		var k := 0.25 if dd < 0.22 else 1.0
		pts.append(p + Vector2(cos(a) * rx * k, sin(a) * rx * 0.55 * k).rotated(rot))
	if lod > 0:
		O.poly(ci, pts, leaf["ombre"])
		return
	O.poly(ci, O.blob(p + Vector2(2, 3), rx, rx * 0.5, p.x, 0.05, 16, rot), Color(0.02, 0.03, 0.05, 0.35))
	O.part(ci, pts, leaf, 1.0, 1.0, 0.4)
	ci.draw_arc(p, rx * 1.35, 0.0, PI, 16, Color(col("spore", etat, "eau_reflet"), 0.2), 1.0, true)
	if etat == "ravive" and r.randf() < 0.3:
		O.flower(ci, p + Vector2(rx * 0.2, -rx * 0.15), rx * 0.32, col("spore", "ravive", "fleur_2"), col("spore", "ravive", "fleur_coeur"), r.randf() * TAU)
	elif etat == "ravive" and r.randf() < 0.3:
		ci.draw_circle(p, rx * 0.9, Color(col("spore", "ravive", "lueur"), 0.07))


# --- Plateaux ---

static func _dalle(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String) -> void:
	var st: Dictionary = pal("vent", etat, "pierre")
	var w := r.randf_range(18.0, 36.0)
	var h := w * r.randf_range(0.35, 0.5)
	var pts := PackedVector2Array()
	for i in 7:
		var a := TAU * i / 7.0 + r.randf_range(-0.2, 0.2)
		pts.append(p + Vector2(cos(a) * w, sin(a) * h - h * 0.4) * r.randf_range(0.85, 1.1))
	O.cast_shadow(ci, p, w * 1.2, h, 0.25)
	O.part(ci, pts, st, 1.2, 1.0, 0.5)
	# Épaisseur de la dalle (bord avant).
	O.poly(ci, PackedVector2Array([p + Vector2(-w * 0.8, h * 0.15), p + Vector2(w * 0.85, h * 0.1), p + Vector2(w * 0.8, h * 0.45), p + Vector2(-w * 0.75, h * 0.5)]), st["ombre"].darkened(0.25))
	if r.randf() < 0.6:
		O.poly(ci, O.blob(p + Vector2(r.randf_range(-0.4, 0.4) * w, -h * 0.5), w * 0.25, h * 0.25, p.x, 0.3, 12), Color(col("vent", etat, "lichen"), 0.8))


static func _herbe_vent(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String, h: float) -> void:
	var hb: Dictionary = pal("vent", etat, "herbe")
	for i in r.randi_range(6, 10):
		var u := r.randf_range(-1.0, 1.0)
		O.blade(ci, p + Vector2(u * h * 0.3, 0), h * r.randf_range(0.6, 1.0), 0.75 + r.randf_range(-0.15, 0.2), maxf(1.2, h * 0.09), hb["clair"] if i % 2 else hb["ombre"])
	if etat == "ravive" and r.randf() < 0.35:
		O.flower(ci, p + Vector2(h * 0.4, -h * 0.7), 2.6, col("vent", "ravive", "fleur"), col("vent", "ravive", "fleur_coeur"), r.randf() * TAU)


## Banc de nuages : boules serrées, dessous ombré, dessus éclairé.
static func _nuage(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String, e: float, lod: int) -> void:
	var v := etat == "ravive"
	var lit := Color("eef3f8") if v else Color("7a828e")
	var mid := Color("c2cfdc") if v else Color("4d5562")
	var shade := Color("8da2b8") if v else Color("323943")
	var w := r.randf_range(140.0, 300.0) * (1.0 + e / 2000.0)
	var balls := []
	for i in r.randi_range(5, 8):
		var u := r.randf_range(-1.0, 1.0)
		balls.append([p + Vector2(u * w * 0.55, -w * 0.12 * (1.0 - u * u) + r.randf_range(-10, 10)), w * r.randf_range(0.2, 0.32) * (1.0 - 0.35 * absf(u))])
	balls.sort_custom(func(x, y): return x[0].y < y[0].y)
	if lod > 0:
		O.poly(ci, O.blob(p + Vector2(0, -w * 0.1), w * 0.65, w * 0.22, p.x, 0.2, 18), mid)
		return
	# Ombre sur la mer de nuages, dessous.
	O.poly(ci, O.blob(p + Vector2(w * 0.08, w * 0.06), w * 0.75, w * 0.12, p.x, 0.2, 20), Color(shade.darkened(0.3), 0.35))
	for b in balls:
		O.poly(ci, O.blob(b[0], b[1], b[1] * 0.62, b[0].x, 0.12, 18), shade)
	for b in balls:
		O.poly(ci, O.blob(b[0] + Vector2(-b[1] * 0.08, -b[1] * 0.12), b[1] * 0.9, b[1] * 0.5, b[0].y, 0.12, 18), mid)
	for b in balls:
		O.poly(ci, O.blob(b[0] + Vector2(-b[1] * 0.22, -b[1] * 0.26), b[1] * 0.55, b[1] * 0.28, b[0].x + 3.0, 0.12, 14), Color(lit, 0.9))


## Île de roche qui flotte au-dessus des nuages (herbe dessus, ombre portée loin dessous).
static func _ile(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String, lod: int) -> void:
	var st: Dictionary = pal("vent", etat, "pierre")
	var w := r.randf_range(40.0, 80.0)
	var lift := r.randf_range(60.0, 110.0)
	var c := p + Vector2(0, -lift)
	O.poly(ci, O.blob(p + Vector2(w * 0.3, 0), w * 0.9, w * 0.2, p.x, 0.2, 16), Color(0.05, 0.07, 0.1, 0.25))
	var pts := PackedVector2Array([c + Vector2(-w, 0), c + Vector2(-w * 0.6, -w * 0.18), c + Vector2(w * 0.5, -w * 0.2), c + Vector2(w, 0), c + Vector2(w * 0.3, w * 0.55), c + Vector2(-w * 0.05, w * 0.95), c + Vector2(-w * 0.45, w * 0.5)])
	if lod > 0:
		O.poly(ci, pts, st["ombre"])
		return
	O.part(ci, pts, st, 1.4, 0.9, 0.4)
	var hb: Dictionary = pal("vent", etat, "herbe")
	O.poly(ci, O.blob(c + Vector2(0, -w * 0.1), w * 0.95, w * 0.2, c.x, 0.15, 18), hb["ombre"])
	for i in 6:
		O.blade(ci, c + Vector2(r.randf_range(-0.8, 0.8) * w, -w * 0.08), r.randf_range(8, 16), 0.7, 1.6, hb["clair"])


static func _plume(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator) -> void:
	var a := r.randf() * TAU
	var l := r.randf_range(7.0, 12.0)
	O.poly(ci, Ink.leaf(p, a, l, l * 0.35, 0.1), col("vent", "ravive", "plume"))
	ci.draw_line(p, p + Vector2.from_angle(a) * l, col("vent", "ravive", "plume_ombre"), 0.8, true)


# --- Vallée ---

## Cime de saule vue d'en haut : grappe de masses rondes, des mèches qui pendent.
static func _cime(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String, e: float, lod: int) -> void:
	var sa: Dictionary = pal("seve", etat, "saule")
	if etat != "ravive":
		sa = {"clair": sa["clair"].darkened(0.3), "ombre": sa["ombre"].darkened(0.3), "reflet": sa["reflet"].darkened(0.35)}
	var s := r.randf_range(42.0, 90.0) * (1.0 + e / 2200.0)
	var c := p + Vector2(0, -s * 0.4)
	if lod > 0:
		O.poly(ci, O.blob(c, s, s * 0.8, p.x, 0.2, 16), sa["ombre"])
		return
	O.poly(ci, O.blob(c + Vector2(s * 0.25, s * 0.3), s * 1.05, s * 0.6, p.x, 0.15, 20), Color(0.02, 0.05, 0.04, 0.4))
	var masses := []
	for i in r.randi_range(4, 7):
		var a := r.randf() * TAU
		masses.append([c + Vector2(cos(a), sin(a) * 0.7) * s * r.randf_range(0.2, 0.55), s * r.randf_range(0.38, 0.55)])
	masses.sort_custom(func(x, y): return x[0].y < y[0].y)
	for ms in masses:
		O.part(ci, Ink.lumpy(ms[0], ms[1], ms[1] * 0.82, 22, 0.14, 9.0, ms[0].x), sa, 1.2, 1.0, 0.55)
	# Mèches qui pendent sur le côté sombre.
	for i in r.randi_range(5, 8):
		var q: Vector2 = c + Vector2(r.randf_range(-0.2, 0.9) * s, r.randf_range(0.1, 0.6) * s)
		O.brush(ci, PackedVector2Array([q, q + Vector2(r.randf_range(-3, 3), s * 0.25)]), 2.0, sa["ombre"].darkened(0.15), 1.0, 0.0)
	if etat == "ravive" and r.randf() < 0.4:
		for i in 4:
			var q: Vector2 = c + Vector2(r.randf_range(-0.6, 0.6), r.randf_range(-0.5, 0.3)) * s
			O.flower(ci, q, 2.6, col("seve", "ravive", "fleur"), col("seve", "ravive", "fleur_coeur"), r.randf() * TAU)


static func _ruisseau(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String) -> void:
	var a := p
	var pts := PackedVector2Array([a])
	var dir := Vector2.from_angle(r.randf() * TAU)
	for i in 9:
		dir = (dir + Vector2(r.randf_range(-0.5, 0.5), r.randf_range(-0.5, 0.5))).normalized()
		a += dir * r.randf_range(30.0, 55.0)
		pts.append(a)
	O.brush(ci, pts, 10.0, col("seve", etat, "eau").darkened(0.2), 0.4, 0.4)
	O.brush(ci, pts, 6.0, col("seve", etat, "eau"), 0.4, 0.4)
	O.brush(ci, pts, 1.4, Color(col("seve", etat, "eau_reflet"), 0.6), 0.4, 0.4)


# --- Falaises ---

## Éclat de cristal qui flotte dans le ciel doré, avec sa lueur.
static func _eclat(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String, e: float, lod: int) -> void:
	var glass: Dictionary = pal("aube", etat, "verre" if r.randf() < 0.7 else "nacre")
	var h := r.randf_range(34.0, 90.0) * (1.0 + e / 1800.0)
	var lift := r.randf_range(30.0, 90.0)
	var foot := p + Vector2(0, -lift)
	if lod > 0:
		O.poly(ci, PackedVector2Array([foot + Vector2(-h * 0.15, 0), foot + Vector2(0, -h), foot + Vector2(h * 0.15, 0), foot + Vector2(0, h * 0.3)]), glass["ombre"])
		return
	O.poly(ci, O.blob(p, h * 0.3, h * 0.08, p.x, 0.1, 12), Color(0.1, 0.07, 0.03, 0.25))
	if etat == "ravive":
		ci.draw_circle(foot + Vector2(0, -h * 0.4), h * 0.6, Color(col("aube", "ravive", "lueur"), 0.08))
	var pts := FO.prism(ci, foot, h * r.randf_range(0.12, 0.18), h, r.randf_range(-0.2, 0.2) * h, glass)
	# La pointe du bas (un éclat, pas un cristal planté).
	O.part(ci, PackedVector2Array([pts[0], pts[4], foot + Vector2(0, h * 0.35)]), glass, 1.0, 0.5, 0.0)


# --- Forêt ---

## Arceaux de racines au ras du bord : de grosses racines pétrifiées qui sortent du sol et y replongent.
static func _racines(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String, nrm: Vector2, h: float, lod: int) -> void:
	var bois: Dictionary = pal("racine", etat, "bois")
	var t := Vector2(-nrm.y, nrm.x)
	var l := r.randf_range(60.0, 130.0)
	var a := p - t * l * 0.5
	var b := p + t * l * 0.5 + nrm * r.randf_range(-10, 20)
	var top := p + Vector2(0, -h)
	var pts := O.curve(a, top, b, 12)
	if lod > 0:
		O.brush(ci, pts, 12.0, bois["ombre"], 1.0, 1.0)
		return
	O.cast_shadow(ci, p, l, h * 0.5, 0.28)
	var w := r.randf_range(9.0, 15.0)
	O.brush(ci, pts, w + 2.4, Ink.encre(), 1.0, 1.0)
	O.brush(ci, pts, w, bois["ombre"], 1.0, 1.0)
	O.brush(ci, Transform2D(0.0, Vector2(-1.2, -1.6)) * pts, w * 0.5, bois["clair"], 1.0, 1.0)
	O.brush(ci, Transform2D(0.0, Vector2(-2.0, -2.6)) * pts, w * 0.15, Color(bois["reflet"], 0.7), 0.5, 0.5)
	if etat == "ravive":
		var moss: Dictionary = pal("racine", "ravive", "mousse")
		O.poly(ci, O.blob(pts[6] + Vector2(0, -w * 0.4), w * 1.2, w * 0.4, p.x, 0.3, 14), moss["clair"])
	else:
		ci.draw_line(pts[5], pts[7], Color(col("racine", "fletri", "veine"), 0.7), 1.2, true)


## Tronc de pierre (forêt pétrifiée) : un fût droit qui monte hors de vue, cerné de racines ; couronne de
## feuilles d'or une fois ravivé. « coupe » : une souche brisée au ras du bord.
static func _tronc_pierre(ci: CanvasItem, p: Vector2, r: RandomNumberGenerator, etat: String, e: float, h: float, lod: int, coupe := false) -> void:
	if h < 18.0:
		return
	var bois: Dictionary = pal("racine", etat, "bois")
	var w := r.randf_range(18.0, 34.0) * (1.0 + e / 1500.0)
	if coupe:
		w = r.randf_range(16.0, 26.0)
	var top := p + Vector2(r.randf_range(-0.05, 0.05) * h, -h)
	var trunk := PackedVector2Array([p + Vector2(-w * 1.6, 3), p + Vector2(-w, -h * 0.1), top + Vector2(-w * 0.85, 0), top + Vector2(w * 0.85, 0), p + Vector2(w, -h * 0.1), p + Vector2(w * 1.7, 3)])
	if lod > 0:
		O.poly(ci, trunk, bois["ombre"])
		return
	O.cast_shadow(ci, p, w * 2.4, minf(h, 160.0), 0.3)
	O.part(ci, trunk, bois, 1.5, 1.0, 0.35)
	# Grain du bois changé en pierre : longues fentes, cernes de veine.
	for i in 3:
		var x := r.randf_range(-0.6, 0.6) * w
		ci.draw_line(p + Vector2(x, -h * r.randf_range(0.05, 0.2)), top + Vector2(x * 0.8, h * r.randf_range(0.05, 0.4)), Color(bois["ombre"].darkened(0.3), 0.7), 1.2, true)
	if coupe:
		O.part(ci, Ink.oval(top, w * 0.85, w * 0.3, 16), {"clair": bois["reflet"], "ombre": bois["clair"]}, 1.0, 1.0, 0.0)
		ci.draw_arc(top, w * 0.45, 0, TAU, 14, Color(col("racine", etat, "veine"), 0.8), 1.0, true)
		return
	# Contreforts de racines au pied.
	for sd in [-1.0, 1.0]:
		var a := p + Vector2(sd * w * 0.7, -h * 0.06)
		O.brush(ci, O.curve(a, a + Vector2(sd * w * 0.8, 0), p + Vector2(sd * w * 2.2, 6), 6), w * 0.45, bois["ombre"], 1.0, 0.0)
	if etat == "ravive":
		var leaf: Dictionary = pal("racine", "ravive", "feuillage")
		var crown := top + Vector2(0, -w * 0.4)
		for i in 5:
			var q := crown + Vector2(r.randf_range(-1.6, 1.6) * w, r.randf_range(-0.9, 0.5) * w)
			O.part(ci, Ink.lumpy(q, w * 1.1, w * 0.85, 20, 0.12, 9.0, q.x), leaf, 1.2, 1.0, 0.6)
	elif r.randf() < 0.5:
		var q := p + Vector2(r.randf_range(-0.4, 0.4) * w, -h * r.randf_range(0.2, 0.5))
		ci.draw_circle(q, 4.0, Color(col("racine", "fletri", "ambre"), 0.2))
		ci.draw_circle(q, 1.5, col("racine", "fletri", "ambre"))
