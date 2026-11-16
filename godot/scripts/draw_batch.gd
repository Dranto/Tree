## Lot de triangles colorés : imite draw_colored_polygon, draw_circle, draw_line, draw_polyline et
## draw_arc d'un CanvasItem, puis envoie tout en un seul appel de rendu
## (RenderingServer.canvas_item_add_triangle_array). Sert aux silhouettes des Flétris : une centaine
## de petites formes par ennemi deviennent un seul appel, ce qui tient 120 Flétris à l'écran.
## L'ordre des formes est conservé (la dernière est dessinée par-dessus).
extends RefCounted

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


func clear() -> void:
	points.clear()
	colors.clear()
	indices.clear()


## Envoie le lot au CanvasItem (à appeler depuis son _draw), puis le vide.
func flush(ci: CanvasItem) -> void:
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)
	clear()


func _push(pts: PackedVector2Array, col: Color, tri: PackedInt32Array) -> void:
	var base := points.size()
	points.append_array(pts)
	for i in pts.size():
		colors.append(col)
	for k in tri:
		indices.append(base + k)


func draw_colored_polygon(pts: PackedVector2Array, col: Color, _uvs := PackedVector2Array(), _tex = null) -> void:
	if col.a <= 0.0 or pts.size() < 3:
		return
	_push(pts, col, Geometry2D.triangulate_polygon(pts))


## Polygone dont la triangulation est déjà connue (même forme, autre échelle : volume).
func polygon_tri(pts: PackedVector2Array, col: Color, tri: PackedInt32Array) -> void:
	if col.a > 0.0 and not tri.is_empty():
		_push(pts, col, tri)


func draw_circle(c: Vector2, r: float, col: Color, _filled := true, _width := -1.0, _aa := false) -> void:
	if col.a <= 0.0 or r <= 0.0:
		return
	var n := clampi(int(r * 0.7) + 8, 10, 28)
	var pts := PackedVector2Array([c])
	var tri := PackedInt32Array()
	for i in n:
		pts.append(c + Vector2.from_angle(TAU * i / n) * r)
		tri.append_array([0, 1 + i, 1 + (i + 1) % n])
	_push(pts, col, tri)


func draw_line(a: Vector2, b: Vector2, col: Color, width := -1.0, _aa := false) -> void:
	if col.a <= 0.0 or a == b:
		return
	var n := (b - a).orthogonal().normalized() * maxf(width, 1.0) * 0.5
	_push(PackedVector2Array([a + n, b + n, b - n, a - n]), col, PackedInt32Array([0, 1, 2, 0, 2, 3]))


## Polyligne : un quadrilatère par segment, et un disque à chaque coude pour les traits épais.
func draw_polyline(pts: PackedVector2Array, col: Color, width := -1.0, _aa := false) -> void:
	if col.a <= 0.0:
		return
	var w := maxf(width, 1.0)
	for i in range(1, pts.size()):
		draw_line(pts[i - 1], pts[i], col, w)
		if w >= 3.0 and i < pts.size() - 1:
			_joint(pts[i], w * 0.5, col)


func _joint(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c])
	var tri := PackedInt32Array()
	for i in 6:
		pts.append(c + Vector2.from_angle(TAU * i / 6.0) * r)
		tri.append_array([0, 1 + i, 1 + (i + 1) % 6])
	_push(pts, col, tri)


func draw_arc(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, width := -1.0, _aa := false) -> void:
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r)
	draw_polyline(pts, col, width)
