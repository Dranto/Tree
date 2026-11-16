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
## Vague de vie : durée de l'avancée de l'herbe depuis le point ravivé (en secondes).
const WAVE_TIME := 1.75
const WAVE_TICK := 0.05

const Regions = preload("res://scripts/regions.gd")

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
## Vagues de vie en cours : {center, radius, add, t, done} (« done » = rayon déjà peint).
var waves: Array = []
var mat: ShaderMaterial


func _ready() -> void:
	data.resize(RES * RES)
	data.fill(0)
	img = Image.create_from_data(RES, RES, false, Image.FORMAT_R8, data)
	tex = ImageTexture.create_from_image(img)
	var rect := ColorRect.new()
	rect.position = Vector2(-SIZE / 2.0, -SIZE / 2.0)
	rect.size = Vector2(SIZE, SIZE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	mat.set_shader_parameter("life_map", tex)
	mat.set_shader_parameter("world_size", Vector2(SIZE, SIZE))
	mat.set_shader_parameter("noise_tex", noise_texture())
	mat.set_shader_parameter("noise_period", NOISE_PERIOD)
	# Région du roncier : secteur de la branche Ronce (sol teinté de rouille).
	var normals := Regions.edge_normals("ronce")
	mat.set_shader_parameter("ronce_n1", normals[0])
	mat.set_shader_parameter("ronce_n2", normals[1])
	mat.set_shader_parameter("region_inner", Regions.INNER)
	mat.set_shader_parameter("region_edge", Regions.EDGE)
	for k in PALETTE_SOL:
		var col: Color = palette()[k]
		mat.set_shader_parameter(k, Vector3(col.r, col.g, col.b))
	rect.material = mat
	add_child(rect)


## Couleurs du sol passées au shader, toutes tirées de la charte (Art) : le fond reste sourd.
const PALETTE_SOL := ["dead_dark", "dead_light", "crack_col", "pebble_col", "rust_dark", "rust_light",
	"calm_dark", "calm_light", "alive_dark", "alive_light", "moss_col", "thicket_dark", "thicket_light",
	"berry_col", "bloom_col"]

static func palette() -> Dictionary:
	var mort := Art.c("sol_mort")
	var vivant := Art.c("sol_vivant")
	var rouille := mort.lerp(Art.ec("cendre", "sombre"), 0.42)
	return {
		# Terre morte : deux tons proches (le sol bouge sans faire de bruit).
		"dead_dark": mort.darkened(0.14),
		"dead_light": mort.lightened(0.02),
		"crack_col": Art.c("decor").darkened(0.35),
		"pebble_col": mort.lightened(0.16),
		# Roncier : rouille tant que le Cœur vit ; apaisé (purifié), une terre brune et calme.
		"rust_dark": rouille.darkened(0.18),
		"rust_light": rouille.lightened(0.03),
		"calm_dark": mort.lerp(Art.ec("racine", "sombre"), 0.5).darkened(0.12),
		"calm_light": mort.lerp(Art.ec("racine"), 0.25),
		# Terre vivante : herbe, et liseré de mousse à la frontière de la vie.
		"alive_dark": vivant.lightened(0.02),
		"alive_light": vivant.lerp(Art.c("decor_vivant"), 0.7).lightened(0.2),
		"moss_col": Art.c("decor_vivant").lerp(Art.ec("racine", "clair"), 0.45),
		"thicket_dark": vivant.darkened(0.22),
		"thicket_light": vivant.lerp(Art.c("decor_vivant"), 0.6).lightened(0.08),
		"berry_col": Art.ec("saignement", "clair"),
		"bloom_col": Art.c("interactif"),
	}


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


## Les vagues de vie avancent à pas fixe : la vie du sol compte pour le jeu (soin, Flétris ralentis).
func _physics_process(delta: float) -> void:
	if waves.is_empty():
		return
	for w in waves:
		w["t"] += delta
		var k: float = minf(1.0, w["t"] / WAVE_TIME)
		# Le front avance par petits bonds (WAVE_TICK) : à l'œil c'est continu, et la carte,
		# la texture et le décor sont mis à jour trois fois moins souvent.
		if k < 1.0 and w["t"] - w.get("last", -1.0) < WAVE_TICK:
			continue
		w["last"] = w["t"]
		# Départ rapide puis ralenti, comme une eau qui se répand.
		_advance(w, w["radius"] * (1.0 - (1.0 - k) * (1.0 - k)))
	waves = waves.filter(func(w): return w["done"] < w["radius"])


## La région de Ronce a été purifiée (son Cœur) : la rouille du sol s'efface.
func set_purified(value: float) -> void:
	mat.set_shader_parameter("ronce_purified", value)


func _to_map(p: Vector2) -> Vector2:
	return (p + Vector2(SIZE / 2.0, SIZE / 2.0)) / SIZE * RES


## Ajoute de la vie dans un disque (coordonnées monde). Ne touche que les texels du disque ;
## la texture est mise à jour une seule fois à la fin de l'image.
func paint(world_pos: Vector2, radius: float, strength: float) -> void:
	_paint_ring(world_pos, radius, strength, -1.0, radius)
	painted.emit(world_pos, radius)


## Vague de vie : le même apport que paint(), mais l'herbe avance du centre vers le bord
## en WAVE_TIME secondes. Les arbres et ronces reverdissent quand la vague les atteint.
func paint_wave(world_pos: Vector2, radius: float, strength: float) -> void:
	waves.append({"center": world_pos, "radius": radius, "add": strength, "t": 0.0, "done": -1.0})


## Termine tout de suite les vagues en cours (avant une sauvegarde ou une capture de la carte).
func finish_waves() -> void:
	for w in waves:
		_advance(w, w["radius"])
	waves = []


func _advance(w: Dictionary, r_now: float) -> void:
	if r_now <= w["done"]:
		return
	_paint_ring(w["center"], w["radius"], w["add"], w["done"], r_now)
	w["done"] = r_now if r_now < w["radius"] else w["radius"]
	painted.emit(w["center"], r_now)


## Ajoute la vie du disque (centre, rayon) mais seulement entre les distances r_in (exclue)
## et r_out (incluse) : une vague peint son disque anneau par anneau, sans compter deux fois.
func _paint_ring(world_pos: Vector2, radius: float, strength: float, r_in: float, r_out: float) -> void:
	var c := _to_map(world_pos)
	var r := radius / SIZE * RES
	var add := strength * 255.0
	var in2: float = (r_in / radius) * absf(r_in / radius) if r_in > 0.0 else -1.0
	var out2: float = minf(1.0, (r_out / radius) * (r_out / radius))
	var ro := r * sqrt(out2)
	for y in range(maxi(0, int(c.y - ro) - 1), mini(RES, int(c.y + ro) + 2)):
		var dy := (y + 0.5 - c.y) / r
		for x in range(maxi(0, int(c.x - ro) - 1), mini(RES, int(c.x + ro) + 2)):
			var dx := (x + 0.5 - c.x) / r
			var d2 := dx * dx + dy * dy
			if d2 >= 1.0 or d2 <= in2 or d2 > out2:
				continue
			var i := y * RES + x
			var old: int = data[i]
			var nv := mini(255, int(old + add * (1.0 - d2)))
			if nv != old:
				data[i] = nv
				total_bytes += nv - old
				dirty = true


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
	finish_waves()
	return Image.create_from_data(RES, RES, false, Image.FORMAT_R8, data).save_png_to_buffer()


## Restaure une carte de vie sauvegardée, redimensionnée si la résolution a changé.
func import_map(png: PackedByteArray) -> bool:
	var loaded := Image.new()
	if loaded.load_png_from_buffer(png) != OK:
		return false
	waves = []
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
