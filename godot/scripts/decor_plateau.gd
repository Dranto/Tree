## Décor des hauts plateaux (région de Vent, « decor » : {"kind": "plateau"} dans
## data/regions/vent.json) : un pays ouvert, balayé par le vent, à l'opposé du roncier étouffant.
##   - les arbres du monde y deviennent des arbres tordus, couchés par le vent dominant ;
##   - des rochers plats et des pierres levées font obstacle (peu nombreux : la région reste ouverte) ;
##   - des touffes d'herbe couchée dans le sens du vent, grises et sèches sur la terre morte, blondes
##     et en épis une fois ravivées (elles ne gênent pas).
## Il pose aussi les rafales de la région (wind.gd), si son fichier a une section « wind ».
##
## Même contrat que decor_roncier.gd (make_tree, spawn). Budget de dessin (docs/performances.md) :
## chaque élément est un DecorTree, dessiné en un appel par le lot fidèle et redessiné seulement
## quand il reverdit ; l'herbe est groupée par touffes de trois à cinq brins.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const Flora = preload("res://scripts/flora.gd")
const Wind = preload("res://scripts/wind.gd")
const O = preload("res://scripts/world_art/outils.gd")
const SolVent = preload("res://scripts/world_bake/sol/vent.gd")

var flora
## Identifiant de la région et réglages de son décor (« decor » du fichier de la région).
var region := ""
var cfg: Dictionary = {}


## Direction du vent dominant à l'écran (wind › angle depuis l'axe de la région) : les arbres
## penchent et l'herbe se couche de ce côté.
func wind_dir() -> Vector2:
	var w := Regions.section(region, "wind")
	return Vector2.from_angle(Regions.angle_of(region) + float(w.get("angle", 0.0)))


func make_tree(_p: Vector2) -> Node2D:
	var t := Twisted.new()
	t.lean = _lean()
	return t


## Penchant à l'écran (de -1 à 1) : le décor est vu de trois quarts, seule la composante
## horizontale du vent couche les formes ; la verticale les tasse un peu.
func _lean() -> float:
	var d := wind_dir()
	return clampf(d.x * 1.15, -1.0, 1.0) if absf(d.x) > 0.15 else (0.15 if d.x >= 0.0 else -0.15)


## Rochers et herbe : tirage à part (graine fixe), pour ne pas déplacer les arbres du reste du monde.
## Le centre de la région (Cœur, arène) et les abords de la graine restent libres d'obstacles.
func spawn() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(cfg.get("seed", 21))
	var mid: float = Regions.angle_of(region)
	var half: float = Regions.half_width()
	var lean := _lean()
	var h := 2850.0
	var rocks := int(cfg.get("rocks", 64))
	var clear_center := float(cfg.get("clear_center", 340.0))
	var clear_seed := float(cfg.get("clear_seed", 560.0))
	for i in rocks + int(cfg.get("grass", 320)):
		var rock := i < rocks
		var a := mid + r.randf_range(-half, half) * 0.97
		var d := sqrt(r.randf_range(pow(Regions.INNER + 30.0, 2), pow(4000.0, 2)))
		var p := Vector2.from_angle(a) * d
		var sz := r.randf_range(0.8, 1.4)
		var sd := r.randi()
		if absf(p.x) > h or absf(p.y) > h or Regions.weight(p, region) < 0.6:
			continue
		if rock and (Regions.near_heart(region, p, clear_center) or p.length() < clear_seed):
			continue
		var t: Flora.DecorTree
		if rock:
			var st := Stone.new()
			st.radius = 16.0 + 16.0 * (sz - 0.8) / 0.6
			st.standing = sd % 5 == 0
			t = st
		else:
			var g := Grass.new()
			g.lean = lean
			t = g
		t.position = p
		t.size = sz
		t.tree_seed = sd
		t.alive = flora.ground.life_at(p) > flora.ALIVE
		if rock:
			flora.add_obstacle(t)
		flora.trees_parent.add_child(t)
		flora._add_tree(t)
	var wind := Regions.section(region, "wind")
	if not wind.is_empty():
		var w := Wind.new()
		w.main = flora.get_parent()
		w.region = region
		w.cfg = wind
		flora.add_child(w)


# --- Dessin des plateaux (refonte du monde, vague 2 P3) ---
# Grammaire de la planche W (world_art/outils.gd) : encre fine, deux tons et un reflet, lumière d'en
# haut à gauche, ombre portée vers le bas à droite. Couleurs : Art.MONDE › vent (flétri ou ravivé).
# Chaque élément se dessine directement sur son nœud (puis il est cuit par decor_bake.gd).

## Outils de dessin partagés des plateaux (aussi pour le Cœur, region_art/vent.gd).
class P extends RefCounted:
	## État de dessin d'un élément : « ravive » une fois vivant, sinon « fletri ».
	static func etat_of(t) -> String:
		return "ravive" if t.alive and t.growth() > 0.5 else "fletri"


	static func pal(etat: String, key: String):
		return Art.mc("vent", etat, key)


	## Membre effilé le long d'une courbe (tronc, branche) : de w0 au pied à w1 au bout, en forme pleine.
	static func limb_poly(pts: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in pts.size():
			var u := float(i) / maxf(1.0, pts.size() - 1.0)
			var d: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var n := d.orthogonal() * lerpf(w0, w1, u) * 0.5
			left.append(pts[i] + n)
			right.append(pts[i] - n)
		right.reverse()
		left.append_array(right)
		return left


	## Plume dressée (fichée dans un cairn, un bouquet) : vane deux tons, rachis clair.
	static func feather(ci: CanvasItem, b: Vector2, a: float, l: float, etat: String, curl := 0.0) -> void:
		var d := Vector2.from_angle(a)
		var tip := b + d * l
		var mid := b.lerp(tip, 0.5) + d.orthogonal() * l * curl
		var vane := O.Ink.leaf(b + d * l * 0.12, a + curl * 0.6, l * 0.9, l * 0.24, curl)
		O.part(ci, vane, {"clair": P.pal(etat, "plume"), "ombre": P.pal(etat, "plume_ombre"), "reflet": P.pal(etat, "plume")}, 0.9, 1.0, 0.4)
		O.brush(ci, O.curve(b, mid, tip, 6), maxf(0.8, l * 0.05), P.pal(etat, "plume_ombre").darkened(0.2), 1.0, 0.0)


## Arbre tordu des plateaux : un tronc bas noueux qui part de biais, des branches toutes rabattues du
## même côté par le vent. Flétri : bois d'ardoise nu, quelques feuilles sèches accrochées. Ravivé : bois
## argenté, feuillage vert de sauge pâle en mèches étirées sous le vent, petites fleurs blanches.
class Twisted extends Flora.DecorTree:
	## Penchant (de -1 à 1) : le côté où le vent couche l'arbre.
	var lean := 1.0

	func dead_color() -> Color:
		return Art.mc("vent", "fletri", "bois")["clair"]

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var etat := P.etat_of(self)
		var bois: Dictionary = P.pal(etat, "bois")
		var h := r.randf_range(46.0, 56.0) * size
		var side := signf(lean) if lean != 0.0 else 1.0
		var bend := 0.55 + 0.45 * absf(lean)
		var w := h * 0.085
		O.cast_shadow(self, Vector2.ZERO, w * 3.0 + h * 0.3, h * 0.55, 0.3 if etat == "ravive" else 0.36)
		# Racines qui agrippent la roche, côté opposé au vent.
		for i in 3:
			var a := PI * (0.15 + 0.35 * i) * (1.0 if side > 0.0 else -1.0) + (0.0 if side > 0.0 else PI)
			var tip := Vector2(cos(a) * w * 2.6, absf(sin(a)) * w * 0.5 + 1.0)
			O.part(self, P.limb_poly(O.curve(Vector2(0, -w * 0.4), Vector2(tip.x * 0.5, -w * 0.3), tip, 4), w * 0.9, w * 0.15), bois, 0.8, 1.0, 0.0)
		# Tronc en deux coudes : il monte, puis se rabat sous le vent.
		var knee := Vector2(-side * r.randf_range(0.02, 0.08) * h, -h * 0.42)
		var top := knee + Vector2(side * h * 0.52 * bend, -h * 0.28)
		var trunk := O.curve(Vector2.ZERO, knee, top, 10)
		O.part(self, P.limb_poly(trunk, w * 2.0, w * 0.75), bois, 1.6, 1.0, 0.3)
		# Écorce torse : deux sillons en spirale, un liseré clair côté lumière.
		for j in 2:
			var pts := PackedVector2Array()
			for i in 8:
				var u := 0.08 + 0.8 * i / 7.0
				var q: Vector2 = trunk[int(u * 10.0)]
				pts.append(q + Vector2(sin(u * 9.0 + j * 2.2) * w * 0.55 * (1.0 - u * 0.5), 0))
			O.brush(self, pts, maxf(0.9, w * 0.14), Color(bois["ombre"], 0.8), 0.0, 0.0)
		O.brush(self, trunk.slice(1, 8), maxf(0.8, w * 0.12), Color(bois["reflet"], 0.55), 0.0, 0.0)
		# Branches : toutes partent vers le côté du vent, quelques-unes cassées net.
		var tips: Array = []
		var nb := 3 + r.randi() % 2
		for i in nb:
			var k := r.randf_range(0.45, 1.0)
			var base: Vector2 = trunk[clampi(int(k * 10.0), 3, 10)]
			var up := r.randf_range(-0.55, 0.15)
			var dir := Vector2(side, up).normalized()
			var l := h * r.randf_range(0.26, 0.42)
			var tip := base + dir * l
			var mid := base.lerp(tip, 0.5) + Vector2(0, -l * r.randf_range(0.05, 0.2))
			var br := O.curve(base, mid, tip, 6)
			O.part(self, P.limb_poly(br, w * 0.75, w * 0.18), bois, 1.0, 1.0, 0.0)
			tips.append(tip)
			tips.append(mid + Vector2(side * l * 0.1, -l * 0.12))
			if r.randf() < 0.6:
				var tw := tip + Vector2(side * l * 0.35, -l * r.randf_range(0.05, 0.3))
				O.brush(self, O.curve(tip, tip.lerp(tw, 0.5) + Vector2(0, -2), tw, 4), maxf(0.8, w * 0.2), bois["ombre"], 1.0, 0.0)
				tips.append(tw)
		tips.append(top + Vector2(side * h * 0.08, -h * 0.04))
		if etat == "ravive":
			# Mèches de feuillage étirées sous le vent, des plus lointaines aux plus proches.
			var leaf: Dictionary = P.pal(etat, "feuillage")
			var masses := []
			for t in tips:
				var p: Vector2 = t + Vector2(side * h * 0.07, r.randf_range(-0.04, 0.04) * h)
				masses.append([p, h * r.randf_range(0.12, 0.17)])
			masses.sort_custom(func(x, y): return x[0].y < y[0].y)
			for ms in masses:
				var c: Vector2 = ms[0]
				var rr: float = ms[1]
				O.part(self, O.Ink.lumpy(c, rr * 1.55, rr * 0.62, 26, 0.12, 8.0, c.x * 0.1), leaf, 1.2, 1.0, 0.7)
				# Pointes de la mèche, peignées par le vent.
				for j in 3:
					var q := c + Vector2(side * rr * 1.2, (j - 1) * rr * 0.32)
					O.brush(self, PackedVector2Array([q, q + Vector2(side * rr * 0.7, -rr * 0.05 + (j - 1) * rr * 0.12)]), rr * 0.2, leaf["clair"], 1.0, 0.0)
			for i in 7:
				var ms: Array = masses[r.randi() % masses.size()]
				var p: Vector2 = ms[0] + Vector2(r.randf_range(-1.0, 0.9) * ms[1], r.randf_range(-0.5, 0.2) * ms[1])
				O.flower(self, p, r.randf_range(1.8, 2.6) * maxf(1.0, size * 0.5), P.pal(etat, "fleur"), P.pal(etat, "fleur_coeur"), r.randf() * TAU)
		else:
			# Quelques feuilles sèches restées aux branches, toutes du côté du vent.
			var leaf: Dictionary = P.pal(etat, "feuillage")
			for i in tips.size():
				if i % 2 != 0:
					continue
				var t: Vector2 = tips[i]
				for j in r.randi_range(1, 3):
					var p := t + Vector2(r.randf_range(-3, 3), r.randf_range(-2, 4))
					O.part(self, O.Ink.leaf(p, (0.2 if side > 0.0 else PI - 0.2) + r.randf_range(-0.5, 0.5), 6.0 * maxf(1.0, size * 0.6), 2.6 * maxf(1.0, size * 0.6), 0.2), leaf, 0.6, 1.0, 0.0)


## Rocher des plateaux : bloc plat et anguleux (ou pierre levée, plus haute), solide (cercle de
## rayon « radius », inchangé). Flétri : ardoise, lichen gris. Ravivé : pierre claire, lichen pâle,
## herbe argentée et fleurs blanches à son pied.
class Stone extends Flora.DecorTree:
	var radius := 24.0
	var standing := false

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var etat := P.etat_of(self)
		var st: Dictionary = P.pal(etat, "pierre")
		var rr := radius
		var pts := PackedVector2Array()
		var hh := rr * 2.3
		if standing:
			# Menhir : un monolithe effilé, un peu penché.
			var w := rr * 0.55
			var tilt := r.randf_range(-0.18, 0.18) * hh
			pts = PackedVector2Array([Vector2(-w, rr * 0.15), Vector2(-w * 0.92 + tilt * 0.3, -hh * 0.35), Vector2(-w * 0.85 + tilt * 0.5, -hh * 0.65), Vector2(-w * 0.3 + tilt, -hh), Vector2(w * 0.45 + tilt, -hh * 0.92), Vector2(w * 0.8 + tilt * 0.6, -hh * 0.6), Vector2(w * 0.95 + tilt * 0.3, -hh * 0.3), Vector2(w, rr * 0.15)])
			O.cast_shadow(self, Vector2.ZERO, w * 2.2, hh, 0.34)
		else:
			# Bloc plat : un polygone cassé, plus large que haut.
			var n := 9
			var rot := r.randf() * 0.6
			for i in n:
				var a := rot + TAU * i / n
				var k := r.randf_range(0.8, 1.08)
				pts.append(Vector2(cos(a) * rr * 1.15 * k, sin(a) * rr * 0.62 * k - rr * 0.35))
			O.cast_shadow(self, Vector2(0, rr * 0.1), rr * 2.2, rr * 0.8, 0.34)
		O.part(self, pts, st, 1.5, 1.0, 0.5)
		# Strates et fissures gravées.
		if standing:
			for i in 3:
				var y := -hh * (0.25 + 0.22 * i)
				O.brush(self, PackedVector2Array([Vector2(-rr * 0.45, y + 2.0), Vector2(0, y), Vector2(rr * 0.4, y + 3.0)]), 1.0, Color(st["ombre"], 0.8), 0.0, 0.0)
		else:
			O.brush(self, PackedVector2Array([Vector2(-rr * 0.7, -rr * 0.45), Vector2(-rr * 0.1, -rr * 0.55), Vector2(rr * 0.6, -rr * 0.4)]), 1.1, Color(st["ombre"], 0.75), 0.0, 0.0)
			O.brush(self, PackedVector2Array([Vector2(-rr * 0.2, -rr * 0.5), Vector2(-rr * 0.05, -rr * 0.25), Vector2(rr * 0.12, -rr * 0.05)]), 0.9, Color(st["ombre"].darkened(0.3), 0.8), 0.0, 0.0)
		# Lichen en rosettes sur le dessus.
		var lichen: Color = P.pal(etat, "lichen")
		for i in 3 + r.randi() % 3:
			var p := Vector2(r.randf_range(-0.55, 0.5) * rr, -rr * (0.45 + (1.4 if standing else 0.15) * r.randf()))
			var s := r.randf_range(2.2, 4.4)
			O.poly(self, O.blob(p, s, s * 0.6, p.x, 0.25, 10), Color(lichen, 0.8))
			O.poly(self, O.blob(p + Vector2(-0.5, -0.4), s * 0.45, s * 0.28, p.y, 0.2, 8), Color(lichen.lightened(0.25), 0.7))
		var herbe: Dictionary = P.pal(etat, "herbe")
		var side := 1.0 if r.randf() < 0.5 else -1.0
		for i in 2:
			var foot := Vector2((i * 2 - 1) * rr * 0.85, rr * 0.12)
			O.tuft(self, foot, 8.0 + rr * 0.15, herbe["clair"], herbe["ombre"], tree_seed + i, etat != "ravive")
		if etat == "ravive":
			for i in 3:
				var p := Vector2((i - 1) * rr * 0.75 + side * 4.0, rr * 0.05 - 7.0)
				O.flower(self, p, 2.4, P.pal(etat, "fleur" if i != 1 else "fleur_2"), P.pal(etat, "fleur_coeur"), i * 1.3)


## Touffe d'herbe haute (stipe) couchée par le vent : deux ou trois touffes de brins qui montent puis
## se rabattent du même côté. Sèche et grège sur la terre morte ; argentée, à longs plumets blancs,
## une fois ravivée.
class Grass extends Flora.DecorTree:
	var lean := 1.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var etat := P.etat_of(self)
		var herbe: Dictionary = P.pal(etat, "herbe")
		var side := signf(lean) if lean != 0.0 else 1.0
		var alive_ := etat == "ravive"
		var tufts := 2 + r.randi() % 2
		O.poly(self, O.blob(Vector2(side * 4.0 * s, 1.5), 13.0 * s, 3.4 * s, float(tree_seed % 97), 0.12, 14), Color(0.04, 0.03, 0.05, 0.22))
		for tf in tufts:
			var at := Vector2(r.randf_range(-12.0, 12.0) * s * tf, r.randf_range(-4.0, 4.0) * s * tf)
			var n := 6 + r.randi() % 4
			for i in n:
				var base := at + Vector2((i - n / 2.0) * 2.2 * s, 0)
				var len := r.randf_range(15.0, 24.0) * s * (1.15 if alive_ else 1.0)
				# Le brin monte puis se couche : vivant, il se redresse un peu.
				var rise := (0.5 if alive_ else 0.38) + r.randf_range(-0.1, 0.1)
				var tip := base + Vector2(side * len * (1.0 - rise * 0.5), -len * rise)
				var mid := base + Vector2(side * len * 0.15, -len * rise * 0.85)
				var col: Color = herbe["ombre"] if i % 3 == 0 else (herbe["clair"] if i % 3 == 1 else herbe["reflet"])
				O.brush(self, O.curve(base, mid, tip, 5), maxf(1.1, 1.7 * s), col, 1.0, 0.0)
				if alive_ and i % 2 == 0:
					# Plumet de stipe : une longue barbe claire qui file sous le vent.
					var end := tip + Vector2(side * len * 0.5, len * 0.08 + r.randf_range(-3.0, 3.0) * s)
					O.brush(self, O.curve(tip, tip.lerp(end, 0.5) + Vector2(0, -2.0 * s), end, 5), maxf(1.2, 2.2 * s), Color(P.pal(etat, "plume"), 0.85), 0.0, 0.0)


## Cairn (repère des plateaux, « rocher » du fichier) : un tas de pierres plates empilées, penché sous
## le vent, des plumes fichées au sommet. Hauteur 16 × size (decor_compose.gd › height_of).
## Pas d'obstacle : dessin seul.
class Cairn extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var etat := P.etat_of(self)
		var st: Dictionary = P.pal(etat, "pierre")
		var h := 16.0 * size
		var side := SolVent.side()
		O.cast_shadow(self, Vector2.ZERO, h * 0.55, h, 0.36)
		# Pierres au pied, éboulées.
		for i in 4:
			var p := Vector2((i - 1.5) * h * 0.2 + r.randf_range(-3, 3), h * 0.03 + r.randf_range(-2, 3))
			O.part(self, O.blob(p, h * r.randf_range(0.06, 0.09), h * 0.04, float(i), 0.2, 10), st, 0.9, 1.0, 0.4)
		# Le tas : sept à huit pierres plates, de plus en plus petites, décalées sous le vent.
		var y := 0.0
		var n := 7 + r.randi() % 2
		var top := Vector2.ZERO
		for i in n:
			var u := float(i) / n
			var rx := h * (0.27 - 0.17 * u) * r.randf_range(0.9, 1.1)
			var ry := h * (0.065 - 0.02 * u) * r.randf_range(0.85, 1.15)
			var c := Vector2(side * h * 0.08 * u * u + r.randf_range(-0.02, 0.02) * h, -y - ry)
			O.part(self, O.blob(c, rx, ry, float(i) * 3.1 + tree_seed % 7, 0.14, 18, r.randf_range(-0.12, 0.12)), st, 1.3, 1.0, 0.5)
			if i % 2 == 0:
				O.poly(self, O.blob(c + Vector2(-rx * 0.3, -ry * 0.3), rx * 0.25, ry * 0.4, c.x, 0.3, 8), Color(P.pal(etat, "lichen"), 0.75))
			y += ry * 1.55
			top = c + Vector2(0, -ry)
		# Plumes fichées au sommet, couchées par le vent.
		for i in 3:
			var a := -PI * 0.5 + side * (0.35 + 0.3 * i) + r.randf_range(-0.1, 0.1)
			P.feather(self, top + Vector2((i - 1) * 2.0, 1.0), a, h * (0.2 - 0.03 * i), etat, side * 0.15)
		if etat == "ravive":
			var herbe: Dictionary = P.pal(etat, "herbe")
			for i in 3:
				O.tuft(self, Vector2((i - 1) * h * 0.3, h * 0.05), 10.0, herbe["clair"], herbe["ombre"], tree_seed + i)
			for i in 4:
				O.flower(self, Vector2((i - 1.5) * h * 0.22, h * 0.02 - 6.0), 2.6, P.pal(etat, "fleur" if i % 2 else "fleur_2"), P.pal(etat, "fleur_coeur"), i * 0.9)


## Dolmen (repère des plateaux, « ruine » du fichier) : deux pierres dressées sous une table de pierre,
## quelques blocs tombés autour. Hauteur 16 × size. Pas d'obstacle : dessin seul.
class Dolmen extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var etat := P.etat_of(self)
		var st: Dictionary = P.pal(etat, "pierre")
		var h := 16.0 * size
		O.cast_shadow(self, Vector2.ZERO, h * 1.1, h * 0.7, 0.36)
		# Bloc tombé derrière.
		O.part(self, O.blob(Vector2(h * 0.5, -h * 0.05), h * 0.16, h * 0.08, 3.0, 0.2, 14, 0.3), st, 1.0, 1.0, 0.4)
		# Deux piliers.
		for sx in [-1.0, 1.0]:
			var x: float = sx * h * 0.28
			var w := h * 0.1
			var pts := PackedVector2Array([Vector2(x - w, 0), Vector2(x - w * 1.1, -h * 0.35), Vector2(x - w * 0.8, -h * 0.62), Vector2(x + w * 0.9, -h * 0.64), Vector2(x + w * 1.05, -h * 0.3), Vector2(x + w, 0)])
			O.part(self, pts, st, 1.3, 1.0, 0.4)
		# Ombre sous la table, puis la table, légèrement de biais.
		O.poly(self, PackedVector2Array([Vector2(-h * 0.2, -h * 0.6), Vector2(h * 0.2, -h * 0.6), Vector2(h * 0.18, -h * 0.4), Vector2(-h * 0.18, -h * 0.4)]), Color(0.04, 0.03, 0.05, 0.45))
		var tab := O.blob(Vector2(0, -h * 0.72), h * 0.52, h * 0.12, 7.0 + tree_seed % 5, 0.1, 22, -0.06)
		O.part(self, tab, st, 1.5, 1.0, 0.6)
		O.brush(self, PackedVector2Array([Vector2(-h * 0.4, -h * 0.74), Vector2(0, -h * 0.79), Vector2(h * 0.38, -h * 0.76)]), 1.2, Color(st["reflet"], 0.6), 0.0, 0.0)
		for i in 4:
			var p := Vector2(r.randf_range(-0.4, 0.4) * h, -h * r.randf_range(0.72, 0.8))
			O.poly(self, O.blob(p, h * 0.04, h * 0.02, p.x, 0.3, 8), Color(P.pal(etat, "lichen"), 0.8))
		var herbe: Dictionary = P.pal(etat, "herbe")
		for i in 4:
			O.tuft(self, Vector2((i - 1.5) * h * 0.3, h * 0.04), 9.0, herbe["clair"], herbe["ombre"], tree_seed + i, etat != "ravive")
		if etat == "ravive":
			# L'herbe a gagné la table : une touffe à plumets et des fleurs blanches.
			O.tuft(self, Vector2(-h * 0.15, -h * 0.8), 9.0, herbe["clair"], herbe["ombre"], tree_seed + 9)
			for i in 5:
				O.flower(self, Vector2((i - 2) * h * 0.2, -4.0 + (h * -0.82 if i == 2 else 0.0)), 2.4, P.pal(etat, "fleur" if i % 2 else "fleur_2"), P.pal(etat, "fleur_coeur"), i * 1.1)
