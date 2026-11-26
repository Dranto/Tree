## Sangsue de vase (Sève, chargeur), direction « Bestiaire d'herbier » : une grosse sangsue des sources,
## annelée, couchée dans la vase, rongée sur le dos par la Flétrissure. Le signe du chargeur est
## sa ventouse dentée tendue en avant ; une rangée de petits yeux de braise sur la tête.
## Elle rampe en ondulant (vague d'anneaux de la queue à la tête).
## Annonce : elle se ramasse, dresse l'avant, la ventouse s'ouvre et s'allume. Charge : étirée et plate,
## ventouse grande ouverte. Après avoir bu (« gorged »), elle enfle et la vie bue luit en vert entre
## les anneaux.
##
## Pose : t, walk, moving, k (annonce 0 → 1), state (""/windup/charge/recover), charge (0 → 1),
##   strike (0 → 1 après la morsure, -1 : aucune), hit, look, gorged (0 → 1), elite, mono.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const S = preload("res://scripts/creature_art/seve/_seve.gd")

## 100 unités en px du jeu (1600×900) : ~53 px de long à l'écran en 1080p.
const HEIGHT := 44.0

## Pose propre (comportement leech) : gonflée d'avoir bu, de 0 à 1 (contrat moteur).
const CUSTOM := {"gorged": 3}
## Collier et liseré d'élite dessinés ici (pose « elite »).
const DRAWS_ELITE := true

const N := 26


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var state: String = o.get("state", "")
	var charge: float = o.get("charge", 1.0 if state == "charge" else 0.0)
	var strike: float = o.get("strike", -1.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var g: float = o.get("gorged", 0.0)
	var elite: bool = o.get("elite", false)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	var prev_mono := Ink.mono
	if o.has("mono"):
		Ink.mono = bool(o["mono"])
	Ink.flash = hit
	var kk := Anim.ease_out(k) if state != "charge" else 0.0
	var rec := 1.0 if state == "recover" else 0.0
	var bite := 0.0 if strike < 0.0 else 1.0 - strike
	var base := Ink.frame(feet, h, flip)
	Ink.ground_shadow(ci, base, Vector2(-2, 0), 52.0 + 8.0 * charge)
	# Flaque de vase luisante sous elle (elle traîne la boue des sources).
	if not Ink.mono:
		ci.draw_colored_polygon(base * Ink.oval(Vector2(-18, -1), 26.0, 26.0 * Art.OMBRE_APLATI * 0.7, 20), Color(Art.bc("seve", "vase"), 0.45))
	# Corps : écrasé dans l'annonce, étiré dans la charge, gonflé après avoir bu, avachi au repos de la charge.
	var sq := Vector2(1.0 - 0.14 * kk + 0.3 * charge + 0.08 * hit, 1.0 + 0.06 * kk - 0.22 * charge - 0.12 * hit - 0.1 * rec)
	var xf := base * Transform2D(0.0, sq, 0.0, Vector2(-6.0 * charge, 0))
	# Ligne médiane de la queue (u = 0) à la tête (u = 1), épaisseur, et vague de reptation.
	var wave := (0.6 + 0.4 * mv) * (1.0 - charge)
	var mid := PackedVector2Array()
	var th := PackedFloat32Array()
	# La tête se dresse vers la cible dans l'annonce (et un peu au repos).
	var rear := 7.0 * (1.0 - charge) + 20.0 * kk + 4.0 * bite
	var aim := clampf(-la, -0.4, 0.6)
	for i in N:
		var u := i / float(N - 1)
		var x := -52.0 + 100.0 * u
		var swell := 1.0 + 0.35 * g + 0.05 * sin(walk * 2.0 - u * 7.0) * mv
		# Arrière gras, tête fine (une vraie sangsue) ; petites bosses des anneaux sur le dos.
		var w := (5.0 + 17.0 * pow(sin(PI * clampf(u * 0.97 + 0.03, 0.0, 1.0)), 0.75) * (1.08 - 0.42 * u)) * swell
		var lift := pow(clampf((u - 0.6) / 0.4, 0.0, 1.0), 2.0) * (rear + 6.0 * aim * kk)
		var y := -w - 3.5 * sin(walk * 2.0 - u * 7.0 + 0.6) * wave * sin(PI * u) - lift
		mid.append(Vector2(x - lift * 0.25, y))
		th.append(w)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in N:
		var d := (mid[mini(i + 1, N - 1)] - mid[maxi(i - 1, 0)]).normalized()
		var nn := d.orthogonal()
		var bump := 0.9 * absf(sin(u_of(i) * PI * 11.0)) * (1.0 - charge * 0.6)
		top.append(mid[i] + nn * (th[i] + bump))
		var b := mid[i] - nn * th[i] * 0.9
		b.y = minf(b.y, -2.5 * (1.0 - pow(sin(PI * u_of(i)), 0.4)))
		bot.append(b)
	# Ventouse arrière posée au sol.
	var tail := Ink.oval(Vector2(-54, -4), 6.5, 4.5, 14)
	Ink.part(ci, xf, tail, S.pal(0.6), 1.8, 1.0, 0.0)
	var body := PackedVector2Array()
	body.append_array(top)
	var hd := mid[N - 1]
	var dir := (mid[N - 1] - mid[N - 3]).normalized()
	body.append(hd + dir * th[N - 1] * 0.8)
	var rb := bot.duplicate()
	rb.reverse()
	body.append_array(rb)
	Ink.part(ci, xf, body, S.pal(), 2.4, 1.0, 0.8)
	# Ventre de vase, plus sombre, le long du sol.
	var belly := PackedVector2Array()
	for i in range(1, N - 1):
		belly.append(bot[i].lerp(mid[i], 0.05))
	for i in range(N - 2, 0, -1):
		belly.append(bot[i].lerp(mid[i], 0.42))
	Ink.flat(ci, xf, belly, Color(Art.bc("seve", "vase"), 0.85))
	# Anneaux : traits sombres en travers ; gonflée, la vie bue luit en vert entre eux.
	for i in range(3, N - 3, 2):
		var a := top[i].lerp(mid[i], 0.5)
		var b2 := bot[i].lerp(mid[i], 0.2)
		Ink.brush(ci, xf, PackedVector2Array([a, mid[i].lerp(b2, 0.5) + Vector2(1.2, 0), b2]), 1.1, Art.bc("seve", "ombre").darkened(0.25))
		if g > 0.0 and i % 4 == 1 and not Ink.mono:
			Ink.brush(ci, xf, PackedVector2Array([a.lerp(b2, 0.15) + Vector2(-2, 0), mid[i] + Vector2(-2.5, 0), a.lerp(b2, 0.8) + Vector2(-2, 0)]), 2.2 * g, Color(S.sap(), 0.85 * g))
	if g > 0.0:
		S.sap_glow(ci, xf, mid[N / 2], 22.0, g * 0.8)
	# Robe des sangsues des sources : deux rayures ocre le long du dos, tachetées de sombre.
	for side: float in [0.3, 0.55]:
		var stripe := PackedVector2Array()
		for i in range(2, N - 3):
			stripe.append(top[i].lerp(mid[i], side))
		Ink.brush(ci, xf, stripe, 2.6 - side * 1.6, Art.bc("seve", "detail").darkened(0.1 + side * 0.3), 0.0, 0.2)
	for i in range(3, N - 4, 3):
		Ink.flat(ci, xf, Ink.oval(top[i].lerp(mid[i], 0.42), 1.5, 1.1, 8), Art.bc("seve", "ombre").darkened(0.45))
	# Reflet mouillé le long du dos, et deux éclats plus vifs.
	var shine := PackedVector2Array()
	for i in range(4, N - 6):
		shine.append(top[i].lerp(mid[i], 0.14) + Vector2(-0.5, 0))
	Ink.brush(ci, xf, shine, 1.5, Art.bc("seve", "reflet"))
	if not Ink.mono:
		for i: int in [7, 15]:
			ci.draw_circle(xf * top[i].lerp(mid[i], 0.2), 1.3 * xf.get_scale().abs().x, Color(1, 1, 1, 0.7))
	# Lentilles d'eau collées au dos : la mare qu'elle traîne avec elle.
	for q: Vector3 in [Vector3(13, 0.12, 2.2), Vector3(15, 0.2, 1.6)]:
		var qi := int(q.x)
		Ink.flat(ci, xf, Ink.oval(top[qi].lerp(mid[qi], q.y), q.z, q.z * 0.75, 10), Art.ec("racine", "clair").darkened(0.15), 0.8)
	# La Flétrissure ronge l'arrière du dos : plaie sombre aux bords déchirés, fendue de braise.
	var rp := top[7].lerp(mid[7], 0.35)
	Ink.flat(ci, xf, Ink.lumpy(rp, 9.0, 6.0, 26, 0.5, 3.0, 0.4), Art.bc("ronge"))
	Ink.flat(ci, xf, Ink.lumpy(rp + Vector2(-9, 3), 3.5, 2.5, 14, 0.4, 3.0, 1.0), Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([rp + Vector2(-6, 1.5), rp + Vector2(-2, -1), rp + Vector2(2, 1), rp + Vector2(6, -1.5)]), 1.6, Art.bc("braise"))
	Ink.brush(ci, xf, PackedVector2Array([rp + Vector2(-1, -1), rp + Vector2(0, -4)]), 1.0, Art.bc("braise"))
	Ink.sparks(ci, xf, rp + Vector2(0, -3), Vector2(0.15, -1.0), 2, t, 1.1, 0.6 + 0.4 * kk)
	# Gouttes de vase qui tombent du ventre quand elle rampe.
	S.drips(ci, xf, bot[N / 2] + Vector2(0, -2), 2, t, 1.3, Art.bc("seve", "vase").lightened(0.1), mv * (1.0 - charge))
	if elite:
		var rim := PackedVector2Array()
		for i in range(2, N - 3, 2):
			rim.append(top[i] + Vector2(0, -0.6))
		S.elite(ci, xf, mid[N - 7], th[N - 7] * 0.45, th[N - 7] * 1.05, t, rim)
	# Ventouse dentée, en trois quarts : une coupe sombre, couronne de dents d'os, braise au fond.
	var open := clampf(0.5 + 0.65 * kk + 0.6 * charge - 0.5 * bite + 0.25 * g, 0.15, 1.0)
	var mc := hd + dir * th[N - 1] * 0.55
	var ang := dir.angle()
	var lip := Ink.oval(mc, 4.5 + 1.5 * open, 8.0 + 6.0 * open, 18, ang)
	Ink.part(ci, xf, lip, S.pal(), 1.8, 1.0, 0.5)
	var cup := Ink.oval(mc + dir * 1.2, 2.6 + 1.2 * open, 5.0 + 5.0 * open, 16, ang)
	Ink.flat(ci, xf, cup, Art.bc("ronge"))
	for i in 7:
		var a := -PI * 0.45 + PI * 0.9 * i / 6.0
		var e := Vector2(cos(a) * (2.6 + 1.2 * open), sin(a) * (5.0 + 5.0 * open)).rotated(ang) + mc + dir * 1.2
		var tooth_dir := (mc + dir * 2.4 - e).angle()
		Ink.part(ci, xf, Ink.thorn(e, tooth_dir, 2.4 + 1.6 * open, 1.5), S.bone(), 0.0, 1.0, 0.0)
	var core := 0.25 + 0.75 * maxf(kk, charge)
	Ink.ember(ci, xf, Ink.oval(mc + dir * 1.6, 1.2 + 0.8 * open, 2.2 + 2.2 * open, 12, ang), core)
	if kk > 0.0 and not Ink.mono:
		Ink.halo(ci, xf * mc, 14.0 * xf.get_scale().abs().x * (0.5 + 0.6 * kk), Art.bc("braise"), kk * 1.4)
	# Petits yeux de braise en fer à cheval sur la tête (le plus grand devant).
	var eh := mid[N - 3].lerp(top[N - 3], 0.6)
	for i in 4:
		var ep := eh + dir * (2.5 - i * 2.6) + dir.orthogonal() * (-0.8 * absf(i - 1.5))
		var s := 1.9 - i * 0.3
		if hit > 0.4:
			Ink.brush(ci, xf, PackedVector2Array([ep - dir * s, ep + dir * s]), 1.1, Ink.encre())
		else:
			Ink.ember(ci, xf, Ink.oval(ep, s, s * 0.8, 10), 0.3 + 0.7 * maxf(kk, charge))
	Ink.mono = prev_mono
	Ink.flash = 0.0


static func u_of(i: int) -> float:
	return i / float(N - 1)
