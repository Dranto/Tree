## Porte-Graine, direction « Bestiaire d'herbier » (planche v2) : une petite créature-graine vêtue en
## ninja de feuillage, vue de trois quarts. Capuche et masque de feuilles qui ne laissent voir que les yeux,
## bandeau noué dont les pans flottent, écharpe, tunique ceinturée, jambes bandées, pieds-racines, et
## devant la main la graine-lanterne qui suit la visée.
##
## La tenue change au fil du parcours sur l'Arbre :
##   - la couleur des feuilles et du bandeau suit la branche dominante du build (Art.FEUILLES_BUILD) ;
##   - le stade (1 → 3) suit la progression : 1 tenue simple, 2 épaulière de feuilles, écharpe plus longue,
##     ceinture à graines, 3 cape de feuilles, couronne et mutation de la branche (Ronce : épines, ronce
##     qui s'enroule au bras, baies ; Sève : veines lumineuses, gouttes en orbite) ; l'aura grandit.
##
## Pose : t, walk, moving, cast (ou k : lancer 0 → 1), strike (0 → 1 après le tir), hit, look (visée),
##        build ("aucun", "ronce", "seve"), stade (1, 2, 3).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")

## 100 unités en px du jeu (1600×900) : ~55 px de haut à l'écran en 1080p (34 px aujourd'hui).
const HEIGHT := 46.0


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
	var build: String = o.get("build", "aucun")
	var stade: int = o.get("stade", 3 if build != "aucun" else 1)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	var lv: Dictionary = Art.FEUILLES_BUILD.get(build, Art.FEUILLES_BUILD["aucun"])
	var acc: Color = lv["detail"]
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	var u := h / 100.0
	_aura(ci, base, t, stade, build, acc, cast)
	Ink.ground_shadow(ci, base, Vector2(0, 0), 24.0)
	var bob := -absf(sin(walk)) * 4.0 * mv + sin(t * TAU / 2.4) * 0.7
	var sq := Vector2(1.0 + 0.1 * hit + 0.03 * cast, 1.0 - 0.12 * hit - 0.02 * cast)
	var lean := 0.12 * mv - 0.12 * hit + 0.05 * cast
	var xf := base * Transform2D(lean, sq, 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2(0, bob))
	var leaf := {"clair": lv["clair"], "ombre": lv["ombre"], "reflet": lv["reflet"]}
	# Tenue sombre d'écorce (le vert reste à la capuche, aux feuilles et à l'aura) : la tête ressort.
	var cloth := {"clair": Color("5c4a3a").lerp(lv["ombre"], 0.25), "ombre": Color("33281f").lerp(lv["ombre"], 0.15), "reflet": Color("8a7660")}
	var band := {"clair": acc, "ombre": acc.darkened(0.4), "reflet": acc.lightened(0.5)}
	var cream := {"clair": Art.c("joueur"), "ombre": Art.c("joueur").darkened(0.2).lerp(Color("b49a7a"), 0.3), "reflet": Color.WHITE}
	var rootc := {"clair": Art.ec("racine"), "ombre": Art.ec("racine", "sombre"), "reflet": Art.ec("racine", "clair")}
	var wind := 0.6 + 0.8 * mv
	# --- Derrière ---
	# Cape de feuilles (stade 3) : cinq feuilles en écailles, du dos jusqu'au sol.
	if stade >= 3:
		for i in 5:
			var a := PI * (0.55 + i * 0.075) + 0.05 * sin(t * 2.2 + i) + 0.12 * mv * sin(walk * 2.0 + i)
			var b := Vector2(-6, -46 + i * 2.0)
			var l := 38.0 + i * 2.0 - absf(i - 2.0) * 3.0
			Ink.part(ci, xf, Ink.leaf(b, a, l, 17.0, 0.04), cloth if i % 2 else leaf, 1.6, 1.0, 0.4)
			Ink.brush(ci, xf, PackedVector2Array([b, b + Vector2.from_angle(a) * l * 0.85]), 1.0, lv["ombre"].darkened(0.35))
			if build == "seve":
				Ink.brush(ci, xf, PackedVector2Array([b + Vector2.from_angle(a) * 5.0, b + Vector2.from_angle(a) * l * 0.75]), 0.8, acc)
	# Pans du bandeau, noués derrière la tête, et écharpe : ils flottent au vent de la course.
	_ribbon(ci, xf, Vector2(-17, -73), 16.0 + 6.0 * stade, 4.2, t, wind, 0.0, band)
	_ribbon(ci, xf, Vector2(-17, -71), 13.0 + 5.0 * stade, 3.4, t, wind, 1.7, band)
	_ribbon(ci, xf, Vector2(-8, -48), 14.0 + 8.0 * stade, 6.0, t * 0.9, wind, 0.8, cloth)
	# Bras du fond (tenu en garde, derrière le corps).
	var sw := sin(walk) * 7.0 * mv
	_limb(ci, xf, Vector2(6, -42), Vector2(-4 - sw * 0.5, -32), 5.0, lv["ombre"].darkened(0.35))
	# Jambes bandées et pieds-racines (celle du fond plus sombre).
	_leg(ci, base, xf * Vector2(4, -24), Vector2(8 - sw, -maxf(-sin(walk), 0.0) * 5.0 * mv), cloth["ombre"].darkened(0.2), rootc, true)
	_leg(ci, base, xf * Vector2(-4, -24), Vector2(-7 + sw, -maxf(sin(walk), 0.0) * 5.0 * mv), cloth["ombre"], rootc, false)
	# --- Corps ---
	var torso := PackedVector2Array([Vector2(-12, -47), Vector2(-3, -50), Vector2(9, -49), Vector2(14, -40), Vector2(13, -26), Vector2(4, -21), Vector2(-9, -22), Vector2(-14, -31)])
	Ink.part(ci, xf, torso, cloth, 2.0, 1.0, 0.5)
	# Écharpe croisée sur la poitrine.
	Ink.part(ci, xf, PackedVector2Array([Vector2(-10, -47), Vector2(-3, -49), Vector2(12, -30), Vector2(7, -27)]), band, 1.2, 1.0, 0.4)
	# Ceinture de racine, nœud ; graines à la ceinture dès le stade 2.
	Ink.part(ci, xf, PackedVector2Array([Vector2(-14, -31), Vector2(13, -29), Vector2(13, -25), Vector2(-13, -26)]), rootc, 1.2, 1.0, 0.0)
	Ink.part(ci, xf, Ink.oval(Vector2(-6, -28), 2.6, 2.4, 10), rootc, 0.9)
	if stade >= 2:
		for j in 2:
			var sp := Vector2(2 + j * 7, -24 + j * 0.5)
			var seed_pal := {"clair": Art.ec("seve", "sombre").lightened(0.3), "ombre": Art.ec("seve", "sombre"), "reflet": Art.ec("seve", "clair")}
			if build == "ronce" and stade >= 3:
				seed_pal = {"clair": acc, "ombre": acc.darkened(0.45), "reflet": Color.WHITE}
			Ink.part(ci, xf, Ink.oval(sp, 2.6, 3.2, 12), seed_pal, 0.9, 1.0, 0.8)
	# Tête : la graine, cachée sous la capuche-masque de feuilles ; seule la bande des yeux reste nue.
	var hc := Vector2(3, -67)
	var head := Ink.oval(hc, 20.0, 19.0, 40)
	Ink.part(ci, xf, head, leaf, 2.2, 1.0, 0.7)
	# Nervures de la capuche (du sommet vers la nuque).
	for j in 4:
		var a := -PI * (0.62 + j * 0.13)
		Ink.brush(ci, xf, PackedVector2Array([hc + Vector2.from_angle(a) * 8.0, hc + Vector2.from_angle(a + 0.25) * 18.0]), 1.0, lv["ombre"].darkened(0.25))
	# Pointe de la capuche, vers l'arrière.
	Ink.part(ci, xf, Ink.leaf(hc + Vector2(-14, -10), PI * 1.1 + 0.08 * sin(t * 2.0) * wind, 11.0 + stade * 2.0, 8.0, -0.1), leaf, 1.4, 1.0, 0.5)
	# Bande des yeux : la peau de la graine, crème.
	# Fente en amande, plus haute au centre du visage, effilée vers la nuque et vers l'avant.
	var win := PackedVector2Array()
	for j in 15:
		var s01 := j / 14.0
		var x := lerpf(-6.0, 27.0, s01)
		win.append(Vector2(x, -67.5 - 7.5 * pow(sin(s01 * PI), 0.7) - 0.05 * x))
	for j in range(14, -1, -1):
		var s01 := j / 14.0
		var x := lerpf(-6.0, 27.0, s01)
		win.append(Vector2(x, -67.0 + 5.5 * pow(sin(s01 * PI), 0.7) - 0.03 * x))
	for poly in Geometry2D.intersect_polygons(xf * win, xf * Ink.oval(hc, 19.0, 18.0, 40)):
		Ink.fill_world(ci, poly, cream, 1.0, 0.6)
	# Bandeau sur le front, au-dessus des yeux.
	var bnd := PackedVector2Array()
	for j in 11:
		var x := lerpf(-17.0, 22.0, j / 10.0)
		bnd.append(Vector2(x, -77.5 + 0.0018 * (x - 4.0) * (x - 4.0) * 4.0 - 0.05 * x))
	Ink.brush(ci, xf, bnd, 6.2, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, bnd, 4.4, band["clair"], 1.0, 1.0)
	Ink.brush(ci, xf, bnd, 1.2, band["reflet"], 0.6, 0.6)
	# Plaque du bandeau : une graine gravée.
	Ink.part(ci, xf, Ink.oval(Vector2(15, -77.8), 3.2, 2.6, 12), {"clair": Art.c("or"), "ombre": Art.c("or").darkened(0.4), "reflet": Color.WHITE}, 0.9, 1.0, 0.8)
	# Yeux : en amande, regard vers la visée, iris de sève ; plissés sous le coup, clignent au repos.
	var gaze := Vector2.from_angle(clampf(la, -1.0, 1.0)) * 1.2
	if hit > 0.3 or (cast == 0.0 and Ink.blink(t, 0.7) > 0.0):
		Ink.brush(ci, xf, PackedVector2Array([Vector2(5, -66), Vector2(9, -65), Vector2(13, -66.5)]), 1.8, Ink.encre())
		Ink.brush(ci, xf, PackedVector2Array([Vector2(18, -66.5), Vector2(22.5, -66.5)]), 1.5, Ink.encre())
	else:
		_eye(ci, xf, Vector2(9, -66.5) + gaze, 4.6, 3.4, -0.12, u, stade, build)
		_eye(ci, xf, Vector2(20.5, -67) + gaze, 2.9, 3.0, -0.2, u, stade, build)
	# Pousse au sommet : grandit avec le stade ; couronne de ronce ou bourgeon de sève au stade 3.
	_crown(ci, xf, hc + Vector2(-3, -18), t, stade, build, lv, u)
	# Épaulière de feuilles (stade 2 et plus), épines de ronce ou veines de sève au stade 3.
	if stade >= 2:
		for j in 3:
			var a := PI * (0.42 + j * 0.13)
			var sb := Vector2(-4, -46)
			Ink.part(ci, xf, Ink.leaf(sb, a, 15.0 - j * 2.0, 10.0, 0.08), leaf if j != 1 else cloth, 1.4, 1.0, 0.6)
			if stade >= 3 and build == "ronce":
				var tq := sb + Vector2.from_angle(a) * (9.0 - j)
				Ink.part(ci, xf, Ink.thorn(tq, a - PI * 0.5, 6.0, 2.6, -0.2), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.9, 1.0, 0.0)
	# Bras de devant : la main tendue vers la lanterne, plus loin pendant un lancer.
	var la2 := clampf(la, -1.0, 0.9)
	var reach := 9.0 + 9.0 * cast
	var hand := Vector2(4, -41) + Vector2.from_angle(la2 * 0.7 + 0.5 - 0.5 * cast) * reach + Vector2(sw * 0.4, 0)
	_limb(ci, xf, Vector2(-1, -42), hand, 5.6, cloth["ombre"])
	if stade >= 3 and build == "ronce":
		# La ronce qui s'enroule autour du bras.
		var vine := PackedVector2Array()
		for j in 9:
			var q := Vector2(-1, -42).lerp(hand, j / 8.0)
			vine.append(q + (hand - Vector2(-1, -42)).orthogonal().normalized() * sin(j * 1.9) * 2.6)
		Ink.brush(ci, xf, vine, 1.4, Art.bc("ronce", "detail").darkened(0.2))
		Ink.part(ci, xf, Ink.thorn(vine[4], -PI * 0.5, 3.6, 1.6), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.7, 1.0, 0.0)
	Ink.part(ci, xf, Ink.oval(hand, 3.4, 3.2, 12), cream, 1.4, 1.0, 0.5)
	if stade >= 3 and build == "seve":
		# Veines de sève qui luisent sur la tunique et la capuche.
		for v: PackedVector2Array in [PackedVector2Array([Vector2(-8, -42), Vector2(-4, -35), Vector2(2, -33)]), PackedVector2Array([Vector2(-12, -70), Vector2(-14, -62), Vector2(-10, -54)])]:
			Ink.brush(ci, xf, v, 1.4, acc)
			if not Ink.mono:
				Ink.halo(ci, xf * v[1], 5.0 * u, Art.ec("seve"), 0.8 + 0.4 * sin(t * 3.0))
	# Graine-lanterne : flotte devant la main, dans l'axe de la visée.
	_lantern(ci, base, xf, hand + Vector2.from_angle(la2) * (12.0 + 6.0 * cast) + Vector2(0, sin(t * 2.6) * 1.6), look, t, cast, stade, u)


## Aura au sol (vert sève : il est vivant) ; elle grandit avec le stade, et porte les braises de la
## branche : pétales rouges pour la Ronce, gouttes de sève pour la Sève.
static func _aura(ci: CanvasItem, base: Transform2D, t: float, stade: int, build: String, acc: Color, cast: float) -> void:
	if Ink.mono:
		return
	var hb := 0.5 + 0.5 * sin(t * TAU / 2.4)
	var R := 70.0 + 10.0 * stade
	for i in 4:
		var gr := R - i * 14.0
		Ink._poly(ci, base * Ink.oval(Vector2(0, -2), gr, gr * 0.45, 40), Color(Art.ec("seve"), 0.07 + 0.03 * hb + 0.03 * cast))
	var ring := Ink.oval(Vector2(0, -2), R * 0.92, R * 0.92 * 0.45, 48)
	ring.append(ring[0])
	ci.draw_polyline(base * ring, Color(Art.ec("seve", "clair"), 0.25 + 0.15 * hb), 1.4 * base.get_scale().y, true)
	var n := 2 + 2 * stade
	for i in n:
		var k := fposmod(t * 0.35 + i / float(n), 1.0)
		var a := i * 2.4 + t * 0.4
		var q := base * Vector2(cos(a) * R * 0.7, -2 + sin(a) * R * 0.3 - k * 60.0)
		var col := Art.ec("seve", "clair") if build != "ronce" else acc
		ci.draw_circle(q, (1.6 + 0.4 * stade) * base.get_scale().y * (1.0 - 0.5 * k), Color(col, 0.85 * sin(PI * k)))


## Pan d'étoffe (ou de feuille) qui ondule : de b vers l'arrière, longueur l, largeur w.
static func _ribbon(ci: CanvasItem, xf: Transform2D, b: Vector2, l: float, w: float, t: float, wind: float, ph: float, pal: Dictionary) -> void:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 12:
		var s := i / 11.0
		var c := b + Vector2(-l * s, 0.35 * l * s * s / wind + sin(t * 6.0 + ph - s * 4.0) * 3.0 * s * wind)
		var ww := w * (1.0 - 0.55 * s)
		top.append(c + Vector2(0, -ww * 0.5))
		bot.append(c + Vector2(0, ww * 0.5))
	# Pointe en queue d'aronde.
	var tip := b + Vector2(-l * 1.08, 0.35 * l / wind + sin(t * 6.0 + ph - 4.0) * 3.0 * wind)
	bot.reverse()
	top.append(tip)
	top.append_array(bot)
	Ink.part(ci, xf, top, pal, 1.3, 1.0, 0.3)


## Membre (bras) : un trait épais encré, de a vers b.
static func _limb(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var m := a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * 1.5
	var pts := PackedVector2Array([a, m, b])
	Ink.brush(ci, xf, pts, w + 2.2, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, pts, w, col, 1.0, 1.0)


## Jambe bandée et pied-racine.
static func _leg(ci: CanvasItem, base: Transform2D, hip_w: Vector2, foot: Vector2, col: Color, rootc: Dictionary, far: bool) -> void:
	var hip := base.affine_inverse() * hip_w
	var knee := hip.lerp(foot, 0.5) + Vector2(1.5, -1)
	var pts := PackedVector2Array([hip, knee, foot + Vector2(0, -3)])
	Ink.brush(ci, base, pts, 8.4, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, base, pts, 6.2, col, 1.0, 1.0)
	# Bandes croisées.
	for j in 3:
		var q := hip.lerp(foot, 0.25 + j * 0.22)
		Ink.brush(ci, base, PackedVector2Array([q + Vector2(-3, 1), q + Vector2(3, -1)]), 0.9, col.lightened(0.3))
	var fp := rootc.duplicate()
	if far:
		fp["clair"] = rootc["ombre"].lightened(0.15)
	Ink.part(ci, base, Ink.lumpy(foot + Vector2(1.5, -2.5), 6.5, 4.0, 16, 0.08, 3.0), fp, 1.4, 1.0, 0.3)
	# Radicelles.
	Ink.brush(ci, base, PackedVector2Array([foot + Vector2(6, -1.5), foot + Vector2(9.5, 0.5)]), 1.2, rootc["ombre"], 1.0, 0.0)


## Œil en amande : blanc, iris de sève, pupille, reflet.
static func _eye(ci: CanvasItem, xf: Transform2D, c: Vector2, w: float, hgt: float, tilt: float, u: float, stade: int, build: String) -> void:
	var lid := Ink.leaf(c - Vector2(w, 0).rotated(tilt), tilt, w * 2.0, hgt * 1.6, 0.0)
	Ink.flat(ci, xf, lid, Color("fbf6e8"), 1.0)
	if Ink.mono:
		return
	var iris := Art.ec("seve") if build != "ronce" else Art.ec("seve").lerp(Art.ec("saignement", "clair"), 0.5 * (stade - 1) / 2.0)
	ci.draw_circle(xf * (c + Vector2(w * 0.25, 0.2)), hgt * 0.62 * u, Ink.shade(iris))
	ci.draw_circle(xf * (c + Vector2(w * 0.32, 0.3)), hgt * 0.34 * u, Ink.encre())
	ci.draw_circle(xf * (c + Vector2(w * 0.1, -0.8)), hgt * 0.2 * u, Color.WHITE)
	# Paupière supérieure appuyée (regard décidé).
	Ink.brush(ci, xf, PackedVector2Array([c - Vector2(w * 1.05, -0.2), c + Vector2(0, -hgt * 0.75), c + Vector2(w * 1.05, -0.6)]), 1.5, Ink.encre(), 1.0, 0.2)


## Pousse, couronne de ronce ou bourgeon de sève au sommet de la capuche.
static func _crown(ci: CanvasItem, xf: Transform2D, top: Vector2, t: float, stade: int, build: String, lv: Dictionary, u: float) -> void:
	var leaf := {"clair": lv["clair"].lightened(0.1), "ombre": lv["ombre"], "reflet": lv["reflet"]}
	var s := 0.8 + 0.2 * stade
	var sway := 0.1 * sin(t * 1.8)
	Ink.brush(ci, xf, PackedVector2Array([top + Vector2(0, 4), top + Vector2(-1, -3 * s), top + Vector2(1, -7 * s)]), 2.6, lv["ombre"].darkened(0.2), 1.0, 0.4)
	var tip := top + Vector2(1, -7 * s)
	Ink.part(ci, xf, Ink.leaf(tip, -2.5 + sway, 9.0 * s, 5.0 * s), leaf, 1.2, 1.0, 0.5)
	Ink.part(ci, xf, Ink.leaf(tip, -0.6 + sway, 8.0 * s, 4.6 * s), leaf, 1.2, 1.0, 0.5)
	if stade >= 2:
		Ink.part(ci, xf, Ink.leaf(tip + Vector2(-1, 1), -1.55 + sway, 7.0 * s, 3.6 * s), leaf, 1.0, 1.0, 0.5)
	if stade < 3:
		return
	if build == "ronce":
		# Couronne d'épines et deux baies.
		for j in 4:
			var a := -PI * (0.95 - j * 0.28)
			Ink.part(ci, xf, Ink.thorn(top + Vector2(2, 6) + Vector2.from_angle(a) * 9.0, a, 6.0, 2.6, 0.1), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.9, 1.0, 0.0)
		for q: Vector2 in [tip + Vector2(6, 3), tip + Vector2(-7, 4)]:
			Ink.part(ci, xf, Ink.lumpy(q, 3.4, 3.4, 14, 0.12, 8.0), {"clair": lv["detail"], "ombre": lv["detail"].darkened(0.45), "reflet": Color.WHITE}, 1.0, 1.0, 0.8)
	elif build == "seve" and not Ink.mono:
		Ink.halo(ci, xf * (tip + Vector2(0, -6)), 10.0 * u, Art.ec("seve"), 1.4 + 0.4 * sin(t * 3.0))
		Ink.flat(ci, xf, Ink.leaf(tip + Vector2(0, -2), -PI * 0.5, 8.0, 5.0), lv["detail"], 1.0)


## Graine-lanterne et ses lucioles ; plus vive avec le stade et pendant un lancer.
static func _lantern(ci: CanvasItem, base: Transform2D, xf: Transform2D, lp: Vector2, look: float, t: float, cast: float, stade: int, u: float) -> void:
	var lw := xf * lp
	if not Ink.mono:
		Ink.halo(ci, lw, (12.0 + 2.0 * stade + 10.0 * cast) * u, Art.ec("seve"), 1.4 + 0.3 * stade + cast)
		for i in 2 + stade:
			var m := lw + Vector2.from_angle(t * 2.6 + i * TAU / (2 + stade)) * 8.0 * u
			ci.draw_circle(m, 0.9 * u, Color(Art.ec("seve", "clair"), 0.5 + 0.4 * sin(t * 4.0 + i * 2.0)))
	var seedx := Transform2D(0.0, base.get_scale(), 0.0, lw)
	Ink.part(ci, seedx, Ink.oval(Vector2.ZERO, 4.6, 3.8, 16), {"clair": Art.ec("seve", "sombre").lightened(0.35), "ombre": Art.ec("seve", "sombre"), "reflet": Art.ec("seve", "clair")}, 1.3)
	if not Ink.mono:
		ci.draw_circle(lw + Vector2(-0.6, -0.6) * u, 2.0 * u, Art.ec("seve", "clair"))
		if cast > 0.0:
			for i in 5:
				var a := look + (i - 2) * 0.35
				ci.draw_line(lw + Vector2.from_angle(a) * 7.0 * u, lw + Vector2.from_angle(a) * (11.0 + 8.0 * cast) * u, Color(Art.ec("seve", "clair"), 0.85 * cast), 1.4 * u, true)
