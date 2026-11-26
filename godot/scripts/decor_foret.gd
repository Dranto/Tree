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
## Refonte du monde, vague 2 (P6, « Paysages d'herbier ») : tout est redessiné à l'encre fine du décor,
## deux tons et un reflet, lumière d'en haut à gauche, ombre portée en bas à droite (world_art/outils.gd),
## aux couleurs de Art.MONDE › racine. Flétri : de la pierre grise et froide qui garde le grain du bois,
## veinée d'ocre ; ravivé : l'écorce reprend son brun chaud, la mousse olive s'y pose, et les couronnes
## repoussent en feuillage d'automne, or et ocre. Ajouts : des racines en arceaux (RootArch, sans
## collision) dans les lisières, et l'arbre de pierre géant (Ancient), repère visible de loin. Le décor est
## cuit (world_bake/decor_bake.gd) : dessiner directement sur le nœud ne coûte rien en jeu.
## Dessin seul : les obstacles (racines géantes) gardent leur place et leur rayon.
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

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
	## Pierre du décor : grise, un peu chaude (l'ocre de Racine), sourde (ancien dessin, gardée pour le
	## mur de l'arène et les appels extérieurs).
	static func stone() -> Color:
		return Art.mc("racine", "fletri", "bois")["clair"]

	## Bois vivant : l'écorce brune de Racine.
	static func wood() -> Color:
		return Art.mc("racine", "ravive", "bois")["clair"]

	## État dessiné : ravivé dès que la vie l'a gagné à moitié (la cuisson garde les deux images).
	func etat() -> String:
		return "ravive" if alive and growth() > 0.5 else "fletri"

	func pal(key: String):
		return Art.mc("racine", etat(), key)

	func dead_color() -> Color:
		return stone()

	## Grain du bois (pierre ou écorce) : traits fins presque verticaux qui suivent le fût.
	func grain(a: Vector2, b: Vector2, w: float, n: int, col: Color, r: RandomNumberGenerator) -> void:
		for i in n:
			var x := (i + 0.5) / n * 2.0 - 1.0
			var pts := PackedVector2Array()
			for j in 6:
				var u := j / 5.0
				var q := a.lerp(b, u * r.randf_range(0.8, 1.0))
				pts.append(q + Vector2(x * w * (1.0 - 0.35 * u) + sin(u * 6.0 + i) * w * 0.08, 0))
			O.brush(self, pts, 0.9, col, 0.3, 0.3)

	## Mousse olive (ravivé) : une tache bosselée qui déborde un peu.
	func moss(c: Vector2, rx: float, ry: float, seed: float) -> void:
		var m: Dictionary = Art.mc("racine", "ravive", "mousse")
		O.part(self, Ink.lumpy(c, rx, ry, 16, 0.18, 7.0, seed), m, 0.8, 1.0, 0.4)

	## Couronne d'automne : un nuage de masses bosselées or et ocre (quelques-unes olive) dans une
	## ellipse rx × ry autour de c, peintes du fond vers l'avant ; les branches tips y entrent.
	func crown(c: Vector2, rx: float, ry: float, n: int, mass: float, r: RandomNumberGenerator, tips := []) -> void:
		Petrified.paint_crown(self, c, rx, ry, n, mass, r, tips)

	static func paint_crown(ci: CanvasItem, c: Vector2, rx: float, ry: float, n: int, mass: float, r: RandomNumberGenerator, tips := []) -> void:
		var leaf: Dictionary = Art.mc("racine", "ravive", "feuillage")
		var mo: Dictionary = Art.mc("racine", "ravive", "mousse")
		var masses := []
		for tp in tips:
			masses.append([tp, mass * r.randf_range(0.75, 0.95), false])
		for i in n:
			var a := r.randf() * TAU
			var d := sqrt(r.randf())
			var p := c + Vector2(cos(a) * rx * d, sin(a) * ry * d)
			masses.append([p, mass * r.randf_range(0.75, 1.1) * (1.0 - 0.25 * d), r.randf() < 0.18])
		masses.sort_custom(func(x, y): return x[0].y < y[0].y)
		# Encre d'abord, d'un seul tenant : la couronne se lit comme une masse, pas comme des boules.
		for ms in masses:
			O.poly(ci, Ink.lumpy(ms[0] + Vector2(0.6, 0.8), ms[1] + 1.2, (ms[1] + 1.2) * 0.84, 20, 0.12, 8.0, ms[0].x), Art.mc("commun", "", "encre_decor"))
		for ms in masses:
			var pal: Dictionary = mo if ms[2] else leaf
			var p: Vector2 = ms[0]
			var rr: float = ms[1]
			O.poly(ci, Ink.lumpy(p, rr, rr * 0.82, 20, 0.12, 8.0, p.x), pal["ombre"])
			O.poly(ci, Ink.lumpy(p + Vector2(-0.18, -0.22) * rr, rr * 0.8, rr * 0.62, 18, 0.14, 7.0, p.y), pal["clair"])
			O.poly(ci, Ink.lumpy(p + Vector2(-0.38, -0.42) * rr, rr * 0.32, rr * 0.22, 12, 0.2, 5.0, p.x), Color(pal["reflet"], 0.75))
		# Feuilles d'or détachées au bord.
		for i in n / 2 + 2:
			var ms: Array = masses[r.randi() % masses.size()]
			var p: Vector2 = ms[0] + Vector2(r.randf_range(-1.0, 1.0), r.randf_range(-0.6, 0.7)) * ms[1]
			O.poly(ci, Ink.leaf(p, r.randf_range(0.0, TAU), ms[1] * 0.45, ms[1] * 0.2, 0.2), Art.mc("racine", "ravive", "feuille" if i % 2 else "feuille_2"))

	## Branche de pierre ou de bois qui se divise (au pinceau, encre, ombre, filet clair côté lumière) ;
	## broken : cassée net, la tranche claire au bout (flétri). Les bouts vont dans tips.
	static func branch(ci: CanvasItem, from: Vector2, dir: Vector2, l: float, w: float, depth: int, r: RandomNumberGenerator, bois: Dictionary, tips: Array, broken: bool) -> void:
		var bend := dir.rotated(r.randf_range(-0.3, 0.3))
		var to := from + bend * l
		var mid := from.lerp(to, 0.5) + dir.orthogonal() * r.randf_range(-0.14, 0.14) * l
		var pts := O.curve(from, mid, to, 6)
		var end := 0.35 if broken and depth <= 0 else 0.75
		O.brush(ci, pts, w + 1.4, Ink.encre(), 0.0, end)
		O.brush(ci, pts, w, bois["ombre"], 0.0, end)
		var off := Vector2(-0.35, -0.45) * w * 0.3
		O.brush(ci, O.curve(from + off, mid + off, to, 6), w * 0.38, bois["clair"], 0.0, 0.6)
		if depth <= 0:
			if broken:
				O.poly(ci, Ink.oval(to, w * 0.42, w * 0.3, 10), bois["reflet"])
			tips.append(to)
			return
		for sgn in [-1.0, 1.0]:
			var k := r.randf_range(0.6, 0.95)
			branch(ci, from.lerp(to, k), dir.rotated(sgn * r.randf_range(0.35, 0.7)), l * r.randf_range(0.5, 0.7), w * 0.6, depth - 1, r, bois, tips, broken)
		if not broken:
			tips.append(to)


## Tronc pétrifié : un fût de pierre cassé net, au grain du bois, veiné d'ocre, des moignons de
## branches ; vivant, l'écorce reprend sa couleur, la mousse et le lierre montent, une couronne
## d'automne repousse sur la cassure. Hauteur ≈ 52 px × size (decor_compose.gd › height_of).
class StoneTree extends Petrified:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var h := 52.0 * size
		var e := etat()
		var bois: Dictionary = pal("bois")
		var fl := -1.0 if tree_seed & 1 else 1.0
		var w := h * 0.075
		O.cast_shadow(self, Vector2.ZERO, h * 0.42, h * 0.62, 0.3 if e == "ravive" else 0.36)
		var lean := r.randf_range(-0.05, 0.05) * fl
		var top := Vector2(lean * h, -h * 0.64)
		# Racines au pied, en coups de pinceau qui plongent dans le sol.
		for sgn in [-1.0, 1.0, 0.35]:
			var a := Vector2(sgn * w * 0.6, -h * 0.04)
			var b := Vector2(sgn * w * 2.8 + r.randf_range(-2, 2), r.randf_range(1.0, 3.0))
			O.brush(self, O.curve(a, a.lerp(b, 0.5) + Vector2(0, -w * 0.4), b, 5), w * 0.9, bois["ombre"], 0.0, 1.0)
		var jag := r.randf_range(0.04, 0.09) * h
		var fut := PackedVector2Array([
			Vector2(-w * 2.0, 2), Vector2(-w * 1.05, -h * 0.08), top + Vector2(-w * 0.8, 0),
			top + Vector2(-w * 0.55, -jag), top + Vector2(-w * 0.1, -jag * 0.3), top + Vector2(w * 0.25, -jag * 1.2),
			top + Vector2(w * 0.8, -jag * 0.2), Vector2(w * 1.1, -h * 0.09), Vector2(w * 2.1, 2),
			Vector2(w * 0.5, -h * 0.02), Vector2(-w * 0.4, -h * 0.025)])
		O.part(self, fut, bois, 1.5, 1.0, 0.45)
		grain(Vector2(0, -h * 0.05), top + Vector2(0, h * 0.02), w * 0.8, 3, Color(bois["ombre"], 0.65), r)
		# Cassure : la tranche plus claire, ses cernes.
		var cut := top + Vector2(w * 0.05, -jag * 0.55)
		O.poly(self, Ink.oval(cut, w * 0.7, w * 0.22, 12), bois["reflet"].lerp(bois["clair"], 0.5))
		self.draw_arc(cut, w * 0.35, 0.0, TAU, 12, Color(bois["ombre"], 0.6), 0.8, true)
		if e == "fletri":
			# Veines d'ocre dans la pierre, et une fente sombre.
			var vein: Color = Art.mc("racine", "fletri", "veine")
			for i in 2:
				var x := (i - 0.5) * w * 0.9
				O.brush(self, O.curve(Vector2(x, -h * r.randf_range(0.12, 0.25)), Vector2(x + w * 0.5, -h * 0.38), Vector2(x + lean * h * 0.5, -h * r.randf_range(0.48, 0.58)), 5), 1.1, Color(vein, 0.75), 0.4, 0.4)
			O.brush(self, PackedVector2Array([top + Vector2(w * 0.25, -jag), top + Vector2(w * 0.1, h * 0.12), top + Vector2(w * 0.3, h * 0.22)]), 1.4, Art.mc("commun", "", "encre_decor"), 0.0, 1.0)
		# Branches : moignons de pierre (flétri) ou branches qui portent la couronne (ravivé).
		var tips := []
		for sgn in [-1.0, 1.0]:
			var base: Vector2 = top * r.randf_range(0.55, 0.85) + Vector2(sgn * w * 0.6, 0)
			var tip: Vector2 = base + Vector2(sgn * r.randf_range(0.16, 0.24), -r.randf_range(0.1, 0.2)) * h
			if e == "fletri":
				O.brush(self, PackedVector2Array([base, base.lerp(tip, 0.5) + Vector2(0, -h * 0.02), tip]), w * 0.75, bois["ombre"], 0.0, 0.35)
				O.brush(self, PackedVector2Array([base + Vector2(0, -w * 0.2), tip + Vector2(0, -w * 0.2)]), w * 0.25, bois["clair"], 0.0, 0.5)
				O.poly(self, Ink.oval(tip, w * 0.3, w * 0.22, 8), bois["reflet"])
			else:
				O.brush(self, O.curve(base, base.lerp(tip, 0.5) + Vector2(0, -h * 0.05), tip + Vector2(0, -h * 0.06), 6), w * 0.6, bois["ombre"], 0.0, 0.8)
			tips.append(tip)
		if e == "fletri":
			# Lichen gris sur la pierre.
			for i in 3:
				var p := Vector2(r.randf_range(-0.6, 0.6) * w, -h * r.randf_range(0.1, 0.5))
				O.poly(self, Ink.lumpy(p, w * 0.32, w * 0.18, 10, 0.2, 5.0, p.y), Color(bois["reflet"], 0.45))
			return
		# Vivant : mousse au pied, lierre qui monte, couronne d'automne sur la cassure.
		moss(Vector2(-w * 0.3, -h * 0.02), w * 1.9, w * 0.55, tree_seed)
		var ivy: Dictionary = pal("mousse")
		var prev := Vector2(-w * 0.6, -h * 0.03)
		for j in 7:
			var u := (j + 1) / 7.0
			var q := Vector2(-w * 0.6 + sin(u * 7.0) * w * 0.7, -h * 0.5 * u)
			self.draw_line(prev, q, ivy["ombre"], 1.0, true)
			O.poly(self, Ink.leaf(q, PI if j % 2 == 0 else 0.0, w * 0.8, w * 0.4, 0.1), ivy["clair"] if j % 2 else ivy["ombre"])
			prev = q
		crown(top + Vector2(0, -h * 0.2), h * 0.28, h * 0.16, 12, h * 0.1, r)


## Racine géante : une dalle de roche d'où sortent deux ou trois racines énormes qui s'arquent et
## replongent dans le sol. Solide (cercle de rayon « radius »). Morte : tout est pierre ; vivante,
## le bois reprend sa couleur, la mousse s'y pose, des pousses d'or sur le dos des arches.
class GiantRoot extends Petrified:
	var radius := 24.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var e := etat()
		var rr := radius
		var st: Dictionary = pal("pierre")
		var bois: Dictionary = pal("bois")
		O.cast_shadow(self, Vector2(0, rr * 0.1), rr * 2.4, rr * 1.2, 0.32)
		# La dalle : un bloc bas et anguleux.
		var pts := PackedVector2Array()
		var n := 8
		var rot := r.randf() * 0.6
		for i in n:
			var a := rot + TAU * i / n
			var k := r.randf_range(0.85, 1.05)
			pts.append(Vector2(cos(a) * rr * 0.95 * k, sin(a) * rr * 0.5 * k - rr * 0.25))
		O.part(self, pts, st, 1.4, 1.0, 0.4)
		# Les arches : chaque racine part de la dalle, monte et redescend plus loin.
		var arches := 2 + r.randi() % 2
		var tops := []
		for i in arches:
			var side := -1.0 if i % 2 == 0 else 1.0
			var start := Vector2(side * rr * r.randf_range(0.1, 0.4), -rr * 0.45)
			var end := Vector2(side * rr * r.randf_range(1.3, 1.8), rr * r.randf_range(-0.05, 0.25))
			var peak := start.lerp(end, 0.45) + Vector2(0, -rr * r.randf_range(0.7, 1.05))
			var w := rr * r.randf_range(0.3, 0.4)
			var line := O.curve(start, peak, end, 9)
			O.brush(self, line, w + 2.0, Ink.encre(), 0.1, 0.55)
			O.brush(self, line, w, bois["ombre"], 0.1, 0.55)
			var lit := PackedVector2Array()
			for q in line:
				lit.append(q + Vector2(-0.2, -0.3) * w)
			O.brush(self, lit, w * 0.4, bois["clair"], 0.15, 0.6)
			O.poly(self, Ink.oval(end, w * 0.6, w * 0.22, 10), Color(Art.mc("commun", "", "encre_decor"), 0.5))
			tops.append(peak + Vector2(0, -w * 0.45))
		if e == "fletri":
			self.draw_line(Vector2(-rr * 0.5, -rr * 0.2), Vector2(rr * 0.2, -rr * 0.35), Color(Art.mc("racine", "fletri", "veine"), 0.7), 1.0, true)
			return
		for i in tops.size():
			var q: Vector2 = tops[i]
			moss(q + Vector2(0, 1.5), rr * 0.35, rr * 0.12, q.x)
			for j in 2:
				O.poly(self, Ink.leaf(q, -PI / 2.0 + (j - 0.5) * 0.9, rr * 0.3, rr * 0.12, 0.1), Art.mc("racine", "ravive", "feuille" if j == 0 else "feuille_2"))
		moss(Vector2(r.randf_range(-0.2, 0.2) * rr, -rr * 0.55), rr * 0.5, rr * 0.14, rr)


## Souche pétrifiée : un tronc coupé bas, ses cernes changés en pierre, ses racines au sol. Vivante :
## l'écorce brune, la mousse sur la tranche, un rejet aux feuilles d'or, deux champignons ocre.
## Hauteur ≈ 26 px × size.
class Stump extends Petrified:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var e := etat()
		var hh := 26.0 * size
		var bois: Dictionary = pal("bois")
		var w := hh * 0.4
		var h := hh * r.randf_range(0.45, 0.6)
		O.cast_shadow(self, Vector2.ZERO, w * 2.2, h, 0.3)
		for sgn in [-1.0, 1.0]:
			O.brush(self, O.curve(Vector2(sgn * w * 0.7, -h * 0.2), Vector2(sgn * w * 1.1, -h * 0.05), Vector2(sgn * w * 1.6, 1.5), 4), w * 0.45, bois["ombre"], 0.0, 1.0)
		var body := PackedVector2Array([Vector2(-w, 0), Vector2(-w * 1.15, 2.0), Vector2(w * 1.15, 2.0), Vector2(w, 0), Vector2(w * 0.95, -h), Vector2(-w * 0.95, -h)])
		O.part(self, body, bois, 1.3, 1.0, 0.3)
		grain(Vector2(0, -1.0), Vector2(0, -h), w * 0.75, 2, Color(bois["ombre"], 0.6), r)
		# La tranche : l'ellipse des cernes, plus claire.
		var top := Ink.oval(Vector2(0, -h), w * 0.95, w * 0.38, 16)
		O.part(self, top, {"clair": bois["reflet"].lerp(bois["clair"], 0.4), "ombre": bois["clair"], "reflet": bois["reflet"]}, 0.9, 1.0, 0.2)
		for i in 2:
			var ring := Ink.oval(Vector2(0.6, -h), w * (0.3 + 0.28 * i), w * (0.12 + 0.1 * i), 12)
			ring.append(ring[0])
			self.draw_polyline(ring, Color(bois["ombre"], 0.8), 0.8, true)
		self.draw_line(Vector2(0, -h), Vector2(w * 0.8, -h + w * 0.1), Color(bois["ombre"], 0.8), 0.9, true)
		if e == "fletri":
			return
		moss(Vector2(-w * 0.35, -h - 0.5), w * 0.45, w * 0.16, tree_seed)
		var tip := Vector2(w * 0.35, -h - hh * 0.45)
		self.draw_line(Vector2(w * 0.35, -h), tip, pal("mousse")["ombre"], maxf(1.0, hh * 0.04), true)
		O.poly(self, Ink.leaf(tip, -PI / 2.0 - 0.7, hh * 0.28, hh * 0.12, 0.1), Art.mc("racine", "ravive", "feuille"))
		O.poly(self, Ink.leaf(tip, -PI / 2.0 + 0.8, hh * 0.24, hh * 0.1, 0.1), Art.mc("racine", "ravive", "feuille_2"))
		var cap: Color = Art.mc("racine", "ravive", "fleur_2")
		for sgn in [-1.0, 1.0]:
			var foot := Vector2(sgn * (w + 2.5), 1.5)
			var ct := foot + Vector2(0, -hh * 0.16)
			self.draw_line(foot, ct, Art.mc("racine", "ravive", "cendre"), maxf(1.0, hh * 0.05), true)
			O.part(self, Ink.lumpy(ct, hh * 0.11, hh * 0.06, 10, 0.05, 3.0, sgn), {"clair": cap, "ombre": cap.darkened(0.3), "reflet": cap.lightened(0.4)}, 0.7, 1.0, 0.6)


## Éboulis : des éclats de pierre à plat, au sol. Vivant : de la mousse et des lichens clairs les couvrent.
class Scree extends Petrified:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var e := etat()
		var st: Dictionary = pal("pierre")
		var n := 3 + r.randi() % 3
		for i in n:
			var p := Vector2(r.randf_range(-12.0, 12.0), r.randf_range(-4.0, 4.0)) * s
			var rr := r.randf_range(2.5, 5.0) * s
			O.poly(self, Ink.oval(p + Vector2(rr * 0.3, rr * 0.35), rr * 1.05, rr * 0.45, 8), Color(0.04, 0.02, 0.03, 0.25))
			var pts := PackedVector2Array()
			var a0 := r.randf() * TAU
			for j in 5:
				var a := a0 + TAU * j / 5.0
				pts.append(p + Vector2(cos(a) * rr, sin(a) * rr * 0.6) * r.randf_range(0.8, 1.1))
			O.part(self, pts, st, 0.8, 1.0, 0.5)
			if e == "ravive" and i % 2 == 0:
				moss(p + Vector2(rr * 0.1, -rr * 0.2), rr * 0.6, rr * 0.25, p.x)


## Racines en arceaux (lisières) : deux ou trois racines sorties de terre qui s'arquent et replongent,
## en pierre (flétri) ou en bois moussu (ravivé). Sans collision. Hauteur ≈ 16 px × size
## (decor_compose.gd › height_of) : les lisières les posent en size 2,4 à 3,6.
class RootArch extends Petrified:
	func _ready() -> void:
		super()
		if sway <= 0.0:
			sway = 0.05

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var e := etat()
		var h := 16.0 * size
		var bois: Dictionary = pal("bois")
		var span := h * r.randf_range(1.8, 2.4)
		O.cast_shadow(self, Vector2.ZERO, span, h * 0.6, 0.3)
		var n := 2 + r.randi() % 2
		var arcs := []
		for i in n:
			var x0 := -span * 0.5 + r.randf_range(-0.1, 0.25) * span + i * span * 0.12
			var x1 := x0 + span * r.randf_range(0.55, 0.8)
			var y0 := r.randf_range(-3.0, 3.0) + (i - 1) * 4.0
			var peak := Vector2((x0 + x1) * 0.5 + r.randf_range(-0.1, 0.1) * span, y0 - h * r.randf_range(0.65, 1.0) * (1.0 - 0.2 * i))
			arcs.append([Vector2(x0, y0), peak, Vector2(x1, y0 + r.randf_range(-2.0, 2.0)), h * r.randf_range(0.2, 0.27) * (1.0 - 0.15 * i)])
		arcs.sort_custom(func(a, b): return a[0].y < b[0].y)
		for a in arcs:
			var line := O.curve(a[0], a[1] + (a[1] - a[0].lerp(a[2], 0.5)) * 0.9, a[2], 10)
			var w: float = a[3]
			O.poly(self, Ink.oval(a[0], w * 0.8, w * 0.28, 10), Color(Art.mc("commun", "", "encre_decor"), 0.55))
			O.poly(self, Ink.oval(a[2], w * 0.7, w * 0.25, 10), Color(Art.mc("commun", "", "encre_decor"), 0.55))
			O.brush(self, line, w + 1.6, Ink.encre(), 0.15, 0.4)
			O.brush(self, line, w, bois["clair"].lerp(bois["ombre"], 0.45), 0.15, 0.4)
			var lit := PackedVector2Array()
			for q in line:
				lit.append(q + Vector2(-0.25, -0.3) * w)
			O.brush(self, lit.slice(1, 9), w * 0.38, bois["reflet"].lerp(bois["clair"], 0.4), 0.3, 0.5)
			if e == "fletri":
				O.brush(self, line.slice(3, 7), 0.9, Color(Art.mc("racine", "fletri", "veine"), 0.7), 0.3, 0.3)
			else:
				var top: Vector2 = line[5] + Vector2(0, -w * 0.4)
				moss(top, w * 1.3, w * 0.4, top.x)
				O.poly(self, Ink.leaf(top, -PI / 2.0 - 0.5, w * 1.3, w * 0.5, 0.1), Art.mc("racine", "ravive", "feuille"))


## Arbre de pierre géant (repère de la forêt, « grand_arbre » des landmarks) : un chêne immense changé en
## pierre, aux contreforts larges, au fût fendu et aux grandes branches cassées net ; on le voit de loin.
## Ravivé : l'écorce brune, la mousse et le lierre, une couronne d'automne énorme. Ne fait pas obstacle.
## Hauteur ≈ 16 px × size (decor_compose.gd › height_of) : posé en size 14 à 15 (≈ 4 fois le héros).
class Ancient extends Flora.DecorLandmark:
	func _ready() -> void:
		super()
		sway = 0.06

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var e := "ravive" if alive and growth() > 0.5 else "fletri"
		var bois: Dictionary = Art.mc("racine", e, "bois")
		var h := 16.0 * size
		var w := h * 0.085
		O.cast_shadow(self, Vector2.ZERO, h * 0.55, h * 0.75, 0.34)
		# Contreforts : six racines larges qui s'étalent et plongent.
		for i in 6:
			var a := PI * (0.02 + 0.96 * i / 5.0)
			var tip := Vector2(cos(a) * w * r.randf_range(3.0, 4.2), sin(a) * w * 0.6 + 2.0)
			var from := Vector2(cos(a) * w * 0.6, -h * 0.06)
			O.brush(self, O.curve(from, from.lerp(tip, 0.5) + Vector2(0, -w * 0.6), tip, 6), w * 1.3 + 1.5, Ink.encre(), 0.0, 1.0)
			O.brush(self, O.curve(from, from.lerp(tip, 0.5) + Vector2(0, -w * 0.6), tip, 6), w * 1.3, bois["ombre"] if i > 2 else bois["clair"], 0.0, 1.0)
		var top := Vector2(w * 0.3, -h * 0.5)
		var fut := PackedVector2Array([
			Vector2(-w * 1.7, 2), Vector2(-w * 1.2, -h * 0.15), Vector2(-w * 0.95, -h * 0.35), top + Vector2(-w * 1.2, 0),
			top + Vector2(-w * 1.6, -h * 0.08), top + Vector2(-w * 0.4, -h * 0.03), top + Vector2(w * 0.3, -h * 0.07),
			top + Vector2(w * 1.5, -h * 0.06), top + Vector2(w * 1.0, 0), Vector2(w * 1.1, -h * 0.3), Vector2(w * 1.3, -h * 0.12), Vector2(w * 1.8, 2)])
		O.part(self, fut, bois, 2.0, 1.0, 0.45)
		# La fente du fût, qu'on reconnaît de loin, et le grain.
		O.poly(self, PackedVector2Array([Vector2(w * 0.1, -h * 0.1), Vector2(w * 0.45, -h * 0.28), Vector2(w * 0.2, -h * 0.42), Vector2(-w * 0.15, -h * 0.26)]), Art.mc("commun", "", "encre_decor"))
		for i in 5:
			var x := (i - 2) * w * 0.42
			O.brush(self, O.curve(Vector2(x, -h * 0.03), Vector2(x + w * 0.2, -h * 0.25), Vector2(x * 0.9, -h * 0.46), 6), 1.0, Color(bois["ombre"], 0.6), 0.3, 0.3)
		if e == "fletri":
			for i in 3:
				var x := (i - 1) * w * 0.8
				O.brush(self, O.curve(Vector2(x, -h * 0.08), Vector2(x - w * 0.3, -h * 0.2), Vector2(x + w * 0.1, -h * 0.36), 6), 1.3, Color(Art.mc("racine", "fletri", "veine"), 0.75), 0.4, 0.4)
		# Grandes branches qui se divisent : cassées net (flétri), ou portant la couronne (ravivé).
		var tips := []
		var broken := e == "fletri"
		for lb in [[-0.85, 0.26, 1.0], [-0.3, 0.3, 1.1], [0.25, 0.28, 1.1], [0.8, 0.25, 0.95]]:
			var dir := Vector2.from_angle(-PI * 0.5 + lb[0] + r.randf_range(-0.08, 0.08))
			var base: Vector2 = top + Vector2(lb[0] * w * 0.7, h * 0.03)
			Petrified.branch(self, base, dir, h * lb[1] * (0.85 if broken else 1.0), w * lb[2] * 0.75, 2 if not broken else 1, r, bois, tips, broken)
		if e == "fletri":
			# Quelques feuilles brunes restées accrochées, et le lichen.
			for i in 5:
				var tp: Vector2 = tips[r.randi() % tips.size()]
				O.poly(self, Ink.leaf(tp + Vector2(r.randf_range(-6, 6), r.randf_range(-2, 8)), r.randf_range(1.0, 2.2), w * 0.5, w * 0.22, 0.2), Art.mc("racine", "fletri", "feuille"))
			for i in 4:
				var p := Vector2(r.randf_range(-1.0, 1.0) * w, -h * r.randf_range(0.08, 0.45))
				O.poly(self, Ink.lumpy(p, w * 0.35, w * 0.18, 10, 0.2, 5.0, p.y), Color(bois["reflet"], 0.4))
			return
		# Ravivé : mousse sur les contreforts, lierre, couronne d'automne énorme.
		var m: Dictionary = Art.mc("racine", "ravive", "mousse")
		O.part(self, Ink.lumpy(Vector2(-w * 0.4, -h * 0.01), w * 2.4, w * 0.6, 20, 0.2, 7.0, 1.0), m, 1.0, 1.0, 0.4)
		var prev := Vector2(-w * 0.9, -h * 0.03)
		for j in 10:
			var u := (j + 1) / 10.0
			var q := Vector2(-w * 0.9 + sin(u * 8.0) * w * 0.8, -h * 0.48 * u)
			self.draw_line(prev, q, m["ombre"], 1.4, true)
			O.poly(self, Ink.leaf(q, PI if j % 2 == 0 else 0.0, w * 0.7, w * 0.35, 0.1), m["clair"] if j % 2 else m["ombre"])
			prev = q
		Petrified.paint_crown(self, top + Vector2(0, -h * 0.26), h * 0.42, h * 0.2, 26, h * 0.085, r, tips)
