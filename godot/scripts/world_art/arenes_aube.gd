## Arène de la Phalène en décor (refonte du monde, vague 3 A2) : le cercle de l'Aube, des bouquets
## d'aiguilles de cristal plantés dans des blocs de calcaire, autour d'un cadran de pierre pâle incrusté
## de verre ; au fond, la grande aiguille de l'aube. Style des « Paysages d'herbier » (trois quarts,
## encre fine, lumière haut-gauche, Art.MONDE.aube) ; mêmes outils que le décor des falaises
## (world_art/falaise_outils.gd : prismes, bouquets de cristaux, blocs en strates, fleurs d'aube).
##
## L'arène touche presque le bord du monde (la falaise, à l'ouest) : on l'en décolle par le dessin
## seulement. Du côté du vide, le mur devient un parapet bas (« b* ») et le sol se prolonge en une
## terrasse de calcaire jusqu'au bord, qui finit en corniche : l'arène se lit comme un belvédère posé
## sur la falaise, pas comme un cercle coupé par le bord. Rien ne bouge côté combat (rayon, centre).
##
## Contrat du moteur (boss_arena.gd, region_art.gd) appelé par region_art/aube.gd :
##   - pieces(a) : l'anneau (region_art.gd › arena_ring), parapet du côté du vide ;
##   - keys() / piece_box(key) / piece(ci, key, etat) : les pièces cuites ;
##   - piece_live(ci, key, a, i) : la lumière crue qui court le long des aiguilles pendant le combat ;
##   - ground(ci, a, etat) : le cadran et la terrasse (fixe) ;
##   - live(ci, a) : le halo du combat, les sillons du mur resserré.
## Dessin seul : aucune collision, rien du combat ; le hasard est tiré de graines fixes.
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const F = preload("res://scripts/world_art/falaise_outils.gd")
const Regions = preload("res://scripts/regions.gd")

const MUR_VARIANTES := 6
const PARAPETS := 2
const REPERES := 1
## Distance (px du monde) entre le mur et le bord du monde en dessous de laquelle le mur devient parapet.
const EDGE_NEAR := 200.0
## La lumière d'aube (region_art/aube.gd › PAL, recopiée pour ne pas charger ce fichier en boucle).
const LUMIERE := Color("f2d06b")
const LUMIERE_CLAIR := Color("fff4cf")


static func _m(etat: String, key: String):
	return Art.mc("aube", etat, key)


static func keys() -> Array:
	var out := []
	for i in MUR_VARIANTES:
		out.append("m%d" % i)
	for i in PARAPETS:
		out.append("b%d" % i)
	for i in REPERES:
		out.append("r%d" % i)
	return out


static func _rng(key: String, salt := 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(["aube", key, 11 + salt])
	return r


static func piece_box(key: String) -> Rect2:
	if key.begins_with("r"):
		return Rect2(-140, -310, 280, 350)
	if key.begins_with("b"):
		return Rect2(-70, -78, 140, 104)
	return Rect2(-86, -160, 172, 188)


## Distance entre un point du monde et le bord du monde (le carré de Regions.WORLD_HALF).
static func edge_gap(p: Vector2) -> float:
	return Regions.WORLD_HALF - maxf(absf(p.x), absf(p.y))


## Direction (depuis le centre de l'arène) du bord du monde le plus proche, et sa distance au centre.
static func edge_dir(center: Vector2) -> Array:
	var dx := Regions.WORLD_HALF - absf(center.x)
	var dy := Regions.WORLD_HALF - absf(center.y)
	if dx < dy:
		return [Vector2(signf(center.x), 0.0), dx]
	return [Vector2(0.0, signf(center.y)), dy]


## L'anneau du mur (region_art.gd › arena_ring) ; les pièces qui tombent près du bord du monde
## deviennent des parapets bas, un peu rentrés (le sol de la terrasse continue derrière eux).
static func pieces(a, ring: Array) -> Array:
	var c: Vector2 = a.center
	for d in ring:
		if not d["ring"]:
			continue
		var p: Vector2 = c + Vector2.from_angle(float(d["ang"])) * a.max_radius
		if edge_gap(p) < EDGE_NEAR:
			d["key"] = "b%d" % (absi(hash(d["ang"])) % PARAPETS)
			d["out"] = minf(float(d["out"]), 0.0) - 6.0
			d["size"] = float(d["size"]) * 0.95
	return ring


static func piece(ci: CanvasItem, key: String, etat: String) -> void:
	var r := _rng(key)
	var v := int(key.substr(1))
	if key.begins_with("r"):
		_aiguille(ci, r, etat)
	elif key.begins_with("b"):
		_parapet(ci, r, v, etat)
	else:
		_mur(ci, r, v, etat)


# --- Le mur : bouquets d'aiguilles sur leurs blocs ---


## Hauteur de la plus grande aiguille d'une variante (tirée à part, pour la lumière animée).
static func _tall(v: int) -> Array:
	var r := _rng("m%d" % v, 1)
	var hgt := r.randf_range(108.0, 128.0) if v % 2 == 0 else r.randf_range(70.0, 86.0)
	return [Vector2(r.randf_range(-10.0, 10.0), -10.0), hgt, r.randf_range(-12.0, 12.0)]


## Pan de mur : deux ou trois blocs de calcaire en strates au pied, et dedans un bouquet d'aiguilles de
## cristal autour d'une grande aiguille (plus haute une variante sur deux). Flétri : verre fumé, calcaire
## froid, poussière de verre, une fente de braise éteinte. Ravivé : verre clair et nacre, lueur d'or au
## pied, herbe dorée et fleurs d'aube.
static func _mur(ci: CanvasItem, r: RandomNumberGenerator, v: int, etat: String) -> void:
	var live := etat == "ravive"
	var glass: Dictionary = F.pal(etat, "verre")
	var nacre: Dictionary = F.pal(etat, "nacre")
	O.cast_shadow(ci, Vector2.ZERO, 118.0, 70.0, 0.28)
	O.poly(ci, O.blob(Vector2(0, 3), 64.0, 12.0, float(v), 0.15, 22), Color(_m(etat, "sol_sombre"), 0.7))
	# Bloc de l'arrière.
	F.block(ci, Vector2(r.randf_range(-30.0, -14.0), -6.0), r.randf_range(20.0, 26.0), r.randf_range(22.0, 30.0), r, etat)
	# Le bouquet : la grande aiguille au milieu, les petites autour.
	var t := _tall(v)
	var foot: Vector2 = t[0]
	var hgt: float = t[1]
	var lean: float = t[2]
	if live:
		ci.draw_circle(foot + Vector2(0, -hgt * 0.4), 34.0, Color(_m("ravive", "lueur"), 0.08))
	F.prism(ci, foot + Vector2(-18, -2), 7.0, hgt * 0.55, lean - 10.0, nacre)
	F.prism(ci, foot + Vector2(17, -1), 6.5, hgt * 0.62, lean + 8.0, glass)
	var pts := F.prism(ci, foot, 12.0, hgt, lean, glass)
	var tip: Vector2 = pts[2]
	# Cœur de nacre de la grande aiguille.
	O.poly(ci, PackedVector2Array([foot + Vector2(-3, -6), tip.lerp(foot, 0.25) + Vector2(-1, 0), tip.lerp(foot, 0.25) + Vector2(2, 0), foot + Vector2(4, -6)]), Color(nacre["clair"], 0.5 if live else 0.25))
	# Blocs de l'avant, et petites aiguilles qui en sortent.
	F.block(ci, Vector2(r.randf_range(10.0, 26.0), 2.0), r.randf_range(18.0, 24.0), r.randf_range(16.0, 22.0), r, etat)
	if v % 2 == 1:
		F.block(ci, Vector2(r.randf_range(-40.0, -30.0), 6.0), r.randf_range(14.0, 18.0), r.randf_range(12.0, 16.0), r, etat)
	F.crystal_group(ci, Vector2(r.randf_range(-44.0, -30.0), 8.0), 24.0, r.randf_range(26.0, 36.0), 3, r, etat)
	F.crystal_group(ci, Vector2(r.randf_range(32.0, 46.0), 9.0), 20.0, r.randf_range(20.0, 30.0), 3, r, etat)
	if live:
		F.spark(ci, tip + Vector2(0, 4), 5.0, glass["reflet"])
		var grass: Color = _m("ravive", "touffe")
		for i in 4:
			var p := Vector2((i - 1.5) * 30.0 + r.randf_range(-5, 5), r.randf_range(6.0, 11.0))
			O.tuft(ci, p, r.randf_range(10.0, 14.0), grass, _m("ravive", "touffe_2"), v * 7 + i)
		for i in 4:
			var p := Vector2(r.randf_range(-50.0, 50.0), r.randf_range(-6.0, 10.0))
			F.star(ci, p, r.randf_range(2.6, 3.4), _m("ravive", "fleur" if i % 2 else "fleur_2"), _m("ravive", "fleur_coeur"))
	else:
		F.ci_dust(ci, Vector2(0, 6), 40.0, r)
		var e := foot + Vector2(lean * 0.3, -hgt * 0.3)
		ci.draw_line(e + Vector2(-1, 6), e + Vector2(2, -6), Color(Art.bc("braise"), 0.55), 1.2, true)
		for i in 2:
			O.tuft(ci, Vector2((i * 2 - 1) * 42.0, 9.0), 10.0, _m("fletri", "touffe"), _m("fletri", "touffe_2"), v * 3 + i, true)


## Parapet du côté du vide : une rangée de blocs bas, de petits cristaux entre eux. Il ferme l'arène
## sans la murer : on voit la falaise derrière.
static func _parapet(ci: CanvasItem, r: RandomNumberGenerator, v: int, etat: String) -> void:
	var live := etat == "ravive"
	O.cast_shadow(ci, Vector2.ZERO, 96.0, 34.0, 0.26)
	F.block(ci, Vector2(-24.0 + r.randf_range(-4, 4), -2.0), r.randf_range(18.0, 22.0), r.randf_range(22.0, 28.0), r, etat)
	F.crystal_group(ci, Vector2(4.0, -6.0), 22.0, r.randf_range(34.0, 46.0) * (1.0 if v == 0 else 0.8), 3, r, etat)
	F.crystal_group(ci, Vector2(30.0, 6.0), 18.0, r.randf_range(22.0, 30.0), 3, r, etat)
	F.crystal_group(ci, Vector2(-42.0, 9.0), 14.0, r.randf_range(16.0, 22.0), 3, r, etat)
	if live:
		for i in 3:
			O.tuft(ci, Vector2((i - 1) * 46.0, 6.0), 10.0, _m("ravive", "touffe"), _m("ravive", "touffe_2"), v * 5 + i)
		F.star(ci, Vector2(r.randf_range(-30, 30), 4.0), 3.0, _m("ravive", "fleur"), _m("ravive", "fleur_coeur"))
	else:
		F.ci_dust(ci, Vector2(0, -16), 40.0, r)


# --- La grande aiguille de l'aube (repère) ---


## Hauteur et pointe de la grande aiguille (pour la lumière animée).
const NEEDLE_H := 272.0


## La grande aiguille (repère de l'Aube) : un prisme de verre haut comme trois arbres, au cœur de
## nacre, entouré d'aiguilles plus petites, planté dans un socle de blocs de calcaire. Flétri : verre
## fumé presque noir, poussière, une fente de braise à mi-hauteur. Ravivé : verre clair, cœur de nacre
## qui luit, une lumière d'or à la pointe, fleurs d'aube et herbe dorée au pied. On la voit de loin.
static func _aiguille(ci: CanvasItem, r: RandomNumberGenerator, etat: String) -> void:
	var live := etat == "ravive"
	var h := NEEDLE_H
	var glass: Dictionary = F.pal(etat, "verre")
	var nacre: Dictionary = F.pal(etat, "nacre")
	O.cast_shadow(ci, Vector2.ZERO, h * 0.42, h * 0.9, 0.3)
	if live:
		ci.draw_circle(Vector2(0, -h * 0.82), h * 0.22, Color(_m("ravive", "lueur"), 0.06))
		ci.draw_circle(Vector2(0, -h * 0.9), h * 0.1, Color(_m("ravive", "lueur"), 0.12))
	# Aiguilles de l'arrière.
	F.prism(ci, Vector2(-h * 0.14, -h * 0.05), h * 0.055, h * 0.58, -h * 0.12, glass)
	F.prism(ci, Vector2(h * 0.15, -h * 0.04), h * 0.05, h * 0.5, h * 0.1, nacre)
	F.prism(ci, Vector2(-h * 0.24, -h * 0.02), h * 0.035, h * 0.32, -h * 0.1, nacre)
	# La grande aiguille, et son cœur de nacre.
	var pts := F.prism(ci, Vector2(0, -h * 0.02), h * 0.095, h, h * 0.03, glass)
	var tip: Vector2 = pts[2]
	var core := PackedVector2Array([Vector2(-h * 0.025, -h * 0.08), tip.lerp(Vector2(0, -h * 0.1), 0.3) + Vector2(-h * 0.01, 0), tip.lerp(Vector2(0, -h * 0.1), 0.3) + Vector2(h * 0.015, 0), Vector2(h * 0.03, -h * 0.08)])
	O.poly(ci, core, Color(nacre["clair"], 0.6 if live else 0.25))
	# Strates de croissance du cristal (lignes en travers).
	for i in 4:
		var y := -h * (0.2 + 0.17 * i)
		var w := h * 0.085 * (1.0 - 0.18 * i)
		ci.draw_line(Vector2(-w + h * 0.004 * i, y), Vector2(w * 0.9, y - h * 0.012), Color(glass["ombre"].darkened(0.3), 0.5), 1.2, true)
	if not live:
		var e := Vector2(h * 0.01, -h * 0.45)
		ci.draw_circle(e, 10.0, Color(Art.bc("braise"), 0.1))
		ci.draw_polyline(PackedVector2Array([e + Vector2(-2, -12), e + Vector2(2, -3), e + Vector2(-1, 5), e + Vector2(3, 13)]), Art.bc("braise"), 1.4, true)
	# Le socle : blocs de calcaire, aiguilles basses devant.
	F.block(ci, Vector2(-h * 0.14, h * 0.02), h * 0.15, h * 0.12, r, etat)
	F.block(ci, Vector2(h * 0.16, h * 0.035), h * 0.12, h * 0.1, r, etat)
	F.block(ci, Vector2(-h * 0.02, h * 0.06), h * 0.1, h * 0.06, r, etat)
	F.crystal_group(ci, Vector2(-h * 0.3, h * 0.07), h * 0.12, h * 0.16, 3, r, etat)
	F.crystal_group(ci, Vector2(h * 0.3, h * 0.08), h * 0.1, h * 0.13, 3, r, etat)
	if live:
		F.spark(ci, tip + Vector2(0, h * 0.02), h * 0.045, glass["reflet"])
		for i in 7:
			F.star(ci, Vector2(r.randf_range(-0.38, 0.38) * h, h * r.randf_range(0.06, 0.12)), 3.6, _m("ravive", "fleur" if i % 2 == 0 else "fleur_2"), _m("ravive", "fleur_coeur"))
		for i in 5:
			O.tuft(ci, Vector2((i - 2) * h * 0.13, h * 0.11), 14.0, _m("ravive", "touffe"), _m("ravive", "touffe_2"), 30 + i)
	else:
		F.ci_dust(ci, Vector2(0, h * 0.09), h * 0.32, r)


# --- Ce qui bouge sur les pièces ---


## Pendant le combat, la lumière crue court le long de la grande aiguille de chaque bouquet (une pièce
## sur trois, redessinées 15 fois par seconde) et la pointe de la grande aiguille du fond brûle.
static func piece_live(ci: CanvasItem, key: String, a, i: int) -> void:
	if a.state != "combat" or i % 3 != 0 or key.begins_with("b"):
		return
	var col: Color = LUMIERE_CLAIR
	if key.begins_with("r"):
		var tip := Vector2(NEEDLE_H * 0.03, -NEEDLE_H * 1.02)
		var pulse := 0.5 + 0.5 * sin(a.t * 4.0)
		ci.draw_circle(tip, 26.0, Color(LUMIERE, 0.1 + 0.12 * pulse))
		ci.draw_circle(tip, 6.0, Color(col, 0.5 + 0.4 * pulse))
		var u := fposmod(a.t * 0.6, 1.0)
		ci.draw_circle(Vector2(0, -NEEDLE_H * 0.02).lerp(tip, u), 4.0, Color(col, sin(PI * u)))
		return
	var t := _tall(int(key.substr(1)))
	var foot: Vector2 = t[0]
	var top: Vector2 = foot + Vector2(float(t[2]), -float(t[1]))
	var u := fposmod(a.t * 0.9 + i * 0.07, 1.0)
	var q := foot.lerp(top, u)
	ci.draw_circle(q, 7.0, Color(LUMIERE, 0.25 * sin(PI * u)))
	ci.draw_circle(q, 2.6, Color(col, sin(PI * u)))


# --- Sol ---


## Le cadran (fixe, redessiné quand l'état change) : une dalle de calcaire pâle polie par la lumière,
## gravée de douze rayons et de deux cercles incrustés de verre (un cadran solaire géant, où la
## Phalène boit la lumière), semée d'éclats ; du côté du vide, une terrasse de calcaire en strates
## prolonge le sol jusqu'à la corniche. Ravivé : le verre des incrustations s'allume d'or, herbe dorée
## et fleurs d'aube entre les dalles.
static func ground(ci: CanvasItem, a, etat: String) -> void:
	var c: Vector2 = a.center
	var R: float = a.max_radius
	var r := RandomNumberGenerator.new()
	r.seed = hash(["aube", "sol"])
	var live := etat == "ravive"
	var sol: Color = _m(etat, "sol")
	var clair: Color = _m(etat, "sol_clair")
	var sombre: Color = _m(etat, "sol_sombre")
	var rock: Dictionary = F.pal(etat, "roche")
	var glass: Dictionary = F.pal(etat, "verre")
	# La terrasse du côté du vide (sous l'aire, puisqu'elle en sort).
	var ed := edge_dir(Regions.arena_center("aube"))
	var edir: Vector2 = ed[0]
	var reach: float = minf(float(ed[1]) - 8.0, R * 1.06 + 26.0)
	_terrace(ci, c, R, reach, edir, r, etat)
	# L'aire : une seule grande surface, puis la couronne sombre au pied du mur.
	O.poly(ci, O.blob(c, R * 0.96, R * 0.96, 5.0, 0.025, 96), Color(rock["clair"].lerp(clair, 0.5), 0.55) if not live else Color(sol.lerp(rock["clair"], 0.6), 0.42))
	var band := O.blob(c, R * 1.0, R * 1.0, 3.0, 0.02, 96)
	band.append(band[0])
	ci.draw_polyline(band, Color(sombre.darkened(0.3), 0.3), 44.0)
	# Dalles polies : plaques claires aux joints fins.
	for i in 26:
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * sqrt(r.randf_range(0.0, 0.8))
		var rx := R * r.randf_range(0.07, 0.12)
		var pts := O.blob(p, rx, rx * 0.6, float(i), 0.2, 7, r.randf() * PI)
		O.poly(ci, pts, Color(rock["reflet"], 0.1 if not live else 0.14))
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, Color(sombre.darkened(0.4), 0.28), 1.6, true)
	# Le cadran : douze rayons et deux cercles de verre incrusté, gravés finement.
	var inlay: Color = glass["clair"] if not live else _m("ravive", "lueur")
	var groove := Color(sombre.darkened(0.5), 0.32)
	for k in [0.3, 0.64]:
		var pts := PackedVector2Array()
		for i in 97:
			pts.append(c + Vector2.from_angle(TAU * i / 96.0) * R * k * (1.0 + 0.006 * O.wave(i * 0.4, k * 7.0)))
		ci.draw_polyline(pts, groove, 6.0, true)
		ci.draw_polyline(pts, Color(inlay, 0.3 if not live else 0.45), 2.2, true)
	for i in 12:
		var d := Vector2.from_angle(TAU * i / 12.0 - PI / 2.0)
		var p0 := c + d * R * 0.31
		var p1 := c + d * R * (0.84 if i % 3 == 0 else 0.62)
		O.brush(ci, PackedVector2Array([p0, p0.lerp(p1, 0.5), p1]), 5.0, groove, 0.2, 0.9)
		O.brush(ci, PackedVector2Array([p0, p0.lerp(p1, 0.5), p1]), 2.0, Color(inlay, 0.28 if not live else 0.4), 0.2, 0.9)
		if i % 3 == 0:
			# Les quatre heures marquées d'un losange de verre.
			var q := c + d * R * 0.74
			var n := d.orthogonal()
			var dia := PackedVector2Array([q - d * 14.0, q + n * 7.0, q + d * 14.0, q - n * 7.0])
			O.poly(ci, dia, Color(glass["ombre"], 0.8))
			O.poly(ci, PackedVector2Array([dia[0], dia[1], dia[2]]), Color(glass["clair"], 0.8))
	# Le centre : un disque de verre (la Phalène s'y pose).
	O.poly(ci, O.blob(c, R * 0.12, R * 0.12 * 0.7, 2.0, 0.04, 32), glass["ombre"])
	O.poly(ci, O.blob(c + Vector2(-3, -3), R * 0.1, R * 0.1 * 0.68, 2.0, 0.04, 32), Color(glass["clair"], 0.85))
	ci.draw_line(c + Vector2(-R * 0.06, -R * 0.03), c + Vector2(R * 0.02, -R * 0.06), Color(glass["reflet"], 0.7), 2.0, true)
	# Liseré du bord intérieur.
	var rim := O.blob(c, R * 0.96, R * 0.96, 5.0, 0.025, 96)
	rim.append(rim[0])
	ci.draw_polyline(rim, Color(sombre.darkened(0.45), 0.55), 5.0, true)
	# Éclats de verre, poussière ; ravivé : herbe dorée et fleurs d'aube.
	for i in 44:
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * sqrt(r.randf_range(0.03, 0.85))
		if live and i % 2 == 0:
			if i % 4 == 0:
				O.tuft(ci, p, r.randf_range(12.0, 17.0), _m("ravive", "touffe"), _m("ravive", "touffe_2"), i)
			else:
				F.star(ci, p, 4.2, _m("ravive", "fleur" if i % 3 else "fleur_2"), _m("ravive", "fleur_coeur"))
		else:
			var a0 := r.randf() * PI
			var l := r.randf_range(7.0, 12.0)
			var d := Vector2.from_angle(a0) * Vector2(1.0, 0.55)
			var n := Vector2(-d.y, d.x).normalized() * l * 0.24
			var sh := PackedVector2Array([p - d * l * 0.5, p + n, p + d * l * 0.5, p - n])
			O.poly(ci, sh, glass["ombre"])
			O.poly(ci, PackedVector2Array([sh[0], sh[1], sh[2]]), glass["clair"])


## Terrasse de calcaire entre le mur et le bord du monde : une bande de roche en strates qui part du pied
## du mur (côté edir), jusqu'à reach du centre, terminée par une corniche (arête claire, flanc sombre).
static func _terrace(ci: CanvasItem, c: Vector2, R: float, reach: float, edir: Vector2, r: RandomNumberGenerator, etat: String) -> void:
	if reach <= R * 0.96:
		return
	var rock: Dictionary = F.pal(etat, "roche")
	var ang0 := edir.angle()
	var span := 1.05
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 41:
		var ang := ang0 - span + 2.0 * span * i / 40.0
		var d := Vector2.from_angle(ang)
		# La corniche suit le bord du monde (droite), sans dépasser reach.
		var along := absf(d.dot(edir))
		var rr := minf(reach / maxf(along, 0.2), R * 1.06 + 26.0)
		var fade := 1.0 - pow(absf(ang - ang0) / span, 3.0)
		outer.append(c + d * lerpf(R * 0.97, rr, fade) + d * O.wave(ang * 9.0, 3.0) * 4.0)
		inner.append(c + d * R * 0.9)
	var poly := outer.duplicate()
	var back := inner.duplicate()
	back.reverse()
	poly.append_array(back)
	O.poly(ci, poly, Color(rock["clair"].lerp(_m(etat, "sol_clair"), 0.4), 0.85))
	# Strates parallèles à la corniche.
	for k in 3:
		var pts := PackedVector2Array()
		for i in outer.size():
			pts.append(inner[i].lerp(outer[i], 0.55 + 0.14 * k))
		ci.draw_polyline(pts, Color(rock["ombre"], 0.45), 2.0, true)
	# La corniche : arête claire, flanc sombre juste derrière.
	ci.draw_polyline(outer, Color(rock["ombre"].darkened(0.4), 0.8), 7.0, true)
	ci.draw_polyline(Transform2D(0.0, -edir * 4.0) * outer, Color(rock["reflet"], 0.7), 2.4, true)
	# Quelques blocs posés sur la terrasse, et de petits cristaux.
	for i in 5:
		var ang := ang0 + (i - 2) * 0.32 + r.randf_range(-0.08, 0.08)
		var p := c + Vector2.from_angle(ang) * (R * 1.03 + 8.0)
		O.pebble(ci, p, r.randf_range(5.0, 8.0), rock, float(i))


## Ce qui bouge au sol : pendant le combat, la lumière crue qui court sur les incrustations du cadran
## (un rayon qui tourne comme l'ombre d'un gnomon, le cercle intérieur qui bat) ; quand le mur s'est
## resserré, les sillons qu'il a laissés.
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
	var R: float = a.max_radius
	var pulse := 0.5 + 0.5 * sin(a.t * 3.0)
	ci.draw_arc(c, R * 0.3, 0.0, TAU, 64, Color(LUMIERE, 0.2 + 0.2 * pulse), 5.0, true)
	ci.draw_arc(c, R * 0.64, 0.0, TAU, 96, Color(LUMIERE, 0.06 + 0.08 * pulse), 12.0, true)
	var d := Vector2.from_angle(a.t * 0.5)
	ci.draw_line(c + d * R * 0.12, c + d * minf(a.radius - 20.0, R * 0.84), Color(LUMIERE, 0.18), 14.0, true)
	ci.draw_line(c + d * R * 0.12, c + d * minf(a.radius - 20.0, R * 0.84), Color(LUMIERE_CLAIR, 0.6), 3.0, true)
	ci.draw_arc(c, a.radius - 12.0, 0.0, TAU, 72, Color(LUMIERE, 0.1 + 0.1 * pulse), 2.0, true)
