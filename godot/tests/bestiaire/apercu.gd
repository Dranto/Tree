## Aperçu de travail : une créature du bestiaire en grand et à la taille réelle, poses variées.
## tools/godot.sh --xvfb -s res://tests/bestiaire/apercu.gd -- sortie.png sorte
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var kind: String = args[1]
	var art = load("res://scripts/creature_art/%s.gd" % kind)
	var b := Bake.new(self)
	var poses := [{}, {"walk": 1.2, "moving": 1.0}, {"k": 0.8, "t": 0.3}, {"hit": 1.0}, {"look": PI * 0.8}, {"look": -0.6, "k": 0.4}]
	if args.size() > 2:
		for p in poses:
			p["build"] = args[2]
	var canvas := Image.create(1800, 760, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("3b3631"))
	for i in poses.size():
		var o: Dictionary = poses[i]
		var img := await b.bake(Vector2i(300, 300), func(ci): art.draw(ci, Vector2(150, 250), 220.0, o))
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * 300, 0))
		var small := await b.bake(Vector2i(120, 120), func(ci): art.draw(ci, Vector2(60, 90), art.HEIGHT * 1.2, o))
		canvas.blend_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(i * 300 + 90, 320))
		var big := await b.bake(Vector2i(120, 120), func(ci): art.draw(ci, Vector2(60, 90), art.HEIGHT * 1.2 * 2.0, o))
		big.resize(240, 240, Image.INTERPOLATE_NEAREST)
		canvas.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(i * 300 + 30, 480))
	canvas.save_png(out)
	quit(0)
