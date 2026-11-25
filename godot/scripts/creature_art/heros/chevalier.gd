## Piste C, « Chevalier-gland » : un petit gland coiffé de sa cupule qui devient un chevalier d'écorce.
## En grandissant : la cupule descend et devient un heaume dont la visière ne laisse passer qu'une fente
## de sève, une épaulière et un plastron d'écorce poussent, la graine se loge dans le plastron, une cape
## de feuilles s'allonge, un panache pousse sur le heaume et la brindille devient une lame vivante.
## La couleur de la branche passe dans le panache, le fil de la lame et la lueur de la visière.
## Pose : t, walk, moving, look, hit, cast, build, evol (0 → 1) ou stade (1 → 3).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const K = preload("res://scripts/creature_art/heros/commun.gd")

const HEIGHT := 56.0
const BARK := {"clair": Color("a27c56"), "ombre": Color("5e4430"), "reflet": Color("d8b88a")}
const CUP := {"clair": Color("8f6a44"), "ombre": Color("4e3826"), "reflet": Color("c9a57a")}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var look: float = o.get("look", 0.0)
	var cast: float = o.get("cast", 0.0)
	var build: String = o.get("build", "aucun")
	var p := K.progress(o)
	var flip := cos(look) < 0.0
	Ink.flash = o.get("hit", 0.0)
	var base := Ink.frame(feet, h * (0.62 + 0.38 * p), flip)
	var u := base.get_scale().y
	var acc := K.accent(build)
	var gl := K.glow(build)
	var lv := K.leaves(build)
	var dark := {"clair": lv["ombre"].lightened(0.1), "ombre": lv["ombre"].darkened(0.35), "reflet": lv["clair"]}
	var skin := {"clair": K.CREME, "ombre": K.CREME.darkened(0.2).lerp(Color("b49a7a"), 0.3), "reflet": Color.WHITE}
	K.aura(ci, base, t, p, acc)
	Ink.ground_shadow(ci, base, Vector2.ZERO, 16.0 + 8.0 * p)
	var bob := sin(t * TAU / 2.4) * 0.8 - absf(sin(walk)) * 3.0 * mv
	var xf := base * Transform2D(0.0, Vector2(0, bob))
	var legl := 9.0 + 9.0 * p
	var th := 18.0 + 22.0 * p
	var tw := 11.0 + 9.0 * p
	var tc := Vector2(0, -legl - th * 0.5)
	var hr := 13.0 - 1.0 * p
	var hc := Vector2(2.0, -legl - th - hr * (0.6 + 0.3 * p))
	var sway := sin(t * 1.7)
	# Cape de feuilles derrière (dès les premiers nœuds).
	if p > 0.1:
		var cl := 8.0 + 36.0 * p
		var cape := PackedVector2Array([Vector2(-tw * 0.6, tc.y - th * 0.45), Vector2(tw * 0.2, tc.y - th * 0.5)])
		var n := 5
		for i in n + 1:
			var k := i / float(n)
			var x := lerpf(tw * 0.1, -tw * 1.2 - 10.0 * p, k) + sway * 2.0 * k
			var y := tc.y - th * 0.5 + cl + (4.0 + 3.0 * p if i % 2 == 1 else 0.0) - 6.0 * k
			cape.append(Vector2(x - 6.0 * p * k, minf(y, -1.0)))
		Ink.part(ci, xf, cape, dark, 2.0, 1.0, 0.4)
		for i in 3:
			var x := -tw * 0.3 - i * 4.0
			Ink.brush(ci, xf, PackedVector2Array([Vector2(x + 2, tc.y - th * 0.4), Vector2(x - 2.0 - 2.0 * i, tc.y - th * 0.5 + cl * 0.8)]), 1.0, dark["ombre"].darkened(0.2))
	# Panache (côté du fond) : longues feuilles couleur de branche, rabattues vers l'arrière.
	if p > 0.3:
		var k := (p - 0.3) / 0.7
		for i in 3:
			var a := PI * (1.12 + 0.07 * i) + 0.08 * sin(t * 2.2 + i)
			K.leaf(ci, xf, hc + Vector2(-2, -hr * 0.95), a, (10.0 + 18.0 * k) * (1.0 - i * 0.15), 5.0, {"clair": acc, "ombre": acc.darkened(0.35), "reflet": acc.lightened(0.4)}, -0.06, 1.0)
	# Jambes : jambières d'écorce, bottes.
	var sw := sin(walk) * 5.0 * mv
	for j in 2:
		var x := (4.0 if j == 0 else -4.0)
		var f := Vector2(x + (sw if j == 0 else -sw), -2.0)
		var pts := PackedVector2Array([Vector2(x, -legl - 1.0), Vector2(x, -legl * 0.5), f])
		var col: Color = BARK["clair"] if j == 0 else BARK["ombre"]
		Ink.brush(ci, xf, pts, 7.0 + 4.0 * p, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, xf, pts, 4.8 + 4.0 * p, col, 1.0, 1.0)
		Ink.part(ci, xf, Ink.lumpy(f + Vector2(2.0, 0.5), 4.4 + 0.8 * p, 2.8, 12, 0.05, 2.0), {"clair": Color("5b4636"), "ombre": Color("3f3026")}, 1.2, 1.0, 0.0)
	# Bras du fond.
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-tw * 0.55, tc.y - th * 0.3), Vector2(-tw * 0.8, tc.y), Vector2(-tw * 0.6, tc.y + th * 0.15)]), 6.0, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-tw * 0.55, tc.y - th * 0.3), Vector2(-tw * 0.8, tc.y), Vector2(-tw * 0.6, tc.y + th * 0.15)]), 3.8, skin["ombre"], 1.0, 1.0)
	# Corps : œuf crème, puis plastron d'écorce.
	var body := Ink.oval(tc, tw, th * 0.55, 30)
	Ink.part(ci, xf, body, skin, 2.2, 1.0, 0.7)
	if p > 0.3:
		var k := clampf((p - 0.3) / 0.4, 0.0, 1.0)
		var plate := PackedVector2Array([tc + Vector2(-tw * 0.75, -th * 0.38), tc + Vector2(tw * 0.85, -th * 0.4), tc + Vector2(tw * 0.95, th * (-0.1 + 0.35 * k)), tc + Vector2(tw * 0.1, th * (0.0 + 0.45 * k)), tc + Vector2(-tw * 0.8, th * (-0.1 + 0.3 * k))])
		Ink.part(ci, xf, plate, BARK, 1.8, 1.0, 0.6)
		# Rainures d'écorce et veine de sève.
		for i in 3:
			var x := -tw * 0.45 + i * tw * 0.45
			Ink.brush(ci, xf, PackedVector2Array([tc + Vector2(x, -th * 0.3), tc + Vector2(x + 1.0, th * 0.2 * k)]), 1.0, BARK["ombre"])
		Ink.brush(ci, xf, PackedVector2Array([tc + Vector2(-tw * 0.75, -th * 0.38), tc + Vector2(tw * 0.85, -th * 0.4)]), 1.6, BARK["reflet"], 0.4, 0.4)
	# Ceinture de lianes.
	Ink.brush(ci, xf, PackedVector2Array([tc + Vector2(-tw * 0.95, th * 0.22), tc + Vector2(0, th * 0.3), tc + Vector2(tw * 0.95, th * 0.2)]), 2.6, lv["ombre"], 0.6, 0.6)
	# Graine : flotte à côté au début, puis se loge dans le plastron et y bat.
	var core := tc + Vector2(tw * 0.25, -th * 0.12)
	if p > 0.5:
		if not Ink.mono:
			for i in 4:
				var a := PI * 0.5 * i + 0.4
				Ink.brush(ci, xf, PackedVector2Array([core, core + Vector2.from_angle(a) * (5.0 + 5.0 * p)]), 1.2, Color(gl, 0.7), 1.0, 0.0)
		K.seed(ci, xf * core, u, p, t, gl, 3.6 + 1.0 * p, 0.45)
	# Épaulière : une cupule de gland, puis hérissée selon la branche.
	if p > 0.25:
		var k := clampf((p - 0.25) / 0.5, 0.0, 1.0)
		var sp := tc + Vector2(tw * 0.55, -th * 0.42)
		Ink.part(ci, xf, Ink.lumpy(sp + Vector2(0, 2), 5.0 + 4.0 * k, 4.0 + 2.5 * k, 16, 0.08, 6.0), CUP, 1.6, 1.0, 0.5)
		_scales(ci, xf, sp + Vector2(0, 2), 5.0 + 4.0 * k, 4.0 + 2.5 * k)
		if build == "ronce" and k > 0.5:
			for i in 3:
				Ink.part(ci, xf, Ink.thorn(sp + Vector2(-4 + i * 4, -2), -PI * 0.5 - 0.5 + i * 0.5, 5.0 + 4.0 * k, 2.4), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.8, 1.0, 0.0)
	# Tête : visage crème aux yeux en amande, puis la cupule descend en heaume.
	var k := clampf((p - 0.3) / 0.45, 0.0, 1.0)
	var bone := {"clair": Color("f4ead6"), "ombre": Color("c9b38c"), "reflet": Color.WHITE}
	Ink.part(ci, xf, Ink.oval(hc, hr * 0.92, hr, 28), skin if k < 0.85 else bone, 2.2, 1.0, 0.8)
	var eye_y := hc.y + hr * 0.15
	if k < 0.85:
		K.eye(ci, xf, Vector2(hc.x + hr * 0.15, eye_y), 3.8, 3.4, -0.12, Art.ec("seve"))
		K.eye(ci, xf, Vector2(hc.x + hr * 0.65, eye_y - 0.3), 2.5, 3.0, -0.2, Art.ec("seve"))
	# Cupule / heaume.
	var low := lerpf(-0.1, 0.0, k)
	var helm := PackedVector2Array()
	var nh := 24
	for i in nh + 1:
		var a := PI + PI * i / nh
		helm.append(hc + Vector2(cos(a) * hr * (1.08 + 0.2 * k), sin(a) * hr * (1.1 + 0.15 * k) - hr * 0.05))
	var hbw := 1.08 + 0.2 * k
	helm.append(hc + Vector2(hr * hbw, hr * low))
	helm.append(hc + Vector2(hr * 0.55, hr * (low + 0.18 * k)))
	helm.append(hc + Vector2(-hr * 0.6, hr * (low + 0.1 * k)))
	helm.append(hc + Vector2(-hr * hbw, hr * low))
	Ink.part(ci, xf, helm, CUP, 2.2, 1.0, 0.7)
	_scales(ci, xf, hc + Vector2(-hr * 0.1, -hr * 0.45), hr * 0.85, hr * 0.5)
	# Bord de la cupule.
	Ink.brush(ci, xf, PackedVector2Array([hc + Vector2(-hr * hbw, hr * low), hc + Vector2(-hr * 0.6, hr * (low + 0.1 * k)), hc + Vector2(hr * 0.55, hr * (low + 0.18 * k)), hc + Vector2(hr * hbw, hr * low)]), 2.4 + 1.4 * k, CUP["reflet"], 0.5, 0.5)
	if k >= 0.85:
		# Visière : une seule fente de sève à la hauteur des yeux.
		K.slit(ci, xf, Vector2(hc.x + hr * 0.3, eye_y - 0.5), -0.08, hr * 1.2, 3.6, gl, 0.8 + 0.4 * p + 0.6 * cast)
		# Arête de la visière et grille de souffle.
		Ink.brush(ci, xf, PackedVector2Array([hc + Vector2(hr * 0.5, hr * 0.05), hc + Vector2(hr * 0.55, hr * 0.95)]), 1.4, bone["ombre"].darkened(0.2), 0.4, 0.4)
		for j in 2:
			var y := hr * (0.52 + j * 0.2)
			Ink.brush(ci, xf, PackedVector2Array([hc + Vector2(hr * 0.05, y), hc + Vector2(hr * 0.75, y - 0.5)]), 1.1, bone["ombre"].darkened(0.1), 0.3, 0.3)
		# Marques de branche sur les joues.
		Ink.flat(ci, xf, Ink.leaf(hc + Vector2(-hr * 0.35, hr * 0.35), PI * 0.5 - 0.15, hr * 0.5, 2.6), acc)
	# Tige de la cupule, qui devient une crête.
	var stem := PackedVector2Array([hc + Vector2(-1, -hr * 1.1), hc + Vector2(0, -hr * 1.1 - 4.0 - 4.0 * p), hc + Vector2(2.0 + 3.0 * p, -hr * 1.1 - 6.0 - 6.0 * p)])
	Ink.brush(ci, xf, stem, 4.6 + 1.0 * p, Ink.encre(), 1.0, 0.2)
	Ink.brush(ci, xf, stem, 2.8 + 1.0 * p, CUP["clair"], 1.0, 0.2)
	if p < 0.45:
		K.leaf(ci, xf, stem[2], -0.4 + 0.1 * sway, 8.0 * (1.0 - p / 0.45), 4.6, lv)
	# Panache (côté de devant).
	if p > 0.3:
		K.leaf(ci, xf, hc + Vector2(0, -hr * 1.0), PI * 1.08 + 0.06 * sin(t * 2.2), 12.0 + 20.0 * k, 5.4, {"clair": acc.lightened(0.15), "ombre": acc.darkened(0.3), "reflet": Color.WHITE}, -0.05, 1.0)
	# Bras de devant et lame : une brindille, puis une lame vivante au fil de la branche.
	var sh := tc + Vector2(tw * 0.6, -th * 0.3)
	var hand := tc + Vector2(tw + 4.0, th * 0.05)
	Ink.brush(ci, xf, PackedVector2Array([sh, sh.lerp(hand, 0.5) + Vector2(1, 2), hand]), 6.4, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, PackedVector2Array([sh, sh.lerp(hand, 0.5) + Vector2(1, 2), hand]), 4.2, skin["clair"] if p < 0.4 else BARK["clair"], 1.0, 1.0)
	var bl := 12.0 + 34.0 * p
	var ba := -0.95 - 0.25 * p + cast * 0.6
	var bd := Vector2.from_angle(ba)
	var btip := hand + bd * bl
	if p < 0.3:
		Ink.brush(ci, xf, PackedVector2Array([hand - bd * 3.0, hand + bd * bl * 0.5 + bd.orthogonal() * 1.5, btip]), 4.4, Ink.encre(), 1.0, 0.3)
		Ink.brush(ci, xf, PackedVector2Array([hand - bd * 3.0, hand + bd * bl * 0.5 + bd.orthogonal() * 1.5, btip]), 2.6, Color("8a6a4a"), 1.0, 0.3)
		K.leaf(ci, xf, hand + bd * bl * 0.6, ba - 0.9, 5.0, 3.0, lv, 0.0, 0.8)
	else:
		var bw := 4.0 + 3.0 * p
		var blade := PackedVector2Array([hand + bd * 3.0 + bd.orthogonal() * bw * 0.5, hand + bd * bl * 0.7 + bd.orthogonal() * bw * 0.55, btip, hand + bd * bl * 0.7 - bd.orthogonal() * bw * 0.45, hand + bd * 3.0 - bd.orthogonal() * bw * 0.5])
		if not Ink.mono and p > 0.7:
			Ink.halo(ci, xf * hand.lerp(btip, 0.6), bl * 0.35 * u, gl, (p - 0.7) * 2.5 + cast)
		Ink.part(ci, xf, blade, {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3), "reflet": Color.WHITE}, 1.6, 1.0, 1.0)
		Ink.brush(ci, xf, PackedVector2Array([hand + bd * 4.0 + bd.orthogonal() * bw * 0.32, hand + bd * bl * 0.72 + bd.orthogonal() * bw * 0.35, btip - bd * 2.0]), 1.6, acc, 0.6, 0.0)
		Ink.brush(ci, xf, PackedVector2Array([hand + bd * 4.0, btip - bd * 4.0]), 1.0, Art.bc("os").darkened(0.25))
		# Garde en racines tressées.
		var g := hand + bd * 2.5
		Ink.brush(ci, xf, PackedVector2Array([g + bd.orthogonal() * (5.0 + 2.0 * p), g + bd * 1.5, g - bd.orthogonal() * (5.0 + 2.0 * p)]), 3.8, Ink.encre(), 0.6, 0.6)
		Ink.brush(ci, xf, PackedVector2Array([g + bd.orthogonal() * (5.0 + 2.0 * p), g + bd * 1.5, g - bd.orthogonal() * (5.0 + 2.0 * p)]), 2.2, Color("8a6a4a"), 0.6, 0.6)
		K.leaf(ci, xf, g + bd.orthogonal() * 5.0, ba + 2.2, 6.0, 3.4, lv, 0.0, 0.8)
	Ink.part(ci, xf, Ink.oval(hand, 3.0, 2.8, 10), {"clair": Color("5b4636"), "ombre": Color("3f3026")}, 1.0)
	if p <= 0.5:
		K.seed(ci, xf * (tc + Vector2(-tw - 8.0, -th * 0.3 + sin(t * 2.6) * 1.4)), u, p, t, gl)


## Écailles de cupule : petits arcs en quinconce.
static func _scales(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float, ry: float) -> void:
	for r in 2:
		for i in 4:
			var q := c + Vector2((-0.6 + i * 0.4 + r * 0.2) * rx, (-0.3 + r * 0.5) * ry)
			Ink.brush(ci, xf, PackedVector2Array([q + Vector2(-2.2, 0), q + Vector2(0, 1.6), q + Vector2(2.2, 0)]), 0.9, CUP["ombre"].darkened(0.2), 0.3, 0.3)
