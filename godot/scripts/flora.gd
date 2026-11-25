## Décor : arbres morts qui reverdissent quand la vie revient, et fleurs qui éclosent.
##
## Performance : rien n'est redessiné en bloc. Les fleurs sont rangées par carrés de
## CHUNK pixels, et une nouvelle fleur ne redessine que son carré. Chaque arbre est son
## propre nœud, redessiné seulement quand il reverdit. Godot ne dessine que ce qui est à l'écran.
## Les arbres sont triés en profondeur (Y-sort) avec les personnages : il suffit de les placer
## dans le même calque trié (« trees_parent »).
##
## Régions (voir regions.gd) : chacune a son décor (DECOR), qui remplace les arbres du monde dans son
## secteur et y ajoute le sien ; dans le roncier (decor_roncier.gd), des ronces mortes et grises qui
## verdissent et fleurissent quand la vie revient, et des buissons d'épines qui font obstacle
## (push_out, collision par cercles rangés dans une grille). Une vague de vie fait
## pousser les feuilles progressivement (GROW_TIME) et éclore les fleurs au passage du front.
extends Node2D

const Regions = preload("res://scripts/regions.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")
const Content = preload("res://scripts/content.gd")

const MAX_FLOWERS := 900
const TREE_COUNT := 260
const CHUNK := 512.0
const ALIVE := 0.45
## Durée de la pousse des feuilles d'un arbre ou d'une ronce qui reverdit pendant une vague.
const GROW_TIME := 1.1
## Taille des cases de la grille des buissons d'épines.
const BUSH_CELL := 256.0
## Décor propre à chaque sorte de région (« decor » : {"kind": …} dans data/regions/<id>.json) : voir
## decor_roncier.gd pour ce qu'une sorte doit fournir. Une sorte absente d'ici est cherchée dans
## scripts/decor_<sorte>.gd.
const DECOR := {
	"roncier": preload("res://scripts/decor_roncier.gd"),
}

var ground
## Calque trié en profondeur où ranger les arbres (par défaut : ce nœud).
var trees_parent: Node2D
var trees: Array = []    # nœuds DecorTree
var flowers: Array = []  # {pos, color, size, petals, chunk}
var chunks: Dictionary = {}  # Vector2i -> FlowerChunk
var rng := RandomNumberGenerator.new()
## Buissons d'épines (obstacles) et leur grille : Vector2i -> Array de DecorBush.
var bushes: Array = []
var bush_cells: Dictionary = {}
## Rectangle qui contient tous les buissons (avec une marge) : test rapide hors du roncier.
var bush_bounds := Rect2()
## Carrés de BUSH_CELL px qui ont un obstacle dans leur voisinage 3 × 3 : push_out sort en une seule
## recherche loin des obstacles (avec plusieurs régions, bush_bounds couvre presque tout le monde).
var bush_near: Dictionary = {}
## Fleurs d'une vague de vie qui n'ont pas encore éclos : {f, at} (at = temps d'éclosion).
var pending: Array = []
var clock := 0.0
## Arbres, ronces et buissons rangés par carrés de CHUNK pixels : Vector2i -> Array.
## Une peinture de vie ne regarde que les carrés qu'elle touche.
var tree_cells: Dictionary = {}
var bloom_timer := 0.0
## Points de repère (DecorLandmark).
var landmarks: Array = []
var _decors: Dictionary = {}
const BLOOM_STEP := 0.25
## Délai avant que le carré d'une fleur couchée cesse de la dessiner (secondes) : un carré se
## redessine au plus tous les LEAN_HOLD, même si dix fleurs se couchent à la suite.
const LEAN_HOLD := 0.1
## Fleurs couchées (dictionnaires des fleurs, avec « lean » et « tgt »), dans l'ordre où elles se
## sont couchées, et leur calque de dessin (tâche F : un monde qui réagit, data/feel.json › world).
var leaning: Array = []
var lean_max := 64
var lean_relax := 1.8
var lean_shift := 2.2
var _lean_layer: LeanLayer
## Carrés à redessiner bientôt : FlowerChunk -> secondes restantes.
var _lean_dirty: Dictionary = {}
var _tick := 0.0


## Un arbre du décor, dessiné autour de son pied (l'origine sert au tri en profondeur).
## « leaf » (0 à 1) : pousse des feuilles quand il reverdit pendant une vague de vie.
##
## Charte : le décor est sourd (Art.c("decor"), proche du sol) pour rester sous les ennemis dans
## la lecture. Formes épurées : un tronc effilé, deux ou trois branches, une couronne de trois
## masses en volume une fois vivant. Quand il reverdit, chaque masse éclot à son tour (Anim.pop)
## et quelques feuilles s'envolent.
class DecorTree extends Node2D:
	var size := 1.0
	var tree_seed := 0
	var alive := false
	var leaf := 1.0
	## Région dont l'atlas cuit dessine l'élément (world_bake/decor_bake.gd ; "" : hors des régions).
	var bake_region := ""
	## Hauteur de l'élément au-dessus de son pied (px du monde) s'il est assez grand pour cacher un
	## personnage : il passe à demi transparent quand le héros ou un Flétri est derrière lui (0 : jamais).
	var tall := 0.0
	## Souplesse au vent (0 : rigide ; 1 : un arbre) : le monde vivant (tâche V) la lit pour le
	## balancement par le shader du décor.
	var sway := 0.0
	## Opacité (premier plan) et teinte (premier plan plus sombre, décor apaisé plus clair) : appliquées
	## par self_modulate, sans redessin.
	var fade := 1.0
	var _fade_to := 1.0
	var shade := 1.0
	## Lot de triangles partagé par tout le décor (voir _draw).
	static var _b = _exact_batch()
	## Décor cuit (refonte du monde, vague 1 D : world_bake/decor_bake.gd), branché par main.gd : son
	## draw(arbre) dessine l'élément depuis l'atlas de sa région, ou rend faux (dessin direct).
	static var baker = null

	static func _exact_batch():
		var b = DrawBatch.new()
		b.exact = true
		return b

	func _ready() -> void:
		set_process(false)

	## Réveille l'arbre : il redevient vivant, d'un coup (chargement) ou en poussant (vague).
	func revive(grow: bool) -> void:
		alive = true
		leaf = 0.0 if grow else 1.0
		set_process(grow)
		queue_redraw()

	func _process(delta: float) -> void:
		leaf = minf(1.0, leaf + delta / GROW_TIME)
		queue_redraw()
		if leaf >= 1.0:
			set_process(false)

	## Avancée de la pousse (0 mort, 1 vivant) avec un départ rapide.
	func growth() -> float:
		return (1.0 - (1.0 - leaf) * (1.0 - leaf)) if alive else 0.0

	## Éclosion du i-ème de n éléments : ils sortent l'un après l'autre, en dépassant un peu.
	func bud(i: int, n: int) -> float:
		if not alive:
			return 0.0
		var start := 0.15 + 0.5 * i / maxf(1.0, n - 1.0)
		return Anim.pop(clampf((leaf - start) / 0.35, 0.0, 1.0)) if leaf < 1.0 else 1.0

	## Tout le dessin part en un seul appel de rendu (lot fidèle, mêmes pixels que les draw_*) :
	## sans lui, chaque arbre coûtait une dizaine d'appels, et le décor plus de 200 par image.
	func _draw() -> void:
		if baker != null and baker.draw(self):
			return
		_paint()
		_b.flush(self)

	## Dessin de l'arbre dans le lot _b (les sous-classes le remplacent).
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var g := growth()
		var bark := dead_color().lerp(Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.25), g)
		flat_shadow(_b, Vector2(0, 1), 11.0 * s)
		var lean := r.randf_range(-0.12, 0.12)
		var h := r.randf_range(34.0, 44.0) * s
		var top := Vector2(lean * h, -h)
		_b.draw_colored_polygon(limb(Vector2.ZERO, top, 4.2 * s, 1.4 * s), bark)
		# Branches : deux ou trois, qui partent vers le haut en se croisant peu.
		var nb := 2 + r.randi() % 2
		var tips: Array = [top]
		for i in nb:
			var side := -1.0 if i % 2 == 0 else 1.0
			var k := r.randf_range(0.45, 0.8)
			var base := top * k
			var a := -PI / 2.0 + side * r.randf_range(0.45, 0.95)
			var tip := base + Vector2.from_angle(a) * r.randf_range(12.0, 20.0) * s
			_b.draw_colored_polygon(limb(base, tip, 1.9 * s, 0.6 * s), bark)
			tips.append(tip)
		# Liseré clair du côté de la lumière (en haut à gauche) : le tronc a du volume sans détail.
		_b.draw_line(Vector2(-2.2 * s, -2.0 * s), top * 0.85 + Vector2(-0.8 * s, 0), bark.lightened(0.14), maxf(1.0, 1.1 * s))
		if g <= 0.0:
			return
		# Couronne : trois masses de feuillage en volume, chacune éclot à son tour.
		var masses := [[top + Vector2(-9, 4) * s, 13.0], [top + Vector2(10, 2) * s, 14.0], [top + Vector2(0, -6) * s, 17.0]]
		var green := Art.c("decor_vivant")
		for i in masses.size():
			var m: Array = masses[i]
			var k := bud(i, masses.size())
			if k <= 0.01:
				continue
			_b.draw_circle(m[0], (m[1] * s + 1.5) * k, Color(Art.c("contour"), 0.45))
		for i in masses.size():
			var m: Array = masses[i]
			var k := bud(i, masses.size())
			if k <= 0.01:
				continue
			Art.volume_circle(_b, m[0], m[1] * s * k, green.darkened(0.12 * (2 - i)), 0.7)
		if leaf < 1.0:
			drift_leaves(_b, top, 18.0 * s, leaf, tree_seed)

	func dead_color() -> Color:
		return Art.c("decor").lerp(Art.c("sol_mort"), 0.35)

	## Ombre au sol aplatie (lumière zénithale) pour le décor : plus légère que celle des acteurs.
	static func flat_shadow(ci, pos: Vector2, r: float) -> void:
		ci.draw_colored_polygon(Art.ellipse(pos, r, r * Art.OMBRE_APLATI, 16), Color(Art.c("ombre"), 0.22))


	## Membre effilé (tronc, branche, tige) : un quadrilatère de base « w0 » et de pointe « w1 ».
	static func limb(a: Vector2, b: Vector2, w0: float, w1: float) -> PackedVector2Array:
		var n := (b - a).orthogonal().normalized()
		return PackedVector2Array([a + n * w0, b + n * w1, b - n * w1, a - n * w0])


	## Feuille (deux arcs pointus) de longueur l, orientée selon a.
	static func leaf_shape(p: Vector2, l: float, a: float) -> PackedVector2Array:
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var pts := PackedVector2Array()
		for i in 7:
			var u := i / 6.0
			pts.append(p + d * l * u + n * l * 0.32 * sin(u * PI))
		for i in range(5, 0, -1):
			var u := i / 6.0
			pts.append(p + d * l * u - n * l * 0.32 * sin(u * PI))
		return pts


	## Pendant la pousse, quelques feuilles s'envolent du feuillage et s'effacent.
	static func drift_leaves(ci, from: Vector2, spread: float, k: float, sd: int) -> void:
		var col := Art.c("decor_vivant").lightened(0.25)
		for i in 4:
			var u := clampf(k * 1.4 - i * 0.12, 0.0, 1.0)
			if u <= 0.0 or u >= 1.0:
				continue
			var side := 1.0 if (sd + i) % 2 == 0 else -1.0
			var p := from + Vector2(side * spread * (0.4 + 0.8 * u), -spread * 0.4 + spread * 1.3 * u * u)
			ci.draw_colored_polygon(leaf_shape(p, 6.0, u * 5.0 * side + i), Color(col, 1.0 - u))


## Une ronce du roncier : trois tiges arquées et quelques épines, sombres et brunes quand la terre
## est morte (elles se fondent dans la rouille) ; vivante, elle verdit, se couvre de feuilles,
## puis de fleurs claires et de baies.
class DecorBramble extends DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size * 1.5
		var g := growth()
		var stem := dead_color().lerp(Art.c("decor_vivant").darkened(0.15), g)
		var thorn := stem.lightened(0.18)
		flat_shadow(_b, Vector2(0, 1), 15.0 * s)
		var tips: Array = []
		for i in 3:
			# Chaque tige part du pied, monte puis retombe en arc, d'un côté puis de l'autre.
			var side := (i - 1) * 0.8 + r.randf_range(-0.3, 0.3)
			var h := r.randf_range(18.0, 30.0)
			var pts := PackedVector2Array()
			for j in 7:
				var k := j / 6.0
				pts.append(Vector2(side * 22.0 * k, -h * sin(k * PI * 0.8)) * s)
			_b.draw_polyline(pts, stem, 2.6 * s)
			for j in [2, 4]:
				var p: Vector2 = pts[j]
				var d: Vector2 = (pts[j + 1] - pts[j - 1]).orthogonal().normalized()
				if d.y > 0.0:
					d = -d
				_b.draw_colored_polygon(PackedVector2Array([p + (pts[j + 1] - p).normalized() * 1.6 * s, p + d * 4.0 * s, p - (pts[j + 1] - p).normalized() * 1.6 * s]), thorn)
			tips.append([pts[5], side])
			tips.append([pts[3], -side])
		if g <= 0.0:
			return
		var green := Art.c("decor_vivant")
		for i in tips.size():
			var k := bud(i, tips.size())
			if k <= 0.01:
				continue
			var p: Vector2 = tips[i][0]
			var a := -PI / 2.0 + 0.9 * signf(tips[i][1] + 0.01)
			_b.draw_colored_polygon(leaf_shape(p, 9.0 * s * k, a), green)
			_b.draw_colored_polygon(leaf_shape(p, 7.0 * s * k, a - 1.4 * signf(tips[i][1] + 0.01)), green.lightened(0.12))
		# Fleurs et baies : les dernières à sortir.
		for i in tips.size():
			var k := bud(i + 2, tips.size() + 2)
			if k <= 0.01:
				continue
			var p: Vector2 = tips[i][0] + Vector2(0, -2.5) * s
			if i % 3 == 0:
				for q in 5:
					_b.draw_circle(p + Vector2.from_angle(TAU * q / 5.0) * 2.2 * s * k, 1.6 * s * k, Art.c("interactif").lightened(0.3))
				_b.draw_circle(p, 1.2 * s * k, Art.c("or"))
			elif i % 3 == 1:
				_b.draw_circle(p + Vector2(1.5, 2.0) * s, 2.0 * s * k, Art.ec("saignement", "clair"))
				_b.draw_circle(p + Vector2(1.0, 1.4) * s, 0.7 * s * k, Art.ec("saignement", "clair").lightened(0.4))
		if leaf < 1.0:
			drift_leaves(_b, Vector2(0, -20) * s, 14.0 * s, leaf, tree_seed)


## Buisson d'épines : obstacle solide (cercle de rayon « radius »), mort ou vivant comme le reste.
## Il doit se lire comme un obstacle sans voler la vedette aux ennemis : une masse ronde et sombre,
## nette, hérissée d'une couronne d'épines régulière.
class DecorBush extends DecorTree:
	var radius := 26.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := growth()
		var rr := radius
		var body := Art.c("decor").lerp(Art.ec("racine", "sombre"), 0.45).lerp(Art.c("decor_vivant").darkened(0.3), g)
		var thorn := Art.ec("epine", "sombre").lerp(Art.ec("epine"), 0.25 + 0.35 * g)
		var cen := Vector2(0, -rr * 0.3)
		flat_shadow(_b, Vector2(0, rr * 0.25), rr * 1.15)
		# Couronne d'épines : régulière, posée sous la masse (on voit leurs pointes dépasser).
		var n := 9 + r.randi() % 3
		var rot := r.randf() * TAU
		for i in n:
			var d := Vector2.from_angle(rot + TAU * i / n)
			var base := cen + d * rr * 0.88
			var nn := d.orthogonal()
			_b.draw_colored_polygon(PackedVector2Array([base + nn * rr * 0.13, base + d * rr * 0.45, base - nn * rr * 0.13]), thorn)
		# Masse en lobes, contour sombre puis volume.
		var lobes: Array = []
		for i in 5:
			var a := rot + TAU * i / 5.0 + r.randf_range(-0.25, 0.25)
			lobes.append([cen + Vector2.from_angle(a) * rr * 0.34, rr * r.randf_range(0.58, 0.68)])
		for l in lobes:
			_b.draw_circle(l[0], l[1] + 2.0, Color(Art.c("contour"), 0.6))
		for l in lobes:
			_b.draw_circle(l[0], l[1], body.darkened(0.25))
		Art.volume_circle(_b, cen + Vector2(-0.06, -0.08) * rr, rr * 0.7, body, 0.55)
		# Quelques épines sur le dessus, et des baies une fois vivant.
		for i in 4:
			var a := r.randf() * TAU
			var p := cen + Vector2.from_angle(a) * rr * r.randf_range(0.15, 0.5)
			var d := Vector2.from_angle(a)
			_b.draw_colored_polygon(PackedVector2Array([p + d.orthogonal() * 1.8, p + d * rr * 0.22, p - d.orthogonal() * 1.8]), thorn.lightened(0.1))
		if g > 0.0:
			for i in 5:
				var k := bud(i, 5)
				var p := cen + Vector2.from_angle(r.randf() * TAU) * rr * r.randf_range(0.15, 0.55)
				if k > 0.01:
					_b.draw_circle(p, 2.8 * k, Art.ec("saignement", "clair"))
					_b.draw_circle(p + Vector2(-0.9, -0.9), 1.0 * k, Art.ec("saignement", "clair").lightened(0.45))


## Point de repère du roncier : grand arbre mort, rocher fendu, ruine. Plus grand que le reste du
## décor et d'une silhouette unique, pour s'orienter sans la carte ; il reste sourd (pas de lueur)
## et ne fait pas obstacle. Vivant, la mousse, le lierre et les fleurs le gagnent.
class DecorLandmark extends DecorTree:
	var kind := "grand_arbre"

	func _paint() -> void:
		match kind:
			"rocher":
				_rock()
			"ruine":
				_ruin()
			_:
				_great_tree()

	func _great_tree() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var g := growth()
		var bark := Art.c("decor").lerp(Art.ec("racine", "sombre"), 0.25 + 0.5 * g)
		flat_shadow(_b, Vector2(0, 2), 46.0 * s)
		# Racines qui s'étalent au pied.
		for i in 5:
			var a := PI * (0.05 + 0.9 * i / 4.0)
			_b.draw_colored_polygon(limb(Vector2(0, -6) * s, Vector2(cos(a) * 44.0, sin(a) * 12.0 - 2.0) * s, 6.0 * s, 1.0 * s), bark.darkened(0.1))
		var top := Vector2(6, -118) * s
		_b.draw_colored_polygon(limb(Vector2.ZERO, top, 15.0 * s, 5.0 * s), bark)
		_b.draw_line(Vector2(-9, -6) * s, top + Vector2(-4, 8) * s, bark.lightened(0.14), 2.5 * s)
		# Une fente sombre dans le tronc (on le reconnaît de loin).
		_b.draw_colored_polygon(PackedVector2Array([Vector2(1, -30) * s, Vector2(5, -58) * s, Vector2(2, -72) * s, Vector2(-1, -55) * s]), Art.c("contour"))
		# Grandes branches tordues.
		var tips: Array = []
		var branches := [[0.55, -2.3, 54.0], [0.7, -0.75, 48.0], [0.85, -1.9, 40.0], [0.95, -1.05, 34.0], [0.4, -0.4, 36.0]]
		for b in branches:
			var base: Vector2 = top * b[0]
			var mid: Vector2 = base + Vector2.from_angle(b[1] + r.randf_range(-0.15, 0.15)) * b[2] * 0.55 * s
			var tip: Vector2 = mid + Vector2.from_angle(b[1] - 0.35 * signf(b[1] + PI / 2.0)) * b[2] * 0.5 * s
			_b.draw_colored_polygon(limb(base, mid, 5.0 * s, 3.0 * s), bark)
			_b.draw_colored_polygon(limb(mid, tip, 3.0 * s, 0.8 * s), bark)
			tips.append(tip)
			tips.append(mid)
		if g <= 0.0:
			return
		var green := Art.c("decor_vivant")
		for i in tips.size():
			var k := bud(i, tips.size())
			if k > 0.01:
				_b.draw_circle(tips[i], (17.0 * s + 2.0) * k, Color(Art.c("contour"), 0.45))
		for i in tips.size():
			var k := bud(i, tips.size())
			if k > 0.01:
				Art.volume_circle(_b, tips[i], 17.0 * s * k, green.darkened(0.1 * (i % 3)), 0.7)
		if leaf < 1.0:
			drift_leaves(_b, top, 50.0 * s, leaf, tree_seed)

	func _rock() -> void:
		var s := size
		var g := growth()
		var stone := Art.c("brume").darkened(0.15)
		flat_shadow(_b, Vector2(0, 2), 58.0 * s)
		# Deux moitiés d'un bloc, écartées par une fente.
		var left := PackedVector2Array([Vector2(-56, 4), Vector2(-60, -30), Vector2(-38, -64), Vector2(-8, -72), Vector2(-2, -40), Vector2(-10, -14), Vector2(-4, 6)])
		var right := PackedVector2Array([Vector2(6, 6), Vector2(2, -18), Vector2(10, -44), Vector2(6, -70), Vector2(34, -62), Vector2(58, -34), Vector2(54, 4)])
		for half in [left, right]:
			var pts := PackedVector2Array()
			for q in half:
				pts.append(q * s)
			Art.volume(_b, pts, stone, 0.5)
			_b.flush(self)
			Art.outline(self, pts, Color(Art.c("contour"), 0.7), Art.TRAIT)
		# Strates gravées.
		_b.draw_line(Vector2(-50, -30) * s, Vector2(-12, -38) * s, stone.darkened(0.3), Art.TRAIT_FIN)
		_b.draw_line(Vector2(16, -40) * s, Vector2(48, -32) * s, stone.darkened(0.3), Art.TRAIT_FIN)
		if g <= 0.0:
			return
		# Mousse sur le dessus, et une pousse qui sort de la fente.
		var moss := Art.c("decor_vivant")
		var spots := [Vector2(-30, -60), Vector2(-48, -40), Vector2(26, -62), Vector2(44, -48)]
		for i in spots.size():
			var k := bud(i, spots.size() + 2)
			if k > 0.01:
				_b.draw_colored_polygon(Art.ellipse(spots[i] * s, 13.0 * s * k, 6.0 * s * k, 12), moss)
		var k2 := bud(spots.size(), spots.size() + 2)
		if k2 > 0.01:
			_b.draw_line(Vector2(3, 2) * s, Vector2(4, -26 * k2) * s, moss.darkened(0.2), 2.5 * s)
			_b.draw_colored_polygon(leaf_shape(Vector2(4, -18 * k2) * s, 12.0 * s * k2, -2.4), moss.lightened(0.1))
			_b.draw_colored_polygon(leaf_shape(Vector2(4, -24 * k2) * s, 12.0 * s * k2, -0.7), moss.lightened(0.1))
		var k3 := bud(spots.size() + 1, spots.size() + 2)
		if k3 > 0.01:
			for q in 5:
				_b.draw_circle(Vector2(4, -30) * s + Vector2.from_angle(TAU * q / 5.0) * 3.0 * s * k3, 2.4 * s * k3, Art.c("interactif").lightened(0.3))
			_b.draw_circle(Vector2(4, -30) * s, 1.8 * s * k3, Art.c("or"))
		if leaf < 1.0:
			drift_leaves(_b, Vector2(0, -50) * s, 40.0 * s, leaf, tree_seed)

	func _ruin() -> void:
		var s := size
		var g := growth()
		var stone := Art.c("brume").lerp(Art.c("interactif"), 0.12).darkened(0.12)
		flat_shadow(_b, Vector2(0, 2), 70.0 * s)
		# Deux colonnes, l'une brisée, et un linteau tombé au pied.
		var cols := [[Vector2(-40, 0), 92.0, 0.0], [Vector2(40, 0), 54.0, 0.35]]
		for c in cols:
			var b: Vector2 = c[0] * s
			var hh: float = c[1] * s
			var w := 12.0 * s
			var pts := PackedVector2Array([b + Vector2(-w, 0), b + Vector2(-w, -hh), b + Vector2(-w * 0.2, -hh - 6.0 * s * c[2]), b + Vector2(w, -hh + 8.0 * s * c[2]), b + Vector2(w, 0)])
			Art.volume(_b, pts, stone, 0.5)
			_b.flush(self)
			Art.outline(self, pts, Color(Art.c("contour"), 0.7), Art.TRAIT)
			# Chapiteau (sur la colonne entière) et anneaux gravés.
			for k in 3:
				var y: float = -hh * (0.28 + 0.3 * k)
				_b.draw_line(b + Vector2(-w + 2, y), b + Vector2(w - 2, y), stone.darkened(0.3), Art.TRAIT_FIN)
		var cap := PackedVector2Array([Vector2(-58, -92), Vector2(-22, -92), Vector2(-24, -100), Vector2(-56, -100)])
		for i in cap.size():
			cap[i] *= s
		Art.volume(_b, cap, stone.lightened(0.05), 0.5)
		_b.flush(self)
		Art.outline(self, cap, Color(Art.c("contour"), 0.7), Art.TRAIT)
		var lintel := PackedVector2Array([Vector2(-14, 22), Vector2(46, 18), Vector2(48, 28), Vector2(-12, 32)])
		for i in lintel.size():
			lintel[i] *= s
		Art.volume(_b, lintel, stone.darkened(0.08), 0.4)
		_b.flush(self)
		Art.outline(self, lintel, Color(Art.c("contour"), 0.7), Art.TRAIT)
		if g <= 0.0:
			return
		# Lierre qui grimpe le long de la grande colonne.
		var ivy := Art.c("decor_vivant")
		for i in 7:
			var k := bud(i, 8)
			if k <= 0.01:
				continue
			var p := Vector2(-40 + (8 if i % 2 == 0 else -8), -8 - i * 12) * s
			_b.draw_colored_polygon(leaf_shape(p, 11.0 * s * k, -PI / 2.0 + (0.9 if i % 2 == 0 else -0.9)), ivy.lightened(0.06 * (i % 3)))
		var kf := bud(7, 8)
		if kf > 0.01:
			for q in 5:
				_b.draw_circle(Vector2(30, 6) * s + Vector2.from_angle(TAU * q / 5.0) * 3.0 * s * kf, 2.4 * s * kf, Art.ec("poison", "clair"))
			_b.draw_circle(Vector2(30, 6) * s, 1.8 * s * kf, Art.c("or"))
		if leaf < 1.0:
			drift_leaves(_b, Vector2(-40, -70) * s, 30.0 * s, leaf, tree_seed)

## Les fleurs d'un carré du monde, dessinées en coordonnées monde.
class FlowerChunk extends Node2D:
	var items: Array = []

	## Un seul appel de rendu pour tout le carré (lot fidèle) : un appel par pétale coûtait cher.
	func _draw() -> void:
		var b = DecorTree._b
		var heart := Art.c("or").lightened(0.3)
		for f in items:
			# Une fleur couchée est dessinée par LeanLayer, le temps qu'elle se relève.
			if f.has("hide"):
				continue
			var p: Vector2 = f["pos"]
			var sz: float = f["size"]
			var n: int = f["petals"]
			for i in n:
				b.draw_circle(p + Vector2.from_angle(TAU * i / n) * sz, sz * 0.8, f["color"])
			b.draw_circle(p, sz * 0.6, heart)
		b.flush(self)


## Les fleurs couchées sous les pas, l'esquive ou un coup (voir Flora.disturb) : dessinées ici, à
## chaque image, pendant qu'elles se relèvent ; leur carré ne les dessine plus entre-temps. Lot
## « économe » (petits disques) : au plus « flowers.max » fleurs, jamais celles de tout un carré.
class LeanLayer extends Node2D:
	var flora
	var _b := DrawBatch.new()

	func _init() -> void:
		_b.lean = true

	func _draw() -> void:
		var heart := Art.c("or").lightened(0.3)
		var stem := Art.c("decor_vivant").darkened(0.1)
		for f in flora.leaning:
			var p: Vector2 = f["pos"]
			var l: Vector2 = f["lean"]
			var sz: float = f["size"]
			var m := l.length()
			var head: Vector2 = p + l * sz * flora.lean_shift
			if m > 0.12:
				_b.draw_line(p, head, stem, 1.2)
			var k := 1.0 - 0.22 * minf(m, 1.0)
			var n: int = f["petals"]
			for i in n:
				_b.draw_circle(head + Vector2.from_angle(TAU * i / n) * sz * k, sz * 0.8 * k, f["color"])
			_b.draw_circle(head, sz * 0.6 * k, heart)
		_b.flush(self)


func _ready() -> void:
	if trees_parent == null:
		trees_parent = self
	rng.seed = 7
	for i in TREE_COUNT:
		var p := Vector2(rng.randf_range(-Regions.WORLD_HALF, Regions.WORLD_HALF), rng.randf_range(-Regions.WORLD_HALF, Regions.WORLD_HALF))
		if p.length() < 180.0:
			continue
		# Dans une région, l'arbre laisse la place à son décor (ronce du roncier…) : même tirage,
		# mêmes autres arbres.
		var reg := Regions.region_weighted(p)
		var t = decor_of(reg).make_tree(p) if reg != "" and decor_of(reg) != null else null
		if t == null:
			t = DecorTree.new()
		t.position = p
		# Même tirage qu'avant, étalé sur plus de tailles (plus de variété, même placement).
		t.size = remap(rng.randf_range(0.8, 1.6), 0.8, 1.6, 0.6, 1.9)
		t.tree_seed = rng.randi()
		t.alive = ground.life_at(p) > ALIVE
		trees_parent.add_child(t)
		_add_tree(t)
	for reg in Regions.ids():
		if decor_of(reg) != null:
			decor_of(reg).spawn()
		_spawn_landmarks(reg)
	# Décor composé (refonte du monde, vague 1 D) : clairières, lisières, grappes, repères et premier
	# plan à la place du semis ; les obstacles restent où ils sont (« --decor-ancien » : le semis d'avant).
	var compose = load("res://scripts/world_bake/decor_compose.gd")
	if compose.enabled:
		compose.apply(self)
	Game.seed_rng(rng, 1)
	ground.painted.connect(_on_painted)
	var cfg: Dictionary = Content.feel().get("world", {}).get("flowers", {})
	lean_max = int(cfg.get("max", lean_max))
	lean_relax = float(cfg.get("relax", lean_relax))
	lean_shift = float(cfg.get("shift", lean_shift))
	_lean_layer = LeanLayer.new()
	_lean_layer.flora = self
	add_child(_lean_layer)
	set_process(false)


func _add_tree(t: DecorTree) -> void:
	trees.append(t)
	var key := Vector2i(floori(t.position.x / CHUNK), floori(t.position.y / CHUNK))
	if not tree_cells.has(key):
		tree_cells[key] = []
	tree_cells[key].append(t)


## Retire un élément du décor (dessin seul : jamais un obstacle). Sert à la composition.
func remove_tree(t: DecorTree) -> void:
	trees.erase(t)
	landmarks.erase(t)
	var key := Vector2i(floori(t.position.x / CHUNK), floori(t.position.y / CHUNK))
	if tree_cells.has(key):
		tree_cells[key].erase(t)
	t.queue_free()


## Ajoute un élément du décor au calque trié en profondeur (ou au sol, flat) et à la grille.
func add_decor(t: DecorTree, flat := false) -> void:
	if flat:
		add_child(t)
	else:
		trees_parent.add_child(t)
	_add_tree(t)
	if DecorTree.baker != null:
		DecorTree.baker.prepare(t)


## Éléments du décor dont le pied est dans le disque (centre, rayon) : arbres, ronces, rochers, objets
## composés, repères et obstacles (pour les réactions du monde vivant, tâche V). Seuls les carrés de
## CHUNK px que touche le disque sont parcourus.
func decor_near(center: Vector2, radius: float) -> Array:
	var out: Array = []
	var r2 := radius * radius
	var a := Vector2i(floori((center.x - radius) / CHUNK), floori((center.y - radius) / CHUNK))
	var b := Vector2i(floori((center.x + radius) / CHUNK), floori((center.y + radius) / CHUNK))
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var list = tree_cells.get(Vector2i(cx, cy))
			if list == null:
				continue
			for t in list:
				if is_instance_valid(t) and t.position.distance_squared_to(center) <= r2:
					out.append(t)
	return out


## Décor de la région (une instance par région, null si elle n'en a pas ou s'il est inconnu).
func decor_of(reg: String):
	if not _decors.has(reg):
		var cfg := Regions.section(reg, "decor")
		var kind := str(cfg.get("kind", ""))
		var script = DECOR.get(kind)
		if script == null and kind != "" and ResourceLoader.exists("res://scripts/decor_%s.gd" % kind):
			script = load("res://scripts/decor_%s.gd" % kind)
		var d = null
		if script != null:
			d = script.new()
			d.flora = self
			d.region = reg
			d.cfg = cfg
		elif kind != "":
			push_error("Décor de région inconnu : « %s » (%s)" % [kind, reg])
		_decors[reg] = d
	return _decors[reg]


## Ajoute un obstacle du décor (buisson d'épines…) : il a un « radius », et push_out en écarte
## le joueur, les ennemis et les épines tirées.
func add_obstacle(t) -> void:
	bushes.append(t)
	var key := Vector2i(floori(t.position.x / BUSH_CELL), floori(t.position.y / BUSH_CELL))
	if not bush_cells.has(key):
		bush_cells[key] = []
	bush_cells[key].append(t)
	for y in range(key.y - 1, key.y + 2):
		for x in range(key.x - 1, key.x + 2):
			bush_near[Vector2i(x, y)] = true
	bush_bounds = Rect2(t.position, Vector2.ZERO) if bushes.size() == 1 else bush_bounds.expand(t.position)


## Points de repère d'une région (« landmarks » de son fichier) : posés à la main (distance à la
## graine, écart à l'axe de la région), loin des sanctuaires, des autels, du Cœur et de l'arène.
## Ils ne font pas obstacle.
func _spawn_landmarks(reg: String) -> void:
	for l in Regions.def(reg).get("landmarks", []):
		var p := Regions.place(reg, l)
		var t := DecorLandmark.new()
		t.kind = l["kind"]
		t.position = push_out(p, 70.0)
		t.size = float(l.get("size", 1.0))
		t.tree_seed = hash(l["kind"])
		t.alive = ground.life_at(t.position) > ALIVE
		landmarks.append(t)
		trees_parent.add_child(t)
		_add_tree(t)


## Sort un cercle (centre, rayon) des buissons d'épines qu'il touche : renvoie la position corrigée
## (la même si rien ne gêne). Sert au joueur, aux ennemis et aux épines tirées.
func push_out(pos: Vector2, radius: float) -> Vector2:
	if bush_cells.is_empty() or not bush_bounds.grow(radius + 40.0).has_point(pos):
		return pos
	var cx := floori(pos.x / BUSH_CELL)
	var cy := floori(pos.y / BUSH_CELL)
	if not bush_near.has(Vector2i(cx, cy)):
		return pos
	var out := pos
	for y in range(cy - 1, cy + 2):
		for x in range(cx - 1, cx + 2):
			var list = bush_cells.get(Vector2i(x, y))
			if list == null:
				continue
			for b in list:
				var d: Vector2 = out - b.position
				var min_d: float = radius + b.radius
				var l2 := d.length_squared()
				if l2 < min_d * min_d:
					var l := sqrt(l2)
					out = b.position + (d / l if l > 0.01 else Vector2.UP) * min_d
	return out


## La vie a changé dans un disque : seuls les arbres concernés qui reverdissent sont redessinés.
## Pendant une vague de vie (rayon fini), leurs feuilles poussent progressivement.
func _on_painted(center: Vector2, radius: float) -> void:
	if radius == INF:
		for t in trees:
			if not t.alive and ground.life_at(t.position) > ALIVE:
				t.revive(false)
		return
	var grow: bool = ground.waves.size() > 0
	var r2 := (radius + 4.0) * (radius + 4.0)
	var lo := Vector2i(floori((center.x - radius) / CHUNK), floori((center.y - radius) / CHUNK))
	var hi := Vector2i(floori((center.x + radius) / CHUNK), floori((center.y + radius) / CHUNK))
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var list = tree_cells.get(Vector2i(cx, cy))
			if list == null:
				continue
			for t in list:
				if t.alive or t.position.distance_squared_to(center) > r2:
					continue
				if ground.life_at(t.position) > ALIVE:
					t.revive(grow)


## Fleurs d'une vague de vie : elles éclosent quand le front de la vague les atteint.
## Elles sortent par petits groupes (toutes les BLOOM_STEP secondes) : chaque éclosion redessine
## tout le carré de fleurs, mieux vaut ne pas le faire à chaque image.
func _physics_process(delta: float) -> void:
	if pending.is_empty():
		return
	clock += delta
	bloom_timer -= delta
	if bloom_timer > 0.0:
		return
	bloom_timer = BLOOM_STEP
	while not pending.is_empty() and pending[0]["at"] <= clock:
		_insert(pending.pop_front()["f"])


func _chunk_for(p: Vector2) -> FlowerChunk:
	var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
	if not chunks.has(key):
		var c := FlowerChunk.new()
		chunks[key] = c
		add_child(c)
		# Les fleurs couchées restent dessinées par-dessus celles de leur carré.
		if _lean_layer != null:
			move_child(_lean_layer, get_child_count() - 1)
	return chunks[key]


func add_flower(p: Vector2, color := Color(0, 0, 0, 0)) -> void:
	_insert(_make_flower(p, color))


func _make_flower(p: Vector2, color: Color) -> Dictionary:
	if color.a == 0.0:
		var palette := [Art.c("interactif").lightened(0.3), Art.c("or"), Art.ec("poison", "clair"), Art.ec("saignement", "clair").lightened(0.2), Art.ec("seve", "clair")]
		color = palette[rng.randi() % palette.size()]
	return {"pos": p, "color": color, "size": rng.randf_range(2.5, 4.5), "petals": rng.randi_range(4, 6)}


func _insert(f: Dictionary) -> void:
	var c := _chunk_for(f["pos"])
	f["chunk"] = c
	c.items.append(f)
	c.queue_redraw()
	flowers.append(f)
	if flowers.size() > MAX_FLOWERS:
		var old: Dictionary = flowers.pop_front()
		var oc: FlowerChunk = old["chunk"]
		oc.items.erase(old)
		oc.queue_redraw()
		leaning.erase(old)


## Sème des fleurs dans un disque. Avec wave_time > 0, elles éclosent au passage d'une vague de vie
## partie du centre (même avancée que ground.paint_wave sur le disque « wave_radius »).
func spawn_patch(center: Vector2, radius: float, count: int, tint: Color, wave_time := 0.0, wave_radius := 0.0) -> void:
	for i in count:
		var p := center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius
		var c := tint if rng.randf() < 0.4 else Color(0, 0, 0, 0)
		if wave_time <= 0.0:
			add_flower(p, c)
			continue
		var f := _make_flower(p, c)
		# Le front de la vague est en R × (1 - (1 - k)²) : il atteint la distance d quand k = 1 - √(1 - d / R).
		var k := 1.0 - sqrt(maxf(0.0, 1.0 - p.distance_to(center) / maxf(1.0, wave_radius if wave_radius > 0.0 else radius)))
		pending.append({"f": f, "at": clock + wave_time * k + 0.05})
	pending.sort_custom(func(a, b): return a["at"] < b["at"])


## Fait éclore tout de suite les fleurs en attente (avant une sauvegarde).
func finish_pending() -> void:
	for e in pending:
		_insert(e["f"])
	pending = []


## Fleurs sous forme de listes simples [x, y, couleur, taille, pétales] (pour la sauvegarde).
func export_flowers() -> Array:
	finish_pending()
	var out: Array = []
	for f in flowers:
		var p: Vector2 = f["pos"]
		var c: Color = f["color"]
		out.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1), c.to_html(false), snappedf(f["size"], 0.01), f["petals"]])
	return out


func import_flowers(list: Array) -> void:
	pending = []
	flowers = []
	leaning = []
	_lean_dirty.clear()
	for c in chunks.values():
		c.items = []
		c.queue_redraw()
	var start := maxi(0, list.size() - MAX_FLOWERS)
	for i in range(start, list.size()):
		var e = list[i]
		if not (e is Array) or e.size() < 5:
			continue
		_insert({"pos": Vector2(float(e[0]), float(e[1])), "color": Color.from_string(str(e[2]), Color.WHITE), "size": float(e[3]), "petals": int(e[4])})


# --- Fleurs couchées (tâche F) ---

## Couche les fleurs du disque (centre, rayon) : elles s'inclinent à l'opposé du centre (ou, avec
## « dir », dans son sens, à demi), d'autant plus qu'elles sont près, de « force » (1 = couchée
## d'une demi-hauteur de pétale par taille), puis se relèvent en lean_relax secondes. Seuls les
## carrés de CHUNK px que touche le disque sont parcourus ; au plus lean_max fleurs couchées.
func disturb(center: Vector2, radius: float, dir := Vector2.ZERO, force := 1.0) -> void:
	var a := Vector2i(floori((center.x - radius) / CHUNK), floori((center.y - radius) / CHUNK))
	var b := Vector2i(floori((center.x + radius) / CHUNK), floori((center.y + radius) / CHUNK))
	var r2 := radius * radius
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var c = chunks.get(Vector2i(cx, cy))
			if c == null:
				continue
			for f in c.items:
				var p: Vector2 = f["pos"]
				var d2 := p.distance_squared_to(center)
				if d2 > r2:
					continue
				var fall := 1.0 - sqrt(d2) / radius
				var away := (p - center).normalized() if d2 > 0.01 else Vector2.RIGHT
				var tgt := (away + dir * 0.5).normalized() * minf(1.0, force * fall * 1.4)
				if not f.has("lean"):
					if leaning.size() >= lean_max:
						continue
					f["lean"] = Vector2.ZERO
					f["tgt"] = tgt
					leaning.append(f)
				elif tgt.length() > f["tgt"].length():
					f["tgt"] = tgt
	if not leaning.is_empty():
		set_process(true)


## Plante une fleur sans toucher au hasard du monde (celle du Porte-Graine qui se repose).
func plant(p: Vector2, color: Color, size: float, petals: int) -> void:
	_insert({"pos": p, "color": color, "size": size, "petals": petals})


func _process(delta: float) -> void:
	var k := 1.0 - exp(-delta / maxf(lean_relax, 0.05))
	var follow := clampf(delta * 14.0, 0.0, 1.0)
	# Les carrés ne changent qu'à chaque « tic » : une fleur qui se couche ou se relève attend le suivant.
	_tick -= delta
	var tic := _tick <= 0.0
	if tic:
		_tick = LEAN_HOLD
	var done: Array = []
	for f in leaning:
		f["tgt"] = f["tgt"] * (1.0 - k)
		f["lean"] = f["lean"].lerp(f["tgt"], follow)
		var rested: bool = f["tgt"].length() < 0.03 and f["lean"].length() < 0.05
		if not tic:
			continue
		if rested:
			done.append(f)
		elif not f.has("hide"):
			# Couchée : son carré cesse de la dessiner (ici, par LeanLayer).
			f["hide"] = true
			_lean_dirty[f["chunk"]] = true
	for f in done:
		leaning.erase(f)
		f.erase("lean")
		f.erase("tgt")
		# Debout : le carré la redessine, ce même instant.
		if f.has("hide"):
			f.erase("hide")
			_lean_dirty[f["chunk"]] = true
	for c in _lean_dirty.keys():
		c.queue_redraw()
	_lean_dirty.clear()
	_lean_layer.queue_redraw()
	if leaning.is_empty():
		set_process(false)
