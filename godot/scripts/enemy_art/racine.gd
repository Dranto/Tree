## Silhouettes des Flétris de la forêt pétrifiée (région de Racine), selon la charte (§ 4) : mêmes
## outils que fletri_art.gd (volume, contour clair, fentes de braise), une forme par sorte qui se lit
## de loin.
##   - termite (Termite de cendre) : petit, trois segments, mandibules en pince ; il trotte vite ;
##   - mandragore (Mandragore) : une racine fourchue à visage, une touffe de feuilles mortes sur la
##     tête ; sous terre, on ne voit qu'un sillon de terre qui avance (pose « under ») ; elle en sort
##     pendant l'annonce (pose « rising ») ;
##   - scarabee (Scarabée perce-écorce) : une carapace ronde et bombée, fendue au milieu, une corne
##     en vrille à l'avant (celle qui perce l'armure) ; elle s'ouvre pendant la charge ;
##   - tertre (Tertre de pierre) : un colosse de roche trapu, deux poings énormes, une racine
##     pétrifiée en travers du dos ; il lève les poings pendant l'annonce.
## Appelé par fletri_art.gd pour les sortes de enemies.json qui portent "art": "racine".
extends RefCounted

const F = preload("res://scripts/fletri_art.gd")
const AA := false


static func body_color(kind_id: String) -> Color:
	var e := Art.c("ennemi")
	match kind_id:
		"termite":
			return e.lerp(Art.ec("racine", "sombre"), 0.35).darkened(0.05)
		"mandragore":
			return e.lerp(Art.ec("racine", "sombre"), 0.55).lightened(0.04)
		"scarabee":
			return e.lerp(Art.ec("racine", "sombre"), 0.3).darkened(0.12)
		"tertre":
			return e.lerp(Art.c("brume").darkened(0.45), 0.5)
	return e


static func draw(ci, kind_id: String, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	match kind_id:
		"termite":
			_termite(ci, pos, r, face, t, o)
		"mandragore":
			_mandragore(ci, pos, r, face, t, o)
		"scarabee":
			_scarabee(ci, pos, r, face, t, o)
		"tertre":
			_tertre(ci, pos, r, face, t, o)


## Termite : tête aux mandibules, thorax, abdomen ovale ; six pattes qui battent vite.
static func _termite(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var sq := F._squash(o, t)
	var xf := F._xf(pos, r, face, sq)
	var body := body_color("termite")
	var leg := F._shade(body.darkened(0.35), o) if not o.get("mono", false) else Color.BLACK
	for i in 3:
		for sgn in [-1.0, 1.0]:
			var sw := sin(walk * 2.0 + i * 2.1 + (0.0 if sgn > 0 else PI)) * 0.25 * mv
			var a := xf * Vector2(0.1 - i * 0.35, 0.2 * sgn)
			var b := xf * Vector2(0.3 - i * 0.45 + sw, 0.95 * sgn)
			ci.draw_line(a, b, leg, maxf(r * 0.14, 1.0), AA)
	var abdomen := xf * Art.ellipse(Vector2(-0.75, 0.0), 0.62, 0.45, 12)
	F._fill(ci, abdomen, body.darkened(0.08), o, 0.5)
	var thorax := xf * Art.ellipse(Vector2(-0.05, 0.0), 0.32, 0.3, 10)
	F._fill(ci, thorax, body, o, 0.4)
	var head := xf * Art.ellipse(Vector2(0.5, 0.0), 0.38, 0.34, 10)
	F._fill(ci, head, body.lightened(0.04), o, 0.5)
	# Mandibules en pince, d'os.
	for sgn in [-1.0, 1.0]:
		var open := 0.1 * sin(t * 9.0)
		F._spike(ci, xf, Vector2(0.78, 0.14 * sgn), Vector2(1.0, (-0.45 + open) * sgn).normalized(), 0.42, F._bone(), o)
	if o.get("mono", false):
		return
	var ring := F._shade(body.darkened(0.4), o)
	for i in 2:
		var x := -0.55 - i * 0.32
		ci.draw_line(xf * Vector2(x, -0.36), xf * Vector2(x, 0.36), ring, maxf(r * 0.08, 1.0), AA)
	F._outline(ci, abdomen, r, o)
	F._outline(ci, head, r, o)
	for sgn in [-1, 1]:
		F._slit(ci, xf, Vector2(0.58, sgn * 0.16), 0.1, sgn, 0.45, o)


## Mandragore : une racine trapue et fourchue (deux jambes-racines), un visage fendu, une touffe de
## feuilles mortes. Sous terre : un sillon de terre et de cailloux ; pendant l'annonce, elle pointe
## hors du sol.
static func _mandragore(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var under: float = o.get("under", 0.0)
	var rising: float = o.get("rising", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var state: String = o.get("state", "")
	if under > 0.0 and not o.get("mono", false):
		_furrow(ci, pos, r, face, t, rising, o)
		if rising < 0.55:
			return
	var sq := F._squash(o, t)
	var emerge := 1.0
	if under > 0.0:
		emerge = clampf((rising - 0.55) / 0.45, 0.0, 1.0) * 0.6
	elif state == "recover":
		sq *= Vector2(1.08, 0.9)
	# Elle se tient droite, comme la souche : seuls les yeux suivent le joueur.
	var xf := Transform2D(0.0, Vector2(r * sq.x, r * sq.y), 0.0, pos + Vector2(0, r * 1.2 * (1.0 - emerge)))
	var body := body_color("mandragore")
	# Jambes-racines qui se croisent en marchant.
	if emerge >= 1.0:
		for sgn in [-1.0, 1.0]:
			var sw := sin(walk + (0.0 if sgn > 0 else PI)) * 0.18 * mv
			var leg := xf * PackedVector2Array([Vector2(0.12 * sgn, 0.25), Vector2(0.48 * sgn + sw, 0.95), Vector2(0.3 * sgn + sw, 1.0), Vector2(0.02 * sgn, 0.4)])
			F._fill(ci, leg, body.darkened(0.2), o, 0.3)
			F._outline(ci, leg, r, o)
	# Corps : un navet ridé, plus large en haut.
	var pts := xf * PackedVector2Array([Vector2(-0.45, 0.35), Vector2(-0.68, -0.15), Vector2(-0.55, -0.62), Vector2(-0.2, -0.82), Vector2(0.2, -0.82), Vector2(0.55, -0.62), Vector2(0.68, -0.15), Vector2(0.45, 0.35), Vector2(0.0, 0.5)])
	# Touffe de feuilles mortes sur la tête (derrière le corps).
	var leaf := F._shade(Art.c("decor").lerp(Art.ec("racine", "sombre"), 0.5), o) if not o.get("mono", false) else Color.BLACK
	for i in 4:
		var a := -PI / 2.0 + (i - 1.5) * 0.45 + 0.08 * sin(t * 3.0 + i)
		var base := xf * Vector2(0.0, -0.78)
		var tip := base + Vector2.from_angle(a) * r * (0.8 + 0.15 * (i % 2))
		var n := (tip - base).orthogonal().normalized() * r * 0.16
		ci.draw_colored_polygon(PackedVector2Array([base - n * 0.4, base.lerp(tip, 0.5) - n, tip, base.lerp(tip, 0.5) + n, base + n * 0.4]), leaf.darkened(0.08 * (i % 2)))
	F._fill(ci, pts, body, o, 0.6)
	if o.get("mono", false):
		return
	# Rides de la racine, radicelles.
	var grain := F._shade(body.darkened(0.35), o)
	for y in [-0.45, -0.1, 0.2]:
		ci.draw_line(xf * Vector2(-0.45, y), xf * Vector2(-0.15, y + 0.06), grain, maxf(r * 0.06, 1.0), AA)
		ci.draw_line(xf * Vector2(0.18, y + 0.04), xf * Vector2(0.48, y), grain, maxf(r * 0.06, 1.0), AA)
	F._outline(ci, pts, r, o)
	# Visage : yeux de braise, bouche ouverte en cri (plus grande pendant l'annonce et à découvert).
	var look := clampf(face.x, -1.0, 1.0) * 0.12
	var cry := 0.12 + (0.14 * rising if under > 0.0 else (0.12 if state == "recover" else 0.0))
	for sgn in [-1, 1]:
		F._slit(ci, xf, Vector2(look + sgn * 0.22, -0.42), 0.1, sgn, 0.4 + 0.5 * rising, o)
	ci.draw_colored_polygon(Art.ellipse(xf * Vector2(look, -0.08), r * 0.14, r * cry, 10), Art.c("contour"))
	if state == "recover":
		# Sonnée : trois braises tournent au-dessus de sa tête.
		for i in 3:
			var a := t * 5.0 + i * TAU / 3.0
			F._flake(ci, pos + Vector2(cos(a) * r * 0.7, -r * 1.5 + sin(a) * r * 0.25), r * 0.1, Art.ec("cendre", "clair"))


## Sillon de la mandragore sous terre : une bosse de terre qui avance, des cailloux qui roulent, une
## traînée derrière ; pendant l'annonce, la bosse se fend et la braise de ses yeux perce.
static func _furrow(ci, pos: Vector2, r: float, face: Vector2, t: float, rising: float, o: Dictionary) -> void:
	var soil := Art.c("sol_mort").lerp(Art.ec("racine", "sombre"), 0.4).lightened(0.05)
	var d := face.normalized() if face.length() > 0.01 else Vector2.RIGHT
	# Traînée derrière la bosse.
	for i in 4:
		var q := pos - d * r * (0.9 + 0.7 * i)
		ci.draw_colored_polygon(Art.ellipse(q, r * (0.55 - 0.1 * i), r * (0.28 - 0.05 * i), 10), Color(soil.darkened(0.2), 0.7 - 0.15 * i))
	var mound := Art.ellipse(pos, r * (1.0 + 0.15 * rising), r * 0.55, 14)
	F._volume(ci, mound, F._shade(soil, o), 0.5)
	# Cailloux qui roulent sur la bosse.
	for i in 4:
		var a := t * 4.0 + i * TAU / 4.0
		var q := pos + Vector2(cos(a) * r * 0.6, sin(a) * r * 0.25 - r * 0.15)
		ci.draw_circle(q, r * 0.12, Art.c("brume").darkened(0.3))
	if rising > 0.0:
		var crack := Color(Art.ec("cendre"), 0.4 + 0.5 * rising)
		ci.draw_polyline(PackedVector2Array([pos + Vector2(-r * 0.6, 0), pos + Vector2(-r * 0.15, -r * 0.18), pos + Vector2(r * 0.2, r * 0.05), pos + Vector2(r * 0.6, -r * 0.1)]), crack, maxf(r * 0.1, 1.2), AA)


## Scarabée : carapace ronde fendue au milieu, tête cornue, pattes courtes. Pendant l'annonce, la
## corne se lève et vibre ; pendant la charge, les élytres s'entrouvrent.
static func _scarabee(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var state: String = o.get("state", "")
	var k: float = o.get("k", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var sq := F._squash(o, t)
	var shake := Vector2.ZERO
	if state == "windup":
		shake = face.orthogonal() * sin(t * 55.0) * r * 0.07
	elif state == "charge":
		sq = Vector2(1.15, 0.9)
	var xf := F._xf(pos + shake, r, face, sq)
	var body := body_color("scarabee")
	if state == "recover":
		body = body.lerp(Art.c("contour"), 0.25)
	var leg := F._shade(body.darkened(0.4), o) if not o.get("mono", false) else Color.BLACK
	for i in 3:
		for sgn in [-1.0, 1.0]:
			var sw := sin(walk * 2.0 + i * 2.1 + (0.0 if sgn > 0 else PI)) * 0.16 * mv
			ci.draw_line(xf * Vector2(0.2 - i * 0.4, 0.55 * sgn), xf * Vector2(0.35 - i * 0.45 + sw, 1.05 * sgn), leg, maxf(r * 0.1, 1.0), AA)
	if state == "charge" and not o.get("mono", false):
		# Poussière soulevée derrière lui.
		for i in 4:
			var q := xf * Vector2(-1.3 - i * 0.45, (i % 2 - 0.5) * 0.7)
			ci.draw_circle(q, r * (0.3 - i * 0.05), Color(Art.c("brume").lightened(0.2), 0.4 - i * 0.08))
	# La corne en vrille (perce l'armure) : levée et plus longue pendant l'annonce et la charge.
	var horn := 0.75 + 0.3 * (k if state == "windup" else (1.0 if state == "charge" else 0.0))
	F._spike(ci, xf, Vector2(0.95, 0.0), Vector2(1.0, 0.0), horn, F._bone().lightened(0.08), o)
	if not o.get("mono", false):
		var hb := xf * Vector2(0.95, 0.0)
		var ht := xf * Vector2(0.95 + horn, 0.0)
		for j in 3:
			var u := 0.2 + 0.25 * j
			var q := hb.lerp(ht, u)
			var n := (ht - hb).orthogonal().normalized() * r * 0.12 * (1.0 - u)
			ci.draw_line(q - n, q + n * 0.4 + (ht - hb).normalized() * r * 0.08, F._shade(F._bone().darkened(0.35), o), maxf(r * 0.05, 1.0), AA)
	var head := xf * Art.ellipse(Vector2(0.78, 0.0), 0.32, 0.38, 10)
	F._fill(ci, head, body.darkened(0.15), o, 0.4)
	# Carapace : deux élytres bombées, qui s'écartent pendant la charge.
	var gap := 0.12 if state == "charge" else 0.0
	var shells: Array = []
	for sgn in [-1.0, 1.0]:
		var el := PackedVector2Array([Vector2(0.55, 0.03 * sgn + gap * sgn), Vector2(0.4, 0.55 * sgn + gap * sgn), Vector2(0.0, 0.85 * sgn + gap * sgn), Vector2(-0.55, 0.82 * sgn + gap * sgn), Vector2(-1.0, 0.45 * sgn + gap * sgn), Vector2(-1.1, 0.03 * sgn + gap * sgn)])
		var w := xf * el
		F._fill(ci, w, body, o, 0.7)
		shells.append(w)
	if o.get("mono", false):
		return
	for w in shells:
		F._outline(ci, w, r, o)
	F._outline(ci, head, r, o)
	# Stries sur les élytres, fente de braise au milieu.
	var grain := F._shade(body.lightened(0.12), o)
	for sgn in [-1.0, 1.0]:
		ci.draw_line(xf * Vector2(0.2, (0.35 + gap) * sgn), xf * Vector2(-0.8, (0.45 + gap) * sgn), grain, maxf(r * 0.05, 1.0), AA)
	F._cracks(ci, xf, [[Vector2(0.45, 0.0), Vector2(-0.3, 0.0), Vector2(-1.0, 0.0)]], r, body, 0.4 + 0.5 * k + (0.4 if state == "charge" else 0.0), t, o)
	for sgn in [-1, 1]:
		F._slit(ci, xf, Vector2(0.85, sgn * 0.2), 0.1, sgn, 0.3 + 0.5 * k, o)
	if state == "recover":
		for i in 3:
			var a := t * 5.0 + i * TAU / 3.0
			F._flake(ci, pos + Vector2(cos(a) * r * 0.7, -r * 1.2 + sin(a) * r * 0.25), r * 0.1, Art.ec("cendre", "clair"))


## Tertre : un bloc de roche trapu, épaules larges, deux poings énormes posés au sol ; une racine
## pétrifiée en travers du dos. Pendant l'annonce, il lève les poings au-dessus de sa tête.
static func _tertre(ci, pos: Vector2, r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var state: String = o.get("state", "")
	var k: float = o.get("k", 0.0)
	var sq := F._squash(o, t)
	var raise := Anim.ease_out(k) if state == "windup" else 0.0
	if state == "recover":
		sq *= Vector2(1.1, 0.9)
	var xf := Transform2D(0.0, Vector2(r * sq.x, r * sq.y), 0.0, pos)
	var body := body_color("tertre")
	# Poings : posés au sol de part et d'autre, levés pendant l'annonce.
	var fists: Array = []
	for sgn in [-1.0, 1.0]:
		var sway := sin(walk + (0.0 if sgn > 0 else PI)) * 0.08 * mv
		var c := Vector2(sgn * (1.0 - 0.45 * raise), 0.15 + sway - 1.55 * raise)
		var fist := xf * F._jag([0.42, 0.36, 0.44, 0.38, 0.42, 0.35], 0.3 * sgn)
		var moved := PackedVector2Array()
		for q in fist:
			moved.append(q + xf.basis_xform(c))
		var arm := xf * PackedVector2Array([Vector2(sgn * 0.45, -0.6), c + Vector2(-sgn * 0.15, -0.2), c + Vector2(sgn * 0.15, -0.2), Vector2(sgn * 0.75, -0.35)])
		F._fill(ci, arm, body.darkened(0.15), o, 0.3)
		fists.append(moved)
	var pts := xf * PackedVector2Array([Vector2(-0.82, 0.38), Vector2(-0.95, -0.35), Vector2(-0.62, -0.92), Vector2(-0.2, -1.12), Vector2(0.25, -1.08), Vector2(0.7, -0.88), Vector2(0.95, -0.3), Vector2(0.8, 0.38)])
	F._fill(ci, pts, body, o, 0.6)
	for w in fists:
		F._fill(ci, w, body.darkened(0.06), o, 0.6)
	if o.get("mono", false):
		return
	# Racine pétrifiée en travers du dos, et des fentes d'ocre dans la pierre.
	var root := F._shade(Art.ec("racine", "sombre").lerp(Art.c("brume"), 0.25), o)
	ci.draw_polyline(PackedVector2Array([xf * Vector2(-0.9, -0.5), xf * Vector2(-0.3, -0.95), xf * Vector2(0.4, -0.85), xf * Vector2(0.9, -0.55)]), root, maxf(r * 0.16, 2.0), AA)
	F._cracks(ci, xf, [[Vector2(-0.4, -0.5), Vector2(-0.15, -0.2), Vector2(-0.3, 0.15)], [Vector2(0.35, -0.6), Vector2(0.2, -0.25)]], r, body, 0.4 + 0.5 * k, t, o)
	F._outline(ci, pts, r, o, true)
	for w in fists:
		F._outline(ci, w, r, o, true)
	var look := clampf(face.x, -1.0, 1.0) * 0.14
	var exf := Transform2D(0.0, Vector2(r, r), 0.0, pos)
	for sgn in [-1, 1]:
		F._slit(ci, exf, Vector2(look + sgn * 0.24, -0.62), 0.11, sgn, 0.35 + 0.55 * k, o)
	if state == "recover":
		# Poussière du coup retombée autour de lui.
		for i in 5:
			var a := TAU * i / 5.0 + 0.4
			ci.draw_circle(pos + Vector2(cos(a) * r * 1.3, sin(a) * r * 0.5 + r * 0.3), r * 0.18, Color(Art.c("brume"), 0.3))
