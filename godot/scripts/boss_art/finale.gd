## La Flétrissure (boss final), « Bestiaire d'herbier » (refonte des personnages, B4) : la Flétrissure
## pure, de la même cendre, de la même braise et du même bois brûlé que les Flétris communs (R0), en
## colosse. Vue de 3/4, tournée vers le héros (retournement gauche/droite, la lumière reste en haut à
## gauche).
##
## Une souche immense, voûtée sous un capuchon d'écorce morte, qui sort du sol sur un pied de racines.
## Son visage est son cœur : dans la poitrine ouverte, une graine noire côtelée, nouée de deux racines,
## fendue de braise, où s'ouvre un œil. Sur ses épaules, le manteau de plaques d'écorce ; au sommet,
## la couronne de bois mort. Six bras-racines en éventail, trois de chaque côté : chacun porte ce
## qu'elle a pris à un gardien (couronne d'épines, champignons, bulbe de sève, plumes, cristaux,
## griffe de racines). Gris de cendre tant qu'il dort, il prend la couleur de son élément quand sa
## phase arrive, et s'allume pendant l'annonce de son attaque.
##
## Seconde forme (form 0 → 1) : le manteau et la couronne tombent, les liens de racine cassent, la
## graine s'ouvre en deux sur un noyau de braise, la braise gagne tout le corps, six éclats des
## gardiens tournent autour d'elle. Mort (die 0 → 1) : les bras retombent en cendre, elle s'affaisse,
## la sève jaillit des fentes. Endormie (wake 0) : repliée, bras ramenés contre elle, l'œil clos.
##
## Repère local : pieds (centre de la base) en 0, y vers le haut négatif, 100 unités = le rayon du
## boss ; le cœur est en (0, -45) (BossFinale : effets de la charge, de la mort, de l'éclat).
## Dessin seul : aucune collision, aucun chiffre de jeu.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const U = preload("res://scripts/creature_art/commun/_outils.gd")

const HEART := Vector2(0, -45)
## Le dessin est plus grand que le rayon du boss (sa collision) : elle domine l'arène.
const ART := 1.2
## Le coude : le point du chemin d'un bras où il plie (sur 9).
const ELBOW := 4
## Place de chaque bras (dans l'ordre de BossFinale.ARMS) : côté (-1 : près, devant le corps ; 1 : loin,
## derrière), hauteur dans l'éventail (0 haut, 1 milieu, 2 bas).
const SLOTS := [[-1, 1], [1, 1], [-1, 2], [1, 0], [-1, 0], [1, 2]]
## Épaule de chaque côté, et bout du bras dressé selon sa hauteur.
const SHOULDER := {-1: Vector2(-62, -112), 1: Vector2(52, -126)}
const TIPS := {
	-1: [Vector2(-150, -238), Vector2(-218, -112), Vector2(-178, 8)],
	1: [Vector2(156, -246), Vector2(220, -124), Vector2(188, 2)],
}

## Le corps : une souche voûtée, capuchon penché vers l'avant (+x).
const BODY := [
	Vector2(-116, 22), Vector2(-124, -8), Vector2(-116, -52), Vector2(-110, -96), Vector2(-88, -134),
	Vector2(-52, -164), Vector2(-10, -182), Vector2(28, -178), Vector2(58, -160), Vector2(78, -136),
	Vector2(70, -120), Vector2(86, -98), Vector2(100, -62), Vector2(98, -26), Vector2(106, 4),
	Vector2(116, 22), Vector2(62, 34), Vector2(0, 38), Vector2(-62, 34),
]
## La poitrine ouverte, où bat le cœur.
const CAVITY_C := Vector2(2, -46)
## Le bas calciné (charbon craquelé, comme les communs).
const LOW := [
	Vector2(-116, 22), Vector2(-124, -8), Vector2(-120, -30), Vector2(-96, -22), Vector2(-74, -30),
	Vector2(-52, -18), Vector2(-30, -10), Vector2(36, -8), Vector2(62, -20), Vector2(84, -12), Vector2(100, -20),
	Vector2(106, 4), Vector2(116, 22), Vector2(62, 34), Vector2(0, 38), Vector2(-62, 34),
]
## Les fentes de braise du cœur (en part de ses rayons) : deux, puis une de plus par phase.
const HEART_CRACKS := [
	[Vector2(-0.12, -0.92), Vector2(0.04, -0.7), Vector2(-0.06, -0.5)],
	[Vector2(0.48, -0.5), Vector2(0.28, -0.28), Vector2(0.42, -0.02), Vector2(0.26, 0.2)],
	[Vector2(-0.5, -0.32), Vector2(-0.26, -0.1), Vector2(-0.42, 0.2)],
	[Vector2(0.06, 0.42), Vector2(-0.1, 0.62), Vector2(0.06, 0.86)],
	[Vector2(-0.62, 0.18), Vector2(-0.42, 0.45), Vector2(-0.52, 0.7)],
	[Vector2(0.64, 0.3), Vector2(0.46, 0.55), Vector2(0.56, 0.76)],
]

static var _cracks_cache := {}


## La Flétrissure entière autour de c (pieds), rayon r, dessinée tout de suite (planches, galeries,
## sans rendu). Mêmes paramètres que BossFinale.draw_colossus, plus facing (1 : tournée vers la
## droite, -1 : vers la gauche ; entre les deux pendant qu'elle se retourne) et arms (BossFinale.ARMS).
static func draw(ci: CanvasItem, c: Vector2, r: float, t: float, phase: int, k: float, lit: int, die: float, wake: float, tint: Callable, lit2: int, form: float, facing: float, arms: Array, anim := {}) -> void:
	compose(ci, c, r, t, phase, k, lit, die, wake, lit2, form, facing, arms, func(cc: CanvasItem, xf: Transform2D, part):
		if str(part) == "corps":
			draw_body(cc, xf, phase, die, wake, form, tint)
		else:
			var pc := piece_of(part)
			draw_arm(cc, xf, pc[0], arms, phase, arm_on(pc[0], k, lit, lit2, form), die, wake, form, tint, pc[1]), "", anim)


## Une partie de bras (id de compose) -> [indice du bras, pièce].
static func piece_of(part) -> Array:
	var sp := str(part)
	if sp.begins_with("f"):
		return [int(sp.substr(1)), "bas"]
	if sp.begins_with("m"):
		return [int(sp.substr(1)), "motif"]
	return [int(part), "haut"]


## Repère de dessin : pieds en c, échelle du rayon (× ART), retournement (facing), puis la vie du corps
## (elle respire : le haut monte et s'élargit à peine ; endormie, elle se tasse ; morte, elle
## s'affaisse ; pendant une annonce, elle se cabre un peu). lean / grow : le geste (FinaleChoreo
## .body_pose) : penchée vers le héros (+) ou rejetée en arrière (-), grandie (+) ou tassée (-).
static func body_xf(c: Vector2, r: float, t: float, phase: int, k: float, die: float, wake: float, form: float, facing: float, lean_g := 0.0, grow := 0.0) -> Transform2D:
	var s := r / 100.0 * ART
	var fx := facing
	if absf(fx) < 0.18:
		fx = 0.18 * (1.0 if fx >= 0.0 else -1.0)
	var beat := Anim.breathe(t * (1.7 if phase >= 3 else 1.0) * (1.0 + 0.6 * form), (0.03 + 0.02 * form) * wake)
	var slump := 1.0 - 0.14 * (1.0 - wake) - 0.22 * Anim.ease_in(die)
	var lean := -0.05 * k * wake + 0.06 * (1.0 - wake) + 0.05 * die
	if lean_g != 0.0 or grow != 0.0:
		lean = 0.06 * (1.0 - wake) + 0.05 * die + lean_g * wake
	var sy := slump * (2.0 - beat) * (1.0 + grow)
	return Transform2D(0.0, Vector2(s * fx, s), 0.0, c) * Transform2D(lean, Vector2(beat * (1.0 - 0.5 * grow), sy), 0.0, Vector2.ZERO)


## Allumage d'un bras (0 → 1) : l'annonce de son attaque ; en seconde forme, tous brillent un peu.
static func arm_on(i: int, k: float, lit: int, lit2: int, form: float) -> float:
	return k if (i == lit or i == lit2) else 0.25 * form


## Le bras i, articulé en deux (épaule, coude), dans le repère local du corps. Sans pose (planches,
## ancien appel) : il se balance et se lève en s'allongeant quand il s'allume. Avec une pose
## (FinaleChoreo.arm_pose) : rotation de l'épaule vers le haut, vers le héros (aim_l, repère local),
## allongement. Le balancement reste, plus discret.
static func arm_xf(i: int, t: float, on: float, wake: float, form: float, pose := {}, aim_l := Vector2.ZERO) -> Transform2D:
	var side: int = SLOTS[i][0]
	var sh: Vector2 = SHOULDER[side]
	var tt := t * (1.0 + form) + i * 1.3
	var sway := (0.04 * sin(tt * 1.3) + 0.02 * cos(tt * 0.7)) * wake * (1.0 + form)
	var ang := sway - side * 0.12 * on
	var sc := 1.0 + 0.1 * on + 0.02 * sin(tt * 1.1) * wake
	if not pose.is_empty():
		ang = sway * 0.6 - side * float(pose["up"])
		if float(pose["aim"]) != 0.0 and aim_l != Vector2.ZERO:
			var rest: Vector2 = TIPS[side][SLOTS[i][1]] - sh
			ang += clampf(angle_difference(rest.angle(), aim_l.angle()), -2.0, 2.0) * float(pose["aim"])
		sc = float(pose["st"]) + 0.02 * sin(tt * 1.1) * wake
	return Transform2D(ang, Vector2(sc, sc), 0.0, sh) * Transform2D(0.0, -sh)


## L'avant-bras, dans le repère du bras : il plie au coude (pose["el"], + : replié vers le haut).
static func fore_xf(i: int, arms: Array, phase: int, die: float, wake: float, form: float, pose := {}, t := 0.0) -> Transform2D:
	var side: int = SLOTS[i][0]
	var el := _arm_path(i, arms, phase, die, wake, form)[ELBOW]
	var ang := 0.03 * sin(t * 1.7 + i * 2.1) * wake
	if not pose.is_empty():
		ang += -side * float(pose["el"])
	return Transform2D(ang, Vector2.ONE, 0.0, el) * Transform2D(0.0, -el)


## Le motif au bout, dans le repère de l'avant-bras : il gonfle ou se resserre (pose["m"]).
static func motif_xf(i: int, arms: Array, phase: int, die: float, wake: float, form: float, pose := {}) -> Transform2D:
	var m := float(pose.get("m", 1.0))
	if is_equal_approx(m, 1.0):
		return Transform2D.IDENTITY
	var tip := _arm_path(i, arms, phase, die, wake, form)[8]
	return Transform2D(0.0, Vector2(m, m), 0.0, tip) * Transform2D(0.0, -tip)


## Les trois repères d'un bras posé : [bras, avant-bras, motif] (repère du dessin).
static func arm_chain(xf: Transform2D, i: int, arms: Array, t: float, phase: int, on: float, die: float, wake: float, form: float, pose := {}, aim_l := Vector2.ZERO) -> Array:
	var a := xf * arm_xf(i, t, on, wake, form, pose, aim_l)
	var f := a * fore_xf(i, arms, phase, die, wake, form, pose, t)
	return [a, f, f * motif_xf(i, arms, phase, die, wake, form, pose)]


## Assemble le colosse dans l'ordre (éclats du fond, bras du fond, corps, œil, bras de devant, cendre,
## braises, lueurs, éclats de devant). part.call(ci, xf, id) dessine une partie fixe dans le repère xf :
## id = "corps", ou pour le bras i : i (bras), "f<i>" (avant-bras), "m<i>" (motif) ; dessin direct,
## ou texture cuite par BossFinale.
## stage : "" pour tout, ou une seule couche (BossFinale les répartit sur des nœuds, les textures
## cuites demandant un autre mélange) : "fond", "corps", "milieu", "devant", "dessus".
## anim (facultatif, FinaleChoreo) : {"arms": [pose par bras], "fx": [effets par bras], "body":
## {lean, grow}, "aim": direction du héros (écran)}.
static func compose(ci: CanvasItem, c: Vector2, r: float, t: float, phase: int, k: float, lit: int, die: float, wake: float, lit2: int, form: float, facing: float, arms: Array, part: Callable, stage := "", anim := {}) -> void:
	var keep_flash := Ink.flash
	Ink.flash = 0.0
	var s := r / 100.0 * ART
	var base := Transform2D(0.0, Vector2(s * signf(facing if facing != 0.0 else 1.0), s), 0.0, c)
	var body: Dictionary = anim.get("body", {})
	var xf := body_xf(c, r, t, phase, k, die, wake, form, facing, float(body.get("lean", 0.0)), float(body.get("grow", 0.0)))
	var poses: Array = anim.get("arms", [])
	var fxs: Array = anim.get("fx", [])
	var aim: Vector2 = anim.get("aim", Vector2.ZERO)
	var aim_l := Vector2(aim.x * (1.0 if facing >= 0.0 else -1.0), aim.y)
	var chains: Array = []
	for i in arms.size():
		var pose: Dictionary = poses[i] if i < poses.size() else {}
		chains.append(arm_chain(xf, i, arms, t, phase, arm_on(i, k, lit, lit2, form), die, wake, form, pose, aim_l))
	if stage == "" or stage == "fond":
		Ink.ground_shadow(ci, base, Vector2(0, 14), 135.0 + 20.0 * form)
		if form > 0.0:
			_shards(ci, xf, t, form, lit, lit2, k, die, false, arms)
	if stage == "" or stage == "corps":
		for i in arms.size():
			if SLOTS[i][0] == 1:
				_arm_parts(ci, chains[i], i, part)
		part.call(ci, xf, "corps")
	if stage == "" or stage == "milieu":
		var glow := _glow(t, phase, die, wake)
		_eye(ci, xf, HEART + Vector2(0, -54.0 * 0.28 * (1.0 - form)), 1.0 + 0.3 * form, t, phase, k, die, wake)
		if not Ink.mono and die <= 0.0:
			Ink.halo(ci, xf * HEART, 60.0 * xf.get_scale().abs().y, Art.bc("braise"), 0.15 * glow * (1.0 + sin(t * 3.0)))
	if stage == "" or stage == "devant":
		for i in arms.size():
			if SLOTS[i][0] == -1:
				_arm_parts(ci, chains[i], i, part)
	if stage != "" and stage != "dessus":
		Ink.flash = keep_flash
		return
	# Ce qui vit par-dessus : la sève qui monte dans les veines, la lueur d'un bras allumé, les gestes.
	if not Ink.mono:
		for i in arms.size():
			var on := arm_on(i, k, lit, lit2, form)
			var ch: Array = chains[i]
			var element := str(arms[i]["element"])
			var path := _arm_path(i, arms, phase, die, wake, form)
			if phase >= int(arms[i]["phase"]) and die <= 0.0:
				var f := fposmod(t * 0.7 + i * 0.17, 1.0)
				var q := 1 + int(f * 6.0)
				var cx: Transform2D = ch[0] if q < ELBOW else ch[1]
				var at := path[q].lerp(path[q + 1], fposmod(f * 6.0, 1.0))
				ci.draw_circle(cx * at, 4.5 * cx.get_scale().abs().y, Color(Art.ec(element, "clair"), 0.85 * sin(PI * f)))
			var tipxf: Transform2D = ch[1]
			var tip := path[8]
			if on > 0.0:
				Ink.halo(ci, tipxf * tip, (44.0 + 26.0 * on) * tipxf.get_scale().abs().y, Art.ec(element, "clair"), 1.4 * on)
				if element == "lumiere":
					var d: Vector2 = (tip - path[6]).normalized()
					for j in 6:
						var dd: Vector2 = d.rotated((j - 2.5) * 0.4)
						ci.draw_line(tipxf * (tip + dd * 60.0), tipxf * (tip + dd * (80.0 + 40.0 * on)), Color(Art.ec(element, "clair"), on), 2.0, true)
			if i < fxs.size() and not (fxs[i] as Dictionary).is_empty():
				_gesture_fx(ci, xf, ch, path, i, element, fxs[i], t, aim_l)
	# La cendre qui monte des épaules et de la couronne ; des braises parmi, de plus en plus.
	if die < 1.0 and not Ink.mono:
		var up := 0.4 + 0.6 * wake
		U.ash(ci, xf, Vector2(-70, -140), 3, t * up, 3.0, 26.0, 60.0)
		U.ash(ci, xf, Vector2(40, -170), 3, t * up + 0.4, 3.0, 26.0, 70.0)
		U.ash(ci, xf, Vector2(-10, -250), 4, t * up + 0.8, 2.6, 60.0, 110.0)
		if phase >= 2 or form > 0.0:
			Ink.sparks(ci, xf, Vector2(-8, -250), Vector2(0, -3.2), 4 + phase, t, 2.4, (1.0 - die) * wake)
			Ink.sparks(ci, xf, Vector2(60, -40), Vector2(0.4, -2.0), 2 + phase, t + 0.7, 2.0, (1.0 - die) * wake)
	# Mort : des gouttes de sève montent des fentes et pâlissent.
	if die > 0.0 and not Ink.mono:
		var heart := xf * HEART
		var seve := Art.ec("seve", "clair")
		for i in 16:
			var a := TAU * i / 16.0 + 0.2
			var u := clampf(die * 1.4 - (i % 3) * 0.12, 0.0, 1.0)
			if u <= 0.0 or u >= 1.0:
				continue
			var q := heart + Vector2.from_angle(a) * r * ART * (0.3 + 1.0 * u) - Vector2(0, r * ART * 0.8 * u)
			ci.draw_circle(q, r * ART * (0.04 + 0.07 * u), Color(seve, 0.75 * (1.0 - u)))
		ci.draw_circle(heart, r * ART * 0.55 * die, Color(U.pal()["clair"], 0.25 * die))
	if form > 0.0:
		_shards(ci, xf, t, form, lit, lit2, k, die, true, arms)
	Ink.flash = keep_flash


static func _arm_parts(ci: CanvasItem, chain: Array, i: int, part: Callable) -> void:
	part.call(ci, chain[0], i)
	part.call(ci, chain[1], "f%d" % i)
	part.call(ci, chain[2], "m%d" % i)


## Les effets d'un geste (vivants, par-dessus) : fx = FinaleChoreo.arm_fx (wind : l'élan 0 → 1 ; hit :
## l'éclat de la frappe 1 → 0 ; hold : tenue de la frappe 0/1 ; kind : l'attaque).
static func _gesture_fx(ci: CanvasItem, xf: Transform2D, ch: Array, path: PackedVector2Array, i: int, element: String, fx: Dictionary, t: float, aim_l: Vector2) -> void:
	var wind := float(fx.get("wind", 0.0))
	var hit := float(fx.get("hit", 0.0))
	var hold := float(fx.get("hold", 0.0))
	var fxf: Transform2D = ch[1]
	var tip := path[8]
	var w := fxf * tip
	var sc := fxf.get_scale().abs().y
	var dir := (fxf.basis_xform(tip - path[6])).normalized()
	var light := Art.ec(element, "clair")
	var col := Art.ec(element)
	# L'élan : la matière de l'élément afflue vers le bout du bras, en spirale qui se resserre.
	if wind > 0.0:
		var n := 9
		for j in n:
			var u := fposmod(t * 1.6 + j / float(n), 1.0)
			var rad := (90.0 * (1.0 - u) + 10.0) * sc
			var a := j * TAU / n + t * 2.4 + u * 2.5
			var p := w + Vector2(cos(a) * rad, sin(a) * rad * 0.7)
			var al := wind * sin(PI * u)
			match element:
				"epine":
					var d := (w - p).normalized()
					ci.draw_line(p, p + d * 9.0 * sc, Color(U.bone()["clair"], al), 2.4 * sc, true)
				"vent":
					ci.draw_arc(p, 12.0 * sc, a, a + 1.6, 6, Color(light, 0.8 * al), 1.6 * sc, true)
				_:
					ci.draw_circle(p, (2.0 + 2.5 * (1.0 - u)) * sc, Color(light, 0.9 * al))
		if element == "lumiere" or element == "seve":
			Ink.halo(ci, w, 30.0 * sc * (0.5 + wind), light, wind)
	# La frappe : un éclat à la pointe, selon l'élément.
	if hit > 0.0:
		var f := 1.0 - hit
		match element:
			"epine":
				for j in 7:
					var d := dir.rotated((j - 3) * 0.32)
					ci.draw_line(w + d * (10.0 + 50.0 * f) * sc, w + d * (30.0 + 80.0 * f) * sc, Color(U.bone()["clair"], hit), 3.0 * sc, true)
			"poison":
				ci.draw_circle(w + dir * 30.0 * sc * f, (20.0 + 70.0 * f) * sc, Color(light, 0.35 * hit))
				for j in 10:
					var a := j * TAU / 10.0 + i
					ci.draw_circle(w + Vector2.from_angle(a) * (20.0 + 90.0 * f) * sc, 4.0 * sc * hit, Color(light, hit))
			"seve":
				for j in 3:
					var rr := (20.0 + 60.0 * fposmod(f + j * 0.33, 1.0)) * sc
					ci.draw_arc(w, rr, 0.0, TAU, 24, Color(light, 0.6 * hit), 3.0 * sc, true)
			"vent":
				for j in 4:
					var o := dir.orthogonal() * (j - 1.5) * 14.0 * sc
					ci.draw_line(w + o - dir * 140.0 * sc * hit, w + o + dir * 30.0 * sc, Color(light, 0.7 * hit), 2.4 * sc, true)
			"lumiere":
				for j in 8:
					var d := Vector2.from_angle(j * TAU / 8.0 + 0.2)
					var l := (j % 2 * 40.0 + 60.0) * sc * (0.6 + f)
					ci.draw_line(w, w + d * l, Color(light, hit), (4.0 - j % 2 * 2.0) * sc, true)
				ci.draw_circle(w, 16.0 * sc * hit, Color(Color.WHITE, hit))
			"racine":
				for j in 8:
					var a := -PI / 2.0 + (j - 3.5) * 0.35
					var q := w + Vector2.from_angle(a) * (16.0 + 70.0 * f) * sc + Vector2(0, 120.0 * f * f * sc)
					ci.draw_circle(q, (5.0 - j % 3) * sc, Color(Art.ec("racine", "sombre"), hit))
				ci.draw_arc(w, (20.0 + 50.0 * f) * sc, 0.0, TAU, 24, Color(light, 0.7 * hit), 3.0 * sc, true)
	# La tenue : le siphon boit (des gouttes remontent du bulbe vers le cœur).
	if hold > 0.0 and element == "seve":
		var heart := xf * HEART
		for j in 6:
			var u := fposmod(t * 1.4 + j / 6.0, 1.0)
			var p := w.lerp(heart, u) + Vector2(0, -sin(PI * u) * 40.0 * sc)
			ci.draw_circle(p, (5.0 - 2.0 * u) * sc, Color(light, hold * sin(PI * u)))


static func _glow(t: float, phase: int, die: float, wake: float) -> float:
	return ((0.6 + 0.35 * sin(t * (5.0 if phase >= 3 else 3.0))) * wake) if die <= 0.0 else 1.0 - die * 0.5


## Le corps, partie fixe (cuite par BossFinale ; ne dépend pas du temps) : couronne, pied de racines,
## souche, fentes de braise, manteau, poitrine et cœur. Repère local (xf).
static func draw_body(ci: CanvasItem, xf: Transform2D, phase: int, die: float, wake: float, form: float, tint: Callable) -> void:
	var t := 0.0
	# Le corps : bois brûlé gris de cendre (plus sombre que les communs : il porte la braise) ; le manteau
	# de plaques est en cendre pâle, le pied et les bras en charbon.
	var ash := _tp(tint, {"clair": Art.bc("commun", "ombre").lerp(Art.bc("commun", "clair"), 0.18), "ombre": Art.bc("commun", "charbon"), "reflet": Art.bc("commun", "clair")})
	var bark := _tp(tint, U.char_pal())
	var far_bark := {"clair": bark["ombre"], "ombre": Color(bark["ombre"].darkened(0.3), bark["ombre"].a), "reflet": bark["clair"]}
	var glow := 0.8 * wake if die <= 0.0 else 1.0 - die * 0.5
	if form < 0.9:
		_crown(ci, xf, t, phase, die, wake, form, _tp(tint, {"clair": Art.bc("commun", "ombre").darkened(0.2), "ombre": Art.bc("commun", "charbon"), "reflet": Art.bc("commun", "clair")}))
	# Le pied de racines qui l'ancre au sol (devant, il déborde sur la base).
	_feet(ci, xf, xf, t, phase, die, form, bark, far_bark)
	# La souche : le bas en charbon craquelé, la braise qui couve dans les joints.
	Ink.part(ci, xf, PackedVector2Array(BODY), ash, 3.2, 1.0, 0.5)
	Ink.fill_world(ci, xf * PackedVector2Array(LOW), bark, 0.6, 0.0)
	Ink.brush(ci, xf, PackedVector2Array([Vector2(-120, -30), Vector2(-96, -22), Vector2(-74, -30), Vector2(-52, -18), Vector2(-30, -10)]), 2.2, ash["reflet"])
	Ink.brush(ci, xf, PackedVector2Array([Vector2(36, -8), Vector2(62, -20), Vector2(84, -12), Vector2(100, -20)]), 2.2, ash["reflet"])
	# Écorce en long, sur le flanc et le dos.
	for g: Array in [[Vector2(-100, -60), Vector2(-96, -110)], [Vector2(-82, -40), Vector2(-74, -128)], [Vector2(-60, -90), Vector2(-40, -150)], [Vector2(80, -50), Vector2(64, -112)], [Vector2(90, -30), Vector2(88, -70)]]:
		Ink.brush(ci, xf, PackedVector2Array(g), 2.0, ash["ombre"])
	# Les cernes du bois au sommet du capuchon (la souche coupée).
	for j in 4:
		var rr := 18.0 + 13.0 * j
		var arc := PackedVector2Array()
		for q in 9:
			var a := PI + 0.25 + (PI - 0.5) * q / 8.0
			arc.append(Vector2(-6, -150) + Vector2(cos(a) * rr * 1.5, sin(a) * rr * 0.55))
		Ink.brush(ci, xf, arc, 1.6, Color(ash["ombre"], 0.8))
	# Les fentes de braise du corps : de plus en plus à chaque phase ; tout le corps en seconde forme.
	var hot := clampf(0.35 + 0.15 * phase + 0.5 * form, 0.0, 1.0) * (1.0 - die)
	var lines: Array = _body_cracks()
	var shown := mini(lines.size(), 5 + 3 * phase + int(10.0 * form))
	for j in shown:
		var ln: Array = lines[j]
		_crack(ci, xf, ln[0], ln[1] * (1.0 + 0.8 * form), hot * glow, t + j, die)
	# Le manteau de plaques d'écorce sur les épaules et le dos ; il tombe pendant la transformation.
	if form < 0.85:
		_mantle(ci, xf, t, die, form, _tp(tint, U.pal()))
	# La poitrine ouverte, le cœur, ses liens (l'œil est vivant : compose).
	_chest(ci, xf, t, phase, 0.0, die, wake, form, glow, tint)


## Palette passée par la teinte du boss (éclair du coup, poison, cendre de la mort).
static func _tp(tint: Callable, pal: Dictionary) -> Dictionary:
	var out := {}
	for key in pal:
		out[key] = tint.call(pal[key])
	return out


## Fente de braise (comme U.crack), qui devient sève à la mort.
static func _crack(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, w: float, glow: float, t: float, die := 0.0) -> void:
	if Ink.mono:
		return
	Ink.brush(ci, xf, pts, w * 1.9, Ink.encre())
	var flick := 0.8 + 0.2 * sin(t * 6.0)
	var col := Art.bc("braise").lerp(Art.bc("braise_coeur"), glow * 0.6)
	if die > 0.0:
		col = col.lerp(Art.ec("seve", "clair"), clampf(die * 2.0, 0.0, 1.0))
		glow = maxf(glow, die)
	Ink.brush(ci, xf, pts, w * (0.7 + 0.5 * glow), Color(col, clampf(0.4 + 0.6 * glow * flick, 0.0, 1.0)))


## Réseau de fentes du corps, tiré une fois (graine fixe, même dessin à chaque image) : [[points, largeur]].
static func _body_cracks() -> Array:
	if _cracks_cache.has("corps"):
		return _cracks_cache["corps"]
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	var zone := PackedVector2Array(BODY)
	var inner := Geometry2D.offset_polygon(zone, -14.0)
	var area: PackedVector2Array = inner[0] if not inner.is_empty() else zone
	var cav := Ink.oval(CAVITY_C, 66.0, 76.0, 20)
	var tries := 0
	while out.size() < 26 and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(-120, 110), rng.randf_range(-180, 30))
		if not Geometry2D.is_point_in_polygon(p, area) or Geometry2D.is_point_in_polygon(p, cav):
			continue
		var a := rng.randf_range(-1.2, 1.2) - PI / 2.0 * (1.0 if rng.randf() < 0.6 else -1.0)
		var line := PackedVector2Array([p])
		for _s in rng.randi_range(2, 4):
			a += rng.randf_range(-0.8, 0.8)
			var q := line[line.size() - 1] + Vector2.from_angle(a) * rng.randf_range(10.0, 22.0)
			if not Geometry2D.is_point_in_polygon(q, area) or Geometry2D.is_point_in_polygon(q, cav):
				break
			line.append(q)
		if line.size() >= 2:
			out.append([line, rng.randf_range(2.2, 3.6)])
	_cracks_cache["corps"] = out
	return out


## Le pied : de grosses racines brûlées qui sortent de la base et plongent dans le sol.
static func _feet(ci: CanvasItem, base: Transform2D, xf: Transform2D, t: float, phase: int, die: float, form: float, bark: Dictionary, far_bark: Dictionary) -> void:
	var roots := [
		[Vector2(-60, 10), Vector2(-150, 30), far_bark, 22.0],
		[Vector2(70, 8), Vector2(160, 26), far_bark, 20.0],
		[Vector2(-90, 18), Vector2(-136, 48), bark, 24.0],
		[Vector2(-20, 26), Vector2(-50, 62), bark, 22.0],
		[Vector2(40, 26), Vector2(80, 58), bark, 22.0],
		[Vector2(96, 18), Vector2(140, 44), bark, 20.0],
		[Vector2(-110, 4), Vector2(-196, 16), far_bark, 18.0],
		[Vector2(104, 2), Vector2(204, 12), far_bark, 16.0],
		[Vector2(-50, 30), Vector2(-104, 76), bark, 18.0],
		[Vector2(14, 34), Vector2(26, 84), bark, 18.0],
	]
	var lift := 1.0 - 0.5 * form
	for j in roots.size():
		var rt: Array = roots[j]
		var a: Vector2 = xf * rt[0]
		var b: Vector2 = base * (rt[1] * Vector2(1.0, lift))
		var w: float = rt[3]
		var mid := a.lerp(b, 0.5) + Vector2(0, -10.0 * base.get_scale().y)
		var la := base.affine_inverse()
		var pts := PackedVector2Array([la * a, la * mid, la * b])
		var pal: Dictionary = rt[2]
		Ink.brush(ci, base, pts, w + 4.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, base, pts, w, pal["clair"], 1.0, 0.0)
		Ink.brush(ci, base, PackedVector2Array([pts[0] + Vector2(-2, -w * 0.25), pts[1] + Vector2(-2, -w * 0.25)]), w * 0.22, Color(pal["reflet"], 0.5), 1.0, 0.0)
		if (phase >= 2 or form > 0.0) and die <= 0.0 and j >= 2:
			_crack(ci, base, PackedVector2Array([pts[0].lerp(pts[1], 0.3), pts[1], pts[1].lerp(pts[2], 0.6)]), 2.0, 0.5 + 0.5 * form, t + j)


## La couronne de bois mort au sommet du capuchon : sept grandes branches fourchues comme des bois de
## cerf, des fils de cendre qui pendent des fourches, braises au bout dès la phase 2 ; en seconde
## forme, elles basculent vers l'extérieur et tombent.
static func _crown(ci: CanvasItem, xf: Transform2D, t: float, phase: int, die: float, wake: float, form: float, bark: Dictionary) -> void:
	var fall := Anim.ease_in(clampf(form / 0.9, 0.0, 1.0))
	var rise := (0.6 + 0.4 * wake) * (1.0 - 0.4 * die)
	var pale := U.pal()
	for i: int in [0, 6, 1, 5, 2, 4, 3]:
		var u := (i - 3) / 3.0
		var from := Vector2(-6 + u * 54.0, -170 + absf(u) * 18.0)
		var a := -PI / 2.0 + u * 0.78 + 0.04 * sin(t * 0.7 + i) + fall * (1.2 if u >= 0.0 else -1.2) * (0.5 + absf(u))
		var length := (150.0 - 46.0 * absf(u)) * rise
		var drop := Vector2(u * 60.0 * fall, 220.0 * fall * fall)
		var pts := _wiggle(from + drop, a, length, 10.0, i * 2.3)
		Ink.brush(ci, xf, pts, 20.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, xf, pts, 15.0, bark["clair"], 1.0, 0.0)
		Ink.brush(ci, xf, pts.slice(0, 4), 3.0, Color(bark["reflet"], 0.45), 1.0, 0.0)
		# Les andouillers : deux fourches, chacune refendue au bout.
		for f in 2:
			var sgn: float = -1.0 if (i + f) % 2 == 0 else 1.0
			var at := pts[2 + 2 * f]
			var la := a + sgn * (0.7 + 0.15 * f)
			var tw := _wiggle(at, la, length * (0.46 - 0.1 * f), 5.0, i + sgn + f)
			Ink.brush(ci, xf, tw, 10.0, Ink.encre(), 1.0, 0.0)
			Ink.brush(ci, xf, tw, 6.5, bark["clair"], 1.0, 0.0)
			var end := tw[tw.size() - 1]
			for g in [-1.0, 1.0]:
				var tt := _wiggle(tw[4], la + g * 0.5, length * 0.16, 2.0, i * 3.0 + g)
				Ink.brush(ci, xf, tt, 5.0, Ink.encre(), 1.0, 0.0)
				Ink.brush(ci, xf, tt, 3.0, bark["clair"], 1.0, 0.0)
			# Un fil de cendre qui pend de la fourche, un flocon au bout.
			if fall <= 0.0 and f == 0:
				var hang := PackedVector2Array([at, at + Vector2(sgn * 6.0, 22.0), at + Vector2(sgn * 3.0, 44.0 + 6.0 * (i % 3))])
				Ink.brush(ci, xf, hang, 2.2, Color(pale["clair"], 0.75), 0.0, 0.0)
				Ink.part(ci, xf, Ink.leaf(hang[2], PI / 2.0, 12.0, 7.0), pale, 1.0, 1.0, 0.0)
			if phase >= 2 and die <= 0.0 and fall <= 0.0 and not Ink.mono:
				Ink.halo(ci, xf * end, 10.0 * xf.get_scale().abs().y, Art.bc("braise"), 0.6 + 0.4 * sin(t * 4.0 + i + sgn))
				Ink.flat(ci, xf, Ink.oval(end, 3.4, 2.6, 10), Art.bc("braise_coeur").lerp(Art.bc("braise"), 0.5))
		if phase >= 3 and die <= 0.0 and fall <= 0.0 and not Ink.mono:
			Ink.halo(ci, xf * pts[pts.size() - 1], 22.0 * xf.get_scale().abs().y, Art.bc("braise"), 0.8)


## Le manteau : sept plaques d'écorce brûlée posées sur les épaules et le dos, en tuiles ; elles
## s'écartent à la mort et glissent au sol pendant la transformation.
static func _mantle(ci: CanvasItem, xf: Transform2D, t: float, die: float, form: float, bark: Dictionary) -> void:
	# [attache, angle de la pointe (PI/2 : vers le bas), longueur, largeur], du bas vers le haut (tuiles).
	var plates := [
		[Vector2(-112, -64), PI / 2.0 + 0.35, 62.0, 34.0],
		[Vector2(-104, -104), PI / 2.0 + 0.55, 72.0, 40.0],
		[Vector2(86, -96), PI / 2.0 - 0.75, 56.0, 30.0],
		[Vector2(-78, -140), PI / 2.0 + 0.75, 74.0, 42.0],
		[Vector2(62, -144), PI / 2.0 - 0.95, 60.0, 34.0],
		[Vector2(-38, -166), PI / 2.0 + 1.05, 70.0, 40.0],
		[Vector2(22, -172), PI / 2.0 - 1.2, 64.0, 38.0],
		[Vector2(-10, -184), PI / 2.0 + 1.5, 58.0, 36.0],
	]
	var fall := Anim.ease_in(clampf(form / 0.85, 0.0, 1.0))
	for j in plates.size():
		var p: Array = plates[j]
		var at: Vector2 = p[0]
		var side := -1.0 if cos(p[1]) > 0.0 else 1.0
		var hang: float = p[1] + 0.03 * sin(t * 0.9 + j) + fall * side * -0.8
		var out := Vector2(side * (10.0 * die + 40.0 * fall), 260.0 * fall * fall)
		var plate := Ink.leaf(at + out - Vector2.from_angle(hang) * 8.0, hang, p[2], p[3], 0.05 * side)
		Ink.part(ci, xf, plate, bark, 2.2, 1.0, 0.25)
		var d := Vector2.from_angle(hang)
		Ink.brush(ci, xf, PackedVector2Array([at + out + d * 6.0, at + out + d * p[2] * 0.75]), 2.0, bark["ombre"].darkened(0.2))
		Ink.brush(ci, xf, PackedVector2Array([at + out + d * p[2] * 0.3 + d.orthogonal() * p[3] * 0.2, at + out + d * p[2] * 0.55 + d.orthogonal() * p[3] * 0.12]), 1.4, bark["ombre"].darkened(0.2))
		# Une frange de lichen de cendre sous la pointe (elle tombe avec la plaque).
		if form < 0.5:
			var end: Vector2 = at + out + d * p[2] * 0.92
			for q in 3:
				var st := end + d.orthogonal() * (q - 1) * 7.0
				var fringe := PackedVector2Array([st, st + Vector2(sin(j + q) * 4.0, 14.0 + 5.0 * q), st + Vector2(sin(j * 2.0 + q) * 6.0, 26.0 + 8.0 * ((j + q) % 3))])
				Ink.brush(ci, xf, fringe, 4.0, Color(Art.bc("commun", "charbon"), 0.9), 1.0, 0.0)


## La poitrine ouverte et le cœur : une graine noire, côtelée, qui bat, nouée de deux racines, fendue
## de braise ; l'œil s'ouvre au milieu. En seconde forme, elle s'ouvre en deux sur un noyau de braise.
static func _chest(ci: CanvasItem, xf: Transform2D, t: float, phase: int, k: float, die: float, wake: float, form: float, glow: float, tint: Callable) -> void:
	var beat := 1.0
	# Le creux : bord d'écorce déchiqueté, fond de « rongé » ; il s'élargit en seconde forme.
	var cav := Ink.lumpy(CAVITY_C, 60.0 + 10.0 * form, 70.0 + 6.0 * form, 22, 0.08, 7.0, 0.4)
	var ronge: Color = tint.call(Art.bc("ronge"))
	Ink.flat(ci, xf, cav, ronge, 2.6)
	Ink.halo(ci, xf * HEART, 60.0 * xf.get_scale().abs().y, Art.bc("braise"), 0.25 * glow + 0.6 * form)
	# Lèvres d'écorce qui retombent sur le bord du creux (comme des côtes).
	var ash := _tp(tint, U.pal())
	for j in 6:
		var a := -PI / 2.0 + (j - 2.5) * 0.5
		var p := CAVITY_C + Vector2(cos(a) * 62.0, sin(a) * 70.0)
		var q := CAVITY_C + Vector2(cos(a) * 50.0, sin(a) * 58.0) + Vector2(0, 10)
		Ink.brush(ci, xf, PackedVector2Array([p, q]), 5.0, ash["ombre"], 1.0, 0.0)
	var rx := 44.0 * beat
	var ry := 54.0 * beat
	var gap := 18.0 * form
	if form > 0.0:
		_core(ci, xf, t, form, die, glow)
	var seed := _tp(tint, {"clair": Art.bc("commun", "charbon").lightened(0.06), "ombre": Art.bc("commun", "detail").darkened(0.2), "reflet": Art.bc("commun", "ombre")})
	var halves: Array = [Ink.oval(HEART, rx, ry, 30)]
	if form > 0.0:
		halves = [_half(HEART - Vector2(gap, 0), rx, ry, -1, form), _half(HEART + Vector2(gap, 0), rx, ry, 1, form)]
	for hf in halves:
		Ink.part(ci, xf, hf, seed, 2.8, 1.0, 0.6)
	# Côtes de la graine.
	for j in 5:
		var u := (j + 1) / 6.0 * 2.0 - 1.0
		if form > 0.0 and absf(u) < 0.2:
			continue
		var sx := signf(u) * gap
		var pts := PackedVector2Array()
		for q in 7:
			var v := q / 6.0 * 1.7 - 0.85
			pts.append(HEART + Vector2(sx + u * rx * sqrt(maxf(1.0 - v * v, 0.0)) * 0.9, v * ry * 0.95))
		Ink.brush(ci, xf, pts, 2.6, Color(seed["ombre"].darkened(0.3), 0.9))
	# Fentes de braise de la graine (sève à la mort).
	var shown := mini(HEART_CRACKS.size(), 1 + phase + (1 if die > 0.0 else 0))
	for j in shown:
		var pts := PackedVector2Array()
		for q: Vector2 in HEART_CRACKS[j]:
			pts.append(HEART + Vector2(q.x * rx + (gap if q.x >= 0.0 else -gap), q.y * ry))
		_crack(ci, xf, pts, 3.4 + 2.0 * die, glow, t + j, die)
	# Les deux racines qui la nouent ; elles cassent au début de la transformation.
	var bind := clampf(1.0 - form * 2.5, 0.0, 1.0)
	if bind > 0.0:
		var knot: Color = tint.call(Art.bc("racine", "bois_ombre").lerp(Art.bc("commun", "charbon"), 0.5))
		for j in 2:
			var y0 := ry * (-0.3 + 0.62 * j)
			var pts := PackedVector2Array()
			for q in 9:
				var u := q / 8.0 * 2.0 - 1.0
				var x := u * rx * sqrt(maxf(1.0 - pow(y0 / ry, 2.0), 0.05)) * 1.22
				pts.append(HEART + Vector2(x + signf(u) * gap * 2.0, y0 + ry * 0.12 * u * (1 if j == 0 else -1) + 3.0 * sin(u * 5.0 + j) + 40.0 * form * absf(u)))
			Ink.brush(ci, xf, pts, 12.0 * bind, Ink.encre(), 1.0, 1.0)
			Ink.brush(ci, xf, pts, 8.5 * bind, knot, 1.0, 1.0)
			Ink.brush(ci, xf, pts.slice(1, 5), 2.0 * bind, Color(knot.lightened(0.3), 0.6), 1.0, 1.0)
			for q in [2, 6]:
				Ink.part(ci, xf, Ink.oval(pts[q], 6.5 * bind, 5.5 * bind, 10), {"clair": knot.lightened(0.08), "ombre": knot.darkened(0.3)}, 1.6, 1.0, 0.0)


## Une moitié de la graine ouverte (side : -1 gauche, 1 droite), penchée vers l'extérieur, bord
## intérieur déchiqueté.
static func _half(h: Vector2, rx: float, ry: float, side: int, form: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var tilt := 0.12 * form * side
	for q in 17:
		var a := -PI / 2.0 + PI * q / 16.0
		var p := Vector2(cos(a) * rx * side, sin(a) * ry)
		if q == 0 or q == 16:
			p.x = 0.0
		pts.append(h + p.rotated(tilt))
	for q in 5:
		var v := 1.0 - (q + 1) / 6.0 * 2.0
		pts.append(h + Vector2(side * rx * (0.06 + 0.08 * (q % 2)), v * ry * 0.95).rotated(tilt))
	if side < 0:
		pts.reverse()
	return pts


## Le noyau de braise entre les deux moitiés : une lueur qui bat.
static func _core(ci: CanvasItem, xf: Transform2D, t: float, form: float, die: float, glow: float) -> void:
	if Ink.mono:
		return
	var fade := form * (1.0 - die)
	var pulse := 0.75 + 0.25 * sin(t * 6.0)
	Ink.flat(ci, xf, Ink.oval(HEART, 40.0 * form, 58.0, 22), Color(Art.bc("braise").darkened(0.55), fade))
	Ink.flat(ci, xf, Ink.oval(HEART, 30.0 * form, 50.0, 22), Color(Art.bc("braise"), 0.9 * fade * pulse))
	Ink.flat(ci, xf, Ink.oval(HEART, 18.0 * form, 36.0, 18), Color(Art.bc("braise_coeur"), 0.95 * fade * glow))


## L'œil de braise au milieu du cœur : fente verticale noire dans une amande de braise. Fermé (un trait)
## quand elle dort ; il s'ouvre grand pendant l'annonce ; plus grand en seconde forme.
static func _eye(ci: CanvasItem, xf: Transform2D, e: Vector2, g: float, t: float, phase: int, k: float, die: float, wake: float) -> void:
	var open := wake * (1.0 - die) * (0.55 + 0.1 * phase + 0.35 * k)
	var w := 34.0 * g
	if open <= 0.05:
		Ink.brush(ci, xf, PackedVector2Array([e + Vector2(-w * 0.8, 0), e + Vector2(0, 3), e + Vector2(w * 0.8, 0)]), 3.2, Ink.encre())
		Ink.brush(ci, xf, PackedVector2Array([e + Vector2(-w * 0.5, 1), e + Vector2(w * 0.5, 1)]), 1.6, Color(Art.bc("braise"), 0.4 + 0.3 * sin(t * 2.0)))
		return
	var hgt := 24.0 * g * open
	var lid := PackedVector2Array()
	for q in 16:
		var a := TAU * q / 16.0
		lid.append(e + Vector2(cos(a) * w, sin(a) * hgt * (1.0 - 0.35 * absf(cos(a)))))
	if not Ink.mono:
		Ink.halo(ci, xf * e, w * (1.3 + 0.5 * k) * xf.get_scale().abs().y, Art.bc("braise"), open)
	Ink.flat(ci, xf, lid, Art.bc("encre"), 2.4)
	if Ink.mono:
		return
	var iris := Ink.oval(e, minf(hgt, w) * 0.9, minf(hgt, w) * 0.9, 18)
	Ink.flat(ci, xf, iris, Art.bc("braise"))
	Ink.flat(ci, xf, Ink.oval(e + Vector2(-2, -2), minf(hgt, w) * 0.55, minf(hgt, w) * 0.55, 14), Art.bc("braise_coeur").lerp(Color.WHITE, 0.3 * k))
	var pw := 5.0 - 2.5 * k
	Ink.flat(ci, xf, PackedVector2Array([e + Vector2(0, -hgt * 0.95), e + Vector2(pw, 0), e + Vector2(0, hgt * 0.95), e + Vector2(-pw, 0)]), Art.bc("encre"))
	# Un reflet blanc chaud.
	Ink.flat(ci, xf, Ink.oval(e + Vector2(-w * 0.32, -hgt * 0.35), 3.0, 2.2, 8), Color(1, 0.96, 0.88, 0.85))


## Chemin d'un bras au repos (9 points, repère local), sans sa pose (arm_xf) : déplié, ou replié
## contre elle quand elle dort, plus court tant qu'il n'est pas éveillé, retombé au sol à la mort.
## Le coude est au point ELBOW.
static func _arm_path(i: int, arms: Array, phase: int, die: float, wake: float, form: float) -> PackedVector2Array:
	var side: int = SLOTS[i][0]
	var slot: int = SLOTS[i][1]
	var awake: bool = phase >= int(arms[i]["phase"])
	var sh: Vector2 = SHOULDER[side]
	var tip: Vector2 = TIPS[side][slot]
	if not awake:
		tip = sh.lerp(tip, 0.82) + Vector2(0, 26)
	var fold := sh.lerp(tip, 0.38) + Vector2(side * -10.0, 90.0 + slot * 24.0)
	tip = fold.lerp(tip, wake)
	tip = sh + (tip - sh) * (1.0 + 0.16 * form)
	if die > 0.0:
		tip = tip.lerp(Vector2(sh.x + (tip.x - sh.x) * 0.8, 30.0), Anim.ease_in(die))
	var dir := (tip - sh).normalized()
	var bulge := dir.orthogonal() * (-1.0 if side > 0 else 1.0) * (34.0 + 30.0 * (1.0 - wake) + 10.0 * form)
	var ctrl := sh.lerp(tip, 0.5) + bulge
	var path := PackedVector2Array()
	for q in 9:
		var u := q / 8.0
		path.append(sh.lerp(ctrl, u).lerp(ctrl.lerp(tip, u), u))
	return path


## Épaisseur du bras le long de son chemin (u 0 → 1) : large à l'épaule, effilé au bout.
static func _arm_w(u: float, far: bool) -> float:
	return lerpf(34.0, 13.0, pow(u, 0.8)) * (0.9 if far else 1.0)


## Un membre effilé le long de pts (épaisseur w0 → w1) : bois brûlé, encre autour, reflet de cendre du
## côté de la lumière. Fait de tronçons (trapèzes et disques aux joints) : jamais de polygone croisé,
## même plié serré.
static func _limb(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, w0: float, w1: float, pal: Dictionary, ink: float) -> void:
	var p := pts
	for _k in 2:
		var sm := PackedVector2Array([p[0]])
		for q in p.size() - 1:
			sm.append(p[q].lerp(p[q + 1], 0.25))
			sm.append(p[q].lerp(p[q + 1], 0.75))
		sm.append(p[p.size() - 1])
		p = sm
	var n := p.size()
	var wp := xf * p
	var k := xf.get_scale().abs().x
	var widths: Array = []
	for q in n:
		var u := float(q) / (n - 1)
		widths.append(lerpf(w0, w1, u) * 0.5 * (1.0 + 0.07 * sin(u * 23.0)) * k)
	var iw := ink * Ink.INK * k
	for pass_ in 2:
		var col: Color = Ink.encre() if pass_ == 0 else Ink.shade(pal["ombre"])
		var grow := iw if pass_ == 0 else 0.0
		for q in n - 1:
			var d := (wp[q + 1] - wp[q]).normalized().orthogonal()
			var a: float = widths[q] + grow
			var b: float = widths[q + 1] + grow
			var off := -Ink.LIGHT * grow * 0.45 if pass_ == 0 else Vector2.ZERO
			var quad := PackedVector2Array([wp[q] + d * a + off, wp[q + 1] + d * b + off, wp[q + 1] - d * b + off, wp[q] - d * a + off])
			ci.draw_colored_polygon(quad, col)
			ci.draw_circle(wp[q + 1] + off, b, col)
		ci.draw_circle(wp[0] + (-Ink.LIGHT * grow * 0.45 if pass_ == 0 else Vector2.ZERO), float(widths[0]) + grow, col)
	if Ink.mono:
		return
	# La face éclairée : une bande décalée vers la lumière, puis un fil de reflet.
	var lit := PackedVector2Array()
	var shine := PackedVector2Array()
	for q in n:
		var d := (wp[mini(q + 1, n - 1)] - wp[maxi(q - 1, 0)]).normalized().orthogonal()
		var side := 1.0 if d.dot(Ink.LIGHT) > 0.0 else -1.0
		lit.append(wp[q] + d * side * float(widths[q]) * 0.3)
		shine.append(wp[q] + d * side * float(widths[q]) * 0.62)
	ci.draw_polyline(lit, Ink.shade(pal["clair"]), maxf(1.0, float(widths[n / 2]) * 0.9), true)
	ci.draw_polyline(shine, Color(Ink.shade(pal["reflet"]), 0.35), maxf(1.0, 2.2 * k), true)


## Un bras, partie fixe (cuite par BossFinale), en trois pièces : « haut » (de l'épaule au coude),
## « bas » (du coude au bout, avec le nœud du coude) et « motif » (ce qu'il porte au bout). Une longue
## racine brûlée, épaisse à l'épaule, couverte d'écailles d'écorce, noueuse, épineuse, veinée de son
## élément (plus vive quand il s'allume : on). Pas encore éveillé : gris de cendre. Les bras du fond
## (côté 1) sont plus sombres.
static func draw_arm(ci: CanvasItem, xf: Transform2D, i: int, arms: Array, phase: int, on: float, die: float, wake: float, form: float, tint: Callable, piece := "") -> void:
	if piece == "":
		for pc in ["haut", "bas", "motif"]:
			draw_arm(ci, xf, i, arms, phase, on, die, wake, form, tint, pc)
		return
	var far: bool = SLOTS[i][0] == 1
	var element := str(arms[i]["element"])
	var awake: bool = phase >= int(arms[i]["phase"])
	var path := _arm_path(i, arms, phase, die, wake, form)
	var tip := path[8]
	var bark := _tp(tint, U.char_pal())
	if far:
		bark = {"clair": bark["ombre"], "ombre": Color(bark["ombre"].darkened(0.3), bark["ombre"].a), "reflet": bark["clair"]}
	var col: Color = Art.ec(element) if awake else U.pal()["ombre"]
	if die > 0.0:
		col = col.lerp(U.pal()["clair"], die)
	if piece == "motif":
		var md := (tip - path[6]).normalized()
		_motif(ci, xf, tip, md, 46.0 * (1.0 + 0.25 * on), element, col, awake, on, float(i), far)
		return
	# Le bois du bras : charbon, face éclairée de cendre (lisible sur le sol sombre du creux).
	var gray: Color = tint.call(Art.bc("commun", "ombre").darkened(0.22 if not far else 0.42))
	var wood := {"clair": gray.lightened(0.14), "ombre": gray, "reflet": tint.call(Art.bc("commun", "clair"))}
	var lo := 0 if piece == "haut" else ELBOW
	var hi := ELBOW if piece == "haut" else 8
	var seg := path.slice(lo, hi + 1)
	if piece == "bas":
		# Le bout s'enfonce dans le motif.
		seg[seg.size() - 1] = path[7].lerp(path[8], 1.15)
	var w0 := _arm_w(lo / 8.0, far)
	var w1 := _arm_w(hi / 8.0, far) if piece == "haut" else 10.0
	_limb(ci, xf, seg, w0, w1, wood, 2.6)
	# Le grain de l'écorce : de longues stries sombres qui suivent le bras, et des anneaux noueux.
	for g in 3:
		var off := (g - 1) * 0.28
		var line := PackedVector2Array()
		for q in seg.size():
			var u := (lo + q) / 8.0
			var d := (seg[mini(q + 1, seg.size() - 1)] - seg[maxi(q - 1, 0)]).normalized()
			line.append(seg[q] + d.orthogonal() * _arm_w(u, far) * (off + 0.05 * sin(q * 2.0 + g + i)))
		Ink.brush(ci, xf, line, 2.2, Color(Ink.encre(), 0.55), 0.0, 0.0)
	for q in range(1, seg.size() - 1):
		var u := (lo + q) / 8.0
		var d := (seg[q + 1] - seg[q - 1]).normalized()
		var o := d.orthogonal()
		var w := _arm_w(u, far)
		# Un anneau (bourrelet) et une épine d'os, d'un côté puis de l'autre.
		Ink.brush(ci, xf, PackedVector2Array([seg[q] - o * w * 0.5, seg[q] + d * 4.0, seg[q] + o * w * 0.5]), 3.2, Ink.encre(), 0.0, 0.0)
		Ink.brush(ci, xf, PackedVector2Array([seg[q] - o * w * 0.4 + d * 3.0, seg[q] + d * 6.0, seg[q] + o * w * 0.4 + d * 3.0]), 1.6, Color(wood["reflet"], 0.4), 0.0, 0.0)
		var sg := 1.0 if (lo + q) % 2 == 0 else -1.0
		Ink.part(ci, xf, Ink.thorn(seg[q] + o * sg * w * 0.42, (o * sg + d * 0.9).angle(), 12.0 + w * 0.4, 9.0, 0.14 * sg), U.bone() if not far else wood, 1.3, 1.0, 0.0)
	# La veine de l'élément (braise grise tant qu'il dort).
	if awake and not Ink.mono:
		Ink.brush(ci, xf, seg, 8.0 + 6.0 * on, Color(col, 0.22 + 0.25 * on), 1.0, 1.0)
		Ink.brush(ci, xf, seg, 2.8 + 2.0 * on, Color(Art.ec(element, "clair"), 0.65 + 0.35 * on), 0.6, 0.6)
	if piece == "bas":
		# Le nœud du coude : une loupe de bois brûlé, fendue de la couleur de l'élément.
		var el := path[ELBOW]
		var wk := _arm_w(ELBOW / 8.0, far)
		Ink.part(ci, xf, Ink.lumpy(el, wk * 0.5, wk * 0.46, 14, 0.18, 5.0, float(i)), wood, 2.4, 1.0, 0.4)
		if awake:
			_crack(ci, xf, PackedVector2Array([el + Vector2(-wk * 0.3, -wk * 0.2), el + Vector2(0, 2), el + Vector2(wk * 0.25, wk * 0.22)]), 2.2, 0.4 + 0.6 * on, float(i))
		# Des radicelles qui pendent du coude (encre fine).
		for j in 3:
			var a := PI / 2.0 + (j - 1) * 0.35
			Ink.brush(ci, xf, _wiggle(el + Vector2((j - 1) * 6.0, wk * 0.4), a, 26.0 + 8.0 * j, 3.0, i + j), 2.0, Color(Ink.encre(), 0.8))


## Boîte (repère local) où tient une pièce du bras i, quelle que soit sa pose de repos (pour sa
## texture cuite ; la pose animée est une transformation de la texture).
static func arm_box(i: int, piece := "") -> Rect2:
	var arms := []
	for j in 6:
		arms.append({"phase": 1 if j != i else 1})
	var r := Rect2()
	var first := true
	for wake in [0.0, 1.0]:
		for die in [0.0, 1.0]:
			for form in [0.0, 1.0]:
				for awake in [0, 9]:
					arms[i] = {"phase": awake}
					var path := _arm_path(i, arms, 1, die, wake, form)
					var pts: Array = []
					match piece:
						"haut":
							pts = Array(path.slice(0, ELBOW + 1))
						"bas":
							pts = Array(path.slice(ELBOW, 9))
						"motif":
							pts = [path[8]]
						_:
							pts = Array(path)
					for p: Vector2 in pts:
						if first:
							r = Rect2(p, Vector2.ZERO)
							first = false
						r = r.expand(p)
	var grow := 46.0
	if piece == "motif" or piece == "":
		grow = 46.0 * 2.4
	elif piece == "bas":
		grow = 60.0
	return r.grow(grow)


## Boîte serrée (repère local) d'une pièce du bras i dans sa pose de repos du moment (pour sa texture
## cuite, refaite à chaque changement de pose), au pas de 16 unités.
static func arm_piece_box(i: int, arms: Array, phase: int, die: float, wake: float, form: float, piece: String) -> Rect2:
	var path := _arm_path(i, arms, phase, die, wake, form)
	var pts: Array = Array(path.slice(0, ELBOW + 1)) if piece == "haut" else (Array(path.slice(ELBOW, 9)) if piece == "bas" else [path[8]])
	var r := Rect2(pts[0], Vector2.ZERO)
	for p: Vector2 in pts:
		r = r.expand(p)
	r = r.grow(46.0 * 2.4 if piece == "motif" else (60.0 if piece == "bas" else 46.0))
	var p0 := (r.position / 16.0).floor() * 16.0
	var p1 := (r.end / 16.0).ceil() * 16.0
	return Rect2(p0, p1 - p0)


## Boîte (repère local) du corps, partie fixe.
static func body_box() -> Rect2:
	return Rect2(-280, -400, 560, 520)


## Le motif d'un élément au bout d'un bras, tourné vers l'extérieur (dir), en repère local.
static func _motif(ci: CanvasItem, xf: Transform2D, tip: Vector2, dir: Vector2, s: float, element: String, col: Color, awake: bool, on: float, t: float, far: bool) -> void:
	var side := dir.orthogonal()
	var ang := dir.angle()
	var light := Art.ec(element, "clair") if awake else col.lightened(0.25)
	var dark := Art.ec(element, "sombre") if awake else col.darkened(0.35)
	if far:
		col = col.darkened(0.15)
	var pal := {"clair": col, "ombre": dark, "reflet": light}
	match element:
		"epine":
			# Une couronne de cinq épines, la plus longue au milieu.
			Ink.part(ci, xf, Ink.oval(tip, s * 0.3, s * 0.3, 12), {"clair": dark, "ombre": dark.darkened(0.3)}, 1.6, 0.5, 0.0)
			for j in 5:
				var a := ang + (j - 2) * 0.42
				Ink.part(ci, xf, Ink.thorn(tip, a, s * (1.6 - 0.25 * absi(j - 2)), s * 0.38, 0.06 * (j - 2)), pal, 1.8, 1.0, 0.4)
		"poison":
			# Une grappe de trois champignons, chapeaux piqués de points clairs ; des spores s'en échappent.
			for j in 3:
				var off := side * s * (j - 1) * 0.72 + dir * s * (0.5 - 0.35 * absi(j - 1))
				var size := s * (0.9 - 0.28 * absi(j - 1))
				var b := tip + off
				Ink.brush(ci, xf, PackedVector2Array([tip, b]), 5.0, dark, 1.0, 1.0)
				var cap := PackedVector2Array()
				for q in 11:
					cap.append(b + Vector2.from_angle(ang - PI / 2.0 + PI * q / 10.0) * size)
				Ink.part(ci, xf, cap, pal, 1.8, 1.0, 0.6 if awake else 0.0)
				if awake:
					for q in 3:
						Ink.flat(ci, xf, Ink.oval(b + dir * size * 0.5 + side * size * (q - 1) * 0.42, size * 0.12, size * 0.12, 8), light)
			if awake and not Ink.mono:
				for q in 4:
					var f := fposmod(t * 0.5 + q * 0.25, 1.0)
					ci.draw_circle(xf * (tip + dir * s * (1.2 + f) + side * s * sin(q * 2.0) * 0.6), s * 0.1 * xf.get_scale().abs().y, Color(light, 0.6 * (1.0 - f)))
		"seve":
			# Un bulbe de sève, lourd, qui goutte.
			Ink.part(ci, xf, PackedVector2Array([tip - dir * s * 0.9, tip + side * s * 0.6, tip + dir * s * 0.8, tip - side * s * 0.6]), {"clair": dark, "ombre": dark.darkened(0.3)}, 1.6, 0.5, 0.0)
			Ink.part(ci, xf, Ink.oval(tip + dir * s * 0.35, s * 0.78, s * 0.78, 18), pal, 2.0, 1.0, 1.0 if awake else 0.0)
			if awake and not Ink.mono:
				var f := fposmod(t * 0.8, 1.0)
				ci.draw_circle(xf * (tip + dir * s * 0.35 + Vector2(0, s * (0.8 + 1.2 * f))), s * 0.16 * (1.0 - 0.4 * f) * xf.get_scale().abs().y, Color(col, 1.0 - f))
		"vent":
			# Un éventail de trois plumes.
			for j in 3:
				var a := ang + (j - 1) * 0.48
				var l := s * (1.75 - 0.25 * absi(j - 1))
				Ink.part(ci, xf, Ink.leaf(tip - Vector2.from_angle(a) * s * 0.15, a, l, s * 0.62, 0.05 * (j - 1)), pal, 1.8, 1.0, 0.4)
				Ink.brush(ci, xf, PackedVector2Array([tip, tip + Vector2.from_angle(a) * l * 0.92]), 2.0, dark)
				for q in 3:
					var p := tip + Vector2.from_angle(a) * l * (0.35 + q * 0.18)
					Ink.brush(ci, xf, PackedVector2Array([p, p + Vector2.from_angle(a + 0.9) * s * 0.22]), 1.2, dark)
		"lumiere":
			# Une grappe de cristaux ; des rayons pendant l'annonce.
			for j in 3:
				var d := Vector2.from_angle(ang + (j - 1) * 0.5)
				var o := d.orthogonal()
				var l := s * (1.5 - 0.35 * absi(j - 1))
				var gem := PackedVector2Array([tip - d * s * 0.2, tip + d * l * 0.45 + o * s * 0.32, tip + d * l, tip + d * l * 0.45 - o * s * 0.32])
				Ink.part(ci, xf, gem, pal, 1.8, 1.0, 1.0 if awake else 0.0)
				if awake:
					Ink.brush(ci, xf, PackedVector2Array([tip + d * l * 0.2, tip + d * l * 0.8]), 1.6, Color(light, 0.8))
		"racine":
			# Une griffe de quatre crochets.
			Ink.part(ci, xf, Ink.oval(tip, s * 0.32, s * 0.3, 12), {"clair": dark, "ombre": dark.darkened(0.3)}, 1.6, 0.5, 0.0)
			for j in 4:
				var a := ang + (j - 1.5) * 0.45
				var d := Vector2.from_angle(a)
				var q1 := tip + d * s * 1.1
				var hook := q1 + d.orthogonal() * s * 0.45 * (1.0 if j >= 2 else -1.0) - d * s * 0.15
				var pts := PackedVector2Array([tip, q1, hook])
				Ink.brush(ci, xf, pts, 9.0, Ink.encre(), 1.0, 0.0)
				Ink.brush(ci, xf, pts, 6.0, col, 1.0, 0.0)
				Ink.brush(ci, xf, pts.slice(0, 2), 1.6, Color(light, 0.6), 1.0, 0.0)


## Les six éclats des gardiens, en orbite autour d'elle (aplatie, vue de 3/4) : ceux de derrière avant
## le corps, ceux de devant après. L'éclat d'un bras allumé brille.
static func _shards(ci: CanvasItem, xf: Transform2D, t: float, form: float, lit: int, lit2: int, k: float, die: float, front: bool, arms: Array) -> void:
	var fade := form * (1.0 - die)
	if fade <= 0.05:
		return
	for i in arms.size():
		var a := t * 0.45 + TAU * i / arms.size()
		if (sin(a) > 0.0) != front:
			continue
		var orbit := 205.0 * (0.5 + 0.5 * form)
		var p := HEART + Vector2(cos(a) * orbit, sin(a) * orbit * 0.36 - 20.0 + 10.0 * sin(t * 1.7 + i))
		var element := str(arms[i]["element"])
		var on := k if (i == lit or i == lit2) else 0.0
		var s := (15.0 + 3.0 * sin(t * 3.0 + i)) * (1.0 + 0.4 * on) * (0.85 + 0.15 * sin(a))
		if not Ink.mono:
			Ink.halo(ci, xf * p, s * (2.4 + on) * xf.get_scale().abs().y, Art.ec(element, "clair"), (0.6 + on) * fade)
		var gem := PackedVector2Array([p + Vector2(0, -s * 1.6), p + Vector2(s * 0.75, 0), p + Vector2(0, s * 1.1), p + Vector2(-s * 0.75, 0)])
		var pal := {"clair": Color(Art.ec(element), fade), "ombre": Color(Art.ec(element, "sombre"), fade), "reflet": Color(Art.ec(element, "clair"), fade)}
		if fade >= 0.95:
			Ink.part(ci, xf, gem, pal, 1.6, 1.0, 1.0)
		else:
			Ink.fill_world(ci, xf * gem, pal, 1.0, 1.0)
		Ink.brush(ci, xf, PackedVector2Array([p + Vector2(0, -s * 1.2), p + Vector2(0, s * 0.6)]), 1.5, Color(Art.ec(element, "clair"), 0.8 * fade))


## Un chemin ondulé de « length » dans la direction « a », depuis « from » (sept points, repère local).
static func _wiggle(from: Vector2, a: float, length: float, amp: float, salt: float) -> PackedVector2Array:
	var d := Vector2.from_angle(a)
	var o := d.orthogonal()
	var out := PackedVector2Array()
	for q in 7:
		var u := q / 6.0
		out.append(from + d * length * u + o * amp * sin(u * 5.0 + salt) * u)
	return out


## Le sol autour d'elle, sous les annonces : une flaque de brume de cendre et les grosses racines
## brûlées qui l'ancrent au creux, couchées sur le sol (aplaties, vue de 3/4) ; des braises y
## courent dès la phase 2 ; en seconde forme, les racines cassent et le sol se fend de braise.
static func draw_floor(ci: CanvasItem, c: Vector2, r: float, t: float, phase: int, die := 0.0, form := 0.0) -> void:
	draw_floor_static(ci, c, r, phase, form, die)
	draw_floor_live(ci, c, r, t, phase, die, form)


## La part fixe du sol (brume, racines) : cuite par BossFinale à chaque changement de phase, de forme, de mort.
static func draw_floor_static(ci: CanvasItem, c: Vector2, r: float, _phase: int, form: float, die: float) -> void:
	var fade := 1.0 - die
	var s := r / 100.0
	var flat := Transform2D(0.0, Vector2(s, s * 0.5), 0.0, c + Vector2(0, 10.0 * s))
	var mist: Color = U.pal()["ombre"].lerp(Art.bc("ronge"), 0.5)
	for j in 3:
		ci.draw_colored_polygon(Ink.oval(c + Vector2(0, 8.0 * s), r * (1.7 + 0.5 * j), r * (0.8 + 0.22 * j), 32), Color(mist, 0.16 * fade))
	var bark := U.char_pal()
	for i in 11:
		var path := _floor_root(i, form)
		if fade < 1.0:
			ci.draw_polyline(flat * path, Color(bark["clair"], 0.9 * fade), 22.0 * s * 0.7, true)
			continue
		Ink.brush(ci, flat, path, 26.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, flat, path, 22.0, bark["clair"], 1.0, 0.0)
		Ink.brush(ci, flat, path.slice(0, 4), 3.0, Color(bark["reflet"], 0.35), 1.0, 0.0)
		# Une radicelle de côté.
		var a := TAU * i / 11.0 + 0.23 * sin(i * 7.3)
		var sub := _wiggle(path[3], a + (0.7 if i % 2 == 0 else -0.7), path[0].distance_to(path[6]) * 0.35, 8.0, i * 3.1)
		Ink.brush(ci, flat, sub, 10.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, flat, sub, 7.0, bark["clair"], 1.0, 0.0)


## Une racine du sol (repère local aplati).
static func _floor_root(i: int, form: float) -> PackedVector2Array:
	var a := TAU * i / 11.0 + 0.23 * sin(i * 7.3)
	var length := 100.0 * (2.2 + 0.7 * fposmod(i * 0.618, 1.0)) * (1.0 - 0.45 * form)
	return _wiggle(Vector2.from_angle(a) * 80.0, a, length, 16.0, i * 1.9)


## La part vivante du sol : les braises qui courent dans les racines dès la phase 2, et en seconde
## forme le sol qui se fend de braise sous elle.
static func draw_floor_live(ci: CanvasItem, c: Vector2, r: float, t: float, phase: int, die := 0.0, form := 0.0) -> void:
	var fade := 1.0 - die
	var s := r / 100.0
	var flat := Transform2D(0.0, Vector2(s, s * 0.5), 0.0, c + Vector2(0, 10.0 * s))
	var ember := Art.bc("braise")
	if phase >= 2 and die <= 0.0:
		for i in 11:
			var path := _floor_root(i, form)
			var f := fposmod(t * 0.35 + i * 0.29, 1.0)
			var q := path[1].lerp(path[path.size() - 2], f)
			ci.draw_circle(flat * q, 5.0 * s, Color(ember, 0.6 * sin(PI * f)))
	if form > 0.0:
		var hot := Art.bc("braise_coeur")
		for i in 9:
			var a := TAU * i / 9.0 + 0.4
			var path := flat * _wiggle(Vector2.from_angle(a) * 40.0, a, 100.0 * (1.4 + 0.9 * form + 0.3 * fposmod(i * 0.618, 1.0)), 12.0, i * 2.7)
			var pulse := 0.6 + 0.4 * sin(t * 3.0 + i)
			ci.draw_polyline(path, Color(Art.bc("encre"), 0.7 * form * fade), 9.0, true)
			ci.draw_polyline(path, Color(ember.lerp(hot, 0.4), 0.8 * form * pulse * fade), 3.0, true)


## Après la victoire : à sa place, une pousse de l'Arbre de vie, six feuilles aux couleurs des gardiens,
## sur un reste de souche brûlée qui fume encore un peu.
static func draw_victory(ci: CanvasItem, c: Vector2, t: float, arms: Array) -> void:
	var xf := Transform2D(0.0, Vector2(1.5, 1.5), 0.0, c)
	Art.glow(ci, c + Vector2(0, -40), 120.0, "seve")
	Ink.ground_shadow(ci, xf, Vector2(0, 2), 30.0)
	# La souche : un anneau de charbon éclaté, cendre pâle au bord.
	var stump := PackedVector2Array([Vector2(-26, 4), Vector2(-28, -6), Vector2(-20, -12), Vector2(-14, -6), Vector2(-6, -14), Vector2(4, -8), Vector2(12, -15), Vector2(20, -7), Vector2(28, -9), Vector2(27, 4), Vector2(0, 8)])
	Ink.part(ci, xf, stump, U.char_pal(), 2.0, 1.0, 0.2)
	U.ash(ci, xf, Vector2(-14, -12), 2, t, 1.8, 10.0, 26.0)
	# La pousse.
	var bark := {"clair": Art.bc("seve", "clair").lerp(Art.c("decor_vivant"), 0.5), "ombre": Art.bc("seve", "ombre"), "reflet": Art.bc("seve", "reflet")}
	var stem := PackedVector2Array([Vector2(0, -6), Vector2(-2, -26), Vector2(1, -46), Vector2(0, -64)])
	Ink.brush(ci, xf, stem, 7.0, Ink.encre(), 1.0, 0.0)
	Ink.brush(ci, xf, stem, 4.6, bark["clair"], 1.0, 0.0)
	for i in arms.size():
		var ang := -PI / 2.0 + (i - 2.5) * 0.46 + 0.06 * sin(t * 1.5 + i)
		var b := Vector2(0, -60 + 6.0 * absf(i - 2.5))
		var col := Art.ec(str(arms[i]["element"])).lerp(Art.c("decor_vivant"), 0.25)
		Ink.part(ci, xf, Ink.leaf(b, ang, 24.0, 12.0, 0.04 * (i - 2.5)), {"clair": col, "ombre": col.darkened(0.35), "reflet": col.lightened(0.4)}, 1.4, 1.0, 0.5)
