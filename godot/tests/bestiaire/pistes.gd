## Planche des pistes de héros (« Bestiaire d'herbier ») : trois créatures possibles, chacune à trois
## étapes de son parcours sur l'Arbre (build Ronce), puis mûre dans une autre branche, et à la taille
## réelle. Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --resolution 2560x1440 -s res://tests/bestiaire/pistes.gd -- sortie.png [piste]
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")

const W := 2560
const H := 1440
const TOP := 150
const LEFT := 330
const CW := 446
const RH := 424

const PISTES := [
	["sylve", "A · Esprit masqué", "Un petit esprit sous un masque de bois aux yeux de sève. Il s'étire, sa cape se déchire en feuilles, des bois poussent du masque, la graine couronne un bâton."],
	["bete", "B · Bête-graine", "Un petit animal-graine qui devient une bête fière, mi-renard mi-cerf : crinière de feuilles, bois, queue dont la pointe est la graine-lanterne."],
	["chevalier", "C · Chevalier-gland", "Un petit gland casqué qui devient un chevalier d'écorce : heaume à visière de sève, cape de feuilles, lame vivante, cœur de sève dans l'armure."],
]

var b
var font: FontFile
var canvas: Image
var labels: Array = []


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	b = Bake.new(self)
	font = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	canvas = Image.create(W, H, false, Image.FORMAT_RGBA8)
	canvas.fill(Art.c("papier_sombre"))
	_text("Porte-Graine : trois pistes de héros", Vector2(24, 14), 44, Art.c("or"))
	_text("Chaque piste garde la même créature du début à la fin et devient plus impressionnante à chaque palier de l'Arbre. La couleur de la branche passe dans les marques, les yeux et les ornements.\nEn grand : ×3,3 la taille à l'écran en 1080p (la créature grandit aussi). Dernière colonne : taille réelle sur le sol de Ronce, au début puis mûre.", Vector2(24, 66), 19, Art.c("texte_doux"))
	var cols := [["Au départ", 0.0, "ronce"], ["Mi-parcours (Ronce)", 0.5, "ronce"], ["Branche maîtrisée (Ronce)", 1.0, "ronce"], ["Maîtrisée, autre branche", 1.0, ""]]
	var alt := ["seve", "vent", "racine"]
	for c in cols.size():
		_text(cols[c][0], Vector2(LEFT + c * CW + 14, TOP - 6), 24, Art.c("texte"))
	_text("Taille réelle", Vector2(LEFT + 4 * CW + 14, TOP - 6), 24, Art.c("texte"))
	for r in PISTES.size():
		var id: String = PISTES[r][0]
		if args.size() > 1 and args[1] != id:
			continue
		var art = load("res://scripts/creature_art/heros/%s.gd" % id)
		var y := TOP + 26 + r * RH
		_box(Rect2i(16, y, LEFT - 26, RH - 10))
		_text(PISTES[r][1], Vector2(32, y + 12), 30, Art.c("or"))
		_text(PISTES[r][2], Vector2(32, y + 60), 18, Art.c("texte_doux"), LEFT - 60)
		for c in cols.size():
			var bd: String = cols[c][2] if cols[c][2] != "" else alt[r]
			var o := {"t": 0.4 + c * 0.6 + r * 0.3, "look": 0.2, "build": bd, "evol": cols[c][1]}
			var img: Image = await b.bake(Vector2i(CW - 10, RH - 10), func(ci):
				ci.draw_rect(Rect2(0, 0, CW - 10, RH - 10), Art.c("papier"))
				art.draw(ci, Vector2(CW * 0.46, RH - 60), art.HEIGHT * 3.3 * C.S1080, o))
			canvas.blend_rect(img, Rect2i(0, 0, CW - 10, RH - 10), Vector2i(LEFT + c * CW, y))
			if c == 3:
				_text("build " + {"seve": "Sève", "vent": "Vent", "racine": "Racine"}[bd], Vector2(LEFT + c * CW + 14, y + 10), 20, Art.c("texte_doux"))
		var real: Image = await b.bake(Vector2i(W - LEFT - 4 * CW - 16, RH - 10), func(ci):
			var sz := Vector2(W - LEFT - 4 * CW - 16, RH - 10)
			C.draw_ground(ci, Rect2(Vector2.ZERO, sz), "ronce", 4 + r)
			art.draw(ci, Vector2(sz.x * 0.3, sz.y * 0.62), art.HEIGHT * C.S1080, {"t": 0.4, "look": 0.2, "build": "ronce", "evol": 0.0})
			art.draw(ci, Vector2(sz.x * 0.68, sz.y * 0.62), art.HEIGHT * C.S1080, {"t": 0.9, "look": 0.2, "build": "ronce", "evol": 1.0})
			C.Ink.flash = 0.0)
		canvas.blend_rect(real, Rect2i(Vector2i.ZERO, real.get_size()), Vector2i(LEFT + 4 * CW, y))
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(canvas)
	root.add_child(tex)
	for l in labels:
		root.add_child(l)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit(0)


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
		var words := s.split(" ")
		var lines := [""]
		for wd in words:
			if (lines[-1] + " " + wd).length() * size * 0.42 > width and lines[-1] != "":
				lines.append(wd)
			else:
				lines[-1] = (lines[-1] + " " + wd).strip_edges()
		l.text = "\n".join(lines)
	if false:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
		l.size = Vector2(width, 0)
	labels.append(l)
