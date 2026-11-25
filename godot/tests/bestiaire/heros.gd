## Planche d'évolution du Porte-Graine (« Bestiaire d'herbier », planche v2) : la tenue de ninja de
## feuillage selon le stade de progression sur l'Arbre (1 → 3) et la branche dominante du build.
## Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --resolution 2560x1440 -s res://tests/bestiaire/heros.gd -- sortie.png
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")

const W := 2560
const H := 1440
const BIG := 5.5 * C.S1080

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
	_text("Porte-Graine : la tenue qui évolue avec l'Arbre", Vector2(24, 14), 44, Art.c("or"))
	_text("Ninja de feuillage, vu de trois quarts. Couleur des feuilles et du bandeau = branche dominante du build ; stade = progression sur l'Arbre et mutations prises.\nEn grand : ×5,5 la taille à l'écran en 1080p (~55 px de haut, contre ~34 px aujourd'hui). En bas de chaque case : taille réelle, sur le sol de Ronce.", Vector2(24, 66), 19, Art.c("texte_doux"))
	var top := 150
	# Aujourd'hui.
	var panel := Image.create(400, 1270, false, Image.FORMAT_RGBA8)
	panel.fill(Art.c("papier"))
	canvas.blend_rect(panel, Rect2i(0, 0, 400, 1270), Vector2i(16, top))
	_text("Aujourd'hui", Vector2(40, top + 14), 30, Art.c("texte"))
	var now: Image = await b.bake(Vector2i(380, 400), func(ci): C.draw_before(ci, "heros", 14.0, Vector2(190, 200), BIG, {"t": 0.5}, Vector2(1, 0.2).normalized()), 1)
	canvas.blend_rect(now, Rect2i(0, 0, 380, 400), Vector2i(26, top + 120))
	var stages := ["Stade 1 : début\nbandeau, capuche-masque, écharpe", "Stade 2 : milieu\népaulière, ceinture à graines, pans plus longs", "Stade 3 : branche maîtrisée\ncape de feuilles, couronne, mutation de la branche"]
	var builds := [["ronce", "Build Ronce"], ["seve", "Build Sève"]]
	for s in 3:
		_text(stages[s], Vector2(440 + s * 700, top - 6), 22, Art.c("texte"), 680)
	for r in builds.size():
		var y := top + 60 + r * 615
		for s in 3:
			var x := 430 + s * 700
			var o := {"t": 0.4 + s * 0.3, "look": 0.2, "build": builds[r][0], "stade": s + 1}
			var big: Image = await b.bake(Vector2i(690, 600), func(ci):
				ci.draw_rect(Rect2(0, 0, 690, 600), Art.c("papier"))
				C.draw_after(ci, "heros", Vector2(300, 545), BIG, o)
				C.draw_ground(ci, Rect2(470, 440, 210, 150), "ronce", 5 + s)
				C.draw_after(ci, "heros", Vector2(575, 545), C.S1080, o))
			canvas.blend_rect(big, Rect2i(0, 0, 690, 600), Vector2i(x, y))
			_text(builds[r][1], Vector2(x + 14, y + 10), 24, Art.c("or"))
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(canvas)
	root.add_child(tex)
	for l in labels:
		root.add_child(l)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit(0)


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
