## Décor des falaises de verre (région d'Aube, « decor » : {"kind": "falaise"} dans
## data/regions/aube.json) : un pays de calcaire pâle et de verre, sous une lumière crue.
##   - les arbres du monde y deviennent des arbres blanchis, couverts de bourgeons de cristal, qui
##     se couvrent de feuillage doré une fois ravivés ;
##   - des grappes de cristaux (prismes de verre fumé) et des blocs de falaise striés de veines de
##     verre font obstacle ;
##   - des éclats de verre jonchent le sol (ils ne gênent pas) : ternes sur la terre morte, ils
##     brillent et des fleurs d'aube poussent entre eux une fois ravivés.
##
## Même contrat que decor_roncier.gd (make_tree, spawn). Budget de dessin (docs/performances.md) :
## chaque élément est un DecorTree, dessiné en un appel par le lot fidèle et redessiné seulement
## quand il reverdit ; les éclats sont groupés par trois à cinq.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const Flora = preload("res://scripts/flora.gd")
const A = preload("res://scripts/region_art/aube.gd")

var flora
## Identifiant de la région et réglages de son décor (« decor » du fichier de la région).
var region := ""
var cfg: Dictionary = {}


func make_tree(_p: Vector2) -> Node2D:
	return Bleached.new()


## Cristaux, blocs de falaise et éclats : tirage à part (graine fixe), pour ne pas déplacer les
## arbres du reste du monde. Le centre de la région (Cœur, arène) et les abords de la graine restent
## libres d'obstacles.
func spawn() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(cfg.get("seed", 33))
	var mid: float = Regions.angle_of(region)
	var half: float = Regions.half_width()
	var center: Vector2 = Regions.center(region)
	var arena: Vector2 = Regions.arena_center(region)
	var arena_r := float(Regions.section(region, "boss").get("arena", {}).get("radius", 460.0))
	var h := 2850.0
	var crystals := int(cfg.get("crystals", 70))
	var cliffs := int(cfg.get("cliffs", 18))
	var clear_center := float(cfg.get("clear_center", 340.0))
	var clear_seed := float(cfg.get("clear_seed", 560.0))
	for i in crystals + cliffs + int(cfg.get("shards", 260)):
		var solid := i < crystals + cliffs
		var cliff := i >= crystals and solid
		var a := mid + r.randf_range(-half, half) * 0.97
		var d := sqrt(r.randf_range(pow(Regions.INNER + 30.0, 2), pow(4000.0, 2)))
		var p := Vector2.from_angle(a) * d
		var sz := r.randf_range(0.8, 1.4)
		var sd := r.randi()
		if absf(p.x) > h or absf(p.y) > h or Regions.weight(p, region) < 0.6:
			continue
		if solid and (p.distance_to(center) < clear_center or p.length() < clear_seed or p.distance_to(arena) < arena_r + 60.0):
			continue
		var t: Flora.DecorTree
		if cliff:
			var c := Cliff.new()
			c.radius = 26.0 + 18.0 * (sz - 0.8) / 0.6
			t = c
		elif solid:
			var g := Crystals.new()
			g.radius = 14.0 + 12.0 * (sz - 0.8) / 0.6
			t = g
		else:
			t = Shards.new()
		t.position = p
		t.size = sz
		t.tree_seed = sd
		t.alive = flora.ground.life_at(p) > flora.ALIVE
		if solid:
			flora.add_obstacle(t)
		flora.trees_parent.add_child(t)
		flora._add_tree(t)


## Arbre blanchi des falaises : un tronc droit et pâle, des branches courtes au bout desquelles
## poussent des bourgeons de cristal. Vivant : un feuillage doré, rond, piqué de reflets.
class Bleached extends Flora.DecorTree:
	func dead_color() -> Color:
		return Art.c("decor").lerp(A.pal("roche_clair"), 0.35)

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var g := growth()
		var bark := dead_color().lerp(Art.ec("racine", "sombre").lerp(A.pal("roche_clair"), 0.3), g)
		flat_shadow(_b, Vector2(0, 1), 12.0 * s)
		var h := r.randf_range(34.0, 46.0) * s
		var top := Vector2(r.randf_range(-4.0, 4.0) * s, -h)
		_b.draw_colored_polygon(limb(Vector2.ZERO, top, 4.2 * s, 1.6 * s), bark)
		var tips: Array = [top]
		var nb := 2 + r.randi() % 2
		for i in nb:
			var k := r.randf_range(0.4, 0.85)
			var base := Vector2.ZERO.lerp(top, k)
			var side := -1.0 if i % 2 == 0 else 1.0
			var tip := base + Vector2.from_angle(-PI / 2.0 + side * r.randf_range(0.6, 1.0)) * r.randf_range(12.0, 18.0) * s
			_b.draw_colored_polygon(limb(base, tip, 1.8 * s, 0.6 * s), bark)
			tips.append(tip)
		_b.draw_line(Vector2(-1.6 * s, -2.0 * s), top + Vector2(-1.0 * s, 4.0 * s), bark.lightened(0.18), maxf(1.0, 1.1 * s))
		# Bourgeons de cristal au bout des branches (ternes morts, clairs vivants).
		var glass := A.pal("verre_fume").lerp(A.pal("verre"), g)
		for tp in tips:
			var q: Vector2 = tp
			_b.draw_colored_polygon(PackedVector2Array([q + Vector2(-2.2, 0) * s, q + Vector2(0, -6.0) * s, q + Vector2(2.2, 0) * s, q + Vector2(0, 1.5) * s]), glass)
		if g <= 0.0:
			return
		var gold := Art.c("decor_vivant").lerp(A.pal("lumiere"), 0.35)
		for i in tips.size():
			var k := bud(i, tips.size())
			if k <= 0.01:
				continue
			var p: Vector2 = tips[i] + Vector2(0, -4.0 * s)
			var rr := (11.0 - 2.0 * (i % 2)) * s * k
			_b.draw_colored_polygon(Art.ellipse(p + Vector2(0, 1.5), rr + 1.5, rr * 0.8 + 1.5, 14), Color(Art.c("contour"), 0.4))
			Art.volume(_b, Art.ellipse(p, rr, rr * 0.8, 14), gold.darkened(0.08 * (i % 3)), 0.6)
			_b.draw_circle(p + Vector2(-rr * 0.3, -rr * 0.3), 1.5 * s * k, A.pal("lumiere_clair"))
		if leaf < 1.0:
			drift_leaves(_b, top, 16.0 * s, leaf, tree_seed)


## Grappe de cristaux : trois à cinq prismes de verre plantés ensemble, solide (cercle de rayon
## « radius »). Morte : verre fumé ; ravivée : verre clair à reflets d'or, fleurs à son pied.
class Crystals extends Flora.DecorTree:
	var radius := 20.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := growth()
		var rr := radius
		flat_shadow(_b, Vector2(0, rr * 0.15), rr * 1.15)
		var glass := A.pal("verre_fume").lerp(A.pal("verre"), 0.25 + 0.6 * g)
		var edge := A.pal("verre").lerp(A.pal("lumiere_clair"), g)
		var n := 3 + r.randi() % 3
		var order: Array = []
		for i in n:
			order.append(i)
		# Du fond vers l'avant : les plus hauts au milieu.
		for i in order:
			var u: float = (i + 0.5) / n - 0.5
			var foot := Vector2(u * rr * 1.7, r.randf_range(-0.15, 0.1) * rr)
			var hgt := rr * (2.1 - absf(u) * 2.0) * r.randf_range(0.8, 1.1)
			A.draw_prism(_b, A.prism(foot, rr * r.randf_range(0.22, 0.32), hgt, u * rr * 0.8), glass, edge)
		if g <= 0.0:
			return
		for i in 3:
			var k := bud(i, 4)
			if k <= 0.01:
				continue
			var p := Vector2((i - 1) * rr * 0.75, rr * 0.2)
			for q in 5:
				_b.draw_circle(p + Vector2.from_angle(TAU * q / 5.0 + i) * 2.4 * k, 2.0 * k, A.pal("lumiere_clair"))
			_b.draw_circle(p, 1.4 * k, A.pal("lumiere"))
		if leaf < 1.0:
			drift_leaves(_b, Vector2(0, -rr), rr * 0.6, leaf, tree_seed)


## Bloc de falaise : une dalle de calcaire pâle aux strates horizontales, fendue d'une veine de
## verre ; solide (cercle de rayon « radius »). Vivant : herbe dorée et lierre clair sur l'arête.
class Cliff extends Flora.DecorTree:
	var radius := 32.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := growth()
		var rr := radius
		var rock := A.pal("roche").lerp(Art.c("sol_mort"), 0.2)
		flat_shadow(_b, Vector2(0, rr * 0.2), rr * 1.25)
		var pts := PackedVector2Array()
		var n := 9
		var rot := r.randf() * 0.4
		for i in n:
			var a := rot + TAU * i / n
			var k := r.randf_range(0.85, 1.08)
			# Plus large que haut, le dessus plat.
			var y := sin(a) * rr * 0.55 * k - rr * 0.5
			if sin(a) < -0.5:
				y = -rr * 1.05 * k
			pts.append(Vector2(cos(a) * rr * 1.2 * k, y))
		Art.volume(_b, pts, rock, 0.6)
		var closed := pts.duplicate()
		closed.append(pts[0])
		_b.draw_polyline(closed, Color(Art.c("contour"), 0.65), Art.TRAIT_FIN + 0.5)
		# Strates.
		for i in 3:
			var y := -rr * (0.2 + 0.25 * i)
			_b.draw_line(Vector2(-rr * (0.95 - 0.1 * i), y), Vector2(rr * (0.9 - 0.15 * i), y + rr * 0.04), rock.darkened(0.2), Art.TRAIT_FIN)
		_b.draw_line(Vector2(-rr * 0.8, -rr * 0.98), Vector2(rr * 0.6, -rr * 1.0), rock.lightened(0.25), Art.TRAIT_FIN)
		# Veine de verre qui fend la dalle.
		var vein := PackedVector2Array([Vector2(rr * 0.1, -rr * 1.0), Vector2(rr * 0.25, -rr * 0.6), Vector2(rr * 0.05, -rr * 0.3), Vector2(rr * 0.2, rr * 0.0)])
		_b.draw_polyline(vein, A.pal("verre_sombre"), 4.0)
		_b.draw_polyline(vein, A.pal("verre_fume").lerp(A.pal("verre"), 0.3 + 0.6 * g), 2.0)
		if g <= 0.0:
			return
		var green := Art.c("decor_vivant").lerp(A.pal("lumiere"), 0.3)
		for i in 5:
			var k := bud(i, 6)
			if k <= 0.01:
				continue
			var foot := Vector2((i - 2) * rr * 0.4, -rr * 1.0)
			_b.draw_colored_polygon(leaf_shape(foot, 8.0 * k, -PI / 2.0 + (i - 2) * 0.4), green)
		if leaf < 1.0:
			drift_leaves(_b, Vector2(0, -rr), rr * 0.7, leaf, tree_seed)


## Éclats de verre au sol : trois à cinq losanges plats. Morts, ternes ; ravivés, ils brillent et
## une petite fleur d'aube pousse entre eux.
class Shards extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var g := growth()
		var glass := A.pal("verre_fume").lerp(A.pal("verre"), 0.2 + 0.6 * g)
		var n := 3 + r.randi() % 3
		for i in n:
			var p := Vector2(r.randf_range(-16.0, 16.0), r.randf_range(-6.0, 6.0)) * s
			var a := r.randf() * PI
			var l := r.randf_range(4.0, 8.0) * s
			var d := Vector2.from_angle(a)
			var nn := Vector2(-d.y, d.x) * l * 0.35 * Vector2(1.0, 0.6)
			var pts := PackedVector2Array([p + d * l * Vector2(1.0, 0.5), p + nn, p - d * l * Vector2(1.0, 0.5), p - nn])
			_b.draw_colored_polygon(pts, glass.darkened(0.1 * (i % 3)))
			_b.draw_line(pts[1], pts[0], Color(A.pal("verre_clair"), 0.35 + 0.5 * g), 1.0)
		if g <= 0.0:
			return
		var k := bud(0, 2)
		if k > 0.01:
			var p := Vector2(r.randf_range(-6.0, 6.0), -2.0) * s
			_b.draw_line(p + Vector2(0, 4) * s, p, Art.c("decor_vivant"), 1.5)
			for q in 5:
				_b.draw_circle(p + Vector2.from_angle(TAU * q / 5.0) * 2.2 * k * s, 1.8 * k * s, A.pal("lumiere_clair"))
			_b.draw_circle(p, 1.2 * k * s, A.pal("lumiere"))
