## Planche et GIF du héros en jeu (refonte des personnages, tâche H) : l'Esprit masqué tel que le jeu le
## dessine (HeroArt avec les atlas cuits de hero_bake.gd), avant / après, selon le build.
## Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --resolution 2560x1440 -s res://tests/bestiaire/heros_jeu.gd -- planche.png
##   tools/godot.sh --xvfb --resolution 1280x720 -s res://tests/bestiaire/heros_jeu.gd -- --gif DOSSIER
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const HeroBake = preload("res://scripts/hero_bake.gd")
const Arme = preload("res://scripts/creature_art/heros/arme.gd")

const W := 2560
const H := 1440
const S := C.S1080

const DEPART := {"voie": {}, "evol": 0.0, "forme": "graine", "mods": []}
const RONCE := {"voie": {"ronce": 1.0}, "evol": 0.72, "forme": "fouet", "mods": ["fourche", "saignement"]}
const PARCOURS := [
	["Départ", {"voie": {}, "evol": 0.0, "forme": "graine", "mods": []}],
	["Ronce, 1er palier", {"voie": {"ronce": 1.0}, "evol": 0.4, "forme": "echarde", "mods": ["fourche"]}],
	["Ronce, 2e palier", {"voie": {"ronce": 1.0}, "evol": 0.72, "forme": "fouet", "mods": ["fourche", "saignement"]}],
	["Ronce + Vent", {"voie": {"ronce": 0.6, "vent": 0.4}, "evol": 1.0, "forme": "lame", "mods": ["fourche", "saignement", "elan"]}],
	["Sève (oubli, nouveau build)", {"voie": {"seve": 1.0}, "evol": 1.0, "forme": "perle", "mods": ["rosee", "sangsue"]}],
	["Aube + Racine", {"voie": {"aube": 0.6, "racine": 0.4}, "evol": 1.0, "forme": "rayon", "mods": ["refraction", "renforcee", "eblouit"]}],
]
const BR := {"ronce": "Ronce", "seve": "Sève", "racine": "Racine", "vent": "Vent", "spore": "Spore", "aube": "Aube"}

var b
var host: Node
var font: FontFile
var canvas: Image
var atlases := {}
var texts := []


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	b = Bake.new(self)
	# Planche en grand : atlas cuits à ×4 (en jeu, l'échelle suit la fenêtre).
	HeroBake.scale = 4.0
	HeroBake.keep = 64
	host = Node.new()
	root.add_child(host)
	font = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	if args.size() >= 2 and args[0] == "--gif":
		await _gif(args[1])
	else:
		await _planche(args[0])
	quit()


func _sp(look: Dictionary) -> Dictionary:
	var k := str(look)
	if not atlases.has(k):
		atlases[k] = await HeroBake.bake(host, look)
	return atlases[k]


## Dessine le héros (rendu du jeu) : pieds en feet, échelle k (1 : px du jeu en 1600×900).
func _hero(ci: CanvasItem, sp: Dictionary, feet: Vector2, k: float, facing: float, st: Dictionary, prev := {}) -> void:
	HeroArt.sprites = sp
	HeroArt.prev_sprites = prev
	HeroArt.base = Transform2D(0.0, Vector2(k, k), 0.0, feet - Vector2(0, 14.0 * k))
	HeroArt.draw(ci, Vector2.ZERO, 14.0, facing, st)
	HeroArt.base = Transform2D.IDENTITY
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _old(ci: CanvasItem, feet: Vector2, k: float, facing: float, st: Dictionary) -> void:
	HeroArt.legacy = true
	HeroArt.base = Transform2D(0.0, Vector2(k, k), 0.0, feet - Vector2(0, 14.0 * k))
	HeroArt.draw(ci, Vector2.ZERO, 14.0, facing, st)
	HeroArt.base = Transform2D.IDENTITY
	HeroArt.legacy = false
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _planche(out: String) -> void:
	canvas = Image.create(W, H, false, Image.FORMAT_RGBA8)
	canvas.fill(Art.c("papier_sombre"))
	_text("Le Porte-Graine en jeu : l'Esprit masqué", Vector2(24, 14), 44, Art.c("or"))
	_text("Dessin du jeu (atlas cuits à chaque changement de build). La tenue suit les branches et les paliers de l'Arbre, l'arme suit l'attaque de base et ses modifications.\nEn grand : ×3 la taille à l'écran en 1080p ; à droite de chaque case, la taille réelle en 1080p sur le sol de Ronce.", Vector2(24, 66), 19, Art.c("texte_doux"))
	# Ligne 1 : avant / après.
	var y := 140
	_text("Avant / après (même pose, même taille de collision)", Vector2(24, y), 24, Art.c("texte"))
	var sp_dep: Dictionary = await _sp(DEPART)
	var sp_ronce: Dictionary = await _sp(RONCE)
	var cells := [["Avant (jusqu'au 25/11)", "old", {}], ["Après : départ", "new", sp_dep], ["Après : Ronce, 2e palier", "new", sp_ronce]]
	for i in cells.size():
		var x := 16 + i * 420
		var c: Array = cells[i]
		var img: Image = await b.bake(Vector2i(410, 390), func(ci):
			ci.draw_rect(Rect2(0, 0, 410, 390), Art.c("papier"))
			C.draw_ground(ci, Rect2(290, 250, 110, 130), "ronce", 3 + i)
			if c[1] == "old":
				_old(ci, Vector2(150, 330), 3.0 * S, 0.3, {"t": 0.6})
				_old(ci, Vector2(345, 350), S, 0.3, {"t": 0.6})
			else:
				_hero(ci, c[2], Vector2(150, 330), 3.0 * S, 0.3, {"t": 0.6})
				_hero(ci, c[2], Vector2(345, 350), S, 0.3, {"t": 0.6}))
		canvas.blend_rect(img, Rect2i(0, 0, 410, 390), Vector2i(x, y + 34))
		_text(c[0], Vector2(x + 12, y + 40), 18, Art.c("or"))
	# Ligne 1 (suite) : les poses en jeu.
	var poses := [["Marche", {"walk": 1.0, "step": 1.2}], ["Esquive", {"dash": 0.8}], ["Coup reçu", {"hurt": 0.7}],
		["Lancer", {"cast": 0.7, "cast_col": Art.ec("epine")}], ["Vie basse", {"low": 1.0, "t": 0.05}], ["Il se fane", {"wither": 0.6}], ["Renaissance", {"appear": 0.3}]]
	for i in poses.size():
		var x := 16 + 3 * 420 + i * 184
		var st: Dictionary = poses[i][1].duplicate()
		if not st.has("t"):
			st["t"] = 0.6
		var img: Image = await b.bake(Vector2i(178, 390), func(ci):
			ci.draw_rect(Rect2(0, 0, 178, 390), Art.c("papier"))
			_hero(ci, sp_ronce, Vector2(89, 300), 2.2 * S, 0.0, st))
		canvas.blend_rect(img, Rect2i(0, 0, 178, 390), Vector2i(x, y + 34))
		_text(poses[i][0], Vector2(x + 10, y + 40), 18, Art.c("or"))
	# Ligne 2 : chaque arme au coup.
	y = 580
	_text("Chaque arme au coup (tenue Racine + Aube, toutes les modifications cumulées sur la dernière)", Vector2(24, y), 24, Art.c("texte"))
	for i in Arme.FORMES.size():
		var f: String = Arme.FORMES[i]
		var lk := {"voie": {"racine": 0.5, "aube": 0.5}, "evol": 1.0, "forme": f, "mods": [] if i < Arme.FORMES.size() - 1 else Arme.ORNEMENTS.duplicate()}
		var sp: Dictionary = await _sp(lk)
		var x := 16 + i * 230
		var img: Image = await b.bake(Vector2i(224, 330), func(ci):
			ci.draw_rect(Rect2(0, 0, 224, 330), Art.c("papier"))
			_hero(ci, sp, Vector2(84, 290), 3.2 * S, 0.0, {"t": 0.4, "a": 0.53}))
		canvas.blend_rect(img, Rect2i(0, 0, 224, 330), Vector2i(x, y + 34))
		_text(f, Vector2(x + 10, y + 40), 18, Art.c("or"))
	# Ligne 3 : un parcours, build par build.
	y = 980
	_text("Un parcours : la tenue change à l'achat d'un nœud, à l'oubli et à la bascule de build", Vector2(24, y), 24, Art.c("texte"))
	for i in PARCOURS.size():
		var sp: Dictionary = await _sp(PARCOURS[i][1])
		var x := 16 + i * 420
		var img: Image = await b.bake(Vector2i(410, 410), func(ci):
			ci.draw_rect(Rect2(0, 0, 410, 410), Art.c("papier"))
			C.draw_ground(ci, Rect2(290, 270, 110, 130), "ronce", 9 + i)
			_hero(ci, sp, Vector2(150, 360), 3.0 * S, 0.3, {"t": 0.3 + i * 0.4})
			_hero(ci, sp, Vector2(345, 370), S, 0.3, {"t": 0.3 + i * 0.4}))
		canvas.blend_rect(img, Rect2i(0, 0, 410, 410), Vector2i(x, y + 34))
		_text(PARCOURS[i][0], Vector2(x + 12, y + 40), 18, Art.c("or"))
	await _finish_texts()
	canvas.save_png(out)
	print("planche : ", out)


## GIF (images successives) : marche et esquive, chaque arme qui frappe, puis le changement de build.
func _gif(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var n := 0
	var sp_r: Dictionary = await _sp(RONCE)
	var looks := []
	for f in Arme.FORMES:
		var br := "ronce"
		for k in Esprit_FORME():
			if Esprit_FORME()[k] == f:
				br = k
		looks.append(await _sp({"voie": {br: 1.0}, "evol": 0.72, "forme": f, "mods": ["fourche"]}))
	var steps := []
	for p in PARCOURS:
		steps.append(await _sp(p[1]))
	var size := Vector2i(1280, 720)
	# 1. Marche (aller-retour) et esquive : 72 images.
	for i in 72:
		var t := i / 24.0
		var img: Image = await b.bake(size, func(ci):
			C.draw_ground(ci, Rect2(Vector2.ZERO, Vector2(size)), "ronce", 5)
			var x := 640.0 + 260.0 * sin(t * 1.4)
			var sens := 1.0 if cos(t * 1.4) >= 0.0 else -1.0
			var st := {"t": t, "walk": 1.0, "step": t * 9.0}
			if i >= 54:
				st["dash"] = 1.0 - (i - 54) / 18.0
				st["walk"] = 0.0
			_hero(ci, sp_r, Vector2(x, 520), 4.0, 0.0 if sens > 0.0 else PI, st)
			_label(ci, "Marche, esquive", Vector2(24, 40)))
		_save(img, dir, n)
		n += 1
	# 2. Chaque arme frappe (deux attaques) : 60 images.
	for i in 60:
		var t := i / 24.0
		var img: Image = await b.bake(size, func(ci):
			C.draw_ground(ci, Rect2(Vector2.ZERO, Vector2(size)), "ronce", 6)
			for j in looks.size():
				var c := Vector2(110 + (j % 6) * 210, 330 + (j / 6) * 320)
				var a := fposmod(t * 1.2 + j * 0.05, 1.0)
				_hero(ci, looks[j], c, 2.6, 0.0, {"t": t, "a": a})
			_label(ci, "Chaque arme au coup", Vector2(24, 40)))
		_save(img, dir, n)
		n += 1
	# 3. Changement de build : transition entre les tenues du parcours.
	for s in range(1, steps.size()):
		for i in 30:
			var m := clampf(1.0 - i / 17.0, 0.0, 1.0)
			var img: Image = await b.bake(size, func(ci):
				C.draw_ground(ci, Rect2(Vector2.ZERO, Vector2(size)), "ronce", 7)
				_hero(ci, steps[s], Vector2(640, 600), 6.0, 0.0, {"t": (s * 30 + i) / 24.0, "morph": m}, steps[s - 1] if m > 0.0 else {})
				_label(ci, "Changement de build : " + PARCOURS[s][0], Vector2(24, 40)))
			_save(img, dir, n)
			n += 1
	print("images : ", n)


static func Esprit_FORME() -> Dictionary:
	return C.Esprit.FORME_DE


func _save(img: Image, dir: String, n: int) -> void:
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%03d.png" % [dir, n])


func _label(ci: CanvasItem, s: String, at: Vector2) -> void:
	ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Art.c("or"))


## Textes de la planche : posés à la fin, en une fois, par-dessus les cases.
func _text(s: String, at: Vector2, size: int, col: Color) -> void:
	texts.append([s, at, size, col])


func _finish_texts() -> void:
	var tex := ImageTexture.create_from_image(canvas)
	canvas = await b.bake(Vector2i(W, H), func(ci):
		ci.draw_texture(tex, Vector2.ZERO)
		for tx in texts:
			var y: float = tx[1].y + tx[2]
			for line in str(tx[0]).split("\n"):
				ci.draw_string(font, Vector2(tx[1].x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, tx[2], tx[3])
				y += tx[2] * 1.3, 1)
