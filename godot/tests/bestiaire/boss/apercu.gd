## Aperçu de travail d'un boss « Bestiaire d'herbier » (scripts/creature_art/<région>/_<boss>.gd) :
## toutes ses poses cuites, en grand, sur le sol de sa région.
##   tools/godot.sh --xvfb -s res://tests/bestiaire/boss/apercu.gd -- sortie.png ronce/_mere_ronce [échelle] [daltonisme]
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var art = load("res://scripts/creature_art/%s.gd" % args[1])
	var k := float(args[2]) if args.size() > 2 else 1.0
	if args.size() > 3:
		# Après les réglages (Settings les applique à son démarrage).
		await process_frame
		await process_frame
		Art.set_access(args[3])
	var b := Bake.new(self)
	var poses := []
	var groups: Dictionary = art.groups()
	for g in groups:
		var seen := {}
		for p in groups[g]["poses"]:
			# Une image par animation (et la mort entière).
			if seen.has(p[0]) and p[0] != "mort" and not str(p[0]).begins_with("x"):
				continue
			seen[p[0]] = true
			var o: Dictionary = p[1].duplicate()
			o["groupe"] = g
			poses.append([g, p[0], o, groups[g]["rect"]])
	var h: float = art.HEIGHT * k
	var cell := Vector2i(int(240 * h / 100.0), int(220 * h / 100.0))
	var cols := 4
	var canvas := Image.create(cell.x * cols, cell.y * ceili(poses.size() / float(cols)), false, Image.FORMAT_RGBA8)
	canvas.fill(Color("4a3a30"))
	for i in poses.size():
		var p: Array = poses[i]
		var r: Rect2 = p[3]
		var feet := Vector2(cell.x * 0.5, cell.y - 20.0 * h / 100.0)
		var img: Image = await b.bake(cell, func(ci):
			ci.draw_rect(Rect2(feet + r.position * h / 100.0, r.size * h / 100.0), Color(1, 1, 1, 0.15), false, 1.0)
			art.draw(ci, feet, h, p[2]), 2)
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * cell.x, (i / cols) * cell.y))
	canvas.save_png(args[0])
	quit(0)
