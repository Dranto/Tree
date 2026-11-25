## Outils de dessin du « Bestiaire d'herbier » (refonte des personnages, vague 0 : planche de direction).
##
## Grammaire commune aux Flétris et au héros :
##   - une encre sombre (Art.bc("encre")) d'épaisseur variable : fine du côté de la lumière (haut,
##     gauche), épaisse du côté de l'ombre (bas, droite), comme un trait de plume appuyé ;
##   - deux tons et une lumière : la forme est remplie de son ton d'ombre, la face éclairée est la
##     même forme décalée vers la lumière (intersection), un reflet plus petit s'y pose ;
##   - les détails (nervures, fentes, gravures) sont des coups de pinceau effilés aux deux bouts.
##
## Chaque créature décrit ses formes dans un repère local (pieds au sol en 0, y vers le haut négatif,
## 100 unités ≈ sa hauteur), regard vers +x ; le retournement gauche/droite et l'échelle sont dans la
## transformation xf. La lumière et l'encre sont calculées après la transformation, donc restent en
## haut à gauche quel que soit le sens.
##
## Rendu lissé : la planche dessine à ×4 puis réduit (la tâche T mesure la version « cuite »).
extends RefCounted

## Direction d'où vient la lumière (écran) : haut gauche, comme toute la charte.
const LIGHT := Vector2(-0.55, -0.83)

## Pose courante : éclair d'un coup reçu (0 → 1), silhouette noire, niveaux de gris.
static var flash := 0.0
static var mono := false


static func encre() -> Color:
	return Color.BLACK if mono else Art.bc("encre")


## Couleur finale d'un remplissage (éclair blanc chaud du coup reçu).
static func shade(col: Color) -> Color:
	if mono:
		return Color.BLACK
	if flash > 0.0:
		return col.lerp(Art.c("danger_eclair"), 0.8 * flash)
	return col


static func _size(w: PackedVector2Array) -> float:
	var r := Rect2(w[0], Vector2.ZERO)
	for q in w:
		r = r.expand(q)
	return maxf(r.size.x, r.size.y)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		ci.draw_colored_polygon(pts, col)


static func _shift(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	return Transform2D(0.0, d) * pts


## Encre seule autour d'une forme (déjà dans le repère de l'écran) : épaisseur iw, décalée vers l'ombre.
static func ink_world(ci: CanvasItem, w: PackedVector2Array, iw: float) -> void:
	for poly in Geometry2D.offset_polygon(w, iw, Geometry2D.JOIN_ROUND):
		_poly(ci, _shift(poly, -LIGHT * iw * 0.45), encre())


## Une forme pleine : encre, ton d'ombre, face éclairée, reflet. pal : {clair, ombre, reflet}.
## ink : épaisseur de l'encre en unités locales (0 : aucune). lit : part de la face éclairée (0 → 1).
static func part(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, pal: Dictionary, ink := 2.2, lit := 1.0, shine := 1.0) -> void:
	var w := xf * pts
	var k := xf.get_scale().abs().x
	if ink > 0.0:
		ink_world(ci, w, ink * k)
	fill_world(ci, w, pal, lit, shine)


## Remplissage deux tons + reflet d'une forme déjà dans le repère de l'écran.
static func fill_world(ci: CanvasItem, w: PackedVector2Array, pal: Dictionary, lit := 1.0, shine := 1.0) -> void:
	_poly(ci, w, shade(pal["ombre"]))
	if mono:
		return
	var s := _size(w)
	if lit > 0.0:
		for poly in Geometry2D.intersect_polygons(w, _shift(w, LIGHT * s * 0.16 * lit)):
			_poly(ci, poly, shade(pal["clair"]))
	if shine > 0.0 and pal.has("reflet"):
		var cen := Vector2.ZERO
		for q in w:
			cen += q
		cen /= w.size()
		var small := Transform2D(0.0, Vector2(0.42, 0.42), 0.0, cen * 0.58 - LIGHT * s * -0.2) * w
		for poly in Geometry2D.intersect_polygons(w, small):
			_poly(ci, poly, Color(shade(pal["reflet"]), 0.55 * shine))


## Forme d'un seul ton (avec ou sans encre) : fentes, taches, détails plats.
static func flat(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, col: Color, ink := 0.0) -> void:
	var w := xf * pts
	if ink > 0.0:
		ink_world(ci, w, ink * xf.get_scale().abs().x)
	_poly(ci, w, shade(col))


## Coup de pinceau effilé le long de pts (repère local) : largeur w au milieu, pointes aux deux bouts.
## taper_end : 0 (bout effilé) → 1 (bout plein, pour un trait qui part d'une forme).
static func brush(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, w: float, col: Color, taper_start := 0.0, taper_end := 0.0) -> void:
	if mono or pts.size() < 2:
		return
	var p := xf * pts
	var k := xf.get_scale().abs().x
	# Points intermédiaires (lissage simple de Chaikin) pour un trait souple.
	for _i in 2:
		var sm := PackedVector2Array([p[0]])
		for i in p.size() - 1:
			sm.append(p[i].lerp(p[i + 1], 0.25))
			sm.append(p[i].lerp(p[i + 1], 0.75))
		sm.append(p[p.size() - 1])
		p = sm
	var n := p.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var u := float(i) / (n - 1)
		var d := (p[mini(i + 1, n - 1)] - p[maxi(i - 1, 0)]).normalized()
		var prof := sin(PI * u)
		if u < 0.5 and taper_start > 0.0:
			prof = lerpf(prof, 1.0, taper_start)
		if u >= 0.5 and taper_end > 0.0:
			prof = lerpf(prof, 1.0, taper_end)
		var half := w * k * 0.5 * maxf(prof, 0.12)
		left.append(p[i] + d.orthogonal() * half)
		right.append(p[i] - d.orthogonal() * half)
	right.reverse()
	left.append_array(right)
	_poly(ci, left, shade(col) if col != encre() else col)


## Ellipse locale (centre c, rayons rx, ry), n points, tournée de rot.
static func oval(c: Vector2, rx: float, ry: float, n := 24, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


## Contour irrégulier : ellipse dont le rayon varie (bosses, drupes, pierre taillée).
static func lumpy(c: Vector2, rx: float, ry: float, n: int, amp: float, freq: float, phase := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var m := 1.0 + amp * absf(sin(a * freq * 0.5 + phase))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry) * m)
	return pts


## Feuille en amande, de base b vers la pointe, longueur l, largeur w (repère local).
static func leaf(b: Vector2, a: float, l: float, w: float, curl := 0.0) -> PackedVector2Array:
	var d := Vector2.from_angle(a)
	var nn := d.orthogonal()
	var pts := PackedVector2Array()
	for i in 11:
		var u := i / 10.0
		pts.append(b + d * l * u + nn * (w * 0.5 * sin(PI * u) + curl * l * u * u))
	for i in range(9, 0, -1):
		var u := i / 10.0
		pts.append(b + d * l * u - nn * (w * 0.5 * sin(PI * u) - curl * l * u * u))
	return pts


## Épine effilée (triangle courbe) de base b, direction a, longueur l, largeur w.
static func thorn(b: Vector2, a: float, l: float, w: float, bend := 0.0) -> PackedVector2Array:
	var d := Vector2.from_angle(a)
	var nn := d.orthogonal()
	return PackedVector2Array([b + nn * w * 0.5, b + d * l * 0.55 + nn * (w * 0.18 + bend * l * 0.2), b + d * l + nn * bend * l * 0.35, b + d * l * 0.55 - nn * (w * 0.18 - bend * l * 0.2), b - nn * w * 0.5])


## Ombre portée : ellipse au sol, comme le décor (Art.OMBRE_APLATI).
static func ground_shadow(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float) -> void:
	if mono:
		return
	var w := xf * oval(c, rx, rx * Art.OMBRE_APLATI, 28)
	_poly(ci, w, Art.c("ombre"))


## Braise : fente ou œil qui couve, avec un halo (signe commun de l'ennemi). glow 0 → 1.
static func ember(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, glow: float) -> void:
	if mono:
		return
	var w := xf * pts
	var s := _size(w)
	var cen := Vector2.ZERO
	for q in w:
		cen += q
	cen /= w.size()
	if glow > 0.0:
		ci.draw_circle(cen, s * (0.9 + 0.8 * glow), Color(Art.bc("braise"), 0.10 + 0.18 * glow))
		ci.draw_circle(cen, s * (0.55 + 0.4 * glow), Color(Art.bc("braise"), 0.16 + 0.22 * glow))
	_poly(ci, w, Art.bc("braise"))
	_poly(ci, Transform2D(0.0, Vector2(0.5, 0.5), 0.0, cen * 0.5) * w, Art.bc("braise_coeur").lerp(Color.WHITE, 0.4 * glow))


## Halo doux (lueur de sève, braise d'une annonce) : disques concentriques transparents.
static func halo(ci: CanvasItem, p: Vector2, r: float, col: Color, k := 1.0) -> void:
	if mono or k <= 0.0:
		return
	for i in 4:
		var u := 1.0 - i * 0.22
		ci.draw_circle(p, r * u, Color(col, 0.07 * k * (1.0 + i * 0.5)))


## Repère d'une créature posée en feet (pieds au sol), hauteur h px pour 100 unités, tournée vers
## la gauche si flip.
static func frame(feet: Vector2, h: float, flip: bool) -> Transform2D:
	var s := h / 100.0
	return Transform2D(0.0, Vector2(-s if flip else s, s), 0.0, feet)
