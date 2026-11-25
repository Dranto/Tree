## Composition du décor par règles (prototype technique, refonte du monde, vague 0 P).
##
## Sur une zone de test du Roncier (le centre : point du banc, « --bench-at »), le décor n'est plus
## semé au hasard mais composé autour d'une clairière de combat :
##   - la clairière (rayon CLEAR) reste vide : on y lit le combat ;
##   - la lisière : des grappes serrées tout autour (un grand élément, puis des plus petits côté
##     clairière : ronces, buissons, rochers), avec deux ou trois trouées (passages, lecture) ;
##   - un repère : un grand arbre, plus grand que tout le reste, d'un côté de la clairière ;
##   - le premier plan : de grands éléments sur l'anneau extérieur, qui débordent sur les bords
##     de l'écran.
## Échelle commune (le héros mesure ~58 px) : arbre 3 à 5 fois le héros, rocher 1 à 2 fois.
##
## Dessin seul : aucun de ces éléments ne fait obstacle (pas d'add_obstacle). Ils reverdissent avec
## la vie comme le reste du décor (flora._add_tree).
extends RefCounted

const Flora = preload("res://scripts/flora.gd")
const Regions = preload("res://scripts/regions.gd")

## Rayon de la clairière de combat, largeur de la lisière (pixels du monde).
const CLEAR := 360.0
const RING := 420.0
## Nombre d'éléments visé (« --decor-n=N »).
static var target := 170


## Centre de la zone de test : dans l'axe du Roncier, entre la ruine, le sanctuaire du Ravin et celui
## de la Veille (aucun Cœur, autel ni arène tout près).
static func test_center() -> Vector2:
	return Vector2.from_angle(Regions.angle_of("ronce")) * 1520.0


static func configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--decor-n="):
			target = clampi(a.get_slice("=", 1).to_int(), 0, 4000)


## Pose le décor composé autour de center. Rend les éléments posés.
static func spawn(flora, center: Vector2) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var out: Array = []
	# Clairière dégagée : les ronces semées (dessin seul) y sont cachées ; les buissons d'épines, qui
	# font obstacle, restent (aucune collision ne change).
	for t in flora.trees:
		if not t is Flora.DecorBush and t.position.distance_to(center) < CLEAR:
			t.visible = false
	# Trouées : trois angles sans grappe, pour les passages et la lecture.
	var gaps := [r.randf() * TAU]
	gaps.append(gaps[0] + 2.2 + r.randf_range(-0.3, 0.3))
	gaps.append(gaps[0] + 4.1 + r.randf_range(-0.3, 0.3))
	var repere_a: float = gaps[0] + 1.1
	# Repère : un grand arbre mort, d'un côté de la clairière.
	out.append(_add(flora, Flora.DecorLandmark.new(), center + Vector2.from_angle(repere_a) * (CLEAR + 120.0), 2.0, "grand_arbre"))
	var per_cluster := 5.0
	var clusters := maxi(0, int(target * 0.8 / per_cluster))
	for i in clusters:
		var a := TAU * (i + r.randf_range(-0.3, 0.3)) / maxf(1.0, clusters)
		if _near_gap(a, gaps) or absf(angle_difference(a, repere_a)) < 0.18:
			continue
		var d := CLEAR + 40.0 + r.randf() * RING * 0.55
		var c := center + Vector2.from_angle(a) * d
		var inward := (center - c).normalized()
		# Le grand élément, côté extérieur.
		var big_is_tree := r.randf() < 0.55
		if big_is_tree:
			out.append(_add(flora, Flora.DecorTree.new(), c - inward * 30.0, r.randf_range(3.0, 4.2)))
		else:
			out.append(_add(flora, Flora.DecorBramble.new(), c - inward * 20.0, r.randf_range(1.8, 2.6)))
		# Les petits, côté clairière : ronces, buissons, rochers.
		var n := 3 + r.randi() % 3
		for j in n:
			var q := c + inward * r.randf_range(10.0, 70.0) + inward.orthogonal() * r.randf_range(-75.0, 75.0)
			var k := r.randf()
			if k < 0.5:
				out.append(_add(flora, Flora.DecorBramble.new(), q, r.randf_range(0.9, 1.5)))
			elif k < 0.8:
				var bush := Flora.DecorBush.new()
				bush.radius = r.randf_range(24.0, 40.0)
				out.append(_add(flora, bush, q, 1.0))
			else:
				out.append(_add(flora, Flora.DecorLandmark.new(), q, r.randf_range(0.35, 0.6), "rocher"))
	# Premier plan : grands éléments sur l'anneau extérieur, plus espacés.
	var fg := int(target * 0.2)
	for i in fg:
		var a := TAU * (i + r.randf()) / maxf(1.0, fg)
		if _near_gap(a, gaps):
			continue
		var q := center + Vector2.from_angle(a) * (CLEAR + RING * r.randf_range(0.7, 1.05))
		if r.randf() < 0.6:
			out.append(_add(flora, Flora.DecorTree.new(), q, r.randf_range(4.0, 5.0)))
		else:
			out.append(_add(flora, Flora.DecorBramble.new(), q, r.randf_range(2.4, 2.8)))
	return out


static func _near_gap(a: float, gaps: Array) -> bool:
	for g in gaps:
		if absf(angle_difference(a, g)) < 0.3:
			return true
	return false


static func _add(flora, t, p: Vector2, size: float, kind := ""):
	if kind != "":
		t.kind = kind
		t.tree_seed = hash(kind)
	else:
		t.tree_seed = hash(p)
	if not t is Flora.DecorBush:
		t.size = size
	t.position = p
	t.alive = flora.ground.life_at(p) > flora.ALIVE
	flora.trees_parent.add_child(t)
	flora._add_tree(t)
	return t
