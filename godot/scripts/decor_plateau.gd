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
	var center: Vector2 = Regions.center(region)
	var lean := _lean()
	var h := 2850.0
	var rocks := int(cfg.get("rocks", 64))
	var clear_center := float(cfg.get("clear_center", 340.0))
	var clear_seed := float(cfg.get("clear_seed", 560.0))
	for i in rocks + int(cfg.get("grass", 150)):
		var rock := i < rocks
		var a := mid + r.randf_range(-half, half) * 0.97
		var d := sqrt(r.randf_range(pow(Regions.INNER + 30.0, 2), pow(4000.0, 2)))
		var p := Vector2.from_angle(a) * d
		var sz := r.randf_range(0.8, 1.4)
		var sd := r.randi()
		if absf(p.x) > h or absf(p.y) > h or Regions.weight(p, region) < 0.6:
			continue
		if rock and (p.distance_to(center) < clear_center or p.length() < clear_seed):
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


## Arbre tordu des plateaux : un tronc bas qui part de biais, des branches toutes rabattues du
## même côté par le vent. Mort : bois gris d'ardoise ; vivant : un feuillage en mèches étirées.
class Twisted extends Flora.DecorTree:
	## Penchant (de -1 à 1) : le côté où le vent couche l'arbre.
	var lean := 1.0

	func dead_color() -> Color:
		return Art.c("decor").lerp(Art.ec("vent", "sombre"), 0.35).lerp(Art.c("sol_mort"), 0.3)

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var g := growth()
		var side := signf(lean) if lean != 0.0 else 1.0
		var bend := 0.55 + 0.45 * absf(lean)
		var bark := dead_color().lerp(Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.2), g)
		flat_shadow(_b, Vector2(side * 8.0 * s, 1), 13.0 * s)
		# Tronc en deux coudes : il monte, puis se rabat sous le vent.
		var h := r.randf_range(30.0, 40.0) * s
		var knee := Vector2(side * r.randf_range(4.0, 9.0) * s, -h * 0.55)
		var top := knee + Vector2(side * h * 0.55 * bend, -h * 0.35)
		_b.draw_colored_polygon(limb(Vector2.ZERO, knee, 4.6 * s, 3.0 * s), bark)
		_b.draw_colored_polygon(limb(knee, top, 3.0 * s, 1.3 * s), bark)
		_b.draw_circle(knee, 3.0 * s, bark)
		# Branches : toutes partent vers le côté du vent, quelques-unes cassées net.
		var tips: Array = [top]
		var nb := 2 + r.randi() % 2
		for i in nb:
			var k := r.randf_range(0.35, 0.95)
			var base := knee.lerp(top, k) if i % 2 == 0 else Vector2.ZERO.lerp(knee, 0.6 + 0.4 * k)
			var a := (-0.35 if side > 0.0 else PI + 0.35) + side * r.randf_range(-0.25, 0.35)
			var tip := base + Vector2.from_angle(a) * r.randf_range(12.0, 20.0) * s
			_b.draw_colored_polygon(limb(base, tip, 1.8 * s, 0.5 * s), bark)
			tips.append(tip)
		# Liseré clair côté lumière.
		_b.draw_line(Vector2(-1.8 * s, -2.0 * s), knee + Vector2(-1.0 * s, 0), bark.lightened(0.14), maxf(1.0, 1.1 * s))
		if g <= 0.0:
			return
		# Feuillage en mèches : des masses étirées dans le sens du vent, qui éclosent tour à tour.
		var green := Art.c("decor_vivant").lerp(Art.c("or"), 0.12)
		for i in tips.size():
			var k := bud(i, tips.size())
			if k <= 0.01:
				continue
			var p: Vector2 = tips[i] + Vector2(side * 6.0 * s, 1.0 * s)
			var rx := (13.0 - 2.0 * (i % 2)) * s * k
			_b.draw_colored_polygon(Art.ellipse(p + Vector2(0, 1.5), rx + 1.5, rx * 0.5 + 1.5, 14), Color(Art.c("contour"), 0.4))
			Art.volume(_b, Art.ellipse(p, rx, rx * 0.5, 14), green.darkened(0.08 * (i % 3)), 0.6)
		if leaf < 1.0:
			drift_leaves(_b, top, 16.0 * s, leaf, tree_seed)


## Rocher des plateaux : bloc plat et anguleux (ou pierre levée, plus haute), solide (cercle de
## rayon « radius »). Une fois la terre ravivée, du lichen clair et quelques fleurs à son pied.
class Stone extends Flora.DecorTree:
	var radius := 24.0
	var standing := false

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := growth()
		var rr := radius
		var stone := Art.c("brume").lerp(Art.ec("vent", "sombre"), 0.35).darkened(0.1)
		flat_shadow(_b, Vector2(0, rr * 0.2), rr * 1.2)
		var pts := PackedVector2Array()
		if standing:
			# Pierre levée : un monolithe effilé, un peu penché.
			var w := rr * 0.55
			var hh := rr * 2.3
			var tilt := r.randf_range(-0.18, 0.18) * hh
			pts = PackedVector2Array([Vector2(-w, rr * 0.15), Vector2(-w * 0.85 + tilt * 0.5, -hh * 0.6), Vector2(-w * 0.3 + tilt, -hh), Vector2(w * 0.45 + tilt, -hh * 0.92), Vector2(w * 0.9 + tilt * 0.4, -hh * 0.45), Vector2(w, rr * 0.15)])
		else:
			# Bloc plat : un polygone cassé, plus large que haut.
			var n := 8
			var rot := r.randf() * 0.6
			for i in n:
				var a := rot + TAU * i / n
				var k := r.randf_range(0.8, 1.08)
				pts.append(Vector2(cos(a) * rr * 1.15 * k, sin(a) * rr * 0.62 * k - rr * 0.35))
		Art.volume(_b, pts, stone, 0.55)
		# Contour sombre, plus léger que celui des acteurs (le décor reste sous les ennemis).
		var closed := pts.duplicate()
		closed.append(pts[0])
		_b.draw_polyline(closed, Color(Art.c("contour"), 0.65), Art.TRAIT_FIN + 0.5)
		# Arête claire sur le dessus, et une fissure.
		if standing:
			_b.draw_line(pts[1].lerp(pts[2], 0.15), pts[2].lerp(pts[3], 0.3), stone.lightened(0.2), Art.TRAIT_FIN)
			_b.draw_line(pts[2].lerp(pts[3], 0.5) + Vector2(0, rr * 0.4), pts[4].lerp(pts[5], 0.4), stone.darkened(0.3), Art.TRAIT_FIN)
		else:
			_b.draw_line(pts[4].lerp(pts[5], 0.3), pts[6].lerp(pts[7], 0.5), stone.lightened(0.18), Art.TRAIT_FIN)
			_b.draw_line(Vector2(-rr * 0.3, -rr * 0.5), Vector2(rr * 0.1, -rr * 0.2), stone.darkened(0.3), Art.TRAIT_FIN)
		if g <= 0.0:
			return
		# Lichen clair du vent sur la pierre, herbe et fleurs à son pied.
		var lichen := Art.ec("vent", "clair").lerp(Art.c("decor_vivant"), 0.45)
		for i in 3:
			var k := bud(i, 6)
			if k <= 0.01:
				continue
			var p := Vector2(r.randf_range(-0.5, 0.5) * rr, -rr * (0.5 + (1.0 if standing else 0.2) * r.randf()))
			_b.draw_colored_polygon(Art.ellipse(p, 5.0 * k, 2.6 * k, 10), lichen)
		var green := Art.c("decor_vivant").lerp(Art.c("or"), 0.2)
		for i in 3:
			var k := bud(i + 3, 6)
			if k <= 0.01:
				continue
			var foot := Vector2((i - 1) * rr * 0.7, rr * 0.18)
			_b.draw_colored_polygon(leaf_shape(foot, 9.0 * k, -PI / 2.0 + (i - 1) * 0.6), green)
			if i != 1:
				for q in 4:
					_b.draw_circle(foot + Vector2(0, -8.0 * k) + Vector2.from_angle(TAU * q / 4.0) * 1.8 * k, 1.4 * k, Art.ec("vent", "clair"))
		if leaf < 1.0:
			drift_leaves(_b, Vector2(0, -rr), rr * 0.6, leaf, tree_seed)


## Touffe d'herbe couchée : trois à cinq brins rabattus dans le sens du vent. Sèche et grise sur la
## terre morte ; blonde, avec des épis, une fois ravivée.
class Grass extends Flora.DecorTree:
	var lean := 1.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var g := growth()
		var side := signf(lean) if lean != 0.0 else 1.0
		var dry := Art.c("decor").lerp(Art.c("brume"), 0.45)
		var blond := Art.c("decor_vivant").lerp(Art.c("or"), 0.35)
		var tufts := 1 + r.randi() % 2
		for tf in tufts:
			var at := Vector2(r.randf_range(-16.0, 16.0), r.randf_range(-6.0, 6.0)) * s * tf
			var n := 3 + r.randi() % 3
			for i in n:
				var base := at + Vector2((i - n / 2.0) * 2.4 * s, 0)
				var len := r.randf_range(12.0, 20.0) * s * (1.0 + 0.3 * g)
				# Le brin monte un peu puis se couche : plus il est vivant, plus il se redresse.
				var rise := 0.35 + 0.25 * g + r.randf_range(-0.08, 0.08)
				var tip := base + Vector2(side * len * (1.0 - rise * 0.5), -len * rise)
				var mid := base.lerp(tip, 0.5) + Vector2(0, -len * 0.12)
				var col := dry.lerp(blond.darkened(0.08 * (i % 3)), g)
				_b.draw_colored_polygon(PackedVector2Array([base + Vector2(-1.3 * s, 0), mid, tip, mid + Vector2(0, 1.2 * s), base + Vector2(1.3 * s, 0)]), col)
				var k := bud(i, n + 1)
				if k > 0.01 and i % 2 == 0:
					# Épi clair au bout du brin.
					_b.draw_colored_polygon(Art.ellipse(tip + Vector2(side * 2.0, -0.5) * s, 3.2 * s * k, 1.4 * s * k, 8), Art.c("or").lerp(Art.ec("vent", "clair"), 0.4))
