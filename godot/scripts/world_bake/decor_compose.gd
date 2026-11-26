## Décor composé par règles (refonte du monde « Paysages d'herbier », vague 1 D ; prototype en vague 0 P,
## règles de la planche W : world_art/paysage.gd).
##
## Au lieu d'un semis uniforme, chaque région est composée :
##   - des **clairières** dégagées, où l'on se bat et où l'on lit le combat : autour de chaque lieu
##     (Cœurs, sanctuaires, autels, secrets, arène, abords de la graine), des clairières de combat
##     semées sur toute la région, et des passages qui relient les lieux (un arbre couvrant) ;
##   - des **lisières** autour d'elles : de petits objets au bord, puis des grappes de 3 à 9 objets
##     autour d'un grand, de plus en plus denses et grandes à mesure qu'on s'éloigne d'une clairière ;
##   - des **repères** visibles de loin (« landmarks » du fichier de la région, à leur place) ;
##   - des **grands éléments de premier plan** (arbres, haies, chapeaux), assez hauts pour passer devant
##     le héros : environ 6 à 8 par écran dans les lisières, assombris, à demi transparents quand le
##     héros ou un Flétri est derrière (decor_bake.gd › Runtime).
## Échelle commune (héros ≈ 56 px) réduite d'un quart après la planche W : arbre ≈ 2,5-3,5 fois le
## héros, rocher 0,75-1,5 fois, touffe moins d'un tiers. Au plus MAX_SCREEN éléments par écran.
##
## Roncier et Marais : les objets de la planche W (world_art/decor.gd, classe Objet). Les quatre autres
## régions gardent leurs dessins (decor_<sorte>.gd), composés de la même façon, en attendant leur passe
## de la vague 2 (une région change sa table, LISIERES[id], sans toucher au moteur).
##
## Dessin seul : les obstacles (buissons d'épines, rochers, troncs, cristaux, racines…) restent où le
## semis les a posés, avec leur rayon ; les sources, flaques et éboulis plats restent au sol ; seuls les
## éléments sans collision du semis sont remplacés. Aucun obstacle n'est ajouté.
extends RefCounted

const Flora = preload("res://scripts/flora.gd")
const Regions = preload("res://scripts/regions.gd")
const Decor = preload("res://scripts/world_art/decor.gd")

## « --decor-ancien » : le semis d'avant (comparaisons).
static var enabled := true
## Éléments au plus dans un écran (1600 × 900 px du monde).
const MAX_SCREEN := 80
const SCREEN := Vector2(1600, 900)
## Bord du monde : rien au-delà (world_edge.gd y dessine la lisière du monde).
const WORLD_LIMIT := 2830.0
## Clairières de combat : espacement, rayon (de … à …), aplatissement (vue de trois quarts).
const CLEAR_STEP := 820.0
const CLEAR_R := [200.0, 280.0]
const CLEAR_FLAT := 0.8
## Demi-largeur des passages entre les lieux.
const PATH_HALF := 80.0
## Grappes : espacement des centres, distance minimale entre deux grands éléments.
const CLUSTER_STEP := 110.0
const BIG_GAP := 230.0
## Lisière : au-delà de DEEP px d'une clairière, la lisière est dense ; le bord, jusqu'à EDGE px.
const EDGE := 80.0
const DEEP := 150.0
## Assombri du premier plan (grands éléments), éclairci du décor apaisé.
const FG_SHADE := 0.82
## Un élément est « grand » (premier plan, transparent quand on passe derrière) au-delà de cette hauteur.
const TALL := 80.0

## Tables de composition : [sorte, taille min, taille max, poids]. Une sorte est un objet de
## world_art/decor.gd (« arbre », « haie »…) ou une classe d'un décor de région (« plateau:Twisted »).
## « bord » : au bord des clairières ; « grappe » : autour d'un grand ; « grand » : le centre d'une
## grappe dans la lisière dense ; « repere » : dessin des repères du fichier (par sorte, « * » : tous).
const LISIERES := {  # i18n: non (début)
	"ronce": {
		"bord": [["buisson", 0.75, 1.1, 4], ["rocher", 0.6, 1.0, 1.2], ["muret", 0.85, 1.05, 1]],
		"grappe": [["haie", 0.85, 1.25, 3], ["buisson", 0.95, 1.3, 2.5], ["rocher", 0.8, 1.25, 0.8], ["muret", 0.9, 1.1, 0.4]],
		"grand": [["arbre", 0.85, 1.15, 3], ["haie", 1.35, 1.6, 1.2]],
		"repere": {"grand_arbre": ["grand_arbre", 0.92], "ruine": ["ruine", 1.15], "rocher": ["rocher", 2.6]},
	},
	"spore": {
		"bord": [["fougere", 0.75, 1.15, 3], ["roseaux", 0.75, 1.05, 2.5], ["champignon", 0.3, 0.45, 0.8], ["rocher", 0.55, 0.85, 0.4]],
		"grappe": [["fougere", 1.0, 1.4, 3], ["roseaux", 1.0, 1.3, 2], ["tronc", 0.85, 1.1, 0.8], ["champignon", 0.45, 0.65, 1]],
		"grand": [["champignon", 0.8, 1.1, 3], ["roseaux", 1.35, 1.55, 1]],
		"repere": {"grand_arbre": ["chapeau_geant", 1.05], "*": ["chapeau_geant", 0.8]},
	},
	"vent": {
		"bord": [["plateau:Grass", 0.8, 1.3, 5], ["plateau:Twisted", 0.9, 1.3, 1]],
		"grappe": [["plateau:Grass", 1.0, 1.5, 3], ["plateau:Twisted", 1.4, 2.0, 2]],
		"grand": [["plateau:Twisted", 2.9, 3.7, 1]],
	},
	"seve": {
		"bord": [["vallee:Fern", 0.8, 1.3, 1]],
		"grappe": [["vallee:Fern", 1.0, 1.5, 3], ["vallee:Willow", 1.3, 1.8, 1]],
		"grand": [["vallee:Willow", 2.6, 3.4, 1]],
	},
	"aube": {
		# Falaises (vague 2 P5) : éclats de cristal et arbres blanchis ; Cluster, Spire et Arch font
		# 16 × size de haut (height_of), Bleached 52 × size.
		"bord": [["falaise:Shards", 0.8, 1.4, 2], ["falaise:Cluster", 1.6, 2.6, 2]],
		"grappe": [["falaise:Cluster", 2.4, 3.8, 3], ["falaise:Bleached", 1.2, 1.7, 2], ["falaise:Shards", 1.0, 1.5, 1]],
		"grand": [["falaise:Bleached", 2.5, 3.2, 3], ["falaise:Cluster", 5.5, 7.0, 1]],
		"repere": {"ruine": ["falaise:Arch", 11.0], "rocher": ["falaise:Spire", 14.0], "grand_arbre": ["falaise:Spire", 16.0], "*": ["falaise:Spire", 14.0]},
	},
	"racine": {
		"bord": [["foret:Stump", 0.8, 1.1, 1]],
		"grappe": [["foret:Stump", 1.0, 1.5, 2], ["foret:StoneTree", 1.3, 1.8, 2]],
		"grand": [["foret:StoneTree", 2.6, 3.4, 1]],
	},
}
## Souplesse au vent par sorte (lue par le monde vivant, tâche V).
const SWAY := {
	"arbre": 1.0, "haie": 0.7, "buisson": 0.6, "champignon": 0.25, "chapeau_geant": 0.15, "grand_arbre": 0.5, "roseaux": 1.2,
	"fougere": 0.9, "Twisted": 0.9, "Grass": 1.1, "Willow": 1.0, "Fern": 0.9, "Bleached": 0.7,
	"StoneTree": 0.1, "DecorTree": 1.0, "DecorBramble": 0.8, "DecorBush": 0.35, "DecorReeds": 1.2, "DecorMushroom": 0.25,
	# Falaises : cristaux et repères rigides (0,01 et non 0, qui laisse la table du monde vivant décider).
	"Cluster": 0.01, "falaise:Spire": 0.01, "falaise:Arch": 0.01,
}  # i18n: non (fin)
## Décor de région -> son script (pour « plateau:Twisted »).
const SCRIPTS := {
	"plateau": "res://scripts/decor_plateau.gd", "vallee": "res://scripts/decor_vallee.gd",
	"falaise": "res://scripts/decor_falaise.gd", "foret": "res://scripts/decor_foret.gd",
	"marais": "res://scripts/decor_marais.gd",
}

## Dernière composition (tests, banc) : région -> {clearings, paths, placed, removed}.
static var report := {}


## Un objet de la planche W (world_art/decor.gd) posé dans le jeu : mort (« fletri ») ou vivant
## (« ravive »), cuit comme le reste du décor ; dessiné en direct avant la cuisson.
class Objet extends Flora.DecorTree:
	var kind := "arbre"
	var region := "ronce"
	var flip := false

	func _paint() -> void:
		var m := Etat.new()
		m.region = region
		m.etat = "ravive" if alive and growth() > 0.5 else "fletri"
		Decor.draw(self, {"kind": kind, "at": Vector2.ZERO, "size": size, "seed": tree_seed, "flip": flip}, m)


## Ce que world_art/decor.gd demande au paysage : la région et l'état d'un point.
class Etat extends RefCounted:
	var region := "ronce"
	var etat := "fletri"

	func region_at(_p: Vector2) -> String:
		return region

	func decor_etat_at(_p: Vector2) -> String:
		return etat


static func configure() -> void:
	enabled = not "--decor-ancien" in OS.get_cmdline_user_args()


# --- Géométrie : clairières et passages ---

## Zones dégagées d'une région : [[centre, rayon, aplatissement], ...] et passages [[a, b], ...].
static func clearings(reg: String) -> Dictionary:
	var lieux := []
	for s in Regions.heart_spots(reg):
		lieux.append([s["pos"], float(s["zone"]) + 40.0, 1.0])
	for s in Regions.def(reg).get("sanctuaries", []):
		lieux.append([Regions.place(reg, s), 140.0, 1.0])
	for s in Regions.def(reg).get("altars", []):
		lieux.append([Regions.place(reg, s), 85.0, 1.0])
	for s in Regions.def(reg).get("secrets", []):
		if s is Dictionary and s.has("dist"):
			lieux.append([Regions.place(reg, s), 85.0, 1.0])
	var boss := Regions.section(reg, "boss")
	if not boss.is_empty():
		lieux.append([Regions.arena_center(reg), float(boss.get("arena", {}).get("radius", 470.0)) + 60.0, 1.0])
	var cfg := Regions.section(reg, "decor")
	var seed_clear := float(cfg.get("clear_seed", 560.0))
	var out := lieux.duplicate()
	# Repères : une petite clairière autour, pour qu'ils se lisent seuls.
	for l in Regions.def(reg).get("landmarks", []):
		out.append([Regions.place(reg, l), 90.0, 1.0])
	# Clairières de combat : une grille décalée sur toute la région, loin des lieux.
	var r := RandomNumberGenerator.new()
	r.seed = hash([reg, "clairieres"])
	var mid := Regions.angle_of(reg)
	for gy in range(-5, 6):
		for gx in range(-5, 6):
			var p := Vector2(gx + (0.5 if posmod(gy, 2) == 1 else 0.0), gy * 0.87) * CLEAR_STEP
			p = p.rotated(mid) + Vector2(r.randf_range(-0.22, 0.22), r.randf_range(-0.22, 0.22)) * CLEAR_STEP
			if Regions.region_weighted(p) != reg or absf(p.x) > WORLD_LIMIT - 150.0 or absf(p.y) > WORLD_LIMIT - 150.0:
				continue
			var far := true
			for l in out:
				if p.distance_to(l[0]) < l[1] + 420.0:
					far = false
					break
			if far:
				out.append([p, r.randf_range(CLEAR_R[0], CLEAR_R[1]), CLEAR_FLAT])
	# Passages : un arbre couvrant qui relie l'entrée de la région (côté graine) à ses lieux.
	var nodes: Array = [Regions.place(reg, {"dist": Regions.INNER + 120.0, "side": 0.0})]
	for l in lieux:
		nodes.append(l[0])
	var paths := []
	var linked := [0]
	while linked.size() < nodes.size():
		var best := [-1, -1, INF]
		for i in linked:
			for j in nodes.size():
				if j in linked:
					continue
				var d: float = nodes[i].distance_to(nodes[j])
				if d < best[2]:
					best = [i, j, d]
		linked.append(best[1])
		paths.append([nodes[best[0]], nodes[best[1]]])
	out.append([Vector2.ZERO, seed_clear, 1.0])
	return {"clearings": out, "paths": paths}


## Distance (px, positive dehors) entre un point et la zone dégagée la plus proche.
static func clear_dist(p: Vector2, geo: Dictionary) -> float:
	var best := INF
	for c in geo["clearings"]:
		var d: Vector2 = p - c[0]
		d.y /= c[2]
		best = minf(best, d.length() - c[1])
	for s in geo["paths"]:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b - a
		var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * u) - PATH_HALF)
	return best


# --- Composition ---

## Remplace le semis sans collision par le décor composé, région par région.
static func apply(flora) -> void:
	report = {}
	var obstacles := {}
	for b in flora.bushes:
		obstacles[b] = true
	# Ce qui reste du semis : les obstacles, ce qui est posé au sol (sources, flaques, éboulis) et ce
	# qui est hors des régions (oasis). Les repères d'une région à objets W sont redessinés.
	var removed := {}
	for t in flora.trees.duplicate():
		var reg := Regions.region_weighted(t.position)
		t.bake_region = reg
		t.sway = float(SWAY.get(_short(t), 0.0))
		if obstacles.has(t) or reg == "" or not LISIERES.has(reg):
			continue
		if t.get_parent() == flora:
			continue
		if t is Flora.DecorLandmark:
			# Repère : gardé (redessiné par _reperes dans une région à objets W).
			_tall(t, 140.0 * t.size)
			continue
		removed[reg] = removed.get(reg, 0) + 1
		flora.remove_tree(t)
	var all := []
	for reg in Regions.ids():
		if LISIERES.has(reg):
			all.append_array(_compose(flora, reg, removed.get(reg, 0)))
	var thinned := _thin(flora, all)
	for reg in report:
		report[reg]["thinned"] = thinned.get(reg, 0)
		report[reg]["placed"] -= thinned.get(reg, 0)


## Nom court de la classe d'un élément (« Twisted », « DecorBush »…).
static func _short(t) -> String:
	if t is Objet:
		return t.kind
	for s in [Flora, load(SCRIPTS["plateau"]), load(SCRIPTS["vallee"]), load(SCRIPTS["falaise"]), load(SCRIPTS["foret"]), load(SCRIPTS["marais"])]:
		var cm: Dictionary = s.get_script_constant_map()
		for k in cm:
			if cm[k] is GDScript and t.get_script() == cm[k]:
				return k
	return ""


static func _tall(t, h: float) -> void:
	if h > TALL:
		t.tall = h


static func _compose(flora, reg: String, removed: int) -> Array:
	var lis: Dictionary = LISIERES[reg]
	var geo := clearings(reg)
	var r := RandomNumberGenerator.new()
	r.seed = hash([reg, "lisiere"])
	var placed := []
	var bigs := []
	var obstacles := []
	for b in flora.bushes:
		if b.position.distance_to(Regions.center(reg)) < 4200.0:
			obstacles.append(b)
	var lieux := []
	for c in geo["clearings"]:
		if c[2] == 1.0:
			lieux.append(c)
	var mid := Regions.angle_of(reg)
	var n := int(ceil(2.0 * WORLD_LIMIT / CLUSTER_STEP)) + 2
	for gy in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var c := Vector2(gx + r.randf_range(-0.45, 0.45), gy + r.randf_range(-0.45, 0.45)) * CLUSTER_STEP
			if Regions.region_weighted(c) != reg or not _in_world(c, 20.0):
				continue
			var e := clear_dist(c, geo)
			if e < 18.0:
				continue
			# Direction de la clairière la plus proche (les petits objets se rangent de ce côté).
			var inward := Vector2(clear_dist(c + Vector2(12, 0), geo) - clear_dist(c - Vector2(12, 0), geo),
				clear_dist(c + Vector2(0, 12), geo) - clear_dist(c - Vector2(0, 12), geo)) * -1.0
			inward = inward.normalized() if inward.length() > 0.001 else Vector2.DOWN
			if e < EDGE:
				# Bord : un ou deux petits objets, clairsemés.
				if r.randf() < 0.9:
					for i in 1 + int(r.randf() < 0.6):
						var q := c + Vector2(r.randf_range(-60, 60), r.randf_range(-40, 40))
						_try(flora, reg, _pick(lis["bord"], r), q, r, geo, placed, obstacles, lieux, 0.0)
				continue
			var dense := clampf((e - EDGE) / (DEEP - EDGE), 0.0, 1.0)
			# Grappe : un grand au centre dans la lisière dense (assez loin des autres grands), puis 2 à
			# 8 objets plus petits, du côté de la clairière.
			var has_big := false
			if dense >= 1.0 and r.randf() < 0.9:
				var ok := true
				for b in bigs:
					if c.distance_to(b) < BIG_GAP:
						ok = false
						break
				if ok and _try(flora, reg, _pick(lis["grand"], r), c, r, geo, placed, obstacles, lieux, 1.0) != null:
					bigs.append(c)
					has_big = true
			var count := r.randi_range(3, 5) + (r.randi_range(2, 4) if has_big else 0)
			if not has_big and r.randf() > 0.7 + 0.3 * dense:
				continue
			for i in count:
				var q := c + inward * r.randf_range(15.0, 85.0) + inward.orthogonal() * r.randf_range(-90.0, 90.0)
				_try(flora, reg, _pick(lis["grappe"] if r.randf() < 0.55 + 0.4 * dense else lis["bord"], r), q, r, geo, placed, obstacles, lieux, 0.0)
	var repl := _reperes(flora, reg, lis, placed)
	report[reg] = {"clearings": geo["clearings"].size(), "paths": geo["paths"].size(), "placed": placed.size(), "removed": removed, "reperes": repl, "bigs": bigs.size()}
	return placed


static func _in_world(p: Vector2, margin: float) -> bool:
	return absf(p.x) < WORLD_LIMIT - margin and absf(p.y) < WORLD_LIMIT - margin and p.length() > Regions.INNER + 40.0


static func _pick(list: Array, r: RandomNumberGenerator) -> Array:
	var total := 0.0
	for e in list:
		total += e[3]
	var x := r.randf() * total
	for e in list:
		x -= e[3]
		if x <= 0.0:
			return e
	return list[0]


## Hauteur dessinée (px du monde) d'une sorte à une taille.
static func height_of(sort: String, size: float) -> float:
	if Decor.HEIGHT.has(sort):
		return Decor.HEIGHT[sort] * size
	# Anciens dessins : un arbre de taille 1 fait ~60 px, une touffe ~18 px.
	match sort.get_slice(":", 1):
		"Twisted", "Willow", "Bleached", "StoneTree":  # i18n: non
			return 52.0 * size
		"Stump":  # i18n: non
			return 26.0 * size
		_:
			return 16.0 * size


## Emprise au sol (rayon, px du monde) d'une sorte à une taille.
static func foot_of(sort: String, size: float) -> float:
	var h := height_of(sort, size)
	match sort:
		"haie", "muret", "tronc":
			return h * 0.9
		"roseaux", "fougere":
			return h * 0.4
	return h * 0.42


## Pose un objet s'il ne gêne rien : hors des zones dégagées, des obstacles, des autres objets, et sans
## cacher un lieu placé derrière lui. Rend l'élément posé, ou null.
static func _try(flora, reg: String, pick: Array, p: Vector2, r: RandomNumberGenerator, geo: Dictionary, placed: Array, obstacles: Array, lieux: Array, fg: float):
	var sort: String = pick[0]
	var size := r.randf_range(pick[1], pick[2])
	var seed := r.randi()
	var flip := r.randf() < 0.5
	if Regions.region_weighted(p) != reg or not _in_world(p, 10.0):
		return null
	var foot := foot_of(sort, size)
	var h := height_of(sort, size)
	if clear_dist(p, geo) < foot * 0.55 + 6.0:
		return null
	for b in obstacles:
		if p.distance_to(b.position) < float(b.radius) + foot * 0.45 + 6.0:
			return null
	for o in placed:
		if p.distance_to(o.position) < (foot + o.get_meta("foot")) * 0.42:
			return null
	# Un objet haut ne cache jamais un lieu placé juste derrière lui (plus haut à l'écran).
	if h > TALL:
		for l in lieux:
			var q: Vector2 = l[0]
			var rr: float = minf(l[1], 120.0)
			if q.y < p.y + 10.0 and q.y > p.y - h - rr and absf(q.x - p.x) < h * 0.5 + rr:
				return null
	var t = _make(sort, reg)
	if t == null:
		return null
	t.position = p
	t.size = size
	t.tree_seed = seed
	if t is Objet:
		t.flip = flip if sort in ["arbre", "haie"] else false
	t.bake_region = reg
	t.alive = flora.ground.life_at(p) > flora.ALIVE
	t.sway = float(SWAY.get(sort.get_slice(":", 1) if ":" in sort else sort, 0.0))
	_tall(t, h)
	if fg > 0.0 and t.tall > 0.0:
		t.shade = FG_SHADE
		t.self_modulate = Color(FG_SHADE, FG_SHADE, FG_SHADE)
	t.set_meta("foot", foot)
	t.set_meta("centre", fg > 0.0)
	flora.add_decor(t)
	placed.append(t)
	return t


static func _make(sort: String, reg: String):
	if ":" in sort:
		var s = load(SCRIPTS.get(sort.get_slice(":", 0), ""))
		var cls = s.get_script_constant_map().get(sort.get_slice(":", 1)) if s != null else null
		if cls == null:
			push_error("Décor composé : sorte inconnue « %s »" % sort)
			return null
		var t = cls.new()
		# Penchant du vent des plateaux : le même que le semis (decor_plateau.gd › _lean).
		if t.get("lean") != null:
			t.lean = _wind_lean(reg)
		return t
	var o := Objet.new()
	o.kind = sort
	o.region = reg
	return o


static func _wind_lean(reg: String) -> float:
	var w := Regions.section(reg, "wind")
	var d := Vector2.from_angle(Regions.angle_of(reg) + float(w.get("angle", 0.0)))
	return clampf(d.x * 1.15, -1.0, 1.0) if absf(d.x) > 0.15 else (0.15 if d.x >= 0.0 else -0.15)


## Repères du fichier de la région (et géants du Marais), redessinés avec les objets W à leur place.
static func _reperes(flora, reg: String, lis: Dictionary, placed: Array) -> int:
	if not lis.has("repere"):
		return 0
	var rep: Dictionary = lis["repere"]
	var spots := []
	for t in flora.landmarks.duplicate():
		if Regions.region_weighted(t.position) == reg:
			spots.append([t.position, t.kind])
			flora.remove_tree(t)
	for g in Regions.section(reg, "decor").get("giants", []):
		spots.append([Regions.place(reg, g), "*"])
	var n := 0
	for s in spots:
		var spec: Array = rep.get(s[1], rep.get("*", ["arbre", 1.4]))
		var o = _make(spec[0], reg) if ":" in spec[0] else Objet.new()
		if o is Objet:
			o.kind = spec[0]
			o.region = reg
		o.size = spec[1]
		o.tree_seed = hash([reg, s[1], n])
		o.position = s[0]
		o.bake_region = reg
		o.alive = flora.ground.life_at(o.position) > flora.ALIVE
		o.sway = float(SWAY.get(spec[0], 0.0)) * 0.5
		_tall(o, height_of(spec[0], spec[1]))
		o.set_meta("foot", foot_of(spec[0], spec[1]))
		# Les objets trop proches du repère lui laissent la place.
		for q in placed.duplicate():
			if q.position.distance_to(o.position) < 90.0 + q.get_meta("foot") * 0.5:
				placed.erase(q)
				flora.remove_tree(q)
		flora.add_decor(o)
		flora.landmarks.append(o)
		n += 1
	return n


## Au plus MAX_SCREEN éléments debout du décor dans un écran (les détails plats posés au sol, sources,
## flaques, éboulis, comptent avec le sol) : les plus petits objets composés en trop sont retirés,
## écran par écran (fenêtres décalées d'un quart d'écran).
static func _thin(flora, placed: Array) -> Dictionary:
	var cells := {}
	var step := SCREEN * 0.2
	var cell_of := func(p: Vector2) -> Vector2i: return Vector2i(floori(p.x / step.x), floori(p.y / step.y))
	for t in flora.trees:
		if is_instance_valid(t) and not t.is_queued_for_deletion() and t.get_parent() != flora:
			var k: Vector2i = cell_of.call(t.position)
			if not cells.has(k):
				cells[k] = []
			cells[k].append(t)
	var mine := {}
	for t in placed:
		mine[t] = true
	var out := {}
	var keys := cells.keys()
	var lo := Vector2i(999999, 999999)
	var hi := Vector2i(-999999, -999999)
	for k in keys:
		lo = Vector2i(mini(lo.x, k.x), mini(lo.y, k.y))
		hi = Vector2i(maxi(hi.x, k.x), maxi(hi.y, k.y))
	# Fenêtres de 6 × 6 cases (un écran et un cinquième) : tout écran, où qu'il tombe, est dedans.
	for wy in range(lo.y - 5, hi.y + 1):
		for wx in range(lo.x - 5, hi.x + 1):
			var inside := []
			for y in range(wy, wy + 6):
				for x in range(wx, wx + 6):
					for t in cells.get(Vector2i(x, y), []):
						if is_instance_valid(t) and not t.is_queued_for_deletion():
							inside.append(t)
			if inside.size() <= MAX_SCREEN:
				continue
			# Les centres des grappes restent ; le reste s'éclaircit au hasard (tiré du germe), pour garder
			# le mélange de petits et de grands autour de chaque centre.
			var extra := inside.filter(func(t): return mine.has(t) and not t.get_meta("centre", false))
			extra.sort_custom(func(a, b): return hash(a.tree_seed) < hash(b.tree_seed))
			for i in mini(inside.size() - MAX_SCREEN, extra.size()):
				placed.erase(extra[i])
				mine.erase(extra[i])
				out[extra[i].bake_region] = out.get(extra[i].bake_region, 0) + 1
				flora.remove_tree(extra[i])
	return out


## Nombre d'éléments debout du décor dans l'écran centré en c (tests, banc).
static func count_in_screen(flora, c: Vector2) -> int:
	var rect := Rect2(c - SCREEN * 0.5, SCREEN)
	var n := 0
	for t in flora.trees:
		if is_instance_valid(t) and not t.is_queued_for_deletion() and t.visible and t.get_parent() != flora and rect.has_point(t.position):
			n += 1
	return n


## Centre de la zone du banc (« --bench-at=ronce ») : dans l'axe du Roncier, entre la ruine, le
## sanctuaire du Ravin et celui de la Veille.
static func test_center() -> Vector2:
	return Vector2.from_angle(Regions.angle_of("ronce")) * 1520.0
