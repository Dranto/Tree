## Silhouettes des Flétris des hauts plateaux (région de Vent), selon la charte (§ 4) : mêmes outils
## que fletri_art.gd (volume, contour clair, fentes de braise), une forme par sorte qui se lit de loin.
##   - plongeur (Piqueur) : rapace de cendre vu de dessus, ailes en flèche, bec d'os ; il replie les
##     ailes pour piquer ;
##   - souffleur : soufflet de cendre ventru, une trompe évasée vers l'avant ; il enfle avant de souffler ;
##   - planeur (Planeur de cendre) : aile en losange à deux longues traînes, qui plane au-dessus du sol ;
##     il monte plus haut quand le joueur approche (hors d'atteinte) ;
##   - menhir (Menhir flétri) : pierre levée qui marche sur deux moignons, gravée de runes de braise.
## Appelé par fletri_art.gd pour les sortes de enemies.json qui portent "art": "vent".
extends RefCounted

const F = preload("res://scripts/fletri_art.gd")
const AA := false

## Altitude du Planeur (en rayons) : au repos, et une fois monté hors d'atteinte.
const GLIDE_LOW := 0.55
const GLIDE_HIGH := 1.7


static func body_color(kind_id: String) -> Color:
	var e := Art.c("ennemi")
	match kind_id:
		"plongeur":
			return e.lerp(Art.ec("vent", "sombre"), 0.45)
		"souffleur":
			return e.lerp(Art.ec("vent", "sombre"), 0.3).darkened(0.05)
		"planeur":
			return e.lerp(Art.ec("vent", "sombre"), 0.35).lightened(0.06)
		"menhir":
			return e.lerp(Art.c("brume"), 0.35).lerp(Art.ec("vent", "sombre"), 0.35)
	return e


static func draw(ci, kind_id: String, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	match kind_id:
		"plongeur":
			_plongeur(ci, pos, r, face, t, o)
		"souffleur":
			_souffleur(ci, pos, r, face, t, o)
		"planeur":
			_planeur(ci, pos, r, face, t, o)
		"menhir":
			_menhir(ci, pos, r, face, t, o)


## Aile en flèche du Piqueur (côté sgn), « span » : ouverture (1 déployée, 0,45 repliée).
static func _wing(sgn: float, span: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.3, 0.22 * sgn), Vector2(0.08, 0.95 * sgn * span), Vector2(-0.3, 1.5 * sgn * span),
		Vector2(-0.42, 1.2 * sgn * span), Vector2(-0.6, 1.24 * sgn * span), Vector2(-0.56, 0.9 * sgn * span),
		Vector2(-0.74, 0.8 * sgn * span), Vector2(-0.4, 0.26 * sgn)])


static var RAPACE := PackedVector2Array([Vector2(1.05, 0), Vector2(0.7, 0.3), Vector2(0.1, 0.4), Vector2(-0.6, 0.26), Vector2(-0.75, 0), Vector2(-0.6, -0.26), Vector2(0.1, -0.4), Vector2(0.7, -0.3)])
static var QUEUE := PackedVector2Array([Vector2(-0.6, 0.18), Vector2(-1.25, 0.36), Vector2(-1.12, 0), Vector2(-1.25, -0.36), Vector2(-0.6, -0.18)])


## Piqueur : ailes qui battent en vol, déployées et frémissantes pendant l'annonce, repliées pour le piqué.
static func _plongeur(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var state: String = o.get("state", "")
	var k: float = o.get("k", 0.0)
	var sq := F._squash(o, t)
	var span := 1.0 + 0.1 * sin(t * 9.0)
	if state == "windup":
		span = 1.12 + 0.05 * sin(t * 40.0)
	elif state == "charge":
		span = 0.42
		sq = Vector2(1.25, 0.85)
	elif state == "recover":
		span = 0.8 + 0.2 * sin(t * 14.0)
	var xf := F._xf(pos, r, face, sq)
	var body := body_color("plongeur")
	var wing := body.darkened(0.12)
	for sgn in [-1.0, 1.0]:
		var w := xf * _wing(sgn, span)
		F._fill(ci, w, wing, o, 0.6)
		F._outline(ci, w, r, o)
	var tail := xf * QUEUE
	F._fill(ci, tail, wing.darkened(0.1), o, 0.4)
	var pts := xf * RAPACE
	F._fill(ci, pts, body, o)
	# Bec d'os, plus long pendant le piqué.
	F._spike(ci, xf, Vector2(0.95, 0), Vector2.RIGHT, 0.45 + (0.2 if state == "charge" else 0.0), F._bone(), o)
	if o.get("mono", false):
		return
	# Rémiges : deux traits clairs du vent sur chaque aile.
	if r >= 9.0:
		for sgn in [-1.0, 1.0]:
			for i in 2:
				var a := xf * Vector2(-0.05 - i * 0.22, (0.45 + i * 0.25) * sgn * span)
				var b := xf * Vector2(-0.4 - i * 0.18, (0.75 + i * 0.3) * sgn * span)
				ci.draw_line(a, b, F._shade(Art.ec("vent", "sombre").lightened(0.25), o), maxf(r * 0.06, 0.8), AA)
	F._cracks(ci, xf, [[Vector2(0.2, 0), Vector2(-0.2, 0.12), Vector2(-0.5, 0.05)]], r, body, 0.4 + 0.5 * k, t, o)
	F._outline(ci, pts, r, o)
	for sgn in [-1, 1]:
		F._slit(ci, xf, Vector2(0.62, sgn * 0.16), 0.1, sgn, 0.3 + 0.5 * k, o)


## Souffleur : un soufflet de cendre (corps rond plissé), une trompe évasée à l'avant, deux
## petites ailes en éventail sur le dos. Il enfle pendant l'annonce, se vide en soufflant.
static func _souffleur(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var state: String = o.get("state", "")
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var puff := 1.0 + 0.22 * Anim.ease_out(k)
	if state == "recover":
		puff = 0.85
	var sq := F._squash(o, t) * Vector2(puff, puff)
	var xf := F._xf(pos, r, face, sq)
	var body := body_color("souffleur")
	# Ailes en éventail sur le dos (côté arrière).
	for sgn in [-1.0, 1.0]:
		var fan := PackedVector2Array([Vector2(-0.3, 0.55 * sgn), Vector2(-0.95, 1.05 * sgn), Vector2(-1.15, 0.7 * sgn), Vector2(-1.2, 0.35 * sgn), Vector2(-0.7, 0.3 * sgn)])
		var w := xf * fan
		F._fill(ci, w, body.darkened(0.2), o, 0.4)
		F._outline(ci, w, r, o)
	# Trompe : un cône évasé vers l'avant, d'os, qui vibre au souffle.
	var flare := 0.5 + 0.12 * k + (0.1 * Anim.flash(strike) if strike >= 0.0 else 0.0)
	var horn := xf * PackedVector2Array([Vector2(0.6, 0.24), Vector2(1.45, flare), Vector2(1.38, 0), Vector2(1.45, -flare), Vector2(0.6, -0.24)])
	F._fill(ci, horn, F._bone().darkened(0.15), o, 0.5)
	F._outline(ci, horn, r, o)
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(Vector2.from_angle(a) * (1.0 if i % 2 == 0 else 0.9))
	pts = xf * pts
	F._fill(ci, pts, body, o)
	if o.get("mono", false):
		return
	# Plis du soufflet, et la bouche de la trompe (sombre, braise pendant l'annonce).
	var fold := F._shade(body.darkened(0.4), o)
	for i in 3:
		var x := -0.45 + i * 0.35
		ci.draw_line(xf * Vector2(x, -0.75 + absf(x) * 0.3), xf * Vector2(x, 0.75 - absf(x) * 0.3), fold, maxf(r * 0.07, 1.0), AA)
	ci.draw_line(xf * Vector2(1.4, -flare * 0.85), xf * Vector2(1.4, flare * 0.85), F._shade(Art.c("contour"), o), maxf(r * 0.12, 1.5), AA)
	if k > 0.0:
		ci.draw_line(xf * Vector2(1.41, -flare * 0.6), xf * Vector2(1.41, flare * 0.6), Color(Art.ec("vent", "clair"), 0.4 + 0.5 * k), maxf(r * 0.06, 1.0), AA)
	F._cracks(ci, xf, [[Vector2(0.1, 0.1), Vector2(-0.2, 0.4)], [Vector2(0.1, -0.1), Vector2(-0.25, -0.45)]], r, body, 0.35 + 0.5 * k, t, o)
	F._outline(ci, pts, r, o)
	for sgn in [-1, 1]:
		F._slit(ci, xf, Vector2(0.42, sgn * 0.3), 0.12, sgn, 0.25 + 0.5 * k, o)


static var LOSANGE := PackedVector2Array([Vector2(1.1, 0), Vector2(0.45, 0.55), Vector2(0.05, 1.5), Vector2(-0.3, 0.75), Vector2(-0.75, 0), Vector2(-0.3, -0.75), Vector2(0.05, -1.5), Vector2(0.45, -0.55)])


## Planeur de cendre : une aile en losange qui plane, deux traînes qui ondulent derrière. Son corps
## est dessiné au-dessus de son ombre (altitude) ; en vol haut (« state » = "vol"), il monte encore.
static func _planeur(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var state: String = o.get("state", "")
	var k: float = o.get("k", 0.0)
	var high := state == "vol"
	var alt := (GLIDE_HIGH if high else GLIDE_LOW) * r + (0.12 * r * sin(t * 2.2) if high else 0.0)
	var at := pos + Vector2(0, -alt)
	var sq := Vector2(1.0, 1.0 + 0.06 * sin(t * 3.0))
	var xf := F._xf(at, r, face, sq)
	var body := body_color("planeur")
	# Traînes : deux rubans qui ondulent derrière l'aile.
	if not o.get("mono", false):
		for sgn in [-1.0, 1.0]:
			var tr := PackedVector2Array()
			for i in 6:
				var u := i / 5.0
				tr.append(xf * Vector2(-0.6 - 1.3 * u, sgn * (0.22 + 0.25 * u) + 0.22 * sin(t * 5.0 + u * 4.0 + sgn)))
			ci.draw_polyline(tr, F._shade(body.darkened(0.3), o), maxf(r * 0.16, 1.5), AA)
			ci.draw_polyline(tr, F._shade(Art.ec("vent", "sombre").lightened(0.2), o), maxf(r * 0.06, 0.8), AA)
	var pts := xf * LOSANGE
	F._fill(ci, pts, body, o, 0.7)
	if o.get("mono", false):
		return
	# Nervures de l'aile et arête centrale.
	var rib := F._shade(body.darkened(0.35), o)
	for sgn in [-1.0, 1.0]:
		ci.draw_line(xf * Vector2(0.3, 0), xf * Vector2(0.05, 1.3 * sgn), rib, maxf(r * 0.06, 0.8), AA)
		ci.draw_line(xf * Vector2(0.0, 0), xf * Vector2(-0.3, 0.7 * sgn), rib, maxf(r * 0.05, 0.8), AA)
	ci.draw_line(xf * Vector2(1.0, 0), xf * Vector2(-0.7, 0), F._shade(body.lightened(0.15), o), maxf(r * 0.08, 1.0), AA)
	F._cracks(ci, xf, [[Vector2(0.4, 0), Vector2(0.1, 0.3), Vector2(-0.1, 0.55)]], r, body, 0.4 + 0.5 * k, t, o)
	F._outline(ci, pts, r, o)
	for sgn in [-1, 1]:
		F._slit(ci, xf, Vector2(0.7, sgn * 0.17), 0.1, sgn, 0.3 + 0.5 * k, o)
	if high:
		# Hors d'atteinte : un anneau de vent tourne sous lui.
		var ash: float = o.get("ash", 0.0)
		for i in 2:
			var a := t * 3.0 + i * PI
			ci.draw_arc(pos + Vector2(0, -alt * 0.45), r * 1.1, a, a + 1.6, 10, Color(Art.ec("vent", "clair"), 0.55 * (1.0 - ash)), Art.TRAIT_FIN, AA)


static var PIERRE := PackedVector2Array([Vector2(-0.72, 0.35), Vector2(-0.82, -0.85), Vector2(-0.38, -1.75), Vector2(0.35, -1.68), Vector2(0.8, -0.75), Vector2(0.72, 0.35)])


## Menhir flétri : une pierre levée, droite (il ne tourne pas : seuls ses yeux suivent le joueur),
## qui marche lourdement sur deux moignons, gravée de runes où couve la braise.
static func _menhir(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var sq := F._squash(o, t)
	var xf := Transform2D(0.0, Vector2(r * sq.x, r * sq.y), 0.0, pos)
	var body := body_color("menhir")
	# Deux moignons de pierre, qui avancent tour à tour.
	for sgn in [-1.0, 1.0]:
		var lift := maxf(0.0, sin(walk + (0.0 if sgn < 0.0 else PI))) * 0.18 * mv
		var foot := PackedVector2Array([Vector2(0.18 * sgn, 0.25), Vector2(0.62 * sgn, 0.28 - lift), Vector2(0.66 * sgn, 0.55 - lift), Vector2(0.15 * sgn, 0.58)])
		var w := xf * foot
		F._fill(ci, w, body.darkened(0.25), o, 0.3)
		F._outline(ci, w, r, o)
	var pts := xf * PIERRE
	F._fill(ci, pts, body, o, 0.6)
	if o.get("mono", false):
		return
	# Strates et lichen mort.
	var grain := F._shade(body.darkened(0.3), o)
	ci.draw_line(xf * Vector2(-0.7, -0.35), xf * Vector2(-0.1, -0.45), grain, maxf(r * 0.05, 1.0), AA)
	ci.draw_line(xf * Vector2(0.15, -1.2), xf * Vector2(0.7, -1.05), grain, maxf(r * 0.05, 1.0), AA)
	ci.draw_circle(xf * Vector2(0.45, -0.2), r * 0.08, Color(Art.c("brume").lightened(0.2), 0.5))
	# Runes de braise : une spirale de vent gravée, et deux traits.
	F._cracks(ci, xf, [[Vector2(-0.3, -0.25), Vector2(-0.05, -0.4), Vector2(0.15, -0.2), Vector2(0.0, 0.0), Vector2(-0.2, -0.1)], [Vector2(-0.45, -0.95), Vector2(-0.2, -1.2)], [Vector2(0.25, -0.75), Vector2(0.45, -0.55)]], r, body, 0.55, t, o)
	F._outline(ci, pts, r, o, true)
	# Les yeux se tournent vers le joueur (la pierre, elle, reste droite).
	var look := clampf(face.x, -1.0, 1.0) * 0.18
	var exf := Transform2D(0.0, Vector2(r, r), 0.0, pos)
	for sgn in [-1, 1]:
		F._slit(ci, exf, Vector2(look + sgn * 0.2, -1.3), 0.11, sgn, 0.35, o)
	F._ash_flakes(ci, pos + Vector2(0, -r * 1.2), r, t, 2, o)
