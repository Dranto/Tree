## Assemble les planches « Paysages d'herbier » (refonte du monde, vague 0, tâche W) à partir des captures
## de scene.gd (avant, vrai jeu) et de rendu.gd (après) rangées dans DOSSIER :
##   <région>_avant_apres.png  les quatre états d'une région (avant/après × flétri/ravivé)
##   apres_gris.png            l'après en niveaux de gris (hiérarchie sol < décor < lieux < personnages)
##   zoom_1080p.png            recadrages à la taille réelle en 1080p, avant | après
##   deck_1280x800.png         le Roncier sur Steam Deck (1280×800), avant | après, taille réelle
##   lieux.png                 Cœurs flétris/purifiés et sanctuaires, avant/après, des deux régions
##   tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/paysages/planche.gd -- DOSSIER
extends SceneTree

const FONT := "res://assets/fonts/CormorantGaramond-Herbier.ttf"
const NOMS := {"ronce": "Roncier", "spore": "Marais"}
const GRIS := "shader_type canvas_item;\nvoid fragment() { vec4 c = texture(TEXTURE, UV); float l = dot(c.rgb, vec3(0.299, 0.587, 0.114)); COLOR = vec4(vec3(l), c.a); }"

var dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var a := OS.get_cmdline_user_args()
	dir = a[0] if a.size() > 0 else "user://paysages"
	for reg in ["ronce", "spore"]:
		var tiles := [
			[_img("%s_avant_fletri" % reg), "Avant · flétri (le jeu aujourd'hui)"],
			[_img("%s_apres_fletri" % reg), "Après · flétri"],
			[_img("%s_avant_ravive" % reg), "Avant · ravivé (Cœur purifié)"],
			[_img("%s_apres_ravive" % reg), "Après · ravivé"],
		]
		await _page(Vector2i(2560, 1440), _grid(tiles, Vector2i(1280, 720), 2, false), "%s/%s_avant_apres.png" % [dir, "roncier" if reg == "ronce" else "marais"])
	var gris := []
	for reg in ["ronce", "spore"]:
		for e in ["fletri", "ravive"]:
			gris.append([_img("%s_apres_%s" % [reg, e]), "%s · %s · niveaux de gris" % [NOMS[reg], "flétri" if e == "fletri" else "ravivé"]])
	await _page(Vector2i(2560, 1440), _grid(gris, Vector2i(1280, 720), 2, true), dir + "/apres_gris.png")
	# Taille réelle : 960×540 autour du héros (centre de l'écran), pixel pour pixel.
	var zoom := []
	for z in [["ronce", "fletri"], ["spore", "ravive"]]:
		for w in ["avant", "apres"]:
			var img := _img("%s_%s_%s" % [z[0], w, z[1]]).get_region(Rect2i(480, 270, 960, 540))
			zoom.append([img, "%s · %s · %s · taille réelle 1080p" % [NOMS[z[0]], "flétri" if z[1] == "fletri" else "ravivé", "avant" if w == "avant" else "après"]])
	await _page(Vector2i(1920, 1080), _grid(zoom, Vector2i(960, 540), 2, false), dir + "/zoom_1080p.png")
	var deck := []
	for e in ["fletri", "ravive"]:
		for w in ["avant", "apres"]:
			deck.append([_img("deck_ronce_%s_%s" % [w, e]), "Steam Deck 1280×800 · Roncier · %s · %s" % ["flétri" if e == "fletri" else "ravivé", "avant" if w == "avant" else "après"]])
	await _page(Vector2i(2560, 1600), _grid(deck, Vector2i(1280, 800), 2, false), dir + "/deck_1280x800.png")
	await _lieux()
	quit(0)


func _img(name: String) -> Image:
	var img := Image.load_from_file("%s/%s.png" % [dir, name])
	if img == null:
		push_error("planche : capture absente " + name)
		img = Image.create(16, 16, false, Image.FORMAT_RGB8)
	return img


## Lieux : pour chaque région, le Cœur du cadre (flétri, purifié) et son sanctuaire (flétri, ravivé),
## recadrés autour de leur position à l'écran, avant et après.
func _lieux() -> void:
	var cell := Vector2i(480, 340)
	var root_c := Control.new()
	var head := 150
	root_c.add_child(_label("", Vector2(0, 0), 30))
	var cols := ["Cœur · flétri", "Cœur · purifié", "Sanctuaire · flétri", "Sanctuaire · ravivé"]
	for i in 4:
		root_c.add_child(_label(cols[i], Vector2(head + i * cell.x + 12, 14), 34))
	var row := 0
	for reg in ["ronce", "spore"]:
		var real = JSON.parse_string(FileAccess.get_file_as_string("%s/cadre_%s.json" % [dir, reg]))
		var cam := Vector2(real["camera"][0], real["camera"][1])
		var to_screen := func(w: Array) -> Vector2: return (Vector2(w[0], w[1]) - cam) * 1.2 + Vector2(960, 540)
		var hp: Vector2 = to_screen.call(real["heart_pos"]) + Vector2(0, -70)
		var sp: Vector2 = to_screen.call(real["sanctuary_pos"]) + Vector2(0, -30)
		for w in ["avant", "apres"]:
			var y := 60 + row * cell.y
			root_c.add_child(_label("%s\n%s" % [NOMS[reg], "avant" if w == "avant" else "après"], Vector2(12, y + cell.y * 0.4), 32))
			var shots := [["fletri", hp], ["ravive", hp], ["fletri", sp], ["ravive", sp]]
			for i in 4:
				var src := _img("%s_%s_%s" % [reg, w, shots[i][0]])
				var c: Vector2 = shots[i][1]
				var crop := Vector2i(343, 243)
				var r := Rect2i(Vector2i(c) - crop / 2, crop)
				r.position = r.position.clamp(Vector2i.ZERO, Vector2i(src.get_width(), src.get_height()) - crop)
				var part := src.get_region(r)
				part.resize(cell.x - 6, cell.y - 6, Image.INTERPOLATE_LANCZOS)
				var tr := TextureRect.new()
				tr.texture = ImageTexture.create_from_image(part)
				tr.position = Vector2(head + i * cell.x + 3, y + 3)
				root_c.add_child(tr)
			row += 1
	await _page(Vector2i(head + cell.x * 4, 60 + cell.y * 4), root_c, dir + "/lieux.png")


func _grid(tiles: Array, cell: Vector2i, cols: int, gray: bool) -> Control:
	var c := Control.new()
	var mat: ShaderMaterial = null
	if gray:
		var sh := Shader.new()
		sh.code = GRIS
		mat = ShaderMaterial.new()
		mat.shader = sh
	for i in tiles.size():
		var img: Image = tiles[i][0].duplicate()
		if img.get_size() != cell:
			img.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.position = Vector2((i % cols) * cell.x, (i / cols) * cell.y)
		if mat != null:
			tr.material = mat
		c.add_child(tr)
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.04, 0.04, 0.72)
		bg.position = tr.position + Vector2(16, 16)
		bg.size = Vector2(cell.x * 0.62, 46)
		c.add_child(bg)
		c.add_child(_label(tiles[i][1], tr.position + Vector2(28, 18), 30))
	# Filets dorés entre les cases.
	for k in range(1, cols):
		var v := ColorRect.new()
		v.color = Art.c("or")
		v.position = Vector2(k * cell.x - 2, 0)
		v.size = Vector2(4, cell.y * ceili(tiles.size() / float(cols)))
		c.add_child(v)
	for k in range(1, ceili(tiles.size() / float(cols))):
		var h := ColorRect.new()
		h.color = Art.c("or")
		h.position = Vector2(0, k * cell.y - 2)
		h.size = Vector2(cell.x * cols, 4)
		c.add_child(h)
	return c


func _label(text: String, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", load(FONT))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("f3ead2"))
	return l


func _page(size: Vector2i, content: Control, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("17110f")
	bg.size = Vector2(size)
	vp.add_child(bg)
	vp.add_child(content)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(path)
	vp.queue_free()
