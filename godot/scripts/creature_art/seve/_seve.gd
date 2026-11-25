## Outils communs aux Flétris de la vallée des sources (Sève, refonte « Bestiaire d'herbier », R4) :
## palette de la région, collier d'élite (feuilles de nénuphar et perles de rosée, liseré doré),
## gouttes de vase qui tombent, lueur de la vie bue. Ce fichier n'est pas une sorte (nom en « _ »).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")


## Palette du corps (Art.BESTIAIRE › seve). dark : 0 → 1 pour les parties du fond.
static func pal(dark := 0.0) -> Dictionary:
	var p := {"clair": Art.bc("seve", "clair"), "ombre": Art.bc("seve", "ombre"), "reflet": Art.bc("seve", "reflet")}
	if dark > 0.0:
		p = {"clair": p["clair"].darkened(0.35 * dark), "ombre": p["ombre"].darkened(0.35 * dark), "reflet": p["clair"]}
	return p


## Palette de la vase (ventre, pattes, détails boueux).
static func mud() -> Dictionary:
	var v := Art.bc("seve", "vase")
	return {"clair": v.lightened(0.18), "ombre": v.darkened(0.3), "reflet": Art.bc("seve", "detail")}


## Palette de l'os (dents, griffes).
static func bone() -> Dictionary:
	return {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}


## Vert de la sève vivante (vie bue, soin) : clair, couleur.
static func sap(k := 1.0) -> Color:
	return Art.ec("seve").lerp(Art.ec("seve", "clair"), 0.3 * k)


## Gouttes de vase qui tombent de p (repère local) : n gouttes, cycle de t.
static func drips(ci: CanvasItem, xf: Transform2D, p: Vector2, n: int, t: float, s: float, col: Color, k := 1.0) -> void:
	if Ink.mono or k <= 0.0:
		return
	var sc := xf.get_scale().abs().x
	for i in n:
		var u := fposmod(t * 0.7 + i / float(n) + p.x * 0.021, 1.0)
		var q := p + Vector2(i * 3.0 - n * 1.5, u * u * 18.0)
		var r := s * (0.6 + 0.6 * minf(u * 3.0, 1.0)) * sc
		var c := Color(col, (1.0 - u) * k)
		ci.draw_circle(xf * q, r, c)
		ci.draw_circle(xf * (q + Vector2(0, -r / sc * 0.9)), r * 0.6, c)


## Collier d'élite : une guirlande de feuilles de nénuphar et de perles de rosée posée sur l'arc
## (centre c, rayons rx, ry, côté avant), puis un liseré doré le long de rim (bord haut du corps).
static func elite(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float, ry: float, t: float, rim := PackedVector2Array()) -> void:
	if not rim.is_empty():
		Ink.brush(ci, xf, rim, 2.4, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, xf, rim, 1.3, Art.c("or"), 1.0, 1.0)
	var pad := {"clair": Art.ec("racine", "clair").darkened(0.2), "ombre": Art.ec("racine", "clair").darkened(0.55), "reflet": Art.ec("seve", "clair")}
	var n := 6
	for i in n:
		var a := PI * (0.12 + 0.76 * i / float(n - 1))
		var q := c + Vector2(cos(a) * rx, sin(a) * ry)
		if i % 2 == 0:
			var lp := Ink.oval(q, 4.6, 3.4, 14, 0.25 * sin(t * 1.3 + i))
			Ink.part(ci, xf, lp, pad, 1.2, 1.0, 0.4)
			Ink.brush(ci, xf, PackedVector2Array([q, q + Vector2(3.6, -1.6)]), 0.9, pad["ombre"].darkened(0.3))
		else:
			Ink.part(ci, xf, Ink.oval(q, 2.4, 2.4, 12), {"clair": Art.c("or").lightened(0.25), "ombre": Art.c("or").darkened(0.25), "reflet": Color.WHITE}, 1.0, 1.0, 1.0)


## Lueur de la vie bue ou de la sève qui monte : halo vert doux en p (repère local), rayon r.
static func sap_glow(ci: CanvasItem, xf: Transform2D, p: Vector2, r: float, k: float) -> void:
	if Ink.mono or k <= 0.0:
		return
	Ink.halo(ci, xf * p, r * xf.get_scale().abs().x, sap(), k * 1.4)
