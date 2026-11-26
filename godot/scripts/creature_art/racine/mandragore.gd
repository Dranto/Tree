## Mandragore (Racine, fouisseuse), « Bestiaire d'herbier » : une racine de mandragore arrachée à la forêt
## pétrifiée, chair de racine ridée, plaques d'écorce devenue pierre sur le dos, une touffe de feuilles
## mortes sur la tête. La Flétrissure lui a ouvert le dos ; la braise couve dans ses yeux et sa bouche.
## Sous terre (pose « under ») : on ne voit qu'un tertre de terre qui avance, la pointe des feuilles qui
## dépasse. Annonce (« rising » 0 → 1) : la butte gonfle et se fend de braise, puis la tête perce, yeux
## allumés. Frappe : elle jaillit en hurlant (bouche grande ouverte), puis reste sonnée.
##
## Pose : t, walk, moving, k, state, strike, hit (ou flash), look, elite ; under (0/1), rising (0 → 1).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const R = preload("res://scripts/creature_art/racine/outils.gd")

## 100 unités en px du jeu (1600×900) : ~58 px de haut à l'écran en 1080p (feuilles comprises).
const HEIGHT := 50.0
const DRAWS_ELITE := true
## Poses propres du comportement « burrower » (contrat moteur) : enfouie, puis la sortie en 4 images.
const CUSTOM := {"under": 1, "rising": 4}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var p := R.read(o)
	var t: float = p["t"]
	var hit: float = p["hit"]
	var under: float = o.get("under", 0.0)
	var rising: float = o.get("rising", 0.0)
	Ink.flash = hit
	var base := Ink.frame(feet, h, p["flip"])
	if under > 0.0 or rising > 0.0:
		_burrowed(ci, base, p, rising)
		return
	_standing(ci, base, p)


## Debout (en marche, ou sonnée après avoir jailli).
static func _standing(ci: CanvasItem, base: Transform2D, p: Dictionary) -> void:
	var t: float = p["t"]
	var walk: float = p["walk"]
	var mv: float = p["mv"]
	var hit: float = p["hit"]
	var strike: float = p["strike"]
	var recover: bool = p["state"] == "recover"
	# Cri : juste après le jaillissement (strike), puis la bouche reste entrouverte, sonnée.
	var scream := 0.0 if strike < 0.0 else clampf(1.0 - strike, 0.0, 1.0)
	Ink.ground_shadow(ci, base, Vector2(2, 0), 30.0)
	if recover or scream > 0.0:
		_crater(ci, base, t, scream)
	# Dandinement : elle bascule d'une jambe-racine sur l'autre.
	var rock := sin(walk) * 0.09 * mv
	var bob := -absf(sin(walk)) * 3.0 * mv + sin(t * TAU / 2.0) * 0.8
	var jump := -10.0 * scream * scream
	var sq := Vector2(1.0 + 0.1 * hit - 0.08 * scream + (0.05 if recover else 0.0), 1.0 - 0.12 * hit + 0.1 * scream - (0.05 if recover else 0.0))
	var xf := base * Transform2D(rock + 0.08 * hit, sq, 0.0, Vector2(0, bob + jump))
	var chair := R.pal("chair")
	var far := {"clair": chair["ombre"], "ombre": chair["ombre"].darkened(0.3), "reflet": chair["clair"]}
	# Jambe-racine du fond.
	var sw := sin(walk) * 9.0 * mv
	_root_leg(ci, xf, Vector2(6, -30), Vector2(10 + sw, 0), far, -1.0)
	# Bras-radicelle du fond.
	var flail := scream * 0.9 + (0.25 * sin(t * 6.0) if recover else 0.0)
	_arm(ci, xf, Vector2(18, -54), -0.4 - flail, far, t)
	_body(ci, xf, p, scream)
	# Jambe-racine de devant.
	_root_leg(ci, xf, Vector2(-6, -30), Vector2(-10 - sw, 0), chair, 1.0)
	# Bras-radicelle de devant, qui pend ou se lève en criant.
	_arm(ci, xf, Vector2(-16, -52), PI + 0.5 + flail, chair, t + 1.3)
	if recover:
		R.dazed(ci, xf, Vector2(0, -102), t, 16.0)


## Corps, tête, visage, touffe (repère xf : pieds en 0, debout).
static func _body(ci: CanvasItem, xf: Transform2D, p: Dictionary, scream: float, eyes := -1.0) -> void:
	var t: float = p["t"]
	var hit: float = p["hit"]
	var la: float = p["la"]
	var chair := R.pal("chair")
	# Touffe de feuilles mortes (derrière la tête), qui frémit.
	_tuft(ci, xf, Vector2(-2, -82), t, scream)
	# Le tubercule : large aux épaules, ridé, qui se fourche vers le bas.
	var tub := PackedVector2Array([
		Vector2(-12, -26), Vector2(-21, -40), Vector2(-25, -56), Vector2(-21, -72), Vector2(-10, -82),
		Vector2(4, -84), Vector2(17, -77), Vector2(24, -62), Vector2(23, -45), Vector2(15, -31), Vector2(2, -24)])
	Ink.part(ci, xf, tub, chair, 2.6, 1.0, 0.7)
	# Plaques d'écorce pétrifiée sur le dos (la forêt de pierre), et la plaie de la Flétrissure.
	var stone := R.pal("pierre")
	Ink.part(ci, xf, PackedVector2Array([Vector2(-24, -52), Vector2(-21, -70), Vector2(-12, -78), Vector2(-10, -66), Vector2(-15, -54)]), stone, 1.4, 1.0, 0.5)
	Ink.part(ci, xf, PackedVector2Array([Vector2(-20, -44), Vector2(-14, -50), Vector2(-9, -42), Vector2(-14, -34)]), stone, 1.2, 1.0, 0.4)
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-16, -61), 4.0, 6.0, 14, 0.3, 5.0), Art.bc("ronge"))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-17, -66), Vector2(-15, -61), Vector2(-17, -56)]), 1.4, Art.bc("braise"))
	# Rides de la racine et radicelles qui pendent.
	var wr: Color = chair["ombre"].darkened(0.15)
	for y: float in [-70.0, -60.0, -48.0, -38.0]:
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-6, y + 1), Vector2(4, y - 1.5), Vector2(16, y + 1)]), 1.3, wr)
	for q: Vector3 in [Vector3(20, -40, 0.4), Vector3(-19, -38, 2.6), Vector3(10, -28, 1.3)]:
		var b0 := Vector2(q.x, q.y)
		Ink.brush(ci, xf, PackedVector2Array([b0, b0 + Vector2.from_angle(q.z) * 7.0, b0 + Vector2.from_angle(q.z + 0.4) * 11.0]), 1.4, chair["ombre"], 1.0, 0.0)
	# Lichens clairs sur l'écorce : la forêt qui reprend.
	for q: Vector2 in [Vector2(-19, -64), Vector2(-16, -68)]:
		Ink.flat(ci, xf, Ink.oval(q, 2.2, 1.5, 10), Art.bc("racine", "reflet").lerp(Art.ec("racine", "clair"), 0.4))
	_face(ci, xf, la, t, hit, scream, eyes)
	if p["elite"]:
		R.elite(ci, xf, Vector2(-22, -46), Vector2(22, -44), 5.0, PackedVector2Array([Vector2(-20, -73), Vector2(-9, -83), Vector2(6, -85)]), t, 0.9)


## Visage : deux yeux de braise (celui du fond plus petit), la bouche en cri. eyes : force des yeux
## (-1 : selon la pose).
static func _face(ci: CanvasItem, xf: Transform2D, la: float, t: float, hit: float, scream: float, eyes: float) -> void:
	var gx := clampf(la, -0.6, 0.6) * 3.0
	var gy := clampf(la, -0.6, 0.6) * 2.0
	var glow := 0.3 + 0.7 * scream if eyes < 0.0 else eyes
	# Arcades froncées, sombres.
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-2, -68), Vector2(5, -64), Vector2(11, -66)]), 2.0, Art.bc("racine", "chair_ombre").darkened(0.3))
	Ink.brush(ci, xf, PackedVector2Array([Vector2(13, -66), Vector2(17, -63), Vector2(21, -64)]), 1.6, Art.bc("racine", "chair_ombre").darkened(0.3))
	if hit > 0.4 or (scream == 0.0 and eyes < 0.0 and Ink.blink(t, 4.1) > 0.0):
		Ink.brush(ci, xf, PackedVector2Array([Vector2(1 + gx, -61 + gy), Vector2(9 + gx, -60 + gy)]), 2.2, Ink.encre())
		Ink.brush(ci, xf, PackedVector2Array([Vector2(14 + gx, -60 + gy), Vector2(19 + gx, -59 + gy)]), 1.8, Ink.encre())
	else:
		Ink.flat(ci, xf, Ink.oval(Vector2(5 + gx, -60 + gy), 5.0, 4.0, 14), Art.bc("ronge"))
		Ink.flat(ci, xf, Ink.oval(Vector2(17 + gx, -59 + gy), 3.4, 3.2, 12), Art.bc("ronge"))
		Ink.ember(ci, xf, Ink.leaf(Vector2(2 + gx, -60 + gy), -0.15, 6.5, 3.6), glow)
		Ink.ember(ci, xf, Ink.leaf(Vector2(15 + gx, -59 + gy), -0.2, 4.4, 2.8), glow)
	# Bouche : une fente qui s'ouvre en cri, la braise au fond.
	var open := 2.0 + 9.0 * scream
	var mouth := Ink.lumpy(Vector2(9 + gx * 0.6, -45 - open * 0.3), 5.0 + 2.0 * scream, open * 0.5 + 1.2, 16, 0.15, 3.0)
	Ink.flat(ci, xf, mouth, Art.bc("ronge"), 1.2)
	if scream > 0.1 and not Ink.mono:
		Ink.ember(ci, xf, Ink.oval(Vector2(9 + gx * 0.6, -44 - open * 0.2), 3.0 * scream + 0.5, open * 0.25, 10), scream)


## Touffe de feuilles mortes (plus une vrille), de base b ; elle se dresse quand la mandragore crie.
static func _tuft(ci: CanvasItem, xf: Transform2D, b: Vector2, t: float, up: float) -> void:
	var leaf := R.pal("feuille")
	for i in 5:
		var a := -PI / 2.0 + (i - 2) * (0.42 - 0.12 * up) + 0.08 * sin(t * 2.6 + i * 1.3)
		var l := 24.0 - absf(i - 2.0) * 3.0 + 4.0 * up
		Ink.part(ci, xf, Ink.leaf(b, a, l, 8.5, 0.12 if i < 2 else -0.12), leaf, 1.6, 1.0, 0.4)
		Ink.brush(ci, xf, PackedVector2Array([b, b + Vector2.from_angle(a) * l * 0.85]), 0.9, leaf["ombre"])
	# Bords des feuilles roussis par la braise.
	for i: int in [0, 4]:
		var a := -PI / 2.0 + (i - 2) * (0.42 - 0.12 * up) + 0.08 * sin(t * 2.6 + i * 1.3)
		var tip: Vector2 = b + Vector2.from_angle(a) * (20.0 + 4.0 * up)
		Ink.brush(ci, xf, PackedVector2Array([tip - Vector2.from_angle(a) * 5.0, tip]), 1.6, Art.bc("braise").darkened(0.2))


## Jambe-racine : de la hanche hip au pied foot, effilée, avec des radicelles au bout.
static func _root_leg(ci: CanvasItem, xf: Transform2D, hip: Vector2, foot: Vector2, pal: Dictionary, s: float) -> void:
	var knee := hip.lerp(foot, 0.5) + Vector2(-3.0 * s, 0)
	var leg := PackedVector2Array([hip + Vector2(-7, 0), knee + Vector2(-4.5, 0), foot + Vector2(-2, -1), foot + Vector2(3, -1), knee + Vector2(4.5, 0), hip + Vector2(7, 0)])
	Ink.part(ci, xf, leg, pal, 2.0, 1.0, 0.3)
	for j in 3:
		var a := PI * (0.15 + j * 0.35)
		Ink.brush(ci, xf, PackedVector2Array([foot + Vector2(0, -1), foot + Vector2.from_angle(a) * Vector2(7, 2.5)]), 1.6, pal["ombre"].darkened(0.2), 1.0, 0.0)


## Bras-radicelle : de l'épaule sh, angle a ; trois doigts de radicelle.
static func _arm(ci: CanvasItem, xf: Transform2D, sh: Vector2, a: float, pal: Dictionary, t: float) -> void:
	var d := Vector2.from_angle(a + 0.1 * sin(t * 3.0))
	var el := sh + d * 13.0 + Vector2(0, 4)
	var hand := el + Vector2.from_angle(a + 0.4) * 11.0
	var pts := PackedVector2Array([sh, el, hand])
	Ink.brush(ci, xf, pts, 6.4, Ink.encre(), 1.0, 0.4)
	Ink.brush(ci, xf, pts, 4.2, pal["clair"], 1.0, 0.3)
	for j in 3:
		var fa := a + 0.4 + (j - 1) * 0.5
		Ink.brush(ci, xf, PackedVector2Array([hand, hand + Vector2.from_angle(fa) * 6.0, hand + Vector2.from_angle(fa + 0.5) * 9.0]), 1.5, pal["ombre"], 1.0, 0.0)


## Cratère d'où elle vient de jaillir : terre retournée, mottes qui retombent (k : jaillissement 1 → 0).
static func _crater(ci: CanvasItem, base: Transform2D, t: float, k: float) -> void:
	if Ink.mono:
		return
	var soil := _soil()
	Ink.flat(ci, base, Ink.lumpy(Vector2(0, -1), 32.0, 9.0, 24, 0.18, 7.0), soil["ombre"].darkened(0.25))
	Ink.flat(ci, base, Ink.lumpy(Vector2(0, -3), 22.0, 5.0, 20, 0.2, 5.0), Art.bc("ronge"))
	for i in 6:
		var a := PI * (1.1 + i * 0.16)
		var u := 1.0 - k
		var q := Vector2(cos(a) * (26.0 + 12.0 * u), -4.0 + sin(a) * 8.0 - 26.0 * k * sin(PI * clampf(u + 0.2, 0.0, 1.0)))
		Ink.part(ci, base, Ink.lumpy(q, 4.0, 3.0, 10, 0.3, 3.0, i), soil, 1.2, 1.0, 0.0)


static func _soil() -> Dictionary:
	var c := Art.bc("racine", "bois").lerp(Art.bc("racine", "ombre"), 0.5)
	return {"clair": c.lightened(0.18), "ombre": c.darkened(0.15), "reflet": Art.bc("racine", "reflet")}


## Sous terre : la butte qui avance (traînée de terre derrière), la pointe des feuilles qui dépasse.
## rising 0 → 1 (annonce) : la butte gonfle, se fend de braise, puis la tête perce.
static func _burrowed(ci: CanvasItem, base: Transform2D, p: Dictionary, rising: float) -> void:
	var t: float = p["t"]
	var mv: float = maxf(p["mv"], 0.0)
	var soil := _soil()
	var swell := 1.0 + 0.3 * rising
	var shake := sin(t * 60.0) * 1.5 * rising
	var bx := base * Transform2D(0.0, Vector2(shake, 0))
	Ink.ground_shadow(ci, base, Vector2(0, 0), 30.0 * swell)
	# Traînée : mottes qui s'aplatissent derrière.
	for i in 4:
		var q := Vector2(-30.0 - i * 13.0, -2.0)
		Ink.flat(ci, base, Ink.lumpy(q, 12.0 - i * 2.0, 4.0 - i * 0.6, 14, 0.25, 5.0, i), Color(soil["ombre"], 0.8 - 0.17 * i), 0.0)
	# Dos de la butte.
	var mound := Ink.lumpy(Vector2(0, -2), 30.0 * swell, 16.0 * swell, 30, 0.12, 9.0, t * 0.0)
	for i in mound.size():
		mound[i].y = minf(mound[i].y, -1.0)
	Ink.part(ci, bx, mound, soil, 2.4, 1.0, 0.5)
	# La pointe des feuilles qui dépasse et file avec la butte.
	var emerge := clampf((rising - 0.5) / 0.5, 0.0, 1.0)
	var tuft_y := -14.0 * swell - 10.0 * rising - 30.0 * emerge
	if emerge <= 0.0:
		var leaf := R.pal("feuille")
		for i in 3:
			var a := -PI / 2.0 + (i - 1) * 0.5 - 0.35 * mv + 0.1 * sin(t * 5.0 + i)
			Ink.part(ci, bx, Ink.leaf(Vector2(2, tuft_y + 4.0), a, 12.0 + 6.0 * rising - absf(i - 1) * 3.0, 6.0), leaf, 1.4, 1.0, 0.3)
	else:
		# La tête perce : haut du tubercule, yeux allumés, touffe dressée.
		var hx := bx * Transform2D(0.0, Vector2(0, 66.0 - 40.0 * emerge))
		_tuft(ci, hx, Vector2(-2, -82), t, 1.0)
		var cap := PackedVector2Array([Vector2(-23, -54), Vector2(-21, -72), Vector2(-10, -82), Vector2(4, -84), Vector2(17, -77), Vector2(24, -62), Vector2(24, -50)])
		Ink.part(ci, hx, cap, R.pal("chair"), 2.4, 1.0, 0.7)
		Ink.part(ci, hx, PackedVector2Array([Vector2(-23, -54), Vector2(-21, -70), Vector2(-12, -78), Vector2(-10, -66), Vector2(-15, -54)]), R.pal("pierre"), 1.4, 1.0, 0.5)
		_face(ci, hx, p["la"], t, p["hit"], 0.0, 0.5 + 0.5 * emerge)
	# Fentes de braise dans la terre pendant l'annonce.
	if rising > 0.0:
		var crack := PackedVector2Array([Vector2(-22, -6), Vector2(-10, -14 * swell), Vector2(2, -9), Vector2(12, -17 * swell), Vector2(24, -7)])
		Ink.brush(ci, bx, crack, 3.4, Ink.encre())
		if not Ink.mono:
			Ink.brush(ci, bx, crack, 1.4 + 1.6 * rising, Art.bc("braise").lerp(Art.bc("braise_coeur"), rising))
			Ink.halo(ci, bx * Vector2(2, -12), 22.0 * bx.get_scale().abs().x * rising, Art.bc("braise"), rising * 1.4)
	# Lèvre de la butte, devant (cache le bas de la tête qui perce), cailloux qui roulent.
	var lip := Ink.lumpy(Vector2(0, -3), 30.0 * swell, 7.0 * swell, 26, 0.18, 7.0, 0.7)
	for i in lip.size():
		lip[i].y = maxf(lip[i].y, -8.0 * swell) if lip[i].y < -3.0 else lip[i].y
	Ink.part(ci, bx, lip, soil, 2.0, 1.0, 0.2)
	for i in 4:
		var a := t * (4.0 + 3.0 * mv) + i * TAU / 4.0
		var q := Vector2(cos(a) * 20.0 * swell, -6.0 * swell + sin(a) * 4.0)
		Ink.part(ci, bx, Ink.lumpy(q, 2.6, 2.2, 8, 0.3, 3.0, i), R.pal("pierre"), 1.0, 1.0, 0.0)
	if p["elite"] and not Ink.mono:
		Ink.brush(ci, bx, PackedVector2Array([Vector2(-26 * swell, -6), Vector2(-14, -14 * swell), Vector2(6, -16 * swell)]), 1.2, Art.c("or"))
