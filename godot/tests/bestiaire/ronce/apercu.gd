## Aperçu de travail des Flétris de Ronce : une sorte en grand dans toutes ses poses, à la taille réelle
## en 1080p, et à ×2 sans lissage. tools/godot.sh --xvfb -s res://tests/bestiaire/ronce/apercu.gd -- sortie.png sorte
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")

const POSES := [
	{"t": 0.4}, {"walk": 1.2, "moving": 1.0, "t": 0.7}, {"k": 0.8, "state": "windup", "t": 0.3},
	{"state": "charge", "charge": 1.0, "moving": 1.0, "walk": 0.5, "t": 0.5, "strike": 0.2}, {"state": "recover", "t": 0.9, "strike": 0.7}, {"k": 1.0, "state": "windup", "t": 0.6}, {"hit": 1.0},
	{"look": PI * 0.8, "t": 1.3}, {"elite": true, "t": 0.4, "k": 0.4, "look": -0.4, "region": "vent"},
]


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var art = load("res://scripts/creature_art/ronce/%s.gd" % args[1])
	var b := Bake.new(self)
	var canvas := Image.create(2700, 640, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("3b3631"))
	for i in POSES.size():
		var o: Dictionary = POSES[i]
		var img: Image = await b.bake(Vector2i(300, 300), func(ci): art.draw(ci, Vector2(120 + (30 if args[1] == "nid" else 0), 270), 230.0 if args[1] == "nid" else 170.0, o))
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * 300, 0))
		var small: Image = await b.bake(Vector2i(120, 120), func(ci): art.draw(ci, Vector2(60, 90), art.HEIGHT * 1.2, o))
		canvas.blend_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(i * 300 + 90, 300))
		var big: Image = await b.bake(Vector2i(100, 100), func(ci): art.draw(ci, Vector2(50, 80), art.HEIGHT * 1.2, o))
		big.resize(200, 200, Image.INTERPOLATE_NEAREST)
		canvas.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(i * 300 + 50, 430))
	canvas.save_png(args[0])
	quit(0)
