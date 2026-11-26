## Décor de la vallée des sources (région de Sève, « decor » : {"kind": "vallee"} dans
## data/regions/seve.json) : un fond de vallée humide, des saules et des sources. Refonte du monde,
## vague 2 (P4) : dessins « Paysages d'herbier » (encre fine, deux tons, lumière d'en haut à gauche),
## couleurs de Art.MONDE › seve ; flétri = gris de brume, fils morts, sève figée ; ravivé = rideaux
## verts, eau claire, myosotis. Lisières (world_bake/decor_compose.gd › LISIERES["seve"]) : fougères,
## massettes, lianes sur leurs arceaux de racine, saules ; repère : le grand saule (Willow géant).
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
const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
## Au-delà de cette taille, un saule est le grand saule (repère visible de loin).
const GREAT := 3.8

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



## Outils de dessin partagés par les éléments de la vallée.
class V extends RefCounted:
	## Couleur (ou palette) de la vallée dans l'état d'un élément : ravivé s'il est vivant et assez poussé.
	static func pal(t, key: String):
		return Art.mc("seve", "ravive" if t.alive and t.growth() > 0.5 else "fletri", key)


	static func alive(t) -> bool:
		return t.alive and t.growth() > 0.5


	## Mèche qui pend (rideau du saule, liane) : de a vers le bas, longueur l, ondulée ; vivante, des
	## feuilles étroites de part et d'autre ; morte, un fil nu, parfois cassé.
	static func strand(ci: CanvasItem, a: Vector2, l: float, sway: float, w: float, col: Color, leaf_col: Color, live: bool, sd: int) -> void:
		var pts := PackedVector2Array()
		var n := 7
		for i in n:
			var u := float(i) / (n - 1)
			pts.append(a + Vector2(sway * u * u * l + sin(u * 4.0 + sd) * w * 0.6, l * u))
		if not live:
			if sd % 3 == 0:
				pts = pts.slice(0, 4)
			O.brush(ci, pts, maxf(0.8, w * 0.4), col, 0.0, 1.0)
			return
		O.brush(ci, pts, maxf(0.9, w * 0.45), col, 0.0, 0.6)
		for i in range(1, n):
			var q: Vector2 = pts[i]
			var side := 1.0 if (i + sd) % 2 == 0 else -1.0
			O.poly(ci, Ink.leaf(q, PI * 0.5 + side * 0.55, w * 2.0, w * 0.75, 0.05 * side), leaf_col if i % 3 != 1 else col)


## Saule pleureur : un tronc court et noueux, des maîtresses branches qui montent puis retombent, une
## couronne d'où pendent des rideaux. Mort : des fils gris et nus qui pendent, la sève figée en
## coulées ambrées sur l'écorce ; vivant : des rideaux de feuilles vert d'eau, quelques myosotis.
## Au-delà de GREAT, c'est le grand saule (repère) : plus large, un étang à son pied, des racines.
class Willow extends Flora.DecorTree:
	func dead_color() -> Color:
		return Art.mc("seve", "fletri", "saule")["clair"]

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var live := V.alive(self)
		var great := size >= GREAT
		var h := 52.0 * size
		var w := h * (0.075 if great else 0.065)
		var bois: Dictionary = V.pal(self, "bois")
		var saule: Dictionary = V.pal(self, "saule")
		var lean := r.randf_range(-0.08, 0.08)
		O.cast_shadow(self, Vector2.ZERO, h * (0.9 if great else 0.7), h * 0.7, 0.28 if live else 0.34)
		if great:
			_pool(r, h, live)
		var top := Vector2(lean * h, -h * 0.42)
		# Racines au pied.
		for i in (7 if great else 3):
			var a := PI * (0.08 + 0.84 * (i + 0.5) / (7.0 if great else 3.0))
			var e := Vector2(cos(a) * w * (5.0 if great else 2.6), sin(a) * w * 0.6 + 2.0)
			O.brush(self, O.curve(Vector2(cos(a) * w * 0.6, -w * 0.4), Vector2(cos(a) * w * 2.0, -w * 0.6), e, 5), w * 0.55, bois["ombre"], 0.0, 1.0)
		# Tronc noueux, un peu tordu.
		var trunk := PackedVector2Array([
			Vector2(-w * 1.7, 2), Vector2(-w * 0.95, -h * 0.06), Vector2(-w * 0.85, -h * 0.2), top + Vector2(-w * 0.75, h * 0.06),
			top + Vector2(-w * 0.9, -h * 0.02), top + Vector2(-w * 0.2, -h * 0.05), top + Vector2(w * 0.5, -h * 0.03),
			top + Vector2(w * 0.7, h * 0.07), Vector2(w * 0.9, -h * 0.2), Vector2(w * 0.85, -h * 0.07), Vector2(w * 1.9, 2),
			Vector2(w * 0.4, -h * 0.01), Vector2(-w * 0.5, -h * 0.015)])
		O.part(self, trunk, bois, 1.6, 1.0, 0.4)
		for i in 3:
			var y := -h * (0.08 + 0.1 * i)
			draw_arc(Vector2(r.randf_range(-0.4, 0.4) * w, y), w * 0.32, PI * 1.1, PI * 1.9, 6, Color(bois["ombre"], 0.8), 1.0, true)
		if not live:
			# Sève figée qui a coulé d'une blessure de l'écorce.
			var sv: Dictionary = Art.mc("seve", "fletri", "seve")
			var wound := Vector2(w * 0.15, -h * 0.28)
			O.poly(self, Ink.oval(wound, w * 0.22, w * 0.36, 10), Ink.encre())
			O.brush(self, PackedVector2Array([wound, wound + Vector2(w * 0.08, h * 0.06), wound + Vector2(-w * 0.04, h * 0.12)]), w * 0.28, sv["ombre"], 0.0, 0.5)
			draw_circle(wound + Vector2(-w * 0.04, h * 0.125), w * 0.16, sv["clair"].darkened(0.2))
		# Maîtresses branches : elles montent en éventail puis s'arquent vers l'extérieur.
		var crowns: Array = []
		var nb := (6 if great else 4)
		for i in nb:
			var u := (i - (nb - 1) * 0.5) / maxf(1.0, (nb - 1) * 0.5)
			var tip := top + Vector2(u * h * 0.36, -h * (0.42 + 0.12 * (1.0 - absf(u))) + r.randf_range(-0.04, 0.04) * h)
			var mid := top.lerp(tip, 0.5) + Vector2(u * h * 0.02, -h * 0.1)
			var br := O.curve(top + Vector2(u * w * 0.5, 0), mid, tip, 7)
			O.brush(self, br, w * 0.75, Ink.encre(), 0.0, 0.8)
			O.brush(self, br, w * 0.55, bois["clair"], 0.0, 0.8)
			crowns.append(tip)
		var curtain_len := h * (0.5 if great else 0.48)
		if not live:
			# Fils gris qui pendent des branches, nus ; quelques-uns cassés.
			for i in crowns.size():
				var c: Vector2 = crowns[i]
				var arc := O.curve(c, c + Vector2(signf(c.x - top.x) * h * 0.1, -h * 0.02), c + Vector2(signf(c.x - top.x) * h * 0.16, h * 0.08), 5)
				O.brush(self, arc, w * 0.3, bois["ombre"], 0.0, 1.0)
				for j in (7 if great else 5):
					var a: Vector2 = arc[mini(j % arc.size(), arc.size() - 1)] + Vector2(r.randf_range(-3, 3), 0)
					V.strand(self, a, curtain_len * r.randf_range(0.5, 0.95), r.randf_range(-0.08, 0.08), w * 0.45, saule["ombre"] if j % 2 else saule["clair"], saule["clair"], false, j + i * 7)
			return
		# Vivant : rideaux arrière (sombres), couronne en volume, rideaux avant (clairs), myosotis.
		var crown := top + Vector2(0, -h * 0.47)
		var cw := h * (0.46 if great else 0.4)
		for i in (22 if great else 14):
			var u := r.randf_range(-1.0, 1.0)
			var a := crown + Vector2(u * cw, h * 0.06 - absf(u) * h * 0.02)
			V.strand(self, a, curtain_len * r.randf_range(0.75, 1.05), u * 0.1, w * 0.55, saule["ombre"], saule["ombre"].darkened(0.08), true, i)
		var masses := []
		for i in (9 if great else 6):
			var u := (i - ((9 if great else 6) - 1) * 0.5) / (((9 if great else 6) - 1) * 0.5)
			masses.append([crown + Vector2(u * cw * 0.85, -h * 0.05 * (1.0 - u * u) + r.randf_range(-3, 3)), h * r.randf_range(0.1, 0.13)])
		masses.append([crown + Vector2(-cw * 0.15, -h * 0.08), h * 0.15])
		masses.sort_custom(func(x, y): return x[0].y < y[0].y)
		for ms in masses:
			O.part(self, Ink.lumpy(ms[0], ms[1] * 1.3, ms[1] * 0.8, 24, 0.12, 10.0, ms[0].x), saule, 1.2, 1.0, 0.7)
		for i in (18 if great else 11):
			var u := r.randf_range(-1.0, 1.0)
			var a := crown + Vector2(u * cw * 0.95, h * 0.04)
			V.strand(self, a, curtain_len * r.randf_range(0.6, 0.95), u * 0.12, w * 0.5, saule["clair"], saule["reflet"], true, i + 31)
		for i in (7 if great else 3):
			var q: Vector2 = crown + Vector2(r.randf_range(-0.8, 0.6) * cw, r.randf_range(-0.12, 0.05) * h)
			O.flower(self, q, r.randf_range(2.0, 2.8) * (1.3 if great else 1.0), Art.mc("seve", "ravive", "fleur"), Art.mc("seve", "ravive", "fleur_coeur"), r.randf() * TAU)

	## Étang au pied du grand saule : eau croupie et sève figée (mort), eau claire (vivant).
	func _pool(r: RandomNumberGenerator, h: float, live: bool) -> void:
		var etat := "ravive" if live else "fletri"
		var c := Vector2(h * 0.05, h * 0.03)
		O.poly(self, O.blob(c + Vector2(2, 2), h * 0.5, h * 0.13, 3.0, 0.1, 30), Color(Ink.encre(), 0.45))
		O.poly(self, O.blob(c, h * 0.48, h * 0.12, 3.0, 0.1, 30), Art.mc("seve", etat, "eau"))
		draw_line(c + Vector2(-h * 0.3, -h * 0.04), c + Vector2(-h * 0.12, -h * 0.05), Color(Art.mc("seve", etat, "eau_reflet"), 0.7), 1.5, true)
		if not live:
			var sv: Dictionary = Art.mc("seve", "fletri", "seve")
			O.poly(self, O.blob(c + Vector2(h * 0.2, h * 0.02), h * 0.12, h * 0.035, 7.0, 0.2, 16), Color(sv["ombre"], 0.9))
		else:
			for i in 3:
				var q := c + Vector2(r.randf_range(-0.35, 0.35) * h, r.randf_range(-0.05, 0.06) * h)
				O.poly(self, Ink.oval(q, h * 0.035, h * 0.015, 10), Art.mc("seve", "ravive", "feuillage")["clair"])
				O.flower(self, q + Vector2(0, -2), h * 0.012, Art.mc("seve", "ravive", "fleur_2"), Art.mc("seve", "ravive", "fleur_coeur"))


## Source : une flaque plate (bord de vase, eau), au sol. Morte, une eau croupie sous une peau de sève
## figée et des feuilles mortes ; vivante, une eau claire, des rides qui partent du milieu, du cresson
## et une fleur d'eau.
class Spring extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var live := V.alive(self)
		var etat := "ravive" if live else "fletri"
		var rr := 30.0 * size
		O.poly(self, _blob(Vector2(1.5, 2.5), rr * 1.1, tree_seed % 89), Color(Ink.encre(), 0.4))
		O.poly(self, _blob(Vector2(0, 1), rr * 1.08, tree_seed % 89), Art.mc("seve", etat, "sol_sombre") if etat == "fletri" else Art.mc("seve", "fletri", "pierre")["ombre"].lerp(Art.mc("seve", "ravive", "eau"), 0.4))
		O.poly(self, _blob(Vector2.ZERO, rr, tree_seed % 89), Art.mc("seve", etat, "eau"))
		var sheen: Color = Art.mc("seve", etat, "eau_reflet")
		O.poly(self, Ink.oval(Vector2(-rr * 0.3, -rr * 0.16), rr * 0.32, rr * 0.06, 12), Color(sheen, 0.3 if live else 0.18))
		if not live:
			var sv: Dictionary = Art.mc("seve", "fletri", "seve")
			O.poly(self, O.blob(Vector2(rr * 0.25, rr * 0.05), rr * 0.32, rr * 0.11, float(tree_seed % 31), 0.25, 14), Color(sv["ombre"], 0.85))
			for i in 3:
				var p := Vector2(r.randf_range(-0.55, 0.55) * rr, r.randf_range(-0.2, 0.2) * rr)
				O.poly(self, Ink.leaf(p, r.randf() * TAU, 5.0 * size, 2.2 * size), Art.mc("seve", "fletri", "feuille"))
			return
		for i in 2:
			var rad := rr * (0.22 + 0.22 * i)
			draw_arc(Vector2(r.randf_range(-0.1, 0.1) * rr, 0), rad, 0.0, TAU, 24, Color(sheen, 0.35 - 0.12 * i), 1.0, true)
		var cress: Dictionary = Art.mc("seve", "ravive", "feuillage")
		for i in 3:
			var a := r.randf() * TAU
			var p := Vector2(cos(a) * rr * 0.9, sin(a) * rr * 0.45)
			for q in 4:
				O.poly(self, Ink.oval(p + Vector2.from_angle(TAU * q / 4.0 + i) * 2.4 * size, 2.2 * size, 1.6 * size, 8), cress["clair"] if q % 2 else cress["ombre"])
		var lily := Vector2(r.randf_range(-0.3, 0.3) * rr, r.randf_range(-0.1, 0.12) * rr)
		O.poly(self, Ink.oval(lily, rr * 0.16, rr * 0.07, 12), cress["clair"])
		O.flower(self, lily + Vector2(0, -2), rr * 0.07, Art.mc("seve", "ravive", "fleur_2"), Art.mc("seve", "ravive", "fleur_coeur"))

	static func _blob(pos: Vector2, r: float, sd: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			var w := 1.0 + 0.12 * sin(a * 3.0 + sd) + 0.05 * sin(a * 5.0 + sd * 1.7)
			pts.append(pos + Vector2(cos(a), sin(a) * 0.5) * r * w)
		return pts


## Bloc moussu : un rocher rond et usé par l'eau, solide (cercle de rayon « radius » : obstacle
## inchangé, seul le dessin change). La mousse, grise et sèche sur la terre morte, reverdit et
## s'étend une fois la terre ravivée ; une fougère pousse à son pied.
class MossRock extends Flora.DecorTree:
	var radius := 22.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var live := V.alive(self)
		var rr := radius
		var stone: Dictionary = V.pal(self, "pierre")
		O.cast_shadow(self, Vector2(0, rr * 0.1), rr * 2.0, rr * 1.2, 0.3)
		var pts := Ink.lumpy(Vector2(0, -rr * 0.42), rr * 1.05, rr * 0.72, 22, 0.08, 5.0, float(tree_seed % 17))
		O.part(self, pts, stone, 1.6, 1.0, 0.5)
		draw_arc(Vector2(-rr * 0.25, -rr * 0.6), rr * 0.45, PI * 1.1, PI * 1.6, 8, Color(stone["reflet"], 0.8), 1.2, true)
		var moss: Dictionary = Art.mc("seve", "ravive", "fougere") if live else Art.mc("seve", "fletri", "fougere")
		var cap := Ink.lumpy(Vector2(r.randf_range(-0.15, 0.15) * rr, -rr * 0.9), rr * (0.55 if live else 0.42), rr * 0.2, 18, 0.25, 7.0, float(tree_seed % 7))
		O.part(self, cap, moss, 1.0, 1.0, 0.6)
		if not live:
			return
		for i in 4:
			var q := Vector2(r.randf_range(-0.6, 0.6) * rr, -rr * r.randf_range(0.2, 0.7))
			O.poly(self, Ink.oval(q, rr * 0.12, rr * 0.06, 8), moss["clair"])
		for i in 3:
			var a := PI * (1.15 + 0.35 * i)
			O.part(self, Ink.leaf(Vector2(rr * 0.75, rr * 0.05), a, rr * 0.6, rr * 0.18, 0.1), Art.mc("seve", "ravive", "fougere"), 0.8, 1.0, 0.5)


## Fougère : quatre à six frondes en éventail. Mortes, des crosses brunes recroquevillées au ras du
## sol ; vivantes, des frondes vertes déployées, découpées en folioles, l'une encore en crosse.
class Fern extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var live := V.alive(self)
		var f: Dictionary = V.pal(self, "fougere")
		O.cast_shadow(self, Vector2.ZERO, 16.0 * s, 12.0 * s, 0.22)
		var n := 4 + r.randi() % 3
		for i in n:
			var u := (i - (n - 1) * 0.5) / ((n - 1) * 0.5)
			var a := -PI / 2.0 + u * 0.95 + r.randf_range(-0.1, 0.1)
			var len := r.randf_range(15.0, 20.0) * s * (1.0 - 0.25 * absf(u))
			if not live or (i == n / 2 and n > 4):
				# Crosse : la fronde reste enroulée sur elle-même.
				var c := Vector2.from_angle(a) * len * (0.45 if not live else 0.7)
				var stem := O.curve(Vector2.ZERO, c * 0.5 + Vector2(u * 2.0, -2.0), c, 5)
				O.brush(self, stem, maxf(1.0, 1.5 * s), f["ombre"], 0.0, 0.3)
				O.part(self, Ink.oval(c + Vector2(1.2 * s * signf(u + 0.01), 0), 2.6 * s, 2.3 * s, 10), f, 0.8, 1.0, 0.3)
				draw_arc(c + Vector2(1.2 * s * signf(u + 0.01), 0), 1.2 * s, 0.0, PI * 1.5, 6, Ink.encre(), 0.8, true)
				continue
			# Fronde : une nervure qui s'arque et retombe, des folioles de part et d'autre.
			var d := Vector2.from_angle(a)
			var tip := d * len + Vector2(0, len * 0.3 * absf(u))
			var mid := d * len * 0.55 + Vector2(0, -len * 0.08)
			var rib := O.curve(Vector2.ZERO, mid, tip, 8)
			O.brush(self, rib, maxf(1.0, 1.3 * s), f["ombre"], 0.0, 0.8)
			for j in range(1, rib.size() - 1):
				var q: Vector2 = rib[j]
				var dd: Vector2 = (rib[j + 1] - rib[j - 1]).normalized()
				var lw := (1.0 - float(j) / rib.size()) * 5.5 * s + 1.2
				for sgn in [-1.0, 1.0]:
					O.poly(self, Ink.leaf(q, (dd.orthogonal() * sgn + dd * 0.6).angle(), lw, lw * 0.45), f["clair"] if (j + int(sgn)) % 2 == 0 else f["ombre"])
			O.brush(self, rib.slice(0, 5), maxf(0.6, 0.6 * s), Color(f["reflet"], 0.7), 0.0, 1.0)


## Massettes : une touffe de feuilles en lames et deux ou trois tiges à épi de velours. Mortes,
## grises et cassées, les épis effilochés ; vivantes, vertes et droites, l'épi brun luisant.
class Cattail extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var live := V.alive(self)
		var f: Dictionary = V.pal(self, "feuillage")
		var h := 22.0 * s
		O.cast_shadow(self, Vector2.ZERO, h * 0.6, h, 0.22)
		var n := 6 + r.randi() % 3
		for i in n:
			var u := (i - (n - 1) * 0.5) / ((n - 1) * 0.5)
			var hh := h * r.randf_range(0.55, 0.85) * (1.0 - 0.3 * absf(u))
			var lean := u * 0.45 + r.randf_range(-0.1, 0.1)
			var b := Vector2(u * h * 0.15, 0)
			var tip := b + Vector2(lean * hh, -hh)
			if not live and i % 3 == 0:
				# Lame cassée qui retombe.
				var k := b.lerp(tip, 0.55)
				O.brush(self, PackedVector2Array([b, k]), maxf(1.0, 1.8 * s), f["ombre"], 0.0, 0.4)
				O.brush(self, PackedVector2Array([k, k + Vector2(lean * hh * 0.6 + 4.0 * signf(u + 0.01), hh * 0.2)]), maxf(0.8, 1.4 * s), f["clair"], 0.0, 1.0)
				continue
			O.brush(self, O.curve(b, b.lerp(tip, 0.5) + Vector2(lean * hh * 0.1, 0), tip, 5), maxf(1.0, 2.0 * s), f["ombre"] if i % 2 else f["clair"], 0.0, 1.0)
		var spike_col: Color = Art.mc("seve", "ravive", "bois")["ombre"] if live else Art.mc("seve", "fletri", "bois")["clair"]
		for j in 2 + r.randi() % 2:
			var b := Vector2((j - 1) * h * 0.12, 0)
			var top := b + Vector2(r.randf_range(-0.1, 0.1) * h, -h * r.randf_range(1.0, 1.25))
			O.brush(self, PackedVector2Array([b, top]), maxf(0.8, 1.0 * s), f["ombre"], 0.0, 0.0)
			var sp := top + Vector2(0, h * 0.12)
			if live:
				O.part(self, Ink.oval(sp, 1.9 * s, 4.4 * s, 12), {"clair": spike_col.lightened(0.15), "ombre": spike_col, "reflet": spike_col.lightened(0.4)}, 0.8, 1.0, 0.8)
			else:
				O.poly(self, Ink.lumpy(sp, 2.2 * s, 4.0 * s, 14, 0.35, 9.0, float(j)), spike_col)
				for q in 3:
					draw_line(sp + Vector2(1.5 * s, -2.0 * s + q * 2.0 * s), sp + Vector2(4.0 * s, -3.0 * s + q * 2.6 * s), Color(spike_col, 0.7), 0.8, true)


## Liane : une racine sortie de terre en arceau, d'où pendent des lianes. Morte, une racine grise et
## des fils secs ; vivante, des lianes feuillues aux feuilles en cœur, quelques myosotis.
class Liana extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var live := V.alive(self)
		var bois: Dictionary = V.pal(self, "bois")
		var li: Dictionary = V.pal(self, "liane")
		var span := 30.0 * s
		var hgt := 22.0 * s
		O.cast_shadow(self, Vector2.ZERO, span * 1.1, hgt * 0.5, 0.24)
		var a := Vector2(-span * 0.5, 0)
		var b := Vector2(span * 0.5, 1)
		var arch := O.curve(a, Vector2(r.randf_range(-0.15, 0.15) * span, -hgt * 1.9), b, 12)
		O.brush(self, arch, 4.6 * s, Ink.encre(), 0.0, 0.0)
		O.brush(self, arch, 3.4 * s, bois["ombre"], 0.0, 0.0)
		O.brush(self, arch.slice(1, 8), 1.3 * s, bois["clair"], 0.0, 0.0)
		for i in range(2, 11, 2):
			var p: Vector2 = arch[i]
			V.strand(self, p, hgt * r.randf_range(0.45, 0.85) * (1.0 - absf(i - 6.0) / 9.0), r.randf_range(-0.1, 0.1), 2.2 * s, li["ombre"] if i % 4 else li["clair"], li["clair"], live, i)
		if live:
			for i in 3:
				var p: Vector2 = arch[3 + i * 3] + Vector2(0, -1.5 * s)
				O.part(self, Ink.leaf(p, -PI * 0.5 + (i - 1) * 0.8, 6.0 * s, 4.6 * s, 0.05), li, 0.8, 1.0, 0.6)
			O.flower(self, arch[6] + Vector2(2.0 * s, -2.0 * s), 2.2 * s, Art.mc("seve", "ravive", "fleur"), Art.mc("seve", "ravive", "fleur_coeur"))
