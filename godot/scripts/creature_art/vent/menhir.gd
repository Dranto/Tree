## Menhir flétri (Vent, lourd), direction « Bestiaire d'herbier » : une pierre levée des plateaux, couverte
## de lichen et d'herbe couchée par le vent, que les racines noires de la Flétrissure ont ligotée et
## mise en marche. Large et ancré : deux pieds de roche, deux poings de pierre au bout de racines.
## Annonce : il lève les deux poings au-dessus de lui, la rune de braise s'allume, puis il frappe.
##
## Pose : t, walk, moving, k (annonce 0 → 1), strike (0 → 1 après la frappe, -1 : aucune), hit, look.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")

## 100 unités en px du jeu (1600×900) : ~84 px de haut à l'écran en 1080p.
const HEIGHT := 64.0


static func pal() -> Dictionary:
	return {"clair": Art.bc("vent", "clair"), "ombre": Art.bc("vent", "ombre"), "reflet": Art.bc("vent", "reflet")}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var flip := cos(look) < 0.0
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	var kk := Anim.ease_out(k)
	var slam := 0.0 if strike < 0.0 else 1.0 - strike
	Ink.ground_shadow(ci, base, Vector2(0, 0), 48.0)
	# Onde de choc au sol après la frappe.
	if slam > 0.0 and not Ink.mono:
		var u := 1.0 - slam
		var ring := Ink.oval(Vector2(30, 0), 20.0 + 50.0 * u, (20.0 + 50.0 * u) * Art.OMBRE_APLATI, 32)
		ring.append(ring[0])
		ci.draw_polyline(base * ring, Color(Art.bc("braise"), 0.8 * slam), 3.0 * h / 100.0, true)
	# Marche lourde : il bascule d'un pied sur l'autre.
	var rock := sin(walk) * 0.05 * mv
	var lift_l := maxf(sin(walk), 0.0) * 6.0 * mv
	var lift_r := maxf(-sin(walk), 0.0) * 6.0 * mv
	var rise := -6.0 * kk + 4.0 * slam
	var sq := Vector2(1.0 + 0.06 * hit - 0.03 * kk + 0.06 * slam, 1.0 - 0.07 * hit + 0.04 * kk - 0.06 * slam)
	var xf := base * Transform2D(rock - 0.08 * kk + 0.06 * slam + 0.05 * hit, sq, 0.0, Vector2(0, -2)) * Transform2D(0.0, Vector2(0, rise))
	var stone := pal()
	var far := {"clair": stone["ombre"], "ombre": stone["ombre"].darkened(0.3), "reflet": stone["clair"]}
	# Poings : levés pendant l'annonce, écrasés au sol à la frappe.
	var up := kk * (1.0 - slam)
	var fist_far := Vector2(40, -30).lerp(Vector2(26, -118), up).lerp(Vector2(46, -12), slam)
	var fist_near := Vector2(-40, -28).lerp(Vector2(-16, -122), up).lerp(Vector2(30, -10), slam)
	_arm(ci, xf, Vector2(16, -76), fist_far, far, 15.0)
	# Pieds de roche.
	Ink.part(ci, base, Ink.lumpy(Vector2(14, -6 - lift_r), 13.0, 8.0, 18, 0.12, 4.0), far, 2.2)
	Ink.part(ci, base, Ink.lumpy(Vector2(-14, -6 - lift_l), 14.0, 8.5, 18, 0.12, 4.0, 1.0), stone, 2.2)
	# La pierre levée : face avant éclairée, flanc droit dans l'ombre.
	var slab := PackedVector2Array([Vector2(-34, -10), Vector2(-38, -52), Vector2(-31, -90), Vector2(-10, -106), Vector2(14, -103), Vector2(31, -84), Vector2(35, -44), Vector2(31, -10)])
	Ink.part(ci, xf, slab, stone, 3.0, 1.0, 0.7)
	Ink.flat(ci, xf, PackedVector2Array([Vector2(14, -103), Vector2(31, -84), Vector2(35, -44), Vector2(31, -10), Vector2(19, -10), Vector2(21, -50), Vector2(17, -92)]), Color(stone["ombre"], 0.85))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(14, -102), Vector2(18, -60), Vector2(19, -12)]), 1.6, stone["ombre"].darkened(0.4))
	# Éclats de taille sur la face.
	for s: Array in [[Vector2(-26, -60), Vector2(-14, -64)], [Vector2(-24, -24), Vector2(-10, -20)], [Vector2(-4, -92), Vector2(6, -96)]]:
		Ink.brush(ci, xf, PackedVector2Array(s), 1.4, stone["ombre"].darkened(0.2))
	# Lichen jaune pâle et herbe couchée par le vent : la vie des plateaux sur la pierre.
	var lich := Art.bc("vent", "detail")
	for q: Vector3 in [Vector3(-28, -70, 5), Vector3(-22, -76, 3.5), Vector3(-30, -40, 4), Vector3(8, -30, 3)]:
		Ink.flat(ci, xf, Ink.lumpy(Vector2(q.x, q.y), q.z, q.z * 0.75, 14, 0.3, 5.0), Color(lich, 0.9))
	if not Ink.mono:
		for i in 7:
			var x := -28.0 + i * 6.5
			var y := -94.0 - 9.0 * sin(PI * (i + 0.5) / 7.0)
			var sway := 4.0 * sin(t * 3.0 + i * 0.7) + 6.0
			Ink.brush(ci, xf, PackedVector2Array([Vector2(x, y + 6), Vector2(x + sway * 0.6, y - 6), Vector2(x + sway * 1.6, y - 13 + absf(i - 3.0))]), 2.6, lich.lerp(Art.bc("vent", "reflet"), 0.15 * (i % 2)), 1.0, 0.0)
	# Une fleur des plateaux qui pousse dans l'herbe, et du gravier qui s'effrite à chaque pas.
	if not Ink.mono:
		var fp := Vector2(-20 + 1.5 * sin(t * 2.0), -104)
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-21, -96), fp]), 1.2, lich.darkened(0.3), 1.0, 0.0)
		for j in 5:
			ci.draw_circle(xf * (fp + Vector2.from_angle(j * TAU / 5.0 + t * 0.3) * 2.6), 1.9 * h / 100.0, Art.ec("vent", "clair"))
		ci.draw_circle(xf * fp, 1.3 * h / 100.0, Art.c("butin"))
		var crumble := absf(sin(walk)) * mv
		for j in 3:
			var u := fposmod(t * 1.3 + j * 0.33, 1.0)
			ci.draw_circle(xf * Vector2(-30 + j * 26, -10 + u * 10.0), (1.6 - j * 0.3) * h / 100.0, Color(stone["ombre"], crumble * (1.0 - u)))
	# Racines noires de la Flétrissure qui la ligotent, nœuds de braise.
	var roots := [
		PackedVector2Array([Vector2(-37, -62), Vector2(-14, -54), Vector2(10, -64), Vector2(33, -58)]),
		PackedVector2Array([Vector2(-36, -22), Vector2(-10, -32), Vector2(14, -26), Vector2(34, -30)]),
	]
	for r: PackedVector2Array in roots:
		Ink.brush(ci, xf, r, 6.5, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, xf, r, 3.6, Art.bc("ronge").lightened(0.12), 1.0, 1.0)
		Ink.ember(ci, xf, Ink.oval(r[1], 2.2, 1.6, 10), 0.2 + 0.5 * kk)
	# Visage taillé : arcade gravée, deux yeux de braise ; la rune du vent au milieu.
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-18, -80), Vector2(-4, -84), Vector2(14, -80)]), 3.4, Ink.encre())
	var glow := 0.3 + 0.7 * kk
	if hit > 0.4 or (kk == 0.0 and Ink.blink(t, 2.0) > 0.0):
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-12, -75), Vector2(-4, -74)]), 2.6, Ink.encre())
		Ink.brush(ci, xf, PackedVector2Array([Vector2(4, -74), Vector2(11, -74)]), 2.2, Ink.encre())
	else:
		Ink.ember(ci, xf, Ink.leaf(Vector2(-13, -75), -0.12, 10.0, 4.4), glow)
		Ink.ember(ci, xf, Ink.leaf(Vector2(3, -76), -0.2, 8.0, 3.8), glow)
	var rune := PackedVector2Array([Vector2(-14, -44), Vector2(-6, -50), Vector2(2, -46), Vector2(0, -38), Vector2(-8, -38), Vector2(-6, -44)])
	Ink.brush(ci, xf, rune, 3.6, Ink.encre(), 1.0, 1.0)
	if not Ink.mono:
		Ink.brush(ci, xf, rune, 1.4 + 1.2 * kk, Art.bc("braise").lerp(Art.bc("braise_coeur"), kk), 1.0, 1.0)
		if kk > 0.0:
			Ink.halo(ci, xf * Vector2(-6, -44), 16.0 * h / 100.0 * (0.5 + kk), Art.bc("braise"), kk)
	_arm(ci, xf, Vector2(-30, -74), fist_near, stone, 17.0)


## Bras de racines tressées (épaule → poing) et poing de pierre.
static func _arm(ci: CanvasItem, xf: Transform2D, shoulder: Vector2, fist: Vector2, col: Dictionary, r: float) -> void:
	var mid := shoulder.lerp(fist, 0.5) + (fist - shoulder).orthogonal().normalized() * 8.0
	for off: float in [-2.5, 2.5]:
		var path := PackedVector2Array([shoulder + Vector2(off, 0), mid + Vector2(off, off), fist + Vector2(off * 0.5, 0)])
		Ink.brush(ci, xf, path, 6.0, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, xf, path, 3.0, Art.bc("ronge").lightened(0.15), 1.0, 1.0)
	Ink.part(ci, xf, Ink.lumpy(fist, r, r * 0.85, 22, 0.1, 5.0, 0.4), col, 2.6, 1.0, 0.6)
	Ink.brush(ci, xf, PackedVector2Array([fist + Vector2(-r * 0.5, -r * 0.1), fist + Vector2(0, r * 0.05), fist + Vector2(r * 0.4, -r * 0.2)]), 1.4, col["ombre"].darkened(0.3))
