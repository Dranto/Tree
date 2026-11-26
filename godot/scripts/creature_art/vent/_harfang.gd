## Le Harfang de cendre (boss de Vent), direction « Bestiaire d'herbier » : une chouette des neiges géante
## des plateaux, rongée par la Flétrissure. Vue de trois quarts, tournée vers la droite (le boss retourne
## le dessin vers le joueur) : grand corps rond au poitrail de duvet barré de chevrons, dos et ailes au
## bleu de la région, tête ronde qui pivote vers sa proie (disque facial pâle, deux yeux de braise, bec
## crochu d'os), pattes emplumées aux serres d'os. La cendre mange le bout des rémiges et une plaie de
## braise lui ouvre le poitrail. Phase 2 : le bord des ailes couve ; phase 3 : rémiges en braise,
## deux plumes arrachées, cendres qui s'envolent.
##
## Pas une sorte (le nom commence par « _ ») : le moteur ne le cuit pas, le boss le dessine (boss_vent.gd).
##
## Pose (clés de o) : t, alt (vol, unités locales au-dessus des pieds), flap (battement : -1 ailes basses,
## 0 à plat, 1 levées, 1,4 dressées), fold (repli : 0 ouvertes → 1 plaquées), dive (piqué : corps tendu
## vers le bas), look (angle de la cible, repère du dessin tourné à droite), k (intensité de l'annonce),
## cri (bec ouvert 0 → 1), bristle (plumes hérissées 0 → 1), rage (0 / 0,5 / 1 selon la phase),
## tired (posé au sol, essoufflé 0 → 1), dk (mort 0 → 1), sleep (yeux clos 0 → 1), hit,
## flip (tourné vers la gauche), gueri (la chouette vivante d'après la victoire : ni cendre ni braise, yeux d'or).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vent/_commun.gd")

## 100 unités = hauteur du corps (des serres au sommet de la tête). Envergure ≈ 2,6 × la hauteur.
const HEIGHT := 145.0


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var alt: float = o.get("alt", 60.0)
	var flap: float = o.get("flap", 0.3)
	var fold: float = o.get("fold", 0.0)
	var dive: float = o.get("dive", 0.0)
	var look: float = o.get("look", 0.0)
	var k: float = o.get("k", 0.0)
	var cri: float = o.get("cri", 0.0)
	var bristle: float = o.get("bristle", 0.0)
	var rage: float = o.get("rage", 0.0)
	var tired: float = o.get("tired", 0.0)
	var dk: float = o.get("dk", 0.0)
	var sleep: float = o.get("sleep", 0.0)
	var hit: float = o.get("hit", 0.0)
	var gueri: bool = o.get("gueri", false)
	if gueri:
		rage = -1.0
	Ink.flash = hit
	Ink.ash = Anim.ease_out(clampf(dk * 1.4, 0.0, 1.0)) * 0.85
	var base := Ink.frame(feet, h, o.get("flip", false))
	# Respiration : le poitrail gonfle, plus vite quand il est essoufflé.
	var breath := sin(t * lerpf(2.2, 6.5, tired)) * lerpf(0.02, 0.05, tired)
	var tilt := 0.85 * dive - 0.12 * k + 0.1 * tired + 0.08 * hit
	var sq := Vector2(1.0 + breath + 0.06 * hit - 0.18 * dive, 1.0 - breath * 0.5 - 0.06 * hit + 0.2 * dive)
	var xf := base * Transform2D(0.0, Vector2(0, -alt - 40.0)) * Transform2D(tilt, sq, 0.0, Vector2.ZERO)
	var blue := V.pal()
	var far_pal := {"clair": Art.bc("vent", "plume"), "ombre": Art.bc("vent", "ombre").darkened(0.3), "reflet": Art.bc("vent", "clair")}
	var down := {"clair": Art.bc("vent", "duvet"), "ombre": Art.bc("vent", "aile"), "reflet": Color.WHITE}
	var pulse := 0.5 + 0.5 * sin(t * (3.0 + 4.0 * rage))
	# Aile du fond : vers la droite, derrière la tête, raccourcie par la perspective.
	_wing(ci, xf, Vector2(10, -30), -1.0, flap, fold, 0.72, far_pal, rage, pulse, dk, t)
	# Queue : un éventail court de plumes barrées, qui s'ouvre quand il se hérisse.
	var spread := 0.16 + 0.2 * bristle + 0.1 * k
	for i in 5:
		var a := PI * 0.72 + (i - 2) * spread + 0.05 * sin(t * 2.6 + i)
		_feather(ci, xf, Vector2(-14, 26), a, 30.0 - absf(i - 2.0) * 3.0, 10.0, down if i % 2 == 0 else blue, rage * 0.6 if i == 0 else 0.0, 2)
	# Pattes emplumées (pantalons de duvet), serres d'os : pendantes en vol, tendues dans le piqué,
	# posées au sol quand il atterrit.
	for s: float in [-1.0, 1.0]:
		_leg(ci, xf, Vector2(4.0 + 11.0 * s, 30), s, dive, tired, k, t)
	# Corps : un gros œuf de plumes, dos bleu.
	var body := Ink.lumpy(Vector2(0, 0), 31.0, 38.0, 30, 0.04, 9.0, 0.3)
	Ink.part(ci, xf, body, blue, 2.6, 1.0, 0.6)
	# Poitrail de duvet (devant, côté droit), barré de chevrons bleus en rangs.
	var chest := PackedVector2Array([Vector2(26, -24), Vector2(31, -6), Vector2(28, 14), Vector2(18, 30), Vector2(2, 36), Vector2(-10, 30), Vector2(-6, 12), Vector2(2, -8), Vector2(12, -24)])
	Ink.part(ci, xf, chest, down, 0.0, 1.0, 0.7)
	if not Ink.mono:
		for row in 5:
			for col in 3:
				var p := Vector2(4.0 + col * 8.0 - row * 1.5 + (row % 2) * 4.0, -14.0 + row * 9.0)
				if p.x > 28.0 - row * 1.0 or (row == 4 and col == 2):
					continue
				Ink.brush(ci, xf, PackedVector2Array([p + Vector2(-3, -1.6), p, p + Vector2(3, -1.6)]), 1.6, Art.bc("vent", "plume"))
		# Hérissé : des pointes de duvet se dressent sur le contour.
		if bristle > 0.0:
			for i in 7:
				var a := -1.2 + i * 0.42
				var q := Vector2(cos(a) * 31.0, sin(a) * 38.0)
				Ink.brush(ci, xf, PackedVector2Array([q * 0.95, q * (1.0 + 0.12 * bristle)]), 3.0, Art.bc("vent", "duvet"), 1.0, 0.0)
	# Taches sombres du harfang sur le dos.
	if not Ink.mono:
		for q: Vector3 in [Vector3(-20, -10, 3.5), Vector3(-24, 6, 3.0), Vector3(-14, -22, 2.6), Vector3(-18, 20, 2.8)]:
			Ink.flat(ci, xf, Ink.leaf(Vector2(q.x - q.z, q.y), 0.3, q.z * 2.2, q.z), Art.bc("vent", "ombre"))
	# La plaie de la Flétrissure : cendre sur le flanc, fente de braise qui palpite.
	if gueri:
		_head(ci, xf * Transform2D(clampf(look, -0.6, 0.6) * 0.36, Vector2(8, -40)), 0.0, 0.0, 0.0, t, 0.0, 0.0, sleep, 0.0, true)
		_wing(ci, xf, Vector2(-8, -26), 1.0, flap, fold, 1.0, {"clair": Art.bc("vent", "duvet"), "ombre": Art.bc("vent", "aile"), "reflet": Color.WHITE}, -1.0, 0.0, 0.0, t)
		return
	var wound := Ink.lumpy(Vector2(-4, 6), 10.0, 7.0, 20, 0.4, 5.0, 1.3)
	Ink.flat(ci, xf, wound, Art.bc("ronge"))
	var glow := 0.35 + 0.4 * k + 0.3 * rage * pulse
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-11, 2), Vector2(-5, 7), Vector2(0, 4), Vector2(5, 10)]), 1.8 + 1.4 * glow, Art.bc("braise"))
	if not Ink.mono and dk < 0.9:
		Ink.halo(ci, xf * Vector2(-3, 6), 14.0 * h / 100.0 * (0.6 + glow), Art.bc("braise"), glow * (1.0 - dk))
	Ink.sparks(ci, xf, Vector2(-4, 2), Vector2(-0.3, -1.0), 3 + int(3 * rage), t, 1.4, (0.6 + 0.4 * rage) * (1.0 - dk))
	# Tête : elle pivote vers la cible (les chouettes tournent la tête plus que le corps).
	var hl := clampf(look - tilt * 0.8, -0.6, 0.6) * (1.0 - 0.6 * dive)
	var hx := xf * Transform2D(hl * 0.6, Vector2.ONE, 0.0, Vector2(8, -34)) * Transform2D(0.0, Vector2(0, -6.0))
	_head(ci, hx, k, cri, hit, t, rage, dk, sleep, dive, false)
	# Aile de devant, par-dessus le corps : vers la gauche, pleine envergure.
	_wing(ci, xf, Vector2(-8, -26), 1.0, flap, fold, 1.0, {"clair": Art.bc("vent", "clair"), "ombre": Art.bc("vent", "plume"), "reflet": Art.bc("vent", "reflet")}, rage, pulse, dk, t)
	# Phase 3 et mort : des plumes de cendre s'arrachent et s'envolent.
	if not Ink.mono and (rage >= 1.0 or dk > 0.0):
		for i in 7:
			var u := fposmod(t * 0.55 + i / 7.0, 1.0)
			var q := Vector2(sin(i * 2.4 + t * 0.7) * 70.0, 10.0 - 110.0 * u)
			_feather(ci, xf, q, -1.2 + sin(t * 2.0 + i) * 1.2, 9.0 * (1.0 - 0.4 * u), 4.0, {"clair": Color(Art.bc("vent", "duvet").lerp(Art.bc("ronge"), 0.5 * u), 1.0 - u), "ombre": Color(Art.bc("ronge"), 1.0 - u)}, 0.6, 0)


## Une plume (repère xf) : base b, direction a, longueur l, largeur w ; rachis sombre, pointe rongée
## par la cendre si ash > 0 (bout noir, braise au bord). ink : encre (0 : aucune).
static func _feather(ci: CanvasItem, xf: Transform2D, b: Vector2, a: float, l: float, w: float, col: Dictionary, ash: float, ink := 1) -> void:
	var shape := Ink.leaf(b, a, l, w, 0.04)
	Ink.part(ci, xf, shape, col, 1.4 * ink, 1.0 if ink > 0 else 0.0, 0.0)
	if Ink.mono:
		return
	var d := Vector2.from_angle(a)
	if ink > 0:
		Ink.brush(ci, xf, PackedVector2Array([b + d * l * 0.1, b + d * l * 0.85]), 0.9, col["ombre"].darkened(0.35))
	if ash > 0.0:
		var tip := b + d * l * (1.0 - 0.3 * ash)
		Ink.flat(ci, xf, Ink.leaf(tip, a, l * 0.3 * ash, w * 0.75, 0.0), Art.bc("ronge"))
		Ink.brush(ci, xf, PackedVector2Array([tip + d.orthogonal() * w * 0.32, tip - d.orthogonal() * w * 0.32]), 1.2, Art.bc("braise"))


## Aile (repère du corps) : épaule sh, côté side (1 : aile de devant, vers la gauche ; -1 : aile du fond,
## vers la droite), battement flap, repli fold, raccourci persp, rage : braise au bord de fuite.
static func _wing(ci: CanvasItem, xf: Transform2D, sh: Vector2, side: float, flap: float, fold: float, persp: float, col: Dictionary, rage: float, pulse: float, dk: float, t: float) -> void:
	# Angle de l'aile : à plat un peu vers le haut, levée avec flap ; repliée le long du dos.
	var up := 0.32 + 0.85 * flap
	var a_open := PI + up if side > 0.0 else -up
	var a_fold := PI * 0.62 if side > 0.0 else PI * 0.4
	var a := lerp_angle(a_open, a_fold, fold)
	var span := lerpf(104.0, 50.0, fold) * persp
	var d := Vector2.from_angle(a)
	# Bord de fuite : du côté du sol (normale vers le bas de l'aile).
	var n := d.orthogonal() * (1.0 if side > 0.0 else -1.0)
	if n.y < -0.2 and absf(d.y) < 0.9:
		n = -n
	var wd := lerpf(0.42, 0.28, fold)
	# Rémiges primaires : un éventail de doigts au bout de l'aile (sous la main), la cendre en ronge le bout.
	var torn := [2, 4] if rage >= 1.0 else []
	var nprim := 6
	for i in nprim:
		if i in torn:
			continue
		var u := float(i) / (nprim - 1)
		var root := sh + d * span * lerpf(0.84, 0.56, u) + n * span * wd * lerpf(0.1, 0.45, u)
		var dir := d.lerp(n, lerpf(0.05, 0.85, u)).normalized()
		var ln := span * lerpf(0.5, 0.34, u) * (1.0 - 0.45 * fold)
		var ash := 0.0 if rage < 0.0 else (0.35 + 0.35 * rage if i < 3 else 0.2 * rage)
		_feather(ci, xf, root, dir.angle(), ln, span * 0.12, col, ash)
		if rage > 0.0 and not Ink.mono:
			var tip := root + dir * ln * 0.92
			Ink.brush(ci, xf, PackedVector2Array([root + dir * ln * 0.55, tip]), 1.6, Color(Art.bc("braise"), (0.3 + 0.6 * rage) * (0.6 + 0.4 * pulse) * (1.0 - dk)))
	# Main et bras : bord d'attaque arrondi, bord de fuite festonné (rémiges secondaires).
	var pts := PackedVector2Array()
	var lead := [Vector2(0.0, -0.08), Vector2(0.18, -0.2), Vector2(0.42, -0.22), Vector2(0.66, -0.14), Vector2(0.86, -0.02), Vector2(0.94, 0.08)]
	for q: Vector2 in lead:
		pts.append(sh + d * span * q.x + n * span * wd * q.y)
	var nsec := 6
	for i in nsec + 1:
		var u := float(i) / nsec
		var x := lerpf(0.84, 0.08, u)
		var y := lerpf(0.5, 0.92, sin(u * PI * 0.5))
		pts.append(sh + d * span * x + n * span * wd * y)
		if i < nsec:
			var xm := lerpf(0.84, 0.08, u + 0.5 / nsec)
			pts.append(sh + d * span * xm + n * span * wd * (y + 0.3))
	pts.append(sh + n * span * wd * 0.6)
	Ink.part(ci, xf, pts, col, 2.2, 1.0, 0.55)
	if Ink.mono:
		return
	# Couvertures : rangées d'écailles de plumes, taches du harfang, et la cendre au bord de fuite.
	for r in 2:
		var row := PackedVector2Array()
		for i in 7:
			var u := float(i) / 6.0
			row.append(sh + d * span * lerpf(0.1, 0.74, u) + n * span * wd * (0.22 + 0.24 * r + 0.06 * sin(u * 9.0)))
		Ink.brush(ci, xf, row, 1.3, col["ombre"].darkened(0.2), 0.0, 0.0)
	for i in 4:
		var u := 0.22 + i * 0.16
		var p := sh + d * span * u + n * span * wd * (0.6 + 0.1 * (i % 2))
		Ink.flat(ci, xf, Ink.leaf(p - d * 2.5, a, 5.5, 2.6), Art.bc("vent", "ombre"))
	Ink.brush(ci, xf, PackedVector2Array([sh + d * span * 0.06 + n * span * wd * 0.05, sh + d * span * 0.5 - n * span * wd * 0.08, sh + d * span * 0.82]), 1.6, Color(col["reflet"], 0.7))
	if rage > 0.0:
		var edge := PackedVector2Array()
		for i in 7:
			var u := float(i) / 6.0
			edge.append(sh + d * span * lerpf(0.8, 0.12, u) + n * span * wd * lerpf(0.55, 0.95, sin(u * PI * 0.5)))
		Ink.brush(ci, xf, edge, 2.0 + 1.5 * rage, Color(Art.bc("braise"), (0.25 + 0.5 * rage) * (0.6 + 0.4 * pulse) * (1.0 - dk)))
		Ink.sparks(ci, xf, edge[3], Vector2(0.2, -1.0), 2 + int(2 * rage), t + side, 1.2, rage * (1.0 - dk))


## Tête de chouette (repère hx, centre de la tête) : ronde, disque facial pâle tourné vers nous, deux
## yeux de braise (l'œil du fond plus petit), bec crochu d'os, deux petites aigrettes rongées.
static func _head(ci: CanvasItem, hx: Transform2D, k: float, cri: float, hit: float, t: float, rage: float, dk: float, sleep: float, dive: float, gueri: bool) -> void:
	var blue := V.pal()
	# Aigrettes de cendre (silhouette de la charte : on les reconnaît de loin).
	for s: float in [-1.0, 1.0]:
		var b := Vector2(5.0 + 13.0 * s, -12)
		var tip_a := -PI / 2.0 + 0.45 * s + 0.12 * sin(t * 3.0 + s)
		Ink.part(ci, hx, Ink.leaf(b, tip_a, 13.0 + 3.0 * k, 7.0, 0.05 * s), blue, 1.6, 1.0, 0.0)
		if not Ink.mono and not gueri:
			var d := Vector2.from_angle(tip_a)
			Ink.flat(ci, hx, Ink.leaf(b + d * 9.0, tip_a, 5.0 + 3.0 * k, 4.0), Art.bc("ronge"))
	var skull := Ink.lumpy(Vector2(3, 1), 24.0, 19.0, 28, 0.05, 6.0)
	Ink.part(ci, hx, skull, blue, 2.4, 1.0, 0.7)
	# Disque facial : un masque pâle cerné d'une collerette sombre, tourné vers nous (trois quarts).
	var down := {"clair": Art.bc("vent", "duvet"), "ombre": Art.bc("vent", "aile"), "reflet": Color.WHITE}
	var disc := PackedVector2Array([Vector2(-12, -6), Vector2(-4, -12), Vector2(6, -6), Vector2(16, -13), Vector2(24, -6), Vector2(23, 6), Vector2(16, 14), Vector2(7, 17), Vector2(-3, 13), Vector2(-11, 5)])
	Ink.part(ci, hx, disc, down, 1.6, 1.0, 0.4)
	if not Ink.mono:
		# Collerette : un liseré bleu sombre autour du masque, et les rayons du disque.
		Ink.brush(ci, hx, PackedVector2Array([Vector2(-11, 6), Vector2(-3, 15), Vector2(8, 19), Vector2(18, 15), Vector2(24, 6)]), 2.4, Art.bc("vent", "plume"), 0.0, 0.0)
		for i in 5:
			var a := 1.0 + i * 0.35
			Ink.brush(ci, hx, PackedVector2Array([Vector2(7, 4) + Vector2.from_angle(a) * 6.0, Vector2(7, 4) + Vector2.from_angle(a) * 12.0]), 0.9, Art.bc("vent", "aile").darkened(0.2))
	# Yeux : fentes en amande de braise sous des arcades froncées en V vers le bec ; plus vifs pendant
	# une annonce ; fermés pendant le sommeil, à la mort, sous un coup.
	var glare := clampf(0.35 + 0.65 * k + 0.4 * dive + 0.2 * rage, 0.0, 1.0) * (1.0 - dk)
	var closed := sleep > 0.5 or dk > 0.6 or hit > 0.6 or (k == 0.0 and dive == 0.0 and Ink.blink(t, 2.3) > 0.0)
	for e: Vector3 in [Vector3(-3.0, -1.5, 0.75), Vector3(15.0, -2.0, 1.0)]:
		var c := Vector2(e.x, e.y)
		var r := 6.4 * e.z
		var inner := 1.0 if e.x < 6.0 else -1.0
		# Arcade : épaisse, du haut extérieur vers le bec (regard dur du rapace).
		if not gueri:
			Ink.brush(ci, hx, PackedVector2Array([c + Vector2(-r * 1.1 * inner, -r * 1.05), c + Vector2(0, -r * 0.8), c + Vector2(r * 1.05 * inner, -r * 0.15)]), 3.4 * e.z, Ink.encre(), 0.0, 1.0)
		if gueri and not closed:
			Ink.flat(ci, hx, Ink.oval(c, r * 0.9, r * 0.85, 14), Art.c("or"), 1.0)
			Ink.flat(ci, hx, Ink.oval(c + Vector2(inner * r * 0.1, 0), r * 0.4, r * 0.45, 10), Ink.encre())
			continue
		if closed:
			Ink.brush(ci, hx, PackedVector2Array([c + Vector2(-r, -r * 0.1), c + Vector2(0, r * 0.25), c + Vector2(r, -r * 0.1)]), 1.8 * e.z, Ink.encre())
		else:
			var tilt_e := 0.32 * inner
			Ink.ember(ci, hx, Ink.leaf(c - Vector2.from_angle(tilt_e) * r, tilt_e, r * 2.0, r * (1.0 + 0.25 * k)), glare)
			if not Ink.mono:
				Ink.flat(ci, hx, Ink.oval(c + Vector2(inner * r * 0.15, 0), r * 0.26, r * 0.62, 10), Ink.encre())
	# Bec crochu d'os, entre les yeux, qui s'ouvre pour le cri.
	var bone := {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.35), "reflet": Color.WHITE}
	var gape := 0.6 * cri + 0.25 * hit
	var low := Transform2D(gape, Vector2(5, 7)) * PackedVector2Array([Vector2(0, 0), Vector2(5.5, 1.0), Vector2(1.5, 4.0)])
	if gape > 0.05:
		Ink.part(ci, hx, low, bone, 1.0, 1.0, 0.0)
		if not Ink.mono:
			Ink.flat(ci, hx, PackedVector2Array([Vector2(5, 7), Vector2(11, 8), Vector2(5, 7) + Vector2(5.5, 1.0).rotated(gape)]), Art.bc("braise").darkened(0.15))
	var up := PackedVector2Array([Vector2(3, 2), Vector2(8, 2.5), Vector2(10.5, 7), Vector2(9, 12), Vector2(7.5, 8.5), Vector2(4, 7)])
	Ink.part(ci, hx, up, bone, 1.4, 1.0, 0.6)


## Patte emplumée (repère du corps) : hanche hip, côté s (-1 fond, 1 devant) ; pendante en vol,
## tendue en avant dans le piqué, à plat au sol quand il est posé.
static func _leg(ci: CanvasItem, xf: Transform2D, hip: Vector2, s: float, dive: float, tired: float, k: float, t: float) -> void:
	var down := {"clair": Art.bc("vent", "duvet"), "ombre": Art.bc("vent", "aile").darkened(0.1 if s > 0.0 else 0.3), "reflet": Color.WHITE}
	var foot := hip + Vector2(2.0, 18.0 + 2.0 * sin(t * 2.0 + s)).lerp(Vector2(22.0, 10.0), dive).lerp(Vector2(4.0 * s, 16.0), tired)
	# Pantalon de duvet (forme molle de la hanche au pied).
	var mid := hip.lerp(foot, 0.5)
	var leg := Ink.lumpy(mid, 8.0, (foot - hip).length() * 0.55 + 3.0, 16, 0.12, 6.0, s)
	var ang := (foot - hip).angle() - PI / 2.0
	Ink.part(ci, xf, Transform2D(ang, mid) * Transform2D(0.0, -mid) * leg, down, 1.8, 1.0, 0.0)
	# Serres d'os : trois crochets devant, un derrière ; ouvertes dans le piqué et l'annonce.
	var open := 0.35 + 0.65 * maxf(dive, k * 0.6) - 0.2 * tired
	var col := Art.bc("os").darkened(0.1 if s > 0.0 else 0.35)
	for j in 4:
		var a := (0.5 + (j - 1) * 0.55 * open) if j < 3 else (PI - 0.6)
		var b := foot + Vector2(0, 2)
		Ink.part(ci, xf, Ink.thorn(b, a + PI * 0.1 * dive, 8.0 if j < 3 else 6.0, 2.6, 0.35), {"clair": col.lightened(0.15), "ombre": col.darkened(0.3)}, 0.9, 1.0, 0.0)
