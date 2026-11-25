## Scarabée perce-écorce (Racine, chargeur), direction « Bestiaire d'herbier » : un scarabée-rhinocéros
## de la forêt pétrifiée, élytres d'écorce devenue pierre, rongé à l'arrière par la Flétrissure. Corps
## bas et long, une grande corne d'os : le signe du chargeur. La braise couve dans la fente des élytres.
## Annonce : il baisse la tête, lève l'arrière, gratte le sol ; la corne et la fente s'allument.
##
## Charge : corps étiré, élytres entrouvertes, poussière derrière. Retour : sonné, braises qui tournent.
##
## Pose : t, walk, moving, k (annonce 0 → 1), state (windup/charge/recover), charge (0 → 1, pleine course),
## hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const R = preload("res://scripts/creature_art/racine/outils.gd")

## 100 unités en px du jeu (1600×900) : ~56 px de long à l'écran en 1080p.
const HEIGHT := 42.0
const DRAWS_ELITE := true


static func pal() -> Dictionary:
	return {"clair": Art.bc("racine", "clair"), "ombre": Art.bc("racine", "ombre"), "reflet": Art.bc("racine", "reflet")}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var state: String = o.get("state", "")
	var charge: float = o.get("charge", 1.0 if state == "charge" else 0.0)
	var hit: float = o.get("hit", o.get("flash", 0.0))
	var recover := 1.0 if state == "recover" else 0.0
	if state != "" and state != "windup":
		k = 0.0
	var look: float = o.get("look", 0.0)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	Ink.ground_shadow(ci, base, Vector2(-4, 0), 50.0)
	var kk := Anim.ease_out(k)
	# Annonce : nez vers le sol, arrière levé, tremblement. Charge : étiré dans l'élan.
	var shake := sin(t * 70.0) * 1.2 * kk
	var tilt := 0.13 * kk - 0.06 * hit - 0.05 * recover
	var bob := -absf(sin(walk * 1.5)) * 1.6 * mv
	var sq := Vector2(1.0 + 0.14 * charge + 0.08 * hit + 0.04 * recover, 1.0 - 0.1 * charge - 0.1 * hit - 0.05 * recover)
	var xf := base * Transform2D(tilt, sq, 0.0, Vector2(20 + shake, 0)) * Transform2D(0.0, Vector2(-20, bob))
	var legc := Art.bc("racine", "ombre").darkened(0.45)
	# Poussière grattée derrière lui pendant l'annonce, traînée pendant la charge.
	if not Ink.mono and (kk > 0.0 or charge > 0.0):
		var dust := Art.bc("racine", "reflet")
		for i in 4:
			var u := fposmod(t * 2.2 + i * 0.25, 1.0)
			var q := Vector2(-52 - u * 26.0 - charge * 14.0 * i, -4 - u * 10.0 - i * 2.0)
			ci.draw_circle(base * q, (5.0 + 6.0 * u) * h / 100.0, Color(dust, 0.35 * (1.0 - u) * maxf(kk, charge)))
	# Pattes du fond (plus sombres), en trépied alterné avec celles de devant.
	for i in 3:
		var ph := walk * 1.5 + (0.0 if i % 2 else PI)
		_leg(ci, base, xf * Vector2(-18 + i * 17, -18), Vector2(-30 + i * 28 + sin(ph) * 6.0 * mv, -3.0 - maxf(cos(ph), 0.0) * 3.0 * mv), legc.darkened(0.35))
	# Élytres : un dôme long, écorce pétrifiée.
	var shell := Ink.lumpy(Vector2(-10, -30), 40.0, 23.0, 48, 0.025, 9.0)
	for i in shell.size():
		shell[i].y = minf(shell[i].y, -9.0)
	# Respiration : les élytres se soulèvent un peu.
	var breath := 1.0 + 0.025 * sin(t * TAU / 2.4)
	shell = Transform2D(0.0, Vector2(1.0, breath), 0.0, Vector2(0, -12 * (1.0 - breath))) * shell
	Ink.part(ci, xf, shell, pal(), 2.4, 1.0, 0.8)
	# Écorce : stries en long, plus marquées dans l'ombre.
	for i in 4:
		var y := -18.0 - i * 6.0
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-44 + i * 3, y + 4), Vector2(-20, y - 2), Vector2(10 - i * 3, y + 2)]), 1.5, Art.bc("racine", "ombre").darkened(0.15))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-36, -16), Vector2(-14, -19), Vector2(8, -16)]), 2.0, Art.bc("racine", "detail"))
	# La Flétrissure ronge l'arrière : plaque sombre fendue.
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-40, -22), 9.0, 7.0, 20, 0.35, 7.0, 1.1), Art.bc("ronge"))
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-30, -16), 6.0, 4.0, 14, 0.35, 5.0, 0.3), Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-46, -26), Vector2(-40, -22), Vector2(-34, -19), Vector2(-28, -16)]), 1.5, Art.bc("braise"))
	# Charge : les élytres s'entrouvrent, l'aile membraneuse vibre dessous.
	if charge > 0.0:
		var flap := 0.5 + 0.5 * sin(t * 90.0)
		var wing := PackedVector2Array([Vector2(-4, -50), Vector2(-30, -60 - 4.0 * flap), Vector2(-46, -54 - 3.0 * flap), Vector2(-30, -48)])
		Ink.flat(ci, xf, wing, Color(Art.bc("racine", "reflet"), 0.55 * charge), 0.8)
		Ink.part(ci, xf, PackedVector2Array([Vector2(-44, -34), Vector2(-30, -52), Vector2(-6, -58), Vector2(12, -50), Vector2(-10, -46)]), pal(), 1.6, 1.0, 0.4)
	# Fente des élytres : la braise couve, s'allume pendant l'annonce.
	var seam := PackedVector2Array([Vector2(-48, -32), Vector2(-28, -46), Vector2(-4, -51), Vector2(16, -44)])
	Ink.brush(ci, xf, seam, 4.2, Ink.encre())
	if not Ink.mono:
		Ink.brush(ci, xf, seam, 1.8 + 1.4 * kk, Art.bc("braise").lerp(Art.bc("braise_coeur"), kk))
	# Lichens clairs : la forêt qui reprend.
	for q: Vector2 in [Vector2(-22, -46), Vector2(-16, -44), Vector2(-26, -42)]:
		Ink.flat(ci, xf, Ink.oval(q, 3.0, 2.0, 10), Art.bc("racine", "reflet").lerp(Art.ec("racine", "clair"), 0.4))
	# Liseré de lumière au bord des élytres, trous de larves dans l'écorce, mousse en touffe.
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-46, -40), Vector2(-34, -50), Vector2(-14, -53)]), 1.3, Art.bc("racine", "reflet"))
	for q: Vector3 in [Vector3(-8, -24, 1.8), Vector3(2, -30, 1.4), Vector3(-26, -30, 1.6)]:
		Ink.flat(ci, xf, Ink.oval(Vector2(q.x, q.y), q.z * 1.3, q.z, 10), Art.bc("racine", "ombre").darkened(0.4))
		Ink.brush(ci, xf, PackedVector2Array([Vector2(q.x - q.z, q.y + q.z * 0.9), Vector2(q.x + q.z, q.y + q.z * 0.9)]), 0.8, Art.bc("racine", "reflet"))
	var moss := Art.ec("racine", "clair").darkened(0.2)
	for j in 5:
		var b0 := Vector2(-20 + j * 2.2, -47 - absf(j - 2.0) * 0.4)
		Ink.brush(ci, xf, PackedVector2Array([b0, b0 + Vector2(-1.5 + sin(t * 2.0 + j) * 1.2, -5.0 - (j % 2) * 2.0)]), 1.4, moss, 1.0, 0.0)
	# Étincelles qui montent de la fente.
	Ink.sparks(ci, xf, Vector2(-14, -50), Vector2(-0.2, -1.0), 3, t * 0.8, 1.1, 0.5 + kk)
	# Corselet, tête et cornes : la tête suit la cible.
	var head_rot := clampf(la, -0.35, 0.3) + 0.12 * kk
	var hx := xf * Transform2D(head_rot, Vector2(26, -26)) * Transform2D(0.0, Vector2(-26, 26))
	# Antennes en massue, qui tâtent l'air.
	for j in 2:
		var sway := sin(t * 3.1 + j * 1.3) * 0.18
		var a0 := -0.55 - j * 0.35 + sway
		var r0 := Vector2(40 - j * 3, -26)
		var r1 := r0 + Vector2.from_angle(a0) * 9.0
		var r2 := r1 + Vector2.from_angle(a0 + 0.7) * 7.0
		var ant := PackedVector2Array([r0, r1, r2])
		Ink.brush(ci, hx, ant, 2.6, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, hx, ant, 1.1, Art.bc("racine", "ombre").lightened(0.1 * (1 - j)), 1.0, 1.0)
		Ink.part(ci, hx, Ink.oval(r2, 2.4, 1.6, 10, a0 + 0.7), {"clair": Art.bc("racine", "detail"), "ombre": Art.bc("racine", "detail").darkened(0.4)}, 0.9, 1.0, 0.0)
	Ink.part(ci, xf, Ink.lumpy(Vector2(24, -28), 15.0, 15.0, 28, 0.03, 6.0), {"clair": Art.bc("racine", "clair").darkened(0.12), "ombre": Art.bc("racine", "ombre").darkened(0.1), "reflet": Art.bc("racine", "reflet")}, 2.4)
	var bone := {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.35), "reflet": Color.WHITE}
	Ink.part(ci, hx, PackedVector2Array([Vector2(24, -38), Vector2(36, -54), Vector2(42, -58), Vector2(38, -48), Vector2(33, -36)]), bone, 1.8, 1.0, 0.0)
	Ink.part(ci, hx, Ink.oval(Vector2(38, -22), 9.5, 8.0, 18), {"clair": Art.bc("racine", "ombre"), "ombre": Art.bc("racine", "ombre").darkened(0.35), "reflet": Art.bc("racine", "clair")}, 2.2)
	var horn := PackedVector2Array([Vector2(36, -30), Vector2(48, -36), Vector2(58, -48), Vector2(64, -62), Vector2(60, -48), Vector2(52, -32), Vector2(44, -22)])
	Ink.part(ci, hx, horn, bone, 2.0, 1.0, 0.6)
	Ink.brush(ci, hx, PackedVector2Array([Vector2(44, -30), Vector2(52, -38), Vector2(58, -50)]), 1.2, Art.bc("os").darkened(0.3))
	if kk > 0.0:
		Ink.halo(ci, hx * Vector2(63, -60), 10.0 * h / 100.0 * (0.5 + kk), Art.bc("braise"), kk * 1.5)
	# Œil de braise (plissé sous le coup).
	if hit > 0.4 or (kk == 0.0 and Ink.blink(t, 1.1) > 0.0):
		Ink.brush(ci, hx, PackedVector2Array([Vector2(39, -24), Vector2(45, -23)]), 2.0, Ink.encre())
	else:
		Ink.ember(ci, hx, Ink.leaf(Vector2(39, -24), -0.15, 7.0, 3.8), 0.3 + 0.7 * kk)
	# Mandibules sous la corne, qui s'ouvrent pendant l'annonce.
	for j in 2:
		var ma: float = 0.35 + (0.25 + 0.35 * kk) * (1.0 if j == 0 else -0.4) + 0.06 * sin(t * 5.0)
		Ink.part(ci, hx, Ink.thorn(Vector2(44, -16 - j * 2), ma, 8.0 - j * 2.0, 3.4, 0.2), {"clair": Art.bc("racine", "ombre").lightened(0.1), "ombre": Art.bc("racine", "ombre").darkened(0.4)}, 1.0, 1.0, 0.0)
	if recover > 0.0:
		R.dazed(ci, xf, Vector2(32, -66), t, 14.0)
	if o.get("elite", false):
		R.elite(ci, xf, Vector2(14, -46), Vector2(22, -10), 3.0, PackedVector2Array([Vector2(-48, -34), Vector2(-30, -50), Vector2(-6, -55), Vector2(14, -48)]), t, 1.0)
	# Pattes de devant.
	for i in 3:
		var ph := walk * 1.5 + (PI if i % 2 else 0.0)
		var scrape := (sin(t * 22.0) * 5.0 * kk) if i == 0 else 0.0
		_leg(ci, base, xf * Vector2(-16 + i * 17, -13), Vector2(-28 + i * 27 + sin(ph) * 6.0 * mv + scrape, -maxf(cos(ph), 0.0) * 3.5 * mv), legc)


## Patte articulée : hanche (écran) → genou haut → pied (local), épine au tibia.
static func _leg(ci: CanvasItem, base: Transform2D, hip_w: Vector2, foot: Vector2, col: Color) -> void:
	var hip := base.affine_inverse() * hip_w
	var out := -1.0 if foot.x < hip.x else 1.0
	var knee := Vector2(hip.x + (foot.x - hip.x) * 0.4 + out * 4.0, minf(hip.y, foot.y) - 6.0)
	var pts := PackedVector2Array([hip, knee, foot])
	Ink.brush(ci, base, pts, 5.6, Ink.encre(), 1.0, 0.5)
	Ink.brush(ci, base, pts, 3.4, col, 1.0, 0.4)
	Ink.brush(ci, base, PackedVector2Array([hip.lerp(knee, 0.3), knee]), 1.0, col.lightened(0.4))
	ci.draw_circle(base * knee, 1.3 * base.get_scale().abs().x, Ink.shade(col.lightened(0.25)) if not Ink.mono else Color.BLACK)
	# Griffe au bout.
	Ink.brush(ci, base, PackedVector2Array([foot, foot + Vector2(out * 3.5, 0.5)]), 1.6, Ink.encre(), 1.0, 0.0)
	Ink.brush(ci, base, PackedVector2Array([knee.lerp(foot, 0.45), knee.lerp(foot, 0.45) + Vector2(out * 4.0, -2.0)]), 1.6, Ink.encre(), 1.0, 0.0)
