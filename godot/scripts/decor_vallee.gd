## Décor de la vallée des sources (région de Sève, « decor » : {"kind": "vallee"} dans
## data/regions/seve.json) : un fond de vallée humide, des saules et des sources.
##   - les arbres du monde y deviennent des saules pleureurs : un tronc court et noueux, une couronne
##     d'où retombent des rideaux de branches ; morts, des fils gris qui pendent ; vivants, des
##     rideaux de feuilles vertes ;
##   - des sources (flaques plates, au sol sous les personnages) : eau croupie et figée tant que la
##     terre est morte, eau claire qui bouillonne et cresson une fois ravivée ;
##   - des blocs moussus font obstacle (peu nombreux : la vallée reste praticable) ;
##   - des fougères, recroquevillées et brunes sur la terre morte, déployées une fois ravivées
##     (elles ne gênent pas).
##
## Même contrat que decor_roncier.gd (make_tree sans tirage au hasard, spawn avec son propre
## tirage, graine « seed » de la région). Budget de dessin (docs/performances.md) : chaque élément
## est un DecorTree, dessiné en un appel par le lot fidèle et redessiné seulement quand il reverdit.
##
## Charte : le décor reste sourd (Art.c("decor"), proche du sol) ; le vert de la sève n'y est qu'une
## nuance de l'eau et des feuilles, jamais une lueur.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const Flora = preload("res://scripts/flora.gd")

var flora
var region := ""
var cfg: Dictionary = {}


func make_tree(_p: Vector2) -> Node2D:
	return Willow.new()


func spawn() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(cfg.get("seed", 33))
	var mid: float = Regions.angle_of(region)
	var half: float = Regions.half_width()
	var h := 2850.0
	var clear_center := float(cfg.get("clear_center", 340.0))
	var clear_seed := float(cfg.get("clear_seed", 560.0))
	# L'étang du Saule reste libre de blocs : le combat s'y joue.
	var arena_c: Vector2 = Regions.arena_center(region)
	var arena_r := float(Regions.section(region, "boss").get("arena", {}).get("radius", 470.0)) + 60.0
	var plan := [["rock", int(cfg.get("rocks", 40))], ["spring", int(cfg.get("springs", 46))], ["fern", int(cfg.get("ferns", 240))]]
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
			if kind == "rock" and (Regions.near_heart(region, p, clear_center) or p.length() < clear_seed or p.distance_to(arena_c) < arena_r):
				continue
			var t: Flora.DecorTree
			match kind:
				"rock":
					var rk := MossRock.new()
					rk.radius = 16.0 + 14.0 * (sz - 0.8) / 0.6
					t = rk
				"spring":
					t = Spring.new()
				_:
					t = Fern.new()
			t.position = p
			t.size = sz
			t.tree_seed = sd
			t.alive = flora.ground.life_at(p) > flora.ALIVE
			if kind == "spring":
				# Au sol, sous les personnages : une source ne passe jamais devant eux.
				flora.add_child(t)
			else:
				flora.trees_parent.add_child(t)
			flora._add_tree(t)
			if kind == "rock":
				flora.add_obstacle(t)


## Saule pleureur : un tronc court et noueux, deux ou trois maîtresses branches, et une couronne d'où
## retombent des rideaux. Mort : des fils gris et nus qui pendent ; vivant : des rideaux de feuilles
## qui éclosent tour à tour, et quelques feuilles qui tombent.
class Willow extends Flora.DecorTree:
	func dead_color() -> Color:
		return Art.c("decor").lerp(Art.c("sol_mort"), 0.3).lerp(Art.ec("seve", "sombre"), 0.12)

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var g := growth()
		var bark := dead_color().lerp(Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.2), g)
		flat_shadow(_b, Vector2(0, 1), 26.0 * s)
		var h := r.randf_range(36.0, 46.0) * s
		var lean := r.randf_range(-0.15, 0.15)
		var top := Vector2(lean * h, -h)
		_b.draw_colored_polygon(limb(Vector2.ZERO, top, 6.0 * s, 3.4 * s), bark)
		# Nœuds du tronc et racines au pied.
		_b.draw_circle(Vector2(lean * h * 0.4, -h * 0.4), 3.2 * s, bark.darkened(0.15))
		for sgn in [-1.0, 1.0]:
			_b.draw_colored_polygon(limb(Vector2(sgn * 2.0 * s, -2.0 * s), Vector2(sgn * 9.0 * s, 2.0 * s), 2.4 * s, 0.6 * s), bark)
		# Maîtresses branches : elles montent en éventail puis s'arquent.
		var crowns: Array = []
		var nb := 3 + r.randi() % 2
		for i in nb:
			var a := -PI / 2.0 + (i - (nb - 1) / 2.0) * 0.55 + r.randf_range(-0.1, 0.1)
			var tip := top + Vector2.from_angle(a) * r.randf_range(18.0, 26.0) * s
			_b.draw_colored_polygon(limb(top, tip, 2.6 * s, 1.0 * s), bark)
			crowns.append(tip)
		_b.draw_line(Vector2(-2.6 * s, -2.0 * s), top + Vector2(-1.5 * s, 2.0 * s), bark.lightened(0.14), maxf(1.0, 1.1 * s))
		# Rideaux qui retombent depuis chaque branche : fils morts, ou feuilles vivantes.
		var dead_strand := dead_color().lightened(0.08)
		var green := Art.c("decor_vivant").lerp(Art.ec("seve", "sombre"), 0.2)
		for i in crowns.size():
			var c: Vector2 = crowns[i]
			var k := bud(i, crowns.size())
			var drop := r.randf_range(34.0, 46.0) * s
			for j in 5:
				var x := (j - 2) * 3.4 * s
				var len := drop * (0.75 + 0.25 * sin(j * 1.7 + i))
				var a0 := c + Vector2(x, 0)
				var a1 := a0 + Vector2(x * 0.3, len)
				if k <= 0.01:
					_b.draw_line(a0, a1, dead_strand, maxf(1.0, 0.9 * s))
				else:
					var col := dead_strand.lerp(green.darkened(0.07 * (j % 3)), k)
					_b.draw_colored_polygon(limb(a0, a0.lerp(a1, 0.5 + 0.5 * k), 3.2 * s * k + 0.8, 1.2 * s), col)
			if k > 0.01:
				Art.volume(_b, Art.ellipse(c + Vector2(0, -1.0 * s), 15.0 * s * k, 7.5 * s * k, 14), green, 0.6)
		if leaf < 1.0:
			drift_leaves(_b, top, 18.0 * s, leaf, tree_seed)


## Source : une flaque plate (bord de vase, eau), au sol. Morte, une eau croupie et figée, de
## l'écume grise ; vivante, une eau claire, des rides qui partent du milieu et du cresson.
class Spring extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := growth()
		var rr := 30.0 * size
		var bank := Art.c("sol_mort").darkened(0.25).lerp(Art.c("sol_vivant").darkened(0.25), g)
		var water := Art.c("sol_mort").darkened(0.3).lerp(Art.ec("racine", "sombre"), 0.3).lerp(Art.ec("seve", "sombre").lerp(Art.ec("vent", "sombre"), 0.3), g)
		_b.draw_colored_polygon(_blob(Vector2(0, 2), rr * 1.12, tree_seed % 89), Color(bank, 0.7))
		_b.draw_colored_polygon(_blob(Vector2.ZERO, rr, tree_seed % 89), water)
		var sheen := Art.c("brume").lerp(Art.ec("seve", "clair"), g)
		_b.draw_colored_polygon(Art.ellipse(Vector2(-rr * 0.3, -rr * 0.16), rr * 0.3, rr * 0.06, 12), Color(sheen, 0.1 + 0.12 * g))
		if g <= 0.0:
			for i in 3:
				var p := Vector2(r.randf_range(-0.5, 0.5) * rr, r.randf_range(-0.2, 0.2) * rr)
				_b.draw_circle(p, 1.5 * size, Color(Art.c("brume"), 0.45))
			return
		# Rides figées du bouillon (le décor n'est redessiné qu'en reverdissant : pas d'animation).
		for i in 2:
			var k := bud(i, 4)
			if k > 0.01:
				var rad := rr * (0.18 + 0.2 * i) * k
				_b.draw_polyline(Art.ellipse(Vector2.ZERO, rad, rad * 0.45, 16), Color(Art.ec("seve", "clair"), 0.35), 1.2)
		# Cresson sur le bord.
		var cress := Art.c("decor_vivant").lightened(0.05)
		for i in 3:
			var k := bud(i + 1, 4)
			if k <= 0.01:
				continue
			var a := r.randf() * TAU
			var p := Vector2(cos(a) * rr * 0.85, sin(a) * rr * 0.42)
			for q in 4:
				_b.draw_circle(p + Vector2.from_angle(TAU * q / 4.0 + i) * 2.6 * size * k, 2.2 * size * k, cress.darkened(0.06 * (q % 2)))

	static func _blob(pos: Vector2, r: float, sd: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			var w := 1.0 + 0.12 * sin(a * 3.0 + sd) + 0.05 * sin(a * 5.0 + sd * 1.7)
			pts.append(pos + Vector2(cos(a), sin(a) * 0.5) * r * w)
		return pts


## Bloc moussu : un rocher rond et usé par l'eau, solide (cercle de rayon « radius »). La mousse,
## grise et sèche sur la terre morte, reverdit et s'étend une fois la terre ravivée.
class MossRock extends Flora.DecorTree:
	var radius := 22.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := growth()
		var rr := radius
		var stone := Art.c("brume").lerp(Art.ec("racine", "sombre"), 0.3).darkened(0.12)
		flat_shadow(_b, Vector2(0, rr * 0.2), rr * 1.15)
		var pts := PackedVector2Array()
		var n := 10
		var rot := r.randf() * 0.5
		for i in n:
			var a := rot + TAU * i / n
			var k := r.randf_range(0.88, 1.05)
			pts.append(Vector2(cos(a) * rr * 1.05 * k, sin(a) * rr * 0.7 * k - rr * 0.4))
		Art.volume(_b, pts, stone, 0.55)
		var closed := pts.duplicate()
		closed.append(pts[0])
		_b.draw_polyline(closed, Color(Art.c("contour"), 0.6), Art.TRAIT_FIN + 0.5)
		_b.draw_line(Vector2(-rr * 0.5, -rr * 0.75), Vector2(rr * 0.1, -rr * 0.9), stone.lightened(0.18), Art.TRAIT_FIN)
		# Mousse : une calotte sur le dessus, sèche morte, verte vivante.
		var moss := Art.c("decor").lerp(Art.c("brume"), 0.3).lerp(Art.c("decor_vivant").lerp(Art.ec("seve", "sombre"), 0.2), g)
		var cap := Art.ellipse(Vector2(r.randf_range(-0.15, 0.15) * rr, -rr * 0.85), rr * (0.45 + 0.3 * g), rr * (0.18 + 0.08 * g), 12)
		_b.draw_colored_polygon(cap, moss)
		if g <= 0.0:
			return
		for i in 3:
			var k := bud(i, 4)
			if k <= 0.01:
				continue
			var foot := Vector2((i - 1) * rr * 0.75, rr * 0.2)
			_b.draw_colored_polygon(leaf_shape(foot, 8.0 * k, -PI / 2.0 + (i - 1) * 0.5), Art.c("decor_vivant"))
		if leaf < 1.0:
			drift_leaves(_b, Vector2(0, -rr), rr * 0.6, leaf, tree_seed)


## Fougère : trois à cinq frondes en éventail. Mortes, des crosses brunes recroquevillées au ras du
## sol ; vivantes, des frondes vertes déployées, découpées en folioles.
class Fern extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var g := growth()
		var brown := Art.c("decor").lerp(Art.ec("racine", "sombre"), 0.35).lerp(Art.c("sol_mort"), 0.25)
		var green := Art.c("decor_vivant").lerp(Art.ec("seve", "sombre"), 0.15)
		_b.draw_colored_polygon(Art.ellipse(Vector2(0, 1.5), 11.0 * s, 3.2 * s, 10), Color(Art.c("ombre"), 0.25))
		var n := 3 + r.randi() % 3
		for i in n:
			var a := -PI / 2.0 + (i - (n - 1) / 2.0) * 0.5 + r.randf_range(-0.12, 0.12)
			var k := bud(i, n + 1)
			var len := r.randf_range(14.0, 22.0) * s * (0.45 + 0.55 * k)
			var col := brown.lerp(green.darkened(0.07 * (i % 3)), k)
			var tip := Vector2.from_angle(a) * len
			if k <= 0.01:
				# Crosse : la fronde reste enroulée sur elle-même.
				var c := tip * 0.6
				_b.draw_line(Vector2.ZERO, c, col, maxf(1.0, 1.4 * s))
				_b.draw_circle(c, 2.6 * s, col)
				_b.draw_circle(c, 1.2 * s, col.darkened(0.3))
				continue
			# Fronde : une nervure arquée, des folioles de part et d'autre.
			var bend := Vector2(sign(cos(a)) * len * 0.15, len * 0.12)
			var mid := tip * 0.5 + Vector2(0, -len * 0.08)
			_b.draw_polyline(PackedVector2Array([Vector2.ZERO, mid, tip + bend]), col, maxf(1.0, 1.2 * s))
			for j in 4:
				var u := 0.3 + 0.17 * j
				var p := Vector2.ZERO.lerp(mid, u * 2.0) if u < 0.5 else mid.lerp(tip + bend, (u - 0.5) * 2.0)
				var d := (tip + bend - Vector2.ZERO).normalized()
				var w := (1.0 - u) * 6.0 * s * k
				for sgn in [-1.0, 1.0]:
					_b.draw_colored_polygon(PackedVector2Array([p, p + d.orthogonal() * w * sgn + d * w * 0.4, p + d * w * 0.6]), col)
