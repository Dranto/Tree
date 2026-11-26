## Luciole flétrie (Aube, essaim), direction « Bestiaire d'herbier » : une luciole des falaises de verre,
## corps de verre fumé, deux paires d'ailes de vitre qui battent vite. Sa lanterne (l'abdomen) ne
## donne plus qu'une lumière sale, fêlée de braise. Petite et simple : elle vole, fond sur le héros en
## zigzag et blesse au contact (pas d'annonce).
##
## Pose : t, walk (inutilisé : elle vole), moving (0 → 1, penchée vers l'avant), hit (1 → 0), look,
## elite (parure d'élite ; les lucioles n'en ont pas en jeu, gardée pour la galerie).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/aube/verre.gd")

## 100 unités en px du jeu (1600×900) : ~36 px de long à l'écran en 1080p (ailes et ombre comprises).
const HEIGHT := 38.0
## Les lucioles ne sont jamais élites (enemies.json) ; si le moteur en faisait une, il poserait le collier ici.
const NECK := Vector2(11, -56)


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var mv: float = o.get("moving", 0.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	# Vol : elle flotte au-dessus de son ombre, monte et descend vite ; l'ombre respire avec la hauteur.
	var hover := sin(t * 7.0) * 4.0 + sin(t * 2.3) * 2.0
	Ink.ground_shadow(ci, base, Vector2(2, 0), 20.0 - hover * 0.6)
	var lean := 0.22 * mv + clampf(la, -0.6, 0.6) * 0.25 + 0.3 * hit
	var sq := Vector2(1.0 + 0.12 * hit, 1.0 - 0.14 * hit)
	var xf := base * Transform2D(0.0, Vector2(0, -52 + hover)) * Transform2D(lean, sq, 0.0, Vector2.ZERO)
	var body := V.pal()
	var flap := absf(sin(t * 23.0))
	# Ailes du fond (plus sombres), derrière le corps.
	_wings(ci, xf, flap, 0.0, true)
	# Lanterne : l'abdomen, une ampoule de verre qui luit d'une lumière sale, fêlée de braise.
	var glow := 0.55 + 0.45 * sin(t * 4.0)
	var lamp := Ink.lumpy(Vector2(-20, 6), 21.0, 15.0, 30, 0.04, 6.0, 0.5)
	if not Ink.mono:
		Ink.halo(ci, xf * Vector2(-22, 7), 30.0 * xf.get_scale().abs().x, Art.bc("aube", "detail"), 0.8 * glow)
	Ink.part(ci, xf, lamp, {"clair": Art.bc("aube", "lueur").lerp(Art.bc("aube", "detail"), 0.55), "ombre": Art.bc("aube", "detail").lerp(Art.bc("ronge"), 0.6), "reflet": Art.bc("aube", "lueur")}, 2.6, 1.0, 1.0)
	if not Ink.mono:
		# Cœur de la lanterne qui pulse, deux anneaux fins, et la fêlure de braise de la Flétrissure.
		ci.draw_circle(xf * Vector2(-18, 4), 7.0 * xf.get_scale().abs().x, Ink.shade(Color(Art.bc("aube", "lueur"), 0.35 + 0.4 * glow)))
		for i in 2:
			var x := -9.0 - i * 13.0
			Ink.brush(ci, xf, PackedVector2Array([Vector2(x + 2, -7), Vector2(x - 1, 6), Vector2(x + 1, 19)]), 1.1, Color(Art.bc("ronge"), 0.6))
		Ink.flat(ci, xf, Ink.lumpy(Vector2(-31, 14), 8.0, 6.0, 14, 0.35, 5.0, 0.4), Art.bc("ronge"))
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-36, 10), Vector2(-30, 13), Vector2(-26, 9), Vector2(-20, 13)]), 1.6, Art.bc("braise"))
		Ink.sparks(ci, xf, Vector2(-34, 18), Vector2(-0.3, 1.0), 2, t * 1.4, 1.6, 0.8)
	# Thorax et tête : verre fumé.
	Ink.part(ci, xf, Ink.oval(Vector2(5, -2), 13.0, 11.0, 20, -0.3), body, 2.4, 1.0, 0.8)
	var head := Ink.oval(Vector2(20, -6), 10.0, 9.0, 18)
	Ink.part(ci, xf, head, body, 2.4, 1.0, 0.9)
	if o.get("elite", false):
		V.collar(ci, xf, Vector2(11, -4), 8.0, 7.0, 5)
		V.liseret(ci, xf, lamp)
	# Pattes repliées sous le vol, qui pendent et gigotent.
	for i in 3:
		var b0 := Vector2(-2 + i * 7, 7)
		var sw := sin(t * 9.0 + i * 1.7) * 2.0
		var leg := PackedVector2Array([b0, b0 + Vector2(-3 + sw, 8), b0 + Vector2(-7 + sw, 13)])
		Ink.brush(ci, xf, leg, 3.2, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, xf, leg, 1.4, V.ash().lightened(0.2), 1.0, 0.0)
	# Antennes plumeuses qui tâtent l'air.
	for j in 2:
		var a0 := -1.0 - j * 0.45 + sin(t * 5.0 + j) * 0.15
		var r0 := Vector2(24 - j * 3, -13)
		var ant := PackedVector2Array([r0, r0 + Vector2.from_angle(a0) * 9.0, r0 + Vector2.from_angle(a0 + 0.6) * 17.0])
		Ink.brush(ci, xf, ant, 2.6, Ink.encre(), 1.0, 0.0)
		if not Ink.mono:
			Ink.brush(ci, xf, ant, 1.0, Art.bc("aube", "clair"), 1.0, 0.0)
	# Œil de braise (le grand œil composé), plissé sous le coup.
	if hit > 0.4:
		Ink.brush(ci, xf, PackedVector2Array([Vector2(21, -7), Vector2(28, -6)]), 2.4, Ink.encre())
	else:
		Ink.ember(ci, xf, Ink.oval(Vector2(24, -6), 4.6, 4.0, 14), 0.4 + 0.3 * mv)
	# Ailes de devant : vitres claires qui battent par-dessus le corps.
	_wings(ci, xf, flap, 1.0, false)
	# L'éclat du verre sur la lanterne.
	V.sparkle(ci, xf * Vector2(-26, -2), 7.0 * xf.get_scale().abs().x, Art.bc("aube", "lueur"), 0.4 + 0.5 * maxf(sin(t * 3.0), 0.0))


## Une paire d'ailes (avant et arrière) : battement flap (0 : rabattues, 1 : levées).
static func _wings(ci: CanvasItem, xf: Transform2D, flap: float, near: float, back: bool) -> void:
	var tint := Art.bc("aube", "verre").lerp(Art.bc("aube", "ombre"), 0.55 if back else 0.0)
	for j in 2:
		var root := Vector2(2 - j * 9, -9)
		var a := lerpf(-PI * 0.5 - 0.25 - j * 0.35, -PI * 0.92 - j * 0.15, 1.0 - flap) + (0.25 if back else 0.0)
		var l := (40.0 if j == 0 else 31.0) * (0.85 if back else 1.0)
		var w := (17.0 if j == 0 else 14.0)
		var pts := Ink.leaf(root, a, l, w, -0.08)
		var d := Vector2.from_angle(a)
		var veins := [PackedVector2Array([root + d * 4.0, root + d * l * 0.9]), PackedVector2Array([root + d * l * 0.3, root + d * l * 0.62 + d.orthogonal() * w * 0.3])]
		V.pane(ci, xf, pts, tint, 0.5 + 0.12 * near if not back else 0.7, 1.4, veins if not back else [])
