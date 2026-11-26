## Lieux des « Paysages d'herbier » : des choses du monde vues de trois quarts, plus des pictogrammes.
##   - Cœur : une chose vivante et enracinée de la région. Roncier : un nœud de ronces qui serre un
##     gros bouton fendu de braise ; purifié, le nœud s'ouvre en églantine. Marais : des vesses-de-loup
##     gonflées, craquelées de braise, au milieu de leur mycélium ; purifié, une couronne de petits
##     chapeaux qui luisent. Les autres régions (en attendant la leur, vague 2) : une souche nouée
##     fendue de braise ; purifiée, elle s'ouvre sur une jeune pousse aux feuilles de la région.
##     La zone de siège reste dite par un cercle en tirets (fonction lisible).
##   - Sanctuaire : un cercle de pierres levées autour d'une pierre creuse où brûle la flamme de sève
##     (vert sève : le signe du vivant), éteinte tant qu'on ne l'a pas ravivé.
##   - Autel : une vraie pierre taillée (table de pierre), son signe gravé luit.
##
## En jeu (vague 1 C), chaque lieu est découpé en une partie fixe, cuite une fois en image
## (scripts/world_bake/lieux_bake.gd : heart_body, sanct_stone, sanct_vasque, altar_table), et une
## partie animée légère dessinée à chaque image (heart_live, sanct_rune, sanct_flame : halos, braises,
## flamme). Les fonctions heart, sanctuary_stones, sanctuary_center et altar dessinent tout d'un coup
## (planche W, tools/paysages-planche.sh).
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

## Hauteur d'un Grand Cœur (taille 1), en pixels du monde (le héros en fait 56).
const HEART_H := 120.0


# --- Couleurs ---


## Fente de braise qui vire à la sève à mesure que le Cœur cède (k de 0 à 1).
static func _braise(k: float) -> Color:
	return Art.bc("braise").lerp(Art.mc("commun", "", "seve"), k)


static func _braise_coeur(k: float) -> Color:
	return Art.bc("braise_coeur").lerp(Art.mc("commun", "", "seve_clair"), k)


## La région a ses couleurs du monde (Art.MONDE) ; sinon les parties communes servent.
static func has_palette(reg: String) -> bool:
	return Art.MONDE.has(reg) and Art.MONDE[reg].has("fletri")


## Pierre des lieux d'une région (« commun » pour une région sans palette, ou la Graine).
static func pierre(reg: String, ravive: bool) -> Dictionary:
	if has_palette(reg):
		return Art.mc(reg, "ravive" if ravive else "fletri", "pierre")
	var st: Dictionary = Art.mc("commun", "", "pierre")
	if ravive:
		return st
	return {"clair": st["clair"].darkened(0.3), "ombre": st["ombre"].darkened(0.3), "reflet": st["reflet"].darkened(0.35)}


## Touffe d'herbe ravivée d'une région (deux tons) : la sienne, ou les feuilles de sa branche.
static func touffe(reg: String) -> Array:
	if has_palette(reg):
		return [Art.mc(reg, "ravive", "touffe"), Art.mc(reg, "ravive", "touffe_2")]
	var f: Dictionary = feuilles(reg)
	return [f["clair"], f["ombre"]]


## Feuilles et fleur d'une région sans palette du monde : celles de sa branche (Art.FEUILLES_BUILD).
static func feuilles(reg: String) -> Dictionary:
	return Art.FEUILLES_BUILD.get(reg, Art.FEUILLES_BUILD["aucun"])


# --- Cœur ---


## Fente de braise : un trait brisé qui se ramifie (jamais un signe régulier), lueur autour.
static func _crack(ci: CanvasItem, from: Vector2, dir: Vector2, l: float, s: float, glow: float, seed: int, k := 0.0) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var pts := PackedVector2Array([from])
	var p := from
	var a := dir.angle()
	for i in 5:
		a += r.randf_range(-0.6, 0.6)
		p += Vector2.from_angle(a) * l / 5.0
		pts.append(p)
	var col := _braise(k)
	ci.draw_polyline(pts, Color(col, 0.18 + 0.2 * glow), 5.0 * s, true)
	ci.draw_polyline(pts, col, 1.8 * s, true)
	ci.draw_polyline(pts.slice(0, 4), _braise_coeur(k), 0.8 * s, true)
	var b := pts[2]
	var e := b + Vector2.from_angle(a + 1.1) * l * 0.3
	ci.draw_polyline(PackedVector2Array([b, b.lerp(e, 0.5) + Vector2(1, -1), e]), col, 1.2 * s, true)


## Cœur entier de la région en c (pied au sol), taille s (1 : Grand Cœur). purified : purifié. zone :
## rayon de la zone de siège (0 : pas de cercle). t : temps (pulsation). Pour la planche ; en jeu,
## heart.gd cuit heart_body et anime heart_live.
static func heart(ci: CanvasItem, reg: String, c: Vector2, s: float, purified: bool, zone: float, t: float) -> void:
	if not purified and zone > 0.0:
		_zone(ci, c, zone, t)
	heart_body(ci, reg, c, s, purified, 0.0)
	heart_live(ci, reg, c, s, purified, 0.0, t)


## Place prise par heart_body autour du pied (pixels du monde), pour la cuisson.
static func heart_box(s: float) -> Rect2:
	var h := HEART_H * s
	return Rect2(-1.45 * h, -1.4 * h, 2.9 * h, 2.25 * h)


## Partie fixe du Cœur (cuite) : flétri qui a cédé de k (fentes de braise → sève), ou purifié.
static func heart_body(ci: CanvasItem, reg: String, c: Vector2, s: float, purified: bool, k: float) -> void:
	if reg == "spore":
		_coeur_marais(ci, c, s, purified, k)
	elif reg == "ronce" or reg == "":
		_coeur_roncier(ci, c, s, purified, k)
	else:
		_coeur_commun(ci, reg, c, s, purified, k)


## Partie animée du Cœur (à chaque image) : lueur qui bat, braises qui montent (flétri), halo de la
## région et lueurs (purifié). k : avancée du siège (les braises virent à la sève).
static func heart_live(ci: CanvasItem, reg: String, c: Vector2, s: float, purified: bool, k: float, t: float, siege := false) -> void:
	var h := HEART_H * s
	var pulse := 0.5 + 0.5 * sin(t * (6.0 if siege else 2.6))
	if purified:
		var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
		var col: Color = heart_glow_color(reg)
		ci.draw_circle(c + Vector2(0, -h * 0.45), h * 0.75, Color(col, 0.03 + 0.02 * b))
		ci.draw_circle(c + Vector2(0, -h * 0.45), h * 0.45, Color(col, 0.05 + 0.03 * b))
		for i in 7:
			var u := fposmod(t * 0.22 + i / 7.0, 1.0)
			var p := c + Vector2(sin(i * 2.3 + t * 0.9) * h * 0.45, -h * 0.55 - h * 0.9 * u)
			ci.draw_circle(p, 4.0 * s, Color(col, 0.14 * sin(PI * u)))
			ci.draw_circle(p, 1.5 * s, Color(col.lightened(0.5), 0.9 * sin(PI * u)))
		return
	var mid := c + Vector2(0, -h * 0.45)
	var ember := _braise(k)
	ci.draw_circle(mid, h * 0.62, Color(ember, 0.04 + 0.05 * pulse + (0.04 if siege else 0.0)))
	ci.draw_circle(mid, h * 0.36, Color(ember, 0.05 + 0.06 * pulse))
	# Braises (ou spores grises au Marais) qui montent : on repère le Cœur de loin.
	var hot := _braise_coeur(k)
	for i in 9:
		var u := fposmod(t * (0.6 if siege else 0.32) + i / 9.0, 1.0)
		var p := c + Vector2(sin(i * 2.7 + t * 1.1) * h * (0.2 + 0.4 * u), -h * 0.7 - h * 1.2 * u)
		var sz := 2.6 * s * (1.0 - u * 0.5)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -sz * 1.4), p + Vector2(sz, 0), p + Vector2(0, sz * 1.1), p + Vector2(-sz, 0)]), Color(hot if i % 3 == 0 else ember, 0.85 * sin(PI * u)))
	if reg == "spore":
		var top := c + Vector2(0, -h * 0.68)
		for j in 3:
			ci.draw_circle(top + Vector2(sin(t + j) * 4.0, -h * 0.1 * (j + 1)), h * (0.04 + 0.02 * j), Color(Art.mc("spore", "fletri", "air"), 0.35 - 0.08 * j))
	elif not (reg == "ronce" or reg == ""):
		var top := c + Vector2(h * 0.04, -h * 0.78)
		for j in 3:
			ci.draw_circle(top + Vector2(sin(t * 0.8 + j) * 3.0, -h * 0.09 * (j + 1)), h * (0.035 + 0.02 * j), Color(0.55, 0.5, 0.5, 0.22 - 0.05 * j))


## Couleur du halo d'un Cœur purifié : celle de sa région.
static func heart_glow_color(reg: String) -> Color:
	if reg == "spore":
		return Art.mc("spore", "ravive", "lueur")
	if reg == "ronce" or reg == "":
		return Art.mc("ronce", "ravive", "fleur")
	return feuilles(reg)["lueur"]


## Cercle de siège au sol : tirets braise, vus de trois quarts (ellipse). Planche seulement : en jeu,
## heart.gd garde le vrai cercle de la zone.
static func _zone(ci: CanvasItem, c: Vector2, zone: float, t: float) -> void:
	var n := 56
	for i in n:
		if i % 2 == 1:
			continue
		var a0 := TAU * i / n + t * 0.05
		var a1 := TAU * (i + 1) / n + t * 0.05
		var p0 := c + Vector2(cos(a0) * zone, sin(a0) * zone * 0.62)
		var p1 := c + Vector2(cos(a1) * zone, sin(a1) * zone * 0.62)
		ci.draw_line(p0, p1, Color(Art.bc("braise"), 0.38), 2.0, true)


## Racines rampantes autour d'un Cœur (ronces noires ou mycélium), braises le long des racines flétries.
static func _roots(ci: CanvasItem, c: Vector2, s: float, col: Color, light: Color, n: int, reach: float, ember: bool, thorns: bool, seed: int, k := 0.0) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	for i in n:
		var a := TAU * i / n + r.randf_range(-0.2, 0.2)
		var pts := PackedVector2Array()
		var p := c + Vector2(cos(a) * 14.0 * s, sin(a) * 6.0 * s)
		var l := reach * s * r.randf_range(0.6, 1.0)
		for j in 9:
			var u := j / 8.0
			var aa := a + sin(u * 5.0 + i) * 0.25
			pts.append(p + Vector2(cos(aa), sin(aa) * 0.6) * l * u)
		O.brush(ci, pts, 5.0 * s, col, 1.0, 0.0)
		O.brush(ci, pts, 1.8 * s, light, 1.0, 0.0)
		if thorns:
			for j in range(2, 8, 2):
				var d := (pts[j + 1] - pts[j - 1]).normalized().orthogonal() * (1.0 if j % 4 == 0 else -1.0)
				O.poly(ci, Ink.thorn(pts[j], d.angle(), 4.5 * s, 2.0 * s), col)
		if ember and i % 2 == 0:
			var q := pts[5]
			ci.draw_circle(q, 5.0 * s, Color(_braise(k), 0.14))
			ci.draw_circle(q, 1.5 * s, _braise(k))


## Cœur du Roncier : nœud de ronces autour d'un gros bouton (cynorhodon) fendu de braise ; purifié, une
## grande églantine ouverte au milieu de ses feuilles.
static func _coeur_roncier(ci: CanvasItem, c: Vector2, s: float, purified: bool, k: float) -> void:
	var ron: Dictionary = Art.mc("ronce", "ravive" if purified else "fletri", "ronce")
	var h := HEART_H * s
	if purified:
		O.poly(ci, O.blob(c, h * 0.9, h * 0.34, 2.0, 0.12, 40), Color(Art.mc("ronce", "ravive", "sol_sombre"), 0.55))
	else:
		O.poly(ci, O.blob(c, h * 0.85, h * 0.32, 2.0, 0.14, 40), Color(Art.mc("ronce", "fletri", "sol_sombre"), 0.6))
	O.cast_shadow(ci, c, h * 0.7, h * 0.7, 0.4)
	_roots(ci, c, s, ron["ombre"], ron["clair"], 9, 150.0, not purified, true, 5, k)
	var bud := c + Vector2(0, -h * 0.5)
	if purified:
		_heart_canes(ci, c, h, s, ron, true)
	if not purified:
		# Le bouton : forme gonflée, sépales secs au sommet, fentes de braise.
		var pal: Dictionary = {"clair": Art.bc("ronce", "clair"), "ombre": Art.bc("ronce", "ombre"), "reflet": Art.bc("ronce", "reflet")}
		Ink.part(ci, Transform2D.IDENTITY, Ink.lumpy(bud, h * 0.27, h * 0.33, 30, 0.06, 6.0), pal, 2.2, 1.0, 1.0)
		for i in 5:
			var a := -PI * 0.5 + (i - 2) * 0.45
			Ink.part(ci, Transform2D.IDENTITY, Ink.leaf(bud + Vector2(0, -h * 0.3), a, h * 0.2, h * 0.07, 0.15), {"clair": Color("5a4a2e"), "ombre": Color("33281a")}, 1.2, 1.0, 0.0)
		_crack(ci, bud + Vector2(-h * 0.05, -h * 0.2), Vector2(0.2, 1), h * 0.38, s, 0.5, 3, k)
		_crack(ci, bud + Vector2(h * 0.12, -h * 0.12), Vector2(0.1, 1), h * 0.24, s, 0.5, 8, k)
		_heart_canes(ci, c, h, s, ron, false)
	else:
		# L'églantine : feuilles autour, cinq grands pétales vus de trois quarts, étamines dorées.
		var leaf: Dictionary = Art.mc("ronce", "ravive", "feuillage")
		for i in 7:
			var a := PI * (1.05 + 0.9 * i / 6.0)
			Ink.part(ci, Transform2D.IDENTITY, Ink.leaf(bud + Vector2(0, h * 0.05), a, h * 0.34, h * 0.16, 0.08), leaf, 1.3, 1.0, 0.6)
		var petal := {"clair": Art.mc("ronce", "ravive", "fleur"), "ombre": Art.mc("ronce", "ravive", "fleur").darkened(0.25), "reflet": Color("fff0f2")}
		for i in 5:
			var a := -PI * 0.5 + TAU * i / 5.0
			var p := bud + Vector2(cos(a) * h * 0.22, sin(a) * h * 0.13)
			Ink.part(ci, Transform2D.IDENTITY, Ink.lumpy(p, h * 0.21, h * 0.15, 18, 0.12, 2.0, a), petal, 1.4, 1.0, 0.9)
			ci.draw_line(bud, p + (p - bud) * 0.5, Color(petal["ombre"], 0.6), 1.0, true)
		ci.draw_circle(bud, h * 0.09, Art.mc("ronce", "ravive", "fleur_coeur"))
		for i in 12:
			var a := TAU * i / 12.0
			ci.draw_line(bud, bud + Vector2(cos(a), sin(a) * 0.6) * h * 0.1, Art.mc("ronce", "ravive", "fleur_coeur").darkened(0.3), 1.0, true)
			ci.draw_circle(bud + Vector2(cos(a), sin(a) * 0.6) * h * 0.1, 1.4, Color("fff2b0"))


## Trois grosses tiges de ronce qui montent en spirale et serrent le Cœur (écartées une fois purifié).
static func _heart_canes(ci: CanvasItem, c: Vector2, h: float, s: float, ron: Dictionary, purified: bool) -> void:
	var open := 1.0 if purified else 0.0
	var top := c + Vector2(0, -h * 0.62)
	for i in 3:
		var pts := PackedVector2Array()
		var a0 := TAU * i / 3.0
		for j in 14:
			var u := j / 13.0
			var rad := h * (0.32 - 0.18 * sin(u * PI) + open * 0.25 * u)
			var a := a0 + u * 2.6
			pts.append(c.lerp(top, u) + Vector2(cos(a) * rad, sin(a) * rad * 0.35 - u * open * h * 0.15))
		O.brush(ci, pts, 7.5 * s, Ink.encre(), 1.0, 0.0)
		O.brush(ci, pts, 5.5 * s, ron["ombre"], 1.0, 0.0)
		O.brush(ci, pts, 2.2 * s, ron["clair"], 1.0, 0.0)
		for j in range(2, 13, 2):
			var d := (pts[j + 1] - pts[j - 1]).normalized().orthogonal() * (1.0 if j % 4 == 0 else -1.0)
			O.poly(ci, Ink.thorn(pts[j], d.angle(), 6.0 * s, 2.6 * s), Ink.encre())


## Cœur du Marais : grappe de vesses-de-loup gonflées et craquelées de braise sur leur mycélium ; purifié,
## une couronne de chapeaux qui luisent (turquoise et violet).
static func _coeur_marais(ci: CanvasItem, c: Vector2, s: float, purified: bool, k: float) -> void:
	var h := HEART_H * s
	var etat := "ravive" if purified else "fletri"
	var myc: Color = Art.mc("spore", etat, "cendre")
	if purified:
		O.poly(ci, O.blob(c, h * 0.9, h * 0.34, 4.0, 0.12, 40), Color(Art.mc("spore", "ravive", "sol_sombre"), 0.6))
	else:
		O.poly(ci, O.blob(c, h * 0.9, h * 0.34, 4.0, 0.12, 40), Color(Art.mc("spore", "fletri", "sol_sombre"), 0.8))
	O.cast_shadow(ci, c, h * 0.8, h * 0.6, 0.4)
	_roots(ci, c, s, Color(myc, 0.5), Color(myc, 0.8), 11, 160.0, not purified, false, 9, k)
	if not purified:
		var pal: Dictionary = Art.mc("spore", "fletri", "chapeau")
		var balls := [[Vector2(-0.3, -0.12), 0.2], [Vector2(0.32, -0.08), 0.16], [Vector2(0.0, -0.36), 0.34]]
		for b in balls:
			var p: Vector2 = c + b[0] * h
			var rr: float = b[1] * h
			Ink.part(ci, Transform2D.IDENTITY, Ink.lumpy(p, rr, rr * 0.92, 28, 0.05, 5.0, b[0].x * 100.0), pal, 2.2, 1.0, 0.8)
			# Peau craquelée : réseau de fentes où la braise couve.
			_crack(ci, p + Vector2(-rr * 0.3, -rr * 0.5), Vector2(0.4, 1), rr * 1.1, s, 0.5, int(b[0].x * 100.0), k)
		# Bouche au sommet (elle fume : heart_live).
		var top: Vector2 = c + Vector2(0, -h * 0.68)
		O.poly(ci, Ink.oval(top, h * 0.07, h * 0.03, 12), Art.bc("ronge"))
	else:
		var caps := [[Vector2(0.0, -0.05), 1.0, 0.4, "fleur_2"], [Vector2(-0.4, 0.05), 0.65, 0.27, "fleur"], [Vector2(0.42, 0.08), 0.72, 0.3, "fleur"],
			[Vector2(-0.2, 0.2), 0.42, 0.18, "fleur"], [Vector2(0.22, 0.24), 0.36, 0.16, "fleur_2"], [Vector2(-0.55, 0.22), 0.3, 0.13, "fleur_2"]]
		caps.sort_custom(func(x, y): return x[0].y < y[0].y)
		for cp in caps:
			var base: Vector2 = c + cp[0] * h
			var hh: float = cp[1] * h
			var cw: float = cp[2] * h
			var col: Color = Art.mc("spore", "ravive", cp[3])
			var pied: Dictionary = Art.mc("spore", "ravive", "pied")
			var top := base + Vector2(0, -hh)
			ci.draw_circle(top, cw * 1.4, Color(col, 0.06))
			Ink.part(ci, Transform2D.IDENTITY, PackedVector2Array([base + Vector2(-cw * 0.2, 0), top + Vector2(-cw * 0.13, 0), top + Vector2(cw * 0.13, 0), base + Vector2(cw * 0.22, 0)]), pied, 1.4, 1.0, 0.5)
			var dome := PackedVector2Array()
			for i in 15:
				var a := PI + PI * i / 14.0
				dome.append(top + Vector2(cos(a) * cw, sin(a) * cw * 0.7))
			for i in range(14, -1, -1):
				var a := PI * i / 14.0
				dome.append(top + Vector2(cos(a) * cw, sin(a) * cw * 0.18))
			Ink.part(ci, Transform2D.IDENTITY, dome, {"clair": col, "ombre": col.darkened(0.35), "reflet": Color.WHITE}, 1.6, 1.0, 1.0)
			for i in 4:
				var a := PI * (1.2 + 0.6 * i / 3.0)
				ci.draw_circle(top + Vector2(cos(a) * cw * 0.55, sin(a) * cw * 0.35), cw * 0.08, Color(1, 1, 1, 0.75))


## Cœur commun (régions sans Cœur à elles, en attendant la vague 2) : une souche nouée, à l'écorce
## morte fendue de braise, prise dans ses racines, des chicots secs au sommet et une bouche qui fume ;
## purifiée, l'écorce s'ouvre en deux et une jeune pousse aux feuilles et aux fleurs de la région en sort.
static func _coeur_commun(ci: CanvasItem, reg: String, c: Vector2, s: float, purified: bool, k: float) -> void:
	var h := HEART_H * s
	var bark: Dictionary = Art.mc("commun", "", "ecorce_vive" if purified else "ecorce")
	var f: Dictionary = feuilles(reg)
	if purified:
		O.poly(ci, O.blob(c, h * 0.88, h * 0.33, 6.0, 0.12, 40), Color(f["ombre"], 0.45))
	else:
		O.poly(ci, O.blob(c, h * 0.85, h * 0.32, 6.0, 0.14, 40), Color(Art.mc("commun", "", "nuit"), 0.35))
	O.cast_shadow(ci, c, h * 0.75, h * 0.75, 0.4)
	_roots(ci, c, s, bark["ombre"], bark["clair"], 8, 140.0, not purified, false, 17, k)
	var mid := c + Vector2(0, -h * 0.4)
	if not purified:
		# Souche : trois bosses d'écorce serrées et noueuses, la plus grosse au milieu.
		for b in [[Vector2(-0.3, -0.14), 0.21, 0.18], [Vector2(0.31, -0.12), 0.19, 0.17], [Vector2(0.0, -0.4), 0.29, 0.38]]:
			var p: Vector2 = c + b[0] * h
			Ink.part(ci, Transform2D.IDENTITY, Ink.lumpy(p, b[1] * h, b[2] * h, 36, 0.16, 9.0, b[0].x * 10.0), bark, 2.2, 1.0, 0.5)
		# Nœuds de l'écorce (des yeux de bois fermés), puis fentes de braise.
		for kn in [[Vector2(-0.12, -0.55), 0.05], [Vector2(0.15, -0.3), 0.04], [Vector2(-0.33, -0.18), 0.035]]:
			var q: Vector2 = c + kn[0] * h
			O.poly(ci, Ink.oval(q, kn[1] * h, kn[1] * h * 0.6, 12), bark["ombre"].darkened(0.3))
			ci.draw_arc(q, kn[1] * h, PI * 1.1, PI * 1.9, 8, bark["reflet"], 1.0 * s, true)
		_crack(ci, mid + Vector2(-h * 0.08, -h * 0.18), Vector2(0.15, 1), h * 0.42, s, 0.5, 21, k)
		_crack(ci, mid + Vector2(h * 0.14, -h * 0.05), Vector2(-0.1, 1), h * 0.28, s, 0.5, 34, k)
		_crack(ci, c + Vector2(-h * 0.33, -h * 0.25), Vector2(0.3, 1), h * 0.16, s, 0.5, 47, k)
		# Bouche au sommet, et des chicots secs tordus.
		var top := c + Vector2(h * 0.04, -h * 0.76)
		O.poly(ci, Ink.oval(top, h * 0.09, h * 0.035, 14), Art.bc("ronge"))
		ci.draw_arc(top, h * 0.09, 0.2, PI - 0.2, 10, Color(_braise(k), 0.6), 1.2 * s, true)
		for sn in [[-1.0, 0.2, 0.22], [1.0, 0.24, 0.16], [0.3, 0.1, 0.26]]:
			var side: float = sn[0]
			var b0 := c + Vector2(side * h * sn[1] * 0.8, -h * 0.66)
			var pts := O.curve(b0, b0 + Vector2(side * h * 0.1, -h * sn[2] * 0.6), b0 + Vector2(side * h * sn[1], -h * sn[2]), 6)
			O.brush(ci, pts, 4.0 * s, Ink.encre(), 1.0, 0.0)
			O.brush(ci, pts, 2.4 * s, bark["clair"], 1.0, 0.0)
	else:
		# L'écorce fendue rabattue au sol de part et d'autre, la pousse au milieu.
		for side in [-1.0, 1.0]:
			var p := c + Vector2(side * h * 0.3, -h * 0.08)
			var shell := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				shell.append(p + Vector2(cos(a) * h * 0.2, sin(a) * h * 0.13 * (1.0 + 0.25 * sin(i * 2.1))))
			shell.append(p + Vector2(h * 0.2, h * 0.03))
			shell.append(p + Vector2(-h * 0.2, h * 0.03))
			Ink.part(ci, Transform2D.IDENTITY, shell, bark, 1.8, 1.0, 0.5)
		var trunk := O.curve(c + Vector2(0, -h * 0.02), c + Vector2(-h * 0.08, -h * 0.5), c + Vector2(h * 0.02, -h * 0.9), 8)
		O.brush(ci, trunk, 9.0 * s, Ink.encre(), 1.0, 0.0)
		O.brush(ci, trunk, 7.0 * s, bark["ombre"], 1.0, 0.0)
		O.brush(ci, trunk, 3.0 * s, bark["clair"], 1.0, 0.0)
		for side in [-1.0, 1.0]:
			var br := O.curve(c + Vector2(-h * 0.04, -h * 0.55), c + Vector2(side * h * 0.2, -h * 0.62), c + Vector2(side * h * 0.3, -h * 0.82), 6)
			O.brush(ci, br, 4.0 * s, Ink.encre(), 1.0, 0.0)
			O.brush(ci, br, 2.4 * s, bark["clair"], 1.0, 0.0)
		var pal := {"clair": f["clair"], "ombre": f["ombre"], "reflet": f["reflet"]}
		# Couronne : trois grappes de feuilles (deux sur les branches, une au sommet).
		for g in [[Vector2(-0.3, -0.84), 0.8], [Vector2(0.3, -0.84), 0.8], [Vector2(0.02, -0.95), 1.0]]:
			var gc: Vector2 = c + g[0] * h
			var gs: float = g[1]
			for i in 9:
				var a := TAU * i / 9.0 + gs
				var l := h * gs * (0.24 + 0.05 * sin(i * 1.7))
				Ink.part(ci, Transform2D.IDENTITY, Ink.leaf(gc, a, l, l * 0.45, 0.08 * (1.0 if i % 2 == 0 else -1.0)), pal, 1.3, 1.0, 0.6)
			for i in 4:
				var a := PI * (1.2 + 0.6 * i / 3.0)
				Ink.part(ci, Transform2D.IDENTITY, Ink.leaf(gc, a, h * 0.14 * gs, h * 0.06 * gs, 0.05), {"clair": f["reflet"], "ombre": f["clair"], "reflet": Color.WHITE}, 1.1, 1.0, 0.8)
		for fl in [[Vector2(-0.34, -0.9), 0.075], [Vector2(0.26, -0.95), 0.07], [Vector2(0.06, -1.06), 0.085], [Vector2(-0.08, -0.86), 0.06], [Vector2(0.36, -0.78), 0.055], [Vector2(-0.22, -0.74), 0.05]]:
			O.flower(ci, c + fl[0] * h, fl[1] * h, f["accent"], f["lueur"], fl[0].x * 7.0)


# --- Sanctuaire ---

const STONES := 7
## Planche : ellipse des pierres levées.
const SANCT_RX := 66.0
const SANCT_RY := 30.0
## Jeu : rayon (vrai cercle du monde) où sont plantées les pierres.
const SANCT_R := 70.0


## Hauteur de la pierre i du cercle (même tirage partout : un sanctuaire se reconnaît).
static func stone_height(i: int) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = 77 + 31 * i
	return r.randf_range(42.0, 58.0) * (0.72 if i % 3 == 1 else 1.0)


## Place de sanct_stone autour du pied, pour la cuisson.
static func stone_box() -> Rect2:
	return Rect2(-30, -68, 70, 84)


## Une pierre levée du sanctuaire, pied en p : polygone cassé en deux tons, graine gravée (vert sève si
## lit), une touffe au pied si ravive. lean : penche (vers l'extérieur du cercle).
static func sanct_stone(ci: CanvasItem, reg: String, p: Vector2, i: int, lit: bool, ravive: bool, lean := 0.0) -> void:
	var st: Dictionary = pierre(reg, ravive)
	var hh := stone_height(i)
	var w := hh * 0.34
	O.cast_shadow(ci, p, w * 1.6, hh, 0.34)
	var pts := PackedVector2Array([p + Vector2(-w * 0.55, 1), p + Vector2(-w * 0.6 + lean * hh, -hh * 0.6), p + Vector2(-w * 0.35 + lean * hh, -hh),
		p + Vector2(w * 0.2 + lean * hh, -hh - 3), p + Vector2(w * 0.55 + lean * hh, -hh * 0.75), p + Vector2(w * 0.6, 1)])
	O.part(ci, pts, st, 1.6, 1.0, 0.5)
	var rc := rune_pos(p, i, lean)
	var col: Color = Art.mc("commun", "", "seve") if lit else Color(st["ombre"].darkened(0.4), 0.9)
	if lit:
		ci.draw_circle(rc, 8.0, Color(col, 0.16))
	# Graine gravée : une amande, une pousse qui en sort.
	ci.draw_polyline(Ink.oval(rc + Vector2(0, 2), 2.6, 4.0, 12) + PackedVector2Array([rc + Vector2(0, -2)]), col, 1.2, true)
	ci.draw_polyline(O.curve(rc + Vector2(0, -2), rc + Vector2(1, -6), rc + Vector2(3.5, -8), 4), col, 1.2, true)
	if ravive:
		var tt := touffe(reg)
		O.tuft(ci, p + Vector2(w * 0.4, 1), 12.0, tt[0], tt[1], i * 13)
		if i % 2 == 0:
			O.tuft(ci, p + Vector2(-w * 0.5, 2), 9.0, tt[1], tt[0], i * 17 + 3)


## Milieu de la graine gravée sur la pierre i.
static func rune_pos(p: Vector2, i: int, lean := 0.0) -> Vector2:
	var hh := stone_height(i)
	return p + Vector2(lean * hh * 0.5, -hh * 0.55)


## Lueur animée de la graine gravée (on : 0 à 1, la pierre s'allume).
static func sanct_rune(ci: CanvasItem, p: Vector2, i: int, on: float, t: float, lean := 0.0) -> void:
	if on <= 0.0:
		return
	var pulse := 0.5 + 0.5 * sin(t * 2.4 - i * 0.9)
	var rc := rune_pos(p, i, lean)
	var seve: Color = Art.mc("commun", "", "seve")
	ci.draw_circle(rc, 9.0, Color(seve, (0.1 + 0.14 * pulse) * on))
	ci.draw_circle(rc, 4.0, Color(seve, 0.18 * on))


## Place de sanct_vasque autour de son pied, pour la cuisson.
static func vasque_box() -> Rect2:
	return Rect2(-34, -24, 68, 40)


## Pierre creuse au centre du sanctuaire (sans flamme : sanct_flame), pied en b.
static func sanct_vasque(ci: CanvasItem, reg: String, b: Vector2, lit: bool) -> void:
	var st: Dictionary = pierre(reg, lit)
	O.cast_shadow(ci, b, 26.0, 16.0, 0.35)
	O.part(ci, PackedVector2Array([b + Vector2(-13, 0), b + Vector2(-16, -12), b + Vector2(16, -12), b + Vector2(13, 0)]), st, 1.5, 1.0, 0.4)
	O.part(ci, Ink.oval(b + Vector2(0, -12), 16.0, 5.0, 20), st, 1.3, 1.0, 0.3)
	O.poly(ci, Ink.oval(b + Vector2(0, -12), 12.0, 3.4, 20), Color(0.05, 0.04, 0.05))
	if lit:
		O.poly(ci, Ink.oval(b + Vector2(0, -12), 11.0, 3.0, 20), Color(Art.mc("commun", "", "seve_sombre"), 0.8))


## Dalle au sol du sanctuaire (sous les pierres), centre c, rayon r (vrai cercle du monde).
static func sanct_dalle(ci: CanvasItem, reg: String, c: Vector2, r: float, lit: bool) -> void:
	var st: Dictionary = pierre(reg, lit)
	O.poly(ci, O.blob(c, r, r, 3.0, 0.04, 48), Color(st["ombre"], 0.3))
	O.poly(ci, O.blob(c + Vector2(-2, -2), r * 0.9, r * 0.88, 5.0, 0.05, 48), Color(st["clair"], 0.22))
	# Pavés usés : quelques dalles plus claires en anneau.
	for i in 14:
		var a := TAU * i / 14.0 + 0.1
		var p := c + Vector2.from_angle(a) * r * 0.62
		O.poly(ci, O.blob(p, r * 0.13, r * 0.08, float(i), 0.15, 10, a), Color(st["reflet"], 0.13))
	if lit:
		O.poly(ci, O.blob(c, r * 1.08, r * 1.08, 7.0, 0.04, 48), Color(Art.mc("commun", "", "seve"), 0.07))


## Flamme du sanctuaire sur la vasque (pied b) : éteinte, une braise froide et un filet de fumée ; k
## (0 à 1) la ranime à mesure qu'on se tient dans le cercle ; allumée, la flamme de sève.
static func sanct_flame(ci: CanvasItem, b: Vector2, lit: bool, k: float, t: float, flash := 0.0) -> void:
	var seve: Color = Art.mc("commun", "", "seve")
	var f := b + Vector2(0, -13)
	if lit:
		var fl := 1.0 + 0.08 * sin(t * 9.0) + 0.3 * flash
		var br := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
		# Colonne de lumière qui se voit de loin.
		for band in [[7.0, Color(seve, (0.1 + 0.04 * br) * 0.6)], [2.5, Color(Art.mc("commun", "", "seve_clair"), 0.1 + 0.04 * br)]]:
			var hw: float = band[0]
			var c0: Color = band[1]
			ci.draw_polygon(PackedVector2Array([f + Vector2(-hw, -10), f + Vector2(hw, -10), f + Vector2(hw, -160), f + Vector2(-hw, -160)]),
				PackedColorArray([c0, c0, Color(c0, 0.0), Color(c0, 0.0)]))
		ci.draw_circle(f + Vector2(0, -12), 34.0 * (1.0 + 0.3 * flash), Color(seve, 0.07 + 0.1 * flash))
		ci.draw_circle(f + Vector2(0, -10), 18.0, Color(seve, 0.12))
		var flame := PackedVector2Array([f + Vector2(-8, 0), f + Vector2(-6, -12 * fl), f + Vector2(sin(t * 3.0) * 1.5, -28 * fl), f + Vector2(6, -12 * fl), f + Vector2(8, 0)])
		O.poly(ci, flame, Color(seve, 0.9))
		O.poly(ci, Transform2D(0.0, Vector2(0.5, 0.6), 0.0, Vector2(f.x * 0.5, f.y * 0.4 + 1.0)) * flame, Art.mc("commun", "", "seve_clair"))
		for i in 5:
			var u := fposmod(t * 0.45 + i / 5.0, 1.0)
			ci.draw_circle(f + Vector2(sin(i * 2.3 + t * 1.3) * 10.0, -14.0 - 60.0 * u), 1.6, Color(Art.mc("commun", "", "seve_clair"), sin(PI * u)))
	else:
		ci.draw_circle(f, 2.2 + 3.0 * k, Color(seve, 0.4 + 0.4 * k))
		if k > 0.0:
			ci.draw_circle(f + Vector2(0, -4), 14.0 * k, Color(seve, 0.14 * k))
			var flame := PackedVector2Array([f + Vector2(-5 * k, 0), f + Vector2(0, -18 * k * (1.0 + 0.1 * sin(t * 9.0))), f + Vector2(5 * k, 0)])
			O.poly(ci, flame, Color(seve, 0.7 * k))
		for j in 3:
			ci.draw_circle(f + Vector2(sin(t * 0.8 + j) * 3.0, -8.0 - 9.0 * j), 3.0 + j, Color(0.6, 0.6, 0.62, 0.12 * (1.0 - k)))


## Planche : pierres levées du sanctuaire, arrière (back = vrai : celles derrière le centre) ou avant.
static func sanctuary_stones(ci: CanvasItem, reg: String, c: Vector2, etat: String, lit: bool, back: bool) -> void:
	var list := []
	for i in STONES:
		var a := -PI * 0.5 + TAU * i / STONES + 0.2
		var p := c + Vector2(cos(a) * SANCT_RX, sin(a) * SANCT_RY)
		list.append([p, sin(a) < 0.0, i, (p.x - c.x) / SANCT_RX * 0.08])
	list.sort_custom(func(x, y): return x[0].y < y[0].y)
	for s in list:
		if s[1] != back:
			continue
		sanct_stone(ci, reg, s[0], s[2], lit, etat == "ravive", s[3])


## Planche : centre du sanctuaire (dalle, pierre creuse, flamme).
static func sanctuary_center(ci: CanvasItem, reg: String, c: Vector2, etat: String, lit: bool, t: float) -> void:
	var st: Dictionary = pierre(reg, etat == "ravive")
	O.poly(ci, Ink.oval(c, SANCT_RX * 0.78, SANCT_RY * 0.78, 40), Color(st["ombre"], 0.55))
	O.poly(ci, Ink.oval(c + Vector2(-2, -1), SANCT_RX * 0.7, SANCT_RY * 0.68, 40), Color(st["clair"], 0.35))
	if lit:
		O.poly(ci, Ink.oval(c, SANCT_RX * 0.95, SANCT_RY * 0.95, 40), Color(Art.mc("commun", "", "seve"), 0.08))
	var b := c + Vector2(0, 4)
	sanct_vasque(ci, reg, b, lit)
	sanct_flame(ci, b, lit, 0.0, t)


# --- Autel ---


## Place de altar_table autour du pied, pour la cuisson.
static func altar_box() -> Rect2:
	return Rect2(-42, -40, 98, 56)


## Autel : une table de pierre (deux pierres dressées, une dalle posée dessus) et son signe gravé
## (éteint ; la lueur est dessinée à part, altar_glyph). ravive : la pierre claire et l'herbe revenue.
static func altar_table(ci: CanvasItem, reg: String, c: Vector2, ravive: bool) -> void:
	var st: Dictionary = pierre(reg, ravive)
	O.cast_shadow(ci, c, 56.0, 30.0, 0.36)
	for sx in [-1.0, 1.0]:
		var b := c + Vector2(sx * 16.0, 0)
		O.part(ci, PackedVector2Array([b + Vector2(-7, 1), b + Vector2(-6, -20), b + Vector2(5, -21), b + Vector2(7, 1)]), st, 1.4, 1.0, 0.3)
	O.poly(ci, Ink.oval(c + Vector2(0, -2), 9.0, 3.0, 12), Color(0, 0, 0, 0.5))
	var slab := PackedVector2Array([c + Vector2(-30, -18), c + Vector2(-27, -27), c + Vector2(-8, -31), c + Vector2(26, -28), c + Vector2(31, -20), c + Vector2(24, -15), c + Vector2(-22, -14)])
	O.part(ci, slab, st, 1.6, 1.0, 0.5)
	var g := c + Vector2(0, -23)
	var dark := Color(st["ombre"].darkened(0.4), 0.9)
	ci.draw_arc(g, 4.0, 0.0, TAU, 14, dark, 1.3, true)
	ci.draw_line(g + Vector2(-7, 0), g + Vector2(7, 0), dark, 1.1, true)
	if not ravive and reg == "ronce":
		var ron: Dictionary = Art.mc("ronce", "fletri", "ronce")
		O.brush(ci, O.curve(c + Vector2(-34, 0), c + Vector2(-14, -34), c + Vector2(34, -12)), 2.4, ron["ombre"], 1.0, 0.0)
	elif ravive:
		var tt := touffe(reg)
		O.tuft(ci, c + Vector2(26, 2), 12.0, tt[0], tt[1], 5)
		O.tuft(ci, c + Vector2(-27, 3), 9.0, tt[1], tt[0], 9)


## Signe gravé de l'autel qui luit (k : 0 éteint à 1 allumé), couleur « interactif ».
static func altar_glyph(ci: CanvasItem, c: Vector2, k: float, t: float) -> void:
	if k <= 0.0:
		return
	var glow: Color = Art.c("interactif")
	var g := c + Vector2(0, -23)
	var p := 0.85 + 0.15 * sin(t * 2.0)
	ci.draw_circle(g, 9.0, Color(glow, 0.16 * k * p))
	ci.draw_arc(g, 4.0, 0.0, TAU, 14, Color(glow, k), 1.3, true)
	ci.draw_line(g + Vector2(-7, 0), g + Vector2(7, 0), Color(glow, k), 1.1, true)


## Planche : l'autel entier, la greffe flotte au-dessus.
static func altar(ci: CanvasItem, reg: String, c: Vector2, etat: String, t: float) -> void:
	altar_table(ci, reg, c, etat == "ravive")
	altar_glyph(ci, c, 1.0, t)
	var glow: Color = Art.c("interactif")
	var y := -50.0 + sin(t * 2.0) * 2.0
	ci.draw_circle(c + Vector2(0, y), 13.0, Color(glow, 0.12))
	Ink.part(ci, Transform2D.IDENTITY, Ink.oval(c + Vector2(0, y), 5.0, 6.5, 14), {"clair": glow.lightened(0.3), "ombre": glow.darkened(0.2), "reflet": Color.WHITE}, 1.2, 1.0, 1.0)
