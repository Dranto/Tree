## Génère l'icône du jeu (PNG + ICO) et l'écran de démarrage, aux couleurs de l'Herbier, par le code.
## Lancer : tools/export.sh --icon   (ou tools/godot.sh --xvfb -s res://tools/gen_icon.gd)
## Sorties : assets/icon/icon.png (256), icon.ico (16-256), splash.png (1280 x 720).
extends SceneTree

const PAPER := Color("2a2118")
const PAPER_LIGHT := Color("3a2e21")
const IVORY := Color("f3ead2")
const GOLD := Color("d9b566")
const LEAF := Color("8af5c0")
const LEAF_DARK := Color("3e5a35")


class Drawing extends Node2D:
	var mode := "icon"
	var size_px := Vector2(512, 512)

	func _draw() -> void:
		if mode == "icon":
			_icon(Vector2(256, 256), 256.0)
		else:
			draw_rect(Rect2(Vector2.ZERO, size_px), PAPER)
			# Filets d'or en bordure, comme un cadre de planche botanique.
			draw_rect(Rect2(Vector2(24, 24), size_px - Vector2(48, 48)), Color(GOLD, 0.45), false, 2.0)
			draw_rect(Rect2(Vector2(34, 34), size_px - Vector2(68, 68)), Color(GOLD, 0.25), false, 1.0)
			_icon(size_px * 0.5 + Vector2(0, -10), 170.0)

	func _icon(c: Vector2, r: float) -> void:
		if mode == "icon":
			# Fond : papier brun à coins arrondis, cerclé d'or.
			var pts := PackedVector2Array()
			var half := r * 0.97
			var rad := r * 0.3
			var centres := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
			for k in 4:
				var inner: Vector2 = c + (centres[k] as Vector2) * (half - rad)
				var a0: float = PI * 0.5 * k
				for s in 9:
					var ang: float = a0 + PI * 0.5 * s / 8.0
					pts.append(inner + Vector2(cos(ang), sin(ang)) * rad)
			draw_colored_polygon(pts, PAPER)
			pts.append(pts[0])
			draw_polyline(pts, Color(GOLD, 0.7), r * 0.025, true)
		r *= 1.3
		c.y -= r * 0.09
		# Tronc : une courbe ivoire qui s'élargit vers la base.
		var base := c + Vector2(0, r * 0.62)
		var top := c + Vector2(r * 0.02, -r * 0.1)
		var trunk := PackedVector2Array()
		for s in 21:
			var t := s / 20.0
			var p := base.lerp(top, t) + Vector2(sin(t * PI * 1.4) * r * 0.06, 0)
			trunk.append(p)
		for s in 20:
			var w := lerpf(r * 0.07, r * 0.025, s / 20.0)
			draw_line(trunk[s], trunk[s + 1], IVORY, w * 2.0, true)
		# Racines.
		for d in [-1.0, 1.0]:
			draw_polyline(PackedVector2Array([base, base + Vector2(d * r * 0.12, r * 0.05), base + Vector2(d * r * 0.26, r * 0.07)]), Color(IVORY, 0.8), r * 0.035, true)
		# Branches et feuilles : trois paires, la dernière dorée (la greffe).
		var rows := [[0.35, 0.34, LEAF_DARK], [0.6, 0.27, LEAF], [0.85, 0.2, GOLD]]
		for row in rows:
			var p: Vector2 = trunk[int(row[0] * 20)]
			for d in [-1.0, 1.0]:
				var tip: Vector2 = p + Vector2(d * r * row[1], -r * 0.2)
				draw_line(p, p + (tip - p) * 0.55, IVORY, r * 0.04, true)
				_leaf(p + (tip - p) * 0.5, tip, r * 0.13, row[2])
		_leaf(top, top + Vector2(0, -r * 0.34), r * 0.14, GOLD)

	func _leaf(a: Vector2, b: Vector2, wd: float, col: Color) -> void:
		var dir := (b - a)
		var n := Vector2(-dir.y, dir.x).normalized() * wd
		var pts := PackedVector2Array()
		for s in 13:
			var t := s / 12.0
			pts.append(a + dir * t + n * sin(t * PI))
		for s in 13:
			var t := 1.0 - s / 12.0
			pts.append(a + dir * t - n * sin(t * PI))
		draw_colored_polygon(pts, col)
		draw_line(a, b, Color(PAPER, 0.55), wd * 0.1, true)


func _render(mode: String, size: Vector2i) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = (mode == "icon")
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var d := Drawing.new()
	d.mode = mode
	d.size_px = Vector2(size)
	vp.add_child(d)
	root.add_child(vp)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


func _initialize() -> void:
	var out := ProjectSettings.globalize_path("res://assets/icon/")
	DirAccess.make_dir_recursive_absolute(out)
	var big := await _render("icon", Vector2i(512, 512))
	var sizes := [256, 48, 32, 16]
	var pngs := []
	for s in sizes:
		var im := big.duplicate() as Image
		im.resize(s, s, Image.INTERPOLATE_LANCZOS)
		pngs.append(im.save_png_to_buffer())
		if s == 256:
			im.save_png(out + "icon.png")
	# ICO : en-tête, répertoire, puis les PNG tels quels (accepté par Windows depuis Vista).
	var ico := PackedByteArray()
	ico.resize(6)
	ico.encode_u16(0, 0)
	ico.encode_u16(2, 1)
	ico.encode_u16(4, sizes.size())
	var offset := 6 + 16 * sizes.size()
	var dir := PackedByteArray()
	for i in sizes.size():
		var e := PackedByteArray()
		e.resize(16)
		e.encode_u8(0, 0 if sizes[i] >= 256 else sizes[i])
		e.encode_u8(1, 0 if sizes[i] >= 256 else sizes[i])
		e.encode_u16(4, 1)
		e.encode_u16(6, 32)
		e.encode_u32(8, pngs[i].size())
		e.encode_u32(12, offset)
		offset += pngs[i].size()
		dir.append_array(e)
	ico.append_array(dir)
	for p in pngs:
		ico.append_array(p)
	var f := FileAccess.open(out + "icon.ico", FileAccess.WRITE)
	f.store_buffer(ico)
	f.close()
	var splash := await _render("splash", Vector2i(1280, 720))
	splash.save_png(out + "splash.png")
	print("Icône et écran de démarrage écrits dans ", out)
	quit()
