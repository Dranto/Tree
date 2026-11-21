## Lot de triangles colorés : imite draw_colored_polygon, draw_circle, draw_line, draw_polyline et
## draw_arc d'un CanvasItem, puis envoie tout en un seul appel de rendu
## (RenderingServer.canvas_item_add_triangle_array). Sert aux silhouettes des Flétris : une centaine
## de petites formes par ennemi deviennent un seul appel, ce qui tient 120 Flétris à l'écran.
## L'ordre des formes est conservé (la dernière est dessinée par-dessus).
extends RefCounted

## Tracé « fidèle » : cercles, traits, polylignes et arcs découpés exactement comme le fait
## Godot 4.3 (draw_circle à 64 points, polyligne en bande de triangles), pour qu'un dessin passé
## au lot donne les mêmes pixels qu'avant (décor, fleurs). Faux : tracé allégé des silhouettes.
var exact := false
## Tracé « économe » (silhouettes mises en cache, silhouette_cache.gd) : polylignes en une bande à
## joints en onglet (deux sommets par point au lieu de quatre par segment, plus les disques des
## coudes) et petits disques à moins de côtés. Moitié moins de sommets : chaque sommet est calculé
## par le processeur en rendu logiciel. Ignoré si exact est vrai.
var lean := false

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


## Comme CanvasItem.draw_primitive : un triangle ou un quadrilatère (deux triangles) dont chaque
## sommet a sa couleur (dégradé). Les coordonnées de texture sont ignorées.
func draw_primitive(pts: PackedVector2Array, cols: PackedColorArray, _uvs := PackedVector2Array(), _tex = null) -> void:
	var n := pts.size()
	if (n != 3 and n != 4) or cols.size() < n:
		return
	var base := points.size()
	points.append_array(pts)
	for i in n:
		colors.append(cols[i])
	indices.append_array(PackedInt32Array([base, base + 1, base + 2]))
	if n == 4:
		indices.append_array(PackedInt32Array([base + 2, base + 3, base]))


func draw_circle(c: Vector2, r: float, col: Color, _filled := true, _width := -1.0, _aa := false) -> void:
	if col.a <= 0.0 or r <= 0.0:
		return
	if exact:
		_push(_circle_points(c, r), col, CIRCLE_TRI)
		return
	# Disque à n côtés (centre + n points) : forme unité en cache, placée par une transformation.
	var d: Array = _DISCS[clampi(int(r) + 5, 6, 28) if lean else clampi(int(r * 0.7) + 8, 10, 28)]
	_push(Transform2D(0.0, Vector2(r, r), 0.0, c) * (d[0] as PackedVector2Array), col, d[1])


## Couronne entre deux cercles concentriques (mode « exact » : mêmes 64 points que draw_circle).
## Des disques opaques empilés, du grand au petit, donnent les mêmes pixels qu'une suite de couronnes,
## sans redessiner les pixels du centre à chaque couche (le coût en rendu logiciel suit les pixels).
func ring(c: Vector2, r_out: float, r_in: float, col: Color) -> void:
	if col.a <= 0.0 or r_out <= r_in:
		return
	var outer := _circle_points(c, r_out)
	var inner := _circle_points(c, r_in)
	var n := outer.size()
	var base := points.size()
	points.append_array(outer)
	points.append_array(inner)
	for i in n * 2:
		colors.append(col)
	for i in n:
		var j := (i + 1) % n
		indices.append_array(PackedInt32Array([base + i, base + j, base + n + j, base + i, base + n + j, base + n + i]))


func draw_line(a: Vector2, b: Vector2, col: Color, width := -1.0, _aa := false) -> void:
	if col.a <= 0.0 or a == b:
		return
	if exact and width < 0.0:
		width = 1.0
	var n := (b - a).orthogonal().normalized() * (width if exact else maxf(width, 1.0)) * 0.5
	_push(PackedVector2Array([a + n, b + n, b - n, a - n]), col, PackedInt32Array([0, 1, 2, 0, 2, 3]))


## Polyligne : un quadrilatère par segment, et un disque à chaque coude pour les traits épais.
func draw_polyline(pts: PackedVector2Array, col: Color, width := -1.0, _aa := false) -> void:
	if col.a <= 0.0:
		return
	if exact or lean:
		_strip(pts, col, width if exact and width > 0.0 else maxf(width, 1.0))
		return
	# Une seule forme pour toute la polyligne (mêmes sommets, même ordre que segment par segment).
	var w := maxf(width, 1.0)
	var n := pts.size()
	var joints := w >= 3.0
	var hex: PackedVector2Array = _DISCS[6][0]
	var out := PackedVector2Array()
	var tri := PackedInt32Array()
	for i in range(1, n):
		var a := pts[i - 1]
		var b := pts[i]
		if a != b:
			var k := out.size()
			var o := (b - a).orthogonal().normalized() * w * 0.5
			out.append_array([a + o, b + o, b - o, a - o])
			tri.append_array([k, k + 1, k + 2, k, k + 2, k + 3])
		if joints and i < n - 1:
			var k := out.size()
			out.append_array(Transform2D(0.0, Vector2(w * 0.5, w * 0.5), 0.0, b) * hex)
			tri.append_array([k, k + 1, k + 2, k, k + 2, k + 3, k, k + 3, k + 4, k, k + 4, k + 5, k, k + 5, k + 6, k, k + 6, k + 1])
	if not tri.is_empty():
		_push(out, col, tri)


func _joint(c: Vector2, r: float, col: Color) -> void:
	var d: Array = _DISCS[6]
	_push(Transform2D(0.0, Vector2(r, r), 0.0, c) * (d[0] as PackedVector2Array), col, d[1])


## Disques unité à n côtés, en cache : [points (centre puis tour), triangles en éventail].
static var _DISCS := _all_discs()

static func _all_discs() -> Dictionary:
	var out := {}
	for n in range(6, 29):
		out[n] = _disc(n)
	return out

static func _disc(n: int) -> Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var tri := PackedInt32Array()
	for i in n:
		pts.append(Vector2.from_angle(TAU * i / n))
		tri.append_array([0, 1 + i, 1 + (i + 1) % n])
	return [pts, tri]


func draw_arc(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, width := -1.0, _aa := false) -> void:
	if exact:
		# Comme CanvasItem.draw_arc : n points, écart d'angle borné à un tour.
		var span := clampf(a1 - a0, -TAU, TAU)
		var arc := PackedVector2Array()
		for i in n:
			var th := i / (n - 1.0) * span + a0
			arc.append(c + Vector2(cos(th), sin(th)) * r)
		draw_polyline(arc, col, width)
		return
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r)
	draw_polyline(pts, col, width)


## --- Tracé fidèle (exact = true) ---

const CIRCLE_POINTS := 64
## Allongement maximal d'un joint en onglet, comme Godot 4.3 (vérifié par tests/draw_batch_test.gd).
const MITER_LIMIT := 3.0
static var CIRCLE_TRI := _fan(CIRCLE_POINTS)
static var _UNIT_CIRCLE := _unit_circle()


static func _fan(n: int) -> PackedInt32Array:
	var tri := PackedInt32Array()
	for i in n - 2:
		tri.append_array([0, i + 1, i + 2])
	return tri


static func _unit_circle() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in CIRCLE_POINTS:
		var a := i * TAU / CIRCLE_POINTS
		pts.append(Vector2(cos(a), sin(a)))
	return pts


## Cercle de Godot 4.3 (canvas_item_add_circle) : 64 points, éventail depuis le premier.
static func _circle_points(c: Vector2, r: float) -> PackedVector2Array:
	return Transform2D(0.0, Vector2(r, r), 0.0, c) * _UNIT_CIRCLE


## Polyligne épaisse de Godot 4.3 (canvas_item_add_polyline sans lissage) : une bande de
## triangles, décalée en chaque point selon la bissectrice des deux segments voisins.
## Vérifié pixel à pixel par tests/draw_batch_test.gd.
func _strip(pts: PackedVector2Array, col: Color, width: float) -> void:
	var n := pts.size()
	if n < 2:
		return
	var out := PackedVector2Array()
	out.resize(n * 2)
	var prev_t := Vector2.ZERO
	for i in n:
		var t: Vector2
		if i == n - 1:
			t = prev_t
		else:
			t = (pts[i + 1] - pts[i]).normalized().orthogonal()
			if i == 0:
				prev_t = t
		# Joint en onglet : la demi-largeur est allongée pour garder l'épaisseur dans le coude,
		# au plus MITER_LIMIT fois (coudes aigus des tiges de ronce).
		var m := (t + prev_t).normalized()
		var tan := m * width * 0.5 * minf(1.0 / maxf(m.dot(t), 0.0001), MITER_LIMIT)
		out[i * 2] = pts[i] + tan
		out[i * 2 + 1] = pts[i] - tan
		prev_t = t
	var tri := PackedInt32Array()
	for i in n * 2 - 2:
		tri.append_array([i, i + 1, i + 2])
	_push(out, col, tri)
