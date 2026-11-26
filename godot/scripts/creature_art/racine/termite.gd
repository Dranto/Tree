## Termite de cendre (Racine, essaim), « Bestiaire d'herbier » : un termite soldat de la forêt pétrifiée,
## au ventre pâle de cendre où la braise de la Flétrissure couve entre les anneaux. Tête de bois sombre,
## deux mandibules d'os en faucille : le signe qu'il mord au contact. Petit, simple, il trotte vite.
## Frappe (contact) : il se jette en avant et ses mandibules claquent.
##
## Pose : t, walk, moving, strike (0 → 1 après la morsure, -1 : aucune), hit (ou flash), look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const R = preload("res://scripts/creature_art/racine/outils.gd")

## 100 unités en px du jeu (1600×900) : ~42 px de long à l'écran en 1080p.
const HEIGHT := 30.0
const DRAWS_ELITE := true


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var p := R.read(o)
	var t: float = p["t"]
	var walk: float = p["walk"]
	var mv: float = p["mv"]
	var hit: float = p["hit"]
	var strike: float = p["strike"]
	Ink.flash = hit
	var base := Ink.frame(feet, h, p["flip"])
	# Ombre serrée sous le corps : une grande ombre noyait ce petit Flétri dans le sol sombre de la forêt.
	Ink.ground_shadow(ci, base, Vector2(-6, 0), 24.0)
	# Morsure : élan vers l'avant, puis retour. Trot : petit rebond rapide.
	var bite := 0.0 if strike < 0.0 else sin(PI * clampf(strike * 1.6, 0.0, 1.0))
	var bob := -absf(sin(walk * 2.0)) * 2.4 * mv
	var sq := Vector2(1.0 + 0.12 * hit + 0.08 * bite, 1.0 - 0.14 * hit - 0.04 * bite)
	var xf := base * Transform2D(-0.05 * bite + 0.06 * hit, sq, 0.0, Vector2(8.0 * bite, bob))
	var cen := R.pal("cendre")
	var legc := Art.bc("racine", "bois").lightened(0.1)
	# Pattes du fond : trépied alterné, battement rapide.
	for i in 3:
		var ph := walk * 2.0 + (0.0 if i % 2 else PI)
		R.leg(ci, base, xf * Vector2(-8 + i * 9, -14), Vector2(-24 + i * 20 + sin(ph) * 7.0 * mv, -1.5 - maxf(cos(ph), 0.0) * 3.0 * mv), legc.darkened(0.3), 0.85)
	# Abdomen : un ovale mou, annelé, qui respire.
	var breath := 1.0 + 0.04 * sin(t * TAU / 1.3)
	var abd := Ink.lumpy(Vector2(-28, -21), 23.0, 13.0 * breath, 36, 0.05, 6.0)
	Ink.part(ci, xf, abd, cen, 2.4, 1.0, 0.8)
	# Braise entre les anneaux : elle bat comme un cœur.
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	for i in 4:
		var x := -44.0 + i * 9.0
		var ring := PackedVector2Array([Vector2(x + 2, -34 + absf(i - 1.5) * 2.0), Vector2(x - 1, -22), Vector2(x + 2, -9)])
		Ink.brush(ci, xf, ring, 2.6, cen["ombre"].darkened(0.2))
		if not Ink.mono and i > 0:
			Ink.brush(ci, xf, ring, 1.0, Color(Art.bc("braise"), 0.45 + 0.4 * pulse))
	# Bout de l'abdomen rongé : la Flétrissure.
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-48, -20), 5.0, 6.0, 14, 0.3, 5.0), Art.bc("ronge"))
	Ink.sparks(ci, xf, Vector2(-50, -26), Vector2(-0.3, -1.0), 2, t * 1.4, 1.2, 0.7)
	# Thorax.
	Ink.part(ci, xf, Ink.oval(Vector2(0, -22), 10.0, 9.0, 18), cen, 2.0, 1.0, 0.6)
	# Tête de bois sombre (soldat), qui suit la cible.
	var head_rot := clampf(p["la"], -0.3, 0.3) * 0.7 - 0.08 * bite
	var hx := xf * Transform2D(head_rot, Vector2(12, -24)) * Transform2D(0.0, Vector2(-12, 24))
	# Antennes en chapelet, qui tâtent l'air.
	for j in 2:
		var sway := sin(t * 7.0 + j * 1.7) * 0.25
		var a0 := -1.25 - j * 0.4 + sway
		var r0 := Vector2(24 - j * 2, -38)
		var r1 := r0 + Vector2.from_angle(a0) * 12.0
		var r2 := r1 + Vector2.from_angle(a0 + 0.9) * 10.0
		Ink.brush(ci, hx, PackedVector2Array([r0, r1, r2]), 2.4, Ink.encre(), 1.0, 1.0)
		if not Ink.mono:
			for q: Vector2 in [r0.lerp(r1, 0.5), r1, r1.lerp(r2, 0.5), r2]:
				ci.draw_circle(hx * q, 0.9 * h / 100.0, Ink.shade(cen["clair"].darkened(0.2 * j)))
	var head := Ink.lumpy(Vector2(25, -27), 17.0, 11.0, 26, 0.04, 4.0)
	Ink.part(ci, hx, head, R.pal("bois"), 2.4, 1.0, 1.0)
	Ink.brush(ci, hx, PackedVector2Array([Vector2(14, -34), Vector2(24, -38), Vector2(34, -33)]), 1.2, Art.bc("racine", "bois").lightened(0.45))
	# Mandibules en faucille : entrouvertes en trottant, grandes ouvertes juste avant la morsure, qui claquent.
	var gape := 0.18 + 0.12 * sin(t * 9.0) * (1.0 - bite)
	if strike >= 0.0:
		gape = lerpf(0.55, -0.05, clampf(strike * 3.0, 0.0, 1.0))
	for j in 2:
		var s := 1.0 if j == 0 else -1.0
		var root := Vector2(39, -24 - s * 3.0)
		var mand := _sickle(root, -s * gape + (0.1 if j else 0.0), 27.0 - j * 4.0, s)
		Ink.part(ci, hx, mand, R.pal("os"), 1.6, 1.0, 0.6)
	# Œil de braise, petit et plissé.
	if hit > 0.4 or Ink.blink(t, 2.3) > 0.0:
		Ink.brush(ci, hx, PackedVector2Array([Vector2(26, -30), Vector2(32, -29)]), 1.8, Ink.encre())
	else:
		Ink.ember(ci, hx, Ink.leaf(Vector2(26, -30), -0.2, 6.5, 3.4), 0.12 + 0.5 * bite)
	if p["elite"]:
		R.elite(ci, xf, Vector2(4, -34), Vector2(12, -11), 2.0, PackedVector2Array([Vector2(-54, -26), Vector2(-40, -37), Vector2(-20, -37)]), t, 0.7)
	# Pattes de devant.
	for i in 3:
		var ph := walk * 2.0 + (PI if i % 2 else 0.0)
		R.leg(ci, base, xf * Vector2(-6 + i * 9, -11), Vector2(-22 + i * 21 + sin(ph) * 7.0 * mv, -maxf(cos(ph), 0.0) * 3.5 * mv), legc, 0.85)


## Mandibule en faucille, de la base root, ouverte de l'angle a, longueur l ; s : haut (1) ou bas (-1).
static func _sickle(root: Vector2, a: float, l: float, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		var ang := a + s * 0.9 * u * u
		var q := root + Vector2.from_angle(ang) * l * u
		var wv := 3.4 * (1.0 - u) + 0.3
		pts.append(q + Vector2.from_angle(ang - s * PI / 2.0) * wv)
		inner.append(q + Vector2.from_angle(ang + s * PI / 2.0) * wv * 0.6)
	inner.reverse()
	pts.append_array(inner)
	return pts
