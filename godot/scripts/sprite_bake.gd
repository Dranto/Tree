## Moteur de créatures : cuisson des dessins des Flétris en sprites (refonte des personnages, vague 1 A).
##
## Rendu par défaut (« -- --no-sprites » revient à l'ancien rendu, pour comparer) : chaque sorte est
## dessinée une fois par le code, à ×scale et lissée (suréchantillonnée dans un SubViewport), image
## par image pour chaque animation, dans un atlas par sorte (ImageTexture avec mipmaps). En jeu,
## enemy.gd n'envoie plus qu'un quadrilatère texturé par Flétri.
##
## Deux sortes de dessins :
##   - une sorte qui a son script « Bestiaire d'herbier », res://scripts/creature_art/<région>/<id>.gd
##     (région = « region » de enemies.json, « commun » sans région ; contrat de dessin dans
##     /mnt/project-files/plans/refonte-persos-contrat-moteur.md) : vue de trois quarts, pieds en
##     bas, hauteur HEIGHT, tournée vers la droite ; la tête suit la cible (pose « look » cuite en
##     trois angles), coup reçu cuit, poses propres du comportement (const CUSTOM) cuites aussi ;
##   - sinon l'ancien dessin (fletri_art.gd, enemy_art/), cuit lissé, vu de dessus avec une
##     inclinaison vers la cible.
## Le retournement gauche/droite est une transformation au moment du dessin ; l'ombre au sol n'est
## pas cuite (elle est relevée, et enemy.gd la dessine sur la couche du sol).
##
## Quand : par région à l'entrée (main.gd), les sortes communes au démarrage, et toute sorte qui
## apparaît sans atlas (request + pump, cuite à l'image suivante ; dessin direct en attendant).
## Cache disque user://sprites/ : un fichier par sorte, invalidé par une empreinte des scripts de
## dessin (sources ou fichiers compilés d'un export), des couleurs et des réglages de cuisson.
##
## Aucun texte visible, aucun chiffre de jeu : apparence seulement.
extends RefCounted

const DrawBatch = preload("res://scripts/draw_batch.gd")
const FletriArt = preload("res://scripts/fletri_art.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

const CREATURE_DIR := "res://scripts/creature_art/"
## Dossier des scripts de créature (un test le remplace par une copie dans user://).
static var creature_dir := CREATURE_DIR
const CACHE_DIR := "user://sprites/"
## À changer quand le format ou la façon de cuire change : invalide tout le cache.
const FORMAT := 3

## Rendu par défaut ; « --no-sprites » revient au dessin direct d'avant (comparaisons, banc).
static var enabled := true
## Résolution de cuisson (×1 = pixels du jeu à 1600x900).
static var scale := 3.0
## Images de la marche (un pas complet), du repos (une respiration), de l'annonce, de la frappe.
static var walk_frames := 12
static var idle_frames := 4
static var windup_frames := 4
static var strike_frames := 3
## Lissage : suréchantillonnage. Le rendu Compatibility n'a pas de MSAA 2D : l'atlas est dessiné
## ss fois plus grand puis réduit (moyenne des ss×ss points de chaque pixel).
static var ss := 2
## Cache disque (« --no-sprite-cache » pour le couper).
static var use_cache := true
## Mémoire des atlas gardés en jeu : au-delà, les atlas qui n'ont pas servi depuis UNUSED_MSEC sont
## rendus (les plus anciens d'abord) et relus du cache disque s'ils reviennent (quelques ms).
static var budget := 64 * 1024 * 1024
const UNUSED_MSEC := 3000
## Inclinaison maximale vers la cible (ancien dessin vu de dessus seulement), en radians.
const TILT := 0.3
## Période des animations lentes (respiration), comme silhouette_cache.gd.
const TIME_LOOP := 2.4
## Marge autour de chaque image (pixels de l'atlas) : le liseré d'élite et les mipmaps n'y débordent pas.
const PAD := 8
## Regard cuit des sortes dessinées (angle de la cible, côté droit) : haut, droit devant, bas.
const LOOKS := [-0.45, 0.0, 0.45]
## Pieds des sortes dessinées : sous la position du Flétri, de FEET × son rayon.
const FEET := 0.45
## Élite d'une sorte dessinée : image agrandie de 15 % (son rayon de jeu, lui, est ×1,2).
const ELITE_SCALE := 1.15
## Coup reçu cuit des sortes dessinées (pose « hit »).
const HIT_POSES := [1.0, 0.5]
## Mémoire visée pour l'atlas d'une sorte dessinée (octets, mipmaps comprises) et résolution minimale :
## au-delà, la sorte est cuite moins fin (×3 → ×2 au plus bas).
const KIND_TARGET := 3.5 * 1024 * 1024
const MIN_SCALE := 2.0
## Repérage de la place prise par un dessin (première passe, petite).
const PROBE_SCALE := 1.5

## Atlas d'une sorte.
class Atlas:
	var kind_id := ""
	var key := ""
	var tex: ImageTexture
	## Rayon de la sorte (enemies.json) : une élite réutilise l'atlas, agrandi.
	var base_r := 1.0
	## Sorte dessinée par un script creature_art (vue de trois quarts) ?
	var scripted := false
	## Images : [case dans l'atlas, position du Flétri dans la case] (pixels de l'atlas). Chaque image
	## a sa propre case, ajustée au dessin (rangées par étagères).
	var frames := []
	## Plus grande case (mesures, tests).
	var cell := Vector2.ZERO
	## Animation -> une liste d'indices de cases par regard (une seule liste sans regard).
	var anims := {}
	## Poses propres du comportement : [[clé, images, état ?], ...] (const CUSTOM du script).
	var custom := []
	var unique := 0
	var total := 0
	var bytes := 0
	## Ombre au sol (pixels du jeu, relatifs à la position) : centre et demi-axes.
	var shadow_c := Vector2.ZERO
	var shadow_r := Vector2.ZERO
	## Haut du dessin (pixels du jeu, relatif à la position, négatif) et point du collier d'élite.
	var top := 0.0
	var neck := Vector2.ZERO
	## La sorte dessine elle-même ses marques d'élite (const DRAWS_ELITE).
	var draws_elite := false
	## Atlas lu depuis le cache disque.
	var from_cache := false
	## Résolution de la cuisson (pixels de l'atlas par pixel du jeu).
	var bake_scale := 3.0
	## Dernier dessin (Time.get_ticks_msec) : les atlas oubliés sont rendus au-delà du budget.
	var last_used := 0

	func src(i: int) -> Rect2:
		return frames[i][0]

	## Position du Flétri dans la case de l'image i (pixels de l'atlas).
	func anchor(i: int) -> Vector2:
		return frames[i][1]

	## Place de l'image i dans le jeu (pixels du jeu, relatifs à la position, rayon de base).
	func rect(i: int) -> Rect2:
		return Rect2(-frames[i][1] / bake_scale, frames[i][0].size / bake_scale)

	func meta() -> Dictionary:
		return {"kind_id": kind_id, "base_r": base_r, "scripted": scripted, "cell": cell, "frames": frames,
			"anims": anims, "custom": custom, "unique": unique, "total": total,
			"shadow_c": shadow_c, "shadow_r": shadow_r, "top": top, "neck": neck, "draws_elite": draws_elite, "bake_scale": bake_scale, "key": key}

	func set_meta_dict(m: Dictionary) -> void:
		for f in m:
			set(f, m[f])

static var atlases := {}
## Mesures (banc, tests).
static var bake_usec := 0
static var build_usec := 0
## Lecture de l'image rendue, réduction, mipmaps et texture (après le rendu).
static var finish_usec := 0
static var cache_hits := 0
static var cache_writes := 0
static var evicted := 0
static var drawn := 0
static var fallback := 0
static var _material: ShaderMaterial
static var _elite_material: ShaderMaterial
## Sortes demandées en jeu sans atlas (cuites par pump), sortes impossibles à cuire (sans rendu).
static var _wanted := {}
static var _failed := {}
static var _busy := false
static var _kinds_cache := {}
static var _scripts := {}
static var _common_sig := ""


## Lit les réglages sur la ligne de commande : « --no-sprites », « --sprites=3 » (résolution),
## « --sprites-walk=8 », « --sprites-ss=1|2|3|4 », « --no-sprite-cache ».
static func configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--no-sprites":
			enabled = false
		elif a == "--sprites":
			enabled = true
		elif a.begins_with("--sprites="):
			enabled = true
			scale = maxf(1.0, a.get_slice("=", 1).to_float())
		elif a.begins_with("--sprites-walk="):
			walk_frames = maxi(2, a.get_slice("=", 1).to_int())
		elif a.begins_with("--sprites-ss="):
			ss = clampi(a.get_slice("=", 1).to_int(), 1, 4)
		elif a == "--no-sprite-cache":
			use_cache = false


static func material(elite := false) -> ShaderMaterial:
	if elite:
		if _elite_material == null:
			_elite_material = ShaderMaterial.new()
			_elite_material.shader = load("res://shaders/sprite_tint.gdshader")
			_elite_material.set_shader_parameter("outline", 1.0)
		_elite_material.set_shader_parameter("outline_color", Art.c("or"))
		return _elite_material
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/sprite_tint.gdshader")
	return _material


# --- Sortes et scripts ---

## Toutes les sortes de enemies.json : [[id, rayon], ...].
static func all_kinds() -> Array:
	var out := []
	for k in _kinds():
		out.append([k, float(_kinds()[k]["radius"])])
	return out


## Sortes d'une région ("" : les communes) : [[id, rayon], ...].
static func region_kinds(region: String) -> Array:
	var out := []
	for k in _kinds():
		if str(_kinds()[k].get("region", "")) == region:
			out.append([k, float(_kinds()[k]["radius"])])
	return out


static func _kinds() -> Dictionary:
	if _kinds_cache.is_empty():
		var f := FileAccess.open("res://data/enemies.json", FileAccess.READ)
		for k in JSON.parse_string(f.get_as_text()).get("kinds", []):
			_kinds_cache[str(k["id"])] = k
	return _kinds_cache


## Dossier du script de dessin d'une sorte : sa région, « commun » sans région.
static func region_dir(kind_id: String) -> String:
	var reg := str(_kinds().get(kind_id, {}).get("region", ""))
	return creature_dir + (reg if reg != "" else "commun") + "/"


## Script « Bestiaire d'herbier » d'une sorte, ou null (ancien dessin).
static func script_of(kind_id: String):
	if not _scripts.has(kind_id):
		var path := region_dir(kind_id) + kind_id + ".gd"
		_scripts[kind_id] = load(path) if ResourceLoader.exists(path) else null
	return _scripts[kind_id]


# --- Empreinte du cache ---

## Empreinte d'un fichier de script : son texte, ou le fichier compilé d'un export (.remap).
static func _sig(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_md5(path)
	if FileAccess.file_exists(path + ".remap"):
		var cfg := ConfigFile.new()
		if cfg.load(path + ".remap") == OK:
			var p := str(cfg.get_value("remap", "path", ""))
			if p != "" and FileAccess.file_exists(p):
				return FileAccess.get_md5(p)
	return path


## Scripts .gd d'un dossier (marche aussi dans un export, où ils sont remappés).
static func _scripts_in(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var files: PackedStringArray = ResourceLoader.list_directory(dir) if dir.begins_with("res://") else DirAccess.get_files_at(dir)
	for f in files:
		if f.ends_with(".gd"):
			out.append(dir + f)
	out.sort()
	return out


## Ce dont dépend tout dessin : ce moteur, les couleurs, l'encre, l'ancien dessin, les réglages.
static func _common() -> String:
	if _common_sig == "":
		var parts := [FORMAT, scale, ss, walk_frames, idle_frames, windup_frames, strike_frames, LOOKS, HIT_POSES, FEET]
		for p in ["res://scripts/sprite_bake.gd", "res://scripts/art.gd", "res://scripts/anim.gd", "res://scripts/fletri_art.gd", "res://scripts/draw_batch.gd"]:
			parts.append(_sig(p))
		for p in _scripts_in("res://scripts/enemy_art/"):
			parts.append(_sig(p))
		for p in _scripts_in(creature_dir):
			parts.append(_sig(p))
		_common_sig = str(hash(parts))
	return _common_sig


## Empreinte d'une sorte : le commun, son rayon, ses données de dessin et les scripts de son dossier.
static func fingerprint(key: String, r: float) -> String:
	var kind_id := key.get_slice("@", 0)
	var parts := [_common(), key, r, _anims_wanted(kind_id)]
	if script_of(kind_id) != null:
		for p in _scripts_in(region_dir(kind_id)):
			parts.append(_sig(p))
	return "%08x" % (hash(parts) & 0xffffffff)


## Oublie les empreintes calculées (un test qui change un script).
static func forget_signatures() -> void:
	_common_sig = ""
	_scripts.clear()


static func _cache_path(key: String, r: float) -> String:
	return CACHE_DIR + "%s_%s.bin" % [key.replace("@", "+"), fingerprint(key, r)]


static func _load_cached(key: String, r: float) -> Atlas:
	var path := _cache_path(key, r)
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
	for f2 in ["img_w", "img_h", "img_format", "img_size"]:
		m.erase(f2)
	a.set_meta_dict(m)
	a.key = key
	a.tex = ImageTexture.create_from_image(img)
	a.bytes = img.get_data_size()
	a.from_cache = true
	return a


static func _save_cached(a: Atlas, img: Image) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	# Une seule version par sorte : les anciennes empreintes sont effacées.
	var stem := a.key.replace("@", "+") + "_"
	for old in DirAccess.get_files_at(CACHE_DIR):
		if old.begins_with(stem) and old.substr(stem.length()).length() == 12:
			DirAccess.remove_absolute(CACHE_DIR + old)
	var f := FileAccess.open_compressed(_cache_path(a.key, a.base_r), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return
	var m := a.meta()
	m["img_w"] = img.get_width()
	m["img_h"] = img.get_height()
	m["img_format"] = img.get_format()
	var data := img.get_data()
	m["img_size"] = data.size()
	f.store_var(m)
	f.store_buffer(data)
	f.close()
	cache_writes += 1


## Vide le cache disque (tests).
static func clear_disk_cache() -> void:
	if DirAccess.dir_exists_absolute(CACHE_DIR):
		for f in DirAccess.get_files_at(CACHE_DIR):
			DirAccess.remove_absolute(CACHE_DIR + f)


# --- Poses cuites ---

## Animations utiles à une sorte, d'après ses données : annonce, retour, charge (la frappe et le
## coup reçu servent à toutes : couronne d'épines des élites, coups du héros).
static func _anims_wanted(kind_id: String) -> Array:
	var d: Dictionary = _kinds().get(kind_id, {})
	var out := ["idle", "walk", "strike"]
	if d.has("windup"):
		out.append("windup")
	if d.has("recover"):
		out.append("recover")
	if d.has("charge_speed") or d.has("dive_speed"):
		out.append("charge")
	return out


## Poses de l'ancien dessin : [animation, regard, pose, temps].
static func _poses_old(kind_id: String) -> Array:
	var want := _anims_wanted(kind_id)
	var out := []
	for i in idle_frames:
		out.append(["idle", 0, {}, (i + 0.5) * TIME_LOOP / idle_frames])
	for i in walk_frames:
		out.append(["walk", 0, {"walk": i * TAU / walk_frames, "moving": 1.0}, TIME_LOOP * 0.5])
	if "windup" in want:
		for i in windup_frames:
			out.append(["windup", 0, {"state": "windup", "k": (i + 0.5) / windup_frames}, TIME_LOOP * 0.5])
	if "charge" in want:
		for i in 2:
			out.append(["charge", 0, {"state": "charge", "moving": 1.0, "walk": i * PI}, (i + 0.5) * TIME_LOOP / 2.0])
	if "recover" in want:
		out.append(["recover", 0, {"state": "recover"}, TIME_LOOP * 0.5])
	for i in strike_frames:
		out.append(["strike", 0, {"strike": (i + 0.5) / strike_frames}, TIME_LOOP * 0.5])
	return out


## Poses d'une sorte dessinée (contrat moteur) : [animation, regard, pose].
static func _poses_scripted(kind_id: String, art) -> Array:
	var want := _anims_wanted(kind_id)
	var out := []
	# La marche regarde droit devant (la cible est presque toujours dans le sens de la marche) ; le
	# repos et l'annonce suivent la cible en trois angles.
	for i in walk_frames:
		out.append(["walk", 0, {"walk": i * TAU / walk_frames, "moving": 1.0, "t": i * TIME_LOOP / walk_frames, "look": 0.0}])
	# « const LOOKS := false » : dessin qui ne suit pas la cible (un seul regard, moitié moins d'images).
	var looks: Array = LOOKS if _const(art, "LOOKS", true) else [0.0]
	for li in looks.size():
		var look: float = looks[li]
		for i in idle_frames:
			out.append(["idle", li, {"t": (i + 0.5) * TIME_LOOP / idle_frames, "look": look}])
		if "windup" in want:
			for i in windup_frames:
				out.append(["windup", li, {"state": "windup", "k": (i + 0.5) / windup_frames, "t": (i + 0.5) * TIME_LOOP / windup_frames, "look": look}])
	if "charge" in want:
		for i in 2:
			out.append(["charge", 0, {"state": "charge", "charge": 1.0, "moving": 1.0, "walk": i * PI, "t": (i + 0.5) * TIME_LOOP / 2.0}])
	if "recover" in want:
		out.append(["recover", 0, {"state": "recover", "t": TIME_LOOP * 0.5}])
	for i in strike_frames:
		out.append(["strike", 0, {"strike": (i + 0.5) / strike_frames, "t": TIME_LOOP * 0.5}])
	for i in HIT_POSES.size():
		out.append(["hit", 0, {"hit": HIT_POSES[i], "t": TIME_LOOP * 0.5}])
	# Poses propres du comportement : les clés déclarées avant valent 1 pendant la cuisson des suivantes
	# (Mandragore : « under », puis « rising » qui sort de terre).
	var before := {}
	for c in _custom_of(art):
		var n: int = c[1]
		for i in n:
			var o := before.duplicate()
			o["t"] = (i + 0.5) * TIME_LOOP / n
			if c[2]:
				o["state"] = c[0]
			else:
				o[c[0]] = 1.0 if n == 1 else float(i) / (n - 1)
			out.append(["c:" + c[0], 0, o])
		if not c[2]:
			before[c[0]] = 1.0
	return out


## const CUSTOM d'un script : [[clé ou état, images, état ?], ...].
static func _custom_of(art) -> Array:
	var out := []
	if art == null:
		return out
	var cm: Dictionary = art.get_script_constant_map()
	if not cm.has("CUSTOM"):
		return out
	for k in cm["CUSTOM"]:
		var n := maxi(1, int(cm["CUSTOM"][k]))
		var key := str(k)
		if key.begins_with("state:"):
			out.append([key.substr(6), n, true])
		else:
			out.append([key, n, false])
	return out


static func _const(art, name: String, default):
	if art == null:
		return default
	var cm: Dictionary = art.get_script_constant_map()
	return cm.get(name, default)


# --- Cuisson ---

## Clé de l'atlas d'élite d'une sorte qui dessine elle-même ses marques d'élite (DRAWS_ELITE).
static func elite_key(kind_id: String, region: String) -> String:
	return "%s@elite@%s" % [kind_id, region]


## Atlas d'une clé ; une élite pas encore cuite prend l'atlas de sa sorte.
static func atlas_of(key: String) -> Atlas:
	var a: Atlas = atlases.get(key)
	if a == null and "@" in key:
		a = atlases.get(key.get_slice("@", 0))
	return a


## Demande la cuisson d'une sorte apparue sans atlas (faite par pump à l'image suivante) ; extra :
## {"elite": true, "region": id} pour l'atlas d'élite d'une sorte DRAWS_ELITE.
static func request(kind_id: String, extra := {}) -> void:
	var key := kind_id if extra.is_empty() else elite_key(kind_id, str(extra.get("region", "")))
	if enabled and not atlases.has(key) and not _failed.has(key) and _kinds().has(kind_id):
		_wanted[key] = [kind_id, float(_kinds()[kind_id]["radius"]), extra]


## Cuit les sortes demandées (appelé à chaque image par main.gd).
static func pump(host: Node) -> void:
	if _busy or _wanted.is_empty():
		return
	var kinds := _wanted.values()
	_wanted.clear()
	bake(host, kinds)


## Cuit les sortes demandées ([[id, rayon], ...] ou [id, ...]) ; host : un nœud de l'arbre (pour les
## SubViewport). Coroutine : attend le rendu des SubViewport (une ou deux images).
static func bake(host: Node, kinds: Array) -> void:
	while _busy:
		await RenderingServer.frame_post_draw
	_busy = true
	var t0 := Time.get_ticks_usec()
	var todo_old := []
	var todo_new := []
	for kr in kinds:
		var kind_id: String = kr[0] if kr is Array else str(kr)
		var r: float = kr[1] if kr is Array else float(_kinds().get(kind_id, {}).get("radius", 14.0))
		var extra: Dictionary = kr[2] if kr is Array and kr.size() > 2 else {}
		var art = script_of(kind_id)
		if art == null:
			extra = {}
		var key := kind_id if extra.is_empty() else elite_key(kind_id, str(extra.get("region", "")))
		if atlases.has(key) or _failed.has(key):
			continue
		if use_cache:
			var cached := _load_cached(key, r)
			if cached != null:
				cached.last_used = Time.get_ticks_msec()
				atlases[key] = cached
				cache_hits += 1
				continue
		if art != null:
			todo_new.append([kind_id, r, art, extra, key])
		else:
			todo_old.append([kind_id, r])
	var jobs := []
	for kr in todo_old:
		jobs.append(_job_old(host, kr[0], kr[1]))
	build_usec += Time.get_ticks_usec() - t0
	if not todo_new.is_empty():
		# Première passe, petite : place prise par chaque image, images identiques, ombre relevée.
		var probes := []
		for kr in todo_new:
			probes.append(_probe(host, kr[0], kr[1], kr[2], kr[3], kr[4]))
		await RenderingServer.frame_post_draw
		var t1 := Time.get_ticks_usec()
		for pr in probes:
			var j = _job_new(host, pr)
			if j != null:
				jobs.append(j)
		build_usec += Time.get_ticks_usec() - t1
	if not jobs.is_empty():
		await RenderingServer.frame_post_draw
		var t2 := Time.get_ticks_usec()
		for j in jobs:
			_finish(j[0], j[1])
		finish_usec += Time.get_ticks_usec() - t2
	bake_usec += Time.get_ticks_usec() - t0
	_busy = false
	trim()


## Rend les atlas qui n'ont pas servi depuis UNUSED_MSEC tant que la mémoire dépasse le budget.
static func trim() -> int:
	var freed := 0
	var total := total_bytes()
	if total <= budget:
		return 0
	var now := Time.get_ticks_msec()
	var old := []
	for k in atlases:
		var a: Atlas = atlases[k]
		if now - a.last_used >= UNUSED_MSEC:
			old.append([a.last_used, k])
	old.sort()
	for it in old:
		if total <= budget:
			break
		total -= atlases[it[1]].bytes
		atlases.erase(it[1])
		freed += 1
		evicted += 1
	return freed


## Image rendue d'un SubViewport, ou null sans rendu (--headless).
static func _read(vp: SubViewport) -> Image:
	var tex := vp.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	return img


static func _finish(a: Atlas, vp: SubViewport) -> void:
	var img := _read(vp)
	if img == null:
		_failed[a.key] = true
		return
	if ss > 1:
		# Trilinéaire : la réduction passe par les mipmaps, une moyenne de boîte exacte pour ss = 2 ou 4.
		img.resize(img.get_width() / ss, img.get_height() / ss, Image.INTERPOLATE_TRILINEAR)
	img.generate_mipmaps()
	a.tex = ImageTexture.create_from_image(img)
	a.bytes = img.get_data_size()
	a.last_used = Time.get_ticks_msec()
	atlases[a.key] = a
	if use_cache:
		_save_cached(a, img)


static func _viewport(host: Node, size: Vector2i, painter: Node2D) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.add_child(painter)
	host.add_child(vp)
	return vp


## Ancien dessin (vu de dessus) : lots de triangles exacts, images identiques dédoublonnées.
static func _job_old(host: Node, kind_id: String, r: float) -> Array:
	var a := Atlas.new()
	a.kind_id = kind_id
	a.key = kind_id
	a.base_r = r
	a.bake_scale = scale
	a.shadow_c = Vector2(0, r * Art.OMBRE_DECALAGE * 0.5)
	a.shadow_r = Vector2(r * 1.05, r * 0.75)
	var b = DrawBatch.new()
	b.exact = true
	var frames := []
	var boxes := []
	var seen := {}
	for p in _poses_old(kind_id):
		var o: Dictionary = p[2].duplicate()
		o["no_squash"] = true
		FletriArt.draw(b, kind_id, Vector2.ZERO, r, Vector2.RIGHT, p[3], o)
		var key := hash([b.points, b.colors])
		if not seen.has(key):
			seen[key] = frames.size()
			frames.append([b.points.duplicate(), b.colors.duplicate(), b.indices.duplicate()])
			var box := Rect2(b.points[0], Vector2.ZERO) if not b.points.is_empty() else Rect2(-Vector2.ONE, Vector2.ONE * 2.0)
			for q in b.points:
				box = box.expand(q)
			boxes.append(box)
		if not a.anims.has(p[0]):
			a.anims[p[0]] = [[]]
		a.anims[p[0]][0].append(seen[key])
		a.total += 1
		b.clear()
	a.unique = frames.size()
	a.top = -r
	a.neck = Vector2(0, -r * 0.4)
	var size := _pack(a, boxes)
	var painter := Painter.new()
	for i in frames.size():
		var origin := a.src(i).position + a.anchor(i)
		painter.items.append([Transform2D(0.0, Vector2(scale, scale) * ss, 0.0, origin * ss)] + frames[i])
	return [a, _viewport(host, size * ss, painter)]


## Range les images (places en pixels du jeu, relatives à la position) dans l'atlas, par étagères :
## les plus hautes d'abord, de gauche à droite. Rend la taille de l'atlas (pixels de l'atlas).
static func _pack(a: Atlas, boxes: Array) -> Vector2i:
	var sizes := []
	var area := 0.0
	for i in boxes.size():
		var bx: Rect2 = boxes[i]
		var sz := (bx.size * a.bake_scale).ceil() + Vector2.ONE * PAD * 2
		sizes.append([i, sz])
		area += sz.x * sz.y
		a.cell = a.cell.max(sz)
	sizes.sort_custom(func(u, v): return u[1].y > v[1].y)
	var width := maxf(a.cell.x, ceilf(sqrt(area) * 1.15))
	a.frames.resize(boxes.size())
	var x := 0.0
	var y := 0.0
	var row_h := 0.0
	var w := 0.0
	for it in sizes:
		var sz: Vector2 = it[1]
		if x + sz.x > width:
			x = 0.0
			y += row_h
			row_h = 0.0
		var bx: Rect2 = boxes[it[0]]
		a.frames[it[0]] = [Rect2(Vector2(x, y), sz), -bx.position * a.bake_scale + Vector2.ONE * PAD]
		x += sz.x
		w = maxf(w, x)
		row_h = maxf(row_h, sz.y)
	return Vector2i(ceili(w), ceili(y + row_h))


## Dessin d'une sorte dessinée : pieds sous la position, hauteur HEIGHT, tourné vers la droite.
static func _feet(r: float) -> Vector2:
	return Vector2(0, FEET * r)


## Première passe d'une sorte dessinée : toutes les poses, petites, dans une case large.
static func _probe(host: Node, kind_id: String, r: float, art, extra := {}, key := "") -> Dictionary:
	var h: float = float(_const(art, "HEIGHT", 40.0))
	var poses := _poses_scripted(kind_id, art)
	for p in poses:
		p[2].merge(extra, true)
	var cell := (Vector2(3.0, 2.2) * h * PROBE_SCALE).ceil()
	# Position du Flétri dans la case : centrée, assez bas pour la tête et les effets au-dessus.
	var origin := Vector2(cell.x * 0.5, cell.y * 0.62)
	var cols := ceili(sqrt(poses.size()))
	var rows := ceili(float(poses.size()) / cols)
	var painter := ScriptPainter.new()
	painter.art = art
	painter.h = h
	painter.feet = _feet(r)
	painter.record = true
	for i in poses.size():
		var at := Vector2(i % cols, i / cols) * cell + origin
		painter.items.append([Transform2D(0.0, Vector2.ONE * PROBE_SCALE, 0.0, at), poses[i][2]])
	var vp := _viewport(host, Vector2i(cell * Vector2(cols, rows)), painter)
	return {"kind_id": kind_id, "key": key if key != "" else kind_id, "r": r, "art": art, "h": h, "poses": poses, "cell": cell, "origin": origin, "cols": cols, "vp": vp, "painter": painter}


## Deuxième passe : cases ajustées à la place prise, images identiques cuites une fois.
static func _job_new(host: Node, pr: Dictionary):
	var painter: ScriptPainter = pr["painter"]
	var shadows: Array = painter.shadows.duplicate()
	var img := _read(pr["vp"])
	if img == null:
		_failed[pr["key"]] = true
		return null
	var poses: Array = pr["poses"]
	var cell: Vector2 = pr["cell"]
	var origin: Vector2 = pr["origin"]
	var cols: int = pr["cols"]
	var a := Atlas.new()
	a.kind_id = pr["kind_id"]
	a.key = pr["key"]
	a.base_r = pr["r"]
	a.bake_scale = scale
	a.scripted = true
	var art = pr["art"]
	var h: float = pr["h"]
	a.custom = _custom_of(art)
	a.draws_elite = bool(_const(art, "DRAWS_ELITE", false))
	var feet := _feet(a.base_r)
	var neck_l: Vector2 = _const(art, "NECK", Vector2(0, -50))
	a.neck = feet + neck_l * h / 100.0
	var seen := {}
	var uniq := []
	var boxes := []
	for i in poses.size():
		var cr := Rect2i(Vector2i(Vector2(i % cols, i / cols) * cell), Vector2i(cell))
		var sub := img.get_region(cr)
		var used := sub.get_used_rect()
		var key := hash(sub.get_data()) if used.size != Vector2i.ZERO else 0
		if not seen.has(key):
			seen[key] = uniq.size()
			uniq.append(i)
			var ur := Rect2(-Vector2.ONE * 2.0, Vector2.ONE * 4.0)
			if used.size != Vector2i.ZERO:
				ur = Rect2((Vector2(used.position) - origin) / PROBE_SCALE, Vector2(used.size) / PROBE_SCALE)
				if used.position.x == 0 or used.position.y == 0 or used.end.x >= int(cell.x) or used.end.y >= int(cell.y):
					push_warning("Sprites : le dessin de %s sort de la case de repérage (pose %s)" % [a.kind_id, poses[i][0]])
			# Un peu de marge (repérage à petite échelle).
			boxes.append(ur.grow(1.5))
		var p: Array = poses[i]
		if not a.anims.has(p[0]):
			a.anims[p[0]] = []
		while a.anims[p[0]].size() <= p[1]:
			a.anims[p[0]].append([])
		a.anims[p[0]][p[1]].append(seen[key])
		a.total += 1
	a.unique = uniq.size()
	# Haut du dessin au repos, droit devant (barre de vie, nom d'élite).
	a.top = 0.0
	var idle: Array = a.anims["idle"][mini(1, a.anims["idle"].size() - 1)]
	for j in idle:
		a.top = minf(a.top, boxes[j].position.y + 1.5)
	if not shadows.is_empty():
		var sr: Rect2 = shadows[0]
		a.shadow_c = sr.get_center()
		a.shadow_r = sr.size * 0.5
	else:
		a.shadow_c = feet
		a.shadow_r = Vector2(h * 0.3, h * 0.3 * Art.OMBRE_APLATI)
	# Une sorte grande ou très animée est cuite un peu moins fin (pas sous MIN_SCALE) pour que son
	# atlas tienne dans KIND_TARGET : la mémoire des 30 sortes reste bornée quand toutes sont dessinées.
	var area := 0.0
	for bx in boxes:
		area += (bx.size.x * scale + PAD * 2) * (bx.size.y * scale + PAD * 2)
	var est := area * 4.0 * 4.0 / 3.0
	if est > KIND_TARGET:
		a.bake_scale = maxf(MIN_SCALE, scale * sqrt(KIND_TARGET / est))
	var size := _pack(a, boxes)
	var out := ScriptPainter.new()
	out.art = art
	out.h = h
	out.feet = feet
	for j in uniq.size():
		var at := (a.src(j).position + a.anchor(j)) * ss
		out.items.append([Transform2D(0.0, Vector2.ONE * a.bake_scale * ss, 0.0, at), poses[uniq[j]][2]])
	return [a, _viewport(host, size * ss, out)]


## Dessine les lots de triangles des images, chacun à sa place dans l'atlas.
class Painter extends Node2D:
	var items := []

	func _draw() -> void:
		var rid := get_canvas_item()
		for it in items:
			RenderingServer.canvas_item_add_set_transform(rid, it[0])
			RenderingServer.canvas_item_add_triangle_array(rid, it[3], it[1], it[2])
		RenderingServer.canvas_item_add_set_transform(rid, Transform2D.IDENTITY)


## Dessine les poses d'un script creature_art, chacune à sa place ; l'ombre au sol est relevée, pas dessinée.
class ScriptPainter extends Node2D:
	var items := []
	var art
	var h := 40.0
	var feet := Vector2.ZERO
	var record := false
	## Place de l'ombre de chaque pose (pixels du jeu, relatifs à la position), première passe.
	var shadows := []

	func _draw() -> void:
		Ink.mono = false
		Ink.no_shadow = true
		for it in items:
			Ink.shadow_seen = Rect2()
			draw_set_transform_matrix(it[0])
			art.draw(self, feet, h, it[1])
			if record and Ink.shadow_seen.size != Vector2.ZERO:
				shadows.append(Ink.shadow_seen)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		Ink.no_shadow = false
		Ink.flash = 0.0


# --- En jeu ---

## Vrai si cette pose a son image dans un atlas (ancien dessin : pas les poses « live » ni les
## états inconnus ; sorte dessinée : tout, une pose propre non déclarée retombe sur repos/marche).
static func usable(o: Dictionary, a: Atlas = null) -> bool:
	if o.has("ash") or o.has("mono"):
		return false
	if a != null and a.scripted:
		return true
	if o.has("live"):
		return false
	return o.get("state", "") in ["", "windup", "charge", "recover"]


static func _pick(a: Atlas, anim: String, li: int) -> Array:
	var per: Array = a.anims[anim]
	return per[clampi(li, 0, per.size() - 1)] if per.size() > 1 else per[0]


## Case de l'atlas pour cette pose. li : regard (indice dans LOOKS, 1 = droit devant).
static func frame_of(a: Atlas, o: Dictionary, t: float, li := 1) -> int:
	var state: String = o.get("state", "")
	var list: Array = []
	var u := 0.0
	if a.scripted:
		for ci in range(a.custom.size() - 1, -1, -1):
			var c: Array = a.custom[ci]
			if (c[2] and state == c[0]) or (not c[2] and float(o.get(c[0], 0.0)) > 0.0):
				list = _pick(a, "c:" + c[0], 0)
				u = fposmod(t, TIME_LOOP) / TIME_LOOP if c[2] else clampf(float(o.get(c[0], 0.0)), 0.0, 1.0)
				if not c[2]:
					return list[clampi(roundi(u * (list.size() - 1)), 0, list.size() - 1)]
				break
		if list.is_empty() and float(o.get("flash", 0.0)) > 0.0 and a.anims.has("hit"):
			list = _pick(a, "hit", 0)
			return list[0 if float(o["flash"]) > 0.5 else list.size() - 1]
	if not list.is_empty():
		pass
	elif state == "windup" and a.anims.has("windup"):
		list = _pick(a, "windup", li)
		u = float(o.get("k", 0.0))
	elif state == "charge" and a.anims.has("charge"):
		list = _pick(a, "charge", 0)
		u = fposmod(t, TIME_LOOP) / TIME_LOOP
	elif state == "recover" and a.anims.has("recover"):
		list = _pick(a, "recover", 0)
	elif float(o.get("strike", -1.0)) >= 0.0:
		list = _pick(a, "strike", 0)
		u = float(o["strike"])
	elif float(o.get("moving", 0.0)) >= 0.5:
		list = _pick(a, "walk", li)
		u = fposmod(float(o.get("walk", 0.0)), TAU) / TAU
	else:
		list = _pick(a, "idle", li)
		u = fposmod(t, TIME_LOOP) / TIME_LOOP
	return list[clampi(int(u * list.size()), 0, list.size() - 1)]


## Regard : vers la droite ou vers la gauche (avec hystérésis), plus une inclinaison bornée (ancien
## dessin) et le regard cuit le plus proche (sorte dessinée). Rend [signe, inclinaison, regard].
static func facing(face: Vector2, prev_sign: float) -> Array:
	var s := prev_sign
	# Un peu d'hystérésis : un Flétri qui monte droit vers le héros ne clignote pas.
	if face.x > 0.15:
		s = 1.0
	elif face.x < -0.15:
		s = -1.0
	var base := 0.0 if s > 0.0 else PI
	var d := angle_difference(base, face.angle())
	# Côté droit : un angle négatif regarde vers le haut ; retourné, l'angle se lit en miroir.
	var la := d if s > 0.0 else -d
	var li := 1
	if la < -0.22:
		li = 0
	elif la > 0.22:
		li = 2
	return [s, clampf(d, -TILT, TILT), li]


## Échelle de l'image : rayon de l'ennemi (une élite a un plus grand rayon) rapporté à celui de la sorte.
static func size_of(a: Atlas, r: float) -> float:
	if a.scripted:
		return ELITE_SCALE if r > a.base_r * 1.05 else 1.0
	return r / a.base_r


## Dessine dans ci (son matériau : material()) l'image de la pose. Faux si la pose n'est pas cuite.
static func draw(ci: CanvasItem, kind_id: String, r: float, sgn: float, tilt: float, t: float, o: Dictionary, li := 1) -> bool:
	var a: Atlas = atlas_of(kind_id)
	if a == null or not usable(o, a):
		return false
	drawn += 1
	a.last_used = Time.get_ticks_msec()
	var i := frame_of(a, o, t, li)
	var k := size_of(a, r) / a.bake_scale
	if a.scripted:
		ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(k * sgn, k), 0.0, Vector2.ZERO))
	else:
		var sq := FletriArt.squash(o, t)
		ci.draw_set_transform_matrix(Transform2D(tilt, Vector2(k * sq.x * sgn, k * sq.y), 0.0, Vector2.ZERO))
	# Teinte : couleur visée en rgb, part de teinte en 1 - alpha (shaders/sprite_tint.gdshader).
	# L'éclair du coup reçu d'une sorte dessinée est cuit (pose « hit »).
	var mod := Color(1, 1, 1, 1)
	var fl: float = o.get("flash", 0.0)
	var tint: Color = o.get("tint", Color(0, 0, 0, 0))
	if fl > 0.0 and not a.scripted:
		mod = Color(Art.c("danger_eclair"), 1.0 - 0.85 * fl)
	elif tint.a > 0.0:
		mod = Color(tint, 1.0 - tint.a)
	ci.draw_texture_rect_region(a.tex, Rect2(-a.anchor(i), a.src(i).size), a.src(i), mod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true


## Image cuite d'une pose, pour les autres systèmes (morts, impact frames) : {} si rien n'est cuit,
## sinon {"tex", "src" (pixels de l'atlas), "rect" (pixels du jeu, relatif à la position du Flétri,
## rayon de base, élite non comprise), "r"}. Le retournement reste à l'appelant.
static func frame(kind_id: String, o := {}, t := 0.0) -> Dictionary:
	var a: Atlas = atlas_of(kind_id)
	if a == null:
		return {}
	var p := o.duplicate()
	p.erase("mono")
	p.erase("ash")
	var li := 1
	if p.has("look"):
		li = 0 if float(p["look"]) < -0.22 else (2 if float(p["look"]) > 0.22 else 1)
	var i := frame_of(a, p, t, li)
	return {"tex": a.tex, "src": a.src(i), "rect": a.rect(i), "r": a.base_r}


## Même image, pour une silhouette d'une seule couleur (l'appelant teinte, sprite_tint.gdshader :
## modulate = Color(couleur, 0.0)).
static func mono(kind_id: String, o := {}, t := 0.0) -> Dictionary:
	return frame(kind_id, o, t)


## Mémoire des atlas cuits (octets, mipmaps comprises).
static func total_bytes() -> int:
	var n := 0
	for a in atlases.values():
		n += a.bytes
	return n


static func clear() -> void:
	atlases.clear()
	_wanted.clear()
	_failed.clear()
	bake_usec = 0
	build_usec = 0
	finish_usec = 0
	cache_hits = 0
	cache_writes = 0
	evicted = 0
	drawn = 0
	fallback = 0
