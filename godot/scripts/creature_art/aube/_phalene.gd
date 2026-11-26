## La Phalène de verre (boss d'Aube), direction « Bestiaire d'herbier » : une grande phalène des falaises,
## corps de fourrure d'or (la couleur de la région) et quatre ailes de vitre claire où la lumière de
## l'aube est restée prise. Vue de trois quarts, tournée vers la droite (le boss la retourne vers le
## joueur) : thorax laineux, abdomen annelé, antennes en plumes, deux gros yeux composés de braise ;
## un ocelle sur chaque aile antérieure, cerclé d'or, dont le cœur couve. La Flétrissure ronge le bord
## des ailes et le bout de l'abdomen. Phase 2 : la lumière court dans les nervures ; phase 3 : les ailes
## sont fêlées de braise et l'aile de devant est ébréchée, des éclats s'en détachent.
##
## Pas une sorte (le nom commence par « _ ») : le moteur ne la cuit pas, le boss la dessine (boss_aube.gd).
##
## Pose (clés de o) : t, alt (vol, unités au-dessus des pieds), beat (battement : -1 ailes basses → 1
## levées), open (ouverture : 0,6 repliées en toit, 1 ouvertes, 1,25 déployées vers le joueur), glow
## (lumière qui monte dans les ailes 0 → 1), k (intensité de l'annonce), rage (0 / 0,5 / 1), dk (mort),
## crack (ailes qui se brisent à la mort 0 → 1), sleep (yeux clos), hit, look, flip, gueri (la phalène
## vivante : ni cendre ni braise, yeux sombres).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/aube/verre.gd")

## 100 unités en px du jeu (1600×900). Envergure ≈ 1,7 × 100 unités.
const HEIGHT := 165.0

## Ailes dans leur repère (x le long du bord d'attaque, de l'épaule au bout ; y vers le bord de fuite).
const FORE := [Vector2(0.0, 0.0), Vector2(0.28, -0.12), Vector2(0.62, -0.16), Vector2(0.9, -0.1), Vector2(1.04, 0.04), Vector2(1.02, 0.2),
	Vector2(0.88, 0.38), Vector2(0.62, 0.5), Vector2(0.34, 0.5), Vector2(0.1, 0.32)]
const HIND := [Vector2(0.0, 0.0), Vector2(0.3, -0.04), Vector2(0.6, 0.06), Vector2(0.78, 0.28), Vector2(0.74, 0.52), Vector2(0.54, 0.7),
	Vector2(0.3, 0.68), Vector2(0.1, 0.46)]


static func fur() -> Dictionary:
	return {"clair": Art.bc("aube", "clair"), "ombre": Art.bc("aube", "ombre"), "reflet": Art.bc("aube", "reflet")}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var alt: float = o.get("alt", 40.0)
	var beat: float = o.get("beat", 0.0)
	var open: float = o.get("open", 1.0)
	var glow: float = o.get("glow", 0.0)
	var k: float = o.get("k", 0.0)
	var rage: float = o.get("rage", 0.0)
	var dk: float = o.get("dk", 0.0)
	var crack: float = o.get("crack", 0.0)
	var sleep: float = o.get("sleep", 0.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var gueri: bool = o.get("gueri", false)
	if gueri:
		rage = -1.0
	Ink.flash = hit
	Ink.ash = Anim.ease_out(clampf(dk * 1.4, 0.0, 1.0)) * 0.85
	var base := Ink.frame(feet, h, o.get("flip", false))
	var breath := sin(t * 2.6) * 0.025
	var tilt := -0.18 + 0.1 * hit - 0.12 * glow + 0.35 * dk
	var sq := Vector2(1.0 + breath + 0.05 * hit, 1.0 - breath - 0.05 * hit)
	var xf := base * Transform2D(0.0, Vector2(0, -alt - 30.0)) * Transform2D(tilt, sq, 0.0, Vector2.ZERO)
	var pulse := 0.5 + 0.5 * sin(t * (3.0 + 4.0 * maxf(rage, 0.0)))
	var light := clampf(glow + 0.3 * maxf(rage, 0.0) * pulse, 0.0, 1.0)
	# Halo de la lumière piégée, derrière tout, quand elle charge l'éclair.
	if not Ink.mono and glow > 0.05:
		Ink.halo(ci, xf * Vector2(-6, -24), 80.0 * h / 100.0 * (0.5 + 0.5 * glow), Art.bc("aube", "lueur"), glow * 1.6)
	# Ailes du fond : vers la droite, derrière la tête, raccourcies.
	_wing(ci, xf, Vector2(4, -8), -1.0, beat, open, 0.7, false, light, rage, crack, t)
	_wing(ci, xf, Vector2(6, -10), -1.0, beat, open, 0.7, true, light, rage, crack, t)
	# Abdomen annelé, vers l'arrière et le bas, bout rongé par la cendre.
	var segs := 6
	for i in segs:
		var u := float(i) / (segs - 1)
		var c := Vector2(-6.0 - 31.0 * u, 8.0 + 19.0 * u + 2.0 * sin(t * 2.0 + u * 2.0) * u)
		var rx := lerpf(11.0, 5.5, u)
		var col := fur()
		if i >= segs - 2 and not gueri:
			col = {"clair": Art.bc("aube", "ombre"), "ombre": Art.bc("ronge"), "reflet": Art.bc("aube", "clair")}
		Ink.part(ci, xf, Ink.lumpy(c, rx, rx * 0.85, 16, 0.08, 8.0, i), col, 1.8, 1.0, 0.3)
	if not gueri:
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-31, 22), Vector2(-35, 25), Vector2(-33, 29), Vector2(-38, 31)]), 1.4 + 1.2 * light, Art.bc("braise"))
		Ink.sparks(ci, xf, Vector2(-36, 30), Vector2(-0.2, 1.0), 2 + int(2 * rage), t, 1.4, 1.0 - dk)
	# Pattes fines (encre et or terni), qui pendent sous le vol et frémissent.
	for j in 3:
		var hip := Vector2(4.0 - j * 5.0, 10)
		var knee := hip + Vector2(6.0 - j * 4.0, 10.0 + 1.5 * sin(t * 5.0 + j))
		var foot := knee + Vector2(-2.0 - j, 11.0)
		var pts := PackedVector2Array([hip, knee, foot])
		Ink.brush(ci, xf, pts, 3.2, Ink.encre(), 1.0, 0.3)
		Ink.brush(ci, xf, pts, 1.6, Art.bc("aube", "ombre").lerp(Art.bc("ronge"), 0.4), 1.0, 0.3)
	# Thorax : une boule de fourrure, collerette laineuse.
	var thorax := Ink.lumpy(Vector2(2, -2), 15.0, 14.0, 34, 0.1, 17.0, 0.4)
	Ink.part(ci, xf, thorax, fur(), 2.4, 1.0, 0.6)
	if not Ink.mono:
		for i in 7:
			var a := -2.6 + i * 0.55
			var q := Vector2(2, -2) + Vector2.from_angle(a) * 10.0
			Ink.brush(ci, xf, PackedVector2Array([q, q + Vector2.from_angle(a + 0.4) * 5.0]), 1.1, Art.bc("aube", "ombre"))
	# Tête : elle suit la cible ; yeux composés de braise, antennes en plumes.
	var hl := clampf(look, -0.5, 0.5) * 0.5
	var hx := xf * Transform2D(hl, Vector2(15, -11))
	_head(ci, hx, k, light, hit, t, dk, sleep, gueri)
	# Ailes de devant : vers la gauche, par-dessus le corps (le verre le laisse voir).
	_wing(ci, xf, Vector2(-4, -6), 1.0, beat, open, 1.0, false, light, rage, crack, t)
	_wing(ci, xf, Vector2(-2, -9), 1.0, beat, open, 1.0, true, light, rage, crack, t)
	# Phase 3 et mort : des éclats de verre se détachent et tombent en scintillant.
	if not Ink.mono and (rage >= 1.0 or dk > 0.0):
		for i in 7:
			var u := fposmod(t * 0.5 + i / 7.0, 1.0)
			var q := xf * Vector2(sin(i * 2.4) * 80.0, -40.0 + 110.0 * u)
			var sz := (4.0 + 2.0 * (i % 3)) * (1.0 - 0.4 * u) * h / 100.0
			var rot := t * 3.0 + i
			var shard := PackedVector2Array([q + Vector2(0, -sz).rotated(rot), q + Vector2(sz * 0.5, 0).rotated(rot), q + Vector2(0, sz * 0.8).rotated(rot), q + Vector2(-sz * 0.4, 0).rotated(rot)])
			Ink._poly(ci, shard, Color(Art.bc("aube", "verre"), 1.0 - u))
			V.sparkle(ci, q, sz * 0.9, Art.bc("aube", "lueur"), (1.0 - u) * maxf(0.0, sin(t * 6.0 + i)))


## Aile (repère du corps) : épaule sh, côté side (1 : devant, vers la gauche ; -1 : fond, vers la droite),
## antérieure (fore) ou postérieure ; battement beat, ouverture open, raccourci persp ; light : la lumière
## monte dans le verre ; rage : fêlures de braise ; crack : à la mort, l'aile se fend.
static func _wing(ci: CanvasItem, xf: Transform2D, sh: Vector2, side: float, beat: float, open: float, persp: float, fore: bool, light: float, rage: float, crack: float, t: float) -> void:
	var up := (0.55 if fore else 0.05) + 0.55 * beat + (0.25 if fore else 0.12) * (1.0 - open)
	var a := PI + up if side > 0.0 else -up
	var span := (78.0 if fore else 54.0) * persp * lerpf(0.8, 1.12, clampf((open - 0.6) / 0.65, 0.0, 1.0))
	var d := Vector2.from_angle(a)
	var n := d.orthogonal() * (1.0 if side > 0.0 else -1.0)
	if n.y < -0.3 and absf(d.y) < 0.95:
		n = -n
	var wd := 0.9 if fore else 1.0
	var shape: Array = FORE if fore else HIND
	var pts := PackedVector2Array()
	for i in shape.size():
		var q: Vector2 = shape[i]
		# Phase 3 (et mort) : l'aile antérieure de devant est ébréchée au bord de fuite.
		if fore and side > 0.0 and rage >= 1.0 and i == 6:
			q = q.lerp(Vector2(0.6, 0.2), 0.45)
		pts.append(sh + d * span * q.x + n * span * wd * q.y)
	var far := side < 0.0
	var tint := Art.bc("aube", "verre").lerp(Art.bc("aube", "lueur"), 0.65 * light)
	if far:
		tint = tint.lerp(Art.bc("aube", "verre_ombre"), 0.35)
	var alpha := (0.62 if fore else 0.55) * (1.0 - 0.45 * crack)
	# Nervures : de l'épaule vers le bord, plus claires quand la lumière monte.
	var veins := []
	for i in range(3, shape.size() - 1, 2 if fore else 2):
		veins.append(PackedVector2Array([sh + d * span * 0.08, pts[i].lerp(sh, 0.12)]))
	V.pane(ci, xf, pts, tint, alpha, 1.6, veins)
	if Ink.mono:
		return
	# Bande de verre fumé le long du bord de fuite (la vitre s'assombrit vers le bord).
	var band := PackedVector2Array()
	for i in range(shape.size() - 4, shape.size()):
		band.append(pts[i])
	for i in range(shape.size() - 1, shape.size() - 5, -1):
		band.append(pts[i].lerp(sh, 0.3))
	Ink._poly(ci, xf * band, Color(Art.bc("aube", "verre_ombre"), 0.22 * (1.0 - light)))
	# Bord rongé par la Flétrissure : taches de cendre au bord de fuite (pas sur la forme guérie).
	if rage >= 0.0:
		for j in 2:
			var q: Vector2 = pts[6 + j] if fore else pts[4 + j]
			Ink.flat(ci, xf, Ink.lumpy(q.lerp(sh, 0.1), 3.4, 2.4, 12, 0.4, 3.0, j), Color(V.ash(), 0.85))
	# Lumière dans les nervures (phase 2 et plus, ou pendant une charge).
	var shine := clampf(light + 0.4 * maxf(rage, 0.0), 0.0, 1.0)
	if shine > 0.05:
		for v: PackedVector2Array in veins:
			Ink.brush(ci, xf, v, 1.6, Color(Art.bc("aube", "lueur"), 0.8 * shine), 0.4, 0.0)
	# Fêlures de braise (phase 2 : une ; phase 3 : trois), et la cassure de la mort.
	var n_cracks := 0 if rage < 0.5 else (1 if rage < 1.0 else 3)
	if crack > 0.0:
		n_cracks = 3
	for j in n_cracks:
		var edge: Vector2 = pts[4 + j] if fore else pts[3 + j % 2]
		var mid := edge.lerp(sh, 0.35) + n * span * 0.06 * (j - 1)
		var deep := edge.lerp(sh, 0.55 + 0.25 * crack)
		var col := Art.bc("braise") if crack < 0.5 else Art.bc("aube", "lueur")
		Ink.brush(ci, xf, PackedVector2Array([edge, mid, deep]), 1.4 + 0.8 * crack, Color(col, 0.9))
	# Ocelle de l'aile antérieure : un œil cerclé d'or dont le cœur couve (braise = ennemi ; lumière en charge).
	if fore:
		var c := sh + d * span * 0.58 + n * span * wd * 0.2
		var r := span * 0.095
		var ring := Ink.oval(c, r, r * 0.9, 18, a)
		Ink.part(ci, xf, ring, {"clair": Art.bc("aube", "clair"), "ombre": Art.bc("aube", "ombre"), "reflet": Art.bc("aube", "reflet")}, 1.2, 1.0, 0.5)
		var inner := Ink.oval(c, r * 0.55, r * 0.5, 14, a)
		if rage < 0.0:
			Ink.flat(ci, xf, inner, Art.bc("aube", "ombre").darkened(0.4))
		elif light > 0.5:
			Ink.flat(ci, xf, inner, Art.bc("aube", "lueur"))
			Ink.halo(ci, xf * c, r * 2.2 * xf.get_scale().abs().x, Art.bc("aube", "lueur"), light)
		else:
			Ink.flat(ci, xf, inner, Art.bc("aube", "ombre").darkened(0.45))
			Ink.ember(ci, xf, Ink.oval(c, r * 0.25, r * 0.22, 10, a), 0.15 + 0.4 * light + 0.3 * maxf(rage, 0.0))
		# Éclat qui court sur le verre.
		var g := maxf(0.0, sin(t * 1.7 + side * 2.0)) ** 6.0
		if g > 0.05:
			V.sparkle(ci, xf * (sh + d * span * 0.85 + n * span * 0.05), 7.0 * g * xf.get_scale().abs().x, Art.bc("aube", "lueur"), g)


## Tête (repère hx) : ronde et laineuse, deux gros yeux composés (braise, plus vifs en annonce), trompe
## enroulée, antennes en plumes qui frémissent.
static func _head(ci: CanvasItem, hx: Transform2D, k: float, light: float, hit: float, t: float, dk: float, sleep: float, gueri: bool) -> void:
	# Antennes : tige d'or, barbes de part et d'autre.
	for s: float in [-1.0, 1.0]:
		var b := Vector2(2.0 + 3.0 * s, -7)
		var tip := b + Vector2(14.0 + 4.0 * s, -26.0 + 4.0 * s).rotated(0.08 * sin(t * 3.0 + s) - 0.25 * k)
		var stem := PackedVector2Array([b, b.lerp(tip, 0.5) + Vector2(-2, -2), tip])
		Ink.brush(ci, hx, stem, 2.6, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, hx, stem, 1.3, Art.bc("aube", "clair").darkened(0.1 if s > 0.0 else 0.3), 1.0, 0.0)
		if not Ink.mono:
			for j in 6:
				var u := 0.25 + 0.12 * j
				var q := b.lerp(tip, u)
				var dd := (tip - b).normalized()
				var nn := dd.orthogonal()
				var l := 6.0 * sin(PI * u)
				Ink.brush(ci, hx, PackedVector2Array([q, q + (nn + dd * 0.4) * l]), 0.9, Art.bc("aube", "clair").darkened(0.2))
				Ink.brush(ci, hx, PackedVector2Array([q, q + (-nn + dd * 0.4) * l]), 0.9, Art.bc("aube", "clair").darkened(0.2))
	var skull := Ink.lumpy(Vector2(0, 0), 10.0, 9.0, 24, 0.12, 12.0)
	Ink.part(ci, hx, skull, fur(), 2.2, 1.0, 0.5)
	# Trompe enroulée sous la tête.
	if not Ink.mono:
		Ink.tendril(ci, hx, Vector2(7, 6), 1.2, 9.0, 0.9, 1.4, Art.bc("aube", "ombre").darkened(0.2))
	# Yeux composés : le proche grand, le lointain à demi caché.
	var closed := sleep > 0.5 or dk > 0.6
	var glare := clampf(0.35 + 0.65 * maxf(k, light), 0.0, 1.0) * (1.0 - dk)
	for e: Vector3 in [Vector3(2.0, -1.0, 0.7), Vector3(7.0, 0.0, 1.0)]:
		var c := Vector2(e.x, e.y)
		var r := 6.0 * e.z
		var eye := Ink.oval(c, r, r * 1.05, 16)
		if gueri:
			Ink.part(ci, hx, eye, {"clair": Art.bc("aube", "ombre").darkened(0.3), "ombre": Ink.encre(), "reflet": Color.WHITE}, 1.0, 1.0, 1.0)
		elif closed:
			Ink.part(ci, hx, eye, {"clair": Art.bc("ronge").lightened(0.15), "ombre": Art.bc("ronge")}, 1.0, 1.0, 0.0)
			Ink.brush(ci, hx, PackedVector2Array([c + Vector2(-r * 0.8, 0), c + Vector2(r * 0.8, r * 0.2)]), 1.2, Art.bc("braise").darkened(0.3))
		else:
			Ink.ember(ci, hx, eye, glare)
			if not Ink.mono:
				# Facettes : un fin quadrillage d'encre.
				for j in 2:
					Ink.brush(ci, hx, PackedVector2Array([c + Vector2(-r * 0.7, (j - 0.5) * r * 0.7), c + Vector2(r * 0.7, (j - 0.5) * r * 0.7)]), 0.6, Color(Ink.encre(), 0.45))
					Ink.brush(ci, hx, PackedVector2Array([c + Vector2((j - 0.5) * r * 0.7, -r * 0.7), c + Vector2((j - 0.5) * r * 0.7, r * 0.7)]), 0.6, Color(Ink.encre(), 0.45))
