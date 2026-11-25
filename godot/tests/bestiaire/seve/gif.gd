## Images du GIF « marche, annonce, attaque, coup reçu » des Flétris de Sève (R4) : avant (en haut) et
## après (en bas), sur le sol de la vallée, à ×2 la taille à l'écran en 1080p. Une image par fichier,
## assemblées ensuite par ffmpeg (voir tests/bestiaire/seve/planches.sh).
## Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --resolution 1270x590 -s res://tests/bestiaire/seve/gif.gd -- DOSSIER
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const P = preload("res://tests/bestiaire/seve/poses.gd")

const CW := 300
const CH := 250
const FPS := 24.0
const FRAMES := 84
const ZOOM := 2.0 * C.S1080

var b
var font: FontFile


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


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
	bg.size = Vector2(1270, 590)
	root.add_child(bg)
	root.move_child(bg, 0)
	var title := _label("", Vector2(20, 10), 30, Art.c("or"))
	_label("avant", Vector2(1258, 64 + CH * 0.5 - 24), 22, Art.c("texte_doux")).rotation = PI / 2.0
	_label("après", Vector2(1258, 64 + CH * 1.5 - 24), 22, Art.c("texte_doux")).rotation = PI / 2.0
	for f in FRAMES:
		var ph: Array = P.cycle("crapaud", f)
		title.text = "Flétris de Sève : marche · annonce · attaque · coup reçu (×2 la taille en 1080p) — %s" % ph[0]
		var sheet := Image.create(CW * 4, CH * 2, false, Image.FORMAT_RGBA8)
		for i in P.CAST.size():
			var c: Array = P.CAST[i]
			var before: Image = await b.bake(Vector2i(CW, CH), func(ci): _cell_before(ci, c, i, f), 1)
			var after: Image = await b.bake(Vector2i(CW, CH), func(ci): _cell_after(ci, c, i, f))
			sheet.blit_rect(before, Rect2i(0, 0, CW, CH), Vector2i(i * CW, 0))
			sheet.blit_rect(after, Rect2i(0, 0, CW, CH), Vector2i(i * CW, CH))
		for i in 3:
			sheet.fill_rect(Rect2i((i + 1) * CW - 1, 0, 2, CH * 2), Art.c("papier_sombre"))
		sheet.fill_rect(Rect2i(0, CH - 1, CW * 4, 2), Art.c("papier_sombre"))
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
	return lerpf(-40.0, 0.0, f / 24.0) if f < 24 else 0.0


func _cell_before(ci: CanvasItem, c: Array, i: int, f: int) -> void:
	C.draw_ground(ci, Rect2(0, 0, CW, CH), "seve", 31 + i)
	var id: String = c[0]
	var ph: Array = P.cycle(id, f)
	var o: Dictionary = ph[1].duplicate()
	o.erase("look")
	if o.has("hit"):
		o["flash"] = o["hit"]
		o.erase("hit")
	if o.get("state", "") == "leap":
		o["state"] = ""
	C.draw_before(ci, id, c[3], Vector2(CW * 0.5 + _x(f), CH * 0.52), ZOOM, o, Vector2(1, 0.25).normalized())


func _cell_after(ci: CanvasItem, c: Array, i: int, f: int) -> void:
	C.draw_ground(ci, Rect2(0, 0, CW, CH), "seve", 31 + i)
	var id: String = c[0]
	var ph: Array = P.cycle(id, f)
	var art = load("res://scripts/creature_art/seve/%s.gd" % id)
	var s := ZOOM * minf(1.0, 270.0 / (P.span(id) * art.HEIGHT * ZOOM / 100.0))
	art.draw(ci, Vector2(CW * 0.5 + _x(f) - P.span_x(id) * art.HEIGHT * s / 100.0, CH * 0.9), art.HEIGHT * s, ph[1])
