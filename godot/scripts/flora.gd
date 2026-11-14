## Décor : arbres morts qui reverdissent quand la vie revient, et fleurs qui éclosent.
extends Node2D

const MAX_FLOWERS := 900
const TREE_COUNT := 260

var ground
var trees: Array = []    # {pos, size, seed}
var flowers: Array = []  # {pos, color, size, petals}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 7
	for i in TREE_COUNT:
		var p := Vector2(rng.randf_range(-2900, 2900), rng.randf_range(-2900, 2900))
		if p.length() < 180.0:
			continue
		trees.append({"pos": p, "size": rng.randf_range(0.8, 1.6), "seed": rng.randi()})
	rng.randomize()
	ground.painted.connect(queue_redraw)


func add_flower(p: Vector2, color := Color(0, 0, 0, 0)) -> void:
	if color.a == 0.0:
		var palette := [Color("f48fb1"), Color("fff59d"), Color("b39ddb"), Color("ffffff"), Color("ffb74d")]
		color = palette[rng.randi() % palette.size()]
	flowers.append({"pos": p, "color": color, "size": rng.randf_range(2.5, 4.5), "petals": rng.randi_range(4, 6)})
	if flowers.size() > MAX_FLOWERS:
		flowers.pop_front()
	queue_redraw()


func spawn_patch(center: Vector2, radius: float, count: int, tint: Color) -> void:
	for i in count:
		var p := center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius
		var c := tint if rng.randf() < 0.4 else Color(0, 0, 0, 0)
		add_flower(p, c)


func _draw() -> void:
	for tree_data in trees:
		var p: Vector2 = tree_data["pos"]
		var s: float = tree_data["size"]
		var alive: bool = ground.life_at(p) > 0.45
		var trunk := Color("5a4636") if alive else Color("1e1a18")
		draw_line(p, p + Vector2(0, -34) * s, trunk, 6.0 * s)
		var r := RandomNumberGenerator.new()
		r.seed = tree_data["seed"]
		if alive:
			draw_circle(p + Vector2(0, -42) * s, 22.0 * s, Color("2f6b2a"))
			draw_circle(p + Vector2(-12, -34) * s, 15.0 * s, Color("3b7d31"))
			draw_circle(p + Vector2(12, -36) * s, 16.0 * s, Color("468f38"))
		else:
			for i in 4:
				var a := -PI / 2.0 + r.randf_range(-1.0, 1.0)
				var start := p + Vector2(0, -r.randf_range(14, 32)) * s
				draw_line(start, start + Vector2.from_angle(a) * r.randf_range(14, 26) * s, trunk, 3.5 * s)
	for f in flowers:
		var p: Vector2 = f["pos"]
		var sz: float = f["size"]
		var n: int = f["petals"]
		for i in n:
			draw_circle(p + Vector2.from_angle(TAU * i / n) * sz, sz * 0.8, f["color"])
		draw_circle(p, sz * 0.6, Color("fff3c4"))


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
	for e in list:
		if not (e is Array) or e.size() < 5:
			continue
		flowers.append({"pos": Vector2(float(e[0]), float(e[1])), "color": Color.from_string(str(e[2]), Color.WHITE), "size": float(e[3]), "petals": int(e[4])})
	if flowers.size() > MAX_FLOWERS:
		flowers = flowers.slice(flowers.size() - MAX_FLOWERS)
	queue_redraw()
