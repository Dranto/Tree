## Planche de la Flétrissure (refonte des personnages, B4) : poses en grand (repos, annonce, seconde
## forme, mort, endormie, retournée), avant (develop, dossier passé en --avant) et après, plus la
## silhouette, les niveaux de gris et un mode daltonien.
##   tools/godot.sh --xvfb --resolution 2560x1440 -s res://tests/bestiaire/boss/finale_planche.gd -- --out=x.png [--avant=/chemin/godot]
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")

const W := 2560
static var TILE := Vector2i(420, 380)
static var R := 75.0
const POSES := [
	["Phase 1, repos", {"phase": 1}],
	["Phase 2, annonce (vent)", {"phase": 2, "k": 0.9, "lit": 3}],
	["Seconde forme, annonce (aurore)", {"phase": 3, "form": 1.0, "k": 0.8, "lit": 4, "lit2": 5}],
	["Mort", {"phase": 3, "form": 1.0, "die": 0.45}],
	["Endormie", {"phase": 0, "wake": 0.0}],
	["Tournée vers la gauche", {"phase": 2, "facing": -1.0}],
]

var b
var font: FontFile
var labels: Array = []
var canvas: Image


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _arg(name: String, def := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return def


func _run() -> void:
	var out := _arg("out", "planche.png")
	var avant := _arg("avant")
	var zoom := float(_arg("zoom", "1"))
	TILE = Vector2i(roundi(420 * zoom), roundi(380 * zoom))
	R = 75.0 * zoom
	b = Bake.new(self)
	font = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	var rows: Array = []
	if avant != "":
		rows.append(["Avant", load(avant.path_join("scripts/boss_finale.gd")), ""])
	var after = load("res://scripts/boss_finale.gd")
	rows.append(["Après", after, ""])
	rows.append(["Après, gris", after, "gris"])
	rows.append(["Après, deutéranopie", after, "deuteranopie"])
	if _arg("rows") != "":
		rows = rows.slice(0, int(_arg("rows")))
	var h := 90 + rows.size() * (TILE.y + 40)
	var w := maxi(W, 200 + POSES.size() * (TILE.x + 10))
	canvas = Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.fill(Art.c("papier_sombre"))
	_text("La Flétrissure (boss final) : avant / après", Vector2(24, 14), 40, Art.c("or"))
	for ri in rows.size():
		var row: Array = rows[ri]
		var y := 90 + ri * (TILE.y + 40)
		_text(row[0], Vector2(24, y), 26, Art.c("texte"))
		if row[2] == "deuteranopie":
			Art.set_access("deuteranopie")
		for pi in POSES.size():
			var pose: Array = POSES[pi]
			var o: Dictionary = pose[1]
			var S = row[1]
			var img: Image = await b.bake(TILE, func(ci): _draw(ci, S, o), 2, Color("2a2224"))
			if row[2] == "gris":
				img = _gray(img)
			canvas.blend_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(200 + pi * (TILE.x + 10), y))
			if ri == 0:
				_text(pose[0], Vector2(200 + pi * (TILE.x + 10), 64), 20, Art.c("texte_doux"))
		if row[2] == "deuteranopie":
			Art.set_access("")
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(canvas)
	root.add_child(tex)
	for l in labels:
		root.add_child(l)
	root.size = Vector2i(w, h)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(Rect2i(0, 0, w, h)).save_png(out)
	quit(0)


static func _draw(ci: CanvasItem, S, o: Dictionary) -> void:
	var c := Vector2(TILE.x * 0.5, TILE.y * 0.74)
	var t := 0.8
	var tint := func(col): return col
	S.draw_floor(ci, c, R, t, int(o.get("phase", 1)), float(o.get("die", 0.0)), float(o.get("form", 0.0)))
	var args := [ci, c, R, t, int(o.get("phase", 1)), float(o.get("k", 0.0)), int(o.get("lit", -1)), float(o.get("die", 0.0)), float(o.get("wake", 1.0)), tint, int(o.get("lit2", -1)), float(o.get("form", 0.0))]
	var n := 0
	for m in S.get_script_method_list():
		if m["name"] == "draw_colossus":
			n = m["args"].size()
	if n >= 13:
		args.append(float(o.get("facing", 1.0)))
	S.callv("draw_colossus", args)


func _text(s: String, pos: Vector2, size: int, col: Color) -> void:
	var l := Label.new()
	l.text = s
	l.position = pos
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	labels.append(l)


static func _gray(img: Image) -> Image:
	var out := img.duplicate()
	for yy in img.get_height():
		for xx in img.get_width():
			var c := img.get_pixel(xx, yy)
			var l := c.get_luminance()
			out.set_pixel(xx, yy, Color(l, l, l, c.a))
	return out
