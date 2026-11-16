## Dessin des Flétris selon la charte graphique (docs/charte-graphique.md, § 4) : une silhouette
## par sorte, anguleuse et cassée, en volume, contour clair, fentes d'écorce où couve la braise.
##
## Toutes les silhouettes regardent vers +x (la direction « face ») et sont décrites pour un rayon
## de 1 : la transformation (rotation, échelle, écrasement) est appliquée point par point, pour que
## la lumière de Art.volume reste en haut à gauche quelle que soit l'orientation.
##
## Fonctions statiques sans état : enemy.gd (jeu), enemy_remains.gd (mort) et la galerie s'en servent.
##
## Pose (dictionnaire, toutes les clés sont facultatives) :
##   k      : avancement de l'annonce d'attaque (0 → 1)
##   state  : "" | "windup" | "charge" | "recover" (comportement de l'ennemi)
##   walk   : phase de la marche (radians) ; moving : 0 (à l'arrêt) → 1 (pleine course)
##   flash  : éclair d'un coup reçu (1 → 0) ; tint : Color dont l'alpha dit la part de teinte
##   strike : avancement de l'éclair du coup qui vient de partir (0 → 1, -1 : aucun)
##   ash    : 0 → 1, la silhouette devient cendre (mort) ; mono : silhouette noire (planche)
extends RefCounted

## Traits lissés : non. Les silhouettes passent par un lot de triangles (draw_batch.gd), sans lissage.
const AA := false

## Teinte du corps de chaque sorte : toutes partent du rôle « ennemi », un élément les nuance.
static func body_color(kind_id: String) -> Color:
	var e := Art.c("ennemi")
	match kind_id:
		"cendreux":
			return e.lerp(Art.ec("cendre", "sombre"), 0.5)
		"colosse":
			return e.darkened(0.14)
		"cracheur":
			return e.lerp(Art.ec("cendre", "sombre"), 0.3)
		"gardien":
			return e.lerp(Art.ec("racine", "sombre"), 0.55)
		"boursoufle":
			return e.lerp(Art.ec("poison", "sombre"), 0.5)
		"chargeur":
			return e.darkened(0.06)
		"nid":
			return e.darkened(0.3)
		"rejeton":
			return e.lightened(0.06)
	return e


## Couleur de la cendre (mort, silhouette éteinte).
static func ash_color() -> Color:
	return Art.c("brume").lightened(0.15)


## Dessine la sorte kind_id en pos, de rayon r, tournée vers face.
static func draw(ci, kind_id: String, pos: Vector2, r: float, face: Vector2, t: float, o := {}) -> void:
	match kind_id:
		"cendreux":
			_cendreux(ci, pos, r, face, t, o)
		"colosse":
			_colosse(ci, pos, r, face, t, o)
		"cracheur":
			_cracheur(ci, pos, r, face, t, o)
		"gardien":
			_gardien(ci, pos, r, face, t, o)
		"boursoufle":
			_boursoufle(ci, pos, r, face, t, o)
		"tireur":
			_tireur(ci, pos, r, face, t, o)
		"chargeur":
			_chargeur(ci, pos, r, face, t, o)
		"nid":
			_nid(ci, pos, r, face, t, o)
		"rejeton":
			_rejeton(ci, pos, r, face, t, o)
		_:
			_fletri(ci, pos, r, face, t, o)


# --- Outils ---

## Volume de la charte (Art.volume, Art.volume_circle), pour un CanvasItem ou un lot de triangles.
static func _volume(ci, pts: PackedVector2Array, col: Color, light := 1.0) -> void:
	var cen := Vector2.ZERO
	for q in pts:
		cen += q
	cen /= pts.size()
	var r := 0.0
	for q in pts:
		r = maxf(r, q.distance_to(cen))
	if ci.has_method("polygon_tri"):
		# Lot de triangles : les trois couches ont la même forme, une seule triangulation suffit.
		var tri := Geometry2D.triangulate_polygon(pts)
		ci.polygon_tri(pts, col.darkened(0.38), tri)
		ci.polygon_tri(Art._xform(pts, cen, 0.84, Vector2(-0.06, -0.09) * r), col, tri)
		if light > 0.0:
			ci.polygon_tri(Art._xform(pts, cen, 0.4, Vector2(-0.24, -0.3) * r), Color(col.lightened(0.3), 0.5 * light), tri)
		return
	ci.draw_colored_polygon(pts, col.darkened(0.38))
	ci.draw_colored_polygon(Art._xform(pts, cen, 0.84, Vector2(-0.06, -0.09) * r), col)
	if light > 0.0:
		ci.draw_colored_polygon(Art._xform(pts, cen, 0.4, Vector2(-0.24, -0.3) * r), Color(col.lightened(0.3), 0.5 * light))


static func _volume_circle(ci, pos: Vector2, r: float, col: Color, light := 1.0) -> void:
	ci.draw_circle(pos, r, col.darkened(0.38))
	ci.draw_circle(pos + Vector2(-0.07, -0.1) * r, r * 0.84, col)
	if light > 0.0:
		ci.draw_circle(pos + Vector2(-0.3, -0.34) * r, r * 0.34, Color(col.lightened(0.32), 0.55 * light))

static func _jag(radii: Array, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in radii.size():
		pts.append(Vector2.from_angle(rot + i * TAU / radii.size()) * float(radii[i]))
	return pts


static var FLETRI := _jag([1.0, 0.72, 1.05, 0.8, 0.95, 0.68, 1.0, 0.85], 0.2)
static var COLOSSE := _jag([1.0, 0.9, 1.0, 0.92, 1.0, 0.9], 0.0)
static var TIREUR := PackedVector2Array([Vector2(-1, -0.7), Vector2(0.5, -0.55), Vector2(0.8, 0), Vector2(0.5, 0.55), Vector2(-1, 0.7), Vector2(-0.6, 0)])
static var REJETON := PackedVector2Array([Vector2(1.0, 0), Vector2(0.55, 0.5), Vector2(-0.1, 0.72), Vector2(-0.7, 0.45), Vector2(-0.95, 0), Vector2(-0.7, -0.45), Vector2(-0.1, -0.72), Vector2(0.55, -0.5)])
static var CRACHEUR := PackedVector2Array([Vector2(0.3, -0.62), Vector2(-0.2, -0.78), Vector2(-0.8, -0.5), Vector2(-0.98, 0), Vector2(-0.8, 0.5), Vector2(-0.2, 0.78), Vector2(0.3, 0.62), Vector2(0.58, 0.28), Vector2(0.58, -0.28)])
static var GARDIEN := _jag([0.92, 0.82, 0.95, 0.85, 0.92, 0.82, 0.95, 0.85], PI / 8.0)


static func _xf(pos: Vector2, r: float, face: Vector2, sq := Vector2.ONE) -> Transform2D:
	return Transform2D(face.angle(), Vector2(r * sq.x, r * sq.y), 0.0, pos)


## Écrasement de la pose : marche (rebond), anticipation (ramassé), coup reçu.
static func _squash(o: Dictionary, t: float) -> Vector2:
	var mv: float = o.get("moving", 0.0)
	var walk: float = o.get("walk", 0.0)
	var s := Vector2(1.0 + 0.04 * sin(walk * 2.0) * mv, 1.0 - 0.04 * sin(walk * 2.0) * mv)
	var k: float = o.get("k", 0.0)
	if k > 0.0:
		s *= Vector2(1.0 - 0.12 * Anim.ease_out(k), 1.0 + 0.1 * Anim.ease_out(k))
	var fl: float = o.get("flash", 0.0)
	if fl > 0.0:
		s *= Vector2(1.0 - 0.18 * fl, 1.0 + 0.14 * fl)
	# Repos : une respiration lente, même à l'arrêt.
	var b := Anim.breathe(t, 0.025)
	return s * Vector2(b, 2.0 - b)


## Couleur finale : teinte d'état, cendre, éclair du coup reçu.
static func _shade(col: Color, o: Dictionary) -> Color:
	var tint: Color = o.get("tint", Color(0, 0, 0, 0))
	if tint.a > 0.0:
		col = col.lerp(Color(tint, 1.0), tint.a)
	var ash: float = o.get("ash", 0.0)
	if ash > 0.0:
		col = col.lerp(ash_color(), ash)
	var fl: float = o.get("flash", 0.0)
	if fl > 0.0:
		col = col.lerp(Art.c("danger_eclair"), 0.85 * fl)
	return col


## Remplit une forme avec du volume (ou en noir pour la planche des silhouettes).
static func _fill(ci, pts: PackedVector2Array, col: Color, o: Dictionary, light := 1.0) -> void:
	if o.get("mono", false):
		ci.draw_colored_polygon(pts, Color.BLACK)
	else:
		_volume(ci, pts, _shade(col, o), light)


static func _outline(ci, pts: PackedVector2Array, r: float, o: Dictionary, strong := false) -> void:
	if o.get("mono", false):
		return
	var w := maxf(r * (0.12 if strong else 0.1), Art.TRAIT if strong else Art.TRAIT_FIN)
	var col := Art.c("ennemi_contour")
	var ash: float = o.get("ash", 0.0)
	if ash > 0.0:
		col = Color(col.lerp(ash_color(), ash), 1.0 - ash)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, col, w, AA)


## Pointe en volume (moitié éclairée, moitié dans l'ombre), décrite dans le repère de la silhouette.
static func _spike(ci, xf: Transform2D, base: Vector2, d: Vector2, len: float, col: Color, o: Dictionary) -> void:
	var b := xf * base
	var tip := xf * (base + d * len)
	var n := (tip - b).orthogonal() * 0.25
	if o.get("mono", false):
		ci.draw_colored_polygon(PackedVector2Array([b + n, tip, b - n]), Color.BLACK)
		return
	col = _shade(col, o)
	ci.draw_colored_polygon(PackedVector2Array([b + n, tip, b]), col.lightened(0.15))
	ci.draw_colored_polygon(PackedVector2Array([b, tip, b - n]), col.darkened(0.3))


## Os des griffes, cornes et canons.
static func _bone() -> Color:
	return Art.ec("epine", "clair").darkened(0.15)


## Fentes de l'écorce, avec la braise qui couve dedans (plus vive pendant une annonce).
static func _cracks(ci, xf: Transform2D, lines: Array, r: float, body: Color, glow: float, t: float, o: Dictionary) -> void:
	if o.get("mono", false) or r < 7.0:
		return
	var w := maxf(r * 0.07, 1.0)
	var ember := Art.ec("cendre")
	var ash: float = o.get("ash", 0.0)
	for crack in lines:
		var line := PackedVector2Array()
		for q in crack:
			line.append(xf * q)
		ci.draw_polyline(line, _shade(body.darkened(0.6), o), w * 1.8, AA)
		var flick := 0.85 + 0.15 * sin(t * 6.0 + line[0].x * 0.05)
		ci.draw_polyline(line, Color(ember, glow * flick * (1.0 - ash)), w * 0.7, AA)


## Œil fendu des Flétris : une lueur et un trait oblique de braise.
static func _slit(ci, xf: Transform2D, p: Vector2, s: float, side: int, glow: float, o: Dictionary) -> void:
	if o.get("mono", false):
		return
	var col := Art.c("ennemi_oeil")
	var ash: float = o.get("ash", 0.0)
	var c := xf * p
	var sw := xf.get_scale().x * s
	ci.draw_circle(c, sw * 1.25, Color(col, glow * (1.0 - ash)))
	var a := xf * (p + Vector2(-s, -side * s * 0.6))
	var b := xf * (p + Vector2(s, side * s * 0.2))
	ci.draw_line(a, b, Color(col, 1.0 - ash), clampf(sw * 0.45, 1.3, 5.0), AA)


## Flocon de cendre (losange).
static func _flake(ci, q: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -s * 1.4), q + Vector2(s, 0), q + Vector2(0, s * 1.4), q + Vector2(-s, 0)]), col)


## Flocons de cendre qui s'élèvent au-dessus d'un Flétri (n flocons).
static func _ash_flakes(ci, pos: Vector2, r: float, t: float, n: int, o: Dictionary) -> void:
	if o.get("mono", false) or r < 9.0:
		return
	for i in n:
		var k := fposmod(t * 0.42 + i / float(n), 1.0)
		var q := pos + Vector2(-r * (0.3 + 0.3 * i) * 0.6 + sin(TAU * k + i) * r * 0.15, -r * (0.8 + 0.9 * k))
		_flake(ci, q, r * 0.06, Color(ash_color().lightened(0.2), 0.75 * sin(PI * k)))


# --- Les sortes ---

## Flétri (mêlée) : corps compact cassé, deux griffes d'os vers l'avant qui s'avancent tour à tour.
static func _fletri(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var xf := _xf(pos, r, face, _squash(o, t))
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	for sgn in [-1, 1]:
		var reach: float = 0.1 * sin(walk) * mv * sgn
		_spike(ci, xf, Vector2(0.78 + reach, sgn * 0.46), Vector2(1, sgn * 0.4).normalized(), 0.55, _bone(), o)
	var body := body_color("fletri")
	var pts := xf * FLETRI
	_fill(ci, pts, body, o)
	if r >= 10.0 and not o.get("mono", false):
		# Grain de l'écorce et lichen mort.
		var grain := _shade(body.darkened(0.3), o)
		for g in [[Vector2(0.15, 0.3), Vector2(0.45, 0.42)], [Vector2(-0.5, 0.05), Vector2(-0.7, 0.12)], [Vector2(0.3, -0.62), Vector2(0.5, -0.5)]]:
			ci.draw_line(xf * g[0], xf * g[1], grain, maxf(r * 0.04, 0.8), AA)
		for l in [Vector2(-0.55, -0.45), Vector2(-0.62, 0.32)]:
			ci.draw_circle(xf * l, r * 0.06, Color(Art.c("brume").lightened(0.2), 0.5))
	_cracks(ci, xf, [[Vector2(-0.1, -0.05), Vector2(-0.45, -0.35), Vector2(-0.62, -0.28)], [Vector2(-0.1, -0.05), Vector2(-0.3, 0.35), Vector2(-0.55, 0.5)], [Vector2(-0.1, -0.05), Vector2(0.1, -0.5)]], r, body, 0.5, t, o)
	_outline(ci, pts, r, o)
	for sgn in [-1, 1]:
		_slit(ci, xf, Vector2(0.38, sgn * 0.27), 0.13, sgn, 0.25, o)
	_ash_flakes(ci, pos, r, t, 2, o)


## Cendreux (petit, rapide) : une flammèche de cendre, tête ronde et traîne de langues effilées.
static func _cendreux(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var xf := _xf(pos, r, face, _squash(o, t))
	var pts := PackedVector2Array()
	for i in 7:
		var a := -1.15 + i * 2.3 / 6.0
		pts.append(Vector2(0.1 + cos(a) * 0.85, sin(a) * 0.8))
	var tongues := [Vector2(-0.35, 0.74), Vector2(-1.05, 0.58), Vector2(-0.55, 0.28), Vector2(-1.4, 0.0), Vector2(-0.55, -0.28), Vector2(-1.05, -0.58), Vector2(-0.35, -0.74)]
	for i in tongues.size():
		var q: Vector2 = tongues[i]
		if i % 2 == 1:
			q += Vector2(0.12 * sin(t * 9.0 + i), 0.1 * sin(t * 11.0 + i * 2.0))
		pts.append(q)
	pts = xf * pts
	var body := body_color("cendreux")
	_fill(ci, pts, body, o)
	if not o.get("mono", false):
		# Cœur de braise qui palpite, visible à travers la cendre.
		var pulse := 0.5 + 0.5 * sin(t * 7.0)
		var ash: float = o.get("ash", 0.0)
		var core := xf * Vector2(-0.05, 0.0)
		ci.draw_circle(core, r * (0.38 + 0.06 * pulse), Color(Art.ec("cendre"), 0.35 * (1.0 - ash)))
		ci.draw_circle(core, r * 0.2, Color(_shade(Art.ec("cendre", "clair"), o), 1.0 - ash))
	_outline(ci, pts, r, o)
	for sgn in [-1, 1]:
		_slit(ci, xf, Vector2(0.5, sgn * 0.26), 0.14, sgn, 0.3, o)
	# Braises qui se détachent de la traîne.
	if not o.get("mono", false):
		for i in 3:
			var k := fposmod(t * 1.6 + i / 3.0, 1.0)
			var q := xf * Vector2(-1.1 - 0.9 * k, (i - 1) * 0.35 + 0.2 * sin(t * 5.0 + i))
			_flake(ci, q, r * 0.09 * (1.0 - k), Color(Art.ec("cendre", "clair"), 0.8 * (1.0 - k)))


## Colosse (lourd) : bloc d'écorce à plaques, deux poings massifs, trait fort, petits yeux.
static func _colosse(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	# Démarche lourde : le corps roule d'un côté à l'autre.
	var f := face.rotated(0.08 * sin(walk) * mv)
	var xf := _xf(pos, r, f, _squash(o, t))
	var body := body_color("colosse")
	for sgn in [-1, 1]:
		var reach: float = 0.14 * sin(walk) * mv * sgn
		var fist := xf * Vector2(0.72 + reach, sgn * 0.74)
		if o.get("mono", false):
			ci.draw_circle(fist, r * 0.32, Color.BLACK)
		else:
			_volume_circle(ci, fist, r * 0.32, _shade(body.lightened(0.08), o))
			ci.draw_arc(fist, r * 0.32, 0.0, TAU, 16, Art.c("ennemi_contour"), maxf(r * 0.07, Art.TRAIT_FIN), AA)
			# Jointures d'os.
			for j in 3:
				ci.draw_circle(xf * Vector2(0.95 + reach, sgn * (0.6 + 0.14 * j)), r * 0.05, _shade(_bone(), o))
	var pts := xf * COLOSSE
	if o.get("mono", false):
		ci.draw_colored_polygon(pts, Color.BLACK)
		return
	ci.draw_colored_polygon(pts, _shade(body.darkened(0.45), o))
	var plates := [
		[Vector2(-0.82, -0.3), Vector2(-0.3, -0.78), Vector2(0.35, -0.72), Vector2(0.15, -0.2), Vector2(-0.45, 0.0)],
		[Vector2(0.25, -0.62), Vector2(0.82, -0.3), Vector2(0.85, 0.3), Vector2(0.3, 0.2), Vector2(0.22, -0.12)],
		[Vector2(-0.82, 0.1), Vector2(-0.4, 0.12), Vector2(0.2, 0.32), Vector2(0.25, 0.75), Vector2(-0.45, 0.75)],
		[Vector2(0.35, 0.32), Vector2(0.82, 0.38), Vector2(0.45, 0.78), Vector2(0.32, 0.72)],
	]
	for pl in plates:
		_volume(ci, xf * PackedVector2Array(pl), _shade(body.lightened(0.05), o), 0.7)
	_cracks(ci, xf, [[Vector2(-0.5, -0.05), Vector2(0.18, -0.16), Vector2(0.26, 0.26), Vector2(-0.4, 0.06)]], r, body, 0.6, t, o)
	_outline(ci, pts, r, o, true)
	for sgn in [-1, 1]:
		_slit(ci, xf, Vector2(0.55, sgn * 0.14), 0.08, sgn, 0.3, o)
	_ash_flakes(ci, pos, r, t, 3, o)


## Cracheur de cendre : corps voûté, gorge gonflée de braises, long museau en entonnoir, cheminées.
static func _cracheur(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var recoil := 0.25 * Anim.flash(strike) if strike >= 0.0 else 0.0
	var xf := _xf(pos - face * r * recoil, r, face, _squash(o, t))
	var body := body_color("cracheur")
	# Cheminées sur le dos, avec leurs fumerolles.
	for sgn in [-1, 1]:
		var b := xf * Vector2(-0.62, sgn * 0.42)
		if o.get("mono", false):
			ci.draw_circle(b, r * 0.2, Color.BLACK)
		else:
			ci.draw_circle(b, r * 0.2, _shade(body.darkened(0.4), o))
			ci.draw_circle(b, r * 0.11, Color(Art.ec("cendre", "sombre"), 1.0))
	var pts := xf * CRACHEUR
	_fill(ci, pts, body, o)
	# Gorge gonflée de braises : elle enfle pendant l'annonce.
	var throat := xf * Vector2(0.28, 0.0)
	if not o.get("mono", false):
		var tr := r * (0.3 + 0.18 * k)
		ci.draw_circle(throat, tr, _shade(Art.ec("cendre", "sombre").lerp(body, 0.3), o))
		ci.draw_circle(throat, tr * 0.6, Color(Art.ec("cendre"), 0.35 + 0.6 * k))
	# Museau en entonnoir tourné vers la cible.
	var funnel := xf * PackedVector2Array([Vector2(0.45, -0.24), Vector2(1.38, -0.44), Vector2(1.38, 0.44), Vector2(0.45, 0.24)])
	_fill(ci, funnel, body.darkened(0.2), o, 0.6)
	_outline(ci, pts, r, o)
	_outline(ci, funnel, r * 0.8, o)
	if not o.get("mono", false):
		var mouth := xf * Vector2(1.38, 0.0)
		ci.draw_circle(mouth, r * 0.36, Art.c("contour"))
		ci.draw_circle(mouth, r * (0.12 + 0.22 * k), Art.ec("cendre").lerp(Art.ec("cendre", "clair"), k))
		# Fumerolles qui montent des cheminées.
		for i in 4:
			var u := fposmod(t * 0.8 + i * 0.25, 1.0)
			var b := xf * Vector2(-0.62, (1 if i % 2 else -1) * 0.42)
			ci.draw_circle(b + Vector2(sin(u * 5.0 + i) * r * 0.15, -r * (0.2 + 1.1 * u)), r * (0.12 + 0.14 * u), Color(Art.c("brume").lightened(0.15), 0.5 * (1.0 - u)))
	for sgn in [-1, 1]:
		_slit(ci, xf, Vector2(0.05, sgn * 0.36), 0.12, sgn, 0.3 + 0.5 * k, o)


## Gardien d'écorce : corps trapu à plaques, grand écu d'écorce en croissant tenu face au joueur.
static func _gardien(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var xf := _xf(pos, r, face, _squash(o, t))
	var body := body_color("gardien")
	var pts := xf * GARDIEN
	_fill(ci, pts, body, o)
	if not o.get("mono", false):
		var bark := _shade(Art.ec("racine", "sombre").lerp(body, 0.4), o)
		for i in 5:
			var a := PI * 0.55 + i * PI * 0.22
			var cen := xf * (Vector2.from_angle(a) * 0.5)
			ci.draw_arc(cen, r * 0.3, a + PI - 0.9, a + PI + 0.9, 8, bark, maxf(r * 0.1, 1.2), AA)
	_outline(ci, pts, r, o)
	for sgn in [-1, 1]:
		_slit(ci, xf, Vector2(0.35, sgn * 0.3), 0.11, sgn, 0.3, o)
	# Écu : un croissant d'écorce noueuse, gravé d'un nœud de racine.
	var shield := PackedVector2Array()
	for i in 11:
		var a := -1.15 + i * 2.3 / 10.0
		shield.append(Vector2.from_angle(a) * 1.28)
	for i in 11:
		var a := 1.0 - i * 2.0 / 10.0
		shield.append(Vector2(-0.12, 0) + Vector2.from_angle(a) * 0.98)
	shield = xf * shield
	_fill(ci, shield, Art.ec("racine"), o)
	if not o.get("mono", false):
		var rim := PackedVector2Array()
		for i in 9:
			rim.append(xf * (Vector2.from_angle(-1.0 + i * 2.0 / 8.0) * 1.2))
		ci.draw_polyline(rim, _shade(Art.ec("racine", "clair"), o), maxf(r * 0.06, 1.0), AA)
		var knot := xf * Vector2(1.12, 0.0)
		ci.draw_line(xf * Vector2(1.08, -0.45), xf * Vector2(1.08, 0.45), _shade(Art.ec("racine", "sombre"), o), maxf(r * 0.07, 1.0), AA)
		ci.draw_circle(knot, r * 0.12, _shade(Art.ec("racine", "clair"), o))
	_outline(ci, shield, r * 0.8, o)


## Boursouflé : outre gonflée et bosselée, pustules de spores violettes qui palpitent, pattes courtes.
static func _boursoufle(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var swell := 1.0 + 0.06 * sin(t * 5.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var xf := _xf(pos, r * swell, face, _squash(o, t))
	var body := body_color("boursoufle")
	# Pattes courtes qui trottinent.
	for i in 4:
		var sgn := 1 if i % 2 else -1
		var x := 0.35 if i < 2 else -0.4
		var step := 0.12 * sin(walk + i * PI / 2.0) * mv
		_spike(ci, xf, Vector2(x + step, sgn * 0.8), Vector2(0.2, sgn).normalized(), 0.32, body.darkened(0.35), o)
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var bump := 0.0
		for j in 6:
			var d := absf(wrapf(a - (j * TAU / 6.0 + 0.5), -PI, PI))
			bump = maxf(bump, 0.16 * maxf(0.0, 1.0 - d / 0.4))
		pts.append(Vector2.from_angle(a) * (0.92 + bump))
	pts = xf * pts
	_fill(ci, pts, body, o)
	_outline(ci, pts, r, o)
	if o.get("mono", false):
		return
	# Pustules de spores, qui s'allument tour à tour.
	var spore := Art.ec("poison")
	var ash: float = o.get("ash", 0.0)
	for j in 6:
		var at := xf * (Vector2.from_angle(j * TAU / 6.0 + 0.5) * 0.62)
		var g := 0.5 + 0.5 * sin(t * 4.0 + j * 1.7)
		_volume_circle(ci, at, r * 0.2, _shade(spore.darkened(0.25), o), 0.8)
		ci.draw_circle(at, r * 0.1, Color(Art.ec("poison", "clair"), (0.5 + 0.5 * g) * (1.0 - ash)))
	# Bulles de spores qui s'échappent.
	for i in 2:
		var u := fposmod(t * 0.7 + i * 0.5, 1.0)
		var q := pos + Vector2(sin(t * 2.0 + i * 3.0) * r * 0.5, -r * (0.6 + 1.1 * u))
		ci.draw_arc(q, r * (0.08 + 0.1 * u), 0.0, TAU, 10, Color(Art.ec("poison", "clair"), (1.0 - u) * (1.0 - ash)), Art.TRAIT_FIN, AA)
	for sgn in [-1, 1]:
		_slit(ci, xf, Vector2(0.72, sgn * 0.2), 0.1, sgn, 0.25, o)


## Tireur d'épines : corps effilé, piquants dans le dos, long canon-épine cerclé, un œil.
static func _tireur(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var recoil := 0.3 * Anim.flash(strike) if strike >= 0.0 else 0.0
	var xf := _xf(pos - face * r * recoil, r, face, _squash(o, t))
	var body := body_color("tireur")
	for i in 3:
		_spike(ci, xf, Vector2(-0.55 - i * 0.12, (i - 1) * 0.45), Vector2(-1, (i - 1) * 0.5).normalized(), 0.6, Art.c("ennemi_contour").darkened(0.35), o)
	var pts := xf * TIREUR
	_fill(ci, pts, body, o)
	# Le canon-épine s'allonge pendant la visée.
	var len := 1.2 + 0.35 * k
	_spike(ci, xf, Vector2(0.55, 0), Vector2.RIGHT, len, _bone(), o)
	if o.get("mono", false):
		return
	for i in 2:
		var x := 0.78 + i * 0.28
		ci.draw_line(xf * Vector2(x, -0.2 + i * 0.05), xf * Vector2(x, 0.2 - i * 0.05), _shade(body.darkened(0.4), o), maxf(r * 0.08, 1.0), AA)
	_outline(ci, pts, r, o)
	var ash: float = o.get("ash", 0.0)
	var eye := xf * Vector2(0.05, 0)
	ci.draw_circle(eye, r * 0.32, Color(Art.c("ennemi_oeil"), (0.3 + 0.4 * k) * (1.0 - ash)))
	ci.draw_circle(eye, r * 0.18, Color(Art.c("ennemi_oeil"), 1.0 - ash))
	ci.draw_circle(xf * Vector2(0.1, 0), r * 0.07, Art.c("contour"))
	# La pointe rougeoie avant le tir.
	if k > 0.0:
		var tip := xf * Vector2(0.55 + len, 0)
		ci.draw_circle(tip, r * (0.1 + 0.3 * k), Color(Art.ec("cendre"), 0.4 * k))
		ci.draw_circle(tip, r * (0.08 + 0.08 * k), Art.ec("cendre", "clair"))


## Chargeur : taureau de ronce, deux cornes d'os en croissant, crête d'épines sur l'échine.
static func _chargeur(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var state: String = o.get("state", "")
	var sq := _squash(o, t)
	var shake := Vector2.ZERO
	if state == "windup":
		shake = face.orthogonal() * sin(t * 60.0) * r * 0.1
	elif state == "charge":
		sq = Vector2(1.22, 0.84)
	var xf := _xf(pos + shake, r, face, sq)
	var body := body_color("chargeur")
	if state == "recover":
		body = body.lerp(Art.c("contour"), 0.3)
	if state == "charge" and not o.get("mono", false):
		# Poussière soulevée derrière lui.
		for i in 4:
			var q := xf * Vector2(-1.3 - i * 0.45, (i % 2 - 0.5) * 0.7)
			ci.draw_circle(q, r * (0.3 - i * 0.05), Color(Art.c("brume").lightened(0.2), 0.4 - i * 0.08))
	# Cornes : deux pointes d'os coudées.
	for sgn in [-1, 1]:
		var base := Vector2(0.8, sgn * 0.42)
		var d1 := Vector2(1, sgn * 0.75).normalized()
		_spike(ci, xf, base, d1, 0.62, _bone(), o)
		_spike(ci, xf, base + d1 * 0.42, Vector2(1, -sgn * 0.25).normalized(), 0.5, _bone(), o)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var v := Vector2(cos(a) * 1.22, sin(a) * 0.82)
		if v.x > 0.0:
			v.y *= 1.0 - 0.2 * v.x
		pts.append(v * (1.0 + 0.04 * sin(a * 4.0 + t * 5.0)))
	pts = xf * pts
	_fill(ci, pts, body, o)
	# Crête d'épines sur l'échine, pointées vers l'arrière.
	for i in 4:
		_spike(ci, xf, Vector2(0.45 - i * 0.4, 0), Vector2(-1, 0.25 * (1 if i % 2 else -1)).normalized(), 0.42, Art.c("ennemi_contour").darkened(0.4), o)
	_cracks(ci, xf, [[Vector2(-0.6, -0.4), Vector2(-0.2, -0.5), Vector2(0.1, -0.35)], [Vector2(-0.6, 0.4), Vector2(-0.2, 0.5), Vector2(0.1, 0.35)]], r, body, 0.4 + 0.5 * float(o.get("k", 0.0)), t, o)
	_outline(ci, pts, r, o)
	for sgn in [-1, 1]:
		_slit(ci, xf, Vector2(0.62, sgn * 0.3), 0.12, sgn, 0.3 + (0.5 if state == "windup" else 0.0), o)
	if state == "recover" and not o.get("mono", false):
		# Étourdi : trois braises tournent au-dessus de sa tête.
		for i in 3:
			var a := t * 5.0 + i * TAU / 3.0
			_flake(ci, pos + Vector2(cos(a) * r * 0.7, -r * 1.2 + sin(a) * r * 0.25), r * 0.1, Art.ec("cendre", "clair"))


## Nid de ronces : monticule étoilé de ronces emmêlées, cœur de braise qui enfle avant une naissance.
static func _nid(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var k: float = o.get("k", 0.0)
	var b := Anim.breathe(t, 0.03 + 0.05 * k)
	var xf := _xf(pos, r * b, Vector2.RIGHT, Vector2.ONE)
	var body := body_color("nid")
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		_spike(ci, xf, Vector2.from_angle(a) * 0.8, Vector2.from_angle(a), 0.45, Art.c("ennemi_contour").darkened(0.4), o)
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(Vector2.from_angle(a) * (1.0 if i % 2 == 0 else 0.8))
	pts = xf * pts
	_fill(ci, pts, body, o)
	if o.get("mono", false):
		return
	# Ronces emmêlées en boucles.
	var vine := _shade(body.darkened(0.45), o)
	for i in 7:
		var a := TAU * i / 7.0 + 0.4
		ci.draw_arc(xf * (Vector2.from_angle(a) * 0.45), r * 0.52, a + 1.2, a + 4.2, 10, vine, maxf(r * 0.1, 1.5), AA)
	_cracks(ci, xf, [[Vector2(0, 0), Vector2(0.55, -0.3)], [Vector2(0, 0), Vector2(-0.5, -0.4)], [Vector2(0, 0), Vector2(-0.1, 0.62)]], r, body, 0.5 + 0.5 * k, t, o)
	_outline(ci, pts, r, o, true)
	# Cœur qui enfle avant de faire naître un Rejeton.
	var ash: float = o.get("ash", 0.0)
	var core := r * (0.26 + 0.2 * k + 0.03 * sin(t * 3.0))
	ci.draw_circle(pos, core * 1.7, Color(Art.ec("cendre"), (0.18 + 0.35 * k) * (1.0 - ash)))
	_volume_circle(ci, pos, core, _shade(Art.ec("cendre").lerp(Art.ec("cendre", "clair"), k), o), 0.8)


## Rejeton : larve de ronce en goutte, une épine recourbée sur le dos, qui frétille.
static func _rejeton(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var f := face.rotated(0.18 * sin(t * 14.0) * maxf(0.3, float(o.get("moving", 0.0))))
	var xf := _xf(pos, r, f, _squash(o, t))
	# Épine recourbée en crochet sur le dos, et deux mandibules à l'avant.
	_spike(ci, xf, Vector2(-0.55, -0.1), Vector2(-0.6, -1).normalized(), 1.0, _bone(), o)
	_spike(ci, xf, Vector2(-0.6, -0.75), Vector2(1, -0.35).normalized(), 0.5, _bone(), o)
	for sgn in [-1, 1]:
		_spike(ci, xf, Vector2(0.75, sgn * 0.3), Vector2(1, sgn * 0.8).normalized(), 0.55, _bone(), o)
	var pts := xf * REJETON
	_fill(ci, pts, body_color("rejeton"), o)
	_outline(ci, pts, r, o)
	if o.get("mono", false):
		return
	var ash: float = o.get("ash", 0.0)
	for sgn in [-1, 1]:
		ci.draw_circle(xf * Vector2(0.45, sgn * 0.25), maxf(r * 0.14, 1.3), Color(Art.c("ennemi_oeil"), 1.0 - ash))
