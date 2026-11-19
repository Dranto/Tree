## Silhouettes des Flétris de la vallée des sources (région de Sève), selon la charte (§ 4) : mêmes
## outils que fletri_art.gd (volume, contour clair, fentes de braise), une forme par sorte qui se lit
## de loin.
##   - sangsue_vase (Sangsue de vase) : un ver annelé, plat, une ventouse dentée à l'avant ; elle
##     ondule en rampant et enfle quand elle vient de boire (pose « gorged ») ;
##   - crapaud (Crapaud des sources) : trapu, cuisses repliées sur les flancs, gros yeux de braise ;
##     il se ramasse avant de bondir et grandit en l'air (pose « lift ») ;
##   - libellule (Libellule de cendre) : corps fin et long, quatre ailes pâles qui vibrent, repliées
##     pendant le piqué ;
##   - souche (Souche gorgée) : une souche coupée qui marche sur ses racines, cernes au sommet ; la
##     sève luit dans ses fentes quand elle soigne.
## Appelé par fletri_art.gd pour les sortes de enemies.json qui portent "art": "seve".
extends RefCounted

const F = preload("res://scripts/fletri_art.gd")
const AA := false


static func body_color(kind_id: String) -> Color:
	var e := Art.c("ennemi")
	match kind_id:
		"sangsue_vase":
			return e.lerp(Art.ec("seve", "sombre"), 0.3).darkened(0.08)
		"crapaud":
			return e.lerp(Art.ec("seve", "sombre"), 0.4)
		"libellule":
			return e.lerp(Art.ec("seve", "sombre"), 0.5).lightened(0.04)
		"souche":
			return e.lerp(Art.ec("racine", "sombre"), 0.45)
	return e


static func draw(ci, kind_id: String, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	match kind_id:
		"sangsue_vase":
			_sangsue(ci, pos, r, face, t, o)
		"crapaud":
			_crapaud(ci, pos, r, face, t, o)
		"libellule":
			_libellule(ci, pos, r, face, t, o)
		"souche":
			_souche(ci, pos, r, face, t, o)


## Sangsue : cinq anneaux de l'arrière (-x) à l'avant (+x), qui ondulent ; la ventouse à l'avant.
static func _sangsue(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var state: String = o.get("state", "")
	var k: float = o.get("k", 0.0)
	var g: float = o.get("gorged", 0.0)
	var sq := F._squash(o, t)
	if state == "windup":
		sq *= Vector2(0.82 + 0.05 * sin(t * 30.0), 1.1)
	elif state == "charge":
		sq *= Vector2(1.3, 0.8)
	sq *= Vector2(1.0, 1.0 + 0.35 * g)
	var xf := F._xf(pos, r, face, sq)
	var body := body_color("sangsue_vase")
	var wave := 0.0 if state == "charge" else 0.16
	var pts := PackedVector2Array()
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		var x := -1.45 + 2.6 * u
		var y := wave * sin(t * 7.0 - u * 4.0)
		var w := (0.24 + 0.2 * sin(PI * clampf(u * 1.1, 0.0, 1.0))) * (1.0 + 0.35 * g)
		top.append(Vector2(x, y - w))
		bottom.append(Vector2(x, y + w))
	pts.append_array(top)
	pts.append(Vector2(1.25, wave * sin(t * 7.0 - 4.0)))
	bottom.reverse()
	pts.append_array(bottom)
	pts.append(Vector2(-1.6, wave * sin(t * 7.0)))
	pts = xf * pts
	F._fill(ci, pts, body, o)
	if o.get("mono", false):
		return
	# Anneaux : traits sombres en travers du corps ; gonflée, la vie bue luit entre eux.
	var ring := F._shade(body.darkened(0.4), o)
	for i in 4:
		var u := (i + 1.5) / 6.5
		var x := -1.45 + 2.6 * u
		var y := wave * sin(t * 7.0 - u * 4.0)
		var w := (0.24 + 0.2 * sin(PI * u)) * (1.0 + 0.35 * g) * 0.85
		ci.draw_line(xf * Vector2(x, y - w), xf * Vector2(x + 0.05, y + w), ring, maxf(r * 0.07, 1.0), AA)
		if g > 0.0:
			ci.draw_line(xf * Vector2(x - 0.12, y - w * 0.5), xf * Vector2(x - 0.1, y + w * 0.5), Color(Art.ec("saignement", "clair"), 0.6 * g), maxf(r * 0.08, 1.0), AA)
	# Ventouse dentée : un disque sombre, une couronne de dents d'os.
	var mouth := xf * Vector2(1.08, wave * sin(t * 7.0 - 3.6))
	var mr := r * (0.24 + 0.08 * k)
	ci.draw_circle(mouth, mr, F._shade(Art.c("contour"), o))
	for i in 6:
		var a := TAU * i / 6.0 + t * 0.5
		var d := Vector2.from_angle(a)
		ci.draw_line(mouth + d * mr * 0.95, mouth + d * mr * 0.45, F._shade(F._bone(), o), maxf(r * 0.06, 1.0), AA)
	F._cracks(ci, xf, [[Vector2(-0.6, 0.0), Vector2(-0.3, 0.08), Vector2(0.0, -0.02)]], r, body, 0.35 + 0.5 * k, t, o)
	F._outline(ci, pts, r, o)
	for sgn in [-1, 1]:
		F._slit(ci, xf, Vector2(0.72, sgn * 0.15), 0.08, sgn, 0.3 + 0.5 * k, o)


## Crapaud : corps large et bas, cuisses repliées sur les flancs, pattes avant, gros yeux.
static func _crapaud(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var state: String = o.get("state", "")
	var k: float = o.get("k", 0.0)
	var lift: float = o.get("lift", 0.0)
	var sq := F._squash(o, t)
	if state == "windup":
		sq *= Vector2(1.0 + 0.16 * k, 1.0 - 0.14 * k)
	elif state == "recover":
		sq *= Vector2(1.12, 0.88)
	sq *= 1.0 + 0.3 * lift
	# En l'air : la silhouette monte (l'ombre reste au sol, dessinée par l'annonce).
	var at := pos + Vector2(0, -r * 1.3 * lift)
	var xf := F._xf(at, r, face, sq)
	var body := body_color("crapaud")
	var spread := 0.25 * lift
	# Cuisses repliées (ou détendues en l'air), en arrière sur les flancs.
	for sgn in [-1.0, 1.0]:
		var thigh := PackedVector2Array([Vector2(-0.1, 0.55 * sgn), Vector2(-0.55 - spread, 1.0 * sgn), Vector2(-1.05 - spread * 2.0, 0.85 * sgn), Vector2(-0.95 - spread, 0.45 * sgn), Vector2(-0.5, 0.35 * sgn)])
		var w := xf * thigh
		F._fill(ci, w, body.darkened(0.15), o, 0.4)
		F._outline(ci, w, r, o)
		var hand := xf * PackedVector2Array([Vector2(0.45, 0.5 * sgn), Vector2(0.75, 0.82 * sgn), Vector2(0.58, 0.9 * sgn), Vector2(0.3, 0.62 * sgn)])
		F._fill(ci, hand, body.darkened(0.2), o, 0.3)
		F._outline(ci, hand, r, o)
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var rr := 1.0 if i % 2 == 0 else 0.92
		pts.append(Vector2(cos(a) * 0.95 * rr, sin(a) * 0.72 * rr))
	pts = xf * pts
	F._fill(ci, pts, body, o)
	if o.get("mono", false):
		return
	# Pustules sur le dos, en volume.
	var wart := F._shade(body.lightened(0.16), o)
	for w in [[-0.35, -0.3, 0.12], [-0.05, 0.32, 0.1], [-0.55, 0.15, 0.09], [0.15, -0.15, 0.08]]:
		F._volume_circle(ci, xf * Vector2(w[0], w[1]), r * w[2], wart, 0.6)
	# Gorge qui se gonfle pendant l'annonce.
	if k > 0.0:
		F._volume_circle(ci, xf * Vector2(0.62, 0.0), r * (0.18 + 0.2 * k), F._shade(body.lightened(0.1), o), 0.5)
	F._cracks(ci, xf, [[Vector2(-0.2, -0.05), Vector2(0.1, 0.1), Vector2(0.3, 0.0)]], r, body, 0.35 + 0.5 * k, t, o)
	F._outline(ci, pts, r, o)
	# Gros yeux saillants, braise dedans.
	for sgn in [-1, 1]:
		var eye := xf * Vector2(0.45, 0.4 * sgn)
		F._volume_circle(ci, eye, r * 0.22, F._shade(body.darkened(0.1), o), 0.6)
		F._slit(ci, xf, Vector2(0.48, 0.4 * sgn), 0.13, sgn, 0.4 + 0.6 * k, o)


## Libellule : abdomen fin et long vers l'arrière, thorax, tête aux deux gros yeux ; quatre ailes.
static func _libellule(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var state: String = o.get("state", "")
	var k: float = o.get("k", 0.0)
	var sq := F._squash(o, t)
	var fold := 0.0
	var beat := 0.12 * sin(t * 45.0)
	if state == "windup":
		beat = 0.2 * sin(t * 60.0) + 0.1
	elif state == "charge":
		fold = 0.75
		beat = 0.0
	var xf := F._xf(pos, r, face, sq)
	var body := body_color("libellule")
	# Ailes pâles et translucides (cendre claire), deux paires.
	var wing := F._shade(Art.c("brume").lightened(0.15).lerp(Art.ec("seve", "clair"), 0.15), o)
	wing.a = 0.55
	for pair in 2:
		var x0 := 0.15 - pair * 0.3
		for sgn in [-1.0, 1.0]:
			var span: float = (1.5 - pair * 0.15) * (1.0 - fold) + 0.25
			var sweep: float = -0.35 - pair * 0.25 - fold * 0.6 + beat * sgn
			var tip: Vector2 = Vector2(x0 + sweep, span * sgn)
			var w := xf * PackedVector2Array([Vector2(x0, 0.12 * sgn), Vector2(x0 + 0.18, 0.6 * sgn).lerp(tip, 0.5), tip, Vector2(x0 - 0.25, 0.55 * sgn).lerp(tip, 0.4)])
			ci.draw_colored_polygon(w, wing)
			if not o.get("mono", false):
				var vein := F._shade(Art.c("ennemi_contour"), o)
				vein.a = 0.5
				ci.draw_line(xf * Vector2(x0, 0.12 * sgn), xf * tip, vein, maxf(r * 0.04, 0.8), AA)
	# Abdomen : un long fuseau annelé.
	var tail := xf * PackedVector2Array([Vector2(-0.1, 0.13), Vector2(-1.6, 0.07), Vector2(-1.75, 0.0), Vector2(-1.6, -0.07), Vector2(-0.1, -0.13)])
	F._fill(ci, tail, body.darkened(0.1), o, 0.5)
	F._outline(ci, tail, r, o)
	var pts := xf * PackedVector2Array([Vector2(0.55, 0.0), Vector2(0.35, 0.28), Vector2(-0.15, 0.24), Vector2(-0.25, 0.0), Vector2(-0.15, -0.24), Vector2(0.35, -0.28)])
	F._fill(ci, pts, body, o)
	if o.get("mono", false):
		return
	var ring := F._shade(body.darkened(0.4), o)
	for i in 4:
		var x := -0.45 - i * 0.3
		ci.draw_line(xf * Vector2(x, -0.1), xf * Vector2(x, 0.1), ring, maxf(r * 0.05, 0.8), AA)
	F._outline(ci, pts, r, o)
	# Tête : deux gros yeux à facettes, braise dedans.
	for sgn in [-1, 1]:
		F._volume_circle(ci, xf * Vector2(0.62, 0.17 * sgn), r * 0.2, F._shade(body.darkened(0.15), o), 0.7)
		F._slit(ci, xf, Vector2(0.66, 0.17 * sgn), 0.1, sgn, 0.4 + 0.6 * k, o)


## Souche : tronc coupé en trapèze, bord du sommet déchiqueté, cernes, racines-pattes ; mousse
## morte sur les flancs. Pendant le soin (« windup »), la sève luit dans ses fentes.
static func _souche(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var state: String = o.get("state", "")
	var k: float = o.get("k", 0.0)
	var sq := F._squash(o, t)
	if state == "windup":
		sq *= Vector2(1.0 + 0.08 * k, 1.0 + 0.08 * k)
	var xf := Transform2D(0.0, Vector2(r * sq.x, r * sq.y), 0.0, pos)
	var body := body_color("souche")
	# Racines-pattes : quatre racines qui se lèvent tour à tour.
	for i in 4:
		var sgn := -1.0 if i < 2 else 1.0
		var outer := 1.0 if i % 2 == 0 else 0.55
		var lift := maxf(0.0, sin(walk + i * PI * 0.5)) * 0.16 * mv
		var root := PackedVector2Array([Vector2(0.25 * sgn * outer, 0.2), Vector2(0.95 * sgn * outer + 0.1 * sgn, 0.42 - lift), Vector2(1.05 * sgn * outer + 0.1 * sgn, 0.55 - lift), Vector2(0.2 * sgn * outer, 0.45)])
		var w := xf * root
		F._fill(ci, w, body.darkened(0.25), o, 0.3)
		F._outline(ci, w, r, o)
	var pts := xf * PackedVector2Array([Vector2(-0.8, 0.35), Vector2(-0.72, -0.9), Vector2(-0.45, -1.05), Vector2(-0.3, -0.92), Vector2(-0.05, -1.12), Vector2(0.2, -0.95), Vector2(0.42, -1.08), Vector2(0.72, -0.9), Vector2(0.8, 0.35)])
	F._fill(ci, pts, body, o, 0.6)
	if o.get("mono", false):
		return
	# Sommet coupé : l'ellipse des cernes, plus claire.
	var top := Art.ellipse(xf * Vector2(0.0, -0.95), r * 0.66 * sq.x, r * 0.2 * sq.y, 16)
	F._fill(ci, top, body.lightened(0.12), o, 0.4)
	var rings := F._shade(body.darkened(0.25), o)
	for i in 2:
		ci.draw_arc(xf * Vector2(0.05, -0.95), r * (0.2 + 0.2 * i), 0.0, TAU, 14, rings, maxf(r * 0.04, 0.8), AA)
	# Écorce : stries verticales, mousse morte en plaques.
	var grain := F._shade(body.darkened(0.3), o)
	for x in [-0.45, -0.1, 0.3, 0.55]:
		ci.draw_line(xf * Vector2(x, -0.75), xf * Vector2(x + 0.04, 0.2), grain, maxf(r * 0.05, 1.0), AA)
	var moss := F._shade(Art.c("decor").lerp(Art.ec("seve", "sombre"), 0.4), o)
	ci.draw_colored_polygon(Art.ellipse(xf * Vector2(-0.5, -0.1), r * 0.24, r * 0.12, 8), moss)
	ci.draw_colored_polygon(Art.ellipse(xf * Vector2(0.55, -0.45), r * 0.18, r * 0.1, 8), moss)
	# Fentes : braise d'ordinaire, sève claire pendant le soin.
	F._cracks(ci, xf, [[Vector2(-0.25, -0.6), Vector2(-0.05, -0.3), Vector2(-0.2, 0.0)], [Vector2(0.3, -0.7), Vector2(0.15, -0.4)]], r, body, 0.4, t, o)
	if k > 0.0:
		var sap := Color(Art.ec("seve", "clair"), 0.4 + 0.5 * k)
		ci.draw_polyline(PackedVector2Array([xf * Vector2(-0.25, -0.6), xf * Vector2(-0.05, -0.3), xf * Vector2(-0.2, 0.0)]), sap, maxf(r * 0.1, 1.5), AA)
		ci.draw_line(xf * Vector2(0.3, -0.7), xf * Vector2(0.15, -0.4), sap, maxf(r * 0.1, 1.5), AA)
		for i in 3:
			var u := fposmod(t * 1.2 + i / 3.0, 1.0)
			ci.draw_circle(xf * Vector2((i - 1) * 0.3, -1.0 - 0.8 * u), r * 0.07 * (1.0 - u), Color(Art.ec("seve", "clair"), (1.0 - u) * k))
	F._outline(ci, pts, r, o, true)
	# Les yeux se tournent vers le joueur (la souche, elle, reste droite).
	var look := clampf(face.x, -1.0, 1.0) * 0.16
	var exf := Transform2D(0.0, Vector2(r, r), 0.0, pos)
	for sgn in [-1, 1]:
		F._slit(ci, exf, Vector2(look + sgn * 0.22, -0.55), 0.11, sgn, 0.35 + 0.5 * k, o)
