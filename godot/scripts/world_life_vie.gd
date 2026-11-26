## Faune non hostile et formes guéries (refonte des personnages, vague 2 F) : images cuites en couleur.
##
## Chaque région a sa petite famille de faune (scripts/creature_art/<région>/vie/faune.gd) et ses formes
## guéries, une par sorte de Flétri (…/vie/gueri.gd ; « commun » pour les Flétris sans région). Tout est
## dessiné par le code avec l'encre commune du bestiaire, à la palette de la région (Art.bc : le mode
## daltonien suit), puis cuit une fois, ×SCALE et lissé, dans un atlas par région : en jeu,
## world_life.gd n'envoie que des quadrilatères texturés, tous dans un seul appel de rendu par région.
##
## Cuisson à la demande (la région où se trouve le héros, plus « commun ») et paresseuse : on ne garde que
## les atlas utiles (keep). Aucune règle de jeu ici : aucun chiffre, aucun hasard, aucune collision.
## Sans rendu (--headless) : pas d'atlas, la logique de world_life tourne quand même.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")

## Côté d'une case (px du jeu) et position des pieds dans la case.
const CELL := 72
const ANCHOR := Vector2(36.0, 60.0)
## Pixels de l'atlas par pixel du jeu, et suréchantillonnage du dessin.
const SCALE := 2
const SS := 1
const COLS := 8
## Régions, dans l'ordre des planches (commun : formes guéries des Flétris sans région, pas de faune).
const REGIONS := ["commun", "ronce", "spore", "vent", "seve", "aube", "racine"]
## Poses et nombre d'images par défaut (un script peut en demander d'autres).
const POSES := ["repos", "marche", "vol", "saut"]


## Un atlas : une image par (forme, pose, numéro).
class Sheet:
	var region := ""
	var tex: ImageTexture
	var bytes := 0
	## clé de forme -> {pose -> [Rect2 en pixels de l'atlas]}
	var rects := {}
	## clé de forme -> {"h", "poses", "v", "gueri", "id"}
	var forms := {}
	var order := []   # [clé, pose, i]


static var sheets := {}
static var _pending := {}
static var bake_usec := 0
static var _scripts := {}
## Mode daltonien au moment de la cuisson : s'il change, les atlas sont refaits.
static var baked_mode := "aucun"


## Script de dessin d'une région : « faune » ou « gueri » (null s'il n'existe pas).
static func script_of(reg: String, what: String):
	var path := "res://scripts/creature_art/%s/vie/%s.gd" % [reg, what]
	var k := reg + "/" + what
	if not _scripts.has(k):
		_scripts[k] = load(path) if ResourceLoader.exists(path) else null
	return _scripts[k]


## Clé d'une forme : « f:id » pour la faune, « g:id » pour une forme guérie.
static func key(id: String, gueri: bool) -> String:
	return ("g:" if gueri else "f:") + id


## Formes d'une région : [{"key", "id", "gueri", "h", "poses", "v"}…], faune puis guéris.
static func forms(reg: String) -> Array:
	var out := []
	for what in ["faune", "gueri"]:
		var s = script_of(reg, what)
		if s == null:
			continue
		for id in s.FORMES:
			var f: Dictionary = s.FORMES[id]
			out.append({"key": key(id, what == "gueri"), "id": id, "gueri": what == "gueri", "h": float(f["h"]),
				"poses": f["poses"], "v": float(f.get("v", 30.0)), "script": s})
	return out


## Dessin d'une forme (h, v, poses) lu dans le script de sa région ; {} si inconnue. Marche sans atlas.
static func info(reg: String, k: String) -> Dictionary:
	var s = script_of(reg, "gueri" if k.begins_with("g:") else "faune")
	var id := k.substr(2)
	if s == null or not s.FORMES.has(id):
		return {}
	return s.FORMES[id]


## Identifiants des formes guéries d'une région.
static func gueri_ids(reg: String) -> Array:
	var s = script_of(reg, "gueri")
	return s.FORMES.keys() if s != null else []


## Identifiants de la faune d'une région.
static func faune_ids(reg: String) -> Array:
	var s = script_of(reg, "faune")
	return s.FORMES.keys() if s != null else []


## Pose passée au dessin pour l'image i sur n d'une pose.
static func pose_of(id: String, pose: String, i: int, n: int) -> Dictionary:
	var u := i / float(maxi(n, 1))
	var o := {"sp": id, "pose": pose, "i": i, "n": n, "t": 0.0, "walk": 0.0, "moving": 0.0}
	match pose:
		"repos":
			o["t"] = (0.25 + 0.5 * u) * 2.4
		"marche":
			o["walk"] = TAU * u
			o["moving"] = 1.0
			o["t"] = 0.9 * u
		"vol":
			o["walk"] = TAU * u
			o["moving"] = 1.0
			o["air"] = 1.0
			o["t"] = 0.9 * u
		"saut":
			var s := i / float(maxi(n - 1, 1))
			o["lift"] = s
			o["t"] = 0.3
	return o


static func ready(reg: String) -> bool:
	return sheets.has(reg) and sheets[reg].tex != null


static func sheet(reg: String):
	return sheets.get(reg, null)


## Image d'une forme : Rect2 en pixels de l'atlas, ou Rect2() si absente.
static func frame(reg: String, k: String, pose: String, i: int) -> Rect2:
	var sh = sheets.get(reg, null)
	if sh == null or not sh.rects.has(k):
		return Rect2()
	var list: Array = sh.rects[k].get(pose, [])
	return list[i % list.size()] if not list.is_empty() else Rect2()


## Nombre d'images d'une pose d'une forme (0 si la forme n'a pas cette pose).
static func count(reg: String, k: String, pose: String) -> int:
	var sh = sheets.get(reg, null)
	if sh == null or not sh.rects.has(k):
		return 0
	return sh.rects[k].get(pose, []).size()


## Hauteur de dessin d'une forme (px du jeu pour 100 unités), 0 si inconnue.
static func height_of(reg: String, k: String) -> float:
	var sh = sheets.get(reg, null)
	return float(sh.forms[k]["h"]) if sh != null and sh.forms.has(k) else 0.0


## Ne garde que les atlas des régions données (le reste est rendu).
static func keep(regs: Array) -> void:
	for r in sheets.keys():
		if not (r in regs):
			sheets.erase(r)


static func clear() -> void:
	sheets.clear()
	_pending.clear()
	_scripts.clear()


## Recuit (changement de mode daltonien) : tout est oublié, les atlas utiles seront refaits à la demande.
static func invalidate() -> void:
	sheets.clear()


## Cuit l'atlas d'une région (une fois ; un SubViewport rendu une fois, lu à l'image suivante).
static func bake(host: Node, reg: String) -> void:
	if sheets.has(reg) or _pending.has(reg) or DisplayServer.get_name() == "headless":
		return
	var list := forms(reg)
	if list.is_empty():
		return
	_pending[reg] = true
	baked_mode = Art.mode_daltonien
	var t0 := Time.get_ticks_usec()
	var sh := Sheet.new()
	sh.region = reg
	for f in list:
		sh.forms[f["key"]] = f
		for pose in f["poses"]:
			for i in int(f["poses"][pose]):
				sh.order.append([f["key"], pose, i])
	var rows := int(ceil(sh.order.size() / float(COLS)))
	var k := SCALE * SS
	var vp := SubViewport.new()
	vp.size = Vector2i(COLS * CELL * k, rows * CELL * k)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_4X   # lissage du dessin sans cuire à une taille double
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	var painter := Painter.new()
	painter.k = k
	painter.sheet = sh
	painter.pose = pose_of
	vp.add_child(painter)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image() if vp.get_texture() != null else null
	vp.queue_free()
	_pending.erase(reg)
	if img == null or img.is_empty():
		return
	if SS > 1:
		img.resize(img.get_width() / SS, img.get_height() / SS, Image.INTERPOLATE_TRILINEAR)
	img.generate_mipmaps()
	sh.tex = ImageTexture.create_from_image(img)
	sh.bytes = img.get_data_size()
	var px := CELL * SCALE
	for n in sh.order.size():
		var kk: String = sh.order[n][0]
		var pose: String = sh.order[n][1]
		if not sh.rects.has(kk):
			sh.rects[kk] = {}
		if not sh.rects[kk].has(pose):
			sh.rects[kk][pose] = []
		sh.rects[kk][pose].append(Rect2((n % COLS) * px, (n / COLS) * px, px, px))
	sheets[reg] = sh
	bake_usec = Time.get_ticks_usec() - t0


## Dessine chaque image dans sa case (px du jeu × k), sans ombre au sol (world_life la dessine à part).
class Painter extends Node2D:
	var k := 4
	var sheet: Sheet
	var pose: Callable

	func _draw() -> void:
		var prev_shadow := Ink.no_shadow
		Ink.no_shadow = true
		Ink.mono = false
		Ink.flash = 0.0
		for n in sheet.order.size():
			var e: Array = sheet.order[n]
			var f: Dictionary = sheet.forms[e[0]]
			var cnt := int(f["poses"][e[1]])
			var corner := Vector2((n % COLS), (n / COLS)) * CELL * k
			f["script"].draw(self, corner + ANCHOR * k, float(f["h"]) * k, pose.call(f["id"], e[1], e[2], cnt))
		Ink.no_shadow = prev_shadow
