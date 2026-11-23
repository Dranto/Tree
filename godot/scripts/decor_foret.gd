## Décor de la forêt pétrifiée (région de Racine, « decor » : {"kind": "foret"} dans
## data/regions/racine.json) : une futaie changée en pierre, d'où sortent des racines géantes.
##   - les arbres du monde y deviennent des troncs pétrifiés : un fût de pierre grise veinée d'ocre,
##     cassé net au sommet, deux moignons de branches ; vivants, la mousse gagne le pied, un lierre
##     y grimpe, et une jeune couronne de feuilles pousse sur la cassure ;
##   - des racines géantes sortent d'une dalle de roche et y replongent en arches : elles font
##     obstacle (cercle de rayon « radius ») ; mortes, de la pierre ; vivantes, du bois brun et
##     moussu, et des pousses sur le dos des arches ;
##   - des souches pétrifiées, aux cernes de pierre (elles ne gênent pas) ; vivantes, un rejet vert
##     et des champignons au pied ;
##   - des éboulis de cailloux à plat, au sol sous les personnages ; vivants, des lichens clairs.
##
## Même contrat que decor_roncier.gd (make_tree sans tirage au hasard, spawn avec son propre
## tirage, graine « seed » de la région). Budget de dessin (docs/performances.md) : chaque élément
## est un DecorTree, dessiné en un appel par le lot fidèle et redessiné seulement quand il reverdit.
##
## Charte : le décor reste sourd (Art.c("decor"), pierre proche du sol) ; l'ocre de Racine n'y est
## qu'une veine, et le vert n'arrive qu'avec la vie.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const Flora = preload("res://scripts/flora.gd")

var flora
var region := ""
var cfg: Dictionary = {}


func make_tree(_p: Vector2) -> Node2D:
	return StoneTree.new()


func spawn() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(cfg.get("seed", 47))
	var mid: float = Regions.angle_of(region)
	var half: float = Regions.half_width()
	var h := 2850.0
	var clear_center := float(cfg.get("clear_center", 340.0))
	var clear_seed := float(cfg.get("clear_seed", 560.0))
	# La clairière de l'Ancien reste libre de racines : le combat s'y joue.
	var arena_c: Vector2 = Regions.arena_center(region)
	var arena_r := float(Regions.section(region, "boss").get("arena", {}).get("radius", 480.0)) + 60.0
	var plan := [["root", int(cfg.get("roots", 30))], ["stump", int(cfg.get("stumps", 54))], ["lichen", int(cfg.get("lichens", 230))]]
	for entry in plan:
		var kind: String = entry[0]
		for i in int(entry[1]):
			var a := mid + r.randf_range(-half, half) * 0.97
			var d := sqrt(r.randf_range(pow(Regions.INNER + 30.0, 2), pow(4000.0, 2)))
			var p := Vector2.from_angle(a) * d
			var sz := r.randf_range(0.8, 1.4)
			var sd := r.randi()
			if absf(p.x) > h or absf(p.y) > h or Regions.weight(p, region) < 0.6:
				continue
			if kind == "root" and (Regions.near_heart(region, p, clear_center) or p.length() < clear_seed or p.distance_to(arena_c) < arena_r):
				continue
			var t: Flora.DecorTree
			match kind:
				"root":
					var rt := GiantRoot.new()
					rt.radius = 20.0 + 14.0 * (sz - 0.8) / 0.6
					t = rt
				"stump":
					t = Stump.new()
				_:
					t = Scree.new()
			t.position = p
			t.size = sz
			t.tree_seed = sd
			t.alive = flora.ground.life_at(p) > flora.ALIVE
			if kind == "lichen":
				# Au sol, sous les personnages : un éboulis ne passe jamais devant eux.
				flora.add_child(t)
			else:
				flora.trees_parent.add_child(t)
			flora._add_tree(t)
			if kind == "root":
				flora.add_obstacle(t)


## Base des éléments de la forêt : les deux matières, pierre et bois vivant.
class Petrified extends Flora.DecorTree:
	## Pierre du décor : grise, un peu chaude (l'ocre de Racine), sourde.
	static func stone() -> Color:
		return Art.c("brume").lerp(Art.c("decor"), 0.45).lerp(Art.ec("racine", "sombre"), 0.18).darkened(0.12)

	## Bois vivant : l'écorce brune de Racine, un peu moussue.
	static func wood() -> Color:
		return Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.18).lightened(0.06)


## Tronc pétrifié : un fût de pierre cassé net, veiné d'ocre, deux moignons de branches. Vivant :
## la mousse au pied, un lierre qui grimpe, une jeune couronne qui pousse sur la cassure.
class StoneTree extends Petrified:
	func dead_color() -> Color:
		return stone()

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var g := growth()
		var bark := stone().lerp(wood(), g * 0.55)
		flat_shadow(_b, Vector2(0, 1), 22.0 * s)
		var h := r.randf_range(38.0, 52.0) * s
		var lean := r.randf_range(-0.08, 0.08)
		var top := Vector2(lean * h, -h)
		var w0 := 7.5 * s
		var w1 := 5.0 * s
		# Le fût, et sa cassure en dents de scie.
		var n := Vector2(1, 0)
		var fut := PackedVector2Array([Vector2(-w0, 0), Vector2(-w0 * 1.25, 3.0 * s), Vector2(w0 * 1.25, 3.0 * s), Vector2(w0, 0)])
		fut.append(top + Vector2(w1, 0))
		fut.append(top + Vector2(w1 * 0.4, -5.0 * s))
		fut.append(top + Vector2(0.0, -1.5 * s))
		fut.append(top + Vector2(-w1 * 0.5, -7.0 * s))
		fut.append(top + Vector2(-w1, -2.0 * s))
		Art.volume(_b, fut, bark, 0.55)
		var closed := fut.duplicate()
		closed.append(fut[0])
		_b.draw_polyline(closed, Color(Art.c("contour"), 0.55), Art.TRAIT_FIN + 0.4)
		# Veines d'ocre et fentes de la pierre.
		var vein := Art.ec("racine", "sombre").lerp(Art.ec("racine"), 0.4)
		for i in 2:
			var x := (i - 0.5) * w0 * 0.8 + r.randf_range(-1.0, 1.0) * s
			var y0 := -h * r.randf_range(0.15, 0.3)
			var y1 := -h * r.randf_range(0.6, 0.85)
			_b.draw_polyline(PackedVector2Array([Vector2(x, y0), Vector2(x + 2.0 * s, (y0 + y1) * 0.5), Vector2(x + lean * h * 0.5, y1)]), Color(vein, 0.7 - 0.4 * g), maxf(1.0, 1.1 * s))
		_b.draw_line(Vector2(-w0 * 0.55, -2.0 * s), top + Vector2(-w1 * 0.5, 3.0 * s), stone().lightened(0.16), maxf(1.0, 1.0 * s))
		# Moignons de branches.
		for sgn in [-1.0, 1.0]:
			var base: Vector2 = top * r.randf_range(0.55, 0.8) + n * sgn * w1 * 0.8
			var tip: Vector2 = base + Vector2(sgn * r.randf_range(9.0, 14.0), -r.randf_range(5.0, 10.0)) * s
			_b.draw_colored_polygon(limb(base, tip, 2.8 * s, 1.6 * s), bark.darkened(0.06))
			_b.draw_colored_polygon(Art.ellipse(tip, 1.8 * s, 1.4 * s, 8), bark.lightened(0.12))
		# Racines au pied, pétrifiées elles aussi.
		for sgn in [-1.0, 1.0]:
			_b.draw_colored_polygon(limb(Vector2(sgn * w0 * 0.6, -1.0 * s), Vector2(sgn * (w0 + 8.0 * s), 3.0 * s), 3.0 * s, 0.8 * s), bark.darkened(0.08))
		if g <= 0.0:
			return
		# Vivant : mousse au pied, lierre qui monte, jeune couronne sur la cassure.
		var green := Art.c("decor_vivant")
		var k0 := bud(0, 3)
		if k0 > 0.01:
			_b.draw_colored_polygon(Art.ellipse(Vector2(0, 0.5 * s), (w0 + 4.0 * s) * k0, 3.5 * s * k0, 12), green.darkened(0.12))
		var k1 := bud(1, 3)
		if k1 > 0.01:
			var prev := Vector2(-w0 * 0.7, -2.0 * s)
			for j in 5:
				var u := (j + 1) / 5.0 * k1
				var q := Vector2(-w0 * 0.7 + sin(u * 7.0) * w0 * 0.6, -h * 0.8 * u)
				_b.draw_line(prev, q, green.darkened(0.2), maxf(1.0, 1.2 * s))
				_b.draw_colored_polygon(leaf_shape(q, 4.0 * s, PI if j % 2 == 0 else 0.0), green.darkened(0.05 * (j % 2)))
				prev = q
		var k2 := bud(2, 3)
		if k2 > 0.01:
			var crown := top + Vector2(0, -6.0 * s)
			for i in 3:
				var c2 := crown + Vector2((i - 1) * 7.0 * s, -3.0 * s * (1 - absf(i - 1))) * k2
				Art.volume(_b, Art.ellipse(c2, 8.5 * s * k2, 6.0 * s * k2, 12), green.lerp(Art.ec("racine", "clair"), 0.15).darkened(0.05 * i), 0.6)
		if leaf < 1.0:
			drift_leaves(_b, top, 14.0 * s, leaf, tree_seed)


## Racine géante : une dalle de roche d'où sortent deux ou trois racines énormes qui s'arquent et
## replongent dans le sol. Solide (cercle de rayon « radius »). Morte : tout est pierre ; vivante,
## le bois reprend sa couleur, la mousse s'y pose, des pousses sur le dos des arches.
class GiantRoot extends Petrified:
	var radius := 24.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := growth()
		var rr := radius
		var rock := stone().darkened(0.05)
		flat_shadow(_b, Vector2(0, rr * 0.2), rr * 1.4)
		# La dalle : un bloc bas et anguleux.
		var pts := PackedVector2Array()
		var n := 8
		var rot := r.randf() * 0.6
		for i in n:
			var a := rot + TAU * i / n
			var k := r.randf_range(0.85, 1.05)
			pts.append(Vector2(cos(a) * rr * 0.95 * k, sin(a) * rr * 0.55 * k - rr * 0.25))
		Art.volume(_b, pts, rock, 0.55)
		var closed := pts.duplicate()
		closed.append(pts[0])
		_b.draw_polyline(closed, Color(Art.c("contour"), 0.55), Art.TRAIT_FIN + 0.5)
		# Les arches : chaque racine part de la dalle, monte et redescend plus loin.
		var root := rock.lightened(0.06).lerp(wood(), g)
		var arches := 2 + r.randi() % 2
		var tops: Array = []
		for i in arches:
			var side := -1.0 if i % 2 == 0 else 1.0
			var start := Vector2(side * rr * r.randf_range(0.1, 0.4), -rr * 0.45)
			var end := Vector2(side * rr * r.randf_range(1.3, 1.8), rr * r.randf_range(-0.05, 0.25))
			var peak := start.lerp(end, 0.45) + Vector2(0, -rr * r.randf_range(0.7, 1.05))
			var w := rr * r.randf_range(0.16, 0.22)
			var segs := 7
			var prev := start
			for j in segs:
				var u := (j + 1.0) / segs
				var q := start.lerp(peak, u).lerp(peak.lerp(end, u), u)
				var ww := w * (1.0 - 0.45 * u)
				_b.draw_colored_polygon(limb(prev, q, ww * (1.0 + 0.45 / segs), ww), root.darkened(0.04 * (j % 2)))
				prev = q
			# Arête claire sur le dos de l'arche.
			_b.draw_polyline(PackedVector2Array([start + Vector2(0, -w * 0.6), peak + Vector2(0, -w * 0.6), end.lerp(peak, 0.35) + Vector2(0, -w * 0.4)]), root.lightened(0.15), maxf(1.0, w * 0.25))
			tops.append(peak + Vector2(0, -w * 0.7))
		# Veines d'ocre dans la dalle.
		_b.draw_line(Vector2(-rr * 0.5, -rr * 0.2), Vector2(rr * 0.2, -rr * 0.35), Color(Art.ec("racine", "sombre"), 0.6), Art.TRAIT_FIN)
		if g <= 0.0:
			return
		var green := Art.c("decor_vivant")
		for i in tops.size():
			var k := bud(i, tops.size() + 1)
			if k <= 0.01:
				continue
			var q: Vector2 = tops[i]
			_b.draw_colored_polygon(Art.ellipse(q + Vector2(0, 2.0), rr * 0.32 * k, rr * 0.1 * k + 0.5, 10), green.darkened(0.1))
			for j in 2:
				_b.draw_colored_polygon(leaf_shape(q, 7.0 * k, -PI / 2.0 + (j - 0.5) * 0.9), green)
		var km := bud(tops.size(), tops.size() + 1)
		if km > 0.01:
			_b.draw_colored_polygon(Art.ellipse(Vector2(r.randf_range(-0.2, 0.2) * rr, -rr * 0.55), rr * 0.5 * km, rr * 0.14 * km + 0.5, 12), green.darkened(0.15))
		if leaf < 1.0:
			drift_leaves(_b, Vector2(0, -rr), rr * 0.7, leaf, tree_seed)


## Souche pétrifiée : un tronc coupé bas, ses cernes changés en pierre. Vivante : un rejet vert
## sort de la cassure, et deux champignons au pied.
class Stump extends Petrified:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var g := growth()
		var bark := stone().lerp(wood(), g * 0.5)
		flat_shadow(_b, Vector2(0, 1), 13.0 * s)
		var w := 8.0 * s
		var h := r.randf_range(8.0, 13.0) * s
		var body := PackedVector2Array([Vector2(-w, 0), Vector2(-w * 1.2, 2.5 * s), Vector2(w * 1.2, 2.5 * s), Vector2(w, 0), Vector2(w * 0.95, -h), Vector2(-w * 0.95, -h)])
		Art.volume(_b, body, bark, 0.5)
		# Le dessus : l'ellipse des cernes, plus claire.
		var top := Art.ellipse(Vector2(0, -h), w * 0.95, w * 0.38, 14)
		_b.draw_colored_polygon(top, bark.lightened(0.14))
		for i in 2:
			_b.draw_polyline(Art.ellipse(Vector2(0.6 * s, -h), w * (0.3 + 0.28 * i), w * (0.12 + 0.1 * i), 12), Color(bark.darkened(0.3), 0.8), maxf(1.0, 0.8 * s))
		_b.draw_line(Vector2(-w * 0.5, -h * 0.85), Vector2(-w * 0.4, -1.0 * s), bark.darkened(0.2), maxf(1.0, 0.9 * s))
		if g <= 0.0:
			return
		var green := Art.c("decor_vivant")
		var k := bud(0, 2)
		if k > 0.01:
			var tip := Vector2(w * 0.3, -h - 12.0 * s * k)
			_b.draw_line(Vector2(w * 0.3, -h), tip, green.darkened(0.2), maxf(1.0, 1.2 * s))
			_b.draw_colored_polygon(leaf_shape(tip, 6.0 * s * k, -PI / 2.0 - 0.6), green)
			_b.draw_colored_polygon(leaf_shape(tip, 5.0 * s * k, -PI / 2.0 + 0.7), green.darkened(0.06))
		var km := bud(1, 2)
		if km > 0.01:
			var cap := Art.ec("racine", "clair").lerp(Art.c("decor_vivant"), 0.3).lightened(0.1)
			for sgn in [-1.0, 1.0]:
				var foot := Vector2(sgn * (w + 3.0 * s), 1.5 * s)
				_b.draw_line(foot, foot + Vector2(0, -4.0 * s * km), Art.c("brume"), maxf(1.0, 1.0 * s))
				_b.draw_colored_polygon(Art.ellipse(foot + Vector2(0, -4.5 * s * km), 3.0 * s * km + 0.3, 1.6 * s * km + 0.3, 10), cap)


## Éboulis : des cailloux à plat, au sol. Vivant : des lichens clairs les couvrent.
class Scree extends Petrified:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var g := growth()
		var rock := stone()
		var n := 3 + r.randi() % 3
		for i in n:
			var p := Vector2(r.randf_range(-12.0, 12.0), r.randf_range(-4.0, 4.0)) * s
			var rr := r.randf_range(2.5, 5.0) * s
			_b.draw_colored_polygon(Art.ellipse(p + Vector2(0, rr * 0.35), rr * 1.05, rr * 0.45, 8), Color(Art.c("ombre"), 0.2))
			_b.draw_colored_polygon(Art.ellipse(p, rr, rr * 0.62, 8), rock.darkened(0.06 * (i % 3)))
			_b.draw_colored_polygon(Art.ellipse(p + Vector2(-rr * 0.25, -rr * 0.2), rr * 0.45, rr * 0.2, 6), rock.lightened(0.12))
			var k := bud(i, n)
			if k > 0.01:
				var lichen := Art.ec("racine", "clair").lerp(Art.c("brume"), 0.35 * (i % 2))
				_b.draw_colored_polygon(Art.ellipse(p + Vector2(rr * 0.2, -rr * 0.1), rr * 0.55 * k + 0.3, rr * 0.3 * k + 0.3, 8), Color(lichen, 0.85))
		if g > 0.0 and r.randf() < 0.5:
			var k2 := bud(n - 1, n)
			if k2 > 0.01:
				var q := Vector2(r.randf_range(-8.0, 8.0), -2.0) * s
				_b.draw_colored_polygon(leaf_shape(q, 5.0 * s * k2, -PI / 2.0 - 0.4), Art.c("decor_vivant"))
				_b.draw_colored_polygon(leaf_shape(q, 4.5 * s * k2, -PI / 2.0 + 0.5), Art.c("decor_vivant").darkened(0.08))
