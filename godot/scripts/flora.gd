## Décor : arbres morts qui reverdissent quand la vie revient, et fleurs qui éclosent.
##
## Performance : rien n'est redessiné en bloc. Les fleurs sont rangées par carrés de
## CHUNK pixels, et une nouvelle fleur ne redessine que son carré. Chaque arbre est son
## propre nœud, redessiné seulement quand il reverdit. Godot ne dessine que ce qui est à l'écran.
## Les arbres sont triés en profondeur (Y-sort) avec les personnages : il suffit de les placer
## dans le même calque trié (« trees_parent »).
extends Node2D

const MAX_FLOWERS := 900
const TREE_COUNT := 260
const CHUNK := 512.0
const ALIVE := 0.45

var ground
## Calque trié en profondeur où ranger les arbres (par défaut : ce nœud).
var trees_parent: Node2D
var trees: Array = []    # nœuds DecorTree
var flowers: Array = []  # {pos, color, size, petals, chunk}
var chunks: Dictionary = {}  # Vector2i -> FlowerChunk
var rng := RandomNumberGenerator.new()


## Un arbre du décor, dessiné autour de son pied (l'origine sert au tri en profondeur).
class DecorTree extends Node2D:
	var size := 1.0
	var tree_seed := 0
	var alive := false

	func _draw() -> void:
		var s := size
		var trunk := Color("5a4636") if alive else Color("1e1a18")
		draw_line(Vector2.ZERO, Vector2(0, -34) * s, trunk, 6.0 * s)
		if alive:
			draw_circle(Vector2(0, -42) * s, 22.0 * s, Color("2f6b2a"))
			draw_circle(Vector2(-12, -34) * s, 15.0 * s, Color("3b7d31"))
			draw_circle(Vector2(12, -36) * s, 16.0 * s, Color("468f38"))
		else:
			var r := RandomNumberGenerator.new()
			r.seed = tree_seed
			for i in 4:
				var a := -PI / 2.0 + r.randf_range(-1.0, 1.0)
				var start := Vector2(0, -r.randf_range(14, 32)) * s
				draw_line(start, start + Vector2.from_angle(a) * r.randf_range(14, 26) * s, trunk, 3.5 * s)


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
		var t := DecorTree.new()
		t.position = p
		t.size = rng.randf_range(0.8, 1.6)
		t.tree_seed = rng.randi()
		t.alive = ground.life_at(p) > ALIVE
		trees_parent.add_child(t)
		trees.append(t)
	Game.seed_rng(rng, 1)
	ground.painted.connect(_on_painted)


## La vie a changé dans un disque : seuls les arbres concernés qui reverdissent sont redessinés.
func _on_painted(center: Vector2, radius: float) -> void:
	var r2 := (radius + 4.0) * (radius + 4.0)
	for t in trees:
		if t.alive or (radius < INF and t.position.distance_squared_to(center) > r2):
			continue
		if ground.life_at(t.position) > ALIVE:
			t.alive = true
			t.queue_redraw()


func _chunk_for(p: Vector2) -> FlowerChunk:
	var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
	if not chunks.has(key):
		var c := FlowerChunk.new()
		chunks[key] = c
		add_child(c)
	return chunks[key]


func add_flower(p: Vector2, color := Color(0, 0, 0, 0)) -> void:
	if color.a == 0.0:
		var palette := [Color("f48fb1"), Color("fff59d"), Color("b39ddb"), Color("ffffff"), Color("ffb74d")]
		color = palette[rng.randi() % palette.size()]
	_insert({"pos": p, "color": color, "size": rng.randf_range(2.5, 4.5), "petals": rng.randi_range(4, 6)})


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


func spawn_patch(center: Vector2, radius: float, count: int, tint: Color) -> void:
	for i in count:
		var p := center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius
		var c := tint if rng.randf() < 0.4 else Color(0, 0, 0, 0)
		add_flower(p, c)


## Fleurs sous forme de listes simples [x, y, couleur, taille, pétales] (pour la sauvegarde).
func export_flowers() -> Array:
	var out: Array = []
	for f in flowers:
		var p: Vector2 = f["pos"]
		var c: Color = f["color"]
		out.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1), c.to_html(false), snappedf(f["size"], 0.01), f["petals"]])
	return out


func import_flowers(list: Array) -> void:
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
