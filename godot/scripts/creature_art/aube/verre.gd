## Outils communs des Flétris des falaises de verre (région d'Aube), « Bestiaire d'herbier » : le verre
## fumé de la région (corps), le verre clair des ailes et des aiguilles, l'éclat d'une lumière piégée,
## et la parure d'élite (collier de prismes, liseré d'or). Pas une sorte : aucun id de enemies.json ne
## s'appelle « verre », le moteur ne le cuit donc jamais.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")


## Corps : verre fumé mauve (deux tons + reflet).
static func pal() -> Dictionary:
	return {"clair": Art.bc("aube", "clair"), "ombre": Art.bc("aube", "ombre"), "reflet": Art.bc("aube", "reflet")}


## Verre clair des aiguilles et des prismes (deux tons + reflet blanc).
static func glass() -> Dictionary:
	return {"clair": Art.bc("aube", "verre"), "ombre": Art.bc("aube", "verre_ombre"), "reflet": Art.bc("aube", "lueur")}


## Pattes et chairs rongées : la cendre de la Flétrissure teintée du mauve de la région.
static func ash() -> Color:
	return Art.bc("ronge").lerp(Art.bc("aube", "ombre"), 0.45)


## Contour fermé (encre fine) d'une forme déjà transformée : pour le verre transparent, où l'encre
## pleine d'Ink.part se verrait à travers.
static func rim(ci: CanvasItem, w: PackedVector2Array, width: float, col: Color) -> void:
	var closed := w.duplicate()
	closed.append(w[0])
	ci.draw_polyline(closed, col, width, true)


## Vitre : une forme de verre translucide (aile, facette), cernée d'encre fine, nervures claires.
## alpha : opacité du verre ; veins : coups de pinceau (repère local) le long de la vitre.
static func pane(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, tint: Color, alpha: float, ink := 1.2, veins := []) -> void:
	var w := xf * pts
	var k := xf.get_scale().abs().x
	if Ink.mono:
		Ink._poly(ci, w, Color.BLACK)
		return
	Ink._poly(ci, w, Color(Ink.shade(tint), alpha))
	# Le haut de la vitre prend la lumière : une bande plus claire du côté de la lumière.
	var s := Ink._size(w)
	for poly in Geometry2D.intersect_polygons(w, Ink._shift(w, Ink.LIGHT * s * 0.3)):
		Ink._poly(ci, poly, Color(Ink.shade(Art.bc("aube", "lueur")), alpha * 0.35))
	for v: PackedVector2Array in veins:
		Ink.brush(ci, xf, v, 0.9, Color(Art.bc("aube", "lueur"), 0.8), 0.6, 0.0)
	rim(ci, w, maxf(ink * Ink.INK * k, 0.8), Ink.encre())


## Éclat : étoile à quatre branches (lumière qui accroche le verre), p en coordonnées de l'écran.
static func sparkle(ci: CanvasItem, p: Vector2, r: float, col: Color, a := 1.0, rot := 0.0) -> void:
	if Ink.mono or a <= 0.0 or r <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in 8:
		var ang := rot + PI * i / 4.0
		pts.append(p + Vector2.from_angle(ang) * (r if i % 2 == 0 else r * 0.18))
	ci.draw_circle(p, r * 0.45, Color(col, 0.25 * a))
	Ink._poly(ci, pts, Color(col, a))


## Prisme debout (repère local) : pied en b, demi-largeur hw, hauteur l, penché de lean (radians),
## pointe en biseau. Renvoie [contour, face éclairée (gauche)].
static func prism(b: Vector2, hw: float, l: float, lean := 0.0) -> Array:
	var d := Vector2.from_angle(-PI / 2.0 + lean)
	var n := d.orthogonal()
	var outline := PackedVector2Array([b - n * hw, b - n * hw + d * l * 0.78, b + d * l, b + n * hw + d * l * 0.72, b + n * hw])
	var face := PackedVector2Array([b - n * hw, b - n * hw + d * l * 0.78, b + d * l, b + d * l * 0.7 + n * hw * 0.1, b + n * hw * 0.1])
	return [outline, face]


## Aiguille de quartz pleine : verre clair, face éclairée, arête lumineuse, encre.
static func needle(ci: CanvasItem, xf: Transform2D, b: Vector2, hw: float, l: float, lean := 0.0, glow := 0.0) -> void:
	var p := prism(b, hw, l, lean)
	var g := glass()
	Ink.part(ci, xf, p[0], {"clair": g["ombre"].lerp(g["clair"], 0.45), "ombre": g["ombre"].lerp(g["clair"], 0.45)}, 1.6, 0.0, 0.0)
	if Ink.mono:
		return
	Ink.flat(ci, xf, p[1], g["clair"])
	var d := Vector2.from_angle(-PI / 2.0 + lean)
	Ink.brush(ci, xf, PackedVector2Array([b + d * l * 0.08, b + d * l * 0.95]), 1.1, Color(g["reflet"], 0.85), 0.0, 0.0)
	if glow > 0.0:
		Ink.flat(ci, xf, Ink.oval(b + d * l * 0.45, hw * 0.45, l * 0.18, 12, lean), Color(Art.bc("aube", "detail"), 0.55 * glow))


## Parure d'élite : un collier de petits prismes (le verre de la région) autour du cou c.
static func collar(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float, ry: float, n := 7) -> void:
	for i in n:
		var u := float(i) / (n - 1)
		var a := lerpf(PI * 0.15, PI * 0.85, u)
		var q := c + Vector2(cos(a) * rx, sin(a) * ry)
		needle(ci, xf, q + Vector2(0, 2.0), 2.0, 7.0 - absf(u - 0.5) * 4.0, (u - 0.5) * 0.9)
	if not Ink.mono:
		var arc := PackedVector2Array()
		for i in 9:
			var a := lerpf(PI * 0.1, PI * 0.9, i / 8.0)
			arc.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		Ink.brush(ci, xf, arc, 1.6, Art.c("or"), 1.0, 1.0)


## Liseré d'or de l'élite autour d'une forme (repère local).
static func liseret(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array) -> void:
	if Ink.mono:
		return
	rim(ci, xf * pts, maxf(1.3 * xf.get_scale().abs().x, 1.0), Art.c("or"))
