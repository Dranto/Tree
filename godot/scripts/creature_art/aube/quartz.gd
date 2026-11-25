## Colosse de quartz (Aube, lourd), direction « Bestiaire d'herbier » : une vieille tortue des falaises dont
## la carapace s'est changée en géode. La Flétrissure l'a fendue : par la fente, une forêt d'aiguilles
## de quartz a poussé, où la lumière reste piégée. Large et ancrée sur quatre pattes-piliers, tête basse
## au bec de pierre, braise dans les yeux et dans les fissures. Elle marche droit et lourdement ; à sa
## mort elle vole en éclats (le comportement « shatter » tire les éclats ; rien à annoncer).
##
## Pose : t, walk, moving, hit, look, elite (k, s'il est donné, fait seulement couver la braise).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/aube/verre.gd")

## 100 unités en px du jeu (1600×900) : ~79 px de haut à l'écran en 1080p (aiguilles comprises).
const HEIGHT := 66.0
## La sorte dessine elle-même sa parure d'élite (collier de prismes, liseré d'or).
const DRAWS_ELITE := true
const NECK := Vector2(40, -30)

## Aiguilles de la géode : [x du pied, y du pied, demi-largeur, longueur, inclinaison], du fond vers l'avant.
const NEEDLES := [
	[-26.0, -48.0, 5.0, 30.0, -0.45], [12.0, -52.0, 5.5, 34.0, 0.35], [-8.0, -56.0, 7.5, 46.0, -0.08],
	[4.0, -54.0, 6.0, 38.0, 0.18], [-18.0, -52.0, 6.0, 36.0, -0.28], [22.0, -46.0, 4.0, 22.0, 0.6],
	[-34.0, -40.0, 3.5, 18.0, -0.75],
]


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	Ink.ground_shadow(ci, base, Vector2(0, 0), 56.0)
	# Marche lourde : la carapace roule d'un côté à l'autre, s'affaisse à chaque pas.
	var rock := sin(walk) * 0.035 * mv
	var sink := absf(sin(walk)) * 2.5 * mv
	var sq := Vector2(1.0 + 0.06 * hit, 1.0 - 0.07 * hit) * Vector2(1.0, 1.0 + 0.012 * sin(t * TAU / 2.4))
	var xf := base * Transform2D(rock + 0.04 * hit, sq, 0.0, Vector2(0, sink))
	var body := V.pal()
	var skin := {"clair": Art.bc("aube", "ombre").lerp(Art.bc("aube", "clair"), 0.4), "ombre": Art.bc("aube", "ombre").darkened(0.25), "reflet": Art.bc("aube", "reflet")}
	var far := {"clair": skin["ombre"], "ombre": skin["ombre"].darkened(0.3), "reflet": skin["clair"]}
	# Pattes du fond (paire diagonale opposée à celles de devant).
	_pillar(ci, base, xf, Vector2(-30, -16), Vector2(-34, 0), maxf(-sin(walk), 0.0) * 6.0 * mv, far)
	_pillar(ci, base, xf, Vector2(22, -16), Vector2(26, 0), maxf(sin(walk), 0.0) * 6.0 * mv, far)
	# Queue courte.
	Ink.part(ci, xf, Ink.thorn(Vector2(-46, -20), PI + 0.35, 12.0, 9.0, -0.2), far, 2.0, 1.0, 0.0)
	# Les aiguilles de la géode, derrière le bord de la carapace (la braise y couve sous le choc).
	var tremble := sin(t * 40.0) * 0.04 * hit
	var glow := 0.4 + 0.3 * sin(t * 1.7) + 0.4 * k
	for i in NEEDLES.size():
		var n: Array = NEEDLES[i]
		V.needle(ci, xf, Vector2(n[0], n[1]), n[2], n[3], n[4] + tremble * (1 if i % 2 else -1), glow if i == 2 or i == 4 else 0.0)
	if not Ink.mono:
		V.sparkle(ci, xf * Vector2(-8 + sin(-0.08) * 46.0, -56 - 40.0), 10.0 * h / 100.0, Art.bc("aube", "lueur"), 0.4 + 0.6 * maxf(sin(t * 2.3), 0.0), t * 0.4)
		V.sparkle(ci, xf * Vector2(16, -80), 6.0 * h / 100.0, Art.bc("aube", "lueur"), 0.3 + 0.6 * maxf(sin(t * 1.9 + 2.0), 0.0))
	# La carapace : un dôme de pierre-verre, ouvert en haut par la géode.
	var shell := PackedVector2Array([Vector2(-50, -16), Vector2(-48, -32), Vector2(-38, -46), Vector2(-28, -50), Vector2(-20, -44), Vector2(-10, -50), Vector2(0, -46), Vector2(10, -52), Vector2(20, -46), Vector2(30, -46), Vector2(40, -34), Vector2(44, -16), Vector2(0, -10)])
	Ink.part(ci, xf, shell, body, 3.0, 1.0, 0.7)
	if not Ink.mono:
		# Écailles de la carapace (plaques), plus marquées dans l'ombre.
		for s: Array in [[Vector2(-44, -24), Vector2(-30, -30), Vector2(-14, -26)], [Vector2(-14, -26), Vector2(4, -32), Vector2(22, -28)], [Vector2(22, -28), Vector2(34, -32), Vector2(42, -22)], [Vector2(-30, -30), Vector2(-32, -42)], [Vector2(4, -32), Vector2(4, -44)]]:
			Ink.brush(ci, xf, PackedVector2Array(s), 1.8, body["ombre"].darkened(0.2))
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-44, -36), Vector2(-34, -44), Vector2(-24, -46)]), 1.6, Color(body["reflet"], 0.8))
		# Bord de la plastron : une bande claire au ras du sol.
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-48, -17), Vector2(-10, -12), Vector2(42, -17)]), 3.6, body["clair"].lerp(Art.bc("os"), 0.4), 1.0, 1.0)
		# Fissures de la Flétrissure : braise qui couve dans la pierre, plaques rongées, étincelles.
		Ink.flat(ci, xf, Ink.lumpy(Vector2(-36, -24), 9.0, 6.0, 16, 0.4, 6.0, 0.4), Art.bc("ronge"))
		Ink.flat(ci, xf, Ink.lumpy(Vector2(26, -36), 6.0, 5.0, 14, 0.4, 5.0, 1.2), Art.bc("ronge"))
		for c: PackedVector2Array in [PackedVector2Array([Vector2(-40, -28), Vector2(-34, -22), Vector2(-26, -26), Vector2(-20, -20)]), PackedVector2Array([Vector2(22, -40), Vector2(27, -34), Vector2(32, -38)])]:
			Ink.brush(ci, xf, c, 3.0, Ink.encre())
			Ink.brush(ci, xf, c, 1.4 + 0.8 * k, Art.bc("braise").lerp(Art.bc("braise_coeur"), k))
		Ink.sparks(ci, xf, Vector2(-30, -26), Vector2(-0.2, -1.0), 3, t * 0.7, 1.3, 0.6 + k)
		# Gravier de verre qui s'effrite à chaque pas.
		var crumble := absf(sin(walk)) * mv
		for j in 3:
			var u := fposmod(t * 1.2 + j * 0.33, 1.0)
			ci.draw_circle(xf * Vector2(-40 + j * 36, -14 + u * 12.0), (1.7 - j * 0.3) * h / 100.0, Color(Art.bc("aube", "verre"), crumble * (1.0 - u)))
	if o.get("elite", false):
		V.liseret(ci, xf, shell)
	# Tête basse au bout d'un cou épais, qui suit la cible (un peu).
	var hr := clampf(la, -0.35, 0.35) * 0.5
	var hx := xf * Transform2D(hr, Vector2(40, -26)) * Transform2D(0.0, Vector2(-40, 26))
	Ink.part(ci, xf, PackedVector2Array([Vector2(34, -36), Vector2(46, -38), Vector2(52, -30), Vector2(48, -18), Vector2(36, -16)]), skin, 2.4, 1.0, 0.4)
	if not Ink.mono:
		for j in 3:
			Ink.brush(ci, xf, PackedVector2Array([Vector2(38 + j * 4, -35), Vector2(37 + j * 4, -19)]), 1.0, skin["ombre"])
	if o.get("elite", false):
		V.collar(ci, xf, NECK, 9.0, 6.0, 6)
	var head := PackedVector2Array([Vector2(46, -40), Vector2(58, -44), Vector2(68, -40), Vector2(74, -32), Vector2(70, -24), Vector2(62, -20), Vector2(50, -22), Vector2(44, -30)])
	Ink.part(ci, hx, head, skin, 2.6, 1.0, 0.7)
	# Bec de pierre, et une petite aiguille de quartz sur le crâne.
	Ink.part(ci, hx, PackedVector2Array([Vector2(66, -30), Vector2(76, -31), Vector2(73, -23), Vector2(64, -22)]), {"clair": Art.bc("os").darkened(0.15), "ombre": Art.bc("os").darkened(0.5)}, 1.8, 1.0, 0.0)
	V.needle(ci, hx, Vector2(58, -42), 2.6, 11.0, 0.4)
	# Œil de braise sous une arcade lourde.
	Ink.brush(ci, hx, PackedVector2Array([Vector2(56, -38), Vector2(62, -40), Vector2(68, -37)]), 2.6, Ink.encre())
	if hit > 0.4 or Ink.blink(t, 0.9) > 0.0:
		Ink.brush(ci, hx, PackedVector2Array([Vector2(59, -34), Vector2(66, -34)]), 2.4, Ink.encre())
	else:
		Ink.ember(ci, hx, Ink.leaf(Vector2(59, -34), -0.1, 8.0, 4.2), 0.35 + 0.5 * k)
	# Pattes de devant.
	_pillar(ci, base, xf, Vector2(-20, -14), Vector2(-20, 0), maxf(sin(walk), 0.0) * 6.0 * mv, skin)
	_pillar(ci, base, xf, Vector2(32, -14), Vector2(36, 0), maxf(-sin(walk), 0.0) * 6.0 * mv, skin)


## Patte-pilier : haut sous la carapace (local, suit le roulis) → pied posé au sol (repère des pieds),
## levé de lift ; écailles et griffes d'os.
static func _pillar(ci: CanvasItem, base: Transform2D, xf: Transform2D, top: Vector2, foot: Vector2, lift: float, col: Dictionary) -> void:
	var tp := base.affine_inverse() * (xf * top)
	var f := foot + Vector2(0, -lift)
	var leg := PackedVector2Array([tp + Vector2(-8, 0), f + Vector2(-9, -2), f + Vector2(-8, 1), f + Vector2(9, 1), f + Vector2(10, -2), tp + Vector2(8, 0)])
	Ink.part(ci, base, leg, col, 2.4, 1.0, 0.0)
	if Ink.mono:
		return
	for j in 2:
		var y := lerpf(tp.y, f.y, 0.35 + j * 0.3)
		Ink.brush(ci, base, PackedVector2Array([Vector2(lerpf(tp.x, f.x, 0.4) - 7, y), Vector2(lerpf(tp.x, f.x, 0.4) + 7, y + 1)]), 1.1, col["ombre"].darkened(0.2))
	for j in 3:
		Ink.flat(ci, base, Ink.oval(f + Vector2(-5 + j * 5, 0), 2.2, 1.6, 8), Art.bc("os").darkened(0.15), 0.8)
