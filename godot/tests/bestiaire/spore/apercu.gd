## Aperçu de travail des Flétris de Spore (R2) : une sorte, poses variées, en grand et à la taille réelle 1080p,
## sur le sol mort de Spore. tools/godot.sh --xvfb -s res://tests/bestiaire/spore/apercu.gd -- sortie.png sorte
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var art = load("res://scripts/creature_art/spore/%s.gd" % args[1])
	var b := Bake.new(self)
	var poses := [{"t": 0.4}, {"walk": 1.2, "moving": 1.0}, {"k": 0.9, "t": 0.3, "state": "windup"}, {"strike": 0.25}, {"hit": 1.0}, {"look": PI * 0.8, "elite": true}]
	var big_h := 175.0
	var canvas := Image.create(2160, 560, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("3b3631"))
	for i in poses.size():
		var o: Dictionary = poses[i]
		var img := await b.bake(Vector2i(360, 360), func(ci):
			C.draw_ground(ci, Rect2(0, 0, 360, 360), "spore", 3 + i)
			art.draw(ci, Vector2(170, 320), big_h, o))
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * 360, 0))
		var small := await b.bake(Vector2i(180, 180), func(ci):
			C.draw_ground(ci, Rect2(0, 0, 180, 180), "spore", 9 + i)
			C.draw_after(ci, "heros", Vector2(40, 120), C.S1080, {"t": 0.4, "look": 0.1})
			art.draw(ci, Vector2(115, 125), art.HEIGHT * C.S1080, o))
		canvas.blend_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(i * 360 + 90, 370))
	canvas.save_png(out)
	quit(0)
