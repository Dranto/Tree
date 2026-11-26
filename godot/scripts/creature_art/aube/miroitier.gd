## Miroitier (Aube, tireur), direction « Bestiaire d'herbier » : une mante religieuse des falaises de verre,
## corps de verre fumé, ailes de vitre repliées sur l'abdomen, rongée par la Flétrissure. Ses pattes
## ravisseuses tiennent devant elle un grand miroir rond cerclé d'os, de biais, qui suit la cible.
## Annonce (le cône au sol) : elle se cabre, lève le miroir et le tourne de face ; la lumière s'y
## amasse et le verre blanchit. Éclair (strike) : une étoile de lumière crue jaillit du miroir.
##
## Pose : t, walk, moving, k (annonce 0 → 1), strike (0 → 1 après l'éclair, -1 : aucun), hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/aube/verre.gd")

## 100 unités en px du jeu (1600×900) : ~48 px de haut à l'écran en 1080p.
const HEIGHT := 40.0
## La sorte dessine elle-même sa parure d'élite (collier de prismes, liseré d'or).
const DRAWS_ELITE := true
const NECK := Vector2(8, -72)


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	var kk := Anim.ease_out(k)
	var fl := 0.0 if strike < 0.0 else 1.0 - strike
	Ink.ground_shadow(ci, base, Vector2(-2, 0), 34.0)
	# Balancement de mante (elle oscille sur place), cabrée pendant l'annonce, rejetée par l'éclair.
	var sway := sin(t * TAU / 1.9) * 0.04 + sin(walk) * 0.03 * mv
	var bob := -absf(sin(walk)) * 2.5 * mv
	var lean := sway - 0.12 * kk + 0.1 * fl + 0.12 * hit
	var sq := Vector2(1.0 + 0.1 * hit, 1.0 - 0.1 * hit + 0.03 * kk)
	var xf := base * Transform2D(lean, sq, 0.0, Vector2(0, bob))
	var body := V.pal()
	var legc := V.ash()
	# Pattes marcheuses du fond (fines, genou haut).
	_leg(ci, base, xf * Vector2(-10, -38), Vector2(-34 + sin(walk) * 7.0 * mv, -maxf(cos(walk), 0.0) * 3.0 * mv), legc.darkened(0.3))
	_leg(ci, base, xf * Vector2(-2, -40), Vector2(8 - sin(walk) * 7.0 * mv, -maxf(-cos(walk), 0.0) * 3.0 * mv), legc.darkened(0.3))
	# Bras ravisseur du fond, qui tient le miroir par derrière.
	var aim := clampf(la, -0.5, 0.45) * 0.7
	var mc := Vector2(34, -62) + Vector2(-4, -10) * kk + Vector2(-5, 0) * fl
	_arm(ci, xf, Vector2(10, -64), mc + Vector2(-2, 12), legc.darkened(0.2))
	# Abdomen : un long fuseau de verre fumé, ailes de vitre repliées dessus.
	var abd := Ink.leaf(Vector2(-2, -42), PI - 0.42 + sway * 0.5, 46.0, 24.0, 0.05)
	Ink.part(ci, xf, abd, body, 2.4, 1.0, 0.8)
	if not Ink.mono:
		for i in 4:
			var q := Vector2(-2, -42) + Vector2.from_angle(PI - 0.42) * (12.0 + i * 8.0)
			Ink.brush(ci, xf, PackedVector2Array([q + Vector2(1, -9 + i), q + Vector2(-1, 9 - i)]), 1.2, Color(Art.bc("aube", "ombre"), 0.8))
		# La Flétrissure ronge le bout de l'abdomen : plaque sombre, fente de braise, étincelles.
		Ink.flat(ci, xf, Ink.lumpy(Vector2(-34, -24), 9.0, 7.0, 18, 0.35, 6.0, 0.8), Art.bc("ronge"))
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-40, -28), Vector2(-34, -24), Vector2(-30, -27), Vector2(-25, -22)]), 1.6, Art.bc("braise"))
		Ink.sparks(ci, xf, Vector2(-36, -20), Vector2(-0.2, 1.0), 2, t, 1.4, 0.7)
	var wing := Ink.leaf(Vector2(-2, -50), PI - 0.3 + sway * 0.5, 44.0, 15.0, 0.06)
	V.pane(ci, xf, wing, Art.bc("aube", "verre"), 0.42, 1.3, [PackedVector2Array([Vector2(-4, -50), Vector2(-40, -36)])])
	# Pattes marcheuses de devant.
	_leg(ci, base, xf * Vector2(-6, -36), Vector2(-20 - sin(walk) * 7.0 * mv, -maxf(-cos(walk), 0.0) * 3.0 * mv), legc)
	_leg(ci, base, xf * Vector2(2, -38), Vector2(18 + sin(walk) * 7.0 * mv, -maxf(cos(walk), 0.0) * 3.0 * mv), legc)
	# Corselet : le long cou dressé de la mante.
	var neck := PackedVector2Array([Vector2(-6, -40), Vector2(-2, -60), Vector2(4, -74), Vector2(12, -76), Vector2(10, -60), Vector2(6, -42)])
	Ink.part(ci, xf, neck, body, 2.2, 1.0, 0.7)
	if o.get("elite", false):
		V.collar(ci, xf, Vector2(8, -72), 8.0, 5.0, 5)
		V.liseret(ci, xf, abd)
	# Tête triangulaire qui suit la cible, grands yeux composés de braise.
	var hr := clampf(la, -0.4, 0.4) * 0.6 - 0.1 * kk
	var hx := xf * Transform2D(hr, Vector2(10, -80)) * Transform2D(0.0, Vector2(-10, 80))
	for j in 2:
		var a0 := -1.35 - j * 0.35 + sin(t * 2.7 + j) * 0.12
		var r0 := Vector2(10 + j * 2, -88)
		var ant := PackedVector2Array([r0, r0 + Vector2.from_angle(a0) * 12.0, r0 + Vector2.from_angle(a0 - 0.5) * 22.0])
		Ink.brush(ci, hx, ant, 2.4, Ink.encre(), 1.0, 0.0)
		if not Ink.mono:
			Ink.brush(ci, hx, ant, 0.9, Art.bc("aube", "clair"), 1.0, 0.0)
	var head := PackedVector2Array([Vector2(-1, -88), Vector2(8, -92), Vector2(20, -90), Vector2(24, -84), Vector2(19, -76), Vector2(14, -72), Vector2(6, -78)])
	Ink.part(ci, hx, head, body, 2.2, 1.0, 0.9)
	var glow := 0.3 + 0.7 * maxf(kk, fl)
	if hit > 0.4 or (kk == 0.0 and fl == 0.0 and Ink.blink(t, 0.7) > 0.0):
		Ink.brush(ci, hx, PackedVector2Array([Vector2(12, -86), Vector2(20, -85)]), 2.2, Ink.encre())
	else:
		Ink.ember(ci, hx, Ink.oval(Vector2(17, -86), 4.2, 3.4, 14, -0.3), glow)
		Ink.ember(ci, hx, Ink.oval(Vector2(3, -88), 2.6, 2.4, 12, -0.3), glow * 0.8)
	# Le miroir, de biais, qui se tourne de face pendant l'annonce.
	_mirror(ci, xf, mc, aim - 0.2 * kk, kk, fl, t)
	# Bras ravisseur de devant (par-dessus le cerclage).
	_arm(ci, xf, Vector2(8, -62), mc + Vector2(-6, 16), legc.lightened(0.05))


## Le miroir rond cerclé d'os : c centre, a inclinaison ; il s'ouvre (vu de face) et s'éclaire avec k.
static func _mirror(ci: CanvasItem, xf: Transform2D, c: Vector2, a: float, k: float, fl: float, t: float) -> void:
	var rx := lerpf(7.0, 15.0, k)
	var ry := 21.0 + 2.0 * k
	var disc := Ink.oval(c, rx, ry, 28, a)
	var shine := clampf(k + fl, 0.0, 1.0)
	# Lumière qui converge vers le miroir pendant l'annonce (rayons fins venus de partout).
	if k > 0.0 and fl == 0.0 and not Ink.mono:
		for i in 6:
			var ang := -PI * 0.9 + i * 0.36 + sin(t * 2.0 + i) * 0.05
			var u := fposmod(t * 1.6 + i * 0.17, 1.0)
			var from := c + Vector2.from_angle(ang) * (70.0 - 50.0 * u)
			Ink.brush(ci, xf, PackedVector2Array([from, from.lerp(c, 0.4)]), 1.4, Color(Art.bc("aube", "lueur"), 0.7 * k * (1.0 - u)), 0.0, 0.0)
	# Cerclage d'os.
	Ink.part(ci, xf, Ink.oval(c, rx + 4.0, ry + 4.0, 28, a), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.35), "reflet": Color.WHITE}, 2.2, 1.0, 0.4)
	# Le verre : fumé au repos, blanchit quand la lumière s'y amasse.
	var smoke := {"clair": Art.bc("aube", "verre_ombre").lerp(Art.bc("aube", "lueur"), shine), "ombre": Art.bc("aube", "ombre").lerp(Art.bc("aube", "detail"), shine * 0.8), "reflet": Art.bc("aube", "lueur")}
	Ink.part(ci, xf, disc, smoke, 0.0, 1.0, 1.0)
	if Ink.mono:
		return
	# Reflets en biais sur la vitre, et la fêlure de braise de la Flétrissure.
	var d := Vector2.from_angle(a + PI / 2.0)
	Ink.brush(ci, xf, PackedVector2Array([c - d * ry * 0.7 + Vector2(-rx * 0.3, 0), c - d * ry * 0.1 + Vector2(-rx * 0.45, 0)]), 2.0, Color(Art.bc("aube", "lueur"), 0.8))
	Ink.brush(ci, xf, PackedVector2Array([c + d * ry * 0.2 + Vector2(rx * 0.3, 0), c + d * ry * 0.75 + Vector2(rx * 0.1, 0)]), 1.2, Color(Art.bc("aube", "lueur"), 0.5))
	Ink.brush(ci, xf, PackedVector2Array([c + d * ry * 0.55, c + d * ry * 0.3 + Vector2(rx * 0.25, 0), c + d * ry * 0.05 + Vector2(rx * 0.1, 0)]), 1.2, Art.bc("braise").lerp(Art.bc("ronge"), 0.4 * (1.0 - k)))
	if k > 0.0 and fl == 0.0:
		Ink.halo(ci, xf * c, 22.0 * xf.get_scale().abs().x * (0.5 + k), Art.bc("aube", "lueur"), k * 1.4)
		V.sparkle(ci, xf * (c + Vector2(-rx * 0.2, -ry * 0.3)), 9.0 * xf.get_scale().abs().x * k, Art.bc("aube", "lueur"), k, t * 0.6)
	# L'éclair : une étoile de lumière crue qui jaillit puis s'éteint.
	if fl > 0.0:
		var s := xf.get_scale().abs().x
		Ink.halo(ci, xf * c, 46.0 * s * (0.6 + 0.4 * fl), Art.c("danger_eclair"), 2.0 * fl)
		V.sparkle(ci, xf * c, 44.0 * s * (0.5 + 0.5 * fl), Art.c("danger_eclair"), fl, PI / 4.0 * (1.0 - fl))
		V.sparkle(ci, xf * c, 26.0 * s * fl, Art.bc("aube", "lueur"), fl, 0.0)


## Patte marcheuse : hanche (écran) → genou haut → pied (local), fine et anguleuse.
static func _leg(ci: CanvasItem, base: Transform2D, hip_w: Vector2, foot: Vector2, col: Color) -> void:
	var hip := base.affine_inverse() * hip_w
	var out := -1.0 if foot.x < hip.x else 1.0
	var knee := Vector2(hip.x + (foot.x - hip.x) * 0.55 + out * 3.0, minf(hip.y, foot.y) - 10.0)
	var pts := PackedVector2Array([hip, knee, foot])
	Ink.brush(ci, base, pts, 4.2, Ink.encre(), 1.0, 0.4)
	Ink.brush(ci, base, pts, 2.2, col, 1.0, 0.3)
	Ink.brush(ci, base, PackedVector2Array([foot, foot + Vector2(out * 3.0, 0.5)]), 1.4, Ink.encre(), 1.0, 0.0)


## Patte ravisseuse : épaule → coude → la main qui tient le cerclage, épines d'os au tibia.
static func _arm(ci: CanvasItem, xf: Transform2D, sh: Vector2, hand: Vector2, col: Color) -> void:
	var elbow := sh.lerp(hand, 0.5) + Vector2(-6, 8)
	var pts := PackedVector2Array([sh, elbow, hand])
	Ink.brush(ci, xf, pts, 6.0, Ink.encre(), 1.0, 0.8)
	Ink.brush(ci, xf, pts, 3.6, col, 1.0, 0.7)
	var bone := {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.35)}
	for j in 2:
		var q := elbow.lerp(hand, 0.3 + j * 0.35)
		Ink.part(ci, xf, Ink.thorn(q, (hand - elbow).angle() + PI / 2.0, 4.0, 2.0, 0.2), bone, 0.8, 1.0, 0.0)
