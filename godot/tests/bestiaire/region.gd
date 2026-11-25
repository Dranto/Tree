## Planche et images du GIF d'une région du « Bestiaire d'herbier » (outil : tools/bestiaire.sh) :
##   planche_<région>.png : pour chaque sorte redessinée, avant / après en grand, à la taille réelle sur le
##     sol de la région avec le Porte-Graine, silhouettes noires et niveaux de gris ;
##   <dossier>/gif_images/NNN.png : marche, annonce, frappe, coup reçu de chaque sorte (après seulement), à
##     ×2 la taille à l'écran en 1080p, assemblées en GIF par le script shell.
## Les sortes sans script de créature sont listées (elles gardent l'ancien dessin).
##   tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/bestiaire/region.gd -- <région> <dossier>
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const Sortes = preload("res://tests/bestiaire/sortes.gd")
const C = preload("res://tests/bestiaire/commun.gd")

const ROW := 270
const COLS := [210, 250, 250, 220, 220, 300, 300]   # nom, avant, après, avant réel, après réel, silhouettes, gris
const CELL_W := 270
const CELL_H := 250
const FRAMES := 84
const ZOOM := 2.0 * Sortes.S1080

var b
var font: FontFile


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


## Phase et avancement à l'image f : marche, annonce, frappe, repos, coup reçu, repos.
static func phase(f: int) -> Array:
	if f < 24:
		return ["marche", f / 24.0]
	if f < 44:
		return ["annonce", (f - 24) / 20.0]
	if f < 54:
		return ["frappe", (f - 44) / 10.0]
	if f < 60:
		return ["repos", 0.0]
	if f < 76:
		return ["coup", (f - 60) / 16.0]
	return ["repos", 0.0]


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var region: String = args[0]
	var out: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	b = Bake.new(self)
	font = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	var mine := []
	var missing := []
	for k in Sortes.kinds():
		if k["region"] != region:
			continue
		if k["script"] != null:
			mine.append(k)
		else:
			missing.append(k["id"])
	print("Région %s : %d sorte(s) redessinée(s)%s" % [region, mine.size(), "" if missing.is_empty() else ", sans script : " + ", ".join(missing)])
	if mine.is_empty():
		print("Rien à dessiner : aucune sorte de cette région n'a de script de créature.")
		quit(0)
		return
	await _planche(region, mine, missing, out)
	await _gif(region, mine, out)
	quit(0)


func _planche(region: String, mine: Array, missing: Array, out: String) -> void:
	var w := 0
	for c in COLS:
		w += c
	var h := 100 + ROW * mine.size()
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.fill(Art.c("papier_sombre"))
	var labels := []
	var heads := ["", "Avant, en grand", "Après, en grand", "Avant, réel 1080p", "Après, réel 1080p", "Silhouettes (avant · après)", "Niveaux de gris (avant · après)"]
	labels.append(_label("Bestiaire d'herbier · %s : avant / après" % region.capitalize(), Vector2(16, 8), 32, Art.c("or")))
	if not missing.is_empty():
		labels.append(_label("Sans script (ancien dessin) : " + ", ".join(missing), Vector2(16, 42), 17, Art.c("texte_doux")))
	var x := 0
	for i in COLS.size():
		labels.append(_label(heads[i], Vector2(x + 8, 70), 18, Art.c("texte")))
		x += COLS[i]
	var gc: Array = C.ground_colors(Sortes.ground_region(region))
	for i in mine.size():
		var k: Dictionary = mine[i]
		var y := 100 + i * ROW
		var script = k["script"]
		var panel := Image.create(w - 8, ROW - 6, false, Image.FORMAT_RGBA8)
		panel.fill(Art.c("papier"))
		canvas.blend_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), Vector2i(4, y))
		var px := roundi(script.HEIGHT * Sortes.S1080)
		labels.append(_label(k["nom"], Vector2(12, y + 10), 24, Art.c("texte")))
		labels.append(_label("%s · %s\n~%d px de haut (mini %d)\ncollision r %d" % [k["id"], k["role"], px, int(k["min_px"]), int(k["r"])], Vector2(12, y + 60), 17, Art.c("texte_doux")))
		var big := 2.4 * Sortes.S1080 / 1.2
		var cx := COLS[0]
		var face := Vector2(1, 0.3).normalized()
		var r: float = k["r"]
		var before: Image = await b.bake(Vector2i(COLS[1], ROW - 10), func(ci): C.draw_before(ci, k["id"], r, Vector2(COLS[1] * 0.5, ROW * 0.5), big, {"t": 0.5}, face), 1)
		var after: Image = await b.bake(Vector2i(COLS[2], ROW - 10), func(ci): Sortes.paint(ci, script, Vector2(COLS[2] * 0.5, ROW - 40), big, Sortes.REPOS))
		canvas.blend_rect(before, Rect2i(Vector2i.ZERO, before.get_size()), Vector2i(cx, y + 4))
		canvas.blend_rect(after, Rect2i(Vector2i.ZERO, after.get_size()), Vector2i(cx + COLS[1], y + 4))
		var rb: Image = await b.bake(Vector2i(COLS[3], ROW - 10), func(ci):
			C.draw_ground(ci, Rect2(0, 0, COLS[3], ROW - 10), Sortes.ground_region(region), 11 + i)
			C.draw_before(ci, "heros", 14.0, Vector2(COLS[3] * 0.72, ROW * 0.5), Sortes.S1080, {"t": 0.5}, Vector2(-1, 0.1).normalized())
			C.draw_before(ci, k["id"], r, Vector2(COLS[3] * 0.32, ROW * 0.5), Sortes.S1080, {"t": 0.5}, Vector2(1, 0.3).normalized()), 1)
		var ra: Image = await b.bake(Vector2i(COLS[4], ROW - 10), func(ci):
			C.draw_ground(ci, Rect2(0, 0, COLS[4], ROW - 10), Sortes.ground_region(region), 11 + i)
			C.draw_after(ci, "heros", Vector2(COLS[4] * 0.72, ROW * 0.5 + 20), Sortes.S1080, {"t": 0.4, "look": PI - 0.1, "build": "ronce"})
			Sortes.paint(ci, script, Vector2(COLS[4] * 0.32, ROW * 0.5 + 25), Sortes.S1080, Sortes.REPOS))
		canvas.blend_rect(rb, Rect2i(Vector2i.ZERO, rb.get_size()), Vector2i(cx + COLS[1] + COLS[2], y + 4))
		canvas.blend_rect(ra, Rect2i(Vector2i.ZERO, ra.get_size()), Vector2i(cx + COLS[1] + COLS[2] + COLS[3], y + 4))
		# Silhouettes et niveaux de gris, à ×1,5 la taille à l'écran.
		var sx := cx + COLS[1] + COLS[2] + COLS[3] + COLS[4]
		var s15 := 1.5 * Sortes.S1080 * 1.2
		var sil_bg := Image.create(COLS[5], ROW - 10, false, Image.FORMAT_RGBA8)
		sil_bg.fill(Color("e8dcc0"))
		canvas.blend_rect(sil_bg, Rect2i(Vector2i.ZERO, sil_bg.get_size()), Vector2i(sx, y + 4))
		var hw := COLS[5] / 2
		var sb: Image = await b.bake(Vector2i(hw, ROW - 10), func(ci): C.draw_before(ci, k["id"], r, Vector2(hw * 0.5, ROW * 0.5), s15, {"t": 0.5}, face), 1)
		var sa: Image = await b.bake(Vector2i(hw, ROW - 10), func(ci): Sortes.paint(ci, script, Vector2(hw * 0.5, ROW - 40), s15, Sortes.REPOS))
		canvas.blend_rect(Sortes.silhouette(sb), Rect2i(Vector2i.ZERO, sb.get_size()), Vector2i(sx, y + 4))
		canvas.blend_rect(Sortes.silhouette(sa), Rect2i(Vector2i.ZERO, sa.get_size()), Vector2i(sx + hw, y + 4))
		var gx := sx + COLS[5]
		var gw := COLS[6] / 2
		var gb: Image = await b.bake(Vector2i(gw, ROW - 10), func(ci):
			ci.draw_rect(Rect2(0, 0, gw, ROW), gc[1])
			C.draw_before(ci, k["id"], r, Vector2(gw * 0.5, ROW * 0.5), s15, {"t": 0.5}, face), 1)
		var ga: Image = await b.bake(Vector2i(gw, ROW - 10), func(ci):
			ci.draw_rect(Rect2(0, 0, gw, ROW), gc[1])
			Sortes.paint(ci, script, Vector2(gw * 0.5, ROW - 40), s15, Sortes.REPOS))
		canvas.blend_rect(Sortes.gray(gb), Rect2i(Vector2i.ZERO, gb.get_size()), Vector2i(gx, y + 4))
		canvas.blend_rect(Sortes.gray(ga), Rect2i(Vector2i.ZERO, ga.get_size()), Vector2i(gx + gw, y + 4))
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(canvas)
	root.add_child(tex)
	for l in labels:
		root.add_child(l)
	root.size = Vector2i(w, h)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/planche_%s.png" % [out, region])
	tex.queue_free()
	for l in labels:
		l.queue_free()


func _gif(region: String, mine: Array, out: String) -> void:
	var dir := out + "/gif_images"
	DirAccess.make_dir_recursive_absolute(dir)
	var n := mine.size()
	var gw := n * CELL_W
	var gc: Array = C.ground_colors(Sortes.ground_region(region))
	var size := Vector2i(gw, CELL_H + 30)
	for f in FRAMES:
		var ph := phase(f)
		var frame: Image = await b.bake(size, func(ci):
			ci.draw_rect(Rect2(Vector2.ZERO, Vector2(size)), Art.c("papier_sombre"))
			for i in n:
				var k: Dictionary = mine[i]
				var rect := Rect2(i * CELL_W + 2, 30, CELL_W - 4, CELL_H)
				C.draw_ground(ci, rect, Sortes.ground_region(region), 41 + i)
				Sortes.paint(ci, k["script"], Vector2(rect.get_center().x, rect.end.y - 36), ZOOM, Sortes.pose(ph[0], ph[1], f / 24.0))
				ci.draw_string(font, Vector2(rect.position.x + 6, 22), k["nom"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.c("texte"))
			ci.draw_string(font, Vector2(gw - 130, 22), ph[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.c("or")), 2)
		frame.convert(Image.FORMAT_RGB8)
		frame.save_png("%s/%03d.png" % [dir, f])


func _label(s: String, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.position = pos
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l
