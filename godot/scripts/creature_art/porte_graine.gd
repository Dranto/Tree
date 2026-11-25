## Porte-Graine en vue de trois quarts, direction « Bestiaire d'herbier » : le même héros (corps crème,
## capuche de feuillage, cape de trois feuilles, pieds-racines, graine-lanterne), debout, visage de trois
## quarts, avec l'encre commune aux Flétris. Ses feuilles prennent la couleur de la branche dominante
## du build (Art.FEUILLES_BUILD) ; la lanterne suit la visée.
##
## Pose : t, walk, moving, cast (lancer 0 → 1), hit, look (visée, radians), build ("aucun", "ronce", "seve").
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")

## 100 unités en px du jeu (1600×900) : ~46 px de haut à l'écran en 1080p (rayon 14 aujourd'hui : ~34 px).
const HEIGHT := 38.0


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var cast: float = o.get("cast", o.get("k", 0.0))
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var build: String = o.get("build", "aucun")
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	var lv: Dictionary = Art.FEUILLES_BUILD.get(build, Art.FEUILLES_BUILD["aucun"])
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	# Halo de sève au sol : il est vivant, on le retrouve d'un coup d'œil dans la mêlée.
	if not Ink.mono:
		var hb := 0.5 + 0.5 * sin(t * TAU / 2.4)
		for i in 3:
			var gr := 84.0 - i * 20.0
			var glow := base * Ink.oval(Vector2(0, -2), gr, gr * 0.5, 36)
			Ink._poly(ci, glow, Color(Art.ec("seve"), 0.06 + 0.03 * hb))
	Ink.ground_shadow(ci, base, Vector2(0, 0), 28.0)
	var bob := -absf(sin(walk)) * 5.0 * mv + sin(t * TAU / 2.4) * 0.8
	var sq := Vector2(1.0 + 0.1 * hit + 0.04 * cast, 1.0 - 0.12 * hit - 0.03 * cast)
	var lean := 0.08 * mv - 0.1 * hit
	var xf := base * Transform2D(lean, sq, 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2(0, bob))
	var leaf := {"clair": lv["clair"], "ombre": lv["ombre"], "reflet": lv["reflet"]}
	var leaf_far := {"clair": lv["ombre"].lerp(lv["clair"], 0.4), "ombre": lv["ombre"].darkened(0.25), "reflet": lv["clair"]}
	# Cape : trois feuilles dans le dos, qui flottent à l'opposé de la marche.
	for i in 3:
		var a := PI * (0.62 + i * 0.14) + 0.08 * sin(t * 3.0 + i) + 0.18 * mv * sin(walk * 2.0 + i)
		var l := 42.0 - absf(i - 1.0) * 6.0
		var pts := Ink.leaf(Vector2(-8, -50 + i * 4.0), a, l, 22.0, 0.05)
		Ink.part(ci, xf, pts, leaf_far if i != 1 else leaf, 2.0, 1.0, 0.5)
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-8, -50 + i * 4.0), Vector2(-8, -50 + i * 4.0) + Vector2.from_angle(a) * l * 0.85]), 1.4, lv["ombre"].darkened(0.35))
		if build == "ronce":
			# Épines sur le bord de la cape.
			for j in 2:
				var q := Vector2(-8, -50 + i * 4.0) + Vector2.from_angle(a) * l * (0.45 + 0.25 * j) + Vector2.from_angle(a + PI / 2.0) * 7.0
				Ink.part(ci, xf, Ink.thorn(q, a + PI / 2.0 + 0.4, 6.0, 3.0), {"clair": lv["detail"], "ombre": lv["detail"].darkened(0.4)}, 1.0, 1.0, 0.0)
		elif build == "seve":
			Ink.brush(ci, xf, PackedVector2Array([Vector2(-8, -50 + i * 4.0) + Vector2.from_angle(a) * 6.0, Vector2(-8, -50 + i * 4.0) + Vector2.from_angle(a) * l * 0.8]), 1.0, lv["detail"])
	# Pieds-racines.
	var sw := sin(walk) * 8.0 * mv
	var rootc := {"clair": Art.ec("racine"), "ombre": Art.ec("racine", "sombre"), "reflet": Art.ec("racine", "clair")}
	Ink.part(ci, base, Ink.oval(Vector2(12 - sw, -4 - maxf(-sin(walk), 0.0) * 5.0 * mv), 8.0, 5.5, 16), {"clair": rootc["ombre"].lightened(0.15), "ombre": rootc["ombre"]}, 1.8, 1.0, 0.0)
	# Corps : un œuf crème.
	var body := Ink.oval(Vector2(0, -40), 28.0, 31.0, 40)
	var cream := {"clair": Art.c("joueur"), "ombre": Art.c("joueur").darkened(0.2).lerp(Color("b49a7a"), 0.3), "reflet": Color.WHITE}
	Ink.part(ci, xf, body, cream, 2.4, 1.0, 0.8)
	Ink.part(ci, base, Ink.oval(Vector2(-10 + sw, -4 - maxf(sin(walk), 0.0) * 5.0 * mv), 9.0, 6.0, 16), rootc, 1.8, 1.0, 0.3)
	# Capuche de feuillage : couvre le crâne et la nuque, bord festonné de pointes de feuilles au-dessus
	# des yeux, ouverte sur le visage.
	var hood := PackedVector2Array()
	var hc := Vector2(0, -40)
	for i in 25:
		var a := lerpf(-0.30, -PI - 0.95, i / 24.0)
		hood.append(hc + Vector2.from_angle(a) * Vector2(30.5, 33.5))
	for i in 13:
		var u := i / 12.0
		var a := lerpf(-PI - 0.95, -0.30, u)
		var rr := lerpf(0.86, 0.62, sin(u * PI * 0.5)) if u < 0.7 else lerpf(0.62, 0.97, (u - 0.7) / 0.3)
		rr -= 0.07 if i % 2 == 1 else 0.0
		hood.append(hc + Vector2.from_angle(a) * Vector2(28.0, 31.0) * rr)
	Ink.part(ci, xf, hood, leaf, 2.2, 1.0, 0.7)
	for i in 5:
		var a := lerpf(-PI - 0.7, -0.6, i / 4.0)
		Ink.brush(ci, xf, PackedVector2Array([hc + Vector2.from_angle(a) * Vector2(19, 21), hc + Vector2.from_angle(a) * Vector2(29, 32)]), 1.3, lv["ombre"].darkened(0.3))
	# Pousse au sommet (une baie de ronce pour un build Ronce, une goutte de sève pour un build Sève).
	var top := Vector2(-6, -73)
	Ink.brush(ci, xf, PackedVector2Array([top + Vector2(0, 4), top + Vector2(-2, -4), top + Vector2(2, -10)]), 3.0, lv["ombre"], 1.0, 0.3)
	Ink.part(ci, xf, Ink.leaf(top + Vector2(1, -8), -2.4, 12.0, 6.5), leaf, 1.4, 1.0, 0.5)
	Ink.part(ci, xf, Ink.leaf(top + Vector2(2, -9), -0.5, 10.0, 5.5), leaf, 1.4, 1.0, 0.5)
	if build == "ronce":
		Ink.part(ci, xf, Ink.lumpy(top + Vector2(10, 2), 4.2, 4.2, 14, 0.12, 8.0), {"clair": lv["detail"], "ombre": lv["detail"].darkened(0.45), "reflet": Color.WHITE}, 1.2)
	elif build == "seve" and not Ink.mono:
		Ink.halo(ci, xf * (top + Vector2(2, -12)), 7.0 * h / 100.0, Art.ec("seve"), 1.2)
		Ink.flat(ci, xf, Ink.oval(top + Vector2(2, -12), 2.4, 3.0, 10), lv["detail"])
	# Visage de trois quarts : deux yeux (celui du fond plus étroit), regard vers la visée.
	var gaze := Vector2.from_angle(clampf(la, -1.0, 1.0)) * 1.5
	if hit > 0.3:
		Ink.brush(ci, xf, PackedVector2Array([Vector2(7, -42), Vector2(13, -41)]), 2.2, Ink.encre())
		Ink.brush(ci, xf, PackedVector2Array([Vector2(19, -42), Vector2(23, -41.5)]), 1.8, Ink.encre())
	else:
		Ink.flat(ci, xf, Ink.oval(Vector2(10, -42) + gaze, 3.2, 4.4, 14), Ink.encre())
		Ink.flat(ci, xf, Ink.oval(Vector2(21.5, -42.5) + gaze, 2.3, 4.0, 12), Ink.encre())
		if not Ink.mono:
			ci.draw_circle(xf * (Vector2(9, -43.5) + gaze), 1.1 * h / 100.0, Color.WHITE)
			ci.draw_circle(xf * (Vector2(20.8, -44) + gaze), 0.8 * h / 100.0, Color.WHITE)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(13, -33), Vector2(16, -31.5), Vector2(19, -33)]), 1.4, Ink.encre())
	if not Ink.mono:
		ci.draw_circle(xf * Vector2(6, -35), 3.0 * h / 100.0, Color(Art.ec("saignement", "clair"), 0.18))
	# Graine-lanterne : flotte devant lui, dans l'axe de la visée.
	var la2 := clampf(la, -1.1, 1.1)
	var lp := Vector2(2, -44) + Vector2.from_angle(la2) * Vector2(44.0, 36.0) + Vector2(0, sin(t * 2.6) * 2.0)
	var lw := base * Transform2D(0.0, Vector2(0, bob)) * lp
	if not Ink.mono:
		Ink.halo(ci, lw, (14.0 + 10.0 * cast) * h / 100.0, Art.ec("seve"), 1.4 + cast)
		for i in 3:
			var m := lw + Vector2.from_angle(t * 2.6 + i * TAU / 3.0) * 9.0 * h / 100.0
			ci.draw_circle(m, 0.9 * h / 100.0, Color(Art.ec("seve", "clair"), 0.5 + 0.4 * sin(t * 4.0 + i * 2.0)))
	var seedx := Transform2D(0.0, base.get_scale(), 0.0, lw)
	Ink.part(ci, seedx, Ink.oval(Vector2.ZERO, 5.5, 4.4, 16), {"clair": Art.ec("seve", "sombre").lightened(0.35), "ombre": Art.ec("seve", "sombre"), "reflet": Art.ec("seve", "clair")}, 1.4)
	if not Ink.mono:
		ci.draw_circle(lw + Vector2(-0.8, -0.8) * h / 100.0, 2.4 * h / 100.0, Art.ec("seve", "clair").lerp(Art.ec("seve"), 0.3 * cast))
		if cast > 0.0:
			for i in 5:
				var a := (look) + (i - 2) * 0.35
				ci.draw_line(lw + Vector2.from_angle(a) * 8.0 * h / 100.0, lw + Vector2.from_angle(a) * (13.0 + 9.0 * cast) * h / 100.0, Color(Art.ec("seve", "clair"), 0.85 * cast), 1.6 * h / 100.0, true)
