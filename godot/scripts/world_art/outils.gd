## Outils de dessin des « Paysages d'herbier » (refonte du monde, vague 0 : planche W).
##
## Le monde reprend la grammaire du bestiaire (scripts/creature_art/ink.gd, lu sans le modifier) :
## lumière d'en haut à gauche, deux tons et un reflet, encre décalée vers l'ombre. Différences :
##   - l'encre du décor est plus fine que celle des créatures (DECOR_INK), celle du sol presque absente ;
##   - chaque objet pose une ombre portée vers le bas à droite (opposée à la lumière) ;
##   - le hasard est tiré d'une grille du monde (hash de la cellule) : un même endroit se dessine
##     toujours pareil, quel que soit le cadre ou l'image (le GIF du bord de vie ne « bouge » pas).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")

## Épaisseur de l'encre du décor par rapport à celle des créatures (Ink.part, même unité).
const DECOR_INK := 0.55
## Direction de l'ombre portée au sol (opposée à Ink.LIGHT, aplatie par la vue de trois quarts).
const SHADOW_DIR := Vector2(0.62, 0.30)


## Générateur reproductible pour une cellule de la grille du monde (et un sel par usage).
static func rng_at(cell: Vector2i, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([cell.x, cell.y, salt])
	return r


## Bruit doux reproductible (somme de sinus) : pour les bords ondulés, sans texture.
static func wave(x: float, seed: float) -> float:
	return sin(x * 1.0 + seed) * 0.5 + sin(x * 2.3 + seed * 1.7) * 0.3 + sin(x * 5.1 + seed * 0.3) * 0.2


## Tache organique : ellipse dont le bord ondule doucement (lavis, flaques, mousses).
static func blob(c: Vector2, rx: float, ry: float, seed: float, amp := 0.18, n := 36, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var m := 1.0 + amp * wave(a * 2.0, seed)
		pts.append(c + Vector2(cos(a) * rx * m, sin(a) * ry * m).rotated(rot))
	return pts


static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		ci.draw_colored_polygon(pts, col)


## Ombre portée d'un objet posé en base, de largeur w et de hauteur h (px du monde) : une ellipse
## allongée vers le bas à droite, plus longue pour un objet haut.
static func cast_shadow(ci: CanvasItem, base: Vector2, w: float, h: float, alpha := 0.32) -> void:
	if Ink.mono:
		return
	var len := w * 0.5 + h * 0.32
	var c := base + SHADOW_DIR * len * 0.42
	var pts := blob(c, len * 0.62, maxf(w * 0.22, 4.0) + h * 0.04, base.x * 0.01, 0.08, 28, 0.18)
	poly(ci, pts, Color(0.05, 0.03, 0.04, alpha))
	poly(ci, blob(base + Vector2(w * 0.04, 1.0), w * 0.5, maxf(w * 0.14, 3.0), base.y, 0.06, 22), Color(0.04, 0.02, 0.03, alpha * 0.9))


## Une forme du décor : encre fine, deux tons, reflet (Ink.part en unités du monde).
static func part(ci: CanvasItem, pts: PackedVector2Array, pal: Dictionary, ink := 1.4, lit := 1.0, shine := 0.6) -> void:
	Ink.part(ci, Transform2D.IDENTITY, pts, pal, ink * DECOR_INK / Ink.INK, lit, shine)


## Coup de pinceau du décor (en px du monde).
static func brush(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color, t0 := 0.0, t1 := 0.0) -> void:
	Ink.brush(ci, Transform2D.IDENTITY, pts, w, col, t0, t1)


## Courbe de Bézier quadratique a → b, tirée vers c, en n points.
static func curve(a: Vector2, c: Vector2, b: Vector2, n := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		pts.append(a.lerp(c, u).lerp(c.lerp(b, u), u))
	return pts


## Couleur assombrie pour le premier plan (objets qui passent devant, plus sombres et plus flous).
static func fg(col: Color, k: float) -> Color:
	return col.darkened(0.45 * k).lerp(Color(0.06, 0.04, 0.05), 0.25 * k)


static func pal_fg(pal: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in pal:
		out[key] = fg(pal[key], k)
	return out


## Brin d'herbe : coup de pinceau courbe, de la base b, hauteur h, penché de lean.
static func blade(ci: CanvasItem, b: Vector2, h: float, lean: float, w: float, col: Color) -> void:
	var tip := b + Vector2(lean * h, -h)
	var mid := b + Vector2(lean * h * 0.3, -h * 0.6)
	brush(ci, PackedVector2Array([b, mid, tip]), w, col, 1.0, 0.0)


## Touffe d'herbe : 5-9 brins en éventail, plus hauts au milieu. dry : herbe sèche couchée.
static func tuft(ci: CanvasItem, b: Vector2, h: float, c1: Color, c2: Color, seed: int, dry := false) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var n := r.randi_range(5, 9)
	for i in n:
		var u := (float(i) / (n - 1)) * 2.0 - 1.0
		var hh := h * (1.0 - 0.45 * absf(u)) * r.randf_range(0.75, 1.1)
		var lean := u * 0.55 + r.randf_range(-0.12, 0.12) + (0.35 if dry else 0.0)
		var col := c1 if (i % 2 == 0) else c2
		blade(ci, b + Vector2(u * h * 0.22, 0.0), hh * (0.7 if dry else 1.0), lean, maxf(h * 0.11, 1.1), col)


## Caillou : petit galet deux tons avec encre très fine.
static func pebble(ci: CanvasItem, c: Vector2, r: float, pal: Dictionary, seed: float) -> void:
	poly(ci, blob(c + Vector2(r * 0.3, r * 0.35), r * 1.1, r * 0.5, seed, 0.1, 14), Color(0, 0, 0, 0.22))
	part(ci, blob(c, r, r * 0.68, seed, 0.16, 16), pal, 1.0, 1.0, 0.5)


## Fleur à cinq pétales vue de trois quarts (églantine, ou petite fleur), rayon r.
static func flower(ci: CanvasItem, c: Vector2, r: float, petal: Color, heart: Color, rot := 0.0, open := 1.0) -> void:
	if r < 0.4:
		return
	var rr := r * (0.35 + 0.65 * open)
	for i in 5:
		var a := rot + TAU * i / 5.0
		var p := c + Vector2(cos(a), sin(a) * 0.62) * rr * 0.55
		poly(ci, blob(p, rr * 0.52, rr * 0.4, float(i) + rot, 0.08, 10, a), petal.darkened(0.12))
		poly(ci, blob(p - Vector2(0.3, 0.4) * rr * 0.12, rr * 0.4, rr * 0.3, float(i) + rot, 0.08, 10, a), petal)
	ci.draw_circle(c, rr * 0.24, heart)
