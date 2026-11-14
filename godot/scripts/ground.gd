## Le sol du monde et sa carte de vie.
## Chaque texel de la carte dit à quel point la vie est revenue (0 = désolation, 1 = prairie).
extends Node2D

## Émis après chaque ajout de vie, avec la zone touchée (coordonnées monde).
## Un rayon infini veut dire « toute la carte » (chargement d'une sauvegarde).
signal painted(world_pos: Vector2, radius: float)

const SIZE := 6000.0
const RES := 200
## Texture de bruit du sol : calculée une fois sur le processeur, puis répétée.
## Une période couvre NOISE_PERIOD pixels du monde.
const NOISE_RES := 512
const NOISE_PERIOD := 3000.0

static var _noise_tex: ImageTexture

var img: Image
var tex: ImageTexture
## Copie des texels de la carte de vie (un octet par texel), lue et écrite directement.
var data := PackedByteArray()
## Somme des texels (0 à 255 chacun) : sert à la part du monde ravivée.
var total_bytes := 0
## Somme des valeurs de vie (0 à 1 par texel).
var total: float:
	get:
		return total_bytes / 255.0
## La texture n'est envoyée à la carte graphique qu'une fois par image, et seulement si elle a changé.
var dirty := false


func _ready() -> void:
	data.resize(RES * RES)
	data.fill(0)
	img = Image.create_from_data(RES, RES, false, Image.FORMAT_R8, data)
	tex = ImageTexture.create_from_image(img)
	var rect := ColorRect.new()
	rect.position = Vector2(-SIZE / 2.0, -SIZE / 2.0)
	rect.size = Vector2(SIZE, SIZE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	mat.set_shader_parameter("life_map", tex)
	mat.set_shader_parameter("world_size", Vector2(SIZE, SIZE))
	mat.set_shader_parameter("noise_tex", noise_texture())
	mat.set_shader_parameter("noise_period", NOISE_PERIOD)
	rect.material = mat
	add_child(rect)


## Bruit du sol, une couche par canal, qui se répète sans couture :
## R = grandes taches, G = taches fines, B = tracé des fissures, A = zones fissurées.
## Les tailles (en pixels du monde) reprennent celles de l'ancien bruit calculé dans le shader.
static func noise_texture() -> ImageTexture:
	if _noise_tex != null:
		return _noise_tex
	var layers := [
		{"scale": 260.0, "octaves": 4, "seed": 11},
		{"scale": 45.0, "octaves": 4, "seed": 23},
		{"scale": 55.0, "octaves": 1, "seed": 37},
		{"scale": 400.0, "octaves": 4, "seed": 51},
	]
	var channels: Array = []
	for l in layers:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
		n.seed = l["seed"]
		# Fréquence en « cases de bruit » par texel.
		n.frequency = NOISE_PERIOD / NOISE_RES / l["scale"]
		n.fractal_type = FastNoiseLite.FRACTAL_FBM if l["octaves"] > 1 else FastNoiseLite.FRACTAL_NONE
		n.fractal_octaves = l["octaves"]
		n.fractal_lacunarity = 2.0
		n.fractal_gain = 0.5
		var layer: Image = n.get_seamless_image(NOISE_RES, NOISE_RES, false, false, 0.1, true)
		layer.convert(Image.FORMAT_L8)
		channels.append(layer.get_data())
	var rgba := PackedByteArray()
	rgba.resize(NOISE_RES * NOISE_RES * 4)
	for i in NOISE_RES * NOISE_RES:
		rgba[i * 4] = channels[0][i]
		rgba[i * 4 + 1] = channels[1][i]
		rgba[i * 4 + 2] = channels[2][i]
		rgba[i * 4 + 3] = channels[3][i]
	_noise_tex = ImageTexture.create_from_image(Image.create_from_data(NOISE_RES, NOISE_RES, false, Image.FORMAT_RGBA8, rgba))
	return _noise_tex


func _process(_delta: float) -> void:
	if dirty:
		dirty = false
		img.set_data(RES, RES, false, Image.FORMAT_R8, data)
		tex.update(img)


func _to_map(p: Vector2) -> Vector2:
	return (p + Vector2(SIZE / 2.0, SIZE / 2.0)) / SIZE * RES


## Ajoute de la vie dans un disque (coordonnées monde). Ne touche que les texels du disque ;
## la texture est mise à jour une seule fois à la fin de l'image.
func paint(world_pos: Vector2, radius: float, strength: float) -> void:
	var c := _to_map(world_pos)
	var r := radius / SIZE * RES
	var add := strength * 255.0
	for y in range(maxi(0, int(c.y - r) - 1), mini(RES, int(c.y + r) + 2)):
		var dy := (y + 0.5 - c.y) / r
		for x in range(maxi(0, int(c.x - r) - 1), mini(RES, int(c.x + r) + 2)):
			var dx := (x + 0.5 - c.x) / r
			var d2 := dx * dx + dy * dy
			if d2 >= 1.0:
				continue
			var i := y * RES + x
			var old: int = data[i]
			var nv := mini(255, int(old + add * (1.0 - d2)))
			if nv != old:
				data[i] = nv
				total_bytes += nv - old
				dirty = true
	painted.emit(world_pos, radius)


func life_at(world_pos: Vector2) -> float:
	var c := _to_map(world_pos)
	var x := clampi(int(c.x), 0, RES - 1)
	var y := clampi(int(c.y), 0, RES - 1)
	return data[y * RES + x] / 255.0


## Part du monde ravivée, de 0 à 1.
func ratio() -> float:
	return total / float(RES * RES)


## Carte de vie encodée en PNG (pour la sauvegarde).
func export_map() -> PackedByteArray:
	return Image.create_from_data(RES, RES, false, Image.FORMAT_R8, data).save_png_to_buffer()


## Restaure une carte de vie sauvegardée, redimensionnée si la résolution a changé.
func import_map(png: PackedByteArray) -> bool:
	var loaded := Image.new()
	if loaded.load_png_from_buffer(png) != OK:
		return false
	loaded.convert(Image.FORMAT_R8)
	if loaded.get_width() != RES or loaded.get_height() != RES:
		loaded.resize(RES, RES, Image.INTERPOLATE_BILINEAR)
	data = loaded.get_data()
	total_bytes = 0
	for v in data:
		total_bytes += v
	dirty = true
	painted.emit(Vector2.ZERO, INF)
	return true
