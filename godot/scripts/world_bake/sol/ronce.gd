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


## Terre ravivée : tige de ronce feuillue, une églantine au bout d'une sur trois.
static func alive_matter(L, p: Vector2, e: RandomNumberGenerator) -> bool:
	var tip := leafy_runner(L, p, e)
	if e.randf() < 0.34:
		eglantine(L, tip, e.randf_range(3.0, 3.8), e)
	return true


## Grappe morte : cendre, avec une braise de loin en loin.
static func dead_item(L, p: Vector2, big: float, kind: int, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if kind != 2:
		return false
	L._oval(p, 3.5 + 4.5 * big, 1.8 + 2.0 * big, Color(pal["cendre"], 0.4), 6)
	if e.randf() < 0.2:
		L._oval(p + Vector2(0, -0.5), 1.2 * big, 1.2 * big, Art.bc("braise"), 5)
	return true


## Grappe ravivée : églantines sur leur tige à la place des fleurs communes, grappe de mûres à la
## place du caillou ; les touffes restent communes.
static func alive_item(L, p: Vector2, big: float, k: float, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if k < 0.55:
		return false
	if k < 0.85:
		L._tuft(p, 8.0 * big, pal["touffe"], pal["touffe_2"])
		var top := p + Vector2(e.randf_range(-2.0, 2.0), -8.0 * big - 2.0)
		L._line(p, top, 0.9, Art.mpc("ronce", "tige_vive"))
		L._leaf(p.lerp(top, 0.5), -PI * 0.5 + (0.9 if e.randf() < 0.5 else -0.9), 4.5 * big + 1.5, Art.mpc("ronce", "feuille"))
		eglantine(L, top, 2.4 + 1.8 * big, e)
		return true
	blackberries(L, p, big, e)
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


## Tige de ronce ravivée : courte, couverte de petites feuilles ; rend son bout.
static func leafy_runner(L, p: Vector2, e: RandomNumberGenerator) -> Vector2:
	var a := e.randf() * TAU
	var pts := PackedVector2Array([p])
	for i in 3:
		a += e.randf_range(-0.5, 0.5)
		pts.append(pts[-1] + Vector2.from_angle(a) * e.randf_range(13.0, 19.0))
	# Un peu fondue dans le sol : le sol ravivé reste le moins contrasté (banc de lisibilité).
	var sol: Color = L._p["ravive"]["sol"]
	L._polyline(pts, 1.4, Art.mpc("ronce", "tige_vive").lerp(sol, 0.5))
	for i in range(1, pts.size()):
		var d: Vector2 = (pts[i] - pts[i - 1]).normalized()
		var side := 1.0 if i % 2 == 0 else -1.0
		L._leaf(pts[i], d.angle() + 0.9 * side, e.randf_range(5.0, 7.0), Art.mpc("ronce", "feuille").lerp(sol, 0.45))
	return pts[-1]


## Églantine (rose des haies) : cinq pétales arrondis, un liseré plus clair côté lumière, cœur doré
## piqué d'étamines sombres ; une sur quatre blanche (fleur_2).
static func eglantine(L, q: Vector2, r: float, e: RandomNumberGenerator) -> void:
	# Fondue à 40 % dans le sol : le sol reste moins contrasté que les personnages (banc de lisibilité).
	var sol: Color = L._p["ravive"]["sol"]
	var petal: Color = Art.mc("ronce", "ravive", "fleur_2" if e.randf() < 0.25 else "fleur").lerp(sol, 0.4)
	var a0 := e.randf() * TAU
	L._oval(q + Vector2(0.8, 1.0), r * 1.1, r * 0.9, Color(Art.mpc("ronce", "encre_vive"), 0.2), 8)
	for k in 5:
		var d := Vector2.from_angle(a0 + TAU * k / 5.0)
		L._oval(q + d * r * 0.62, r * 0.55, r * 0.55, petal, 7)
	L._oval(q + Vector2(-0.3, -0.3) * r, r * 0.42, r * 0.3, petal.lightened(0.15), 6)
	L._oval(q, r * 0.34, r * 0.34, Art.mc("ronce", "ravive", "fleur_coeur").lerp(sol, 0.4), 6)


## Grappe de mûres : trois à cinq fruits faits de grains serrés, un reflet en haut à gauche, une feuille.
static func blackberries(L, p: Vector2, big: float, e: RandomNumberGenerator) -> void:
	L._leaf(p + Vector2(-1.0, 1.0), PI * 0.85 + e.randf_range(-0.3, 0.3), 6.0 * big + 2.0, Art.mpc("ronce", "feuille"))
	var sol: Color = L._p["ravive"]["sol"]
	var fruit: Color = Art.mc("ronce", "ravive", "fruit").lerp(sol, 0.4)
	var ripe: Color = Art.mpc("ronce", "baie").lerp(sol, 0.4)
	for i in e.randi_range(3, 5):
		var c := p + Vector2(e.randf_range(-4.0, 4.0), e.randf_range(-3.0, 2.0)) * (0.6 + 0.5 * big)
		var rr := (1.3 + 0.9 * big) * e.randf_range(0.85, 1.1)
		var col := ripe if e.randf() < 0.3 else fruit
		L._oval(c, rr * 1.15, rr * 1.1, col.darkened(0.2), 6)
		for g in 3:
			L._oval(c + Vector2.from_angle(TAU * g / 3.0 + 0.5) * rr * 0.45, rr * 0.5, rr * 0.5, col, 5)
		L._oval(c + Vector2(-0.4, -0.45) * rr, rr * 0.22, rr * 0.22, Color(1, 1, 1, 0.25), 4)
