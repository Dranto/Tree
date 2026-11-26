## Chargeur (Ronce, chargeur), direction « Bestiaire d'herbier » : un charançon des ronces rongé par la
## Flétrissure. Élytres bombés couleur de mûre hérissés d'épines d'os en rangs (une tige de ronce faite
## dos), corps bas, et un long rostre en lance tendu vers l'avant : le signe du chargeur.
## Annonce (windup) : il abaisse le rostre à l'horizontale vers sa cible, lève l'arrière, gratte le sol ;
##   la braise monte dans la fente des élytres et la pointe du rostre s'allume.
## Charge : étiré dans l'élan, pattes repliées en arrière, poussière.
## Remise (recover) : sonné, rostre piqué au sol, trois braises tournent au-dessus de sa tête.
##
## Pose : t, walk, moving, k (annonce 0 → 1), state (""/windup/charge/recover), charge (0 → 1, facultatif :
##   déduit de state), hit, look, elite, mono.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const O = preload("res://scripts/creature_art/ronce/_outils.gd")

## 100 unités en px du jeu (1600×900) : ~75 px de long, ~44 px de haut à l'écran en 1080p.
const HEIGHT := 46.0
## L'élite : collier et liseré dessinés ici (contrat moteur), collier au cou.
const DRAWS_ELITE := true
const NECK := Vector2(20, -32)


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var state: String = o.get("state", "")
	var hit: float = o.get("hit", 0.0)
	var elite: bool = o.get("elite", false)
	var charge: float = o.get("charge", 1.0 if state == "charge" else 0.0)
	var dazed := 1.0 if state == "recover" else 0.0
	if state == "windup" and k == 0.0:
		k = 1.0
	var fl: Array = O.aim(o.get("look", 0.0))
	var la: float = fl[1]
	Ink.flash = hit
	var base := Ink.frame(feet, h, fl[0])
	Ink.ground_shadow(ci, base, Vector2(2, 0), 52.0 + 8.0 * charge)
	var kk := Anim.ease_out(k)
	# Annonce : arrière levé, tremblement. Charge : étiré, couché dans l'élan. Sonné : tête basse.
	var shake := sin(t * 70.0) * 1.4 * kk
	var tilt := 0.12 * kk + 0.05 * charge + 0.08 * dazed - 0.06 * hit
	var bob := -absf(sin(walk * 1.5)) * 1.8 * mv - 2.0 * charge
	var sq := Vector2(1.0 + 0.16 * charge + 0.08 * hit, 1.0 - 0.1 * charge - 0.1 * hit)
	var xf := base * Transform2D(tilt, sq, 0.0, Vector2(14 + shake, 0)) * Transform2D(0.0, Vector2(-14, bob))
	var legc := Art.bc("ronce", "ombre").darkened(0.45)
	# Poussière grattée pendant l'annonce, traînée pendant la charge.
	if not Ink.mono and (kk > 0.0 or charge > 0.0):
		var dust := Art.bc("os").darkened(0.2)
		for i in 5:
			var u := fposmod(t * 2.4 + i * 0.2, 1.0)
			var q := Vector2(-48 - u * 30.0 - charge * 16.0 * i, -4 - u * 12.0 - i * 1.5)
			ci.draw_circle(base * q, (5.0 + 7.0 * u) * h / 100.0, Color(dust, 0.32 * (1.0 - u) * maxf(kk, charge)))
	if charge > 0.0 and not Ink.mono:
		for i in 3:
			var y := -22.0 - i * 14.0
			Ink.brush(ci, base, PackedVector2Array([Vector2(-60 - i * 6, y), Vector2(-30 - i * 4, y - 1)]), 2.2, Color(Art.bc("os"), 0.55))
	# Pattes du fond (plus sombres).
	for i in 3:
		var ph := walk * 1.5 + (0.0 if i % 2 else PI)
		var foot := Vector2(-30 + i * 26 + sin(ph) * 7.0 * mv, -3.0 - maxf(cos(ph), 0.0) * 4.0 * mv)
		if charge > 0.0:
			foot = Vector2(-40 + i * 18 - 6.0 * sin(t * 40.0 + i), -6.0)
		O.leg(ci, xf, Vector2(-14 + i * 15, -22), foot, legc.darkened(0.35), 3.4, 8.0)
	# Élytres : un dôme bombé de mûre, plus haut à l'arrière.
	var shell := Ink.lumpy(Vector2(-14, -36), 34.0, 27.0, 52, 0.03, 12.0)
	var breath := 1.0 + 0.025 * sin(t * TAU / 2.2)
	shell = Transform2D(0.0, Vector2(1.0, breath), 0.0, Vector2(0, -16 * (1.0 - breath))) * shell
	for i in shell.size():
		shell[i].y = minf(shell[i].y, -14.0)
	if elite:
		O.rim(ci, xf, shell, 2.6)
	# Épines d'os en rangs sur le dos (derrière le bord de l'élytre, la pointe vers l'arrière).
	for i in 5:
		var a := PI * (1.12 + i * 0.13)
		var p := Vector2(-14, -36) + Vector2.from_angle(a) * Vector2(32, 25)
		Ink.part(ci, xf, Ink.thorn(p, a - 0.55, 15.0 - absf(i - 2) * 1.5 + 3.0 * kk, 7.0, -0.25), O.bone(), 1.6, 1.0, 0.0)
	Ink.part(ci, xf, shell, O.pal(), 2.6, 1.0, 0.8)
	# Drupes en rangs (les élytres de mûre), creux sombres et petits reflets.
	if not Ink.mono:
		var sk := xf.get_scale().abs().x
		for row in 4:
			for col in 7:
				var p := Vector2(-42 + col * 9.0 + (4.5 if row % 2 else 0.0), -52 + row * 8.5)
				var q := (p - Vector2(-14, -36)) / Vector2(30, 23)
				if q.length() > 0.9 or p.y > -18.0:
					continue
				var lit := clampf(-(q.dot(Ink.LIGHT)) * 0.9 + 0.35, 0.0, 1.0)
				ci.draw_circle(xf * (p + Vector2(0.6, 0.9)), 3.2 * sk, Ink.shade(Color(Art.bc("ronce", "ombre"), 0.5)))
				ci.draw_circle(xf * (p + Vector2(-1.0, -1.2)), 1.5 * sk, Ink.shade(Color(Art.bc("ronce", "reflet"), 0.2 + 0.6 * lit)))
	# Petites épines sur le dessus des élytres, en rangs.
	for i in 4:
		var p := Vector2(-34 + i * 13.0, -58 + absf(i - 1.5) * 3.0)
		Ink.part(ci, xf, Ink.thorn(p, -PI * 0.5 - 0.5, 8.0, 4.2, -0.2), O.bone(), 1.1, 1.0, 0.0)
	# La Flétrissure ronge l'arrière : plaque sombre fendue de braise.
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-42, -28), 10.0, 9.0, 20, 0.35, 7.0, 1.1), Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-48, -34), Vector2(-42, -29), Vector2(-44, -23), Vector2(-38, -19)]), 1.6, Art.bc("braise"))
	# Fente des élytres : la braise monte pendant l'annonce et pendant la charge.
	var seam := PackedVector2Array([Vector2(-44, -44), Vector2(-28, -58), Vector2(-6, -62), Vector2(14, -52)])
	Ink.brush(ci, xf, seam, 4.4, Ink.encre())
	if not Ink.mono:
		var heat := maxf(kk, charge * 0.8)
		Ink.brush(ci, xf, seam, 1.8 + 1.6 * heat, Art.bc("braise").lerp(Art.bc("braise_coeur"), heat))
	Ink.sparks(ci, xf, Vector2(-20, -60), Vector2(-0.3, -1.0), 3, t * 0.8, 1.2, 0.5 + kk)
	# Une feuille encore verte prise dans les épines : la ronce vit encore dessous.
	var green := {"clair": Art.ec("racine", "clair").darkened(0.15), "ombre": Art.ec("racine", "clair").darkened(0.55), "reflet": Art.ec("racine", "clair").lightened(0.3)}
	Ink.part(ci, xf, Ink.leaf(Vector2(-22, -60), -PI * 0.5 - 0.7 + 0.08 * sin(t * 2.0), 13.0, 6.5, 0.12), green, 1.3, 1.0, 0.5)
	if elite:
		O.collar(ci, xf, NECK, 7.0, 15.0, t, o.get("region", "ronce"))
	# Corselet.
	var pron := Ink.lumpy(Vector2(20, -34), 14.0, 15.0, 26, 0.03, 6.0)
	Ink.part(ci, xf, pron, O.pal(0.1), 2.4, 1.0, 0.6)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(12, -46), Vector2(22, -48), Vector2(30, -42)]), 1.2, Art.bc("ronce", "reflet"))
	# Tête et rostre : la lance suit la cible ; à l'annonce elle se met à l'horizontale, sonné elle pique au sol.
	var hp := Vector2(32, -34)
	var aim := clampf(la, -0.35, 0.3) * (1.0 - kk) * (1.0 - charge)
	var rot := aim + 0.24 * (1.0 - kk) * (1.0 - charge) - 0.2 * kk - 0.18 * charge + 0.42 * dazed + 0.06 * sin(t * 2.0) * (1.0 - kk)
	var hx := O.turn(xf, hp, rot)
	# Antennes coudées (au milieu du rostre), qui tâtent l'air ; couchées pendant la charge.
	for j in 2:
		var sway := sin(t * 3.4 + j * 1.3) * 0.2 * (1.0 - charge)
		var r0 := Vector2(47 - j * 2, -34)
		var a0 := -1.25 - j * 0.25 + sway + 0.9 * charge
		var r1 := r0 + Vector2.from_angle(a0) * 10.0
		var r2 := r1 + Vector2.from_angle(a0 + 1.3 - 0.6 * charge) * 9.0
		var ant := PackedVector2Array([r0, r1, r2])
		Ink.brush(ci, hx, ant, 2.6, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, hx, ant, 1.1, Art.bc("ronce", "detail").lightened(0.1 * (1 - j)), 1.0, 1.0)
		Ink.part(ci, hx, Ink.oval(r2, 2.6, 1.7, 10, a0 + 1.3), O.stem(), 0.9, 1.0, 0.0)
	var head := Ink.oval(hp + Vector2(4, 0), 10.0, 9.5, 20)
	Ink.part(ci, hx, head, O.pal(0.15), 2.2, 1.0, 0.5)
	# Le rostre : tige de ronce effilée, nœuds d'épines, pointe d'os.
	var rost := PackedVector2Array([hp + Vector2(8, -6), Vector2(54, -36), Vector2(68, -32.5), Vector2(80, -28.5), Vector2(68, -26.5), Vector2(54, -27), hp + Vector2(8, 4)])
	Ink.part(ci, hx, rost, {"clair": Art.bc("ronce", "detail").lerp(Art.bc("os"), 0.3), "ombre": Art.bc("ronce", "detail").darkened(0.35), "reflet": Art.bc("os")}, 2.0, 1.0, 0.6)
	Ink.part(ci, hx, PackedVector2Array([Vector2(70, -32), Vector2(88, -28.5), Vector2(70, -26.5)]), O.bone(), 1.4, 1.0, 0.0)
	for i in 2:
		var q := Vector2(52 + i * 10, -34 + i * 1.5)
		Ink.brush(ci, hx, PackedVector2Array([q + Vector2(0, -2.5), q + Vector2(0.5, 5.0)]), 1.3, Art.bc("ronce", "detail").darkened(0.5))
		Ink.part(ci, hx, Ink.thorn(q + Vector2(0, -2), -PI * 0.5 - 0.6, 5.0, 2.4), O.bone(), 0.8, 1.0, 0.0)
	if kk > 0.0 or charge > 0.0:
		var glow := maxf(kk, charge)
		Ink.halo(ci, hx * Vector2(86, -28.5), 12.0 * h / 100.0 * (0.5 + glow), Art.bc("braise"), glow * 1.6)
		Ink.ember(ci, hx, Ink.oval(Vector2(82, -28.5), 3.5, 1.6, 10), glow)
	# Œil de braise, plissé sous le coup ; sonné, l'œil s'éteint à moitié.
	O.eye(ci, hx, hp + Vector2(2, -3), -0.15, 7.0, 4.0, (0.3 + 0.7 * maxf(kk, charge)) * (1.0 - 0.6 * dazed), hit, t, kk, 1.7)
	# Pattes de devant (la première gratte le sol à l'annonce).
	for i in 3:
		var ph := walk * 1.5 + (PI if i % 2 else 0.0)
		var scrape := (sin(t * 22.0) * 6.0 * kk) if i == 2 else 0.0
		var foot := Vector2(-26 + i * 26 + sin(ph) * 7.0 * mv + scrape, -maxf(cos(ph), 0.0) * 4.0 * mv)
		if charge > 0.0:
			foot = Vector2(-36 + i * 20 + 6.0 * sin(t * 40.0 + i * 2.0), -4.0)
		O.leg(ci, xf, Vector2(-12 + i * 15, -16), foot, legc, 3.6, 8.0)
	# Sonné : trois braises tournent au-dessus de la tête.
	if dazed > 0.0 and not Ink.mono:
		for i in 3:
			var a := t * 5.0 + i * TAU / 3.0
			var q := xf * (hp + Vector2(cos(a) * 18.0, -30.0 + sin(a) * 5.0))
			ci.draw_circle(q, 2.4 * h / 100.0, Art.bc("braise"))
			ci.draw_circle(q, 1.2 * h / 100.0, Art.bc("braise_coeur"))
