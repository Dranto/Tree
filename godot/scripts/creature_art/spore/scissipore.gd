## Scissipore (Spore, splitter), « Bestiaire d'herbier » : deux vesses-de-loup soudées, à moitié divisées,
## qui marchent sur un faisceau de filaments de mycélium. Le pli de la division couve de braise : à sa
## mort, elle se sépare en deux Sporules (qui sont chacune une de ses boules).
## Annonce (windup) : elle gonfle, les ostioles rougeoient ; frappe (strike) : bouffée de spores autour
## d'elle, puis elle se dégonfle.
##
## Pose : t, walk, moving, k (annonce 0 → 1), strike (0 → 1 après la bouffée, -1 : aucune), hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const Sp = preload("res://scripts/creature_art/spore/commun.gd")

## 100 unités en px du jeu : ~52 px de haut en 1080p.
const HEIGHT := 43.0
## La sorte dessine elle-même son collier d'élite (pose elite).
const DRAWS_ELITE := true


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
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	var kk := Anim.ease_out(k)
	var puff := 0.0 if strike < 0.0 else 1.0 - strike
	Ink.ground_shadow(ci, base, Vector2(0, 0), 36.0)
	# Gonflement (annonce, palpitation), dégonflement après la bouffée, écrasement du coup reçu.
	var beat := sin(t * (4.0 + 8.0 * kk)) * (0.02 + 0.03 * kk)
	var swell := 1.0 + 0.16 * kk + beat - 0.12 * puff
	var sq := Vector2(swell * (1.0 + 0.1 * hit), swell * (1.0 - 0.12 * hit) * (1.0 - 0.06 * puff))
	var bob := -absf(sin(walk * 2.0)) * 3.0 * mv
	var lean := 0.06 * mv + 0.08 * hit - 0.05 * kk
	var xf := base * Transform2D(lean, Vector2.ONE, 0.0, Vector2(0, -16 + bob)) * Transform2D(0.0, sq, 0.0, Vector2.ZERO)
	var fl := Sp.flesh()
	var back := {"clair": fl["clair"].darkened(0.12), "ombre": fl["ombre"].darkened(0.15), "reflet": fl["reflet"].darkened(0.1)}
	# Filaments-pattes : six faisceaux de mycélium, ceux du fond plus sombres.
	var hy := Art.bc("spore", "chapeau").darkened(0.1)
	for i in 5:
		var far := i % 2 == 0
		var x0 := -22.0 + i * 11.0
		var ph := walk * 2.0 + i * 1.7
		var foot := Vector2(x0 * 1.5 + (i - 2) * 4.0 + sin(ph) * 7.0 * mv, -maxf(cos(ph), 0.0) * 5.0 * mv)
		_hypha(ci, base, xf * Vector2(x0, -4), foot, hy.darkened(0.35) if far else hy)
	# La boule du fond (l'aînée), puis celle de devant.
	Sp.puffball(ci, xf, Vector2(-16, -40), 25.0, 30.0, back, kk, 8, 0.7)
	_seam(ci, xf, k, t)
	Sp.puffball(ci, xf, Vector2(12, -30), 27.0, 30.0, fl, kk, 9, 2.1)
	# La Flétrissure : une plaie de braise sur le flanc de la boule de devant.
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-3, -21), 6.0, 9.0, 18, 0.35, 5.0, 0.3), Color(Art.bc("ronge"), 0.85))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-4, -30), Vector2(0, -24), Vector2(-3, -18), Vector2(1, -14)]), 1.6, Art.bc("braise"))
	# Bouche : une fente dentelée sous les yeux.
	var jaw := PackedVector2Array()
	for i in 7:
		jaw.append(Vector2(20 + i * 2.6, -21 + (1.6 if i % 2 else -0.4) + 2.0 * kk * sin(PI * i / 6.0)))
	Ink.brush(ci, xf, jaw, 2.0 + 1.5 * kk, Art.bc("ronge"), 0.0, 0.0)
	# Visage : deux yeux de braise plissés qui suivent la cible, mandibules d'os.
	var lk := Vector2(cos(clampf(la, -0.8, 0.8)), sin(clampf(la, -0.8, 0.8))) * 2.0
	if hit > 0.4 or (k == 0.0 and Ink.blink(t, 0.5) > 0.0):
		Ink.brush(ci, xf, PackedVector2Array([Vector2(20, -34), Vector2(28, -33)]), 2.2, Ink.encre())
		Ink.brush(ci, xf, PackedVector2Array([Vector2(31, -33), Vector2(36, -32)]), 1.8, Ink.encre())
	else:
		Ink.ember(ci, xf, Ink.leaf(Vector2(19, -33) + lk, -0.15, 9.0, 4.6), 0.3 + 0.7 * kk)
		Ink.ember(ci, xf, Ink.leaf(Vector2(31, -34) + lk, -0.2, 5.5, 3.2), 0.3 + 0.7 * kk)
	var bone := {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}
	var bite := 0.25 * sin(t * 6.0) * (0.3 + kk)
	Ink.part(ci, xf, Ink.thorn(Vector2(32, -20), 0.5 + bite, 11.0, 4.2, 0.4), bone, 1.2, 1.0, 0.0)
	Ink.part(ci, xf, Ink.thorn(Vector2(34, -15), 0.1 - bite, 10.0, 3.8, 0.5), bone, 1.2, 1.0, 0.0)
	if elite:
		Sp.elite_rim(ci, xf, Ink.oval(Vector2(12, -30), 25.0, 28.0, 20).slice(11, 20))
		Sp.elite_caps(ci, xf, [Vector2(-26, -66), Vector2(-14, -70), Vector2(2, -58)], t)
	# Spores qui s'échappent des ostioles : un filet au repos, la bouffée à la frappe.
	Sp.spore_puff(ci, xf, Vector2(-14, -70), fposmod(t * 0.6, 1.0), 0.3 + 0.5 * kk, 3, 18.0)
	Sp.spore_puff(ci, xf, Vector2(15, -60), fposmod(t * 0.6 + 0.5, 1.0), 0.3 + 0.5 * kk, 3, 18.0)
	if strike >= 0.0 and not Ink.mono:
		var u := Anim.ease_out(strike)
		Sp.spore_puff(ci, xf, Vector2(-14, -70), u, 1.0 - strike * 0.6, 9, 55.0)
		Sp.spore_puff(ci, xf, Vector2(15, -60), u, 1.0 - strike * 0.6, 9, 55.0)
		# Anneau de spores qui roule au sol.
		var s := base.get_scale().abs().x
		for i in 16:
			var a := TAU * i / 16.0
			var q := base * Vector2(cos(a) * (30.0 + 80.0 * u), sin(a) * (30.0 + 80.0 * u) * Art.OMBRE_APLATI - 6.0)
			ci.draw_circle(q, (4.0 + 6.0 * u) * s, Color(Art.bc("spore", "spore"), 0.4 * (1.0 - strike)))


## Le pli de la division : une gorge sombre entre les deux boules, qui s'ouvre et rougeoie à l'annonce.
static func _seam(ci: CanvasItem, xf: Transform2D, k: float, t: float) -> void:
	var pts := PackedVector2Array([Vector2(-6, -64), Vector2(-4, -50), Vector2(-8, -36), Vector2(-5, -22), Vector2(-8, -10)])
	Ink.brush(ci, xf, pts, 4.0 + 2.0 * k, Art.bc("ronge"), 0.0, 0.0)
	Ink.brush(ci, xf, pts, 1.4 + 1.6 * k, Art.bc("braise").lerp(Art.bc("braise_coeur"), 0.5 * k), 0.0, 0.0)
	if k > 0.0:
		Ink.halo(ci, xf * Vector2(-6, -38), 14.0 * xf.get_scale().abs().x, Art.bc("braise"), k * (0.8 + 0.2 * sin(t * 12.0)))


## Une patte de mycélium : faisceau de filaments clairs, encre puis couleur, effilés vers le pied.
static func _hypha(ci: CanvasItem, base: Transform2D, hip_w: Vector2, foot: Vector2, col: Color) -> void:
	var hip := base.affine_inverse() * hip_w
	var knee := hip.lerp(foot, 0.5) + Vector2(4 if foot.x > hip.x else -4, -3)
	var pts := PackedVector2Array([hip, knee, foot])
	Ink.brush(ci, base, pts, 5.8, Ink.encre(), 1.0, 0.0)
	Ink.brush(ci, base, pts, 3.6, col, 1.0, 0.0)
	for s: float in [-1.0, 1.0]:
		Ink.brush(ci, base, PackedVector2Array([foot + Vector2(0, -1), foot + Vector2(s * 4.5, 0.6)]), 1.6, col.darkened(0.15), 1.0, 0.0)
