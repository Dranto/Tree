## Prismeur (Aube, tireur), direction « Bestiaire d'herbier » : un faucheux des falaises de verre. Son corps
## est un prisme de verre fumé, dressé, porté haut sur quatre longues pattes de cendre aux genoux plus
## hauts que lui ; au sommet, un cristal taillé vise la cible. La Flétrissure a fêlé le prisme : la
## braise couve dans la fêlure. Annonce (le couloir au sol) : il s'accroupit et s'ancre, la lumière
## monte par les facettes jusqu'au cristal qui s'allume. Rayon (strike) : le cristal flambe, recul.
##
## Pose : t, walk, moving, k (annonce 0 → 1), strike (0 → 1 après le rayon, -1 : aucun), hit, look, elite.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/aube/verre.gd")

## 100 unités en px du jeu (1600×900) : ~50 px de haut à l'écran en 1080p.
const HEIGHT := 42.0
## La sorte dessine elle-même sa parure d'élite (collier de prismes, liseré d'or).
const DRAWS_ELITE := true
const NECK := Vector2(0, -40)


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var k: float = o.get("k", 0.0)
	var strike: float = o.get("strike", -1.0)
	var hit: float = o.get("hit", 0.0)
	var look: float = o.get("look", 0.0)
	var flip := cos(look) < 0.0
	var la := wrapf(PI - look if flip else look, -PI, PI)
	Ink.flash = hit
	var base := Ink.frame(feet, h, flip)
	var kk := Anim.ease_out(k)
	var fl := 0.0 if strike < 0.0 else 1.0 - Anim.ease_out(strike)
	Ink.ground_shadow(ci, base, Vector2(0, 0), 40.0)
	# Il trotte en se balançant sur ses échasses ; s'accroupit pendant l'annonce ; recule au rayon.
	var bob := sin(walk * 2.0) * 2.5 * mv + sin(t * TAU / 2.4) * 1.2
	var crouch := 9.0 * kk - 4.0 * fl
	var sway := sin(walk) * 0.06 * mv + 0.08 * hit - 0.1 * fl
	var sq := Vector2(1.0 + 0.1 * hit + 0.04 * kk, 1.0 - 0.1 * hit - 0.04 * kk)
	var xf := base * Transform2D(sway, sq, 0.0, Vector2(-3.0 * fl, crouch + bob))
	var legc := V.ash()
	var hip := Vector2(0, -36)
	# Pattes du fond (deux), puis le corps, puis les pattes de devant (deux).
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ph := walk + (0.0 if i == 0 else PI)
		var foot := Vector2(side * (30.0 - 6.0 * kk) + sin(ph) * 8.0 * mv, -maxf(cos(ph), 0.0) * 5.0 * mv)
		_leg(ci, base, xf * (hip + Vector2(side * 4.0, 0)), foot, legc.darkened(0.35), side, 22.0 + 6.0 * kk)
	# Le prisme : deux faces, la gauche dans la lumière, la droite dans l'ombre.
	var body := V.pal()
	var top := Vector2(0, -90)
	var outline := PackedVector2Array([Vector2(-14, -34), Vector2(-17, -66), top, Vector2(15, -64), Vector2(13, -34), Vector2(0, -28)])
	Ink.part(ci, xf, outline, body, 2.6, 0.0, 0.0)
	if not Ink.mono:
		Ink.flat(ci, xf, PackedVector2Array([Vector2(-14, -34), Vector2(-17, -66), top, Vector2(2, -66), Vector2(2, -30), Vector2(0, -28)]), body["clair"])
		# Une lumière sale piégée au cœur du prisme, qui monte vers le cristal pendant l'annonce.
		var core := Vector2(-1, -48 - 26.0 * kk)
		Ink.flat(ci, xf, Ink.oval(core, 5.0 + 2.0 * kk, 9.0, 14), Color(Art.bc("aube", "detail"), 0.35 + 0.45 * kk))
		for i in 3:
			if kk > 0.0:
				var u := fposmod(t * 2.2 + i / 3.0, 1.0)
				var q := Vector2(-6 + i * 6, -34).lerp(top + Vector2(0, 6), u)
				Ink.flat(ci, xf, Ink.oval(q, 1.8, 3.8, 10), Color(Art.bc("aube", "lueur"), 0.8 * kk * (1.0 - u * 0.5)))
		# Arêtes claires des facettes, reflet en long.
		Ink.brush(ci, xf, PackedVector2Array([Vector2(2, -30), Vector2(2, -66), top]), 1.3, Color(Art.bc("aube", "reflet"), 0.85), 0.0, 0.0)
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-11, -40), Vector2(-13, -64)]), 2.2, Color(Art.bc("aube", "reflet"), 0.7))
		# La fêlure de la Flétrissure, où couve la braise.
		var crack := PackedVector2Array([Vector2(13, -42), Vector2(7, -48), Vector2(10, -54), Vector2(4, -60)])
		Ink.brush(ci, xf, crack, 3.2, Ink.encre())
		Ink.brush(ci, xf, crack, 1.4, Art.bc("braise").lerp(Art.bc("braise_coeur"), kk))
		Ink.flat(ci, xf, Ink.lumpy(Vector2(8, -32), 6.0, 4.0, 12, 0.3, 4.0), Art.bc("ronge"))
		Ink.sparks(ci, xf, Vector2(8, -50), Vector2(0.3, -1.0), 2, t, 1.2, 0.5 + kk)
	if o.get("elite", false):
		V.collar(ci, xf, Vector2(0, -38), 15.0, 5.0, 6)
		V.liseret(ci, xf, outline)
	# Yeux de braise : une rangée de quatre ocelles sur la face éclairée (yeux d'araignée).
	var glow := 0.3 + 0.7 * maxf(kk, fl)
	if hit > 0.4 or (kk == 0.0 and fl == 0.0 and Ink.blink(t, 1.6) > 0.0):
		Ink.brush(ci, xf, PackedVector2Array([Vector2(-8, -58), Vector2(6, -58)]), 2.2, Ink.encre())
	else:
		for e: Vector3 in [Vector3(-7, -58, 2.4), Vector3(0, -59, 3.0), Vector3(6, -58, 2.2), Vector3(-3, -63, 1.6)]:
			Ink.ember(ci, xf, Ink.oval(Vector2(e.x, e.y), e.z, e.z * 0.85, 10), glow)
	# Pattes de devant.
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ph := walk + (PI * 0.5 if i == 0 else PI * 1.5)
		var foot := Vector2(side * (18.0 - 4.0 * kk) + sin(ph) * 8.0 * mv, -maxf(cos(ph), 0.0) * 5.0 * mv)
		_leg(ci, base, xf * (hip + Vector2(side * 7.0, 3)), foot, legc, side, 18.0 + 6.0 * kk)
	# Cristal du sommet : il vise la cible et se charge.
	var aim := clampf(la, -0.9, 0.8)
	_gem(ci, xf, top + Vector2(0, 4), aim, kk, fl, t)


## Le cristal qui vise : un biseau de verre clair, tourné vers aim, qui blanchit et flambe.
static func _gem(ci: CanvasItem, xf: Transform2D, c: Vector2, aim: float, k: float, fl: float, t: float) -> void:
	var d := Vector2.from_angle(aim)
	var n := d.orthogonal()
	var L := 16.0 + 2.0 * k
	var gem := PackedVector2Array([c - d * 5.0, c + n * 5.5, c + d * L * 0.65 + n * 4.0, c + d * L, c + d * L * 0.65 - n * 4.0, c - n * 5.5])
	var charge := clampf(k + fl, 0.0, 1.0)
	var g := V.glass()
	var pal := {"clair": g["clair"].lerp(Art.bc("aube", "lueur"), charge), "ombre": g["ombre"].lerp(Art.bc("aube", "detail"), charge), "reflet": g["reflet"]}
	if k > 0.0 and fl == 0.0:
		Ink.halo(ci, xf * (c + d * L * 0.6), 16.0 * xf.get_scale().abs().x * (0.5 + k), Art.bc("aube", "detail"), k * 1.6)
	Ink.part(ci, xf, gem, pal, 1.8, 1.0, 0.9)
	if Ink.mono:
		return
	Ink.brush(ci, xf, PackedVector2Array([c + n * 2.0, c + d * L * 0.9]), 1.0, Color(Art.bc("aube", "lueur"), 0.9), 0.0, 0.0)
	if k > 0.0 and fl == 0.0:
		V.sparkle(ci, xf * (c + d * L), 8.0 * xf.get_scale().abs().x * k, Art.bc("aube", "lueur"), k, t * 1.5)
		Ink.ember(ci, xf, Ink.oval(c + d * L * 0.45, 2.2, 1.6, 10, aim), k)
	if fl > 0.0:
		var s := xf.get_scale().abs().x
		# Le départ du rayon : une gerbe blanche au bout du cristal, dans l'axe de la visée.
		Ink.brush(ci, xf, PackedVector2Array([c + d * L, c + d * (L + 40.0 * fl)]), 9.0 * fl, Color(Art.c("danger_eclair"), fl), 0.0, 1.0)
		Ink.halo(ci, xf * (c + d * L), 26.0 * s, Art.c("danger_eclair"), 1.8 * fl)
		V.sparkle(ci, xf * (c + d * L), 24.0 * s * (0.4 + 0.6 * fl), Art.c("danger_eclair"), fl, aim)


## Patte de faucheux : hanche (écran) → genou très haut → pied (local), fine, articulations nouées.
static func _leg(ci: CanvasItem, base: Transform2D, hip_w: Vector2, foot: Vector2, col: Color, side: float, rise: float) -> void:
	var hip := base.affine_inverse() * hip_w
	var knee := Vector2(hip.x + (foot.x - hip.x) * 0.55 + side * 6.0, hip.y - rise)
	var pts := PackedVector2Array([hip, knee, foot])
	Ink.brush(ci, base, pts, 4.4, Ink.encre(), 1.0, 0.4)
	Ink.brush(ci, base, pts, 2.4, col, 1.0, 0.3)
	if not Ink.mono:
		Ink.brush(ci, base, PackedVector2Array([hip.lerp(knee, 0.2), knee]), 0.8, col.lightened(0.45), 0.0, 0.0)
	# Genou : un nœud de verre clair.
	Ink.part(ci, base, Ink.oval(knee, 1.9, 1.7, 10), {"clair": V.glass()["ombre"], "ombre": col}, 0.9, 1.0, 0.0)
	Ink.brush(ci, base, PackedVector2Array([foot, foot + Vector2(side * 3.0, 0.5)]), 1.4, Ink.encre(), 1.0, 0.0)
