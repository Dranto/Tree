## Porte-Graine, direction « Bestiaire d'herbier » (planche v3) : une créature-graine qui ÉVOLUE avec
## l'Arbre. Au début, une petite graine crème toute simple (pousse, pieds-racines, grands yeux ronds).
## Chaque branche prise la transforme pour de bon : silhouette, posture, visage, caractère.
##   - Ronce : farouche. Elle se ramasse vers l'avant, crinière de ronce, épines dans le dos, queue-fouet,
##     griffes, sourcils froncés, regard en fente.
##   - Sève : sereine. Elle s'allonge et décolle du sol, corps translucide au cœur lumineux, pétales en
##     ailes, yeux mi-clos, bouton de lotus qui luit, gouttes en orbite.
##   - Racine : têtue. Elle s'élargit, plaques d'écorce, mousse, bois de jeune cerf en rameaux, pattes en
##     souches, petits yeux sous une arcade d'écorce.
##   - Vent : vive. Elle s'allège, aigrette de pissenlit, plumes en oreilles et en queue, pattes fines,
##     grands yeux brillants.
## Les branches se mêlent : un build Ronce + Sève donne une créature translucide hérissée d'épines.
## Le corps reste clair (vivant) : les Flétris sont sombres.
##
## Pose : t, walk, moving, cast (ou k : lancer 0 → 1), strike, hit, look (visée),
##   voie : {branche: poids} (part de chaque branche dans le build) ou build : "ronce" | "seve" | …,
##   evol : 0 → 1 (progression sur l'Arbre) ou stade : 1 → 3.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")

## 100 unités en px du jeu (1600×900) pour une créature mûre (evol 1) : ~55 px à l'écran en 1080p.
const HEIGHT := 46.0
const BRANCHES := ["ronce", "seve", "racine", "vent"]


## Part de chaque branche × progression : la force de chaque trait.
static func traits(o: Dictionary) -> Dictionary:
	var w := {}
	if o.has("voie"):
		w = o["voie"]
	elif o.get("build", "aucun") != "aucun":
		w = {o["build"]: 1.0}
	var p: float = o.get("evol", clampf((float(o.get("stade", 3 if not w.is_empty() else 1)) - 1.0) / 2.0, 0.0, 1.0))
	var tot := 0.0
	for b in w:
		tot += float(w[b])
	var s := {"p": p}
	for b in BRANCHES:
		s[b] = (float(w.get(b, 0.0)) / tot * p) if tot > 0.0 else 0.0
	return s


static func _mix(s: Dictionary, key: String) -> Color:
	var c: Color = Art.FEUILLES_BUILD["aucun"][key]
	for b in BRANCHES:
		if s[b] > 0.0:
			c = c.lerp(Art.FEUILLES_BUILD[b][key], minf(s[b] * 1.1, 1.0))
	return c


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var cast: float = o.get("cast", o.get("k", 0.0))
	var strike: float = o.get("strike", -1.0)
	if strike >= 0.0:
		cast = maxf(cast, 1.0 - strike)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var s := traits(o)
	var sR: float = s["ronce"]
	var sS: float = s["seve"]
	var sT: float = s["racine"]
	var sV: float = s["vent"]
	var p: float = s["p"]
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	# Plus elle évolue, plus elle grandit.
	var base := Ink.frame(feet, h * (0.8 + 0.2 * p), flip)
	var u := base.get_scale().y
	var acc := _mix(s, "detail")
	var leaf := {"clair": _mix(s, "clair"), "ombre": _mix(s, "ombre"), "reflet": _mix(s, "reflet")}
	var body_c := _mix(s, "corps")
	var skin := {"clair": body_c, "ombre": body_c.darkened(0.22).lerp(Color("b49a7a"), 0.25), "reflet": Color.WHITE}
	var rootc := {"clair": Art.ec("racine"), "ombre": Art.ec("racine", "sombre"), "reflet": Art.ec("racine", "clair")}
	var bone := {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}
	# Silhouette : la Racine élargit, la Sève allonge et fait flotter, la Ronce ramasse, le Vent allège.
	var rx := 24.0 * (1.0 + 0.3 * sT + 0.1 * sR - 0.1 * sS - 0.12 * sV)
	var ry := 26.0 * (1.0 + 0.22 * sS - 0.08 * sT - 0.12 * sR - 0.05 * sV)
	var hover := 12.0 * sS + 3.0 * sV + (sin(t * 2.2) * 2.5 * (sS + sV))
	var legl := 10.0 + 6.0 * sR + 8.0 * sV - 2.0 * sT
	var c := Vector2(0, -legl - ry - hover + 4.0)
	_aura(ci, base, t, s, acc, cast)
	Ink.ground_shadow(ci, base, Vector2(0, 0), rx * (1.0 - 0.3 * sS / (1.0 + hover * 0.02)))
	var bob := -absf(sin(walk)) * 4.0 * mv + sin(t * TAU / 2.4) * 0.8
	var crouch := 0.28 * sR
	var sq := Vector2(1.0 + 0.1 * hit + 0.03 * cast, 1.0 - 0.12 * hit - 0.02 * cast)
	var xf := base * Transform2D(crouch + 0.1 * mv - 0.12 * hit, sq, 0.0, Vector2(0, -legl * 0.5)) * Transform2D(0.0, Vector2(0, legl * 0.5 + bob))
	var sw := sin(walk) * 7.0 * mv
	# --- Derrière ---
	if sR > 0.05:
		_whip(ci, xf, c + Vector2(-rx * 0.9, ry * 0.3), sR, t, mv)
	if sV > 0.05:
		for j in 3:
			var a := PI * (0.86 + j * 0.07) + 0.1 * sin(t * 3.0 + j)
			Ink.part(ci, xf, Ink.leaf(c + Vector2(-rx * 0.8, ry * 0.2), a, (12.0 + 14.0 * sV) * (1.0 - j * 0.12), 6.0, 0.05), leaf, 1.2, 1.0, 0.5)
	if sS > 0.05:
		# Pétales en ailes, translucides, qui ondulent.
		for j in 3:
			var a := -PI * (0.62 + j * 0.13) + 0.12 * sin(t * 1.8 + j)
			var l := (18.0 + 26.0 * sS) * (1.0 - j * 0.15)
			var pet := {"clair": Color(Art.ec("seve", "clair"), 0.75), "ombre": Color(Art.ec("seve"), 0.6), "reflet": Color.WHITE}
			Ink.part(ci, xf, Ink.leaf(c + Vector2(-rx * 0.3, -ry * 0.5), a, l, l * 0.42, 0.06), pet, 1.0, 1.0, 0.6)
			Ink.brush(ci, xf, PackedVector2Array([c + Vector2(-rx * 0.3, -ry * 0.5), c + Vector2(-rx * 0.3, -ry * 0.5) + Vector2.from_angle(a) * l * 0.85]), 1.0, Color(Art.ec("seve", "clair"), 0.9))
	if sR > 0.05:
		# Épines dans le dos.
		var n := 2 + roundi(4.0 * sR)
		for j in n:
			var a := -PI * (0.55 + 0.42 * j / maxf(n - 1, 1))
			var q := c + Vector2.from_angle(a) * Vector2(rx, ry) * 0.92
			Ink.part(ci, xf, Ink.thorn(q, a - 0.35, 6.0 + 12.0 * sR, 4.0 + 2.0 * sR, -0.25), bone, 1.2, 1.0, 0.0)
	if sS > 0.3:
		var tip := c + Vector2(-4.0 + sin(t * 2.0) * 3.0, ry * (1.0 + 0.45 * sS) + 10.0 * sS)
		var wisp := PackedVector2Array([c + Vector2(0, ry * 0.8), c + Vector2(2, ry * 1.1), tip])
		Ink.brush(ci, xf, wisp, 8.0 * sS + 2.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, xf, wisp, 8.0 * sS, Color(Art.ec("seve", "clair"), 0.8), 1.0, 0.0)
	# Patte du fond (la Sève, quand elle domine, n'a plus de pattes : une traîne de sève).
	if sS < 0.75:
		_leg(ci, xf, c + Vector2(rx * 0.25, ry * 0.75), Vector2(6 - sw, -legl * 0.5 - c.y - ry * 0.75), s, rootc, true, u, t)
	# --- Corps ---
	var body := _body(c, rx, ry, s)
	if sS > 0.05 and not Ink.mono:
		skin["clair"] = Color(skin["clair"], 1.0 - 0.3 * sS)
		skin["ombre"] = Color(skin["ombre"], 1.0 - 0.25 * sS)
	Ink.part(ci, xf, body, skin, 2.2, 1.0, 0.8)
	if sS > 0.05 and not Ink.mono:
		Ink.halo(ci, xf * (c + Vector2(-2, 4)), ry * 0.9 * u, Art.ec("seve"), 0.8 + 1.2 * sS)
		ci.draw_circle(xf * (c + Vector2(-2, 4)), ry * 0.18 * u, Color(Art.ec("seve", "clair"), sS))
	# Ventre plus clair.
	Ink.flat(ci, xf, Ink.oval(c + Vector2(rx * 0.25, ry * 0.35), rx * 0.48, ry * 0.42, 24), Color(body_c.lightened(0.35), 0.55))
	if sT > 0.05:
		# Plaques d'écorce et mousse.
		var bark := {"clair": Art.ec("racine").darkened(0.1), "ombre": Art.ec("racine", "sombre"), "reflet": Art.ec("racine", "clair")}
		var plates := [[-0.75, 0.0], [-0.95, 0.35], [-0.55, -0.45], [-0.25, -0.75]]
		for j in roundi(1.0 + 3.0 * sT):
			var pp: Array = plates[j]
			var q := c + Vector2(rx * pp[0], ry * pp[1])
			Ink.part(ci, xf, Ink.lumpy(q, 6.0 + 4.0 * sT, 5.0 + 3.0 * sT, 12, 0.18, 3.0, j), bark, 1.2, 1.0, 0.3)
			Ink.brush(ci, xf, PackedVector2Array([q + Vector2(-4, -1), q + Vector2(4, 1)]), 0.9, bark["ombre"])
		for j in 6:
			var q := c + Vector2.from_angle(-PI * (0.35 + j * 0.08)) * Vector2(rx, ry) * 0.98
			Ink.brush(ci, xf, PackedVector2Array([q, q + Vector2(-1.0 + sin(t * 2.0 + j), -4.0 - (j % 2) * 2.0)]), 1.8, Art.ec("racine", "clair").darkened(0.15), 1.0, 0.0)
	if sR > 0.2:
		# Crinière de ronce sur la nuque, baies.
		for j in 5:
			var a := PI * (0.78 + j * 0.11)
			Ink.part(ci, xf, Ink.leaf(c + Vector2.from_angle(a) * Vector2(rx, ry) * 0.7, a + 0.2, 9.0 + 9.0 * sR, 6.0, 0.12), leaf, 1.2, 1.0, 0.4)
		for q: Vector2 in [c + Vector2(-rx * 0.8, -ry * 0.1), c + Vector2(-rx * 0.6, ry * 0.45)]:
			Ink.part(ci, xf, Ink.lumpy(q, 3.0, 3.0, 14, 0.12, 8.0), {"clair": acc, "ombre": acc.darkened(0.45), "reflet": Color.WHITE}, 0.9, 1.0, 0.8)
	# Visage et caractère.
	_face(ci, xf, c, rx, ry, s, la, t, cast, hit, u)
	# Sommet : pousse → couronne de ronce, lotus, bois de rameaux, aigrette.
	_crest(ci, xf, c + Vector2(-rx * 0.1, -ry * 0.95), s, leaf, acc, bone, t, u)
	if sV > 0.05:
		# Plumes-oreilles.
		for sgn: float in [1.0, -1.0]:
			var q := c + Vector2(rx * (0.1 if sgn > 0 else -0.45), -ry * 0.75)
			var a := PI * 1.12 + 0.12 * sin(t * 2.6 + sgn)
			Ink.part(ci, xf, Ink.leaf(q, a - 0.15 * sgn, 12.0 + 16.0 * sV, 6.0, -0.08), leaf if sgn > 0 else {"clair": leaf["ombre"], "ombre": leaf["ombre"].darkened(0.3), "reflet": leaf["clair"]}, 1.1, 1.0, 0.5)
	# Patte de devant.
	if sS < 0.75:
		_leg(ci, xf, c + Vector2(-rx * 0.2, ry * 0.8), Vector2(-6 + sw, -legl * 0.5 - c.y - ry * 0.8), s, rootc, false, u, t)
	# Petit bras-feuille qui tient la lanterne.
	var la2 := clampf(la, -1.0, 0.9)
	var sh := c + Vector2(rx * 0.3, ry * 0.5)
	var hand := sh + Vector2.from_angle(la2 * 0.5 + 0.35) * (14.0 + 6.0 * cast + 4.0 * sR)
	_arm(ci, xf, sh, hand, s, leaf, skin)
	if sS > 0.05 and not Ink.mono:
		for j in 3:
			var a := t * 1.4 + j * TAU / 3.0
			var q := c + Vector2(cos(a) * (rx + 10.0), sin(a) * (ry * 0.5) - 6.0)
			Ink.halo(ci, xf * q, 4.0 * u, Art.ec("seve"), sS * 1.2)
			Ink.flat(ci, xf, Ink.leaf(q + Vector2(0, -2.5), PI * 0.5, 5.0, 3.6), Color(Art.ec("seve", "clair"), sS))
	_lantern(ci, base, xf, hand + Vector2.from_angle(la2) * (11.0 + 6.0 * cast) + Vector2(0, -4) + Vector2(0, sin(t * 2.6) * 1.6), look, t, cast, p, u)


## Corps : un œuf au début ; la Sève l'étire en goutte (pointe en bas), la Racine le tasse en cloche,
## la Ronce le bossue dans le dos.
static func _body(c: Vector2, rx: float, ry: float, s: Dictionary) -> PackedVector2Array:
	var sR: float = s["ronce"]
	var sS: float = s["seve"]
	var sT: float = s["racine"]
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var d := Vector2(cos(a), sin(a))
		var q := d * Vector2(rx, ry)
		if d.y > 0.0:
			q.x *= 1.0 - 0.72 * sS * pow(d.y, 1.4) + 0.16 * sT * d.y
			q.y *= 1.0 + 0.45 * sS * d.y - 0.08 * sT
		else:
			q.y *= 1.0 - 0.18 * sT
			q.x *= 1.0 + 0.08 * sT
		if d.x < 0.0 and d.y < 0.2:
			q += d * 0.22 * sR * rx * (-d.x) * (0.2 - d.y)
		q *= 1.0 + 0.035 * sT * sin(a * 9.0)
		pts.append(c + q)
	return pts


## Aura au sol : vert sève (vivant), plus large et plus vive avec la progression ; les particules
## prennent la couleur de la branche dominante.
static func _aura(ci: CanvasItem, base: Transform2D, t: float, s: Dictionary, acc: Color, cast: float) -> void:
	if Ink.mono:
		return
	var p: float = s["p"]
	var hb := 0.5 + 0.5 * sin(t * TAU / 2.4)
	var R := 44.0 + 16.0 * p
	for i in 3:
		var gr := R - i * 11.0
		Ink._poly(ci, base * Ink.oval(Vector2(0, -2), gr, gr * 0.45, 40), Color(Art.ec("seve"), 0.07 + 0.03 * hb + 0.03 * cast))
	var ring := Ink.oval(Vector2(0, -2), R * 0.92, R * 0.92 * 0.45, 48)
	ring.append(ring[0])
	ci.draw_polyline(base * ring, Color(Art.ec("seve", "clair"), 0.22 + 0.15 * hb), 1.4 * base.get_scale().y, true)
	var n := 3 + roundi(5.0 * p)
	for i in n:
		var k := fposmod(t * 0.35 + i / float(n), 1.0)
		var a := i * 2.4 + t * 0.4
		var q := base * Vector2(cos(a) * R * 0.7, -2 + sin(a) * R * 0.3 - k * 60.0)
		var col := Art.ec("seve", "clair").lerp(acc, minf(p, 0.8))
		ci.draw_circle(q, 2.0 * base.get_scale().y * (1.0 - 0.5 * k), Color(col, 0.85 * sin(PI * k)))


## Bras : petite feuille au début ; griffe d'épines (Ronce), poing de bois (Racine), pétale (Sève),
## aile-plume (Vent).
static func _arm(ci: CanvasItem, xf: Transform2D, sh: Vector2, hand: Vector2, s: Dictionary, leaf: Dictionary, skin: Dictionary) -> void:
	var sR: float = s["ronce"]
	var sT: float = s["racine"]
	var w := 4.5 + 4.0 * sT + 1.5 * sR
	var pts := PackedVector2Array([sh, sh.lerp(hand, 0.5) + Vector2(2, 2), hand])
	Ink.brush(ci, xf, pts, w + 2.4, Ink.encre(), 1.0, 0.6)
	Ink.brush(ci, xf, pts, w, skin["ombre"].lerp(skin["clair"], 0.5), 1.0, 0.6)
	var d := (hand - sh).angle()
	if sT > 0.3:
		Ink.part(ci, xf, Ink.lumpy(hand, 4.0 + 3.0 * sT, 3.6 + 2.0 * sT, 12, 0.15, 3.0), {"clair": Art.ec("racine"), "ombre": Art.ec("racine", "sombre"), "reflet": Art.ec("racine", "clair")}, 1.2, 1.0, 0.3)
	else:
		Ink.part(ci, xf, Ink.leaf(hand - Vector2.from_angle(d) * 2.0, d + 0.3, 7.0 + 3.0 * s["vent"] + 2.0 * s["seve"], 4.4), leaf, 1.1, 1.0, 0.5)
	if sR > 0.3:
		for j in 3:
			Ink.part(ci, xf, Ink.thorn(hand + Vector2.from_angle(d + PI * 0.5) * (j - 1) * 1.8, d + (j - 1) * 0.35, 3.0 + 3.0 * sR, 1.5, 0.3), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.7, 1.0, 0.0)


## Queue-fouet de ronce, épineuse, qui fouette doucement.
static func _whip(ci: CanvasItem, xf: Transform2D, b: Vector2, sR: float, t: float, mv: float) -> void:
	var pts := PackedVector2Array()
	var l := 16.0 + 26.0 * sR
	for i in 10:
		var k := i / 9.0
		pts.append(b + Vector2(-l * k, -sin(k * PI * 1.2 + t * 3.0 + mv) * 6.0 * k - 8.0 * k * k))
	Ink.brush(ci, xf, pts, 5.2, Ink.encre(), 1.0, 0.0)
	Ink.brush(ci, xf, pts, 3.2, Art.FEUILLES_BUILD["ronce"]["ombre"].lightened(0.15), 1.0, 0.0)
	for i in [3, 5, 7]:
		var q: Vector2 = pts[i]
		var d: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
		Ink.part(ci, xf, Ink.thorn(q, d.angle() - PI * 0.6, 4.0 + 2.0 * sR, 2.0), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.8, 1.0, 0.0)


## Patte : de la hanche h (repère du corps) jusqu'au sol. Griffue (Ronce), souche (Racine), fine (Vent),
## pendante quand elle flotte (Sève).
static func _leg(ci: CanvasItem, xf: Transform2D, hip: Vector2, off: Vector2, s: Dictionary, rootc: Dictionary, far: bool, u: float, t: float) -> void:
	var sR: float = s["ronce"]
	var sS: float = s["seve"]
	var sT: float = s["racine"]
	var sV: float = s["vent"]
	var foot := hip + off * (1.0 - 0.6 * sS) + Vector2(0, -sin(t * 2.2 + (1.0 if far else 0.0)) * 2.0 * sS)
	var knee := hip.lerp(foot, 0.5) + Vector2(-5.0 * sR - 2.0 * sV, -2.0 * sR)
	var w := 6.0 + 7.0 * sT - 2.5 * sV - 2.0 * sS
	var col: Color = rootc["ombre"] if far else rootc["clair"].darkened(0.1)
	var pts := PackedVector2Array([hip, knee, foot])
	Ink.brush(ci, xf, pts, w + 2.4, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, pts, w, col, 1.0, 1.0)
	var fp := rootc.duplicate()
	if far:
		fp["clair"] = rootc["ombre"].lightened(0.15)
	Ink.part(ci, xf, Ink.lumpy(foot + Vector2(1.5, 0), 5.0 + 3.0 * sT, 3.4 + 1.0 * sT, 14, 0.1, 3.0), fp, 1.3, 1.0, 0.3)
	if sR > 0.2:
		for j in 3:
			Ink.part(ci, xf, Ink.thorn(foot + Vector2(4.5, -1.0 + j * 1.2), 0.25 * (j - 1), 3.0 + 2.0 * sR, 1.6), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.7, 1.0, 0.0)
	if sT > 0.2:
		for j in 2:
			Ink.brush(ci, xf, PackedVector2Array([foot + Vector2(-3 + j * 7, 2), foot + Vector2(-6 + j * 13, 4.5)]), 1.6, rootc["ombre"], 1.0, 0.0)


## Visage : grands yeux ronds au début ; la branche dominante donne le caractère.
static func _face(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float, ry: float, s: Dictionary, la: float, t: float, cast: float, hit: float, u: float) -> void:
	var sR: float = s["ronce"]
	var sS: float = s["seve"]
	var sT: float = s["racine"]
	var sV: float = s["vent"]
	var gaze := Vector2.from_angle(clampf(la, -1.0, 1.0)) * 1.2
	var e1 := c + Vector2(rx * 0.38, -ry * 0.2)
	var e2 := c + Vector2(rx * 0.82, -ry * 0.22)
	var size := 1.0 + 0.35 * sV - 0.3 * sT - 0.1 * sR
	var closed := hit > 0.3 or (cast == 0.0 and Ink.blink(t, 0.7) > 0.0)
	var serene := sS > 0.45 and sS >= maxf(sR, maxf(sT, sV)) and cast < 0.3
	if closed or serene:
		# Yeux fermés (coup) ou mi-clos, sereins (Sève) : deux arcs.
		for q: Vector2 in [e1, e2]:
			var wv := 4.4 if q == e1 else 3.0
			var arc := PackedVector2Array([q + Vector2(-wv, 0), q + Vector2(0, 1.8 if serene and not closed else -0.6), q + Vector2(wv, 0)])
			Ink.brush(ci, xf, arc, 1.8, Ink.encre(), 0.3, 0.3)
	else:
		for q: Vector2 in [e1, e2]:
			var far := q == e2
			var ew := (4.2 if not far else 2.8) * size
			var eh := (5.0 if not far else 4.4) * size * (1.0 - 0.35 * sR)
			Ink.flat(ci, xf, Ink.oval(q, ew, eh, 18), Color("fbf6e8"), 1.0)
			if Ink.mono:
				continue
			ci.draw_circle(xf * (q + gaze + Vector2(ew * 0.2, 0.3)), eh * 0.62 * u, Ink.shade(Art.ec("seve").lerp(Art.ec("seve", "sombre"), 0.3 * sT)))
			if sR > 0.3:
				# Pupille en fente.
				Ink.flat(ci, xf, Ink.leaf(q + gaze + Vector2(ew * 0.25, -eh * 0.5), PI * 0.5, eh, 1.6), Ink.encre())
			else:
				ci.draw_circle(xf * (q + gaze + Vector2(ew * 0.25, 0.4)), eh * 0.36 * u, Ink.encre())
			ci.draw_circle(xf * (q + gaze + Vector2(-ew * 0.15, -eh * 0.35)), eh * 0.22 * u, Color.WHITE)
			if sV > 0.3:
				ci.draw_circle(xf * (q + gaze + Vector2(ew * 0.35, eh * 0.25)), eh * 0.12 * u, Color.WHITE)
	# Sourcils : froncés (Ronce), arcade d'écorce (Racine).
	if sR > 0.1:
		for q: Vector2 in [e1, e2]:
			var wv := 5.0 if q == e1 else 3.4
			Ink.brush(ci, xf, PackedVector2Array([q + Vector2(-wv, -6.5 - 1.5 * sR), q + Vector2(wv * 0.9, -4.2)]), 1.4 + 1.4 * sR, Ink.encre(), 0.5, 0.2)
	if sT > 0.1:
		Ink.part(ci, xf, PackedVector2Array([e1 + Vector2(-7, -5), e2 + Vector2(5, -6.5), e2 + Vector2(4, -3.5), e1 + Vector2(-6, -2.5)]), {"clair": Art.ec("racine"), "ombre": Art.ec("racine", "sombre")}, 1.1 * sT, 1.0, 0.0)
	# Bouche : sourire (début, Sève, Vent), crocs (Ronce), trait têtu (Racine).
	var m := c + Vector2(rx * 0.62, ry * 0.18)
	if sR > 0.3:
		# Museau de bête qui pousse, crocs d'épine.
		var mz := c + Vector2(rx * 0.82 + 3.0 * sR, ry * 0.2)
		var sk := {"clair": _mix(s, "corps"), "ombre": _mix(s, "corps").darkened(0.25)}
		Ink.part(ci, xf, Ink.oval(mz, 5.0 + 6.0 * sR, 4.0 + 3.0 * sR, 20, -0.15), sk, 1.6, 1.0, 0.6)
		ci.draw_circle(xf * (mz + Vector2(4.0 + 5.0 * sR, -2.0)), 1.6 * u, Ink.encre())
		var jaw := PackedVector2Array([mz + Vector2(-4, 3.0 + 1.5 * sR), mz + Vector2(4.0 + 4.0 * sR, 2.0 + sR)])
		Ink.brush(ci, xf, jaw, 1.4, Ink.encre())
		for fx: float in [-1.0, 3.0 + 2.0 * sR]:
			Ink.flat(ci, xf, PackedVector2Array([mz + Vector2(fx - 1.2, 2.6 + sR), mz + Vector2(fx, 6.0 + 3.0 * sR), mz + Vector2(fx + 1.2, 2.4 + sR)]), Art.bc("os"), 0.7)
	elif sR > 0.35:
		Ink.brush(ci, xf, PackedVector2Array([m + Vector2(-4, 0), m + Vector2(0, 1.2), m + Vector2(4, 0)]), 1.3, Ink.encre())
		Ink.flat(ci, xf, PackedVector2Array([m + Vector2(-2, 0.4), m + Vector2(-1, 3), m + Vector2(0, 0.6)]), Color.WHITE, 0.6)
	elif sT > 0.35:
		Ink.brush(ci, xf, PackedVector2Array([m + Vector2(-4, 1.5), m + Vector2(4, 1.5)]), 1.6, Ink.encre())
		# Défenses de racine qui sortent de la mâchoire.
		for dx: float in [-4.0, 4.0]:
			var tk := PackedVector2Array([m + Vector2(dx, 2), m + Vector2(dx * 1.4 + 1.0, 6.0), m + Vector2(dx * 1.6 + 3.0, -2.0 - 4.0 * sT)])
			Ink.brush(ci, xf, tk, 3.6 * sT + 1.6, Ink.encre(), 1.0, 0.0)
			Ink.brush(ci, xf, tk, 3.6 * sT, Art.bc("os").darkened(0.08), 1.0, 0.0)
	else:
		Ink.brush(ci, xf, PackedVector2Array([m + Vector2(-3, -0.5), m + Vector2(0, 1.6 + sV), m + Vector2(3, -0.5)]), 1.3, Ink.encre())
	if not Ink.mono:
		ci.draw_circle(xf * (e1 + Vector2(-3, 7)), 2.6 * u, Color(Art.ec("saignement", "clair"), 0.18))


## Sommet de la tête : la pousse du début, transformée par les branches.
static func _crest(ci: CanvasItem, xf: Transform2D, top: Vector2, s: Dictionary, leaf: Dictionary, acc: Color, bone: Dictionary, t: float, u: float) -> void:
	var sR: float = s["ronce"]
	var sS: float = s["seve"]
	var sT: float = s["racine"]
	var sV: float = s["vent"]
	var sway := 0.1 * sin(t * 1.8)
	# Pousse commune (elle s'efface quand une autre forme prend sa place).
	var keep := 1.0 - minf(1.0, 1.3 * maxf(maxf(sS, sT), sV))
	if keep > 0.05:
		Ink.brush(ci, xf, PackedVector2Array([top + Vector2(0, 3), top + Vector2(-1, -3), top + Vector2(1, -7)]), 2.4, leaf["ombre"], 1.0, 0.4)
		var tip := top + Vector2(1, -7)
		Ink.part(ci, xf, Ink.leaf(tip, -2.5 + sway, 9.0 * keep, 5.0 * keep), leaf, 1.1, 1.0, 0.5)
		Ink.part(ci, xf, Ink.leaf(tip, -0.6 + sway, 8.0 * keep, 4.6 * keep), leaf, 1.1, 1.0, 0.5)
	if sR > 0.1:
		for j in 3:
			var a := -PI * (0.75 - j * 0.25) + sway * 0.5
			Ink.part(ci, xf, Ink.thorn(top + Vector2(j * 3.0 - 3.0, 2), a, 5.0 + 8.0 * sR, 2.6, 0.1), bone, 0.9, 1.0, 0.0)
	if sT > 0.1:
		# Bois de rameaux, avec de petites feuilles.
		for sgn: float in [-1.0, 1.0]:
			var b := top + Vector2(sgn * 4.0, 2)
			var l := 8.0 + 12.0 * sT
			var tip := b + Vector2(sgn * l * 0.45, -l)
			var mid := b.lerp(tip, 0.55)
			Ink.brush(ci, xf, PackedVector2Array([b, mid, tip]), 4.0, Ink.encre(), 1.0, 0.2)
			Ink.brush(ci, xf, PackedVector2Array([b, mid, tip]), 2.4, Art.ec("racine"), 1.0, 0.2)
			var br := mid + Vector2(sgn * l * 0.35, -l * 0.15)
			Ink.brush(ci, xf, PackedVector2Array([mid, br]), 3.0, Ink.encre(), 1.0, 0.2)
			Ink.brush(ci, xf, PackedVector2Array([mid, br]), 1.6, Art.ec("racine"), 1.0, 0.2)
			Ink.part(ci, xf, Ink.leaf(tip, -PI * 0.5 + sgn * 0.6 + sway, 5.0 + 3.0 * sT, 3.2), leaf, 0.8, 1.0, 0.4)
	if sS > 0.1:
		# Bouton de lotus qui luit.
		var b := top + Vector2(0, -2)
		if not Ink.mono:
			Ink.halo(ci, xf * (b + Vector2(0, -6)), (8.0 + 8.0 * sS) * u, Art.ec("seve"), 1.0 + sS)
		for j in 5:
			var a := -PI * 0.5 + (j - 2) * 0.42
			var pet := {"clair": Art.ec("seve", "clair"), "ombre": Art.ec("seve"), "reflet": Color.WHITE}
			Ink.part(ci, xf, Ink.leaf(b, a, (6.0 + 8.0 * sS) * (1.0 - absf(j - 2) * 0.15), 4.6, 0.0), pet, 0.9, 1.0, 0.6)
	if sV > 0.1:
		# Aigrette de pissenlit : des rayons et leurs plumets.
		var b0 := top + Vector2(-1, 0)
		var b := b0 + Vector2(-2.0 + 2.0 * sin(t * 1.6), -6.0 - 10.0 * sV)
		Ink.brush(ci, xf, PackedVector2Array([b0, b0.lerp(b, 0.5) + Vector2(1.5, 0), b]), 1.6, leaf["ombre"], 1.0, 0.6)
		var R := 6.0 + 9.0 * sV
		for j in 22:
			var a := TAU * j / 22.0 + 0.06 * sin(t * 2.0 + j)
			var q := b + Vector2.from_angle(a) * R
			Ink.brush(ci, xf, PackedVector2Array([b + Vector2.from_angle(a) * R * 0.3, q]), 0.6, Color(Art.FEUILLES_BUILD["vent"]["ombre"].lightened(0.45), 0.8))
			if not Ink.mono:
				ci.draw_circle(xf * q, 1.9 * u, Color(Art.FEUILLES_BUILD["vent"]["reflet"], 0.95))
		Ink.flat(ci, xf, Ink.oval(b, 2.4, 2.0, 10), Art.FEUILLES_BUILD["vent"]["detail"].darkened(0.3), 0.8)


## Graine-lanterne et ses lucioles ; plus vive avec la progression et pendant un lancer.
static func _lantern(ci: CanvasItem, base: Transform2D, xf: Transform2D, lp: Vector2, look: float, t: float, cast: float, p: float, u: float) -> void:
	var lw := xf * lp
	if not Ink.mono:
		Ink.halo(ci, lw, (12.0 + 4.0 * p + 10.0 * cast) * u, Art.ec("seve"), 1.4 + 0.6 * p + cast)
		for i in 3:
			var m := lw + Vector2.from_angle(t * 2.6 + i * TAU / 3.0) * 8.0 * u
			ci.draw_circle(m, 0.9 * u, Color(Art.ec("seve", "clair"), 0.5 + 0.4 * sin(t * 4.0 + i * 2.0)))
	var seedx := Transform2D(0.0, base.get_scale(), 0.0, lw)
	Ink.part(ci, seedx, Ink.oval(Vector2.ZERO, 4.6, 3.8, 16), {"clair": Art.ec("seve", "sombre").lightened(0.35), "ombre": Art.ec("seve", "sombre"), "reflet": Art.ec("seve", "clair")}, 1.3)
	if not Ink.mono:
		ci.draw_circle(lw + Vector2(-0.6, -0.6) * u, 2.0 * u, Art.ec("seve", "clair"))
		if cast > 0.0:
			for i in 5:
				var a := look + (i - 2) * 0.35
				ci.draw_line(lw + Vector2.from_angle(a) * 7.0 * u, lw + Vector2.from_angle(a) * (11.0 + 8.0 * cast) * u, Color(Art.ec("seve", "clair"), 0.85 * cast), 1.4 * u, true)
