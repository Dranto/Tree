## Images du GIF « marche, annonce, attaque, coup reçu » (« Bestiaire d'herbier », vague 0) : les six
## Flétris communs, avant (en haut) et après (en bas), sur le sol de leur région, à ×1,6 la taille
## à l'écran en 1080p. Une image par fichier, assemblées ensuite par tools/bestiaire-communs.sh.
## Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --resolution 1320x590 -s res://tests/bestiaire/communs/gif.gd -- DOSSIER
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const K = preload("res://tests/bestiaire/communs/communs.gd")

const CW := 210
const CH := 240
const FPS := 24.0
const FRAMES := 84
const ZOOM := 1.6 * C.S1080

var b
var font: FontFile


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


## Phase et avancement à l'image f : marche, annonce, attaque, repos, coup reçu, repos.
static func phase(f: int) -> Array:
	if f < 24:
		return ["marche", f / 24.0]
	if f < 44:
		return ["annonce", (f - 24) / 20.0]
	if f < 54:
		return ["attaque", (f - 44) / 10.0]
	if f < 60:
		return ["repos", 0.0]
	if f < 76:
		return ["coup reçu", (f - 60) / 16.0]
	return ["repos", 0.0]


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	b = Bake.new(self)
	font = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	var tex := TextureRect.new()
	tex.position = Vector2(20, 64)
	root.add_child(tex)
	var bg := ColorRect.new()
	bg.color = Art.c("papier_sombre")
	bg.size = Vector2(1320, 590)
	root.add_child(bg)
	root.move_child(bg, 0)
	var title := _label("", Vector2(20, 10), 30, Art.c("or"))
	_label("avant", Vector2(1290, 64 + CH * 0.5 - 24), 22, Art.c("texte_doux")).rotation = PI / 2.0
	_label("après", Vector2(1290, 64 + CH * 1.5 - 24), 22, Art.c("texte_doux")).rotation = PI / 2.0
	for f in FRAMES:
		var ph := phase(f)
		title.text = "Marche · annonce · attaque · coup reçu (×1,6 la taille en 1080p), Flétris communs — %s" % ph[0]
		var sheet := Image.create(CW * 6, CH * 2, false, Image.FORMAT_RGBA8)
		for i in K.CAST.size():
			var cc: Array = K.CAST[i]
			var c := {"id": cc[0], "r": cc[3], "region": "ronce"}
			var before: Image = await b.bake(Vector2i(CW, CH), func(ci): _cell_before(ci, c, i, f), 1)
			var after: Image = await b.bake(Vector2i(CW, CH), func(ci): _cell_after(ci, c, i, f))
			sheet.blit_rect(before, Rect2i(0, 0, CW, CH), Vector2i(i * CW, 0))
			sheet.blit_rect(after, Rect2i(0, 0, CW, CH), Vector2i(i * CW, CH))
		for i in 5:
			sheet.fill_rect(Rect2i((i + 1) * CW - 1, 0, 2, CH * 2), Art.c("papier_sombre"))
		sheet.fill_rect(Rect2i(0, CH - 1, CW * 6, 2), Art.c("papier_sombre"))
		tex.texture = ImageTexture.create_from_image(sheet)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png("%s/%03d.png" % [out, f])
	quit(0)


func _label(s: String, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.position = pos
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	root.add_child(l)
	return l


## Position au sol pendant la marche : il avance de gauche à droite puis revient au centre.
static func _x(f: int) -> float:
	var ph := phase(f)
	return lerpf(-40.0, 0.0, ph[1]) if ph[0] == "marche" else 0.0


func _cell_before(ci: CanvasItem, c: Dictionary, i: int, f: int) -> void:
	C.draw_ground(ci, Rect2(0, 0, CW, CH), c["region"], 31 + i)
	var ph := phase(f)
	var t := f / FPS
	var id: String = c["id"]
	var o := {"t": t}
	if id == "heros":
		match ph[0]:
			"marche":
				o["walk"] = 1.0
				o["step"] = ph[1] * TAU * 2.0
				o["move"] = Vector2.RIGHT
			"annonce":
				o["cast"] = ph[1]
			"attaque":
				o["shoot"] = 1.0 - ph[1]
			"coup reçu":
				o["hurt"] = 1.0 - ph[1]
	else:
		match ph[0]:
			"marche":
				o["walk"] = ph[1] * TAU * 2.0
				o["moving"] = 1.0
			"annonce":
				o["state"] = "windup"
				o["k"] = ph[1]
			"attaque":
				o["strike"] = ph[1]
				if id == "scarabee":
					o["state"] = "charge"
			"coup reçu":
				o["flash"] = 1.0 - ph[1]
	C.draw_before(ci, id, c["r"], Vector2(CW * 0.5 + _x(f), CH * 0.52), ZOOM * (0.8 if id == "colosse" else 1.0), o, Vector2(1, 0.25).normalized())


func _cell_after(ci: CanvasItem, c: Dictionary, i: int, f: int) -> void:
	C.draw_ground(ci, Rect2(0, 0, CW, CH), c["region"], 31 + i)
	var ph := phase(f)
	var id: String = c["id"]
	var o := {"t": f / FPS, "look": 0.2, "build": "ronce"}
	match ph[0]:
		"marche":
			o["walk"] = ph[1] * TAU * 2.0
			o["moving"] = 1.0
		"annonce":
			o["k"] = ph[1]
		"attaque":
			o["strike"] = ph[1]
			if id == "scarabee":
				o["charge"] = 1.0 - ph[1]
			if id == "heros":
				o["cast"] = 1.0 - ph[1]
		"coup reçu":
			o["hit"] = 1.0 - ph[1]
	if id == "cracheur" and ph[0] == "annonce":
		o["state"] = "windup"
	K.draw_after(ci, id, Vector2(CW * 0.5 + _x(f), CH * 0.9), ZOOM * (0.8 if id == "colosse" else 1.0), o)
