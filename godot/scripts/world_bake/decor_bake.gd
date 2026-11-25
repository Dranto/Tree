## Décor cuit (prototype technique, refonte du monde « Paysages d'herbier », vague 0 P).
##
## Réglage interne, éteint par défaut (« -- --paysage-decor ») : au chargement, les arbres, ronces,
## buissons d'épines et points de repère de flora.gd sont dessinés une fois par le code, à ×scale et
## lissés (suréchantillonnés ss fois dans un SubViewport, réduits, mipmaps), dans un seul atlas pour
## tout le décor. En jeu, chaque élément du décor n'envoie plus qu'un quadrilatère texturé au lieu de
## son lot de triangles ; un seul atlas et un seul matériau : les éléments voisins dans le tri en
## profondeur partent dans le même appel de rendu.
##
## Même méthode que la cuisson des Flétris (sprite_bake.gd, PR #125) : SubViewport suréchantillonné,
## réduction trilinéaire, mipmaps, alpha prémultiplié. Son API n'est pas reprise telle quelle : sa
## fonction bake() est propre aux Flétris (FletriArt.draw et leurs poses) et son Painter ne rejoue que
## des lots de triangles, alors que les repères du décor tracent aussi des contours à part
## (Art.outline sur le nœud). Ici, chaque élément se dessine lui-même dans l'atlas (copie locale).
##
## Variantes : chaque sorte est cuite en `variants` tirages (le tirage d'un élément choisit sa
## variante), par paliers de taille (un grand arbre de premier plan n'est pas un petit arbre agrandi),
## mort et vivant. La pousse des feuilles (vague de vie, 1,1 s) reste dessinée en direct, puis
## l'élément repasse à l'image cuite. Les points de repère (un tirage fixe) sont cuits tels quels.
##
## Aucun texte visible, aucun chiffre de jeu, aucune collision : apparence seulement.
extends RefCounted

const Flora = preload("res://scripts/flora.gd")

## Réglage interne : « --paysage-decor » (cuit), « --paysage-decor=direct » (composition dessinée
## en direct, pour la comparaison).
static var enabled := false
static var baked := true
## Résolution de cuisson (pixels de l'atlas par pixel du monde), « --decor-cuisson=S ».
static var scale := 2.0
static var ss := 2
static var variants := 6
const PAD := 3
## Largeur de l'atlas (pixels).
const ATLAS_W := 2048

static var tex: ImageTexture
## Clé -> [src (Rect2, pixels de l'atlas), ancre (pied de l'élément dans sa case), taille cuite]
static var cells := {}
static var bake_usec := 0
static var finish_usec := 0
static var bytes := 0
static var drawn := 0
static var fallback := 0
static var _material: ShaderMaterial
static var _baking := false
static var _measuring := false


static func configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--paysage-decor":
			enabled = true
		elif a == "--paysage-decor=direct":
			enabled = true
			baked = false
		elif a.begins_with("--decor-cuisson="):
			scale = clampf(a.get_slice("=", 1).to_float(), 0.5, 4.0)
		elif a.begins_with("--decor-variantes="):
			variants = clampi(a.get_slice("=", 1).to_int(), 1, 32)


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/decor_baked.gdshader")
	return _material


## Sortes cuites : [classe, paliers de taille, sortes (repères)]. La taille est « size » (radius pour
## un buisson).
static func sorts() -> Array:
	return [
		[Flora.DecorTree, [1.9, 5.0], [""]],
		[Flora.DecorBramble, [1.4, 2.8], [""]],
		[Flora.DecorBush, [32.0, 52.0], [""]],
		[Flora.DecorLandmark, [1.0, 2.2], ["grand_arbre", "ruine", "rocher"]],
	]


static func _size_of(t) -> float:
	return t.radius if t is Flora.DecorBush else t.size


static func _tier(tiers: Array, s: float) -> int:
	for i in tiers.size():
		if s <= tiers[i] * 1.05:
			return i
	return tiers.size() - 1


static func _key(script, kind: String, variant: int, tier: int, alive: bool) -> String:
	return "%d/%s/%d/%d/%d" % [script.get_instance_id(), kind, variant, tier, int(alive)]


## Tirage cuit pour la variante v (les repères gardent leur tirage : hash de leur sorte).
static func _seed(kind: String, v: int) -> int:
	return hash(kind) if kind != "" else 7919 * v + 13


## Cuit tout le décor dans un atlas. host : un nœud de l'arbre (pour le SubViewport). Coroutine.
static func bake(host: Node) -> void:
	var t0 := Time.get_ticks_usec()
	var jobs := []
	var b = Flora.DecorTree._b
	b.clear()
	for sd in sorts():
		var script = sd[0]
		var tiers: Array = sd[1]
		for kind in sd[2]:
			var nv := 1 if kind != "" else variants
			for v in nv:
				for ti in tiers.size():
					for alive in [false, true]:
						var t = script.new()
						if kind != "":
							t.kind = kind
						if t is Flora.DecorBush:
							t.radius = tiers[ti]
						else:
							t.size = tiers[ti]
						t.tree_seed = _seed(kind, v)
						t.alive = alive
						t.leaf = 1.0
						jobs.append({"key": _key(script, kind, v, ti, alive), "base": tiers[ti], "node": t})
	# Première image : chaque élément mesure sa boîte dans son _draw (voir draw), sans rien dessiner
	# (les repères tracent aussi des contours sur le nœud, permis seulement pendant _draw).
	var vp := SubViewport.new()
	vp.size = Vector2i(8, 8)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_baking = true
	_measuring = true
	Flora.DecorTree.baker = load("res://scripts/world_bake/decor_bake.gd")
	for j in jobs:
		vp.add_child(j["node"])
	host.add_child(vp)
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	_measuring = false
	for j in jobs:
		var box: Rect2 = j["node"].get_meta("box", Rect2(-8, -8, 16, 16))
		j["box"] = box.grow(3.0)
	# Rangement en étagères, les plus hautes d'abord.
	jobs.sort_custom(func(a, c): return a["box"].size.y > c["box"].size.y)
	var x := 0.0
	var y := 0.0
	var shelf := 0.0
	for j in jobs:
		var cell: Vector2 = (j["box"].size * scale).ceil() + Vector2.ONE * PAD * 2
		if x + cell.x > ATLAS_W:
			x = 0.0
			y += shelf
			shelf = 0.0
		j["src"] = Rect2(Vector2(x, y), cell)
		j["anchor"] = -j["box"].position * scale + Vector2.ONE * PAD
		x += cell.x
		shelf = maxf(shelf, cell.y)
	var h := int(y + shelf)
	vp.size = Vector2i(ATLAS_W, h) * ss
	# Chaque élément se dessine lui-même (son _draw : lot de triangles et contours) à sa place dans
	# l'atlas, agrandi ×scale×ss.
	for j in jobs:
		var origin: Vector2 = (j["src"] as Rect2).position + j["anchor"]
		var t = j["node"]
		t.position = origin * ss
		t.scale = Vector2(scale, scale) * ss
		t.queue_redraw()
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	_baking = false
	var t1 := Time.get_ticks_usec()
	var img := vp.get_texture().get_image()
	if ss > 1:
		img.resize(img.get_width() / ss, img.get_height() / ss, Image.INTERPOLATE_TRILINEAR)
	img.generate_mipmaps()
	tex = ImageTexture.create_from_image(img)
	bytes = img.get_data_size()
	cells.clear()
	for j in jobs:
		cells[j["key"]] = [j["src"], j["anchor"], j["base"]]
	vp.queue_free()
	finish_usec = Time.get_ticks_usec() - t1
	bake_usec = Time.get_ticks_usec() - t0
	print("DECOR cuisson : %d images, atlas %dx%d (×%.1f, ss %d), %.1f Mo, %.0f ms (dont lecture et mipmaps %.0f ms)" % [jobs.size(), ATLAS_W, h, scale, ss, bytes / 1048576.0, bake_usec / 1000.0, finish_usec / 1000.0])


## Branche la cuisson sur le décor : chaque élément d'une sorte cuite se redessine depuis l'atlas.
static func install(flora) -> void:
	Flora.DecorTree.baker = load("res://scripts/world_bake/decor_bake.gd")
	for t in flora.trees:
		prepare(t)


## Matériau et filtre d'un élément du décor (appelé aussi pour ceux ajoutés après la cuisson).
static func prepare(t) -> void:
	if not _known(t):
		return
	t.material = material()
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.queue_redraw()


static func _known(t) -> bool:
	var s = t.get_script()
	return s == Flora.DecorTree or s == Flora.DecorBramble or s == Flora.DecorBush or s == Flora.DecorLandmark


## Dessine l'élément depuis l'atlas (appelé par DecorTree._draw). Faux : dessin direct.
static func draw(t) -> bool:
	if _measuring:
		var b = Flora.DecorTree._b
		t._paint()
		if not b.points.is_empty():
			var box := Rect2(b.points[0], Vector2.ZERO)
			for q in b.points:
				box = box.expand(q)
			t.set_meta("box", box)
		b.clear()
		return true
	if tex == null or _baking or not _known(t):
		return false
	if t.alive and t.leaf < 1.0:
		fallback += 1
		return false
	var script = t.get_script()
	var kind: String = t.kind if script == Flora.DecorLandmark else ""
	var tiers: Array = []
	for sd in sorts():
		if sd[0] == script:
			tiers = sd[1]
	var s := _size_of(t)
	var ti := _tier(tiers, s)
	var v := 0 if kind != "" else posmod(t.tree_seed, variants)
	var c = cells.get(_key(script, kind, v, ti, t.alive))
	if c == null:
		fallback += 1
		return false
	drawn += 1
	var k: float = s / float(c[2]) / scale
	var src: Rect2 = c[0]
	t.draw_texture_rect_region(tex, Rect2(-c[1] * k, src.size * k), src)
	return true
