## Aperçu de travail des Flétris d'Aube : une sorte en grand (poses variées), à la taille réelle 1080p et ×2.
## tools/godot.sh --xvfb -s res://tests/bestiaire/aube/apercu.gd -- sortie.png sorte
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var art = load("res://scripts/creature_art/aube/%s.gd" % args[1])
	var b := Bake.new(self)
	var poses := [{"t": 0.3}, {"walk": 1.2, "moving": 1.0}, {"k": 0.8, "t": 0.3, "state": "windup"}, {"strike": 0.15}, {"hit": 1.0}, {"look": -0.45, "k": 0.4}, {"elite": true, "t": 0.6}]
	var canvas := Image.create(2100, 760, false, Image.FORMAT_RGBA8)
	canvas.fill(C.ground_colors("aube")[1])
	for i in poses.size():
		var o: Dictionary = poses[i]
		var img := await b.bake(Vector2i(300, 300), func(ci): art.draw(ci, Vector2(150, 270), 220.0, o))
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * 300, 0))
		var small := await b.bake(Vector2i(120, 120), func(ci): art.draw(ci, Vector2(60, 100), art.HEIGHT * C.S1080, o))
		canvas.blend_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(i * 300 + 90, 320))
		var big := await b.bake(Vector2i(120, 120), func(ci): art.draw(ci, Vector2(60, 100), art.HEIGHT * C.S1080, o))
		big.resize(240, 240, Image.INTERPOLATE_NEAREST)
		canvas.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(i * 300 + 30, 480))
	canvas.save_png(args[0])
	quit(0)
