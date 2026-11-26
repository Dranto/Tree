## Aperçu de travail d'un boss du bestiaire (dessin seul) : une rangée de poses en grand.
## tools/godot.sh --xvfb -s res://tests/bestiaire/boss/apercu.gd -- sortie.png vent/_harfang '[{"flap":0.3},…]'
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var art = load("res://scripts/creature_art/%s.gd" % args[1])
	var poses: Array = JSON.parse_string(args[2])
	var cell := 420
	var canvas := Image.create(cell * poses.size(), cell + 160, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("3b3e44"))
	for i in poses.size():
		var o: Dictionary = poses[i]
		var img := await b_bake(Vector2i(cell, cell), func(ci): art.draw(ci, Vector2(cell / 2.0, cell - 40.0), art.HEIGHT * 1.5, o))
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * cell, 0))
		var small := await b_bake(Vector2i(cell / 2, 160), func(ci): art.draw(ci, Vector2(cell / 4.0, 140.0), art.HEIGHT * 1.2 * 0.5, o))
		canvas.blend_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(i * cell + cell / 4, cell))
	canvas.save_png(out)
	quit(0)


func b_bake(size: Vector2i, f: Callable) -> Image:
	return await Bake.new(self).bake(size, f)
