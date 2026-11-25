## Planche d'évolution du Porte-Graine (« Bestiaire d'herbier », planche v3) : une créature-graine qui
## se transforme avec les branches prises sur l'Arbre (silhouette, posture, visage, caractère), hybrides
## compris. Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --resolution 2560x1440 -s res://tests/bestiaire/heros.gd -- sortie.png
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")

const W := 2560
const H := 1440
const BIG := 3.3 * C.S1080
const TOP := 150
const PANEL := 360
const CW := 540
const RH := 318

var b
var font: FontFile
var canvas: Image
var labels: Array = []


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	b = Bake.new(self)
	font = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	canvas = Image.create(W, H, false, Image.FORMAT_RGBA8)
	canvas.fill(Art.c("papier_sombre"))
	_text("Porte-Graine : une créature qui évolue avec l'Arbre", Vector2(24, 14), 44, Art.c("or"))
	_text("Tout le monde part de la même petite graine. Chaque branche prise la transforme pour de bon : silhouette, posture, visage et caractère ; les branches se mêlent dans un build hybride.\nEn grand : ×3,3 la taille à l'écran en 1080p. En bas à droite de chaque case : taille réelle, sur le sol de la branche.", Vector2(24, 66), 19, Art.c("texte_doux"))
	# Colonne de gauche : la graine commune, et le héros d'aujourd'hui.
	_box(Rect2i(16, TOP, PANEL - 24, H - TOP - 16))
	_text("Au départ\nla graine commune", Vector2(36, TOP + 10), 26, Art.c("texte"))
	await _cell(Vector2i(26, TOP + 60), Vector2i(PANEL - 44, 420), {"t": 0.3, "look": 0.2}, "ronce", 1.25)
	_text("Aujourd'hui", Vector2(36, TOP + 560), 26, Art.c("texte"))
	var now: Image = await b.bake(Vector2i(PANEL - 44, 380), func(ci): C.draw_before(ci, "heros", 14.0, Vector2((PANEL - 44) / 2.0, 190), BIG * 1.25, {"t": 0.5}, Vector2(1, 0.2).normalized()), 1)
	canvas.blend_rect(now, Rect2i(0, 0, PANEL - 44, 380), Vector2i(26, TOP + 620))
	# Branches × progression.
	var rows := [["ronce", "Ronce : farouche", "se ramasse, crinière et queue d'épines, griffes, regard en fente"],
		["seve", "Sève : sereine", "s'allonge et flotte, corps translucide, pétales en ailes, lotus"],
		["racine", "Racine : têtue", "s'élargit, plaques d'écorce, mousse, bois de rameaux, pattes-souches"],
		["vent", "Vent : vive", "s'allège, aigrette de pissenlit, plumes-oreilles, grands yeux"]]
	var cols := [[0.35, "Premiers nœuds"], [0.7, "Mi-parcours"], [1.0, "Branche maîtrisée"]]
	var x0 := PANEL + 10
	for ci in cols.size():
		_text(cols[ci][1], Vector2(x0 + ci * CW + 14, TOP - 6), 24, Art.c("texte"))
	_text("Hybrides (branche maîtrisée)", Vector2(x0 + 3 * CW + 14, TOP - 6), 24, Art.c("texte"))
	var hybrids := [[{"ronce": 0.55, "seve": 0.45}, "Ronce + Sève", "ronce"], [{"racine": 0.55, "vent": 0.45}, "Racine + Vent", "racine"],
		[{"ronce": 0.5, "racine": 0.5}, "Ronce + Racine", "racine"], [{"seve": 0.5, "vent": 0.5}, "Sève + Vent", "vent"]]
	for r in rows.size():
		var y := TOP + 26 + r * RH
		for ci in cols.size():
			var o := {"t": 0.4 + ci * 0.37 + r * 0.2, "look": 0.2, "voie": {rows[r][0]: 1.0}, "evol": cols[ci][0]}
			await _cell(Vector2i(x0 + ci * CW, y), Vector2i(CW - 10, RH - 10), o, rows[r][0])
			if ci == 0:
				_text(rows[r][1], Vector2(x0 + 14, y + 8), 24, Art.c("or"))
				_text(rows[r][2], Vector2(x0 + 14, y + 38), 16, Art.c("texte_doux"), 240)
		var hy: Array = hybrids[r]
		await _cell(Vector2i(x0 + 3 * CW, y), Vector2i(CW - 10, RH - 10), {"t": 0.9 + r * 0.3, "look": 0.2, "voie": hy[0], "evol": 1.0}, hy[2])
		_text(hy[1], Vector2(x0 + 3 * CW + 14, y + 8), 24, Art.c("or"))
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(canvas)
	root.add_child(tex)
	for l in labels:
		root.add_child(l)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit(0)


## Une case : le héros en grand, et en bas à droite à la taille réelle sur le sol de la région.
func _cell(pos: Vector2i, size: Vector2i, o: Dictionary, region: String, k := 1.0) -> void:
	var img: Image = await b.bake(size, func(ci):
		ci.draw_rect(Rect2(Vector2.ZERO, size), Art.c("papier"))
		C.draw_after(ci, "heros", Vector2(size.x * 0.42, size.y - 34), BIG * k, o)
		C.draw_ground(ci, Rect2(size.x - 130, size.y - 110, 124, 104), region, 3)
		C.draw_after(ci, "heros", Vector2(size.x - 68, size.y - 30), C.S1080, o))
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, size), pos)


func _box(r: Rect2i) -> void:
	var img := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	img.fill(Art.c("papier"))
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, r.size), r.position)


func _text(s: String, pos: Vector2, size: int, col: Color, width := 0) -> void:
	var l := Label.new()
	l.text = s
	l.position = pos
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	if width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
		l.size = Vector2(width, 0)
	labels.append(l)
