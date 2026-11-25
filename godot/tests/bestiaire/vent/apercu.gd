## Aperçu de travail des Flétris de Vent : une sorte, toutes ses poses en grand, à la taille réelle
## (1080p) et en silhouette. tools/godot.sh --xvfb -s res://tests/bestiaire/vent/apercu.gd -- sortie.png sorte
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")


## Poses à montrer pour chaque sorte (celles que son comportement utilise).
static func poses(kind: String) -> Array:
	var p := [{"t": 0.3}, {"walk": 1.2, "moving": 1.0, "t": 0.7}, {"k": 0.5, "state": "windup", "t": 0.2}, {"k": 1.0, "state": "windup", "t": 0.4}]
	match kind:
		"plongeur":
			p += [{"state": "charge", "t": 0.5}, {"state": "charge", "look": 0.7, "t": 0.6}, {"state": "recover", "t": 0.1}]
		"souffleur":
			p += [{"state": "recover", "strike": 0.1, "t": 0.5}, {"state": "recover", "strike": 0.6, "t": 0.7}]
		"planeur":
			p += [{"strike": 0.2, "t": 0.5}, {"state": "vol", "t": 0.6}, {"state": "vol", "t": 1.1}]
		"menhir":
			p += [{"strike": 0.1}, {"strike": 0.6}]
	p += [{"hit": 1.0, "t": 0.9}, {"look": PI * 0.8, "t": 1.3}, {"look": -0.7, "t": 1.5, "elite": true}]
	return p


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var kind: String = args[1]
	var art = load("res://scripts/creature_art/vent/%s.gd" % kind)
	var b := Bake.new(self)
	var ps := poses(kind)
	var cw := 260
	var canvas := Image.create(cw * ps.size(), 520, false, Image.FORMAT_RGBA8)
	canvas.fill(C.ground_colors("vent")[1])
	for i in ps.size():
		var o: Dictionary = ps[i]
		var img: Image = await b.bake(Vector2i(cw, 300), func(ci): art.draw(ci, Vector2(cw * 0.5, 280), 230.0, o))
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * cw, 0))
		var small: Image = await b.bake(Vector2i(120, 110), func(ci):
			C.draw_ground(ci, Rect2(0, 0, 120, 110), "vent", 3 + i)
			art.draw(ci, Vector2(60, 95), art.HEIGHT * C.S1080, o))
		canvas.blend_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(i * cw + 4, 310))
		var mono := o.duplicate()
		Ink.mono = true
		var sil: Image = await b.bake(Vector2i(120, 110), func(ci): art.draw(ci, Vector2(60, 95), art.HEIGHT * C.S1080 * 1.2, mono))
		Ink.mono = false
		var paper := Image.create(120, 110, false, Image.FORMAT_RGBA8)
		paper.fill(Color("e8dcc0"))
		canvas.blend_rect(paper, Rect2i(0, 0, 120, 110), Vector2i(i * cw + 134, 310))
		canvas.blend_rect(sil, Rect2i(Vector2i.ZERO, sil.get_size()), Vector2i(i * cw + 134, 310))
	canvas.save_png(out)
	quit(0)
