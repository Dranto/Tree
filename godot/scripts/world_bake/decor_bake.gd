## Décor cuit (refonte du monde « Paysages d'herbier », vague 1 D ; prototype en vague 0 P).
##
## Rendu par défaut (« -- --decor-direct » revient au dessin direct, pour comparer) : chaque élément du
## décor (flora.gd › DecorTree et ses sous-classes, dont les objets de world_art/decor.gd posés par
## decor_compose.gd) est dessiné une fois par le code, à ×scale et lissé (suréchantillonné ss fois dans
## un SubViewport, réduit, mipmaps, alpha prémultiplié), dans **un atlas par région** ; en jeu, il
## n'envoie plus qu'un quadrilatère texturé. Un seul matériau pour tout le décor (material()) : les
## éléments voisins dans le tri en profondeur partent dans le même appel de rendu.
##
## Méthode de la cuisson des Flétris (sprite_bake.gd, moteur de créatures A, lu sans le modifier) :
## SubViewport suréchantillonné, réduction, mipmaps, alpha prémultiplié, cache disque invalidé par une
## empreinte des scripts de dessin (SpriteBake._sig). Son bake() est propre aux poses des Flétris :
## ici, chaque élément se dessine lui-même (son _draw : lot de triangles, contours, encre de world_art).
##
## Ce qui est cuit : pour chaque élément d'une région, son image morte et son image vivante, pour
## `variants` tirages (le tirage d'un élément choisit sa variante), par paliers de taille (TIER : un
## élément est dessiné entre 0,8 et 1,25 fois la taille de son image), avec les réglages
## propres à sa sorte (penchant du vent, rocher debout, angle d'un tronc couché, sorte d'objet…).
## La pousse des feuilles d'une vague de vie (GROW_TIME) est un fondu de l'image morte à la vivante,
## qui éclot (Anim.pop) : plus aucun dessin direct après la cuisson.
##
## Quand : la région de la caméra et ses voisines visibles à l'entrée (Runtime, quelques images), puis
## toute région qui entre dans le champ. Cache disque user://decor/ : un fichier par région.
## Avant la cuisson (première image d'une région, galeries figées, sans écran) : dessin direct.
##
## Premier plan : un grand élément devient à demi transparent quand le héros ou un Flétri passe
## derrière lui (Runtime, self_modulate : sans redessin).
##
## Aucun texte visible, aucun chiffre de jeu, aucune collision : apparence seulement.
extends RefCounted

const Flora = preload("res://scripts/flora.gd")
const SpriteBake = preload("res://scripts/sprite_bake.gd")
const Regions = preload("res://scripts/regions.gd")

## À changer quand le format ou la façon de cuire change : invalide tout le cache.
const FORMAT := 1
## Rendu par défaut ; « --decor-direct » : dessin direct d'avant (comparaisons, banc).
static var enabled := true
## Pixels de l'atlas par pixel du monde (« --decor-cuisson=S »), suréchantillonnage, variantes.
static var scale := 1.5
static var ss := 2
static var variants := 3
## Cache disque (« --no-decor-cache »).
static var use_cache := true
## Une ligne par région cuite (« --decor-verbeux »).
static var verbose := false
## Mémoire des atlas gardés (octets, mipmaps comprises) : au-delà, la région la plus ancienne hors du
## champ est rendue et relue du cache si elle revient.
static var budget := 96 * 1024 * 1024
const PAD := 3
## Largeur de l'atlas (pixels).
const ATLAS_W := 2048
## Rapport entre deux paliers de taille.
const TIER := 1.6
const CACHE_DIR := "user://decor/"
## Région des éléments hors de toute région (oasis).
const COMMUN := "commun"
## Premier plan : opacité d'un grand élément quand quelqu'un passe derrière, vitesse du fondu (par s).
const FADE_ALPHA := 0.42
const FADE_SPEED := 5.0

## Atlas d'une région.
class Atlas:
	var region := ""
	var tex: Texture2D
	## Clé -> [src (Rect2, pixels de l'atlas), ancre (pied dans la case), taille cuite]
	var cells := {}
	var bytes := 0
	var last_used := 0
	var from_cache := false

static var atlases := {}
## Mesures (banc, tests).
static var bake_usec := 0
static var finish_usec := 0
static var drawn := 0
static var fallback := 0
static var cache_hits := 0
static var cache_writes := 0
static var jobs_baked := 0
static var _material: ShaderMaterial
static var _busy := false
static var _wanted := {}
static var _failed := {}
static var _measuring := false
static var _baking := false
## Nom stable de chaque classe du décor (« decor_marais.gd:DecorLog ») : sert aux clés du cache.
static var _names := {}
static var _sig := ""
static var _flora_ref: WeakRef


## Vide les atlas, le matériau et les cuissons en cours (fin de partie, fermeture).
static func release() -> void:
	atlases.clear()
	_material = null
	_wanted.clear()
	_failed.clear()
	_busy = false
	_baking = false
	_measuring = false


static func configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--decor-direct":
			enabled = false
		elif a.begins_with("--decor-cuisson="):
			scale = clampf(a.get_slice("=", 1).to_float(), 0.5, 4.0)
		elif a.begins_with("--decor-variantes="):
			variants = clampi(a.get_slice("=", 1).to_int(), 1, 32)
		elif a == "--decor-verbeux":
			verbose = true
		elif a == "--no-decor-cache":
			use_cache = false
	# Sans écran (tests de logique) : rien à cuire, rien n'est dessiné.
	if DisplayServer.get_name() == "headless":
		enabled = false


## Le matériau unique du décor (le monde vivant, tâche V, y pose ses réglages de balancement).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/decor_baked.gdshader")
	return _material


# --- Clés ---

## Propriétés d'un élément qui ne changent pas son image (elles n'entrent pas dans sa clé).
const BASE_PROPS := ["size", "tree_seed", "alive", "leaf", "radius", "bake_region", "tall", "sway", "fade", "_fade_to", "shade", "fg"]


static func _class_name(script: Script) -> String:
	if _names.is_empty():
		var files: Array = ["res://scripts/flora.gd", "res://scripts/world_bake/decor_compose.gd"]
		for f in ResourceLoader.list_directory("res://scripts/"):
			if f.begins_with("decor_") and f.ends_with(".gd"):
				files.append("res://scripts/" + f)
		for f in files:
			var s = load(f)
			if s == null:
				continue
			var cm: Dictionary = s.get_script_constant_map()
			for k in cm:
				if cm[k] is GDScript and not _names.has(cm[k]):
					_names[cm[k]] = "%s:%s" % [f.get_file().get_basename(), k]
	return _names.get(script, "?%d" % script.get_instance_id())


## Propriétés propres à la sorte de l'élément (penchant, sorte d'objet, angle…), arrondies.
static func _props(t) -> String:
	var out := ""
	for p in t.get_property_list():
		if not (p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = p["name"]
		if n in BASE_PROPS or n.begins_with("_"):
			continue
		var v = t.get(n)
		if v is float:
			v = snappedf(v, 0.15)
		elif v is Object or v is Array or v is Dictionary:
			continue
		out += "%s=%s;" % [n, v]
	return out


static func size_of(t) -> float:
	var r = t.get("radius")
	return float(r) if r != null else float(t.size)


static func tier_of(s: float) -> int:
	return roundi(log(maxf(s, 0.05)) / log(TIER))


static func tier_size(ti: int) -> float:
	return pow(TIER, ti)


static func _seed(v: int) -> int:
	return 7919 * v + 13


## Clé de l'image d'un élément (sans l'état) : sa classe, sa variante, son palier, ses propriétés.
static func key_of(t) -> String:
	var k = t.get_meta("bake_key", "")
	if k == "":
		var v: int = 0 if t is Flora.DecorLandmark else posmod(t.tree_seed, variants)
		k = "%s|%d|%d|%s" % [_class_name(t.get_script()), v, tier_of(size_of(t)), _props(t)]
		t.set_meta("bake_key", k)
	return k


static func region_of(t) -> String:
	return t.bake_region if t.bake_region != "" else COMMUN


# --- Cuisson ---

## Demande la cuisson d'une région (faite par Runtime à l'image suivante).
static func request(region: String) -> void:
	if enabled and not atlases.has(region) and not _failed.has(region):
		_wanted[region] = true


## Cuit les régions demandées ; host : un nœud de l'arbre (pour le SubViewport). Coroutine.
static func pump(host: Node, flora) -> void:
	if _busy or _wanted.is_empty():
		return
	var reg: String = _wanted.keys()[0]
	_wanted.erase(reg)
	await bake(host, flora, reg)


## Éléments d'une région, par clé : clé -> un élément modèle.
static func _models(flora, region: String) -> Dictionary:
	var out := {}
	for t in flora.trees:
		if not is_instance_valid(t) or region_of(t) != region:
			continue
		var k := key_of(t)
		if not out.has(k):
			out[k] = t
	return out


## Empreinte de tout ce dont dépend le dessin du décor d'une région.
static func fingerprint(keys: Array) -> String:
	if _sig == "":
		var parts := [FORMAT, scale, ss, variants, TIER]
		var files := ["res://scripts/flora.gd", "res://scripts/art.gd", "res://scripts/anim.gd", "res://scripts/draw_batch.gd",
			"res://scripts/world_bake/decor_bake.gd", "res://scripts/world_bake/decor_compose.gd", "res://scripts/creature_art/ink.gd"]
		for f in ResourceLoader.list_directory("res://scripts/"):
			if f.begins_with("decor_") and f.ends_with(".gd"):
				files.append("res://scripts/" + f)
		for f in ResourceLoader.list_directory("res://scripts/world_art/"):
			if f.ends_with(".gd"):
				files.append("res://scripts/world_art/" + f)
		for f in files:
			parts.append(SpriteBake._sig(f))
		_sig = str(parts).md5_text()
	var ks := keys.duplicate()
	ks.sort()
	return (_sig + str(ks)).md5_text().substr(0, 12)


static func _cache_path(region: String, fp: String) -> String:
	return CACHE_DIR + "%s_%s.bin" % [region, fp]


static func _load_cached(region: String, fp: String) -> Atlas:
	var path := _cache_path(region, fp)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return null
	var m = f.get_var()
	if not m is Dictionary or not m.has("img_w"):
		return null
	var data := f.get_buffer(int(m["img_size"]))
	if data.size() != int(m["img_size"]):
		return null
	var img := Image.create_from_data(int(m["img_w"]), int(m["img_h"]), true, int(m["img_format"]), data)
	var a := Atlas.new()
	a.region = region
	a.cells = m["cells"]
	a.tex = ImageTexture.create_from_image(img)
	a.bytes = img.get_data_size()
	a.from_cache = true
	return a


static func _save_cached(a: Atlas, fp: String, img: Image) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	# Une seule version par région : les anciennes empreintes sont effacées.
	for old in DirAccess.get_files_at(CACHE_DIR):
		if old.begins_with(a.region + "_") and old.length() == a.region.length() + 17:
			DirAccess.remove_absolute(CACHE_DIR + old)
	var f := FileAccess.open_compressed(_cache_path(a.region, fp), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return
	var data := img.get_data()
	f.store_var({"cells": a.cells, "img_w": img.get_width(), "img_h": img.get_height(), "img_format": img.get_format(), "img_size": data.size()})
	f.store_buffer(data)
	f.close()
	cache_writes += 1


## Vide le cache disque (tests).
static func clear_disk_cache() -> void:
	if DirAccess.dir_exists_absolute(CACHE_DIR):
		for f in DirAccess.get_files_at(CACHE_DIR):
			DirAccess.remove_absolute(CACHE_DIR + f)


## Nœud à cuire pour une clé : même classe et mêmes propriétés que le modèle, au palier de la clé,
## dans la variante de la clé.
static func _bake_node(model, alive: bool):
	var t = model.get_script().new()
	for p in model.get_property_list():
		if not (p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = p["name"]
		if n in BASE_PROPS or n.begins_with("_"):
			continue
		var v = model.get(n)
		if v is Object:
			continue
		t.set(n, v.duplicate() if v is Array or v is Dictionary else v)
	var base := tier_size(tier_of(size_of(model)))
	if model.get("radius") != null:
		t.radius = base
		t.size = model.size
	else:
		t.size = base
	t.tree_seed = model.tree_seed if model is Flora.DecorLandmark else _seed(posmod(model.tree_seed, variants))
	t.bake_region = model.bake_region
	t.alive = alive
	t.leaf = 1.0
	return [t, base]


## Image suivante rendue. Par le signal du Runtime quand c'est lui l'hôte : s'il quitte l'arbre (fin de
## partie, fermeture), la cuisson en cours s'arrête avec lui au lieu de survivre au serveur de rendu.
static func _drawn(host: Node) -> Signal:
	return host.drawn if host.has_signal("drawn") else RenderingServer.frame_post_draw


## Cuit le décor d'une région dans un atlas. Coroutine (deux images de rendu ; aucune si le cache sert).
static func bake(host: Node, flora, region: String) -> void:
	while _busy:
		await _drawn(host)
	if atlases.has(region):
		return
	_busy = true
	var t0 := Time.get_ticks_usec()
	var models := _models(flora, region)
	var fp := fingerprint(models.keys())
	if use_cache:
		var cached := _load_cached(region, fp)
		if cached != null and cached.cells.size() >= models.size() * 2:
			cache_hits += 1
			_install_atlas(flora, cached)
			bake_usec += Time.get_ticks_usec() - t0
			_busy = false
			return
	if models.is_empty():
		var empty := Atlas.new()
		empty.region = region
		atlases[region] = empty
		_busy = false
		return
	var jobs := []
	for k in models:
		for alive in [false, true]:
			var nb: Array = _bake_node(models[k], alive)
			jobs.append({"key": "%s|%d" % [k, int(alive)], "base": nb[1], "node": nb[0]})
	# Première image : chaque élément se dessine une fois, petit, dans une case large, pour relever la
	# place qu'il prend (lot de triangles, contours et encre de world_art compris).
	var probe := 0.5
	var cell := Vector2(560, 380) * probe
	var cols := int(ATLAS_W / cell.x)
	var vp := SubViewport.new()
	vp.size = Vector2i(int(cols * cell.x), int(ceili(jobs.size() / float(cols)) * cell.y))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_baking = true
	for i in jobs.size():
		var j: Dictionary = jobs[i]
		var n = j["node"]
		var s: float = j["base"] if n.get("radius") == null else 1.0
		# Case de relevé : l'élément y tient s'il ne dépasse pas ±280 × (−300, +80) px du monde
		# (à sa taille cuite) ; un élément plus grand est relevé plus petit.
		var fit := minf(1.0, 1.0 / maxf(s, 0.01)) if n.get("radius") == null else minf(1.0, 40.0 / maxf(float(n.radius), 1.0))
		var k := probe * fit
		j["probe_k"] = k
		j["probe_o"] = Vector2((i % cols) * cell.x + cell.x * 0.5, (i / cols) * cell.y + cell.y * 0.79)
		n.position = j["probe_o"]
		n.scale = Vector2(k, k)
		vp.add_child(n)
	host.add_child(vp)
	await _drawn(host)
	var pimg := vp.get_texture().get_image()
	for i in jobs.size():
		var j: Dictionary = jobs[i]
		var r := Rect2i(Vector2i((i % cols) * int(cell.x), (i / cols) * int(cell.y)), Vector2i(cell))
		var used := pimg.get_region(r).get_used_rect()
		var k: float = j["probe_k"]
		if used.size.x <= 0:
			j["box"] = Rect2(-4, -4, 8, 8)
		else:
			var o: Vector2 = j["probe_o"] - Vector2(r.position)
			j["box"] = Rect2((Vector2(used.position) - o) / k, Vector2(used.size) / k).grow(2.0 / k + 1.0)
	# Rangement en étagères, les plus hautes d'abord.
	jobs.sort_custom(func(a, c): return a["box"].size.y > c["box"].size.y)
	var x := 0.0
	var y := 0.0
	var shelf := 0.0
	for j in jobs:
		var c: Vector2 = (j["box"].size * scale).ceil() + Vector2.ONE * PAD * 2
		c.x = minf(c.x, ATLAS_W)
		if x + c.x > ATLAS_W:
			x = 0.0
			y += shelf
			shelf = 0.0
		j["src"] = Rect2(Vector2(x, y), c)
		j["anchor"] = -j["box"].position * scale + Vector2.ONE * PAD
		x += c.x
		shelf = maxf(shelf, c.y)
	var h := int(y + shelf)
	vp.size = Vector2i(ATLAS_W, maxi(h, 8)) * ss
	for j in jobs:
		var n = j["node"]
		var origin: Vector2 = (j["src"] as Rect2).position + j["anchor"]
		n.position = origin * ss
		n.scale = Vector2(scale, scale) * ss
		n.queue_redraw()
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await _drawn(host)
	_baking = false
	var t1 := Time.get_ticks_usec()
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		_failed[region] = true
		_busy = false
		return
	if ss > 1:
		img.resize(img.get_width() / ss, img.get_height() / ss, Image.INTERPOLATE_TRILINEAR)
	img.generate_mipmaps()
	var a := Atlas.new()
	a.region = region
	a.tex = ImageTexture.create_from_image(img)
	a.bytes = img.get_data_size()
	for j in jobs:
		a.cells[j["key"]] = [j["src"], j["anchor"], j["base"]]
	jobs_baked += jobs.size()
	if use_cache:
		_save_cached(a, fp, img)
	if verbose:
		print("DÉCOR cuisson %s : %d images, atlas %dx%d, %.1f Mo, %.0f ms" % [region, jobs.size(), img.get_width(), img.get_height(), a.bytes / 1048576.0, (Time.get_ticks_usec() - t0) / 1000.0])
	finish_usec += Time.get_ticks_usec() - t1
	bake_usec += Time.get_ticks_usec() - t0
	_install_atlas(flora, a)
	_busy = false


static func _install_atlas(flora, a: Atlas) -> void:
	a.last_used = Time.get_ticks_msec()
	atlases[a.region] = a
	for t in flora.trees:
		if is_instance_valid(t) and region_of(t) == a.region:
			t.queue_redraw()
	trim(flora)


static func total_bytes() -> int:
	var n := 0
	for a in atlases.values():
		n += a.bytes
	return n


## Rend les atlas des régions hors du champ tant que la mémoire dépasse le budget (les plus anciens
## d'abord). Leurs éléments, hors de vue, repassent au dessin direct jusqu'à leur retour.
static func trim(flora, keep := {}) -> void:
	var total := total_bytes()
	if total <= budget:
		return
	var old := []
	for r in atlases:
		if not keep.has(r):
			old.append([atlases[r].last_used, r])
	old.sort()
	for it in old:
		if total <= budget:
			break
		total -= atlases[it[1]].bytes
		atlases.erase(it[1])
		for t in flora.trees:
			if is_instance_valid(t) and region_of(t) == it[1]:
				t.queue_redraw()


# --- Dessin ---

## Branche la cuisson sur le décor : le matériau unique, et le nœud qui cuit les régions en vue et
## fond le premier plan.
static func install(flora) -> void:
	if not enabled:
		return
	_flora_ref = weakref(flora)
	Flora.DecorTree.baker = load("res://scripts/world_bake/decor_bake.gd")
	for t in flora.trees:
		prepare(t)
	var rt := Runtime.new()
	rt.flora = flora
	flora.add_child(rt)


## Matériau et filtre d'un élément du décor (appelé aussi pour ceux ajoutés après la mise en route).
static func prepare(t) -> void:
	t.set_meta("cuit", true)
	t.material = material()
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Dessine l'élément depuis l'atlas de sa région (appelé par DecorTree._draw). Faux : dessin direct.
static func draw(t) -> bool:
	# Seul le décor du monde (flora) est cuit ; une galerie figée dessine en direct.
	if _baking or not t.has_meta("cuit"):
		return false
	var a: Atlas = atlases.get(region_of(t))
	if a == null:
		# La région est cuite dans une ou deux images (ou relue du cache) : rien en attendant, plutôt
		# que des centaines de dessins directs coûteux. Une région impossible à cuire reste en direct.
		if _failed.has(region_of(t)):
			fallback += 1
			return false
		return true
	var k := key_of(t)
	var dead = a.cells.get(k + "|0")
	var live = a.cells.get(k + "|1")
	if dead == null or live == null:
		fallback += 1
		return false
	drawn += 1
	var s := size_of(t)
	if not t.alive:
		_quad(t, a, dead, s, 1.0, 1.0)
	elif t.leaf >= 1.0:
		_quad(t, a, live, s, 1.0, 1.0)
	else:
		# Pousse : l'image vivante éclot par-dessus la morte, qui s'efface.
		var g: float = t.growth()
		_quad(t, a, dead, s, 1.0 - smoothstep(0.3, 1.0, g), 1.0)
		_quad(t, a, live, s, minf(1.0, g * 1.6), 0.82 + 0.18 * Anim.pop(minf(1.0, g * 1.15)))
	return true


static func _quad(t, a: Atlas, c: Array, s: float, alpha: float, grow: float) -> void:
	if alpha <= 0.01:
		return
	var k: float = s / float(c[2]) / scale * grow
	var src: Rect2 = c[0]
	var anchor: Vector2 = c[1]
	var r := Rect2(-anchor * k, src.size * k)
	t.draw_texture_rect_region(a.tex, r, src, Color(1, 1, 1, alpha))
	if t.tall > 0.0:
		t.set_meta("box", r)


## Cuit les régions qui entrent dans le champ, fond le premier plan quand quelqu'un passe derrière.
class Runtime extends Node:
	var flora
	## Ce script (une classe interne ne voit pas les variables statiques de son script).
	var B = load("res://scripts/world_bake/decor_bake.gd")
	var _faded := {}
	var _tick := 0

	## Régions du champ (les seules cuites), grands éléments proches du héros (relevés toutes les
	## NEAR_EVERY images) et ceux devant lesquels quelqu'un passe.
	var _keep := {}
	var _near := {}
	const NEAR_EVERY := 6

	signal drawn

	func _ready() -> void:
		process_priority = 10
		RenderingServer.frame_post_draw.connect(_on_drawn)

	func _on_drawn() -> void:
		drawn.emit()

	## Les atlas et le matériau vivent dans des variables statiques : les libérer avec la partie, sinon
	## ils survivent au serveur de rendu à la fermeture (Godot s'arrête alors sur un abort).
	func _exit_tree() -> void:
		if RenderingServer.frame_post_draw.is_connected(_on_drawn):
			RenderingServer.frame_post_draw.disconnect(_on_drawn)
		B.release()

	func _process(delta: float) -> void:
		_tick += 1
		# Pas à la première image : le héros et la caméra ne sont pas encore à leur place.
		if _tick % 20 == 2:
			_want()
		if not B._wanted.is_empty() and not B._busy:
			for reg in B._wanted.keys():
				if not _keep.has(reg):
					B._wanted.erase(reg)
			B.pump(self, flora)
		_fade(delta)

	## Régions du champ de la caméra (et un peu au-delà) : demandées, gardées en mémoire.
	func _want() -> void:
		var cam := get_viewport().get_camera_2d() if get_viewport() != null else null
		var c: Vector2 = cam.get_screen_center_position() if cam != null else Vector2.ZERO
		var half := get_viewport().get_visible_rect().size * 0.5 / (cam.zoom if cam != null else Vector2.ONE) + Vector2(500, 400)
		var keep := {}
		for i in 5:
			for j in 5:
				var p := c + Vector2((i - 2) * 0.5 * half.x, (j - 2) * 0.5 * half.y)
				var reg := Regions.region_weighted(p)
				keep[reg if reg != "" else COMMUN] = true
		for reg in keep:
			if B.atlases.has(reg):
				B.atlases[reg].last_used = Time.get_ticks_msec()
			else:
				B.request(reg)
		_keep = keep
		B.trim(flora, keep)

	## Premier plan : les grands éléments proches du héros, à demi transparents si le héros ou un
	## Flétri est derrière eux (plus haut à l'écran, dans leur silhouette).
	func _fade(delta: float) -> void:
		var main = flora.get_parent()
		var p = main.get("player") if main != null else null
		if p == null or not is_instance_valid(p):
			return
		if _tick % NEAR_EVERY == 0 or _near.is_empty():
			_near.clear()
			for t in flora.decor_near(p.position, 560.0):
				if t.tall > 0.0:
					_near[t] = true
		var near := _near
		var check_enemies := _tick % 3 == 0
		for t in near:
			if not is_instance_valid(t):
				continue
			var hidden := _behind(t, p.position, 22.0)
			if not hidden and not check_enemies:
				hidden = t._fade_to < 1.0
			elif not hidden and main.has_method("enemies_near"):
				var box: Rect2 = t.get_meta("box", Rect2(-t.tall * 0.4, -t.tall, t.tall * 0.8, t.tall))
				var c: Vector2 = t.position + box.get_center()
				for e in main.enemies_near(c, maxf(box.size.x, box.size.y) * 0.5, false):
					if _behind(t, e.position, float(e.radius)):
						hidden = true
						break
			t._fade_to = FADE_ALPHA if hidden else 1.0
			if t._fade_to < 1.0 or t.fade < 1.0:
				_faded[t] = true
		var done := []
		for t in _faded:
			if not is_instance_valid(t):
				done.append(t)
				continue
			if not near.has(t):
				t._fade_to = 1.0
			t.fade = move_toward(t.fade, t._fade_to, delta * FADE_SPEED * (1.0 - FADE_ALPHA))
			t.self_modulate = Color(t.shade, t.shade, t.shade, t.fade)
			if t.fade >= 1.0 and t._fade_to >= 1.0:
				done.append(t)
		for t in done:
			_faded.erase(t)

	## Vrai si un personnage en pos (rayon r) est derrière l'élément : plus haut que son pied et dans
	## sa silhouette.
	static func _behind(t, pos: Vector2, r: float) -> bool:
		if pos.y >= t.position.y - 4.0:
			return false
		var box: Rect2 = t.get_meta("box", Rect2(-t.tall * 0.4, -t.tall, t.tall * 0.8, t.tall))
		var body := Rect2(pos - t.position - Vector2(r, r * 2.2), Vector2(r * 2.0, r * 2.4))
		return box.grow_individual(-box.size.x * 0.18, -box.size.y * 0.08, -box.size.x * 0.18, 0.0).intersects(body)
