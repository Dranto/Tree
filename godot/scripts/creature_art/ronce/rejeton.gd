## Rejeton (Ronce, essaim), direction « Bestiaire d'herbier » : la larve que pond le Nid de ronces, une
## chenille de tenthrède rongée par la Flétrissure. Petite et simple : un corps annelé couleur de mûre,
## une épine d'os en crochet sur le dos, deux yeux de braise. Elle ondule en rampant (l'onde court de la
## queue vers la tête) et se jette sur le héros au contact.
##
## Pose : t, walk (radians), moving (0 → 1), hit (1 → 0), look, strike (morsure 0 → 1, -1 : aucune),
##   elite, mono.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const O = preload("res://scripts/creature_art/ronce/_outils.gd")

## 100 unités en px du jeu (1600×900) : ~30 px de haut à l'écran en 1080p (essaim ≥ 28).
const HEIGHT := 26.0
const SEGMENTS := 5
## L'élite : collier et liseré dessinés ici (contrat moteur).
const DRAWS_ELITE := true
const NECK := Vector2(10, -60)


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var hit: float = o.get("hit", 0.0)
	var strike: float = o.get("strike", -1.0)
	var elite: bool = o.get("elite", false)
	var fl: Array = O.aim(o.get("look", 0.0))
	var la: float = fl[1]
	Ink.flash = hit
	var base := Ink.frame(feet, h, fl[0])
	Ink.ground_shadow(ci, base, Vector2(-8, 0), 40.0)
	# Bond de la morsure : elle se ramasse puis se détend vers l'avant.
	var lunge := 0.0
	if strike >= 0.0:
		lunge = sin(PI * strike) * 16.0
	var sq := Vector2(1.0 + 0.14 * hit + lunge * 0.006, 1.0 - 0.16 * hit - lunge * 0.004)
	var xf := base * Transform2D(0.0, sq, 0.0, Vector2(lunge, 0))
	# Le corps : anneaux du plus gros (milieu) au plus petit (queue), soulevés par l'onde de reptation.
	var rings := []
	for i in SEGMENTS:
		var u := float(i) / (SEGMENTS - 1)
		# La tête se dresse (S de la chenille qui guette) ; l'onde la balance d'avant en arrière.
		var rear := smoothstep(0.35, 1.0, u) * (44.0 - 6.0 * hit)
		var x := lerpf(-44.0, 12.0, u) - rear * 0.18 + sin(walk - u * 2.6) * 3.0 * mv * u
		var wave := maxf(sin(walk - u * 2.6), 0.0) * 8.0 * mv * (1.0 - u * 0.6)
		var r := lerpf(14.0, 19.0, sin(PI * (0.2 + 0.55 * u)))
		rings.append(Vector3(x, -r - 2.0 - wave - rear, r))
	var hull := PackedVector2Array()
	for i in SEGMENTS:
		var c: Vector3 = rings[i]
		var ring := Ink.oval(Vector2(c.x, c.y), c.z * 0.95, c.z, 20)
		hull = ring if hull.is_empty() else _union(hull, ring)
	if elite:
		O.rim(ci, xf, hull, 2.4)
	# Fausses pattes sous les anneaux posés, qui s'accrochent tour à tour ; petites pattes griffues
	# sous les anneaux dressés.
	var legc := Art.bc("ronce", "ombre").darkened(0.4)
	for i in SEGMENTS:
		var c: Vector3 = rings[i]
		var u := float(i) / (SEGMENTS - 1)
		var lift := maxf(sin(walk - u * 2.6), 0.0) * 4.0 * mv
		var top := Vector2(c.x, c.y + c.z * 0.7)
		var tip := Vector2(c.x + 2.0, -1.0 - lift)
		if tip.y - top.y > 14.0:
			tip = top + Vector2(7.0, 9.0 + 2.0 * sin(t * 6.0 + i))
		Ink.brush(ci, xf, PackedVector2Array([top, tip]), 6.6, Ink.encre(), 1.0, 0.6)
		Ink.brush(ci, xf, PackedVector2Array([top, tip]), 4.2, legc, 1.0, 0.5)
	# Épine en crochet sur le dos (derrière le corps), qui se dresse sous le coup.
	var back: Vector3 = rings[2]
	var hook := Ink.thorn(Vector2(back.x - 4.0, back.y - back.z * 0.6), -PI * 0.68 - 0.25 * hit, 34.0, 13.0, 0.5)
	Ink.part(ci, xf, hook, O.bone(), 2.0, 1.0, 0.6)
	Ink.part(ci, xf, hull, O.pal(), 2.6, 1.0, 0.8)
	# Plis entre les anneaux, et la Flétrissure qui ronge la queue.
	for i in range(1, SEGMENTS):
		var c: Vector3 = rings[i]
		var p: Vector3 = rings[i - 1]
		var m := Vector2(c.x + p.x, c.y + p.y) * 0.5
		var ax := Vector2(c.x - p.x, c.y - p.y).normalized()
		var nn := ax.orthogonal()
		var rr := (c.z + p.z) * 0.5 * 0.82
		Ink.brush(ci, xf, PackedVector2Array([m + nn * rr, m + nn * rr * 0.1 + ax * 3.0, m - nn * rr]), 1.5, Art.bc("ronce", "ombre").darkened(0.25))
	var tail: Vector3 = rings[0]
	Ink.flat(ci, xf, Ink.lumpy(Vector2(tail.x - 4.0, tail.y + 2.0), 9.0, 10.0, 18, 0.35, 5.0, 0.4), Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(tail.x - 9.0, tail.y - 2.0), Vector2(tail.x - 4.0, tail.y + 3.0), Vector2(tail.x - 6.0, tail.y + 8.0)]), 1.8, Art.bc("braise"))
	# Points clairs sur le dos (les drupes de la mûre, en petit).
	if not Ink.mono:
		for i in range(1, SEGMENTS):
			var c: Vector3 = rings[i]
			ci.draw_circle(xf * Vector2(c.x - c.z * 0.3, c.y - c.z * 0.55), 2.0 * xf.get_scale().abs().x, Ink.shade(Color(Art.bc("ronce", "reflet"), 0.7)))
	if elite:
		# Collier autour du cou : l'anneau entre le corps et la tête, perpendiculaire au corps.
		var n0: Vector3 = rings[SEGMENTS - 2]
		var n1: Vector3 = rings[SEGMENTS - 1]
		var nc := Vector2(n0.x + n1.x, n0.y + n1.y) * 0.5 + Vector2(4.0, 0.0)
		var ang := Vector2(n1.x - n0.x, n1.y - n0.y).angle()
		O.collar(ci, O.turn(xf, nc, ang), nc, 5.0, n0.z * 0.95, t, o.get("region", "ronce"))
	# Tête : le dernier anneau porte les mandibules et les yeux, et suit la cible.
	var head: Vector3 = rings[SEGMENTS - 1]
	var hp := Vector2(head.x + 15.0, head.y - 4.0)
	var hx := O.turn(xf, hp, clampf(la, -0.4, 0.5) * 0.6)
	var hshape := Ink.lumpy(hp, 15.0, 14.0, 22, 0.04, 4.0)
	if elite:
		O.rim(ci, hx, hshape, 2.4)
	Ink.part(ci, hx, hshape, O.pal(0.12), 2.4, 1.0, 0.7)
	# Mandibules d'os, qui claquent (plus vite en morsure).
	var snap := 0.5 + 0.5 * sin(t * (9.0 if strike < 0.0 else 30.0))
	for j in 2:
		var a := (0.25 if j == 0 else 0.9) - (0.35 * snap if j == 0 else -0.25 * snap)
		Ink.part(ci, hx, Ink.thorn(hp + Vector2(11.0, 3.0 + j * 4.0), a, 12.0, 4.6, 0.45 if j == 0 else -0.45), O.bone(), 1.1, 1.0, 0.0)
	# Bourgeon sec sur la tête : deux petits sépales.
	for j in 2:
		Ink.part(ci, hx, Ink.leaf(hp + Vector2(-4.0 + j * 5.0, -12.0), -PI * 0.5 - 0.5 + j * 0.7 + 0.15 * sin(t * 3.0 + j), 11.0, 5.0, 0.1), O.stem(), 1.2, 1.0, 0.3)
	var glow := 0.55 + 0.45 * (1.0 if strike >= 0.0 else 0.0)
	O.eye(ci, hx, hp + Vector2(3.0, -2.0), -0.2, 8.0, 5.0, glow, hit, t, 0.0, 0.7 + head.x * 0.01)
	O.eye(ci, hx, hp + Vector2(11.5, -3.5), -0.3, 4.5, 3.2, glow, hit, t, 0.0, 0.7 + head.x * 0.01)


static func _union(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var u := Geometry2D.merge_polygons(a, b)
	var best := a
	var area := -1.0
	for p in u:
		var r := _area(p)
		if r > area:
			area = r
			best = p
	return best


static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		s += p[i].cross(p[(i + 1) % p.size()])
	return absf(s) * 0.5
