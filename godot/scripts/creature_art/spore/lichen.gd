## Lichen cuirassé (Spore, lourd), « Bestiaire d'herbier » : un vieux cloporte des souches, grand comme une
## tortue, dont la carapace à plaques a été recouverte de lichen et de polypores ; la Flétrissure couve
## dans les jointures. La croûte boit le poison. Large et ancré : quatre pattes trapues, tête basse.
## Annonce (windup) : il se dresse sur ses pattes arrière, l'avant levé, les jointures rougeoient ;
## frappe (strike) : il s'abat de tout son poids (onde au sol, éclats de croûte).
##
## Pose : t, walk, moving, k (annonce 0 → 1), strike (0 → 1 après la frappe, -1 : aucune), hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const Sp = preload("res://scripts/creature_art/spore/outils.gd")

## 100 unités (la hauteur) en px du jeu : ~72 px de haut et ~108 px de long en 1080p (lourd).
const HEIGHT := 60.0
## La sorte dessine elle-même son collier d'élite (pose elite).
const DRAWS_ELITE := true
## Il ne tourne presque pas la tête : un seul regard cuit (atlas moitié moins lourd).
const LOOKS := false


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var elite: bool = o.get("elite", false)
	var flip := cos(look) < 0.0
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	var kk := Anim.ease_out(k)
	var slam := 0.0 if strike < 0.0 else 1.0 - strike
	Ink.ground_shadow(ci, base, Vector2(0, 0), 72.0)
	# Onde de choc et éclats de croûte après la frappe.
	if strike >= 0.0 and not Ink.mono:
		var u := Anim.ease_out(strike)
		var ring := Ink.oval(Vector2(36, 0), 44.0 + 26.0 * u, (44.0 + 26.0 * u) * Art.OMBRE_APLATI, 36)
		ring.append(ring[0])
		var s := base.get_scale().abs().x
		ci.draw_polyline(base * ring, Color(Art.bc("braise"), 0.75 * slam), 4.0 * s, true)
		ci.draw_polyline(base * ring, Color(Art.bc("spore", "lichen"), 0.5 * slam), 1.6 * s, true)
		for i in 7:
			var a := -PI * (0.15 + 0.7 * i / 6.0)
			var q := Vector2(60, -4) + Vector2(cos(a) * 30.0 * u, sin(a) * 30.0 * sin(PI * u))
			Ink.flat(ci, base, Ink.lumpy(q, 3.0, 2.4, 6, 0.3, 3.0, i), Art.bc("spore", "lichen_ombre").lerp(Art.bc("spore", "lichen"), 0.4 * (i % 2)), 0.8)
	# Il se dresse (pivot sur les pattes arrière) pendant l'annonce, s'écrase à la frappe.
	var rear := -0.38 * kk * (1.0 - slam) + 0.06 * slam
	var rock := sin(walk) * 0.03 * mv
	var sq := Vector2(1.0 + 0.06 * hit + 0.08 * slam, 1.0 - 0.08 * hit - 0.1 * slam)
	var piv := Vector2(-46, -12)
	var xf := base * Transform2D(0.0, piv) * Transform2D(rear + rock + 0.04 * hit, sq, 0.0, Vector2.ZERO) * Transform2D(0.0, -piv)
	var shell := Sp.flesh()
	# Carapace un peu plus claire que la région, pour ressortir aussi sur le marais ravivé.
	shell["clair"] = shell["clair"].lightened(0.1)
	shell["ombre"] = shell["ombre"].lightened(0.18)
	shell = {"clair": shell["clair"].lerp(Art.bc("spore", "lichen_ombre"), 0.35), "ombre": shell["ombre"].darkened(0.1), "reflet": shell["reflet"]}
	var leg := Art.bc("spore", "ombre").darkened(0.2)
	# Pattes du fond (plus sombres), puis carapace, puis pattes de devant.
	var step := walk
	for i in 2:
		var x := -34.0 + i * 60.0
		_leg(ci, base, xf, Vector2(x + 8, -22), Vector2(x + 14 + sin(step + i * PI) * 8.0 * mv, -2.0 - maxf(sin(step + i * PI), 0.0) * 6.0 * mv), leg.darkened(0.3), i == 1, kk)
	# Tête basse sous le bord de la carapace, qui suit un peu la cible.
	var hl := 0.0
	var head := Transform2D(hl, Vector2(62, -24))
	var hp := PackedVector2Array([Vector2(-8, -14), Vector2(8, -16), Vector2(20, -10), Vector2(24, 0), Vector2(18, 10), Vector2(0, 12), Vector2(-8, 8)])
	Ink.part(ci, xf, head * hp, {"clair": leg.lightened(0.2), "ombre": leg.darkened(0.2), "reflet": leg.lightened(0.5)}, 2.2, 1.0, 0.4)
	# Antennes courtes et yeux de braise.
	for s: float in [0.0, 1.0]:
		var b := head * Vector2(16, -10 + s * 3.0)
		var tip := b + Vector2.from_angle(-0.7 + s * 0.5 + 0.15 * sin(t * 2.5 + s) - 0.4 * kk) * 22.0
		Ink.brush(ci, xf, PackedVector2Array([b, b.lerp(tip, 0.5) + Vector2(0, -3), tip]), 3.4, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, xf, PackedVector2Array([b, b.lerp(tip, 0.5) + Vector2(0, -3), tip]), 2.0, leg.lightened(0.35 - 0.2 * s), 1.0, 0.0)
	if hit > 0.4 or (k == 0.0 and Ink.blink(t, 0.2) > 0.0):
		Ink.brush(ci, xf, head * PackedVector2Array([Vector2(8, -4), Vector2(16, -3)]), 2.4, Ink.encre())
	else:
		Ink.ember(ci, xf, head * Ink.leaf(Vector2(7, -4), -0.1, 9.0, 4.4), 0.3 + 0.7 * kk)
		Ink.ember(ci, xf, head * Ink.leaf(Vector2(17, -3), -0.2, 5.0, 3.0), 0.3 + 0.7 * kk)
	# Carapace : dôme long à plaques (segments du cloporte), bord qui retombe sur la tête.
	var dome := PackedVector2Array()
	for i in 25:
		var u := i / 24.0
		var x := lerpf(-74.0, 74.0, u)
		var y := -12.0 - 66.0 * pow(sin(PI * u), 0.75) - 4.0 * sin(PI * u * 7.0) * sin(PI * u)
		dome.append(Vector2(x, y))
	dome.append(Vector2(70, -10))
	dome.append(Vector2(0, -6))
	dome.append(Vector2(-70, -10))
	Ink.part(ci, xf, dome, shell, 3.0, 1.0, 0.6)
	# Jointures des plaques : des arcs, fendus de braise qui rougeoie à l'annonce.
	for i in 6:
		var x := -52.0 + i * 21.0
		var top := -12.0 - 66.0 * pow(sin(PI * (x + 74.0) / 148.0), 0.75)
		var arc := PackedVector2Array([Vector2(x - 3, top + 2), Vector2(x + 1, (top - 10) * 0.5), Vector2(x - 2, -10)])
		Ink.brush(ci, xf, arc, 1.8, shell["ombre"].darkened(0.35), 0.0, 0.0)
		Ink.brush(ci, xf, Transform2D(0.0, Vector2(-1.6, 0)) * arc, 1.0, shell["clair"].lightened(0.15), 0.0, 0.0)
		# La braise ne couve que dans le bas des jointures (là où la croûte se fend).
		if i % 2 == 1:
			var crack := PackedVector2Array([arc[1].lerp(arc[2], 0.35), arc[2] + Vector2(0, -2)])
			Ink.brush(ci, xf, crack, 2.2 + 1.2 * kk, Art.bc("ronge"), 0.0, 0.0)
			Ink.brush(ci, xf, crack, 1.0 + 1.2 * kk, Art.bc("braise").lerp(Art.bc("braise_coeur"), 0.5 * kk), 0.0, 0.0)
	if kk > 0.0:
		Ink.halo(ci, xf * Vector2(0, -40), 34.0 * base.get_scale().abs().x, Art.bc("braise"), kk * 0.8)
	# Le lichen : rosettes foliacées vert-de-gris en plaques sur le dos.
	var lp := Sp.lichen_pal()
	for q: Vector3 in [Vector3(-36, -56, 13), Vector3(-2, -70, 12), Vector3(30, -60, 10), Vector3(-60, -32, 7), Vector3(48, -34, 7), Vector3(12, -42, 8), Vector3(-22, -36, 6)]:
		var c := Vector2(q.x, q.y)
		Ink.part(ci, xf, Ink.lumpy(c, q.z, q.z * 0.62, 26, 0.3, 7.0, q.x * 0.1), lp, 1.2, 1.0, 0.5)
		# Lobes plus petits autour, et le cœur plus sombre de la rosette.
		for j in 3:
			var a := q.x * 0.37 + j * 2.1
			Ink.part(ci, xf, Ink.lumpy(c + Vector2(cos(a) * q.z, sin(a) * q.z * 0.55), q.z * 0.38, q.z * 0.28, 12, 0.3, 5.0, a), lp, 0.9, 1.0, 0.3)
		Ink.flat(ci, xf, Ink.lumpy(c + Vector2(0.15, 0.1) * q.z, q.z * 0.32, q.z * 0.2, 10, 0.3, 4.0, q.x), Color(lp["ombre"], 0.8))
	# Polypores : étagères ocre sur le flanc, et un petit champignon pâle tout en haut.
	var poly := {"clair": Art.bc("spore", "detail"), "ombre": Art.bc("spore", "detail").darkened(0.45), "reflet": Art.bc("spore", "detail").lightened(0.35)}
	for q: Vector3 in [Vector3(-62, -22, 13), Vector3(-50, -16, 9), Vector3(56, -24, 10)]:
		var shelf := PackedVector2Array()
		for j in 11:
			var a := PI * j / 10.0
			shelf.append(Vector2(q.x - cos(a) * q.z, q.y - sin(a) * q.z * 0.45))
		Ink.part(ci, xf, shelf, poly, 1.4, 1.0, 0.5)
		Ink.brush(ci, xf, PackedVector2Array([Vector2(q.x - q.z * 0.7, q.y - q.z * 0.15), Vector2(q.x + q.z * 0.7, q.y - q.z * 0.15)]), 0.9, poly["ombre"])
	Sp.cap(ci, xf, Vector2(-14, -76), -PI / 2.0 - 0.25 + 0.4 * kk, 9.0, 16.0, 0.3 * sin(t * 1.8), kk * 0.6)
	if elite:
		Sp.elite_rim(ci, xf, dome.slice(1, 24))
		Sp.elite_caps(ci, xf, [Vector2(68, -16), Vector2(60, -30), Vector2(48, -44)], t)
	# Pattes de devant.
	for i in 2:
		var x := -44.0 + i * 64.0
		_leg(ci, base, xf, Vector2(x + 4, -16), Vector2(x - 2 + sin(step + i * PI + PI * 0.5) * 9.0 * mv, -maxf(sin(step + i * PI + PI * 0.5), 0.0) * 6.0 * mv), leg, i == 1, kk)


## Patte trapue : de la hanche (locale, sous la carapace) au pied (local au sol) ; celles de devant
## (front) se lèvent quand il se dresse.
static func _leg(ci: CanvasItem, base: Transform2D, xf: Transform2D, hip_l: Vector2, foot: Vector2, col: Color, front: bool, kk: float) -> void:
	var hip := base.affine_inverse() * (xf * hip_l)
	if front:
		foot = foot.lerp(hip + Vector2(14, 4), kk * 0.8)
	var knee := hip.lerp(foot, 0.5) + Vector2(6, -2)
	var pts := PackedVector2Array([hip, knee, foot])
	Ink.brush(ci, base, pts, 15.0, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, base, pts, 11.0, col, 1.0, 1.0)
	Ink.brush(ci, base, PackedVector2Array([hip.lerp(knee, 0.3) + Vector2(-2, 0), knee + Vector2(-2, 0)]), 2.0, col.lightened(0.3))
	for s: float in [-1.0, 0.0, 1.0]:
		Ink.part(ci, base, Ink.thorn(foot + Vector2(s * 3.0, -1.5), (PI - 0.5) if s < 0.0 else s * 0.5, 5.0, 3.0), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.9, 1.0, 0.0)
