## Planche avant / après des Flétris communs (refonte des personnages, R0) : pour chaque sorte, l'ancien
## dessin en grand, le nouveau en grand (repos, annonce ou frappe, élite), la taille réelle 1080p sur trois
## sols (Ronce, Spore, Aube : les communs vont partout) avec le héros, la silhouette et les niveaux de gris.
##   tools/godot.sh --xvfb --resolution 2560x1440 -s res://tests/bestiaire/communs/planche.gd -- sortie.png
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const K = preload("res://tests/bestiaire/communs/communs.gd")

const W := 2560
const H := 1440
const TOP := 150
const ROW := 214
const BIG := 2.0 * C.S1080
const GROUNDS := ["ronce", "spore", "aube"]

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
	_text("Flétris communs : la Flétrissure pure (cendre, braise, écorce morte)", Vector2(24, 12), 40, Art.c("or"))
	_text("Avant (develop) et après, même sorte. « En grand » : ×2 la taille en 1080p. « Taille réelle » : pixels d'un écran 1920×1080, sur le sol mort de Ronce, Spore et Aube, le héros à gauche pour l'échelle. Collisions inchangées.", Vector2(24, 60), 19, Art.c("texte_doux"))
	var heads := [["Avant", 250], ["Après : repos · annonce ou coup · élite", 470], ["Taille réelle : Ronce · Spore · Aube", 1250], ["Silhouettes", 1985], ["Gris (avant · après)", 2200]]
	for hd in heads:
		_text(hd[0], Vector2(hd[1], TOP - 34), 22, Art.c("texte"))
	for i in K.CAST.size():
		await _row(i, K.CAST[i], TOP + i * ROW)
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
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
		l.size = Vector2(width, 0)
	labels.append(l)


func _blit(img: Image, x: int, y: int) -> void:
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, y))


## Pose « action » de la sorte : annonce pour le tireur, frappe pour la mêlée, coup reçu sinon.
static func action(id: String) -> Dictionary:
	match id:
		"cracheur":
			return {"t": 0.4, "k": 0.85, "state": "windup", "look": 0.2}
		"fletri", "cendreux", "colosse":
			return {"t": 0.4, "strike": 0.35, "look": 0.2}
	return {"t": 0.4, "hit": 0.7, "look": 0.2}


func _row(i: int, c: Array, y: int) -> void:
	var id: String = c[0]
	var r: float = c[3]
	var art = K.art(id)
	var panel := Image.create(W - 32, ROW - 8, false, Image.FORMAT_RGBA8)
	panel.fill(Art.c("papier"))
	_blit(panel, 16, y)
	_text(c[1], Vector2(28, y + 8), 24, Art.c("texte"), 210)
	_text(c[2], Vector2(28, y + 70), 20, Art.c("or"), 210)
	_text("~%d px avant\n~%d px de haut après\ncollision r %d" % [roundi(2.4 * r), roundi(art.HEIGHT * C.S1080), int(r)], Vector2(28, y + 104), 18, Art.c("texte_doux"), 210)
	var cy := y + 4
	var bs := BIG * (0.75 if id == "colosse" else 1.0)
	var face := Vector2(1, 0.3).normalized()
	var img: Image = await b.bake(Vector2i(210, 206), func(ci): C.draw_before(ci, id, r, Vector2(105, 103), bs * 1.4, {"t": 0.5}, face), 1)
	_blit(img, 240, cy)
	var poses := [{"t": 0.4, "look": 0.2}, action(id), {"t": 0.4, "look": 0.2, "elite": true, "region": "ronce"}]
	for k in 3:
		var o: Dictionary = poses[k]
		var im: Image = await b.bake(Vector2i(256, 206), func(ci): K.draw_after(ci, id, Vector2(128, 196), bs, o))
		_blit(im, 460 + k * 256, cy)
	for g in GROUNDS.size():
		var region: String = GROUNDS[g]
		var im: Image = await b.bake(Vector2i(240, 206), func(ci):
			C.draw_ground(ci, Rect2(0, 0, 240, 206), region, 11 + i * 3 + g)
			K.draw_after(ci, "heros", Vector2(56, 150), C.S1080, {"t": 0.4, "look": 0.1})
			K.draw_after(ci, id, Vector2(156, 160), C.S1080, {"t": 0.4, "look": PI - 0.25}))
		_blit(im, 1240 + g * 244, cy)
	var sil_bg := Image.create(206, 206, false, Image.FORMAT_RGBA8)
	sil_bg.fill(Color("e8dcc0"))
	_blit(sil_bg, 1980, cy)
	var s15 := 1.5 * C.S1080 * (0.8 if id == "colosse" else 1.0)
	var sb: Image = await b.bake(Vector2i(103, 206), func(ci): C.draw_before(ci, id, r, Vector2(51, 110), s15 * 1.3, {"t": 0.5}, face), 1)
	var sa: Image = await b.bake(Vector2i(103, 206), func(ci): K.draw_after(ci, id, Vector2(51, 190), s15, {"t": 0.4, "look": 0.2}))
	_blit(_silhouette(sb), 1980, cy)
	_blit(_silhouette(sa), 2083, cy)
	var gc: Array = C.ground_colors("ronce")
	var gb: Image = await b.bake(Vector2i(160, 206), func(ci):
		ci.draw_rect(Rect2(0, 0, 160, 206), gc[1])
		C.draw_before(ci, id, r, Vector2(80, 103), bs * 1.1, {"t": 0.5}, face), 1)
	var ga: Image = await b.bake(Vector2i(160, 206), func(ci):
		ci.draw_rect(Rect2(0, 0, 160, 206), gc[1])
		K.draw_after(ci, id, Vector2(80, 196), bs * 0.85, {"t": 0.4, "look": 0.2}))
	_blit(_gray(gb), 2200, cy)
	_blit(_gray(ga), 2360, cy)


static func _silhouette(img: Image) -> Image:
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for yy in img.get_height():
		for xx in img.get_width():
			if img.get_pixel(xx, yy).a > 0.55:
				out.set_pixel(xx, yy, Color(0.05, 0.04, 0.04, 1.0))
	return out


static func _gray(img: Image) -> Image:
	var out := img.duplicate()
	for yy in img.get_height():
		for xx in img.get_width():
			var c := img.get_pixel(xx, yy)
			var l := c.get_luminance()
			out.set_pixel(xx, yy, Color(l, l, l, c.a))
	return out
