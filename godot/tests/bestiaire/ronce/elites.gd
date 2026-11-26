## Élites de Ronce (tâche R1) : chaque sorte normale puis élite (collier de ronce tressée, liseré doré,
## ×1,15), en grand puis à la taille réelle en 1080p sur le sol de Ronce ; dernière colonne : la même
## élite dans une autre région (le collier prend la couleur de la région, ici Vent).
##   tools/godot.sh --xvfb --resolution 1920x1080 -s res://tests/bestiaire/ronce/elites.gd -- sortie.png
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/ronce/commun.gd")

const W := 1920
const H := 1080


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var b := Bake.new(self)
	var canvas := Image.create(W, H, false, Image.FORMAT_RGBA8)
	canvas.fill(Art.c("papier_sombre"))
	var cw := W / 4
	for i in C.CAST.size():
		var c: Dictionary = C.CAST[i]
		var id: String = c["id"]
		var art = C.art_of(id)
		var big := 2.4 * C.S1080 * (0.8 if id == "nid" else 1.0)
		for j in 3:
			var region := "vent" if j == 2 else "ronce"
			var o := {"t": 0.4 + j * 0.3, "look": 0.2, "elite": j > 0, "region": region}
			var s := big * (1.15 if j > 0 else 1.0)
			var img: Image = await b.bake(Vector2i(cw, 300), func(ci):
				C.draw_ground(ci, Rect2(0, 0, cw, 300), region, 40 + i * 3 + j)
				C.draw_after(ci, id, Vector2(cw * 0.5 - (40 if id == "chargeur" else 0), 270), s, o)
				# Taille réelle en 1080p, dans le coin.
				C.draw_after(ci, id, Vector2(cw - 40, 290), C.S1080 * (1.15 if j > 0 else 1.0), o))
			canvas.blit_rect(img, Rect2i(0, 0, cw, 300), Vector2i(i * cw, 60 + j * 340))
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(canvas)
	root.add_child(tex)
	var font: FontFile = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	var rows := ["Normal", "Élite (Ronce) : collier de ronce tressée, liseré doré, ×1,15", "Élite en Vent : le collier prend la couleur de la région"]
	for j in 3:
		var l := Label.new()
		l.text = rows[j]
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.position = Vector2(16, 16 + j * 340)
		var ls := LabelSettings.new()
		ls.font = font
		ls.font_size = 28
		ls.font_color = Art.c("or")
		l.label_settings = ls
		root.add_child(l)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit(0)
