## Décor des falaises de verre (région d'Aube, « decor » : {"kind": "falaise"} dans
## data/regions/aube.json) : un pays de calcaire pâle et de verre, sous une lumière crue.
##   - les arbres du monde y deviennent des arbres blanchis, couverts de bourgeons de cristal, qui
##     se couvrent de feuillage doré une fois ravivés ;
##   - des grappes de cristaux (prismes de verre fumé) et des blocs de falaise striés de veines de
##     verre font obstacle ;
##   - des éclats de verre jonchent le sol (ils ne gênent pas) : ternes sur la terre morte, ils
##     brillent et des fleurs d'aube poussent entre eux une fois ravivés.
##
## Même contrat que decor_roncier.gd (make_tree, spawn).
##
## Refonte du monde, vague 2 P5 (« Paysages d'herbier ») : tout est redessiné à l'encre fine de
## world_art (lumière d'en haut à gauche, deux tons, ombre portée vers le bas à droite), aux couleurs de
## Art.MONDE["aube"] (flétri : calcaire froid, verre fumé ; ravivé : bois blanchi, feuillage de miel,
## verre clair et nacre), et cuit par world_bake/decor_bake.gd. Sortes ajoutées pour le décor composé
## (world_bake/decor_compose.gd › LISIERES["aube"]), sans collision : Cluster (bouquet d'éclats de
## cristal des lisières), Spire (aiguille de cristal géante, repère) et Arch (arche de roche et de
## cristal, repère). Hauteur dessinée : 52 × size pour Bleached, 16 × size pour les autres sortes
## composées (decor_compose.gd › height_of), pour que le fondu du premier plan tombe juste.
## Dessin seul : les obstacles (Crystals, Cliff) gardent leur place et leur rayon.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const Flora = preload("res://scripts/flora.gd")
const A = preload("res://scripts/region_art/aube.gd")
const O = preload("res://scripts/world_art/outils.gd")
const Decor = preload("res://scripts/world_art/decor.gd")
const F = preload("res://scripts/world_art/falaise_outils.gd")

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
		if solid and (Regions.near_heart(region, p, clear_center) or p.length() < clear_seed or p.distance_to(arena) < arena_r + 60.0):
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
		else:
			# Les éclats sont plats, posés au sol : sous les personnages, gardés par le décor composé.
			flora.add_child(t)
		flora._add_tree(t)



# --- Éléments ---


## Arbre blanchi des falaises : un tronc droit au bois blanchi, des branches qui se divisent au
## bout desquelles poussent des bourgeons de cristal fumé. Ravivé : un houppier de feuillage de miel,
## piqué de fleurs d'aube de nacre et de bourgeons de cristal clair. Hauteur : 52 × size.
class Bleached extends Flora.DecorTree:
	func dead_color() -> Color:
		return Art.mc("aube", "fletri", "bois")["clair"]

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var etat: String = F.etat_of(self)
		var h := 52.0 * size
		var bois: Dictionary = F.pal(etat, "bois")
		O.cast_shadow(self, Vector2.ZERO, h * 0.42, h * 0.6, 0.28 if etat == "ravive" else 0.34)
		var w := h * 0.05
		var lean := r.randf_range(-0.07, 0.07)
		var top := Vector2(lean * h, -h * 0.52)
		var trunk := PackedVector2Array([
			Vector2(-w * 2.2, 2), Vector2(-w * 0.95, -h * 0.07), top + Vector2(-w * 0.55, 0),
			top + Vector2(w * 0.5, 0), Vector2(w * 1.05, -h * 0.08), Vector2(w * 2.4, 2),
			Vector2(w * 0.6, -h * 0.02), Vector2(-w * 0.5, -h * 0.025)])
		O.part(self, trunk, bois, 1.5, 1.0, 0.5)
		# Écorce blanchie fendue : de longues fentes fines.
		for i in 3:
			var x := (i - 1) * w * 0.45
			draw_line(Vector2(x, -h * (0.06 + 0.05 * i)), Vector2(x + lean * h * 0.3, -h * (0.3 + 0.06 * i)), Color(bois["ombre"].darkened(0.2), 0.7), 0.9, true)
		var tips := []
		Decor._branch(self, top, Vector2(0.12 * signf(lean + 0.01), -1).normalized(), h * 0.24, w * 1.05, 2, r, bois, tips)
		Decor._branch(self, top.lerp(Vector2.ZERO, 0.15), Vector2(-0.9, -0.75).normalized(), h * 0.2, w * 0.75, 1, r, bois, tips)
		Decor._branch(self, top.lerp(Vector2.ZERO, 0.05), Vector2(0.9, -0.65).normalized(), h * 0.2, w * 0.75, 1, r, bois, tips)
		var glass: Dictionary = F.pal(etat, "verre")
		if etat == "ravive":
			var leaf: Dictionary = F.pal("ravive", "feuillage")
			var crown := top + Vector2(0, -h * 0.17)
			var masses := []
			for i in 7:
				var a := -PI * 0.5 + (i - 3) * 0.5
				var c := crown + Vector2(cos(a) * h * 0.22, sin(a) * h * 0.1 + h * 0.05) + Vector2(r.randf_range(-6, 6), r.randf_range(-5, 5)) * size * 0.3
				masses.append([c, h * r.randf_range(0.1, 0.14)])
			masses.append([crown + Vector2(-h * 0.03, -h * 0.02), h * 0.16])
			masses.sort_custom(func(x, y): return x[0].y < y[0].y)
			for ms in masses:
				O.part(self, O.Ink.lumpy(ms[0], ms[1], ms[1] * 0.82, 24, 0.1, 9.0, ms[0].x), leaf, 1.2, 1.0, 0.7)
			for i in 10:
				var ms: Array = masses[r.randi() % masses.size()]
				var p: Vector2 = ms[0] + Vector2(r.randf_range(-0.7, 0.5), r.randf_range(-0.7, 0.3)) * ms[1]
				if i % 3 == 0:
					F.prism(self, p + Vector2(0, 2.0), maxf(1.4, h * 0.012), h * 0.05, 0.0, glass)
				else:
					F.star(self, p, maxf(1.8, h * 0.017), F.col("ravive", "fleur"), F.col("ravive", "fleur_coeur"))
		else:
			# Bourgeons de cristal fumé au bout des branches, quelques feuilles sèches.
			for i in tips.size():
				var tp: Vector2 = tips[i]
				if i % 2 == 0:
					F.prism(self, tp + Vector2(0, 1.0), maxf(1.4, h * 0.014), h * r.randf_range(0.05, 0.08), r.randf_range(-1.0, 1.0), glass)
				elif i % 3 == 1:
					O.part(self, O.Ink.leaf(tp, r.randf_range(1.2, 2.2), h * 0.05, h * 0.022, 0.15), F.pal("fletri", "feuillage"), 0.7, 1.0, 0.0)


## Grappe de cristaux : trois à cinq prismes plantés ensemble, solide (cercle de rayon « radius »).
## Morte : verre fumé ; ravivée : verre clair et nacre, lueur d'or et fleurs d'aube à son pied.
class Crystals extends Flora.DecorTree:
	var radius := 20.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		F.crystal_group(self, Vector2.ZERO, radius * 1.7, radius * 2.3, 3 + r.randi() % 3, r, F.etat_of(self))


## Bloc de falaise : une dalle de calcaire aux strates horizontales, fendue d'une veine de verre ;
## solide (cercle de rayon « radius »). Vivant : herbe dorée et fleurs d'aube sur l'arête.
class Cliff extends Flora.DecorTree:
	var radius := 32.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var etat: String = F.etat_of(self)
		var rr := radius
		O.cast_shadow(self, Vector2(0, rr * 0.1), rr * 2.3, rr * 1.0, 0.3)
		F.block(self, Vector2(0, rr * 0.12), rr * 1.2, rr * 1.15, r, etat)
		# Veine de verre qui fend la dalle.
		var g: Dictionary = F.pal(etat, "verre")
		var vein := PackedVector2Array([Vector2(rr * 0.1, -rr * 0.95), Vector2(rr * 0.26, -rr * 0.6), Vector2(rr * 0.06, -rr * 0.3), Vector2(rr * 0.2, rr * 0.05)])
		O.brush(self, vein, 4.4, O.Ink.encre(), 1.0, 1.0)
		O.brush(self, vein, 3.0, g["clair"], 1.0, 1.0)
		O.brush(self, vein, 1.0, g["reflet"], 0.5, 0.5)
		if etat == "ravive":
			var grass: Color = F.col("ravive", "touffe")
			for i in 5:
				var foot := Vector2((i - 2) * rr * 0.42 + r.randf_range(-3, 3), -rr * 0.95)
				O.tuft(self, foot, rr * 0.32, grass, F.col("ravive", "touffe_2"), tree_seed + i)
				if i % 2 == 1:
					F.star(self, foot + Vector2(0, -rr * 0.28), maxf(2.0, rr * 0.08), F.col("ravive", "fleur"), F.col("ravive", "fleur_coeur"))
		else:
			F.ci_dust(self, Vector2(0, -rr * 0.92), rr, r)



## Éclats de verre au sol : trois à cinq losanges plats. Morts, ternes ; ravivés, ils brillent et
## une petite fleur d'aube pousse entre eux.
class Shards extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size
		var etat: String = F.etat_of(self)
		var g: Dictionary = F.pal(etat, "nacre" if etat == "ravive" else "verre")
		var n := 3 + r.randi() % 3
		for i in n:
			var p := Vector2(r.randf_range(-16.0, 16.0), r.randf_range(-6.0, 6.0)) * s
			var a := r.randf() * PI
			var l := r.randf_range(4.5, 8.5) * s
			var d := Vector2.from_angle(a) * Vector2(1.0, 0.55)
			var nn := Vector2(-d.y, d.x).normalized() * l * 0.24 * Vector2(1.0, 0.6)
			var pts := PackedVector2Array([p - d * l * 0.5, p + nn, p + d * l * 0.5, p - nn])
			O.poly(self, Transform2D(0.0, Vector2(1.0, 1.3)) * pts, Color(0.05, 0.03, 0.04, 0.28))
			O.poly(self, pts, g["ombre"])
			O.poly(self, PackedVector2Array([pts[0], pts[1], pts[2]]), g["clair"])
			draw_line(pts[0].lerp(pts[1], 0.5), pts[2].lerp(pts[1], 0.4), Color(g["reflet"], 0.5 if etat == "fletri" else 0.9), 0.9, true)
		if etat != "ravive":
			return
		var p := Vector2(r.randf_range(-6.0, 6.0), -2.0) * s
		O.blade(self, p + Vector2(0, 4) * s, 5.0 * s, 0.1, 1.2, F.col("ravive", "touffe"))
		F.star(self, p, 2.4 * s, F.col("ravive", "fleur"), F.col("ravive", "fleur_coeur"))
		F.spark(self, Vector2(r.randf_range(-10.0, 10.0), -3.0) * s, 2.4 * s, Color(F.pal("ravive", "nacre")["reflet"], 0.9))


## Bouquet d'éclats de cristal des lisières (sans collision) : trois à six aiguilles de verre et de
## nacre plantées en éventail. Hauteur : 16 × size.
class Cluster extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var h := 16.0 * size
		F.crystal_group(self, Vector2.ZERO, h * 0.75, h, 3 + r.randi() % 4, r, F.etat_of(self))


## Aiguille de cristal géante (repère, sans collision) : une haute aiguille de verre au cœur de nacre,
## entourée d'aiguilles plus petites, plantée dans un socle de calcaire. Ravivée : le verre s'éclaircit,
## une lumière d'or naît à la pointe, des fleurs d'aube au pied. Hauteur : 16 × size.
class Spire extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var etat: String = F.etat_of(self)
		var h := 16.0 * size
		var alive := etat == "ravive"
		O.cast_shadow(self, Vector2.ZERO, h * 0.45, h * 0.9, 0.3)
		if alive:
			draw_circle(Vector2(0, -h * 0.85), h * 0.2, Color(F.col("ravive", "lueur"), 0.05))
			draw_circle(Vector2(0, -h * 0.9), h * 0.1, Color(F.col("ravive", "lueur"), 0.1))
		# Aiguilles de l'arrière.
		var glass: Dictionary = F.pal(etat, "verre")
		var nacre: Dictionary = F.pal(etat, "nacre")
		F.prism(self, Vector2(-h * 0.13, -h * 0.05), h * 0.06, h * 0.55, -h * 0.12, glass)
		F.prism(self, Vector2(h * 0.15, -h * 0.04), h * 0.055, h * 0.46, h * 0.1, nacre)
		# La grande aiguille, puis son cœur de nacre (une veine au milieu).
		var pts := F.prism(self, Vector2(0, -h * 0.02), h * 0.1, h, h * 0.03, glass)
		var tip: Vector2 = pts[2]
		var core := PackedVector2Array([Vector2(-h * 0.025, -h * 0.08), tip.lerp(Vector2(0, -h * 0.1), 0.3) + Vector2(-h * 0.01, 0), tip.lerp(Vector2(0, -h * 0.1), 0.3) + Vector2(h * 0.015, 0), Vector2(h * 0.03, -h * 0.08)])
		O.poly(self, core, Color(nacre["clair"], 0.55 if alive else 0.3))
		# Socle : blocs de calcaire et aiguilles basses devant.
		F.block(self, Vector2(-h * 0.14, h * 0.02), h * 0.16, h * 0.13, r, etat)
		F.block(self, Vector2(h * 0.16, h * 0.04), h * 0.13, h * 0.1, r, etat)
		for i in 3:
			var u := (i - 1) * 0.22
			F.prism(self, Vector2(u * h, h * 0.06), h * 0.03, h * r.randf_range(0.12, 0.2), u * h * 0.3, nacre if i == 1 else glass)
		if alive:
			F.spark(self, tip + Vector2(0, h * 0.02), h * 0.04, F.pal("ravive", "verre")["reflet"])
			for i in 5:
				F.star(self, Vector2(r.randf_range(-0.35, 0.35) * h, h * r.randf_range(0.06, 0.12)), maxf(2.4, h * 0.016),
					F.col("ravive", "fleur" if i % 2 == 0 else "fleur_2"), F.col("ravive", "fleur_coeur"))
		else:
			F.ci_dust(self, Vector2(0, h * 0.08), h * 0.3, r)


## Arche de calcaire et de cristal (repère, sans collision) : deux piliers de dalles empilées portent une
## voûte de claveaux en strates ; des aiguilles de cristal poussent sur l'extrados. Ravivée : herbe dorée,
## fleurs et cristaux clairs. Hauteur : 16 × size.
class Arch extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var etat: String = F.etat_of(self)
		var h := 16.0 * size
		var w := h * 0.42
		var rock: Dictionary = F.pal(etat, "roche")
		O.cast_shadow(self, Vector2(w * 0.2, 0), w * 2.4, h * 0.35, 0.26)
		# Piliers : trois ou quatre dalles empilées, un peu décalées.
		var spring := -h * 0.42
		for side: float in [-1.0, 1.0]:
			var y := 0.0
			var k := 0
			while y > spring + 1.0:
				var bh := h * r.randf_range(0.1, 0.14)
				var bw := h * (0.13 - 0.012 * k)
				F.block(self, Vector2(side * w + r.randf_range(-0.02, 0.02) * h, y), bw, bh, r, etat)
				y -= bh * 0.95
				k += 1
		# Voûte : claveaux taillés en coin entre l'intrados (rayon w) et l'extrados.
		var c := Vector2(0, spring)
		var ri := w * 0.92
		var ro := w + h * 0.15
		var n := 9
		var pts_top := []
		for i in n:
			var a0 := PI + PI * i / n + 0.015
			var a1 := PI + PI * (i + 1) / n - 0.015
			var q := PackedVector2Array()
			for j in 4:
				var a := lerpf(a0, a1, j / 3.0)
				q.append(c + Vector2(cos(a) * ri, sin(a) * ri * 0.95))
			for j in 4:
				var a := lerpf(a1, a0, j / 3.0)
				q.append(c + Vector2(cos(a), sin(a) * 0.95) * (ro + r.randf_range(-0.02, 0.02) * h))
			O.part(self, q, rock, 1.3, 0.9, 0.3)
			var am := (a0 + a1) * 0.5
			var m := c + Vector2(cos(am), sin(am) * 0.95) * (ri + ro) * 0.5
			var d := Vector2.from_angle(am).orthogonal() * h * 0.045
			draw_line(m - d, m + d, Color(rock["ombre"].darkened(0.25), 0.7), 1.0, true)
			pts_top.append([c + Vector2(cos(am), sin(am) * 0.95) * ro, Vector2(cos(am), sin(am))])
		# Aiguilles de cristal sur l'extrados.
		var glass: Dictionary = F.pal(etat, "verre")
		var nacre: Dictionary = F.pal(etat, "nacre")
		for i in [2, 4, 5, 7]:
			var pt: Array = pts_top[i]
			var out: Vector2 = pt[1]
			F.prism(self, pt[0] + Vector2(0, h * 0.02), h * 0.035, h * r.randf_range(0.14, 0.26), out.x * h * 0.12, nacre if i % 2 == 0 else glass)
		if etat == "ravive":
			for i in 5:
				var pt: Array = pts_top[1 + r.randi() % (n - 2)]
				O.tuft(self, pt[0] + Vector2(0, h * 0.015), h * 0.06, F.col("ravive", "touffe"), F.col("ravive", "touffe_2"), tree_seed + i)
			for i in 4:
				F.star(self, Vector2((i - 1.5) * w * 0.55, h * 0.05), maxf(2.4, h * 0.016), F.col("ravive", "fleur"), F.col("ravive", "fleur_coeur"))
		else:
			F.ci_dust(self, Vector2(0, h * 0.04), w, r)
