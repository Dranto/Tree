## Silhouettes des Flétris du marais de Spore (charte graphique, § 4), branchées sur fletri_art.gd
## par le champ « art": "spore" de leurs sortes dans data/enemies.json.
##
## Mêmes règles que les Flétris du roncier : décrites pour un rayon de 1, regard vers +x, volume et
## contour clair (ennemi_contour), fentes d'écorce où couve la braise. Le marais les nuance de
## l'élément poison (violet) : chapeaux, pores et bulles de spores. Chaque sorte a une silhouette
## qui se lit en noir (planche des silhouettes) :
##   - Traîne-vase : limace basse et longue, trois chapeaux sur le dos, coulures de vase derrière ;
##   - Scissipore : une cellule à moitié divisée (deux lobes et un pli), pores qui s'allument ;
##   - Sporule : petite spore ronde hérissée de cils, un œil ;
##   - Lichen cuirassé : carapace à plaques couvertes de lichen, tête basse et rentrée.
## Fonctions statiques sans état, comme fletri_art.gd (cache des silhouettes compris).
extends RefCounted

const FA = preload("res://scripts/fletri_art.gd")

static var SLUG := PackedVector2Array([Vector2(1.0, 0.0), Vector2(0.82, -0.5), Vector2(0.35, -0.78), Vector2(-0.3, -0.8), Vector2(-0.95, -0.58), Vector2(-1.3, -0.2), Vector2(-1.35, 0.2), Vector2(-0.95, 0.58), Vector2(-0.3, 0.8), Vector2(0.35, 0.78), Vector2(0.82, 0.5)])
static var SHELL := FA._jag([1.0, 0.86, 0.96, 0.84, 0.98, 0.86, 0.95, 0.84, 1.0, 0.86], 0.0)


static func body_color(kind_id: String) -> Color:
	var e := Art.c("ennemi")
	match kind_id:
		"traine_vase":
			return e.lerp(Art.ec("poison", "sombre"), 0.45)
		"scissipore":
			return e.lerp(Art.ec("poison"), 0.3).darkened(0.12)
		"sporule":
			return e.lerp(Art.ec("poison"), 0.35).lightened(0.04)
		"lichen":
			return e.lerp(Art.ec("vent", "sombre"), 0.55)
	return e


static func draw(ci, kind_id: String, pos: Vector2, r: float, face: Vector2, t: float, o := {}) -> void:
	match kind_id:
		"traine_vase":
			_traine_vase(ci, pos, r, face, t, o)
		"scissipore":
			_scissipore(ci, pos, r, face, t, o)
		"sporule":
			_sporule(ci, pos, r, face, t, o)
		"lichen":
			_lichen(ci, pos, r, face, t, o)


## Petit chapeau de champignon en volume (dessus), posé en p, de largeur w, tourné vers d.
static func _cap(ci, xf: Transform2D, p: Vector2, w: float, col: Color, o: Dictionary) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		pts.append(p + Vector2(-sin(a) * 0.55, -cos(a)) * w)
	pts.append(p + Vector2(0.25, 0) * w)
	FA._fill(ci, xf * pts, col, o, 0.8)


## Pore de spores : rond sombre, cœur clair qui s'allume (g de 0 à 1).
static func _pore(ci, at: Vector2, s: float, g: float, o: Dictionary) -> void:
	if o.get("mono", false):
		return
	var ash: float = o.get("ash", 0.0)
	ci.draw_circle(at, s, FA._shade(Art.ec("poison", "sombre"), o))
	ci.draw_circle(at, s * 0.55, Color(Art.ec("poison", "clair"), (0.35 + 0.65 * g) * (1.0 - ash)))


## Traîne-vase : limace basse, trois chapeaux pâles sur le dos, coulures de vase derrière. Pendant
## l'annonce, elle s'étale et la vase bouillonne sous elle.
static func _traine_vase(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var k: float = o.get("k", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	# Reptation : le corps s'allonge et se ramasse, plus large pendant l'annonce.
	var crawl := 0.06 * sin(walk * 1.5) * mv
	var sq := FA._squash(o, t) * Vector2(1.0 + crawl, (1.0 - crawl) * (1.0 + 0.18 * k))
	var xf := FA._xf(pos, r, face, sq)
	var body := body_color("traine_vase")
	if not o.get("mono", false):
		# Coulures de vase qui traînent derrière.
		var ash: float = o.get("ash", 0.0)
		for i in 3:
			var u := fposmod(t * 0.6 + i / 3.0, 1.0)
			var q := xf * Vector2(-1.3 - 0.5 * u, (i - 1) * 0.42)
			ci.draw_circle(q, r * 0.16 * (1.0 - 0.6 * u), Color(FA._shade(Art.ec("poison", "sombre"), o), 0.8 * (1.0 - u) * (1.0 - ash)))
	var pts := xf * SLUG
	FA._fill(ci, pts, body, o)
	# Chapeaux sur le dos : le plus grand au milieu.
	var cap := body.lerp(Art.ec("poison", "clair"), 0.5)
	for i in 3:
		_cap(ci, xf, Vector2(-0.7 + i * 0.4, (i - 1) * 0.3), 0.36 + 0.1 * (1 - absf(i - 1)), cap, o)
	FA._cracks(ci, xf, [[Vector2(0.3, -0.4), Vector2(-0.1, -0.5), Vector2(-0.6, -0.42)], [Vector2(0.3, 0.4), Vector2(-0.2, 0.48)]], r, body, 0.35 + 0.4 * k, t, o)
	FA._outline(ci, pts, r, o)
	if not o.get("mono", false):
		# Pores sous les chapeaux, qui s'allument pendant l'annonce.
		for i in 2:
			_pore(ci, xf * Vector2(-0.5 + i * 0.45, 0.32), r * 0.09, k, o)
	for sgn in [-1, 1]:
		FA._slit(ci, xf, Vector2(0.62, sgn * 0.22), 0.11, sgn, 0.25 + 0.4 * k, o)


## Scissipore : une cellule à moitié divisée, deux lobes de part et d'autre du regard et un pli qui
## les sépare ; pores de spores qui palpitent, plus vite pendant l'annonce ; deux pinces d'os.
static func _scissipore(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var k: float = o.get("k", 0.0)
	var swell := 1.0 + 0.05 * sin(t * 4.0) + 0.16 * k
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var xf := FA._xf(pos, r * swell, face, FA._squash(o, t))
	var body := body_color("scissipore")
	for sgn in [-1, 1]:
		var reach: float = 0.08 * sin(walk + sgn) * mv
		FA._spike(ci, xf, Vector2(0.62 + reach, sgn * 0.28), Vector2(1, sgn * 0.55).normalized(), 0.42, FA._bone(), o)
	# Deux lobes (en arachide), pincés au milieu.
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var pinch := 1.0 - 0.22 * pow(absf(cos(a)), 3.0)
		pts.append(Vector2(cos(a) * 0.8 * pinch, sin(a) * 1.02))
	pts = xf * pts
	FA._fill(ci, pts, body, o)
	if not o.get("mono", false):
		# Le pli de la division.
		var seam := PackedVector2Array([xf * Vector2(-0.62, 0.0), xf * Vector2(-0.2, 0.05), xf * Vector2(0.2, -0.05), xf * Vector2(0.62, 0.0)])
		ci.draw_polyline(seam, FA._shade(body.darkened(0.55), o), maxf(r * 0.1, 1.2), FA.AA)
		var beat := 3.0 + 9.0 * k
		for i in 4:
			var sgn := 1.0 if i % 2 else -1.0
			var at := xf * Vector2(-0.35 + (i / 2) * 0.55, sgn * 0.55)
			_pore(ci, at, r * 0.13, 0.5 + 0.5 * sin(t * beat + i * 1.6), o)
	FA._outline(ci, pts, r, o)
	for sgn in [-1, 1]:
		FA._slit(ci, xf, Vector2(0.5, sgn * 0.2), 0.1, sgn, 0.3 + 0.4 * k, o)


## Sporule : petite spore ronde hérissée de six cils, un œil.
static func _sporule(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var f := face.rotated(0.15 * sin(t * 12.0) * maxf(0.3, float(o.get("moving", 0.0))))
	var xf := FA._xf(pos, r, f, FA._squash(o, t))
	var body := body_color("sporule")
	for i in 6:
		var d := Vector2.from_angle(PI / 6.0 + i * TAU / 6.0)
		FA._spike(ci, xf, d * 0.8, d, 0.45, Art.c("ennemi_contour").darkened(0.35), o)
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(Vector2.from_angle(TAU * i / 10.0) * (1.0 if i % 2 == 0 else 0.9))
	pts = xf * pts
	FA._fill(ci, pts, body, o)
	FA._outline(ci, pts, r, o)
	if o.get("mono", false):
		return
	var ash: float = o.get("ash", 0.0)
	ci.draw_circle(xf * Vector2(0.35, 0), maxf(r * 0.24, 1.6), Color(Art.c("ennemi_oeil"), 1.0 - ash))
	ci.draw_circle(xf * Vector2(0.42, 0), maxf(r * 0.1, 1.0), Art.c("contour"))


## Lichen cuirassé : carapace à plaques couverte de lichen (taches claires), tête basse rentrée sous
## le bord. Il se dresse pendant l'annonce (FletriArt.squash) et ses fentes rougeoient.
static func _lichen(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var k: float = o.get("k", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var xf := FA._xf(pos, r, face, FA._squash(o, t))
	var body := body_color("lichen")
	# Pattes trapues sous la carapace.
	for i in 4:
		var sgn := 1 if i % 2 else -1
		var x := 0.45 if i < 2 else -0.45
		var step := 0.1 * sin(walk + i * PI / 2.0) * mv
		FA._spike(ci, xf, Vector2(x + step, sgn * 0.78), Vector2(0.25, sgn).normalized(), 0.34, body.darkened(0.4), o)
	# Tête basse, en avant.
	var head := xf * PackedVector2Array([Vector2(0.78, -0.32), Vector2(1.22, -0.18), Vector2(1.3, 0.0), Vector2(1.22, 0.18), Vector2(0.78, 0.32)])
	FA._fill(ci, head, body.darkened(0.15), o, 0.5)
	var pts := xf * SHELL
	FA._fill(ci, pts, body, o)
	if not o.get("mono", false):
		# Plaques : lignes de jointure en étoile depuis le sommet de la carapace.
		var joint := FA._shade(body.darkened(0.5), o)
		var top := xf * Vector2(-0.1, -0.05)
		for i in 5:
			var d := Vector2.from_angle(i * TAU / 5.0 + 0.3)
			ci.draw_line(top, xf * (Vector2(-0.1, -0.05) + d * 0.82), joint, maxf(r * 0.06, 1.0), FA.AA)
		ci.draw_polyline(_ring(xf, Vector2(-0.1, -0.05), 0.42), joint, maxf(r * 0.05, 1.0), FA.AA)
		# Lichen : taches pâles bosselées (vert-de-gris), qui couvrent une bonne part de la croûte.
		var lichen := FA._shade(Art.ec("racine", "clair").lerp(Art.ec("vent", "clair"), 0.45).darkened(0.25), o)
		for l in [[Vector2(-0.5, -0.45), 0.2], [Vector2(0.25, -0.55), 0.14], [Vector2(-0.55, 0.42), 0.16], [Vector2(0.3, 0.45), 0.18], [Vector2(-0.05, 0.05), 0.12]]:
			var c: Vector2 = xf * l[0]
			var s: float = l[1] * r
			ci.draw_circle(c, s, Color(lichen, 0.85))
			ci.draw_circle(c + Vector2(s * 0.7, s * 0.2), s * 0.55, Color(lichen, 0.85))
			ci.draw_circle(c + Vector2(-s * 0.3, -s * 0.15), s * 0.35, Color(lichen.lightened(0.25), 0.8))
	FA._cracks(ci, xf, [[Vector2(-0.75, -0.1), Vector2(-0.55, 0.15)], [Vector2(0.5, -0.15), Vector2(0.65, 0.12)]], r, body, 0.3 + 0.6 * k, t, o)
	FA._outline(ci, pts, r, o, true)
	FA._outline(ci, head, r * 0.7, o)
	for sgn in [-1, 1]:
		FA._slit(ci, xf, Vector2(1.06, sgn * 0.12), 0.08, sgn, 0.3 + 0.5 * k, o)


static func _ring(xf: Transform2D, c: Vector2, rr: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		pts.append(xf * (c + Vector2.from_angle(TAU * i / 12.0) * rr))
	return pts
