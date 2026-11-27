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
## Vie du bord de vie : la terre est ravivée au-delà (front net du shader, éléments du calque).
const FRONT := 0.45

const Regions = preload("res://scripts/regions.gd")
## Sol en trois couches (refonte du monde « Paysages d'herbier », vague 1 S) : matière, détails et
## pousses du bord de vie dessinés une fois par carré de sol en cache.
const GroundLayers = preload("res://scripts/world_bake/ground_layers.gd")
const LieuxBake = preload("res://scripts/world_bake/lieux_bake.gd")
const Frontieres = preload("res://scripts/world_art/frontieres.gd")

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
## Carrés à refaire au plus par image (0 : tous tout de suite, pour les captures et les tests).
## Refaire un carré coûte ~1 ms en rendu logiciel : une mort en salit 1 à 4, la purification d'un
## Cœur tous. Les autres attendent les images suivantes, les plus proches du centre de l'écran
## d'abord (main.gd le règle à TILE_BUDGET en jeu et dans le banc).
var tile_budget := 0
const TILE_BUDGET := 2
## Carrés en cache : Vector2i -> {vp: SubViewport, sprite: Sprite2D, used: int}.
var _tiles: Dictionary = {}
## Échelle de l'écran (pixels par pixel du monde) des carrés en cache.
var _tile_scale := 0.0
var _frame := 0
## Matériau des carrés : recopie opaque, sans mélange (voir shaders/ground_tile.gdshader).
var _tile_mat: ShaderMaterial
## Taille des carrés (pixels d'écran) : TILE_PX, ou « --sol-tile=N » (mesures du prototype P).
var tile_px := TILE_PX
## Chaque carré reçoit un calque dessiné (world_bake/ground_layers.gd) : toujours vrai en jeu.
var layered := true
## Matériau des calques (shaders/ground_layer.gdshader), partagé par tous les carrés.
var layer_mat: ShaderMaterial
## Mesures : carrés construits (nouveaux) et refaits (vie changée) depuis le début.
var tiles_built := 0
var tiles_redrawn := 0


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
	# Frontières entre régions (vague 3 B) : bande d'îlots, mêmes constantes que world_art/frontieres.gd.
	mat.set_shader_parameter("border_half", Frontieres.HALF)
	mat.set_shader_parameter("border_inner", Frontieres.HALF_INNER)
	mat.set_shader_parameter("border_amp", Frontieres.AMP)
	mat.set_shader_parameter("border_scale", Frontieres.NOISE_SCALE)
	mat.set_shader_parameter("border_offset", Frontieres.NOISE_OFFSET)
	mat.set_shader_parameter("front", FRONT)
	var pal := palette()
	for k in PALETTE_SOL:
		var col: Color = pal[k]
		mat.set_shader_parameter(k, Vector3(col.r, col.g, col.b))
	_set_regions()
	rect.material = mat
	add_child(rect)
	if "--sol-direct" in OS.get_cmdline_user_args():
		cached = false
	GroundLayers.configure()
	GroundLayers.clear_cache()
	if GroundLayers.tile_px > 0:
		tile_px = GroundLayers.tile_px
	if "--sol-sans-calque" in OS.get_cmdline_user_args():
		layered = false
	layer_mat = GroundLayers.material(self)
	layer_mat.set_shader_parameter("region_purified", _purified)


## Le monde entier, couvert par le shader du sol.
static func _make_rect() -> ColorRect:
	var rect := ColorRect.new()
	rect.position = Vector2(-SIZE / 2.0, -SIZE / 2.0)
	rect.size = Vector2(SIZE, SIZE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Couleurs du sol de l'oasis (et hors des régions) passées au shader, tirées de la charte (Art) :
## trois tons de terre morte, trois d'herbe, et la sève du liseré du bord de vie.
const PALETTE_SOL := ["dead_dark", "dead_mid", "dead_light", "alive_dark", "alive_mid", "alive_light", "seve_col"]

static func palette() -> Dictionary:
	var p := GroundLayers.world_palette("")
	return {
		"dead_dark": p["fletri"]["sol_sombre"], "dead_mid": p["fletri"]["sol"], "dead_light": p["fletri"]["sol_clair"],
		"alive_dark": p["ravive"]["sol_sombre"], "alive_mid": p["ravive"]["sol"], "alive_light": p["ravive"]["sol_clair"],
		"seve_col": Art.mc("commun", "", "seve"),
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


## Tons du lavis (sombre, moyen, clair) dans le shader, dans l'ordre de ses tableaux.
const LAVIS_TONS := ["sol_sombre", "sol", "sol_clair"]
const LAVIS_DEAD := ["region_dead_dark", "region_dead_mid", "region_dead_light"]
const LAVIS_ALIVE := ["region_alive_dark", "region_alive_mid", "region_alive_light"]
## Palette du monde de chaque région (GroundLayers.world_palette), dans l'ordre du shader.
var _region_pals: Array = []


## Passe au shader le secteur et les tons de chaque région.
func _set_regions() -> void:
	var ids := Regions.ids().slice(0, Regions.MAX_REGIONS)
	_region_ids = ids
	_region_pals = []
	var n1 := PackedVector2Array()
	var n2 := PackedVector2Array()
	for id in ids:
		var normals := Regions.edge_normals(id)
		n1.append(normals[0])
		n2.append(normals[1])
		_region_pals.append(GroundLayers.world_palette(id))
	mat.set_shader_parameter("region_count", ids.size())
	mat.set_shader_parameter("region_n1", n1)
	mat.set_shader_parameter("region_n2", n2)
	for t in 3:
		var alive := PackedVector3Array()
		for pal in _region_pals:
			var c: Color = pal["ravive"][LAVIS_TONS[t]]
			alive.append(Vector3(c.r, c.g, c.b))
		mat.set_shader_parameter(LAVIS_ALIVE[t], alive)
	_purified.resize(ids.size())
	_purified.fill(0.0)
	_set_dead_tones()


## Tons de la terre morte de chaque région : flétri, apaisé d'un cran par Cœur purifié.
func _set_dead_tones() -> void:
	for t in 3:
		var dead := PackedVector3Array()
		for i in _region_pals.size():
			var pal: Dictionary = _region_pals[i]
			var c: Color = (pal["fletri"][LAVIS_TONS[t]] as Color).lerp(pal["apaise"][LAVIS_TONS[t]], _purified[i])
			dead.append(Vector3(c.r, c.g, c.b))
		mat.set_shader_parameter(LAVIS_DEAD[t], dead)


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
	if not _floor_dirty.is_empty():
		for area in _floor_dirty:
			_invalidate(area)
		_floor_dirty.clear()
	var vp := get_viewport()
	var xf := vp.get_final_transform() * get_canvas_transform()
	var s := xf.get_scale().x
	if s <= 0.0:
		return
	if not is_equal_approx(s, _tile_scale):
		_clear_tiles()
		_tile_scale = s
	var world := tile_px / s
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
	_refresh_dirty(view.get_center())
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
	vp.size = Vector2i(tile_px, tile_px)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := _make_rect()
	rect.material = mat
	vp.add_child(rect)
	var layer: Node2D = null
	var af: Node2D = null
	if layered:
		layer = GroundLayers.make(self, Rect2(origin, Vector2(world, world)), layer_mat)
		vp.add_child(layer)
	# Sols des arènes (boss_arena.gd) : posés dans le carré par-dessus le sol et son calque.
	if not floor_hosts.is_empty():
		af = FloorOverlay.new()
		af.ground = self
		af.rect = Rect2(origin, Vector2(world, world))
		af.material = LieuxBake.material()
		af.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		vp.add_child(af)
	add_child(vp)
	tiles_built += 1
	# Après l'entrée dans l'arbre : le canevas du SubViewport n'existe qu'à ce moment.
	vp.canvas_transform = Transform2D(0.0, Vector2(_tile_scale, _tile_scale), 0.0, -origin * _tile_scale)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.position = origin
	sprite.scale = Vector2(world, world) / tile_px
	sprite.texture = vp.get_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _tile_mat == null:
		_tile_mat = ShaderMaterial.new()
		_tile_mat.shader = preload("res://shaders/ground_tile.gdshader")
	sprite.material = _tile_mat
	add_child(sprite)
	return {"vp": vp, "sprite": sprite, "used": _frame, "rect": Rect2(origin, Vector2(world, world)), "layer": layer, "floor": af}


## --- Sols des arènes dans les carrés en cache ---
## Le sol d'une arène (une grande image douce, voir boss_arena.gd › _keep_floor_baked) était un calque
## de plus par-dessus le sol, rempli à chaque image sur la moitié de l'écran (~2,5 ms en rendu logiciel).
## Il est maintenant dessiné une fois dans les carrés du sol qu'il touche, par-dessus leur calque : ce
## que l'écran montrait (sol, puis sol de l'arène) est fait une fois par carré au lieu d'une fois par image.
## Une arène s'inscrit avec add_floor_host et demande refresh_area quand son sol change.
var floor_hosts: Array = []


class FloorOverlay extends Node2D:
	var ground
	var rect: Rect2

	func _draw() -> void:
		for a in ground.floor_hosts:
			if is_instance_valid(a):
				a.draw_floor_in(self, rect)


## Vrai : le sol des arènes peut être porté par les carrés en cache.
func hosts_floors() -> bool:
	return cached


func add_floor_host(arena) -> void:
	if floor_hosts.has(arena):
		return
	floor_hosts.append(arena)
	# Les carrés déjà faits n'ont pas de calque pour les sols : ils sont refaits.
	_clear_tiles()


## Les carrés qui touchent « area » (monde) sont refaits (au rythme de tile_budget en jeu). Le calque
## des sols est redessiné tout de suite, le carré rendu à partir de l'image suivante : en Godot 4.7, un
## rendu demandé dans l'image même d'un changement montre encore l'état d'avant (docs/performances.md).
var _floor_dirty: Array = []


func refresh_area(area: Rect2) -> void:
	for t in _tiles.values():
		if t.get("floor") != null and (t["rect"] as Rect2).intersects(area):
			t["floor"].queue_redraw()
	_floor_dirty.append(area)


func _free_tile(key: Vector2i) -> void:
	var t: Dictionary = _tiles[key]
	t["sprite"].queue_free()
	t["vp"].queue_free()
	_tiles.erase(key)


func _clear_tiles() -> void:
	for key in _tiles.keys():
		_free_tile(key)


## Redessine les carrés qui touchent ce rectangle du monde (tous s'il est infini) : tout de suite,
## ou dans la limite de tile_budget par image (voir _refresh_dirty).
func _invalidate(area: Rect2) -> void:
	for t in _tiles.values():
		if not area.is_finite() or (t["rect"] as Rect2).intersects(area):
			if tile_budget > 0:
				t["dirty"] = true
			else:
				_rerender(t)


## Relance le rendu d'un carré. Depuis Godot 4.7, remettre UPDATE_ONCE sur une image qui l'a déjà
## ne relance rien : on repasse d'abord par UPDATE_DISABLED.
func _render_once(vp: SubViewport) -> void:
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Refait le rendu d'un carré (la vie a changé sous lui). Son calque n'est pas redessiné : le shader
## du calque relit la vie. Seule exception : un carré tout mort reçoit pour la première fois de la vie,
## il tire alors aussi les éléments ravivés et les pousses du front (une fois).
func _rerender(t: Dictionary) -> void:
	tiles_redrawn += 1
	var layer = t["layer"]
	if layer != null and layer.mask != GroundLayers.DEAD | GroundLayers.ALIVE | GroundLayers.FRONT:
		var m: int = GroundLayers.needs(self, t["rect"])
		if m & ~layer.mask:
			layer.mask |= m
			layer.queue_redraw()
	_render_once(t["vp"])


## Refait au plus tile_budget carrés salis, les plus proches de « center » d'abord.
func _refresh_dirty(center: Vector2) -> void:
	if tile_budget <= 0:
		return
	var dirty_tiles: Array = []
	for t in _tiles.values():
		if t.get("dirty", false):
			dirty_tiles.append(t)
	if dirty_tiles.is_empty():
		return
	dirty_tiles.sort_custom(func(a, b): return (a["rect"] as Rect2).get_center().distance_squared_to(center) < (b["rect"] as Rect2).get_center().distance_squared_to(center))
	for i in mini(tile_budget, dirty_tiles.size()):
		dirty_tiles[i]["dirty"] = false
		_rerender(dirty_tiles[i])


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
## Purification affichée d'une région (0 → 1), 0 si elle n'existe pas.
func purified_of(region: String) -> float:
	var i := _region_ids.find(region)
	return _purified[i] if i >= 0 else 0.0


func set_purified(region: String, value: float) -> void:
	var i := _region_ids.find(region)
	if i < 0 or _purified[i] == value:
		return
	_purified[i] = value
	_set_dead_tones()
	layer_mat.set_shader_parameter("region_purified", _purified)
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
	# Hors de la carte (l'arène de la finale, sous la graine) : pas de terre vivante.
	if c.x < -1.0 or c.y < -1.0 or c.x > RES or c.y > RES:
		return 0.0
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
	# La vie peut baisser (autre sauvegarde) : chaque calque refait son masque et son dessin.
	for t in _tiles.values():
		if t["layer"] != null:
			t["layer"].mask = GroundLayers.needs(self, t["rect"])
			t["layer"].queue_redraw()
	painted.emit(Vector2.ZERO, INF)
	return true
