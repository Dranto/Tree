## Le Saule exsangue (boss de Sève), direction « Bestiaire d'herbier » (refonte des personnages, vague 2,
## B2) : le saule-mère dont les Souches gorgées sont les rejets. Vu de trois quarts : tronc noueux de
## la même écorce que la Souche (vert de mare et limon, Art.bc("seve")), penché vers ce qu'il vise,
## couronne basse de saule pleureur d'où retombent des rideaux de branches feuillues jusqu'à l'étang.
## Ses racines plongent dans la vase, où flottent des nénuphars et des œufs de grenouille ; des
## sangsues sont accrochées à son écorce. Visage taillé dans une fente de l'écorce : yeux de braise,
## bouche creuse. La vie qu'il boit monte en veines de sève verte qui battent (vert = vivant, bu).
##
## Annonces (même timing que le combat, aucune zone au sol ici) : « rideau » soulève les branches du
## côté visé ; « siphon » les agite et fait battre les veines ; « graines » gonfle des gousses dans la
## couronne ; « racines » allume les racines. Phase 2 : les veines battent vite. Phase 3 : la couronne
## se dégarnit, le tronc se fend, la braise couve. Mort : les rideaux tombent, la sève bue s'échappe.
##
## Pose (o) : t, k (0 → 1), attack, stage, phase, die (0 → 1), aim (côté visé : -1 → 1), hit, poison,
## flip, ash (0 → 1), mono. Dessin statique : la même pose donne le même dessin.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const S = preload("res://scripts/creature_art/seve/_seve.gd")
const Souche = preload("res://scripts/creature_art/seve/souche.gd")
const A = preload("res://scripts/creature_art/spore/_amanite_mere.gd")

## 100 unités en px du jeu (1600×900) : la couronne culmine ~165 px au-dessus des pieds.
const HEIGHT := 165.0


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var k: float = o.get("k", 0.0)
	var attack: String = o.get("attack", "")
	var stage: String = o.get("stage", "annonce")
	var phase: int = o.get("phase", 1)
	var die: float = o.get("die", 0.0)
	var hit: float = o.get("hit", 0.0)
	var flip: bool = o.get("flip", false)
	var aim: float = o.get("aim", 0.0)
	var prev_mono := Ink.mono
	if o.has("mono"):
		Ink.mono = bool(o["mono"])
	Ink.flash = hit
	var alive := 1.0 - die
	var sag := Anim.ease_out(die)
	var kk := Anim.ease_out(k)
	# Couches : « body » (cuit par pose, sans le temps : la respiration est une transformation posée par
	# le boss ; les rideaux du siphon s'agitent sur 4 images, clé « wig »), « live » (ce qui bouge sans
	# cesse, dessiné en direct par-dessus), « all » (les deux).
	var layer: String = o.get("layer", "all")
	var body := layer != "live"
	var live := layer != "body"
	var tw := float(o.get("wig", 0)) * (TAU / 4.0) / 12.0
	var base := Ink.frame(feet, h, flip)
	# Le côté visé, dans le repère du dessin (tourné vers +x).
	var side := aim * (-1.0 if flip else 1.0)
	var bark := A.pal(Souche.bark(), o)
	var far := {"clair": bark["ombre"], "ombre": bark["ombre"].darkened(0.3), "reflet": bark["clair"]}
	var sap := S.sap(1.0)
	var xf := base
	var crown_c := Vector2(6.0, -92.0 + 30.0 * sag)
	var top := Vector2(10.0, -82.0 + 30.0 * sag)
	var face := Vector2(7, -46 + 18.0 * sag)
	if body:
		_body(ci, xf, o, bark, far, sap, kk, side, sag, tw, crown_c, top, face)
	if not live:
		Ink.flash = 0.0
		Ink.mono = prev_mono
		return
	# L'étang frémit : des ronds dans l'eau.
	if not Ink.mono:
		for i in 2:
			var u := fposmod(t * 0.3 + i * 0.5, 1.0)
			var rr := 10.0 + 50.0 * u
			var ring := Ink.oval(Vector2(-6, 0), rr, rr * Art.OMBRE_APLATI, 26)
			ring.append(ring[0])
			ci.draw_polyline(xf * ring, Color(Art.bc("seve", "reflet"), 0.25 * (1.0 - u) * alive), 1.0, true)
	# Veines de la vie bue : la sève verte monte le long du tronc et bat (plus vite en phase 2, et
	# pendant le siphon) ; des perles de sève y montent.
	var rate := 7.0 if (phase >= 2 or attack == "siphon") else 3.0
	var beat := 0.5 + 0.5 * sin(t * rate)
	var drink := clampf(0.4 + 0.4 * beat + 0.6 * kk * float(attack == "siphon") + float(attack == "siphon" and stage == "frappe") * 0.5, 0.0, 1.4) * alive
	if not Ink.mono and drink > 0.0:
		for v: Array in [[-10.0, 1.0], [4.0, -1.0], [16.0, 0.6]]:
			var x0: float = v[0]
			var wob: float = v[1]
			var vein := PackedVector2Array([Vector2(x0 * 1.4, -4), Vector2(x0 + 3.0 * wob, -22), Vector2(x0 - 2.0 * wob, -40), Vector2(x0 * 0.6 + 6.0, top.y + 8.0)])
			var sc := xf.get_scale().abs().x
			ci.draw_polyline(xf * vein, Color(Ink.encre(), 0.5), 2.4 * sc, true)
			ci.draw_polyline(xf * vein, Color(sap, 0.65 * minf(drink, 1.0)), 1.3 * sc, true)
			var u := fposmod(t * 0.6 + x0 * 0.05, 1.0)
			var q := vein[0].lerp(vein[3], u)
			ci.draw_circle(xf * q, 1.6 * xf.get_scale().abs().x, Color(Art.ec("seve", "clair"), minf(drink, 1.0) * sin(PI * u)))
		S.sap_glow(ci, xf, Vector2(4, -40), 26.0, 0.25 * drink)
	if phase >= 3 and alive > 0.0:
		Ink.sparks(ci, xf, Vector2(4, -38), Vector2(0, -1), 4, t, 1.5, alive)
	# Yeux de braise, qui clignent et s'allument pendant l'annonce.
	var glow := (0.15 + 0.45 * kk) * alive
	var shut := Ink.blink(t, 0.3) * alive
	if alive > 0.0:
		for e: Vector2 in [face + Vector2(-5, 0), face + Vector2(6, -1)]:
			var w := 3.6 if e.x > face.x else 3.0
			Ink.ember(ci, xf, PackedVector2Array([e + Vector2(-w, 0.6), e + Vector2(0, -1.4 * (1.0 - shut)), e + Vector2(w, -0.6), e + Vector2(0, 1.0)]), glow)
	# Mort : la sève bue s'échappe en gouttes vertes qui montent et pâlissent.
	if die > 0.0 and not Ink.mono:
		var s := xf.get_scale().abs().x
		for i in 10:
			var a := TAU * i / 10.0 + 0.3
			var u := clampf(die * 1.3 - (i % 3) * 0.12, 0.0, 1.0)
			if u <= 0.0 or u >= 1.0:
				continue
			var q := top + Vector2.from_angle(a) * (16.0 + 40.0 * u) - Vector2(0, 30.0 * u)
			ci.draw_circle(xf * q, (2.5 + 4.0 * u) * s, Color(Art.ec("seve", "clair"), 0.7 * (1.0 - u)))
	Ink.flash = 0.0
	Ink.mono = prev_mono


## Corps (couche « body », cuite par pose) : étang, nénuphars, racines, rideaux, tronc, visage,
## couronne, gousses. Sans le temps (tw : agitation du siphon, sur 4 images).
static func _body(ci: CanvasItem, xf: Transform2D, o: Dictionary, bark: Dictionary, far: Dictionary, sap: Color, kk: float, side: float, sag: float, tw: float, crown_c: Vector2, top: Vector2, face: Vector2) -> void:
	var attack: String = o.get("attack", "")
	var stage: String = o.get("stage", "annonce")
	var phase: int = o.get("phase", 1)
	var leaf := A.pal(_drained(S.pal(0.35)), o)
	var leaf_far := A.pal(_drained(S.pal(1.0)), o)
	var mud := A.pal(S.mud(), o)
	Ink.ground_shadow(ci, xf, Vector2(4, 0), 70.0)
	# L'étang : une mare sombre, des reflets, des nénuphars et des œufs de grenouille.
	if not Ink.mono:
		var pond := Ink.lumpy(Vector2(2, -1), 72.0, 72.0 * Art.OMBRE_APLATI, 30, 0.1, 7.0, 0.6)
		Ink.flat(ci, xf, pond, Color(mud["ombre"].lerp(Art.bc("seve", "ombre"), 0.25), 0.85 * (1.0 - 0.5 * sag)))
		Ink.flat(ci, xf, Ink.lumpy(Vector2(-14, -4), 40.0, 40.0 * Art.OMBRE_APLATI * 0.6, 22, 0.1, 5.0, 2.0), Color(Art.bc("seve", "reflet"), 0.12))
		_pads(ci, xf, 0.0, false)
	# Racines du fond, qui plongent dans l'étang.
	var root_glow := kk * float(attack == "racines")
	for r: Array in [[-0.2, 0.75], [0.25, 0.9], [-0.55, 0.6], [0.6, 0.7]]:
		_root(ci, xf, Vector2(r[0] * 30.0, -10.0), r[0], 48.0 * r[1], far, 5.0, root_glow, sap)
	# Rideaux du fond (derrière le tronc).
	var thin := 0.82 if phase >= 3 else 1.0
	_curtains(ci, xf, crown_c, o, tw, kk, side, thin, sag, leaf_far, false)
	# Tronc : noueux, évasé au pied, penché vers le regard ; il s'affaisse à la mort.
	var trunk := PackedVector2Array([
		Vector2(-30, -4), Vector2(-22, -14), Vector2(-17, -30), Vector2(-20, -48), Vector2(-14, -66), top + Vector2(-14, 0),
		top + Vector2(-2, -8), top + Vector2(12, -2), Vector2(19, -62), Vector2(15, -40), Vector2(18, -24), Vector2(26, -12), Vector2(34, -3), Vector2(0, 0)])
	Ink.part(ci, xf, trunk, bark, 3.4, 1.0, 0.5)
	Ink.flat(ci, xf, PackedVector2Array([Vector2(8, -56), top + Vector2(12, -2), Vector2(19, -54), Vector2(15, -40), Vector2(18, -24), Vector2(26, -12), Vector2(34, -3), Vector2(14, -2), Vector2(8, -30)]), Color(bark["ombre"], 0.75))
	# Écorce : sillons ondulés, nœuds.
	for i in 6:
		var x := -16.0 + i * 6.0
		var sw := 2.0 * sin(i * 1.7)
		Ink.brush(ci, xf, PackedVector2Array([Vector2(x + 6, -64 + 26.0 * sag), Vector2(x + sw, -46), Vector2(x - sw * 0.5, -26), Vector2(x * 1.3 + sw, -4)]), 1.5, bark["ombre"].darkened(0.35))
	for q: Vector3 in [Vector3(-13, -36, 3.4), Vector3(12, -22, 2.8)]:
		Ink.flat(ci, xf, Ink.oval(Vector2(q.x, q.y), q.z, q.z * 0.7, 12), bark["ombre"].darkened(0.4), 0.8)
		Ink.brush(ci, xf, PackedVector2Array([Vector2(q.x - q.z, q.y - q.z * 0.6), Vector2(q.x + q.z * 0.4, q.y - q.z)]), 0.9, bark["reflet"])
	# Sangsues accrochées à l'écorce (elles se tortillent avec l'agitation du siphon).
	_leech(ci, xf, Vector2(-13, -26), -0.4, 0.6 + tw * 4.0, o, 1.0)
	_leech(ci, xf, Vector2(15, -34), 0.5, 1.9 + tw * 4.0, o, 0.8)
	# Fente de braise (phase 3).
	if phase >= 3 and sag < 1.0:
		var crack := PackedVector2Array([Vector2(-2, -18), Vector2(5, -30), Vector2(0, -42), Vector2(6, -52)])
		Ink.brush(ci, xf, crack, 4.6, Ink.encre(), 0.0, 0.0)
		Ink.brush(ci, xf, crack, 2.6, Art.bc("braise"), 0.0, 0.0)
		Ink.brush(ci, xf, crack, 1.0, Art.bc("braise_coeur"), 0.0, 0.0)
	# Visage taillé dans l'écorce, tourné vers le regard : creux sombre, orbites, bouche.
	Ink.flat(ci, xf, Ink.lumpy(face + Vector2(0, 4), 13.0, 10.0, 16, 0.12, 4.0, 1.0), tint_dark(bark, o), 0.0)
	for e: Vector2 in [face + Vector2(-5, 0), face + Vector2(6, -1)]:
		var w := 3.6 if e.x > face.x else 3.0
		Ink.flat(ci, xf, Ink.oval(e, w + 1.2, 2.6, 12), A.tint(Art.bc("ronge"), o), 0.8)
	var gape := 2.2 + 3.5 * kk * float(attack in ["graines", "siphon"]) + 3.0 * sag
	Ink.flat(ci, xf, Ink.lumpy(face + Vector2(1, 9), 5.5, gape, 12, 0.2, 3.0, 2.0), A.tint(Art.bc("ronge"), o), 1.0)
	# Couronne : masses basses de feuillage, dégarnies en phase 3, gousses pendant les graines.
	var lobes := [[0.0, -0.5, 26.0], [-0.62, -0.18, 20.0], [0.66, -0.2, 21.0], [-1.1, 0.12, 15.0], [1.12, 0.14, 16.0], [-0.35, 0.12, 19.0], [0.38, 0.1, 19.0]]
	for i in lobes.size():
		var l: Array = lobes[i]
		var q := crown_c + Vector2(l[0] * 40.0, l[1] * 30.0) * thin
		var rr: float = l[2] * 0.9 * thin * (1.0 - 0.25 * sag)
		Ink.part(ci, xf, Ink.lumpy(q, rr, rr * 0.62, 40, 0.09, 13.0, i * 1.3), leaf, 2.2, 1.0, 0.35)
	if not Ink.mono:
		# Petites feuilles en éventail sur le dessus de la couronne (le côté éclairé).
		for i in 14:
			var a := PI * (1.08 + 0.84 * i / 13.0)
			var b := crown_c + Vector2(cos(a) * 42.0, sin(a) * 24.0 + 4.0) * thin
			Ink.flat(ci, xf, Ink.leaf(b, a + 1.9 + 0.1 * sin(i), 9.0, 3.0, 0.1), leaf["clair"].lerp(leaf["reflet"], 0.25 * fposmod(i * 0.61, 1.0)))
		if phase >= 3:
			# Branches nues qui percent la couronne dégarnie.
			for b: Array in [[-0.4, -1.0, 0.8], [0.5, -1.2, 1.0], [0.9, -0.5, 0.7]]:
				var p0 := crown_c + Vector2(b[0] * 20.0, -6.0)
				var p1 := p0 + Vector2(b[0] * 18.0, b[1] * 22.0)
				Ink.brush(ci, xf, PackedVector2Array([p0, p0.lerp(p1, 0.5) + Vector2(3, 0), p1]), 3.2 * b[2], Ink.encre(), 1.0, 0.0)
				Ink.brush(ci, xf, PackedVector2Array([p0, p0.lerp(p1, 0.5) + Vector2(3, 0), p1]), 1.8 * b[2], far["clair"], 1.0, 0.0)
	if attack == "graines" and stage == "annonce":
		var pod := {"clair": A.tint(Art.bc("seve", "detail"), o).lerp(Art.bc("braise"), kk * 0.6), "ombre": A.tint(Art.bc("seve", "vase"), o).darkened(0.2)}
		for i in 5:
			var q := crown_c + Vector2((i - 2) * 17.0, 8.0 + 4.0 * (i % 2))
			Ink.part(ci, xf, Ink.oval(q, 3.0 + 3.0 * kk, 4.0 + 3.5 * kk, 12), pod, 1.2, 1.0, 0.6)
	# Racines du premier plan et rideaux de devant.
	for r: Array in [[-0.85, 0.85], [0.95, 0.8], [0.05, 0.55]]:
		_root(ci, xf, Vector2(r[0] * 26.0, -6.0), r[0], 52.0 * r[1], far, 5.5, root_glow, sap)
	_curtains(ci, xf, crown_c, o, tw, kk, side, thin, sag, leaf, true)
	if not Ink.mono:
		_pads(ci, xf, 0.0, true)


## Feuillage exsangue : le vert de la région, terni vers le limon (la vie lui a été bue).
static func _drained(p: Dictionary) -> Dictionary:
	var v := Art.bc("seve", "vase")
	return {"clair": p["clair"].lerp(v, 0.45), "ombre": p["ombre"].lerp(v, 0.5).darkened(0.1), "reflet": p["reflet"].lerp(v, 0.3)}


static func tint_dark(bark: Dictionary, _o: Dictionary) -> Color:
	return bark["ombre"].darkened(0.45)


## Une racine noueuse qui part du tronc (b, local) et plonge dans l'étang ; side : -1 (gauche) → 1.
static func _root(ci: CanvasItem, xf: Transform2D, b: Vector2, side: float, l: float, p: Dictionary, w: float, glow: float, sap: Color) -> void:
	var tip := b + Vector2(side * l, 4.0 + (1.0 - absf(side)) * 10.0)
	var knee := b.lerp(tip, 0.45) + Vector2(0, -7.0 - 4.0 * absf(side))
	var pts := PackedVector2Array([b, knee, tip])
	Ink.brush(ci, xf, pts, w + 3.2, Ink.encre(), 1.0, 0.0)
	Ink.brush(ci, xf, pts, w, p["clair"].lerp(p["ombre"], 0.4), 1.0, 0.0)
	Ink.brush(ci, xf, PackedVector2Array([b + Vector2(-1, -1.5), knee + Vector2(-1, -2.0), tip]), w * 0.35, p["reflet"].lerp(p["clair"], 0.5), 1.0, 0.0)
	if glow > 0.0 and not Ink.mono:
		Ink.brush(ci, xf, pts, w * 0.4, Color(sap, glow), 1.0, 0.0)
	# Petit remous là où la racine entre dans l'eau.
	if not Ink.mono:
		var ring := Ink.oval(tip, 5.0, 5.0 * Art.OMBRE_APLATI, 14)
		ring.append(ring[0])
		ci.draw_polyline(xf * ring, Color(Art.bc("seve", "reflet"), 0.3), 1.0, true)


## Rideaux de branches qui retombent de la couronne (front : ceux de devant le tronc). Ils se
## soulèvent du côté visé (rideau), s'agitent pendant le siphon, tombent à la mort.
static func _curtains(ci: CanvasItem, xf: Transform2D, crown_c: Vector2, o: Dictionary, t: float, kk: float, side: float, thin: float, sag: float, p: Dictionary, front: bool) -> void:
	var attack: String = o.get("attack", "")
	var phase: int = o.get("phase", 1)
	var n := 18 if phase < 3 else 12
	var leaf_c: Color = p["clair"]
	var strand_c: Color = p["ombre"]
	for i in n:
		var u0 := (i + 0.5) / n
		var x0 := (u0 * 2.0 - 1.0) * 52.0 * thin
		# Devant : un rideau sur deux, du milieu ; derrière : les autres.
		var is_front := i % 2 == 0 and absf(u0 * 2.0 - 1.0) > 0.4 and absf(u0 * 2.0 - 1.0) < 0.9
		if is_front != front:
			continue
		var base := crown_c + Vector2(x0, 8.0 + 6.0 * (1.0 - absf(u0 * 2.0 - 1.0)))
		var sx := signf(x0) if absf(x0) > 4.0 else 0.0
		var lift := 0.0
		if attack == "rideau":
			lift = kk * clampf(0.3 + 0.7 * sx * signf(side if side != 0.0 else 1.0), 0.0, 1.0) * 0.8
		var shake := (3.5 if attack == "siphon" else 1.4) * sin(t * (12.0 if attack == "siphon" else 1.5) + i * 1.3)
		var len := (66.0 + 8.0 * sin(i * 2.1)) * (1.0 - 0.6 * lift) * (1.0 - 0.45 * sag)
		var tip := base + Vector2(sx * 9.0 * (1.0 + 2.2 * lift) + shake, len)
		var mid := base.lerp(tip, 0.5) + Vector2(sx * 3.0 + shake * 0.4, 0)
		var pts := PackedVector2Array([base, mid, tip])
		Ink.brush(ci, xf, pts, 3.4, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, xf, pts, 1.8, strand_c.darkened(0.1 * (i % 3)), 1.0, 0.0)
		if Ink.mono:
			continue
		# Feuilles de saule, fines et pendantes, le long de la branche.
		for j in 4:
			var u := 0.25 + 0.2 * j
			var q := base.lerp(mid, u * 2.0) if u < 0.5 else mid.lerp(tip, u * 2.0 - 1.0)
			var a := PI / 2.0 + (0.5 if j % 2 else -0.5) + 0.15 * sin(t * 1.3 + i + j)
			Ink.flat(ci, xf, Ink.leaf(q, a, 8.0, 2.4, 0.05), leaf_c.lerp(strand_c, 0.25 * (j % 2)), 0.7)


## Une sangsue accrochée à l'écorce en p (local), penchée de a ; elle se tortille.
static func _leech(ci: CanvasItem, xf: Transform2D, p: Vector2, a: float, t: float, o: Dictionary, s: float) -> void:
	var wig := sin(t * 2.6) * 0.18
	var body := PackedVector2Array()
	for i in 6:
		var u := i / 5.0
		body.append(p + Vector2(sin(u * PI * 1.4 + wig * 4.0) * 2.0 * s, u * 12.0 * s).rotated(a + wig))
	var m := A.pal(S.mud(), o)
	Ink.brush(ci, xf, body, 6.4 * s, Ink.encre(), 1.0, 0.5)
	Ink.brush(ci, xf, body, 4.6 * s, m["ombre"].lerp(Art.bc("seve", "ombre"), 0.4), 1.0, 0.5)
	Ink.brush(ci, xf, body, 1.4 * s, Color(S.sap(), 0.8), 0.0, 0.0)
	if not Ink.mono:
		ci.draw_circle(xf * body[body.size() - 1], 1.0 * s * xf.get_scale().abs().x, Art.bc("braise"))


## Nénuphars et œufs de grenouille sur l'étang (front : ceux de devant).
static func _pads(ci: CanvasItem, xf: Transform2D, t: float, front: bool) -> void:
	var pad := {"clair": Art.ec("racine", "clair").darkened(0.2).lerp(Art.bc("seve", "clair"), 0.3), "ombre": Art.ec("racine", "clair").darkened(0.55), "reflet": Art.ec("seve", "clair")}
	for q: Vector3 in [Vector3(-56, -6, 7.0), Vector3(48, -9, 6.0), Vector3(-36, 10, 6.5), Vector3(58, 6, 5.0)]:
		if (q.y > 0.0) != front:
			continue
		var bob := 0.5 * sin(t * 1.1 + q.x)
		var lp := Ink.oval(Vector2(q.x, q.y + bob), q.z, q.z * 0.5, 16, 0.1 * sin(q.x))
		Ink.part(ci, xf, lp, pad, 1.0, 1.0, 0.4)
		Ink.brush(ci, xf, PackedVector2Array([Vector2(q.x, q.y + bob), Vector2(q.x + q.z * 0.8, q.y + bob - q.z * 0.2)]), 0.9, pad["ombre"].darkened(0.3))
	# Œufs de grenouille : une grappe de perles gélatineuses au point noir.
	for c: Vector2 in ([Vector2(30, 12)] if front else [Vector2(-22, -12)]):
		for i in 7:
			var e := c + Vector2(cos(i * 2.4) * 3.0 * (i % 3), sin(i * 2.4) * 1.6 * (i % 3))
			ci.draw_circle(xf * e, 2.0 * xf.get_scale().abs().x, Color(Art.bc("seve", "reflet"), 0.55))
			ci.draw_circle(xf * e, 0.7 * xf.get_scale().abs().x, Color(Art.bc("seve", "vase").darkened(0.5), 0.9))


## Endormi : un saule bas aux rideaux immobiles, au milieu de l'étang ; open : il frémit, les veines
## battent doucement (l'arène est ouverte).
static func draw_sleeper(ci: CanvasItem, feet: Vector2, h: float, t: float, open: bool) -> void:
	var pulse := (0.5 + 0.5 * sin(t * 2.0)) if open else 0.0
	draw(ci, feet, h * 0.72, {"t": 0.0, "phase": 1, "die": 0.0, "k": 0.0, "attack": "sommeil"})
	if open:
		var xf := Ink.frame(feet, h * 0.72, false)
		S.sap_glow(ci, xf, Vector2(4, -40), 24.0, 0.5 * pulse)


## Guéri (après la victoire) : une source claire et un jeune saule vert, sans braise ni sangsue.
static func draw_healed(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, c)
	var water := Color(Art.ec("seve", "sombre").lerp(Art.ec("vent", "sombre"), 0.35), 0.8)
	Ink.flat(ci, xf, Ink.lumpy(Vector2.ZERO, 70.0, 70.0 * Art.OMBRE_APLATI, 26, 0.1, 6.0, 0.4), water)
	for i in 2:
		var u := fposmod(t * 0.3 + i * 0.5, 1.0)
		var rr := 10.0 + 50.0 * u
		var ring := Ink.oval(Vector2.ZERO, rr, rr * Art.OMBRE_APLATI, 26)
		ring.append(ring[0])
		ci.draw_polyline(xf * ring, Color(Art.ec("seve", "clair"), 0.3 * (1.0 - u)), 1.5, true)
	_pads(ci, xf, t, false)
	var bark := {"clair": Art.ec("racine", "clair").lerp(Art.c("decor_vivant"), 0.25), "ombre": Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.2)}
	Ink.part(ci, xf, PackedVector2Array([Vector2(-6, 0), Vector2(-3, -26), Vector2(-4, -46), Vector2(3, -48), Vector2(4, -26), Vector2(7, 0)]), bark, 2.0, 1.0, 0.3)
	var leaf := {"clair": Art.c("decor_vivant").lerp(Art.ec("seve"), 0.35).lightened(0.1), "ombre": Art.c("decor_vivant").darkened(0.15), "reflet": Art.ec("seve", "clair")}
	Ink.part(ci, xf, Ink.lumpy(Vector2(0, -50), 26.0, 13.0, 20, 0.15, 6.0, 0.5), leaf, 1.8, 1.0, 0.6)
	for i in 10:
		var ang := PI + PI * (i + 0.5) / 10.0
		var b := Vector2(0, -48) + Vector2(cos(ang) * 24.0, sin(ang) * 8.0 + 8.0)
		var tip := b + Vector2(cos(ang) * 5.0 + 1.5 * sin(t * 1.2 + i), 30.0 - 4.0 * (i % 2))
		Ink.brush(ci, xf, PackedVector2Array([b, b.lerp(tip, 0.5), tip]), 2.4, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, xf, PackedVector2Array([b, b.lerp(tip, 0.5), tip]), 1.4, leaf["ombre"], 1.0, 0.0)
		for j in 3:
			Ink.flat(ci, xf, Ink.leaf(b.lerp(tip, 0.3 + 0.25 * j), PI / 2.0 + (0.5 if j % 2 else -0.5), 6.0, 2.0, 0.05), leaf["clair"])
	Ink.halo(ci, xf * Vector2(0, -22), 34.0 * s, Art.ec("seve", "clair"), 0.8)
