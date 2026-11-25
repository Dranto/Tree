## Outils partagés des Flétris de Vent (« Bestiaire d'herbier ») : plumes, traits de vent, collier d'élite.
## Pas une sorte (aucun id de enemies.json ne s'appelle « _commun ») : le moteur ne le cuit pas.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")


static func pal(clair: String = "clair", ombre: String = "ombre", reflet: String = "reflet") -> Dictionary:
	return {"clair": Art.bc("vent", clair), "ombre": Art.bc("vent", ombre), "reflet": Art.bc("vent", reflet)}


## Une plume (repère local) : base b, direction a, longueur l, largeur w ; rachis clair, pointe rongée
## par la cendre si ash > 0 (bout sombre, braise au bord).
static func feather(ci: CanvasItem, xf: Transform2D, b: Vector2, a: float, l: float, w: float, col: Dictionary, ink := 1.2, ash := 0.0) -> void:
	var shape := Ink.leaf(b, a, l, w, 0.06)
	Ink.part(ci, xf, shape, col, ink, 1.0, 0.3)
	var d := Vector2.from_angle(a)
	Ink.brush(ci, xf, PackedVector2Array([b + d * l * 0.08, b + d * l * 0.85]), 0.9, col["ombre"].darkened(0.35), 1.0, 0.0)
	if ash > 0.0:
		var tip := b + d * l * (1.0 - 0.28 * ash)
		Ink.flat(ci, xf, Ink.leaf(tip, a, l * 0.3 * ash, w * 0.7, 0.0), Art.bc("ronge"))
		Ink.brush(ci, xf, PackedVector2Array([tip + d.orthogonal() * w * 0.3, tip - d.orthogonal() * w * 0.3]), 1.0, Art.bc("braise"))


## Traits du vent : n filets clairs qui filent de p vers dir (repère local), sur une longueur l.
static func gusts(ci: CanvasItem, xf: Transform2D, p: Vector2, dir: Vector2, n: int, l: float, t: float, k := 1.0, spread := 10.0) -> void:
	if Ink.mono or k <= 0.0:
		return
	var nn := dir.orthogonal()
	for i in n:
		var u := fposmod(t * 2.4 + i / float(n), 1.0)
		var off := nn * (i - (n - 1) * 0.5) * spread * (0.6 + u)
		var a := p + off + dir * l * u
		var pts := PackedVector2Array([a, a + dir * l * 0.3 + nn * 2.0 * sin(t * 6.0 + i), a + dir * l * 0.55])
		Ink.brush(ci, xf, pts, 2.2, Color(Art.bc("vent", "reflet"), 0.8 * k * (1.0 - u)))


## Collier d'élite des plateaux : une tresse d'herbe blonde autour du cou (c, rayons rx/ry, local),
## liseré doré, trois pierres de lichen pendues. Rien en silhouette noire (le moteur agrandit l'atlas).
static func collar(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float, ry: float, rot := 0.0) -> void:
	if Ink.mono:
		return
	var front := PackedVector2Array()
	for i in 13:
		var a := lerpf(0.05, PI - 0.05, i / 12.0)
		front.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	Ink.brush(ci, xf, front, 6.0, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, front, 4.4, Art.c("or"), 1.0, 1.0)
	Ink.brush(ci, xf, front, 2.4, Art.bc("vent", "detail"), 1.0, 1.0)
	for j in 3:
		var q: Vector2 = front[3 + j * 3]
		var gem := Ink.oval(q + Vector2(0, 3.4), 2.4, 3.0, 12)
		Ink.part(ci, xf, gem, {"clair": Art.bc("vent", "reflet"), "ombre": Art.bc("vent", "clair"), "reflet": Color.WHITE}, 0.9, 1.0, 0.8)
		var gw := xf * Ink.oval(q + Vector2(0, 3.4), 3.0, 3.6, 12)
		gw.append(gw[0])
		ci.draw_polyline(gw, Art.c("or"), 0.6 * xf.get_scale().abs().x, true)
