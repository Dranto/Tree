## Outils partagés des Flétris communs (la Flétrissure pure : cendre, braise, écorce morte).
## Ce fichier ne porte le nom d'aucune sorte : le moteur ne le prend pas pour un dessin.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")


## Cendre pâle (corps).
static func pal() -> Dictionary:
	return {"clair": Art.bc("commun", "clair"), "ombre": Art.bc("commun", "ombre"), "reflet": Art.bc("commun", "reflet")}


## Écorce brûlée (plaques, membres) : sombre, avec un reflet de cendre.
static func char_pal() -> Dictionary:
	var c := Art.bc("commun", "charbon")
	return {"clair": c, "ombre": Art.bc("commun", "detail"), "reflet": Art.bc("commun", "clair")}


## Os des griffes et des cornes.
static func bone() -> Dictionary:
	return {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.35), "reflet": Color.WHITE}


## Fente de braise dans l'écorce : un creux d'encre et la braise qui couve dedans (glow 0 → 1).
static func crack(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, w: float, glow: float, t := 0.0) -> void:
	Ink.brush(ci, xf, pts, w * 1.9, Ink.encre())
	var flick := 0.8 + 0.2 * sin(t * 6.0 + pts[0].x * 0.3)
	Ink.brush(ci, xf, pts, w * (0.7 + 0.5 * glow), Art.bc("braise").lerp(Art.bc("braise_coeur"), glow * 0.6) * Color(1, 1, 1, clampf(0.45 + 0.55 * glow * flick, 0.0, 1.0)))


## Flocons de cendre qui montent depuis p (repère local) : n losanges pâles qui s'éteignent.
static func ash(ci: CanvasItem, xf: Transform2D, p: Vector2, n: int, t: float, s := 2.2, spread := 14.0) -> void:
	if Ink.mono:
		return
	var k := xf.get_scale().abs().x
	for i in n:
		var u := fposmod(t * 0.45 + i / float(n), 1.0)
		var q := xf * (p + Vector2(sin(TAU * u + i * 1.9) * spread * 0.5 + (i - n * 0.5) * 3.0, -u * 34.0))
		var r := s * k * (1.0 - 0.4 * u)
		var col := Color(Art.bc("commun", "reflet"), 0.75 * sin(PI * u))
		ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -r * 1.4), q + Vector2(r, 0), q + Vector2(0, r * 1.4), q + Vector2(-r, 0)]), col)


## Deux yeux de braise (celui du fond plus petit), plissés sous un coup, qui clignent au repos.
static func eyes(ci: CanvasItem, xf: Transform2D, near: Vector2, far: Vector2, s: float, glow: float, hit: float, t: float, salt := 0.0) -> void:
	if hit > 0.4 or (glow < 0.35 and Ink.blink(t, salt) > 0.0):
		Ink.brush(ci, xf, PackedVector2Array([near + Vector2(-s * 0.5, 0), near + Vector2(s * 0.5, s * 0.1)]), s * 0.3, Ink.encre())
		Ink.brush(ci, xf, PackedVector2Array([far + Vector2(-s * 0.3, 0), far + Vector2(s * 0.3, s * 0.1)]), s * 0.25, Ink.encre())
		return
	Ink.ember(ci, xf, Ink.leaf(near + Vector2(-s * 0.5, 0), -0.2, s, s * 0.45), glow)
	Ink.ember(ci, xf, Ink.leaf(far + Vector2(-s * 0.3, 0), -0.28, s * 0.6, s * 0.32), glow)


## Liseré doré de l'élite : la forme du corps, un peu plus large que l'encre, en or (à dessiner avant elle).
static func elite_rim(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, ink: float) -> void:
	if Ink.mono:
		return
	var w := xf * pts
	var k := xf.get_scale().abs().x
	for poly in Geometry2D.offset_polygon(w, ink * k * Ink.INK + 1.8 * k, Geometry2D.JOIN_ROUND):
		if not Geometry2D.triangulate_polygon(poly).is_empty():
			ci.draw_colored_polygon(poly, Art.c("or"))


## Collier de l'élite : un rang de perles à la couleur de la région (les communs vont partout), serti d'or.
static func elite_collar(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float, ry: float, region: String, t: float) -> void:
	var col := Art.bc("commun", "reflet")
	var r = Art.BESTIAIRE.get(region, null)
	if r is Dictionary and r.has("clair"):
		col = r["clair"].lightened(0.15)
	var gold := {"clair": Art.c("or"), "ombre": Art.c("or").darkened(0.4), "reflet": Color.WHITE}
	var bead := {"clair": col, "ombre": col.darkened(0.45), "reflet": col.lightened(0.5)}
	# Le cordon d'or, puis les perles du devant (celles du fond sont cachées par le corps).
	var cord := PackedVector2Array()
	for i in 9:
		var a := PI * (0.05 + 0.9 * i / 8.0)
		cord.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	Ink.brush(ci, xf, cord, 3.4, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, cord, 1.8, Art.c("or"), 1.0, 1.0)
	for i in 5:
		var a := PI * (0.15 + 0.7 * i / 4.0)
		var q := c + Vector2(cos(a) * rx, sin(a) * ry)
		var rr := (2.6 if i == 2 else 1.9) * (1.0 + 0.06 * sin(t * 3.0 + i))
		Ink.part(ci, xf, Ink.oval(q + Vector2(0, rr * 0.6), rr, rr * 1.15, 12), bead if i != 2 else gold, 1.0, 1.0, 0.8)
