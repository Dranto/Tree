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
## Rectangle de la carte de vie (en texels) changé depuis le dernier envoi : ses carrés de sol en
## cache sont à redessiner. Vide : rien n'a changé.
var _dirty_rect := Rect2i()
var _rect: ColorRect
## Régions passées au shader (dans l'ordre de ses tableaux) et leur état purifié (0 ou 1).
var _region_ids: Array = []
var _purified := PackedFloat32Array()

## --- Sol en cache (docs/performances.md) ---
## Le shader du sol coûtait ~9 ms par image en rendu logiciel : il est maintenant dessiné une fois
## par carré de TILE_PX pixels d'écran dans une texture (SubViewport), et chaque image ne fait que
## recopier les carrés visibles. Un carré est redessiné quand la vie change sous lui (vague, peinture,
## chargement), quand la rouille s'efface, ou quand l'échelle de l'écran change.
## Écart avec le calcul direct : moins d'un pixel (la grille des carrés suit le monde, pas l'écran).
const TILE_PX := 512
## Carrés gardés en plus de ceux visibles (les plus anciens hors écran sont libérés au-delà).
const TILE_SPARE := 12
## Marge autour de la vue (pixels du monde) où les carrés sont déjà prêts.
const TILE_MARGIN := 96.0
## Vrai : sol en cache (le jeu) ; faux : shader dessiné directement à chaque image (comparaison).
var cached := true
## Carrés en cache : Vector2i -> {vp: SubViewport, sprite: Sprite2D, used: int}.
var _tiles: Dictionary = {}
## Échelle de l'écran (pixels par pixel du monde) des carrés en cache.
var _tile_scale := 0.0
var _frame := 0


func _ready() -> void:
	data.resize(RES * RES)
	data.fill(0)
	img = Image.create_from_data(RES, RES, false, Image.FORMAT_R8, data)
	tex = ImageTexture.create_from_image(img)
	var rect := _make_rect()
	_rect = rect
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	mat.set_shader_parameter("life_map", tex)
	mat.set_shader_parameter("world_size", Vector2(SIZE, SIZE))
	mat.set_shader_parameter("noise_tex", noise_texture())
	mat.set_shader_parameter("noise_period", NOISE_PERIOD)
	mat.set_shader_parameter("region_inner", Regions.INNER)
	mat.set_shader_parameter("region_edge", Regions.EDGE)
	var pal := palette()
	for k in PALETTE_SOL:
		var col: Color = pal[k]
		mat.set_shader_parameter(k, Vector3(col.r, col.g, col.b))
	_set_regions()
	rect.material = mat
	add_child(rect)
	if "--sol-direct" in OS.get_cmdline_user_args():
		cached = false


## Le monde entier, couvert par le shader du sol.
static func _make_rect() -> ColorRect:
	var rect := ColorRect.new()
	rect.position = Vector2(-SIZE / 2.0, -SIZE / 2.0)
	rect.size = Vector2(SIZE, SIZE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Couleurs du sol passées au shader, toutes tirées de la charte (Art) : le fond reste sourd.
## Celles de chaque région viennent de son fichier (data/regions/<id>.json, « ground »).
const PALETTE_SOL := ["dead_dark", "dead_light", "crack_col", "pebble_col", "alive_dark", "alive_light",
	"moss_col", "bloom_col"]

static func palette() -> Dictionary:
	var mort := Art.c("sol_mort")
	var vivant := Art.c("sol_vivant")
	return {
		# Terre morte : deux tons proches (le sol bouge sans faire de bruit).
		"dead_dark": mort.darkened(0.14),
		"dead_light": mort.lightened(0.02),
		"crack_col": Art.c("decor").darkened(0.35),
		"pebble_col": mort.lightened(0.16),
		# Terre vivante : herbe, et liseré de mousse à la frontière de la vie.
		"alive_dark": vivant.lightened(0.02),
		"alive_light": vivant.lerp(Art.c("decor_vivant"), 0.7).lightened(0.2),
		"moss_col": Art.c("decor_vivant").lerp(Art.ec("racine", "clair"), 0.45),
		"bloom_col": Art.c("interactif"),
	}


## Palette du sol d'une région, lue dans son fichier : couleurs de la terre morte (« dead »), apaisée
## (« purified »), de l'herbe (« alive ») et des points sur l'herbe (« dot »), plus leurs réglages.
static func region_palette(id: String) -> Dictionary:
	var g := Regions.section(id, "ground")
	var named := Regions.named_colors(g)
	var out := {}
	for k in REGION_COLORS:
		out[k] = Regions.color(g.get(k, "sol_mort"), named)
	var salt: Array = g.get("dot_salt", [0.0, 0.0])
	out["dot_params"] = Vector4(float(g.get("dot_cell", 16.0)), float(g.get("dot_rarity", 1.0)), float(g.get("dot_size", 0.18)), float(g.get("dot_strength", 0.0)))
	out["dot_salt"] = Vector2(float(salt[0]), float(salt[1]))
	out["alive_mix"] = Vector2(float(g.get("alive_mix", 0.85)), float(g.get("alive_mix_purified", 0.35)))
	return out

## Couleurs obligatoires de « ground » dans le fichier d'une région.
const REGION_COLORS := ["dead_dark", "dead_light", "purified_dark", "purified_light", "alive_dark", "alive_light", "dot"]
## Nom de chaque couleur de région dans le shader.
const REGION_UNIFORMS := {"dead_dark": "region_dead_dark", "dead_light": "region_dead_light",
	"purified_dark": "region_calm_dark", "purified_light": "region_calm_light", "alive_dark": "region_alive_dark",
	"alive_light": "region_alive_light", "dot": "region_dot_col"}


## Passe au shader le secteur, la palette et l'état purifié de chaque région.
func _set_regions() -> void:
	var ids := Regions.ids().slice(0, Regions.MAX_REGIONS)
	_region_ids = ids
	var n1 := PackedVector2Array()
	var n2 := PackedVector2Array()
	var cols := {}
	for k in REGION_UNIFORMS:
		cols[k] = PackedVector3Array()
	# vec4 en tableau : passé comme couleurs (quatre nombres).
	var dots := PackedColorArray()
	var salts := PackedVector2Array()
	var mixes := PackedVector2Array()
	for id in ids:
		var normals := Regions.edge_normals(id)
		n1.append(normals[0])
		n2.append(normals[1])
		var pal := region_palette(id)
		for k in REGION_UNIFORMS:
			var c: Color = pal[k]
			cols[k].append(Vector3(c.r, c.g, c.b))
		var d: Vector4 = pal["dot_params"]
		dots.append(Color(d.x, d.y, d.z, d.w))
		salts.append(pal["dot_salt"])
		mixes.append(pal["alive_mix"])
	mat.set_shader_parameter("region_count", ids.size())
	mat.set_shader_parameter("region_n1", n1)
	mat.set_shader_parameter("region_n2", n2)
	for k in REGION_UNIFORMS:
		mat.set_shader_parameter(REGION_UNIFORMS[k], cols[k])
	mat.set_shader_parameter("region_dot", dots)
	mat.set_shader_parameter("region_dot_salt", salts)
	mat.set_shader_parameter("region_alive_mix", mixes)
	_purified.resize(ids.size())
	_purified.fill(0.0)
	mat.set_shader_parameter("region_purified", _purified)


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
		if _dirty_rect.has_area():
			# Un texel de marge : le shader lit la carte en filtrage linéaire.
			var k := SIZE / RES
			var r := _dirty_rect.grow(1)
			_invalidate(Rect2(Vector2(r.position) * k - Vector2(SIZE, SIZE) / 2.0, Vector2(r.size) * k))
			_dirty_rect = Rect2i()
	_update_tiles()


# --- Carrés de sol en cache ---

## Rend les carrés visibles, libère les plus anciens hors de l'écran.
func _update_tiles() -> void:
	_rect.visible = not cached
	if not cached or not is_visible_in_tree():
		return
	_frame += 1
	var vp := get_viewport()
	var xf := vp.get_final_transform() * get_canvas_transform()
	var s := xf.get_scale().x
	if s <= 0.0:
		return
	if not is_equal_approx(s, _tile_scale):
		_clear_tiles()
		_tile_scale = s
	var world := TILE_PX / s
	# Marge : la caméra (lissage, secousse) bouge encore après ce calcul, dans la même image.
	var view := (xf.affine_inverse() * Rect2(Vector2.ZERO, vp.get_visible_rect().size * vp.get_final_transform().get_scale())).grow(TILE_MARGIN)
	var lo := Vector2i(floori(view.position.x / world), floori(view.position.y / world))
	var hi := Vector2i(floori(view.end.x / world), floori(view.end.y / world))
	for ty in range(lo.y, hi.y + 1):
		for tx in range(lo.x, hi.x + 1):
			var key := Vector2i(tx, ty)
			if not _tiles.has(key):
				_tiles[key] = _make_tile(key, world)
			_tiles[key]["used"] = _frame
	var keep := (hi.x - lo.x + 1) * (hi.y - lo.y + 1) + TILE_SPARE
	if _tiles.size() > keep:
		var old := _tiles.keys()
		old.sort_custom(func(a, b): return _tiles[a]["used"] < _tiles[b]["used"])
		for i in _tiles.size() - keep:
			_free_tile(old[i])


## Un carré : le shader du sol dessiné une fois dans une texture, montrée par un sprite posé au même
## endroit du monde (un pixel de texture par pixel d'écran).
func _make_tile(key: Vector2i, world: float) -> Dictionary:
	var origin := Vector2(key) * world
	var vp := SubViewport.new()
	vp.size = Vector2i(TILE_PX, TILE_PX)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := _make_rect()
	rect.material = mat
	vp.add_child(rect)
	add_child(vp)
	# Après l'entrée dans l'arbre : le canevas du SubViewport n'existe qu'à ce moment.
	vp.canvas_transform = Transform2D(0.0, Vector2(_tile_scale, _tile_scale), 0.0, -origin * _tile_scale)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.position = origin
	sprite.scale = Vector2(world, world) / TILE_PX
	sprite.texture = vp.get_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	return {"vp": vp, "sprite": sprite, "used": _frame, "rect": Rect2(origin, Vector2(world, world))}


func _free_tile(key: Vector2i) -> void:
	var t: Dictionary = _tiles[key]
	t["sprite"].queue_free()
	t["vp"].queue_free()
	_tiles.erase(key)


func _clear_tiles() -> void:
	for key in _tiles.keys():
		_free_tile(key)


## Redessine les carrés qui touchent ce rectangle du monde (tous s'il est infini).
func _invalidate(area: Rect2) -> void:
	for t in _tiles.values():
		if not area.is_finite() or (t["rect"] as Rect2).intersects(area):
			t["vp"].render_target_update_mode = SubViewport.UPDATE_ONCE


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


## Le Cœur d'une région a été purifié : la terre morte de la région s'apaise.
func set_purified(region: String, value: float) -> void:
	var i := _region_ids.find(region)
	if i < 0 or _purified[i] == value:
		return
	_purified[i] = value
	mat.set_shader_parameter("region_purified", _purified)
	_invalidate(Rect2(-Vector2.INF, Vector2.INF))


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
				_dirty_rect = Rect2i(x, y, 1, 1) if not _dirty_rect.has_area() else _dirty_rect.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))


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
	_dirty_rect = Rect2i(0, 0, RES, RES)
	total_bytes = 0
	for v in data:
		total_bytes += v
	dirty = true
	painted.emit(Vector2.ZERO, INF)
	return true
