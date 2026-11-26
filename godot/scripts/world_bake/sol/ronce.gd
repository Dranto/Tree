## Matière du sol de la région « ronce » (Roncier), refonte du monde vague 2 (ground_layers.gd › SOL_REGION).
##
## Contrat : voir sol/vent.gd. Flétri : craquelures à braise, tiges rampantes à épines, feuilles mortes
## en congères, cendre à braise ; ravivé : tiges feuillues, baies de mûre.
extends RefCounted


## Terre morte : craquelure à braise (premier tirage) ; tige à épines ou feuilles mortes (second).
static func dead_matter(L, p: Vector2, i: int, sd: int, _e: RandomNumberGenerator) -> bool:
	if i == 0:
		L._crack(p, true)
	elif sd & 1:
		thorns(L, p, _e)
	else:
		L._leaves(p, L._p["fletri"])
	return true


## Terre ravivée : tige de ronce feuillue.
static func alive_matter(L, p: Vector2, e: RandomNumberGenerator) -> bool:
	leafy_runner(L, p, e)
	return true


## Grappe morte : cendre, avec une braise de loin en loin.
static func dead_item(L, p: Vector2, big: float, kind: int, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if kind != 2:
		return false
	L._oval(p, 3.5 + 4.5 * big, 1.8 + 2.0 * big, Color(pal["cendre"], 0.4), 6)
	if e.randf() < 0.2:
		L._oval(p + Vector2(0, -0.5), 1.2 * big, 1.2 * big, Art.bc("braise"), 5)
	return true


## Grappe ravivée : une mûre à la place du caillou.
static func alive_item(L, p: Vector2, big: float, k: float, _pal: Dictionary, _e: RandomNumberGenerator) -> bool:
	if k < 0.85:
		return false
	L._oval(p, 1.8 * big + 0.6, 1.8 * big + 0.6, Art.mpc("ronce", "baie"), 6)
	L._oval(p + Vector2(-0.6, -0.6), 0.6, 0.6, Art.mpc("ronce", "fleur_coeur"), 4)
	return true


static func flower(_L, _p: Vector2, _r: float, _pal: Dictionary, _e: RandomNumberGenerator) -> bool:
	return false


## Tige rampante à épines (flétri), ombre d'encre en bas à droite (lumière d'en haut à gauche).
static func thorns(L, p: Vector2, e: RandomNumberGenerator) -> void:
	var a := e.randf() * TAU
	var pts := PackedVector2Array([p])
	for i in 4 + e.randi() % 3:
		a += e.randf_range(-0.5, 0.5)
		pts.append(pts[-1] + Vector2.from_angle(a) * e.randf_range(13.0, 20.0))
	var ink := Art.mpc("ronce", "encre_morte")
	var shadow := PackedVector2Array()
	for q in pts:
		shadow.append(q + Vector2(1.0, 1.3))
	L._polyline(shadow, 2.0, Color(ink, 0.5))
	L._polyline(pts, 1.3, Art.mpc("ronce", "tige_morte"))
	for i in range(1, pts.size() - 1):
		var d: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
		var nn := d.orthogonal() * (1.0 if i % 2 == 0 else -1.0)
		var q: Vector2 = pts[i]
		L._tri(q + d * 1.4, q + nn * 3.4 + d * 0.8, q - d * 1.0, ink)


## Tige de ronce ravivée : courte, couverte de petites feuilles.
static func leafy_runner(L, p: Vector2, e: RandomNumberGenerator) -> void:
	var a := e.randf() * TAU
	var pts := PackedVector2Array([p])
	for i in 3:
		a += e.randf_range(-0.5, 0.5)
		pts.append(pts[-1] + Vector2.from_angle(a) * e.randf_range(13.0, 19.0))
	L._polyline(pts, 1.4, Art.mpc("ronce", "tige_vive"))
	for i in range(1, pts.size()):
		var d: Vector2 = (pts[i] - pts[i - 1]).normalized()
		var side := 1.0 if i % 2 == 0 else -1.0
		L._leaf(pts[i], d.angle() + 0.9 * side, e.randf_range(5.0, 7.0), Art.mpc("ronce", "feuille"))
