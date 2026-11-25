## Aperçu de travail (R4, Sève) : une sorte en grand dans toutes ses poses, plus la taille réelle 1080p.
## tools/godot.sh --xvfb -s res://tests/bestiaire/seve/apercu.gd -- sortie.png sorte
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const P = preload("res://tests/bestiaire/seve/poses.gd")


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var kind: String = args[1]
	var art = load("res://scripts/creature_art/seve/%s.gd" % kind)
	var b := Bake.new(self)
	var poses: Array = P.gallery(kind)
	var cols := 6
	var rows := ceili(poses.size() / float(cols))
	var canvas := Image.create(cols * 300, rows * 330 + 160, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("3b3631"))
	var big := 300.0 * 0.62 / P.span(kind) * 100.0
	for i in poses.size():
		var o: Dictionary = poses[i]
		var img := await b.bake(Vector2i(300, 330), func(ci): art.draw(ci, Vector2(150 - P.span_x(kind) * big / 100.0, 300), big, o))
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * 300, (i / cols) * 330))
	var real := await b.bake(Vector2i(cols * 300, 160), func(ci):
		C.draw_ground(ci, Rect2(0, 0, cols * 300, 160), "seve", 5)
		C.draw_after(ci, "heros", Vector2(80, 110), C.S1080, {"t": 0.4, "look": 0.1})
		for i in mini(poses.size(), 10):
			art.draw(ci, Vector2(190 + i * 160, 120), art.HEIGHT * C.S1080, poses[i]))
	canvas.blend_rect(real, Rect2i(Vector2i.ZERO, real.get_size()), Vector2i(0, rows * 330))
	canvas.save_png(out)
	quit(0)
