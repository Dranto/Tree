## Test du lot de triangles fidèle (draw_batch.gd, exact = true) : chaque forme dessinée par le
## lot doit donner les mêmes pixels que le même appel de CanvasItem. Rendu réel : lancer avec
##   tools/godot.sh --xvfb -s res://tests/draw_batch_test.gd
extends SceneTree

const DrawBatch = preload("res://scripts/draw_batch.gd")
const SIZE := Vector2i(480, 360)

var failures := 0


class Canvas extends Node2D:
	var batched := false
	var shapes: Callable

	func _draw() -> void:
		if batched:
			var b = DrawBatch.new()
			b.exact = true
			shapes.call(b)
			b.flush(self)
		else:
			shapes.call(self)


func _initialize() -> void:
	_run.call_deferred()


func _viewport(batched: bool, shapes: Callable) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	var c := Canvas.new()
	c.batched = batched
	c.shapes = shapes
	vp.add_child(c)
	root.add_child(vp)
	return vp


func _compare(label: String, shapes: Callable) -> void:
	var a := _viewport(false, shapes)
	var b := _viewport(true, shapes)
	for i in 4:
		await process_frame
	var ia := a.get_texture().get_image()
	var ib := b.get_texture().get_image()
	var diff := 0
	var worst := 0
	for y in SIZE.y:
		for x in SIZE.x:
			var ca := ia.get_pixel(x, y)
			var cb := ib.get_pixel(x, y)
			var d := roundi(maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b)) * 255.0)
			worst = maxi(worst, d)
			if d > 0:
				diff += 1
	var ok := diff == 0
	if not ok:
		failures += 1
		ia.save_png("/tmp/claude-0/s/batch_%s_natif.png" % label)
		ib.save_png("/tmp/claude-0/s/batch_%s_lot.png" % label)
	print("LOT %-10s %s  pixels différents %d, écart max %d" % [label, "OK" if ok else "ÉCHEC", diff, worst])
	a.queue_free()
	b.queue_free()


func _run() -> void:
	var col := Color(0.8, 0.5, 0.3, 0.7)
	await _compare("cercles", func(ci):
		var i := 0
		for r in [0.6, 1.2, 2.3, 3.7, 5.5, 9.0, 17.3, 41.0]:
			for k in 3:
				ci.draw_circle(Vector2(20 + i * 55 + k * 0.37, 40 + k * 60 + r + 0.21 * k), r, Color(col, 0.5 + 0.15 * k))
			i += 1)
	await _compare("polygones", func(ci):
		for i in 12:
			var pts := PackedVector2Array()
			for j in 7:
				var a := j * TAU / 7.0 + i
				pts.append(Vector2(40 + (i % 6) * 75, 60 + (i / 6) * 150) + Vector2.from_angle(a) * (20.0 + 9.0 * sin(j * 3.0 + i)))
			ci.draw_colored_polygon(pts, Color(col, 0.9)))
	await _compare("traits", func(ci):
		for i in 20:
			var a := Vector2(10 + i * 23.3, 20.5)
			ci.draw_line(a, a + Vector2.from_angle(i * 0.4) * 60.0, col, 0.7 + i * 0.35))
	await _compare("polylignes", func(ci):
		for i in 8:
			var pts := PackedVector2Array()
			for j in 6:
				pts.append(Vector2(30 + i * 55 + sin(j * 1.7 + i) * 18.0, 30 + j * 40.3 + cos(j + i) * 9.0))
			ci.draw_polyline(pts, Color(col, 0.8), 1.0 + i * 0.8))
	await _compare("arcs", func(ci):
		for i in 10:
			ci.draw_arc(Vector2(50 + (i % 5) * 90, 90 + (i / 5) * 170), 20.0 + i * 3.3, 0.3 * i, 0.3 * i + 1.0 + i * 0.6, 6 + i * 4, Color(col, 0.85), 1.0 + i * 0.5))
	print("LOT %s" % ("réussi" if failures == 0 else "%d échecs" % failures))
	quit(1 if failures > 0 else 0)
