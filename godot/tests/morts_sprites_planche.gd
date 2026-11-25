## Planche animée des morts depuis les sprites cuits (refonte des personnages, tâche M) : les huit
## morts d'Éclat B, image par image, en trois lignes :
##   1. avant : la silhouette calculée (fletri_art.gd), comme aujourd'hui en jeu ;
##   2. l'ancien dessin cuit (sprite_bake.gd, ×3) : la mort part de l'image cuite ;
##   3. les nouvelles créatures (scripts/creature_art/, cuites ici de la même façon) : la mort part de
##      leur image (le moteur de la tâche A fera cette cuisson en jeu).
## Chaque colonne sur le sol de la région de sa créature, à ×2 de la taille du jeu. Rien n'est comparé.
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --resolution 1800x840 -s res://tests/morts_sprites_planche.gd -- --out=DOSSIER
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
const SS := 2

## [façon, sorte, élite, surpuissance]
const CASES := [
	["cendre", "menhir", false, 0.0], ["venin", "tireur", false, 0.0], ["sang", "scarabee", false, 0.0],
	["tranche", "tireur", false, 0.6], ["vent", "menhir", false, 0.0], ["aube", "scarabee", false, 0.0],
	["racine", "menhir", true, 0.0], ["seve", "tireur", false, 0.0],
]
const ROWS := ["avant", "ancien cuit", "nouveau cuit"]


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


## Cuit le nouveau dessin d'une sorte (pose de repos) comme sprite_bake.gd : ×scale, suréchantillonné,
## alpha prémultiplié, mipmaps. Rend {tex, src, rect, r, shadow}.
func _bake_new(kind: String) -> Dictionary:
	var art = C.art_of(kind)
	var h: float = art.HEIGHT
	var s := Sprites.scale
	var box := Rect2(-1.1 * h, -1.4 * h, 2.2 * h, 1.8 * h)
	var size := Vector2i((box.size * s).ceil())
	var vp := SubViewport.new()
	vp.size = size * SS
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(vp)
	var n := Node2D.new()
	n.scale = Vector2.ONE * s * SS
	n.position = -box.position * s * SS
	n.draw.connect(func(): art.draw(n, Vector2.ZERO, h, {"t": 0.3, "look": 0.0}))
	vp.add_child(n)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img.resize(size.x, size.y, Image.INTERPOLATE_TRILINEAR)
	var used := img.get_used_rect().grow(3).intersection(Rect2i(Vector2i.ZERO, size))
	var crop := img.get_region(used)
	crop.generate_mipmaps()
	var rect := Rect2(box.position + Vector2(used.position) / s, Vector2(used.size) / s)
	return {"tex": ImageTexture.create_from_image(crop), "src": Rect2(Vector2.ZERO, Vector2(used.size)), "rect": rect, "r": _radius(kind), "shadow": true}


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
	Sprites.scale = 3.0
	var kinds := []
	var fresh := {}
	for c in CASES:
		if not fresh.has(c[1]):
			kinds.append([c[1], _radius(c[1])])
			fresh[c[1]] = await _bake_new(c[1])
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
			elif row == 2:
				r.sprite = fresh[c[1]]
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
