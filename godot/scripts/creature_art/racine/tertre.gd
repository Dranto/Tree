## Tertre de pierre (Racine, lourd), « Bestiaire d'herbier » : un tumulus de la forêt pétrifiée qui s'est
## levé. Une masse de roche voûtée, la souche d'un chêne pétrifié plantée dans le dos (ses cernes à nu),
## deux bras de racines tordues terminés par des poings de pierre énormes. La Flétrissure fend la roche :
## la braise couve dans les fentes et sous l'arcade. Large et ancré, il marche sur les poings.
## Annonce : il se dresse et lève les deux poings au-dessus de la tête, les fentes s'allument.
## Frappe : les poings s'écrasent devant lui (poussière ; l'onde est l'annonce au sol) ; retour : affaissé dans la poussière.
##
## Pose : t, walk, moving, k (annonce 0 → 1), state, strike (0 → 1 après la frappe, -1 : aucune), hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const R = preload("res://scripts/creature_art/racine/outils.gd")

## 100 unités en px du jeu (1600×900) : ~77 px de haut et ~100 px de large à l'écran en 1080p.
const HEIGHT := 64.0
const DRAWS_ELITE := true
## La tête ne suit pas la cible (un lourd fait front tout entier) : un seul regard à cuire.
const LOOKS := false


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var p := R.read(o)
	var t: float = p["t"]
	var walk: float = p["walk"]
	var mv: float = p["mv"]
	var hit: float = p["hit"]
	var strike: float = p["strike"]
	var recover: bool = p["state"] == "recover"
	var k: float = p["k"] if p["state"] == "windup" or p["state"] == "" else 0.0
	Ink.flash = hit
	var base := Ink.frame(feet, h, p["flip"])
	var kk := Anim.ease_out(k)
	var slam := 0.0 if strike < 0.0 else clampf(1.0 - strike, 0.0, 1.0)
	var slump := 1.0 if recover and slam <= 0.0 else slam
	Ink.ground_shadow(ci, base, Vector2(4, 0), 58.0)
	# L'onde de choc au sol est l'annonce du comportement (couche sol) : le dessin ne garde que la
	# poussière soulevée, pour rester dans une case d'atlas raisonnable.
	if recover or slam > 0.0:
		R.dust(ci, base, Vector2(-30, -4), Vector2(-0.6, 0), 4, t, 4.0, 0.6 + 0.4 * slam)
	# Marche lourde : il bascule d'un poing-pied sur l'autre.
	var rock := sin(walk) * 0.035 * mv
	var rise := -2.0 * kk * (1.0 - slam) + 5.0 * slump
	var lean := -0.06 * kk * (1.0 - slam) + 0.1 * slam + 0.05 * hit + (0.06 if recover else 0.0)
	var sq := Vector2(1.0 + 0.05 * hit + 0.06 * slam - 0.04 * kk, 1.0 - 0.06 * hit - 0.06 * slam + 0.05 * kk)
	var xf := base * Transform2D(rock + lean, sq, 0.0, Vector2(4, -2)) * Transform2D(0.0, Vector2(-4, rise))
	var stone := R.pal("pierre")
	var far := {"clair": stone["ombre"], "ombre": stone["ombre"].darkened(0.3), "reflet": stone["clair"]}
	var wood := R.pal("bois")
	# Poings : posés devant au repos, levés pendant l'annonce, écrasés au sol à la frappe.
	var up := kk * (1.0 - slam)
	var lift_f := maxf(sin(walk), 0.0) * 7.0 * mv
	var lift_n := maxf(-sin(walk), 0.0) * 7.0 * mv
	var fist_far := Vector2(42, -14 - lift_f).lerp(Vector2(38, -80), up).lerp(Vector2(42, -12), slam)
	var fist_near := Vector2(18, -12 - lift_n).lerp(Vector2(18, -82), up).lerp(Vector2(28, -10), slam)
	# Bras et poing du fond.
	_arm(ci, xf, Vector2(20, -66), fist_far, {"clair": wood["ombre"], "ombre": wood["ombre"].darkened(0.3), "reflet": wood["clair"]}, t)
	_fist(ci, xf, fist_far, far, 0.9, up)
	# Jambes trapues de roche, orteils de racine.
	Ink.part(ci, base, Ink.lumpy(Vector2(-6, -8), 15.0, 10.0, 18, 0.12, 4.0), far, 2.4)
	Ink.part(ci, base, Ink.lumpy(Vector2(-34, -8), 16.0, 10.0, 18, 0.12, 4.0, 1.0), stone, 2.4)
	for j in 3:
		Ink.brush(ci, base, PackedVector2Array([Vector2(-26 + j * 5, -3), Vector2(-20 + j * 7, 1)]), 2.0, wood["ombre"], 1.0, 0.0)
	# Souche de chêne pétrifiée plantée dans le dos (derrière la masse).
	_stump(ci, xf, t)
	# La masse voûtée.
	var hump := PackedVector2Array([
		Vector2(-56, -14), Vector2(-62, -40), Vector2(-54, -66), Vector2(-34, -84), Vector2(-8, -90),
		Vector2(16, -82), Vector2(34, -68), Vector2(42, -48), Vector2(38, -26), Vector2(26, -12), Vector2(-20, -8)])
	Ink.part(ci, xf, hump, stone, 3.2, 1.0, 0.6)
	# Strates de la roche, flanc dans l'ombre.
	Ink.flat(ci, xf, PackedVector2Array([Vector2(26, -76), Vector2(38, -62), Vector2(42, -46), Vector2(38, -26), Vector2(26, -12), Vector2(18, -14), Vector2(28, -34), Vector2(30, -58)]), Color(stone["ombre"], 0.75))
	for y: float in [-30.0, -48.0, -66.0]:
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-58, y + 4), Vector2(-30, y - 2), Vector2(0, y + 2), Vector2(28, y - 3)]), 1.5, stone["ombre"].darkened(0.2))
	# Racines pétrifiées qui ceinturent la roche.
	var belt := PackedVector2Array([Vector2(-60, -30), Vector2(-36, -40), Vector2(-8, -34), Vector2(18, -44), Vector2(38, -40)])
	Ink.brush(ci, xf, belt, 7.0, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, belt, 4.6, wood["clair"], 1.0, 1.0)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-58, -32), Vector2(-36, -42), Vector2(-10, -37)]), 1.2, wood["reflet"])
	# La Flétrissure fend la roche : plaie sombre, fentes de braise qui s'allument à l'annonce.
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-40, -58), 9.0, 11.0, 18, 0.35, 6.0, 0.4), Art.bc("ronge"))
	var glow := 0.35 + 0.65 * maxf(kk, slam)
	for crack: PackedVector2Array in [
			PackedVector2Array([Vector2(-44, -70), Vector2(-38, -60), Vector2(-42, -50), Vector2(-34, -40)]),
			PackedVector2Array([Vector2(-12, -84), Vector2(-6, -70), Vector2(-12, -58)]),
			PackedVector2Array([Vector2(10, -24), Vector2(4, -16), Vector2(8, -10)])]:
		Ink.brush(ci, xf, crack, 3.6, Ink.encre())
		if not Ink.mono:
			Ink.brush(ci, xf, crack, 1.3 + 1.4 * glow, Art.bc("braise").lerp(Art.bc("braise_coeur"), kk))
	Ink.sparks(ci, xf, Vector2(-40, -66), Vector2(-0.2, -1.0), 3, t * 0.9, 1.4, 0.5 + kk)
	# Lichens clairs et mousse : la forêt qui reprend.
	for q: Vector3 in [Vector3(-48, -50, 3.2), Vector3(-22, -78, 2.6), Vector3(4, -60, 2.2), Vector3(-26, -20, 2.8)]:
		Ink.flat(ci, xf, Ink.lumpy(Vector2(q.x, q.y), q.z * 1.4, q.z, 10, 0.3, 3.0, q.x), Art.bc("racine", "reflet").lerp(Art.ec("racine", "clair"), 0.45))
	# Tête enfoncée entre les épaules : arcade de pierre, yeux de braise dessous. Comme le Menhir, elle ne
	# tourne pas avec le regard (un lourd fait front tout entier).
	var hx := xf
	Ink.part(ci, hx, Ink.lumpy(Vector2(32, -58), 15.0, 13.0, 22, 0.08, 4.0), {"clair": stone["clair"].darkened(0.08), "ombre": stone["ombre"], "reflet": stone["reflet"]}, 2.6, 1.0, 0.5)
	Ink.part(ci, hx, PackedVector2Array([Vector2(18, -66), Vector2(30, -74), Vector2(48, -68), Vector2(46, -62), Vector2(30, -64), Vector2(20, -60)]), stone, 2.0, 1.0, 0.8)
	Ink.flat(ci, hx, PackedVector2Array([Vector2(24, -62), Vector2(46, -62), Vector2(44, -54), Vector2(26, -55)]), Art.bc("ronge"))
	if hit > 0.4:
		Ink.brush(ci, hx, PackedVector2Array([Vector2(29, -59), Vector2(36, -58)]), 2.2, Ink.encre())
		Ink.brush(ci, hx, PackedVector2Array([Vector2(39, -58), Vector2(44, -57)]), 1.8, Ink.encre())
	else:
		Ink.ember(ci, hx, Ink.leaf(Vector2(29, -59), -0.1, 7.0, 3.6), 0.3 + 0.7 * maxf(kk, slam))
		Ink.ember(ci, hx, Ink.leaf(Vector2(39, -58), -0.15, 5.0, 3.0), 0.3 + 0.7 * maxf(kk, slam))
	# Mâchoire : une fente de braise.
	Ink.brush(ci, hx, PackedVector2Array([Vector2(28, -48), Vector2(36, -46), Vector2(44, -49)]), 2.6, Ink.encre())
	if not Ink.mono:
		Ink.brush(ci, hx, PackedVector2Array([Vector2(29, -48), Vector2(36, -46.5), Vector2(43, -49)]), 1.0 + 1.2 * kk, Art.bc("braise"))
	if p["elite"]:
		R.elite(ci, xf, Vector2(4, -80), Vector2(40, -40), 6.0, PackedVector2Array([Vector2(-60, -44), Vector2(-52, -68), Vector2(-32, -86), Vector2(-6, -92)]), t, 1.4)
	if recover and slam <= 0.0:
		R.dazed(ci, xf, Vector2(30, -84), t, 14.0, 0.8)
	# Bras et poing de devant.
	_arm(ci, xf, Vector2(-16, -56), fist_near, wood, t + 0.7)
	_fist(ci, xf, fist_near, stone, 1.0, up)


## Souche de chêne pétrifiée dans le dos : tronc coupé, cernes à nu, une branche cassée, mousse.
static func _stump(ci: CanvasItem, xf: Transform2D, t: float) -> void:
	var wood := R.pal("bois")
	var pw := {"clair": wood["clair"].lerp(Art.bc("racine", "clair"), 0.45), "ombre": wood["ombre"].lerp(Art.bc("racine", "ombre"), 0.4), "reflet": Art.bc("racine", "reflet")}
	var trunk := PackedVector2Array([Vector2(-44, -70), Vector2(-42, -92), Vector2(-14, -94), Vector2(-10, -74)])
	Ink.part(ci, xf, trunk, pw, 2.6, 1.0, 0.4)
	for i in 3:
		var x := -38.0 + i * 9.0
		Ink.brush(ci, xf, PackedVector2Array([Vector2(x, -100), Vector2(x + 1, -88), Vector2(x - 1, -76)]), 1.3, pw["ombre"].darkened(0.25))
	# Branche cassée.
	Ink.part(ci, xf, PackedVector2Array([Vector2(-16, -82), Vector2(0, -98), Vector2(6, -102), Vector2(4, -94), Vector2(-12, -76)]), pw, 1.8, 1.0, 0.3)
	# Coupe : les cernes (le Cœur des cernes de la région).
	var top := Ink.oval(Vector2(-28, -93), 15.0, 5.0, 24)
	Ink.part(ci, xf, top, {"clair": Art.bc("racine", "chair"), "ombre": Art.bc("racine", "chair_ombre"), "reflet": Art.bc("racine", "reflet")}, 1.8, 0.6, 0.0)
	for i in 3:
		var rr := 3.0 + i * 3.6
		var ring := Ink.oval(Vector2(-29, -93), rr, rr * 0.34, 18)
		ring.append(ring[0])
		if not Ink.mono:
			ci.draw_polyline(xf * ring, Ink.shade(Art.bc("racine", "chair_ombre")), maxf(0.9 * xf.get_scale().abs().x, 0.6), true)
	# Mousse qui pend du bord.
	var moss := Art.ec("racine", "clair").darkened(0.25)
	for j in 4:
		var b0 := Vector2(-40 + j * 7.0, -100 + absf(j - 1.5))
		Ink.brush(ci, xf, PackedVector2Array([b0, b0 + Vector2(sin(t * 1.6 + j) * 1.5, 5.0 + (j % 2) * 3.0)]), 2.0, moss, 1.0, 0.0)


## Bras de racines tordues, de l'épaule sh au poing f.
static func _arm(ci: CanvasItem, xf: Transform2D, sh: Vector2, f: Vector2, pal: Dictionary, t: float) -> void:
	var mid := sh.lerp(f, 0.5) + (f - sh).orthogonal().normalized() * 8.0
	var pts := PackedVector2Array([sh, mid, f])
	Ink.brush(ci, xf, pts, 18.0, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, pts, 14.0, pal["ombre"], 1.0, 1.0)
	Ink.brush(ci, xf, PackedVector2Array([sh + Vector2(-2, -2), mid + Vector2(-2, -2), f + Vector2(-2, -2)]), 7.5, pal["clair"], 1.0, 1.0)
	# Brins enroulés autour du bras.
	for i in 3:
		var u := 0.2 + i * 0.25
		var q := sh.lerp(mid, u * 2.0) if u < 0.5 else mid.lerp(f, (u - 0.5) * 2.0)
		var d := (f - sh).normalized()
		Ink.brush(ci, xf, PackedVector2Array([q - d.orthogonal() * 6.0 - d * 2.0, q + d.orthogonal() * 6.0 + d * 2.0]), 1.4, pal["ombre"].darkened(0.35))


## Poing de pierre : un gros bloc anguleux, phalanges, fente de braise quand il est levé.
static func _fist(ci: CanvasItem, xf: Transform2D, c: Vector2, pal: Dictionary, s: float, up: float) -> void:
	Ink.part(ci, xf, Ink.lumpy(c, 17.0 * s, 13.0 * s, 16, 0.14, 5.0, c.x * 0.1), pal, 2.6, 1.0, 0.6)
	for j in 3:
		var q := c + Vector2(4.0 + j * 0.5, -9.0 + j * 7.0) * s
		Ink.brush(ci, xf, PackedVector2Array([q, q + Vector2(9.0, 1.0) * s]), 1.4, pal["ombre"].darkened(0.3))
	if up > 0.0 and not Ink.mono:
		Ink.brush(ci, xf, PackedVector2Array([c + Vector2(-8, -4) * s, c + Vector2(0, 2) * s, c + Vector2(-4, 8) * s]), 1.6 * up + 0.4, Art.bc("braise"))
