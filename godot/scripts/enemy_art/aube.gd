## Silhouettes des Flétris des falaises de verre (région d'Aube), selon la charte (§ 4) : mêmes
## outils que fletri_art.gd (volume, contour clair, fentes de braise), une forme par sorte qui se
## lit de loin ; le verre fumé de la région (region_art/aube.gd › PAL) remplace l'écorce par endroits.
##   - luciole (Luciole flétrie) : petit insecte de cendre aux ailes de verre qui battent, l'abdomen
##     qui luit d'une lumière sale ;
##   - miroitier : Flétri voûté qui porte devant lui un grand miroir rond cerclé d'os ; il le lève et
##     le fait briller pendant l'annonce ;
##   - prismeur : un prisme de verre fumé dressé sur trois pattes de cendre, un cristal au sommet
##     qui se charge de lumière avant le rayon ;
##   - quartz (Colosse de quartz) : un bloc de cendre trapu hérissé d'aiguilles de quartz.
## Appelé par fletri_art.gd pour les sortes de enemies.json qui portent "art": "aube".
extends RefCounted

const F = preload("res://scripts/fletri_art.gd")
const A = preload("res://scripts/region_art/aube.gd")
const AA := false


static func body_color(kind_id: String) -> Color:
	var e := Art.c("ennemi")
	match kind_id:
		"luciole":
			return e.lerp(A.pal("lumiere_sombre"), 0.3)
		"miroitier":
			return e.lerp(A.pal("verre_fume"), 0.3)
		"prismeur":
			return e.lerp(A.pal("verre_fume"), 0.55).lightened(0.04)
		"quartz":
			return e.lerp(A.pal("roche"), 0.25).lerp(A.pal("verre_fume"), 0.25)
	return e


static func draw(ci, kind_id: String, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	match kind_id:
		"luciole":
			_luciole(ci, pos, r, face, t, o)
		"miroitier":
			_miroitier(ci, pos, r, face, t, o)
		"prismeur":
			_prismeur(ci, pos, r, face, t, o)
		"quartz":
			_quartz(ci, pos, r, face, t, o)


## Verre teinté par l'état (cendre, éclair du coup) mais pas assombri par la mort comme l'écorce.
static func _glass(col: Color, o: Dictionary, alpha := 0.85) -> Color:
	return Color(F._shade(col, o), alpha * (1.0 - float(o.get("ash", 0.0)) * 0.6))


static var LUCIOLE := PackedVector2Array([Vector2(1.0, 0), Vector2(0.55, 0.32), Vector2(-0.2, 0.4), Vector2(-0.95, 0.22), Vector2(-1.1, 0), Vector2(-0.95, -0.22), Vector2(-0.2, -0.4), Vector2(0.55, -0.32)])


## Luciole : deux paires d'ailes de verre qui battent vite, un abdomen qui luit.
static func _luciole(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var bob := Vector2(0, -r * (0.5 + 0.15 * sin(t * 9.0)))
	var xf := F._xf(pos + bob, r, face, F._squash(o, t))
	var body := body_color("luciole")
	var flap := 0.55 + 0.45 * absf(sin(t * 22.0))
	if not o.get("mono", false):
		for sgn in [-1.0, 1.0]:
			for j in 2:
				var span := (1.25 - 0.3 * j) * flap
				var base := Vector2(0.25 - 0.45 * j, 0.15 * sgn)
				var w := xf * PackedVector2Array([base, base + Vector2(0.35 - 0.3 * j, span * sgn), base + Vector2(-0.35 - 0.2 * j, span * 0.8 * sgn)])
				ci.draw_colored_polygon(w, _glass(A.pal("verre").lerp(A.pal("verre_fume"), 0.4), o, 0.55))
	var pts := xf * LUCIOLE
	F._fill(ci, pts, body, o, 0.6)
	if o.get("mono", false):
		return
	# Abdomen qui luit (lumière sale, qui pulse).
	var glow := 0.55 + 0.45 * sin(t * 4.0 + pos.x * 0.01)
	ci.draw_circle(xf * Vector2(-0.65, 0), r * 0.42, Color(A.pal("lumiere"), 0.35 * glow * (1.0 - float(o.get("ash", 0.0)))))
	ci.draw_circle(xf * Vector2(-0.65, 0), r * 0.22, Color(F._shade(A.pal("lumiere_clair"), o), 0.9))
	F._outline(ci, pts, r, o)
	for sgn in [-1, 1]:
		F._slit(ci, xf, Vector2(0.62, sgn * 0.15), 0.1, sgn, 0.4, o)


static var MIROITIER := PackedVector2Array([Vector2(0.55, 0.0), Vector2(0.4, 0.6), Vector2(-0.2, 0.8), Vector2(-0.85, 0.5), Vector2(-0.95, 0.0), Vector2(-0.85, -0.5), Vector2(-0.2, -0.8), Vector2(0.4, -0.6)])


## Miroitier : un Flétri voûté, un grand miroir rond devant lui ; il le lève pendant l'annonce
## (le verre s'éclaircit), puis l'éclair blanchit tout.
static func _miroitier(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var state: String = o.get("state", "")
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var xf := F._xf(pos, r, face, F._squash(o, t))
	var body := body_color("miroitier")
	var pts := xf * MIROITIER
	F._fill(ci, pts, body, o, 0.6)
	if not o.get("mono", false):
		F._cracks(ci, xf, [[Vector2(-0.1, 0.3), Vector2(-0.5, 0.45)], [Vector2(-0.1, -0.3), Vector2(-0.5, -0.4)]], r, body, 0.35 + 0.5 * k, t, o)
		F._outline(ci, pts, r, o)
		for sgn in [-1, 1]:
			F._slit(ci, xf, Vector2(0.25, sgn * 0.28), 0.1, sgn, 0.3 + 0.4 * k, o)
	# Le miroir : un disque vu de biais devant lui, cerclé d'os, qui se lève et brille.
	var lift := 0.2 * Anim.ease_out(k) if state == "windup" else 0.0
	var cen := Vector2(0.95 + lift, 0)
	var disc := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		disc.append(cen + Vector2(cos(a) * (0.28 + 0.12 * lift), sin(a) * 0.95))
	var dd := xf * disc
	if o.get("mono", false):
		ci.draw_colored_polygon(dd, Color.BLACK)
		return
	var shine := clampf(k + (Anim.flash(strike) if strike >= 0.0 else 0.0), 0.0, 1.0)
	ci.draw_colored_polygon(dd, _glass(A.pal("verre_fume").lerp(A.pal("verre_clair"), 0.25 + 0.75 * shine), o, 0.95))
	var rim := dd.duplicate()
	rim.append(dd[0])
	ci.draw_polyline(rim, F._shade(F._bone(), o), maxf(r * 0.12, 1.5), AA)
	# Reflet en biais, et une étoile de lumière au plus fort de l'annonce.
	ci.draw_line(xf * (cen + Vector2(0.05, -0.55)), xf * (cen + Vector2(-0.05, -0.1)), Color(A.pal("verre_clair"), 0.7), maxf(r * 0.08, 1.0), AA)
	if shine > 0.3:
		var c := xf * cen
		var s := r * 0.9 * shine
		ci.draw_line(c - Vector2(s, 0), c + Vector2(s, 0), Color(A.pal("lumiere_clair"), shine), maxf(r * 0.08, 1.2), AA)
		ci.draw_line(c - Vector2(0, s), c + Vector2(0, s), Color(A.pal("lumiere_clair"), shine), maxf(r * 0.08, 1.2), AA)


## Prismeur : un prisme de verre fumé, debout sur trois pattes de cendre (il ne tourne pas, seul
## son cristal vise), le cristal du sommet se charge d'or pendant l'annonce.
static func _prismeur(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var sq := F._squash(o, t)
	var xf := Transform2D(0.0, Vector2(r * sq.x, r * sq.y), 0.0, pos)
	var body := body_color("prismeur")
	# Trois pattes de cendre, qui trottinent.
	for i in 3:
		var x := (i - 1) * 0.55
		var lift := maxf(0.0, sin(walk + i * 2.1)) * 0.15 * mv
		var leg := xf * PackedVector2Array([Vector2(x - 0.12, 0.0), Vector2(x * 1.4 - 0.08, 0.55 - lift), Vector2(x * 1.4 + 0.08, 0.55 - lift), Vector2(x + 0.12, 0.0)])
		F._fill(ci, leg, F.ash_color().darkened(0.3), o, 0.3)
		F._outline(ci, leg, r, o)
	var pts := xf * PackedVector2Array([Vector2(-0.75, 0.15), Vector2(-0.55, -1.0), Vector2(0.0, -1.75), Vector2(0.55, -1.0), Vector2(0.75, 0.15)])
	if o.get("mono", false):
		ci.draw_colored_polygon(pts, Color.BLACK)
		return
	A.draw_prism(ci, pts, F._shade(body, o), F._shade(A.pal("verre"), o))
	F._outline(ci, pts, r, o)
	F._cracks(ci, xf, [[Vector2(-0.35, -0.2), Vector2(-0.1, -0.55), Vector2(-0.25, -0.85)]], r, body, 0.35 + 0.5 * k, t, o)
	var look := clampf(face.x, -1.0, 1.0) * 0.15
	for sgn in [-1, 1]:
		F._slit(ci, xf, Vector2(look + sgn * 0.22, -0.55), 0.1, sgn, 0.3 + 0.4 * k, o)
	# Cristal du sommet, tourné vers sa cible, qui se charge de lumière.
	var top := xf * Vector2(0.0, -1.75)
	var aim := face * r * 0.55
	var n := face.orthogonal() * r * 0.2
	var gem := PackedVector2Array([top - n, top + aim, top + n, top - aim * 0.25])
	var charge := clampf(k + (Anim.flash(strike) if strike >= 0.0 else 0.0), 0.0, 1.0)
	ci.draw_colored_polygon(gem, _glass(A.pal("verre").lerp(A.pal("lumiere_clair"), charge), o, 0.95))
	var rim := gem.duplicate()
	rim.append(gem[0])
	ci.draw_polyline(rim, F._shade(A.pal("verre_sombre"), o), maxf(r * 0.07, 1.0), AA)
	if charge > 0.05:
		ci.draw_circle(top + aim * 0.4, r * (0.25 + 0.35 * charge), Color(A.pal("lumiere"), 0.45 * charge))


static var QUARTZ := PackedVector2Array([Vector2(0.95, 0.1), Vector2(0.7, 0.6), Vector2(0.0, 0.72), Vector2(-0.75, 0.55), Vector2(-0.95, 0.0), Vector2(-0.7, -0.5), Vector2(0.05, -0.62), Vector2(0.75, -0.45)])


## Colosse de quartz : un bloc de cendre trapu, droit, hérissé de cinq aiguilles de quartz qui
## pointent vers le haut ; fentes de braise et lumière piégée dans le cristal.
static func _quartz(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var sq := F._squash(o, t)
	var xf := Transform2D(0.0, Vector2(r * sq.x, r * sq.y), 0.0, pos)
	var body := body_color("quartz")
	# Deux pieds massifs.
	for sgn in [-1.0, 1.0]:
		var lift := maxf(0.0, sin(walk + (0.0 if sgn < 0.0 else PI))) * 0.15 * mv
		var foot := xf * PackedVector2Array([Vector2(0.2 * sgn, 0.45), Vector2(0.7 * sgn, 0.45 - lift), Vector2(0.72 * sgn, 0.78 - lift), Vector2(0.18 * sgn, 0.8)])
		F._fill(ci, foot, body.darkened(0.25), o, 0.3)
		F._outline(ci, foot, r, o)
	# Aiguilles de quartz derrière le corps (dessinées d'abord).
	var spikes := [[-0.55, 0.9, -0.35], [-0.2, 1.35, -0.1], [0.2, 1.15, 0.12], [0.55, 0.8, 0.32], [0.0, 0.7, 0.0]]
	for sp in spikes:
		var foot: Vector2 = xf * Vector2(sp[0], -0.3)
		var pts := A.prism(foot, r * 0.17, r * float(sp[1]), r * float(sp[2]))
		if o.get("mono", false):
			ci.draw_colored_polygon(pts, Color.BLACK)
		else:
			A.draw_prism(ci, pts, F._shade(A.pal("verre").lerp(A.pal("verre_fume"), 0.5), o), F._shade(A.pal("verre_clair"), o))
	var pts := xf * QUARTZ
	F._fill(ci, pts, body, o, 0.6)
	if o.get("mono", false):
		return
	F._cracks(ci, xf, [[Vector2(-0.5, 0.1), Vector2(-0.2, 0.3), Vector2(0.1, 0.15)], [Vector2(0.4, -0.25), Vector2(0.6, 0.05)]], r, body, 0.5, t, o)
	F._outline(ci, pts, r, o, true)
	var look := clampf(face.x, -1.0, 1.0) * 0.18
	for sgn in [-1, 1]:
		F._slit(ci, xf, Vector2(look + sgn * 0.25, -0.15), 0.11, sgn, 0.35, o)
	# Lumière piégée dans une aiguille.
	var glow := 0.5 + 0.5 * sin(t * 2.0 + pos.y * 0.01)
	ci.draw_circle(xf * Vector2(-0.2, -1.0), r * 0.12, Color(A.pal("lumiere_clair"), 0.5 * glow * (1.0 - float(o.get("ash", 0.0)))))
