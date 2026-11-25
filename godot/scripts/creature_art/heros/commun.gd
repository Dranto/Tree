## Outils partagés par les pistes de héros (planche des pistes, « Bestiaire d'herbier ») : palette selon la
## branche, aura de sève au sol, œil en amande, graine-lanterne.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")

const CREME := Color("f3ead2")


static func leaves(build: String) -> Dictionary:
	var f: Dictionary = Art.FEUILLES_BUILD.get(build, Art.FEUILLES_BUILD["aucun"])
	return {"clair": f["clair"], "ombre": f["ombre"], "reflet": f["reflet"]}


## Couleur de marque de la branche (lisible sur le crème).
static func accent(build: String) -> Color:
	match build:
		"ronce": return Color("d4485a")
		"seve": return Art.ec("seve", "clair")
		"racine": return Color("c08a3e")
		"vent": return Color("8fb4e0")
	return Art.ec("seve")


## Lueur de la branche (yeux, cœur, lames).
static func glow(build: String) -> Color:
	match build:
		"ronce": return Color("ff9a8a")
		"racine": return Color("f2d27a")
		"vent": return Color("d8ecff")
	return Art.ec("seve", "clair")


static func progress(o: Dictionary) -> float:
	if o.has("evol"):
		return o["evol"]
	return clampf((float(o.get("stade", 1)) - 1.0) / 2.0, 0.0, 1.0)


static func aura(ci: CanvasItem, base: Transform2D, t: float, p: float, col: Color) -> void:
	if Ink.mono:
		return
	var hb := 0.5 + 0.5 * sin(t * TAU / 2.4)
	var R := 34.0 + 22.0 * p
	for i in 3:
		var gr := R - i * 9.0
		Ink._poly(ci, base * Ink.oval(Vector2(0, -1), gr, gr * 0.42, 40), Color(Art.ec("seve"), 0.07 + 0.03 * hb))
	var ring := Ink.oval(Vector2(0, -1), R * 0.95, R * 0.95 * 0.42, 48)
	ring.append(ring[0])
	ci.draw_polyline(base * ring, Color(Art.ec("seve", "clair"), 0.2 + 0.15 * hb), 1.3 * base.get_scale().y, true)
	if p > 0.6:
		# Rune de la branche au sol, à maturité.
		var r2 := Ink.oval(Vector2(0, -1), R * 0.7, R * 0.7 * 0.42, 40)
		for k in 6:
			var a := TAU * k / 6.0 + t * 0.3
			var q := Vector2(cos(a) * R * 0.7, -1 + sin(a) * R * 0.7 * 0.42)
			ci.draw_circle(base * q, 1.6 * base.get_scale().y, Color(col, (p - 0.6) * 2.0 * (0.5 + 0.5 * hb)))
		r2.append(r2[0])
		ci.draw_polyline(base * r2, Color(col, 0.35 * (p - 0.6) * 2.5), 1.0 * base.get_scale().y, true)
	var n := 2 + roundi(6.0 * p)
	for i in n:
		var k := fposmod(t * 0.35 + i / float(n), 1.0)
		var a := i * 2.4 + t * 0.4
		var q := base * Vector2(cos(a) * R * 0.7, -2 + sin(a) * R * 0.3 - k * 50.0)
		ci.draw_circle(q, 1.8 * base.get_scale().y * (1.0 - 0.5 * k), Color(Art.ec("seve", "clair").lerp(col, p * 0.7), 0.85 * sin(PI * k)))


## Œil en amande (celui que préfère Antoine) : blanc, iris, pupille, reflet, paupière appuyée.
static func eye(ci: CanvasItem, xf: Transform2D, c: Vector2, w: float, hgt: float, tilt: float, iris: Color) -> void:
	var u := xf.get_scale().abs().x
	Ink.flat(ci, xf, Ink.leaf(c - Vector2(w, 0).rotated(tilt), tilt, w * 2.0, hgt * 1.6, 0.0), Color("fbf6e8"), 1.0)
	if Ink.mono:
		return
	ci.draw_circle(xf * (c + Vector2(w * 0.25, 0.2)), hgt * 0.62 * u, Ink.shade(iris))
	ci.draw_circle(xf * (c + Vector2(w * 0.32, 0.3)), hgt * 0.34 * u, Ink.encre())
	ci.draw_circle(xf * (c + Vector2(w * 0.1, -0.8)), hgt * 0.2 * u, Color.WHITE)
	Ink.brush(ci, xf, PackedVector2Array([c - Vector2(w * 1.05, -0.2), c + Vector2(0, -hgt * 0.75), c + Vector2(w * 1.05, -0.6)]), 1.5, Ink.encre(), 1.0, 0.2)


## Fente lumineuse (yeux d'un masque ou d'un heaume).
static func slit(ci: CanvasItem, xf: Transform2D, c: Vector2, a: float, l: float, w: float, col: Color, k := 1.0) -> void:
	var u := xf.get_scale().abs().x
	if not Ink.mono:
		Ink.halo(ci, xf * c, l * 0.9 * u, col, 1.2 * k)
	Ink.flat(ci, xf, Ink.leaf(c - Vector2.from_angle(a) * l * 0.5, a, l, w), Ink.encre(), 0.8)
	Ink.flat(ci, xf, Ink.leaf(c - Vector2.from_angle(a) * l * 0.4, a, l * 0.8, w * 0.55), col if not Ink.mono else Color.WHITE)


## Graine-lanterne lumineuse (en monde : `w` est déjà transformé).
static func seed(ci: CanvasItem, w: Vector2, u: float, p: float, t: float, col: Color, r := 4.4, hk := 1.0) -> void:
	if not Ink.mono:
		Ink.halo(ci, w, (11.0 + 6.0 * p) * u * hk, Art.ec("seve"), 1.4 + 0.8 * p)
		for i in 3:
			var m := w + Vector2.from_angle(t * 2.6 + i * TAU / 3.0) * (7.0 + 2.0 * p) * u
			ci.draw_circle(m, 0.9 * u, Color(col, 0.5 + 0.4 * sin(t * 4.0 + i * 2.0)))
	var sx := Transform2D(0.0, Vector2(u, u), 0.0, w)
	Ink.part(ci, sx, Ink.oval(Vector2.ZERO, r, r * 0.84, 16), {"clair": Art.ec("seve", "sombre").lightened(0.35), "ombre": Art.ec("seve", "sombre"), "reflet": Art.ec("seve", "clair")}, 1.2)
	if not Ink.mono:
		ci.draw_circle(w + Vector2(-0.5, -0.5) * u, r * 0.45 * u, Art.ec("seve", "clair"))


## Feuille à deux tons avec nervure.
static func leaf(ci: CanvasItem, xf: Transform2D, b: Vector2, a: float, l: float, w: float, pal: Dictionary, curl := 0.0, ink := 1.1) -> void:
	Ink.part(ci, xf, Ink.leaf(b, a, l, w, curl), pal, ink, 1.0, 0.5)
	Ink.brush(ci, xf, PackedVector2Array([b, b + Vector2.from_angle(a + curl * 2.0) * l * 0.8]), 0.8, pal["ombre"], 1.0, 0.0)
