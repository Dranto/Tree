## Décor : arbres morts qui reverdissent quand la vie revient, et fleurs qui éclosent.
##
## Performance : rien n'est redessiné en bloc. Les fleurs sont rangées par carrés de
## CHUNK pixels, et une nouvelle fleur ne redessine que son carré. Chaque arbre est son
## propre nœud, redessiné seulement quand il reverdit. Godot ne dessine que ce qui est à l'écran.
## Les arbres sont triés en profondeur (Y-sort) avec les personnages : il suffit de les placer
## dans le même calque trié (« trees_parent »).
##
## Roncier (région de Ronce, voir regions.gd) : les arbres y sont remplacés par des ronces mortes
## et grises qui verdissent et fleurissent quand la vie revient, et des buissons d'épines font
## obstacle (push_out, collision par cercles rangés dans une grille). Une vague de vie fait
## pousser les feuilles progressivement (GROW_TIME) et éclore les fleurs au passage du front.
extends Node2D

const Regions = preload("res://scripts/regions.gd")

const MAX_FLOWERS := 900
const TREE_COUNT := 260
const CHUNK := 512.0
const ALIVE := 0.45
## Durée de la pousse des feuilles d'un arbre ou d'une ronce qui reverdit pendant une vague.
const GROW_TIME := 1.1
const BRAMBLE_COUNT := 130
const BUSH_COUNT := 46
## Taille des cases de la grille des buissons d'épines.
const BUSH_CELL := 256.0
## Zones gardées libres de buissons : l'oasis de départ et le centre de la région (Cœur, arène).
const BUSH_CLEAR_CENTER := 340.0
const BUSH_CLEAR_SEED := 560.0

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
## Fleurs d'une vague de vie qui n'ont pas encore éclos : {f, at} (at = temps d'éclosion).
var pending: Array = []
var clock := 0.0


## Un arbre du décor, dessiné autour de son pied (l'origine sert au tri en profondeur).
## « leaf » (0 à 1) : pousse des feuilles quand il reverdit pendant une vague de vie.
class DecorTree extends Node2D:
	var size := 1.0
	var tree_seed := 0
	var alive := false
	var leaf := 1.0

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

	func _draw() -> void:
		var s := size
		var trunk := Color("5a4636") if alive else Color("1e1a18")
		if alive and leaf < 1.0:
			trunk = Color("1e1a18").lerp(Color("5a4636"), leaf)
		draw_line(Vector2.ZERO, Vector2(0, -34) * s, trunk, 6.0 * s)
		if alive and leaf < 1.0:
			_dead_branches(s, trunk)
		if alive:
			var g := 1.0 - (1.0 - leaf) * (1.0 - leaf)
			if g > 0.02:
				draw_circle(Vector2(0, -42) * s, 22.0 * s * g, Color("2f6b2a"))
				draw_circle(Vector2(-12, -34) * s, 15.0 * s * g, Color("3b7d31"))
				draw_circle(Vector2(12, -36) * s, 16.0 * s * g, Color("468f38"))
		else:
			_dead_branches(s, trunk)

	func _dead_branches(s: float, trunk: Color) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		for i in 4:
			var a := -PI / 2.0 + r.randf_range(-1.0, 1.0)
			var start := Vector2(0, -r.randf_range(14, 32)) * s
			draw_line(start, start + Vector2.from_angle(a) * r.randf_range(14, 26) * s, trunk, 3.5 * s)


## Une ronce du roncier : tiges arquées et épineuses, grises quand la terre est morte ;
## vivante, elle verdit, se couvre de feuilles, de fleurs blanches et de baies rouges.
class DecorBramble extends DecorTree:
	func _draw() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var s := size * 1.6
		var g := (1.0 - (1.0 - leaf) * (1.0 - leaf)) if alive else 0.0
		var stem := Color("5e5650").lerp(Color("3f6e2e"), g)
		var thorn := Color("8a8078").lerp(Color("c9b48a"), g)
		draw_circle(Vector2(0, -2) * s, 13.0 * s, Color(0, 0, 0, 0.18))
		var tips: Array = []
		for i in 5:
			# Chaque tige part du pied, monte puis retombe en arc.
			var side := r.randf_range(-1.0, 1.0)
			var h := r.randf_range(18.0, 34.0)
			var pts := PackedVector2Array()
			for j in 7:
				var k := j / 6.0
				pts.append(Vector2(side * 26.0 * k, -h * sin(k * PI * 0.85)) * s)
			draw_polyline(pts, stem, 2.4 * s)
			for j in [2, 4]:
				var p: Vector2 = pts[j]
				draw_line(p, p + Vector2(0, -4) * s, thorn, 1.4 * s)
			tips.append(pts[5])
			tips.append(pts[3])
		if g > 0.02:
			for p in tips:
				draw_circle(p, 5.0 * s * g, Color("4f8a37"))
				draw_circle(p + Vector2(3, -2) * s, 3.5 * s * g, Color("5f9c40"))
			if g > 0.6:
				for i in tips.size():
					var p: Vector2 = tips[i]
					if i % 3 == 0:
						draw_circle(p + Vector2(-2, -3) * s, 2.6 * s, Color("f4ecf0"))
						draw_circle(p + Vector2(-2, -3) * s, 1.0 * s, Color("f2d06b"))
					else:
						draw_circle(p + Vector2(2, 2) * s, 2.0 * s, Color("c8243a"))
		else:
			# Quelques baies sèches restées sur les tiges mortes.
			for i in 2:
				draw_circle(tips[i * 3], 1.6 * s, Color("5a2a2a"))


## Buisson d'épines : obstacle solide (cercle de rayon « radius »), mort ou vivant comme le reste.
class DecorBush extends DecorTree:
	var radius := 26.0

	func _draw() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := (1.0 - (1.0 - leaf) * (1.0 - leaf)) if alive else 0.0
		var body := Color("3a3330").lerp(Color("244a22"), g)
		var light := Color("524842").lerp(Color("356b2c"), g)
		var thorn := Color("9a8f86").lerp(Color("d6c39a"), g)
		draw_circle(Vector2(0, 2), radius * 1.05, Color(0, 0, 0, 0.25))
		for i in 7:
			var a := TAU * i / 7.0 + r.randf_range(-0.3, 0.3)
			draw_circle(Vector2.from_angle(a) * radius * 0.45 + Vector2(0, -radius * 0.25), radius * 0.55, body)
		draw_circle(Vector2(0, -radius * 0.35), radius * 0.55, light)
		for i in 18:
			var a := r.randf() * TAU
			var base := Vector2.from_angle(a) * radius * r.randf_range(0.55, 0.9) + Vector2(0, -radius * 0.25)
			draw_line(base, base + Vector2.from_angle(a) * radius * 0.32, thorn, 1.6)
		if g > 0.6:
			for i in 7:
				var p := Vector2.from_angle(r.randf() * TAU) * radius * r.randf_range(0.2, 0.8) + Vector2(0, -radius * 0.3)
				draw_circle(p, 2.6, Color("c8243a"))
				draw_circle(p + Vector2(-0.8, -0.8), 0.9, Color("ff8a8a"))


## Les fleurs d'un carré du monde, dessinées en coordonnées monde.
class FlowerChunk extends Node2D:
	var items: Array = []

	func _draw() -> void:
		for f in items:
			var p: Vector2 = f["pos"]
			var sz: float = f["size"]
			var n: int = f["petals"]
			for i in n:
				draw_circle(p + Vector2.from_angle(TAU * i / n) * sz, sz * 0.8, f["color"])
			draw_circle(p, sz * 0.6, Color("fff3c4"))


func _ready() -> void:
	if trees_parent == null:
		trees_parent = self
	rng.seed = 7
	for i in TREE_COUNT:
		var p := Vector2(rng.randf_range(-2900, 2900), rng.randf_range(-2900, 2900))
		if p.length() < 180.0:
			continue
		# Dans le roncier, l'arbre laisse la place à une ronce (même tirage, mêmes autres arbres).
		var t: DecorTree = DecorBramble.new() if Regions.weight(p, "ronce") > 0.5 else DecorTree.new()
		t.position = p
		t.size = rng.randf_range(0.8, 1.6)
		t.tree_seed = rng.randi()
		t.alive = ground.life_at(p) > ALIVE
		trees_parent.add_child(t)
		trees.append(t)
	_spawn_thicket()
	Game.seed_rng(rng, 1)
	ground.painted.connect(_on_painted)


## Ronces et buissons d'épines du roncier : tirage à part (graine fixe), pour ne pas déplacer
## les arbres du reste du monde. Le centre de la région et l'oasis restent libres d'obstacles.
func _spawn_thicket() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 8
	var mid := Regions.angle_of("ronce")
	var half := Regions.half_width()
	var center := Regions.center("ronce")
	var h := 2850.0
	for i in BRAMBLE_COUNT + BUSH_COUNT:
		var bush := i >= BRAMBLE_COUNT
		var a := mid + r.randf_range(-half, half) * 0.97
		var d := sqrt(r.randf_range(pow(Regions.INNER + 30.0, 2), pow(4000.0, 2)))
		var p := Vector2.from_angle(a) * d
		var sz := r.randf_range(0.8, 1.4)
		var sd := r.randi()
		if absf(p.x) > h or absf(p.y) > h or Regions.weight(p, "ronce") < 0.6:
			continue
		if bush and (p.distance_to(center) < BUSH_CLEAR_CENTER or p.length() < BUSH_CLEAR_SEED):
			continue
		var t: DecorTree = DecorBush.new() if bush else DecorBramble.new()
		t.position = p
		t.size = sz
		t.tree_seed = sd
		t.alive = ground.life_at(p) > ALIVE
		if bush:
			t.radius = 20.0 + 12.0 * (sz - 0.8) / 0.6
			bushes.append(t)
			var key := Vector2i(floori(p.x / BUSH_CELL), floori(p.y / BUSH_CELL))
			if not bush_cells.has(key):
				bush_cells[key] = []
			bush_cells[key].append(t)
			bush_bounds = Rect2(p, Vector2.ZERO) if bushes.size() == 1 else bush_bounds.expand(p)
		trees_parent.add_child(t)
		trees.append(t)


## Sort un cercle (centre, rayon) des buissons d'épines qu'il touche : renvoie la position corrigée
## (la même si rien ne gêne). Sert au joueur, aux ennemis et aux épines tirées.
func push_out(pos: Vector2, radius: float) -> Vector2:
	if bush_cells.is_empty() or not bush_bounds.grow(radius + 40.0).has_point(pos):
		return pos
	var cx := floori(pos.x / BUSH_CELL)
	var cy := floori(pos.y / BUSH_CELL)
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
	var r2 := (radius + 4.0) * (radius + 4.0)
	for t in trees:
		if t.alive or (radius < INF and t.position.distance_squared_to(center) > r2):
			continue
		if ground.life_at(t.position) > ALIVE:
			t.revive(radius < INF and ground.waves.size() > 0)


## Fleurs d'une vague de vie : elles éclosent quand le front de la vague les atteint.
func _physics_process(delta: float) -> void:
	clock += delta
	while not pending.is_empty() and pending[0]["at"] <= clock:
		_insert(pending.pop_front()["f"])


func _chunk_for(p: Vector2) -> FlowerChunk:
	var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
	if not chunks.has(key):
		var c := FlowerChunk.new()
		chunks[key] = c
		add_child(c)
	return chunks[key]


func add_flower(p: Vector2, color := Color(0, 0, 0, 0)) -> void:
	_insert(_make_flower(p, color))


func _make_flower(p: Vector2, color: Color) -> Dictionary:
	if color.a == 0.0:
		var palette := [Color("f48fb1"), Color("fff59d"), Color("b39ddb"), Color("ffffff"), Color("ffb74d")]
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
	for c in chunks.values():
		c.items = []
		c.queue_redraw()
	var start := maxi(0, list.size() - MAX_FLOWERS)
	for i in range(start, list.size()):
		var e = list[i]
		if not (e is Array) or e.size() < 5:
			continue
		_insert({"pos": Vector2(float(e[0]), float(e[1])), "color": Color.from_string(str(e[2]), Color.WHITE), "size": float(e[3]), "petals": int(e[4])})
