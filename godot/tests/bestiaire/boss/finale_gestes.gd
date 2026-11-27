## Gestes de la Flétrissure (direction, dessin seul) : chaque attaque en trois temps (élan, frappe,
## retour), sur une planche (une ligne par attaque) ou en images d'une frise (--frames=dossier, à
## assembler en GIF). Aucune partie n'est jouée : la frise rejoue les enregistrements de
## boss_art/finale_choreo.gd comme le fait BossFinale.
##   tools/godot.sh --xvfb -s res://tests/bestiaire/boss/finale_gestes.gd -- --out=x.png
##   tools/godot.sh --xvfb -s res://tests/bestiaire/boss/finale_gestes.gd -- --frames=dossier [--fps=24]
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const Choreo = preload("res://scripts/boss_art/finale_choreo.gd")
## Chargée à l'exécution (elle lit des autoloads).
static var BossFinale

## [attaque, bras allumés, annonce (s), tenue de la frappe (s), phase, seconde forme]
const SEQ := [
	["epines", [0], 1.0, 0.67, 1, 0.0],
	["spores", [1], 1.0, 0.0, 1, 0.0],
	["siphon", [2], 1.0, 1.2, 2, 0.0],
	["rafale", [3], 1.0, 0.0, 2, 0.0],
	["lumiere", [4], 1.0, 0.0, 3, 0.0],
	["racines", [5], 0.7, 0.6, 3, 0.0],
	["tempete", [3, 0], 1.15, 0.67, 3, 1.0],
	["floraison", [1, 2], 1.1, 0.0, 3, 1.0],
	["aurore", [4, 5], 1.0, 0.7, 3, 1.0],
]
const NAMES := {"epines": "Épines (Ronce)", "spores": "Spores (Spore)", "siphon": "Siphon (Sève)", "rafale": "Rafale (Vent)",
	"lumiere": "Lumière (Aube)", "racines": "Racines (Racine)", "tempete": "Tempête (Vent + Ronce)",
	"floraison": "Floraison (Spore + Sève)", "aurore": "Aurore (Aube + Racine)"}
const COLS := [["Repos", -1.0, -1.0, -1.0], ["Élan", 0.55, -1.0, -1.0], ["Élan, fin", 1.0, -1.0, -1.0],
	["Frappe", 1.0, 0.06, -1.0], ["Frappe tenue", 1.0, 0.3, -1.0], ["Retour", 1.0, 0.3, 0.12], ["Retour, fin", 1.0, 0.3, 0.4]]

const R := 50.0
const TILE := Vector2i(420, 440)
var b
var font: FontFile


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _arg(name: String, def := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return def


func _run() -> void:
	b = Bake.new(self)
	BossFinale = load("res://scripts/boss_finale.gd")
	font = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	if _arg("frames") != "":
		await _frames(_arg("frames"), float(_arg("fps", "24")))
	else:
		await _sheet(_arg("out", "gestes.png"))
	quit(0)


## Le héros, pour viser : en bas à droite d'elle.
const AIM := Vector2(0.62, 0.78)


static func _scene(ci: CanvasItem, c: Vector2, r: float, t: float, phase: int, form: float, kind: String, lit: Array, k: float, recs: Array) -> void:
	BossFinale.draw_floor(ci, c, r, t, phase, 0.0, form)
	var anim := Choreo.build(recs, BossFinale.ARMS, AIM.normalized(), t)
	var tint := func(col): return col
	BossFinale.draw_colossus(ci, c, r, t, phase, k, lit[0] if lit.size() > 0 else -1, 0.0, 1.0, tint, lit[1] if lit.size() > 1 else -1, form, 1.0, anim)
	# Le héros (un repère) : où elle vise.
	var hp := c + AIM.normalized() * r * 3.2
	ci.draw_circle(hp, 9.0, Color(Art.c("or"), 0.9))
	ci.draw_arc(hp, 13.0, 0.0, TAU, 20, Color(Art.c("or"), 0.5), 2.0, true)


func _sheet(out: String) -> void:
	var w := 230 + COLS.size() * (TILE.x + 8)
	var h := 80 + SEQ.size() * (TILE.y + 8)
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.fill(Art.c("papier_sombre"))
	var labels: Array = []
	labels.append(_label("La Flétrissure : chaque attaque en trois temps", Vector2(20, 12), 34, Art.c("or")))
	for ci_ in COLS.size():
		labels.append(_label(COLS[ci_][0], Vector2(230 + ci_ * (TILE.x + 8) + 10, 54), 20, Art.c("texte_doux")))
	for ri in SEQ.size():
		var row: Array = SEQ[ri]
		var y := 80 + ri * (TILE.y + 8)
		labels.append(_label(NAMES[row[0]], Vector2(16, y + TILE.y * 0.45), 22, Art.c("texte")))
		for ci_ in COLS.size():
			var col: Array = COLS[ci_]
			var recs := _recs(row, col[1], col[2], col[3])
			var k: float = clampf(col[1], 0.0, 1.0) if col[2] < 0.0 else 0.0
			var lit: Array = row[1] if col[1] >= 0.0 and col[3] < 0.0 else []
			var img: Image = await b.bake(TILE, func(cc): _scene(cc, Vector2(TILE.x * 0.5, TILE.y * 0.72), R, 0.8 + ci_ * 0.11, row[4], row[5], row[0], lit, k, recs), 2, Color("2a2224"))
			canvas.blend_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(230 + ci_ * (TILE.x + 8), y))
	await _save(canvas, labels, out)


## Les enregistrements des bras pour une case (k : annonce ; s : depuis la frappe ; e : depuis la fin).
static func _recs(row: Array, k: float, s: float, e: float) -> Array:
	var recs: Array = []
	for i in 6:
		recs.append({})
	if k < 0.0:
		return recs
	for i: int in row[1]:
		recs[i] = {"kind": row[0], "k": k, "s": s, "e": e}
	return recs


func _frames(dir: String, fps: float) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var size := Vector2i(720, 640)
	var gap := 0.5
	var n := 0
	var t := 0.0
	for row: Array in SEQ:
		var ann: float = row[2]
		var hold: float = row[3]
		var total: float = ann + hold + Choreo.RECOVER + gap
		var u := 0.0
		while u < total:
			var k := -1.0
			var s := -1.0
			var e := -1.0
			if u < ann:
				k = u / ann
			else:
				k = 1.0
				s = u - ann
				if s > hold:
					e = s - hold
			var recs := _recs(row, k, s, e)
			var lit: Array = row[1] if e < 0.0 else []
			var kk := k if s < 0.0 else 0.0
			var label: String = NAMES[row[0]] + ("  ·  élan" if s < 0.0 else ("  ·  frappe" if e < 0.0 else "  ·  retour"))
			var img: Image = await b.bake(size, func(cc):
				_scene(cc, Vector2(size.x * 0.5, size.y * 0.7), 78.0, t, row[4], row[5], row[0], lit, kk, recs), 2, Color("2a2224"))
			var canvas := img
			await _save(canvas, [_label(label, Vector2(16, 10), 26, Art.c("or"))], dir.path_join("f%04d.png" % n))
			n += 1
			u += 1.0 / fps
			t += 1.0 / fps


func _save(canvas: Image, labels: Array, out: String) -> void:
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(canvas)
	root.add_child(tex)
	for l in labels:
		root.add_child(l)
	root.size = canvas.get_size()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(Rect2i(Vector2i.ZERO, canvas.get_size())).save_png(out)
	tex.queue_free()
	for l in labels:
		l.queue_free()


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
