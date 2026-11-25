## Planche animée des morts depuis les sprites cuits (refonte des personnages, tâche M) : les huit
## morts d'Éclat B, image par image, en trois lignes :
##   1. avant : la silhouette calculée (fletri_art.gd), comme aujourd'hui en jeu ;
##   2. après : les nouvelles créatures cuites par le moteur (sprite_bake.gd, scripts/creature_art/) :
##      la mort part de leur image.
## Chaque colonne sur le sol de la région de sa créature, à ×2 de la taille du jeu. Rien n'est comparé.
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --resolution 1800x590 -s res://tests/morts_sprites_planche.gd -- --out=DOSSIER
extends SceneTree

const C = preload("res://tests/bestiaire/commun.gd")
const Sprites = preload("res://scripts/sprite_bake.gd")
## Chargé à l'exécution : un script -s ne précharge pas un script qui nomme un autoload.
var Remains

const FRAMES := 52
const STEP := 1.0 / 30.0
const CW := 210
const CH := 255
const TOP := 34
const LEFT := 120
const ZOOM := 2.0

## [façon, sorte, élite, surpuissance]
const CASES := [
	["cendre", "menhir", false, 0.0], ["venin", "tireur", false, 0.0], ["sang", "scarabee", false, 0.0],
	["tranche", "tireur", false, 0.6], ["vent", "menhir", false, 0.0], ["aube", "scarabee", false, 0.0],
	["racine", "menhir", true, 0.0], ["seve", "tireur", false, 0.0],
]
const ROWS := ["avant", "après"]


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _region(kind: String) -> String:
	for c in C.CAST:
		if c["id"] == kind:
			return c["region"]
	return "ronce"


func _radius(kind: String) -> float:
	for c in C.CAST:
		if c["id"] == kind:
			return c["r"]
	return 14.0


func _label(text: String, at: Vector2, size := 20) -> void:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("efe6cf"))
	root.add_child(l)


func _run() -> void:
	Remains = load("res://scripts/enemy_remains.gd")
	var out := "user://morts_sprites"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	var kinds := []
	for c in CASES:
		if not kinds.any(func(k): return k[0] == c[1]):
			kinds.append([c[1], _radius(c[1])])
	await Sprites.bake(root, kinds)
	var bg := ColorRect.new()
	bg.color = Color("1d1a17")
	bg.size = Vector2(4000, 3000)
	root.add_child(bg)
	var grounds := Node2D.new()
	grounds.draw.connect(func():
		for row in ROWS.size():
			for i in CASES.size():
				C.draw_ground(grounds, Rect2(LEFT + i * CW + 2, TOP + row * CH + 2, CW - 4, CH - 4), _region(CASES[i][1]), 11 + i))
	root.add_child(grounds)
	for i in CASES.size():
		_label(CASES[i][0], Vector2(LEFT + i * CW + 8, 4))
	for row in ROWS.size():
		_label(ROWS[row], Vector2(8, TOP + row * CH + CH * 0.45), 17)
	var list: Array = []
	for row in ROWS.size():
		for i in CASES.size():
			var c: Array = CASES[i]
			var r = Remains.new()
			r.style = c[0]
			r.kind_id = c[1]
			r.elite = c[2]
			r.power = c[3]
			r.region = _region(c[1]) if c[2] else ""
			r.radius = _radius(c[1]) * (1.2 if c[2] else 1.0)
			r.dir = Vector2(1, -0.25).normalized()
			r.color = Remains.FletriArt.body_color(c[1])
			r.side = 1.0
			# Planche : 24 morts à la fois, au-delà du plafond des morts élémentaires (feel.json).
			r._styled = true
			if row == 1:
				r.sprite = Remains.frame_for(c[1], {}, 0.3)
			r.position = (Vector2(LEFT + (i + 0.5) * CW, TOP + row * CH + CH * 0.62) - Vector2.ZERO) / ZOOM
			var holder := Node2D.new()
			holder.scale = Vector2(ZOOM, ZOOM)
			root.add_child(holder)
			holder.add_child(r)
			r.set_process(false)
			list.append(r)
	for f in FRAMES:
		var time := f * STEP - 0.1   # quelques images avant la mort : le Flétri entier
		for r in list:
			r.t = maxf(time, 0.0)
			r.visible = time >= 0.0
			r.queue_redraw()
			for ch in r.get_children():
				ch.queue_redraw()
		await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/%03d.png" % [out, f])
	quit(0)
