## Dessin du Porte-Graine, gardien de l'Arbre : l'Esprit masqué (refonte des personnages, 25/11).
## Fonctions statiques sans état : player.gd s'en sert en jeu, les signatures (skill_fx.gd) et les
## galeries pour figer chaque pose.
##
## Le dessin vient de scripts/creature_art/heros/esprit.gd (tenue selon les branches du build, vraie arme
## selon la forme d'attaque, ornements selon les modifications) : en jeu, cuit en sprites par
## hero_bake.gd à chaque changement d'apparence (hero_look.gd) ; sans atlas cuit (galeries, tests),
## dessiné directement. Les états passagers (coup reçu, vie basse, voile, chez soi, lancer, renaissance,
## transition de tenue) sont dessinés ici, par-dessus.
##
## L'ancien héros (rond, capuche de feuillage, graine-lanterne) reste dessinable avec `legacy` (planches
## avant/après).
class_name HeroArt
extends RefCounted

const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const HeroBake = preload("res://scripts/hero_bake.gd")
const HeroLook = preload("res://scripts/hero_look.gd")

## Pose par défaut (voir draw) : chaque clé peut manquer.
const POSE := {
	"t": 0.0,          ## temps (s) : respiration, cape, lucioles
	"walk": 0.0,       ## 0 immobile → 1 pleine marche
	"step": 0.0,       ## phase du pas (radians), avance avec la distance parcourue
	"move": Vector2.ZERO,   ## direction du déplacement (la cape flotte à l'opposé)
	"squash": Vector2.ONE,  ## écrasement / étirement (Anim.squash)
	"hurt": 0.0,       ## éclair d'un coup reçu (1 → 0)
	"cast": 0.0,       ## lancer de compétence : la lanterne s'embrase (1 → 0)
	"cast_col": Color(0, 0, 0, 0),   ## couleur de l'élément lancé (sève par défaut)
	"shoot": 0.0,      ## tir de graine : petit recul et éclat de la lanterne (1 → 0)
	"low": 0.0,        ## vie basse : 0 → 1 (battement rouge)
	"invuln": 0.0,     ## invulnérable : voile de sève (0 → 1)
	"home": false,     ## « se battre chez soi » : mousse et lueurs aux pieds
	"wither": 0.0,     ## mort : 0 vivant → 1 flétri, effondré
	"appear": 1.0,     ## renaissance : 0 (graine en terre) → 1 (debout)
	"dash": 0.0,       ## esquive : 1 → 0 (corps étiré dans le sens de l'élan)
	"a": -1.0,         ## attaque de base : 0 → 1 (préparation, coup, retour), < 0 au repos
	"morph": 0.0,      ## changement de tenue : 1 → 0 (l'ancienne s'efface, la nouvelle éclot)
	"side": 0.0,       ## côté regardé (1 droite, -1 gauche) ; 0 : selon facing (player.gd y met de l'hystérésis)
}


## Repère de base des dessins (identité en jeu). La galerie le change pour dessiner en grand :
## HeroArt compose ses propres écrasements avec lui au lieu de l'écraser.
static var base := Transform2D.IDENTITY
## Ancien dessin (planches avant/après).
static var legacy := false
## Atlas cuits de l'apparence en cours ({corps, bras}, hero_bake.gd) et de la précédente pendant une
## transition : posés par player.gd. Vides : dessin direct.
static var sprites := {}
static var prev_sprites := {}


## Valeur d'une clé de pose, ou sa valeur par défaut.
static func _g(st: Dictionary, k: String):
	return st.get(k, POSE[k])


## Dessine le héros centré en p, rayon r (14 en jeu), tourné vers facing (radians).
## st : pose (voir POSE), plus « apparence » ({voie, evol, forme, mods}, hero_look.gd) pour un dessin
## direct d'une apparence donnée. ci : le CanvasItem qui dessine (depuis son _draw).
static func draw(ci: CanvasItem, p: Vector2, r: float, facing: float, st := {}) -> void:
	if legacy:
		draw_legacy(ci, p, r, facing, st)
		return
	var appear: float = clampf(_g(st, "appear"), 0.0, 1.0)
	ci.draw_set_transform_matrix(base)
	if appear < 1.0:
		_draw_rebirth(ci, p, r, facing, st, appear)
		ci.draw_set_transform_matrix(base)
		return
	var t: float = _g(st, "t")
	var feet := p + Vector2(0, r)
	var sk := r / 14.0
	var wither: float = clampf(_g(st, "wither"), 0.0, 1.0)
	var dash: float = _g(st, "dash")
	var sq: Vector2 = _g(st, "squash")
	if dash > 0.0:
		sq *= Vector2(1.0 + 0.22 * dash, 1.0 - 0.14 * dash)
	if wither > 0.0:
		sq *= Vector2(1.0 + 0.25 * wither, 1.0 - 0.45 * Anim.ease_in(wither))
	var sgn: float = _g(st, "side")
	if sgn == 0.0:
		sgn = 1.0 if cos(facing) >= 0.0 else -1.0
	# Penché dans l'élan de l'esquive.
	var lean := 0.25 * dash * sgn
	var xf := base * Transform2D(lean, sq * sk, 0.0, feet)
	var mod := Color(1, 1, 1, 1.0 - 0.55 * wither)
	if wither > 0.0:
		mod = Color(Color(0.78, 0.74, 0.68).lerp(Color.WHITE, 1.0 - wither), mod.a)
	var sp: Dictionary = sprites
	var look: Dictionary = st.get("apparence", {})
	var morph: float = _g(st, "morph")
	var direct := st.has("apparence") or sp.is_empty()
	if direct:
		_draw_direct(ci, xf, sgn, facing, st, look)
	else:
		look = sp["corps"].look
		if morph > 0.0 and not prev_sprites.is_empty():
			# L'ancienne tenue s'efface et se dilate, la nouvelle éclot (sans pause ni texte).
			var g := 1.0 + 0.15 * (1.0 - morph)
			_draw_sprites(ci, xf * Transform2D(0.0, Vector2(g, g), 0.0, Vector2.ZERO), prev_sprites, sgn, facing, st, Color(mod, mod.a * morph))
			var s2 := maxf(Anim.pop(1.0 - morph), 0.05)
			_draw_sprites(ci, xf * Transform2D(0.0, Vector2(s2, s2), 0.0, Vector2.ZERO), sp, sgn, facing, st, Color(mod, mod.a * (1.0 - morph * 0.6)))
		else:
			_draw_sprites(ci, xf, sp, sgn, facing, st, mod)
	ci.draw_set_transform_matrix(base)
	_draw_states(ci, feet, r, sgn, facing, st, look)


## Hauteur du dessin (px du jeu pour 100 unités) et facteur d'échelle de son repère.
static func _evol(look: Dictionary) -> float:
	return float(look.get("evol", 0.0))


## Dessin direct de l'Esprit (galeries, tests, avant la première cuisson) : coûteux, jamais en jeu.
static func _draw_direct(ci: CanvasItem, xf: Transform2D, sgn: float, facing: float, st: Dictionary, look: Dictionary) -> void:
	var o := look.duplicate()
	o["t"] = _g(st, "t")
	o["walk"] = _g(st, "step")
	o["moving"] = clampf(_g(st, "walk"), 0.0, 1.0)
	o["look"] = 0.0 if sgn > 0.0 else PI
	o["hit"] = _g(st, "hurt")
	o["cast"] = _g(st, "cast")
	o["a"] = _g(st, "a")
	o["vise"] = _vise(facing, sgn)
	o["vol"] = false
	ci.draw_set_transform_matrix(xf)
	Esprit.draw(ci, Vector2.ZERO, HeroBake.h_for(_evol(look)), o)
	Ink.flash = 0.0


## Inclinaison du bras vers la visée, dans le repère du dessin (vers le bas : positive).
static func _vise(facing: float, sgn: float) -> float:
	var la := angle_difference(0.0, facing) if sgn > 0.0 else -angle_difference(PI, facing)
	return clampf(la, -0.9, 0.9)


## Corps puis bras cuits. xf : pieds à l'origine, pixels du jeu (r = 14).
static func _draw_sprites(ci: CanvasItem, xf: Transform2D, sp: Dictionary, sgn: float, facing: float, st: Dictionary, mod: Color) -> void:
	var ab = sp["corps"]
	var aa = sp["bras"]
	var t: float = _g(st, "t")
	var walking: bool = _g(st, "walk") > 0.3
	var anim := "walk" if walking else "idle"
	var u: float = fposmod(_g(st, "step"), TAU) / TAU if walking else fposmod(t, HeroBake.IDLE_LOOP) / HeroBake.IDLE_LOOP
	var fx := xf * Transform2D(0.0, Vector2(sgn, 1.0), 0.0, Vector2.ZERO)
	ab.draw(ci, ab.frame(anim, u), fx, mod)
	# Le bras : rebond et penché du pas, puis rotation autour de l'épaule vers la visée.
	var an: Dictionary = aa.anchors
	var fs: float = aa.fs
	var shoulder: Vector2 = an["shoulder"] * fs
	var v := _vise(facing, sgn)
	var arm := fx * Transform2D(0.06 if walking else 0.0, Vector2(0, HeroBake.bob(anim, u) * fs))
	arm = arm * Transform2D(v, shoulder - shoulder.rotated(v))
	var a: float = _g(st, "a")
	var i: int = aa.frame("attack", a, false) if a >= 0.0 else aa.frame("idle", fposmod(t, HeroBake.ARM_LOOP) / HeroBake.ARM_LOOP)
	aa.draw(ci, i, arm, mod)


## États passagers par-dessus le dessin : lancer, coup reçu, vie basse, voile, chez soi, transition.
static func _draw_states(ci: CanvasItem, feet: Vector2, r: float, sgn: float, facing: float, st: Dictionary, look: Dictionary) -> void:
	var t: float = _g(st, "t")
	var wither: float = clampf(_g(st, "wither"), 0.0, 1.0)
	var an := Esprit.anchors(look)
	var fs: float = HeroBake.h_for(_evol(look), r) * float(an["scale"]) / 100.0
	var core: Vector2 = feet + Vector2(an["core"].x * sgn, an["core"].y) * fs
	var mask: Vector2 = feet + Vector2(an["mask"].x * sgn, an["mask"].y) * fs
	if _g(st, "home") and wither == 0.0:
		_draw_home(ci, feet - Vector2(0, r * 0.95), r, t)
	var cast: float = _g(st, "cast")
	if cast > 0.0 and wither < 0.5:
		var cc: Color = _g(st, "cast_col")
		var col := Art.ec("seve") if cc.a == 0.0 else cc
		Ink.halo(ci, mask, r * (0.9 + 0.6 * cast), col, 1.6 * cast)
		var sh: Vector2 = feet + Vector2(an["shoulder"].x * sgn, an["shoulder"].y) * fs
		var hand := sh + Vector2.from_angle(facing) * r * 0.9
		for i in 5:
			var a: float = facing + (i - 2) * 0.35
			ci.draw_line(hand + Vector2.from_angle(a) * r * 0.45, hand + Vector2.from_angle(a) * r * (0.85 + 0.5 * cast), Color(col.lightened(0.2), 0.85 * cast), maxf(r * 0.07, 1.0), true)
	var hurt: float = _g(st, "hurt")
	if hurt > 0.0:
		ci.draw_arc(core, r * (1.1 + 0.6 * (1.0 - hurt)), 0, TAU, 32, Color(Art.c("danger"), 0.9 * hurt), maxf(r * 0.1, 1.5), true)
	var low: float = _g(st, "low")
	if low > 0.0 and wither == 0.0:
		# Battement de cœur : deux pulsations rapprochées, puis un silence.
		var beat := fposmod(t * 1.3, 1.0)
		var pulse := maxf(Anim.flash(beat / 0.18), 0.7 * Anim.flash((beat - 0.22) / 0.18) if beat > 0.22 else 0.0)
		ci.draw_arc(core, r * (1.35 + 0.25 * pulse), 0, TAU, 32, Color(Art.c("danger"), (0.25 + 0.55 * pulse) * low), maxf(r * 0.1, 1.5), true)
		Ink.halo(ci, core, r * 0.5 * (1.0 + 0.3 * pulse), Art.c("danger"), low * pulse)
	var inv: float = _g(st, "invuln")
	if inv > 0.0:
		_draw_shield(ci, core, r, t, inv)
	var morph: float = _g(st, "morph")
	if morph > 0.0:
		# Changement de tenue : un anneau de sève qui s'ouvre et des feuilles de la nouvelle branche.
		var u := 1.0 - morph
		var acc := Esprit.K.accent(_dominant(look))
		ci.draw_arc(core, r * (0.8 + 2.4 * Anim.ease_out(u)), 0, TAU, 40, Color(Art.ec("seve", "clair"), 0.8 * morph), maxf(r * 0.1, 1.4), true)
		for i in 8:
			var a := i * TAU / 8.0 + t * 0.6
			var q := core + Vector2.from_angle(a) * r * (0.6 + 2.0 * u) + Vector2(0, r * 0.6 * u * u)
			ci.draw_colored_polygon(leaf_pts(q, r * 0.2, a + u * 4.0), Color(acc if i % 2 == 0 else Art.ec("seve", "clair"), morph))


## Centre du masque (la tête) du héros dessiné en p, rayon r, tourné vers facing.
static func head_at(p: Vector2, r: float, facing: float) -> Vector2:
	var look: Dictionary = sprites["corps"].look if not sprites.is_empty() else {}
	if legacy:
		return p + Vector2(0, -r * 1.6)
	var an := Esprit.anchors(look)
	var fs: float = HeroBake.h_for(_evol(look), r) * float(an["scale"]) / 100.0
	var sgn := 1.0 if cos(facing) >= 0.0 else -1.0
	return p + Vector2(0, r) + Vector2(an["mask"].x * sgn, an["mask"].y) * fs


static func _dominant(look: Dictionary) -> String:
	var w := Esprit.weights(look)
	var dom := "aucun"
	var best := 0.0
	for b in w:
		if w[b] > best:
			best = w[b]
			dom = b
	return dom


## Ancien héros (avant la refonte) : planches avant/après.
static func draw_legacy(ci: CanvasItem, p: Vector2, r: float, facing: float, st := {}) -> void:
	var t: float = _g(st, "t")
	var appear: float = clampf(_g(st, "appear"), 0.0, 1.0)
	ci.draw_set_transform_matrix(base)
	if appear < 1.0:
		_draw_rebirth(ci, p, r, facing, st, appear)
		return
	var wither: float = clampf(_g(st, "wither"), 0.0, 1.0)
	var walk: float = clampf(_g(st, "walk"), 0.0, 1.0)
	var step: float = _g(st, "step")
	var d := Vector2.from_angle(facing)
	var n := d.orthogonal()
	var hurt: float = _g(st, "hurt")
	var low: float = _g(st, "low")
	# Rebond de la marche (deux appuis par cycle) et respiration du repos.
	var bob := -absf(sin(step)) * r * 0.16 * walk
	var breath := Anim.breathe(t, 0.035 * (1.0 - walk))
	var sq: Vector2 = _g(st, "squash") * breath
	var dash: float = _g(st, "dash")
	if dash > 0.0:
		# Étiré dans le sens de l'élan (l'axe x du dessin pivote vers facing, voir plus bas).
		sq *= Vector2(1.0 + 0.25 * dash, 1.0 - 0.18 * dash)
	if wither > 0.0:
		sq *= Vector2(1.0 + 0.25 * wither, 1.0 - 0.45 * Anim.ease_in(wither))
	# Halo de sève au sol : on retrouve le héros d'un coup d'œil dans la mêlée (il est vivant).
	if wither == 0.0:
		var hb := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
		ci.draw_circle(p, r * 2.5, Color(Art.ec("seve"), 0.05 + 0.02 * hb))
		ci.draw_circle(p, r * 1.7, Color(Art.ec("seve"), 0.06))
	# Ombre au sol : ne monte pas avec le rebond.
	if wither < 1.0:
		Art.shadow(ci, p, r * 1.1 * (1.0 - 0.15 * absf(bob) / r))
	if _g(st, "home") and wither == 0.0:
		_draw_home(ci, p, r, t)
	# Pieds-racines : deux petits ovales sous le corps, qui avancent tour à tour quand il marche.
	var mv: Vector2 = _g(st, "move")
	var stride := d if mv.length() < 0.1 else mv.normalized()
	var foot_col := Art.ec("racine").lerp(Art.c("decor"), wither)
	for sgn: int in [-1, 1]:
		var fwd := sin(step + (0.0 if sgn < 0 else PI)) * r * 0.4 * walk
		var fp: Vector2 = p + Vector2(sgn * r * 0.5, r * 0.92) + stride * fwd - Vector2(0, absf(fwd) * 0.3)
		var foot := Art.ellipse(fp, r * 0.3, r * 0.22, 12)
		ci.draw_colored_polygon(foot, foot_col)
		ci.draw_arc(fp + Vector2(0, -r * 0.03), r * 0.2, PI * 1.15, PI * 1.85, 6, foot_col.lightened(0.3), maxf(r * 0.05, 0.8), true)
		Art.outline(ci, foot, Art.c("contour"), maxf(r * 0.05, 1.0))
	var body_p := p + Vector2(0, bob)
	# Tout le haut du corps est écrasé ou étiré autour de son centre, dans l'axe de la visée
	# quand il esquive, à l'écran sinon (la lumière de la charte reste en haut à gauche).
	var rot := facing if dash > 0.0 else 0.0
	ci.draw_set_transform_matrix(base * Transform2D(rot, sq, 0.0, body_p))
	var lp := Vector2.ZERO
	var f := facing - rot
	_draw_cape(ci, lp, r, f, t, walk, mv.rotated(-rot), wither)
	_draw_body(ci, lp, r, f, t, wither, low)
	_draw_hood(ci, lp, r, f, wither)
	if wither < 0.6:
		_draw_face(ci, lp, r, f, hurt, wither)
	ci.draw_set_transform_matrix(base)
	if wither < 0.5:
		_draw_lantern(ci, body_p, r, facing, st, 1.0 - wither * 2.0)
	if hurt > 0.0:
		ci.draw_circle(body_p, r * 1.02, Color(Art.c("danger_eclair"), 0.7 * hurt))
		ci.draw_arc(body_p, r * (1.1 + 0.6 * (1.0 - hurt)), 0, TAU, 32, Color(Art.c("danger"), 0.9 * hurt), maxf(r * 0.1, 1.5), true)
	if low > 0.0 and wither == 0.0:
		# Battement de cœur : deux pulsations rapprochées, puis un silence.
		var beat := fposmod(t * 1.3, 1.0)
		var pulse := maxf(Anim.flash(beat / 0.18), 0.7 * Anim.flash((beat - 0.22) / 0.18) if beat > 0.22 else 0.0)
		ci.draw_arc(body_p, r * (1.35 + 0.25 * pulse), 0, TAU, 32, Color(Art.c("danger"), (0.25 + 0.55 * pulse) * low), maxf(r * 0.1, 1.5), true)
	var inv: float = _g(st, "invuln")
	if inv > 0.0:
		_draw_shield(ci, body_p, r, t, inv)


## Cape : trois feuilles nervurées dans le dos, qui flottent à l'opposé de la marche.
static func _draw_cape(ci: CanvasItem, p: Vector2, r: float, facing: float, t: float, walk: float, mv: Vector2, wither: float) -> void:
	var leaf_col := Art.c("joueur_accent").darkened(0.3).lerp(Art.c("decor").lightened(0.15), wither)
	var back := facing + PI
	if mv.length() > 0.1 and walk > 0.0:
		# La cape traîne derrière le mouvement, pas derrière le regard.
		back = lerp_angle(back, mv.angle() + PI, 0.6 * walk)
	for side: int in [-1, 0, 1]:
		var sway := 0.09 * sin(t * TAU / Anim.DUREE["respiration"] * 2.0 + side * 1.1) + 0.12 * walk * sin(t * 9.0 + side)
		var a: float = back + side * (0.62 + 0.12 * walk) + sway
		var droop := wither * 0.6
		var c := p + Vector2.from_angle(a) * r * (1.05 if side == 0 else 0.95) + Vector2(0, r * droop * 0.4)
		var lf := leaf_pts(c, r * (0.78 if side == 0 else 0.66) * (1.0 + 0.08 * walk), a + droop * side)
		Art.volume(ci, lf, leaf_col.darkened(0.08 * absf(side)), 0.6)
		ci.draw_line(c - Vector2.from_angle(a) * r * 0.5, c + Vector2.from_angle(a) * r * 0.55, leaf_col.darkened(0.45), maxf(r * 0.05, 1.0), true)
		# Deux nervures secondaires sur la feuille du milieu.
		if side == 0 and r >= 12.0:
			for k: float in [-0.15, 0.2]:
				var q := c + Vector2.from_angle(a) * r * k
				ci.draw_line(q, q + Vector2.from_angle(a + 0.8) * r * 0.25, leaf_col.darkened(0.4), maxf(r * 0.03, 0.7), true)
				ci.draw_line(q, q + Vector2.from_angle(a - 0.8) * r * 0.25, leaf_col.darkened(0.4), maxf(r * 0.03, 0.7), true)
		Art.outline(ci, lf, Art.c("contour"), maxf(r * 0.06, 1.2))


static func _draw_body(ci: CanvasItem, p: Vector2, r: float, _facing: float, _t: float, wither: float, low: float) -> void:
	var col := Art.c("joueur").lerp(Art.c("brume"), wither * 0.8)
	if low > 0.0:
		col = col.lerp(Art.ec("saignement", "clair"), 0.12 * low)
	Art.volume_circle(ci, p, r, col)
	ci.draw_arc(p, r, 0, TAU, 32, Art.c("contour"), maxf(r * 0.12, Art.TRAIT_FIN), true)


## Capuche de feuillage : un croissant qui couvre l'arrière du crâne, avec sa pousse au sommet.
static func _draw_hood(ci: CanvasItem, p: Vector2, r: float, facing: float, wither: float) -> void:
	var d := Vector2.from_angle(facing)
	var n := d.orthogonal()
	var hood := PackedVector2Array()
	for i in 17:
		var a: float = facing + PI / 2.0 + 0.25 + i * (PI - 0.5) / 16.0
		hood.append(p + Vector2.from_angle(a) * r * 1.04)
	for i in range(16, -1, -1):
		var a: float = facing + PI / 2.0 + 0.25 + i * (PI - 0.5) / 16.0
		hood.append(p - d * r * 0.12 + Vector2.from_angle(a) * r * 0.62)
	var col := Art.c("accent").darkened(0.15).lerp(Art.c("decor").lightened(0.1), wither)
	Art.volume(ci, hood, col, 0.7)
	for i in 4:
		var a: float = facing + PI / 2.0 + 0.6 + i * 0.62
		ci.draw_line(p + Vector2.from_angle(a) * r * 0.66, p + Vector2.from_angle(a) * r * 0.98, col.darkened(0.45), maxf(r * 0.045, 0.8), true)
	Art.outline(ci, hood, Art.c("contour"), maxf(r * 0.06, 1.2))
	if wither < 0.8:
		var sprout := leaf_pts(p - d * r * 0.55 - n * r * 0.1, r * 0.32 * (1.0 - wither), facing + PI + 0.5 + wither)
		Art.volume(ci, sprout, Art.c("accent").lerp(Art.c("decor"), wither), 0.8)
		Art.outline(ci, sprout, Art.c("contour"), maxf(r * 0.04, 1.0))


## Visage : deux yeux tournés vers la visée (fermés sous le coup), une petite bouche.
static func _draw_face(ci: CanvasItem, p: Vector2, r: float, facing: float, hurt: float, wither: float) -> void:
	var d := Vector2.from_angle(facing)
	var n := d.orthogonal()
	for sgn: int in [-1, 1]:
		var e := p + d * r * 0.5 + n * sgn * r * 0.26
		if hurt > 0.3 or wither > 0.0:
			# Yeux plissés : deux petits traits.
			ci.draw_line(e - n * r * 0.09, e + n * r * 0.09, Art.c("contour"), maxf(r * 0.07, 1.0), true)
		else:
			ci.draw_circle(e, r * 0.1, Art.c("contour"))
			ci.draw_circle(e + Vector2(-r * 0.03, -r * 0.03), r * 0.035, Color.WHITE)
	ci.draw_arc(p + d * r * 0.62, r * 0.12, facing - 0.9, facing + 0.9, 8, Art.c("contour").lightened(0.2), maxf(r * 0.04, 0.8), true)


## Graine-lanterne devant le héros : lueur qui respire, lucioles, éclat au tir et au lancer.
static func _draw_lantern(ci: CanvasItem, p: Vector2, r: float, facing: float, st: Dictionary, k: float) -> void:
	var t: float = _g(st, "t")
	var cast: float = _g(st, "cast")
	var shoot: float = _g(st, "shoot")
	var low: float = _g(st, "low")
	var d := Vector2.from_angle(facing)
	var recoil := -d * r * 0.18 * shoot
	var seed_p := p + d * r * (1.4 + 0.25 * Anim.ease_out(cast)) + recoil
	var cc: Color = _g(st, "cast_col")
	var elem_col := Art.ec("seve") if cc.a == 0.0 else cc
	# Vie basse : la lanterne vacille.
	var flicker := 1.0 - 0.35 * low * (0.5 + 0.5 * sin(t * 23.0) * sin(t * 7.0))
	var gr := r * (0.75 + 0.55 * cast + 0.25 * shoot) * (1.0 + 0.08 * sin(t * TAU / Anim.DUREE["respiration"] * 2.0)) * flicker
	ci.draw_circle(seed_p, gr, Color(elem_col, 0.08 * k))
	ci.draw_circle(seed_p, gr * 0.7, Color(elem_col, 0.14 * k))
	ci.draw_circle(seed_p, gr * 0.42, Color(elem_col, 0.3 * k))
	# Lucioles qui tournent autour.
	for i in 3:
		var m := seed_p + Vector2.from_angle(t * 2.6 + i * TAU / 3.0) * r * (0.6 + 0.08 * sin(t * 5.0 + i))
		ci.draw_circle(m, maxf(r * 0.05, 0.8), Color(Art.ec("seve", "clair"), (0.5 + 0.4 * sin(t * 4.0 + i * 2.0)) * k))
	ci.draw_colored_polygon(Art.ellipse(seed_p, r * 0.3, r * 0.22, 14), Color(Art.ec("seve", "sombre").lightened(0.2), k))
	ci.draw_circle(seed_p + Vector2(-r * 0.06, -r * 0.06), r * 0.13, Color(Art.ec("seve", "clair").lerp(elem_col, 0.4 * cast), k))
	if cast > 0.0:
		# Rayons de l'élément lancé, en éventail vers la visée.
		for i in 5:
			var a: float = facing + (i - 2) * 0.35
			var l0 := r * 0.55
			var l1 := r * (0.95 + 0.5 * cast)
			ci.draw_line(seed_p + Vector2.from_angle(a) * l0, seed_p + Vector2.from_angle(a) * l1, Color(elem_col.lightened(0.2), 0.85 * cast * k), maxf(r * 0.07, 1.0), true)


## Voile de sève quand il est invulnérable : un anneau de feuilles translucides qui tourne.
static func _draw_shield(ci: CanvasItem, p: Vector2, r: float, t: float, k: float) -> void:
	var col := Art.ec("seve")
	ci.draw_arc(p, r * 1.55, 0, TAU, 40, Color(col, 0.22 * k), maxf(r * 0.08, 1.2), true)
	for i in 6:
		var a := t * 1.8 + i * TAU / 6.0
		var q := p + Vector2.from_angle(a) * r * 1.55
		ci.draw_colored_polygon(leaf_pts(q, r * 0.22, a + PI / 2.0), Color(Art.ec("seve", "clair"), 0.55 * k))


## « Chez soi » : un tapis de mousse sous les pieds et des lueurs de sève qui montent.
static func _draw_home(ci: CanvasItem, p: Vector2, r: float, t: float) -> void:
	var col := Art.ec("racine", "clair")
	ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, r * 0.6), r * 1.5, r * 0.55, 18), Color(col, 0.22))
	for i in 5:
		var a := i * TAU / 5.0 + 0.4
		var q := p + Vector2(cos(a) * r * 1.3, r * 0.6 + sin(a) * r * 0.45)
		for j in 3:
			ci.draw_line(q, q + Vector2((j - 1) * r * 0.12, -r * 0.3), Color(col, 0.8), maxf(r * 0.06, 1.0), true)
	for i in 3:
		var k := fposmod(t * 0.6 + i / 3.0, 1.0)
		var q := p + Vector2(sin(i * 2.3 + t) * r * 1.1, r * 0.4 - k * r * 2.2)
		ci.draw_circle(q, r * 0.09 * (1.0 - k * 0.5), Color(Art.ec("seve", "clair"), 0.8 * (1.0 - k)))


## Renaissance : une pousse sort de terre, s'ouvre, et le héros s'en déploie (appear 0 → 1).
static func _draw_rebirth(ci: CanvasItem, p: Vector2, r: float, facing: float, st: Dictionary, k: float) -> void:
	var t: float = _g(st, "t")
	var seve := Art.ec("seve")
	Art.glow(ci, p, r * (1.2 + 1.6 * k), "seve")
	ci.draw_arc(p, r * (0.6 + 2.6 * Anim.ease_out(k)), 0, TAU, 40, Color(Art.ec("seve", "clair"), 0.8 * (1.0 - k)), maxf(r * 0.12, 1.5), true)
	if k < 0.45:
		# La pousse : une tige et deux cotylédons qui s'ouvrent.
		var g := Anim.ease_out(k / 0.45)
		var top := p + Vector2(0, r * 0.5 - r * 1.1 * g)
		ci.draw_line(p + Vector2(0, r * 0.5), top, Art.c("accent").darkened(0.2), maxf(r * 0.12, 1.5), true)
		for sgn: int in [-1, 1]:
			ci.draw_colored_polygon(leaf_pts(top + Vector2(sgn * r * 0.3 * g, 0), r * 0.35 * g, PI / 2.0 + PI / 2.0 * sgn - sgn * 0.5 * g), Art.c("accent"))
		ci.draw_circle(top, r * 0.16, Art.ec("seve", "clair"))
		return
	var u := (k - 0.45) / 0.55
	var s := Anim.pop(u)
	var st2 := st.duplicate()
	st2["appear"] = 1.0
	st2["squash"] = Vector2.ONE * maxf(s, 0.05)
	draw(ci, p, r, facing, st2)
	# Pétales de sève qui retombent autour.
	for i in 6:
		var a := i * TAU / 6.0 + t * 0.5
		var q := p + Vector2.from_angle(a) * r * (1.0 + 1.6 * u) + Vector2(0, r * 0.8 * u * u)
		ci.draw_colored_polygon(leaf_pts(q, r * 0.18, a + u * 3.0), Color(seve, 1.0 - u))


## Feuille en amande (même forme que celle de la charte), pointe dans la direction a.
static func leaf_pts(p: Vector2, l: float, a: float) -> PackedVector2Array:
	var d := Vector2.from_angle(a)
	var n := d.orthogonal()
	var pts := PackedVector2Array()
	for i in 9:
		var k := i / 8.0
		pts.append(p + d * l * (2.0 * k - 1.0) + n * l * 0.5 * sin(k * PI))
	for i in range(7, 0, -1):
		var k := i / 8.0
		pts.append(p + d * l * (2.0 * k - 1.0) - n * l * 0.5 * sin(k * PI))
	return pts


## Silhouette du héros d'une seule couleur (images rémanentes de l'esquive) : les cases « mono » des
## atlas cuits (corps et bras), teintées ; sans atlas, l'ancienne silhouette (trois feuilles, deux formes).
static func draw_ghost(ci: CanvasItem, p: Vector2, r: float, facing: float, col: Color) -> void:
	if not legacy and not sprites.is_empty():
		var sgn := 1.0 if cos(facing) >= 0.0 else -1.0
		var xf := base * Transform2D(0.0, Vector2(sgn, 1.0) * r / 14.0, 0.0, p + Vector2(0, r))
		var ab = sprites["corps"]
		var aa = sprites["bras"]
		ab.draw(ci, ab.frame("mono", 0.0), xf, col)
		aa.draw(ci, aa.frame("mono", 0.0), xf, col)
		ci.draw_set_transform_matrix(base)
		return
	_draw_ghost_legacy(ci, p, r, facing, col)


static func _draw_ghost_legacy(ci: CanvasItem, p: Vector2, r: float, facing: float, col: Color) -> void:
	var back := facing + PI
	for side: int in [-1, 0, 1]:
		var a: float = back + side * 0.62
		var c := p + Vector2.from_angle(a) * r * (1.05 if side == 0 else 0.95)
		ci.draw_colored_polygon(leaf_pts(c, r * (0.78 if side == 0 else 0.66), a), col)
	ci.draw_circle(p, r, col)
	var d := Vector2.from_angle(facing)
	ci.draw_colored_polygon(leaf_pts(p - d * r * 0.55, r * 0.32, facing + PI + 0.5), col)
	# Pieds-racines : deux petites ombres.
	for sgn: int in [-1, 1]:
		ci.draw_circle(p + Vector2(sgn * r * 0.5, r * 0.92), r * 0.25, col)
