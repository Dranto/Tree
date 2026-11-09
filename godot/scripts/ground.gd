## Le sol du monde et sa carte de vie.
## Chaque texel de la carte dit à quel point la vie est revenue (0 = désolation, 1 = prairie).
extends Node2D

signal painted

const SIZE := 6000.0
const RES := 200

var img: Image
var tex: ImageTexture
var total := 0.0


func _ready() -> void:
	img = Image.create(RES, RES, false, Image.FORMAT_R8)
	img.fill(Color(0, 0, 0))
	tex = ImageTexture.create_from_image(img)
	var rect := ColorRect.new()
	rect.position = Vector2(-SIZE / 2.0, -SIZE / 2.0)
	rect.size = Vector2(SIZE, SIZE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	mat.set_shader_parameter("life_map", tex)
	mat.set_shader_parameter("world_size", Vector2(SIZE, SIZE))
	rect.material = mat
	add_child(rect)


func _to_map(p: Vector2) -> Vector2:
	return (p + Vector2(SIZE / 2.0, SIZE / 2.0)) / SIZE * RES


## Ajoute de la vie dans un disque (coordonnées monde).
func paint(world_pos: Vector2, radius: float, strength: float) -> void:
	var c := _to_map(world_pos)
	var r := radius / SIZE * RES
	for y in range(int(c.y - r) - 1, int(c.y + r) + 2):
		if y < 0 or y >= RES:
			continue
		for x in range(int(c.x - r) - 1, int(c.x + r) + 2):
			if x < 0 or x >= RES:
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / r
			if d >= 1.0:
				continue
			var old := img.get_pixel(x, y).r
			var nv := minf(1.0, old + strength * (1.0 - d * d))
			total += nv - old
			img.set_pixel(x, y, Color(nv, 0, 0))
	tex.update(img)
	painted.emit()


func life_at(world_pos: Vector2) -> float:
	var c := _to_map(world_pos)
	var x := clampi(int(c.x), 0, RES - 1)
	var y := clampi(int(c.y), 0, RES - 1)
	return img.get_pixel(x, y).r


## Part du monde ravivée, de 0 à 1.
func ratio() -> float:
	return total / float(RES * RES)
