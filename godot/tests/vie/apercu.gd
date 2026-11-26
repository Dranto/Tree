## Aperçu de travail de la faune et des formes guéries d'une région : chaque forme dans toutes ses poses, en
## grand (×4 lissé) puis à la taille réelle en 1080p. Aucun jeu lancé, seulement les scripts de dessin.
##   tools/godot.sh --xvfb -s res://tests/vie/apercu.gd -- sortie.png <région> <gueri|faune> [forme…]
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const Vie = preload("res://scripts/world_life_vie.gd")

const CELL := 72


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var art = load("res://scripts/creature_art/%s/vie/%s.gd" % [args[1], args[2]])
	var only := args.slice(3)
	var b := Bake.new(self)
	var rows: Array = []
	for id in art.FORMES:
		if only.is_empty() or id in only:
			rows.append(id)
	var maxn := 0
	for id in rows:
		var n := 0
		for pose in art.FORMES[id]["poses"]:
			n += int(art.FORMES[id]["poses"][pose])
		maxn = maxi(maxn, n)
	var big := 3
	var rw := CELL * big
	var canvas := Image.create(maxn * rw, rows.size() * (rw + 40), false, Image.FORMAT_RGBA8)
	canvas.fill(Color("5b5547"))
	for r in rows.size():
		var id: String = rows[r]
		var col := 0
		print("forme ", id)
		for pose in art.FORMES[id]["poses"]:
			var n: int = art.FORMES[id]["poses"][pose]
			for i in n:
				var o := Vie.pose_of(id, pose, i, n)
				var h: float = art.FORMES[id]["h"]
				var img: Image = await b.bake(Vector2i(CELL, CELL), func(ci):
					Ink.no_shadow = false
					art.draw(ci, Vector2(CELL * 0.5, CELL * 0.84), h, o), 4)
				img.resize(rw, rw, Image.INTERPOLATE_LANCZOS)
				canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(col * rw, r * (rw + 40)))
				col += 1
		# Taille réelle (1080p : ×1,2), sur la ligne basse.
		var small: Image = await b.bake(Vector2i(CELL, CELL), func(ci): art.draw(ci, Vector2(CELL * 0.5, CELL * 0.84), art.FORMES[id]["h"] * 1.2, Vie.pose_of(id, "repos" if art.FORMES[id]["poses"].has("repos") else art.FORMES[id]["poses"].keys()[0], 0, 2)), 1)
		canvas.blend_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(4, r * (rw + 40) + rw - 8))
	canvas.save_png(args[0])
	print("planche : ", args[0], " ", rows)
	quit(0)

const Ink = preload("res://scripts/creature_art/ink.gd")
