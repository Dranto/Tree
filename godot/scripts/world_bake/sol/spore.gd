## Matière du sol de la région « spore » (Marais), refonte du monde vague 2 (ground_layers.gd › SOL_REGION).
##
## Contrat : voir sol/vent.gd. Flétri : rides de vase, mycélium pâle, petits chapeaux ternes ;
## ravivé : mycélium luisant, chapeaux luisants (grappes et bord de vie).
extends RefCounted


## Terre morte : rides de vase autour d'une flaque croupie (premier tirage), mycélium pâle (second).
static func dead_matter(L, p: Vector2, i: int, sd: int, e: RandomNumberGenerator) -> bool:
	if i == 0:
		if sd % 3 == 0:
			puddle(L, p, e.randf_range(9.0, 15.0), false)
		rides(L, p, e)
	else:
		mycelium(L, p, Color(L._p["fletri"]["cendre"], 0.22), e)
	return true


## Terre ravivée : mycélium luisant ; une fois sur trois, une flaque claire qui reflète le ciel.
static func alive_matter(L, p: Vector2, e: RandomNumberGenerator) -> bool:
	if e.randf() < 0.33:
		puddle(L, p, e.randf_range(8.0, 13.0), true)
	mycelium(L, p, Color(Art.mc("spore", "ravive", "lueur"), 0.32), e)
	return true


## Grappe morte « cendre » : petits chapeaux ternes (assombris et moins nombreux, retour d'Antoine
## du 25/11) mêlés de cailloux.
static func dead_item(L, p: Vector2, big: float, kind: int, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if kind != 2:
		return false
	if big > 0.9 or e.randf() < 0.4:
		cap(L, p, 2.0 + 2.6 * big, false)
	else:
		L._pebble(p, 2.5 + 3.5 * big, pal["pierre"])
	return true


## Grappe ravivée : chapeaux luisants à la place des fleurs (souvent un petit à côté), coussin de
## mousse piquée de points de lumière à la place du caillou.
static func alive_item(L, p: Vector2, big: float, k: float, _pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if k < 0.55:
		return false
	if k < 0.85:
		cap(L, p, 2.0 + 2.4 * big, true)
		if big > 0.9 or e.randf() < 0.5:
			cap(L, p + Vector2(e.randf_range(3.0, 5.0) * (1.0 if e.randf() < 0.5 else -1.0), 1.5), 1.3 + 1.0 * big, true)
		return true
	glow_moss(L, p, big, e)
	return true


## Bord de vie : un chapeau luisant.
static func flower(L, p: Vector2, r: float, _pal: Dictionary, _e: RandomNumberGenerator) -> bool:
	cap(L, p, r * 0.8, true)
	return true


## Petit chapeau du Marais (de la taille d'une touffe). lit : luit (ravivé) ; sinon sombre et terne.
static func cap(L, p: Vector2, r: float, lit: bool) -> void:
	var etat := "ravive" if lit else "fletri"
	var pied: Dictionary = Art.mc("spore", etat, "pied")
	var c0: Color = Art.mc("spore", "ravive", "fleur") if lit else Art.mc("spore", "fletri", "chapeau")["ombre"]
	if lit:
		L._oval(p + Vector2(0, -r * 1.2), r * 2.2, r * 1.8, Color(c0, 0.1), 8)
	L._line(p, p + Vector2(0, -r * 1.3), maxf(r * 0.45, 1.0), pied["ombre"])
	var c := p + Vector2(0, -r * 1.3)
	var dome := PackedVector2Array()
	for i in 7:
		var a := PI + PI * i / 6.0
		dome.append(c + Vector2(cos(a) * r, sin(a) * r * 0.8))
	L._fan(dome, c0.darkened(0.25))
	L._oval(c + Vector2(-r * 0.2, -r * 0.35), r * 0.45, r * 0.22, c0.lightened(0.3) if lit else c0, 6)


## Rides de vase : arcs plats concentriques autour d'un creux.
static func rides(L, c: Vector2, e: RandomNumberGenerator) -> void:
	var ink: Color = L._p["fletri"]["matiere"]
	var a0 := e.randf_range(-0.6, 0.2)
	for k in e.randi_range(2, 3):
		var rad := 8.0 + k * 6.0
		var pts := PackedVector2Array()
		for i in 6:
			var a := a0 + PI * 0.9 * i / 5.0
			pts.append(c + Vector2(cos(a) * rad * 1.6, sin(a) * rad * 0.55))
		L._polyline(pts, 1.0, Color(ink, 0.4 - k * 0.07))


## Mycélium : fils pâles qui se ramifient (lumineux une fois ravivé).
static func mycelium(L, c: Vector2, col: Color, e: RandomNumberGenerator) -> void:
	var p := c
	var a := e.randf() * TAU
	var pts := PackedVector2Array([p])
	for i in e.randi_range(4, 7):
		a += e.randf_range(-0.9, 0.9)
		p += Vector2.from_angle(a) * e.randf_range(6.0, 12.0)
		pts.append(p)
		if e.randf() < 0.3:
			L._line(p, p + Vector2.from_angle(a + e.randf_range(-1.6, 1.6)) * e.randf_range(5.0, 9.0), 0.7, Color(col, col.a * 0.7))
	L._polyline(pts, 0.8, col)


## Flaque : eau sombre et croupie (flétri) ou claire, avec un reflet en haut à gauche (ravivé).
static func puddle(L, c: Vector2, r: float, lit: bool) -> void:
	var etat := "ravive" if lit else "fletri"
	var eau: Color = Art.mc("spore", etat, "eau")
	var ref: Color = Art.mc("spore", etat, "eau_reflet")
	L._oval(c + Vector2(0.6, 0.8), r * 1.08, r * 0.5, Color(L._p[etat]["matiere"], 0.55), 9)
	L._oval(c, r, r * 0.44, eau, 9)
	L._oval(c + Vector2(-r * 0.3, -r * 0.12), r * 0.42, r * 0.1, Color(ref, 0.55 if lit else 0.35), 6)


## Coussin de mousse ravivé : une touffe ronde et quelques points de lumière.
static func glow_moss(L, p: Vector2, big: float, e: RandomNumberGenerator) -> void:
	var pal: Dictionary = L._p["ravive"]
	var r := 3.0 + 2.6 * big
	L._oval(p + Vector2(0.6, 0.8), r * 1.1, r * 0.6, Color(pal["touffe_2"].darkened(0.3), 0.6), 7)
	L._oval(p, r, r * 0.55, pal["touffe_2"], 7)
	L._oval(p + Vector2(-r * 0.2, -r * 0.18), r * 0.6, r * 0.3, pal["touffe"], 6)
	var glow: Color = Art.mc("spore", "ravive", "lueur")
	for i in e.randi_range(2, 4):
		var q := p + Vector2(e.randf_range(-0.8, 0.8) * r, e.randf_range(-0.5, 0.2) * r)
		L._oval(q, 1.8, 1.8, Color(glow, 0.18), 5)
		L._oval(q, 0.7, 0.7, glow, 4)
