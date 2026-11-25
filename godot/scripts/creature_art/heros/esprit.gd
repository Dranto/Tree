## Porte-Graine, piste A retenue : « Esprit masqué ». Un petit esprit de la forêt sous un masque de
## bois clair aux yeux de lumière. Le corps et le masque restent les mêmes du début à la fin ; ce qui
## change, c'est la TENUE (selon les branches prises, mélangées dans un build hybride) et l'ARME
## (selon la forme d'attaque et les modifications d'attaque prises, voir arme.gd).
##
## Tenue, par branche (la force de chaque trait = part de la branche × progression) :
##   Ronce  : cape vert sombre à ourlet en épines, liane de ronce et baies, épaulière d'épines, couronne
##            d'épines sur la capuche.
##   Sève   : cape à ourlet en pétales, veines lumineuses, traîne de pétales translucides, collerette de
##            pétales, bois à pointes lumineuses.
##   Racine : cape lourde d'écorce et de mousse, racines qui pendent, épaulière d'écorce, racines
##            enroulées aux jambes.
##   Vent   : cape de plumes en rangs, double écharpe, mantelet de plumes, plumes sur la capuche.
##   Spore  : chapeau-champignon à pois sur la capuche, cape à lamelles et pois, fils de mycélium.
##   Aube   : ailes de phalène dans le dos, auréole derrière la tête, éclats de verre aux épaules,
##            liseré doré.
##
## Pose : t, walk, moving, look, hit, cast ; voie {branche: poids} ou build ; evol (0 → 1) ou stade ;
## forme (data/attack.json › forms) ; mods (liste de data/attack.json › mods).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const K = preload("res://scripts/creature_art/heros/commun.gd")
const Arme = preload("res://scripts/creature_art/heros/arme.gd")
const Sylve = preload("res://scripts/creature_art/heros/sylve.gd")

const HEIGHT := 56.0
const BRANCHES := ["ronce", "seve", "racine", "vent", "spore", "aube"]
## Forme d'attaque de la branche, quand la pose n'en donne pas.
const FORME_DE := {"ronce": "fouet", "seve": "perle", "racine": "massue", "vent": "lame", "spore": "spore_lobee", "aube": "rayon"}
const BARK := {"clair": Color("a27c56"), "ombre": Color("5e4430"), "reflet": Color("d8b88a")}
const BONE := {"clair": Color("e6d2a8"), "ombre": Color("a8946a")}


static func weights(o: Dictionary) -> Dictionary:
	var w: Dictionary = {}
	if o.has("voie"):
		w = o["voie"]
	elif o.get("build", "aucun") != "aucun":
		w = {o["build"]: 1.0}
	var tot := 0.0
	for b in w:
		tot += float(w[b])
	var out := {}
	for b in BRANCHES:
		out[b] = float(w.get(b, 0.0)) / tot if tot > 0.0 else 0.0
	return out


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var look: float = o.get("look", 0.0)
	var cast: float = o.get("cast", 0.0)
	var p := K.progress(o)
	var w := weights(o)
	var dom := "aucun"
	var sec := ""
	var best := 0.0
	for b in BRANCHES:
		if w[b] > best:
			best = w[b]
			dom = b
	for b in BRANCHES:
		if b != dom and w[b] >= 0.25 and (sec == "" or w[b] > w[sec]):
			sec = b
	var s := {}
	for b in BRANCHES:
		s[b] = w[b] * p
	var flip := cos(look) < 0.0
	# Couches (cuisson en jeu, hero_bake.gd) : « corps » sans le bras ni l'arme, « bras » le bras et
	# l'arme seuls, dans le repère immobile du corps (le moteur y rejoue le rebond et la visée).
	var couche: String = o.get("couche", "")
	var corps := couche != "bras"
	var bras := couche != "corps"
	Ink.flash = o.get("hit", 0.0)
	var base := Ink.frame(feet, h * (0.62 + 0.38 * p), flip)
	var u := absf(base.get_scale().y)
	var acc := K.accent(dom)
	var acc2 := K.accent(sec) if sec != "" else acc
	var gl := K.glow(dom)
	var lv := K.leaves(dom)
	var dark := {"clair": lv["ombre"], "ombre": lv["ombre"].darkened(0.35), "reflet": lv["clair"]}
	if corps:
		K.aura(ci, base, t, p, acc)
		Ink.ground_shadow(ci, base, Vector2.ZERO, 18.0 + 8.0 * p)
	var bob := sin(t * TAU / 2.4) * 1.2 - absf(sin(walk)) * 3.0 * mv
	if couche == "bras":
		bob = 0.0
		mv = 0.0
	var xf := base * Transform2D(0.06 * mv, Vector2.ONE, 0.0, Vector2(0, bob))
	var legl := 10.0 + 14.0 * p
	var ch := 30.0 + 26.0 * p
	var top := -legl - ch
	var rm := 17.0 - 2.0 * p
	var mc := Vector2(3.0, top - rm * 0.55)
	var sway := sin(t * 1.7)
	var sh: float = 9.0 + 5.0 * p + 3.0 * s["racine"]
	var hem: float = 15.0 + 12.0 * p + 4.0 * s["racine"]
	if corps:
		# --- Derrière ---
		if s["aube"] > 0.1:
			_wings(ci, xf, Vector2(-2, top + 8.0), s["aube"], t)
		if s["seve"] > 0.1:
			for j in 3:
				var a := PI * (0.62 + j * 0.06) + 0.06 * sin(t * 1.5 + j)
				K.leaf(ci, xf, Vector2(-4, top + 10.0), a, (16.0 + 30.0 * s["seve"]) * (1.0 - j * 0.18), 9.0, {"clair": Color(Art.ec("seve", "clair"), 0.8), "ombre": Color(Art.ec("seve"), 0.65), "reflet": Color.WHITE}, 0.04, 0.8)
		if s["spore"] > 0.1:
			for j in 5:
				var x: float = -hem * 0.8 + j * 4.0
				Ink.tendril(ci, xf, Vector2(x, -legl + 4.0), PI * 0.5 + 0.2, 6.0 + 10.0 * s["spore"], 1.2, 1.0, Color("e2d0f2"), sin(t * 1.3 + j))
		# Écharpe(s) : couleur de la branche secondaire (un hybride se lit à l'écharpe).
		if p > 0.15:
			var ns := 2 if s["vent"] > 0.3 else 1
			for k2 in ns:
				var sl := (10.0 + 52.0 * p) * (1.0 - k2 * 0.25)
				var sc := PackedVector2Array()
				for i in 9:
					var k := i / 8.0
					sc.append(Vector2(-2.0 - sl * 0.8 * k, top + 4.0 + k2 * 3.0 + sin(k * 4.0 - t * 3.0 + k2) * 4.0 * k + sl * (0.55 - 0.25 * s["vent"]) * k * k))
				Ink.brush(ci, xf, sc, 8.6, Ink.encre(), 1.0, 0.0)
				Ink.brush(ci, xf, sc, 6.4, acc2.lerp(K.CREME, 0.15 + 0.2 * k2), 1.0, 0.0)
				if s["vent"] > 0.3:
					for i in [4, 6, 8]:
						K.leaf(ci, xf, sc[i], PI * 0.75 + 0.3 * sin(t * 2.0 + i), 7.0, 3.4, {"clair": Color("e8f2fa"), "ombre": Color("8fb4e0")}, 0.0, 0.8)
		if p > 0.25:
			Sylve._antler(ci, xf, mc + Vector2(-rm * 0.55, -rm * 0.7), -1.0, p, _tipkind(dom), acc, gl, t, true)
		if s["aube"] > 0.1 and not Ink.mono:
			# Auréole derrière la tête.
			var ring := Ink.oval(mc + Vector2(-3, -2), rm * (1.4 + 0.2 * s["aube"]), rm * (1.4 + 0.2 * s["aube"]), 40)
			ring.append(ring[0])
			ci.draw_polyline(xf * ring, Color(Art.FEUILLES_BUILD["aube"]["accent"], 0.9 * s["aube"]), 2.2 * u, true)
			Ink.halo(ci, xf * (mc + Vector2(-3, -2)), rm * 1.6 * u, Art.ec("lumiere"), 0.6 * s["aube"])
		# Capuche.
		Ink.part(ci, xf, Ink.oval(mc + Vector2(-3.0, -1.0), rm * 1.18, rm * 1.15, 28), dark, 2.0, 1.0, 0.3)
		# Jambes.
		var sw := sin(walk) * 6.0 * mv
		for j in 2:
			var x := (3.0 if j == 0 else -4.0)
			var f := Vector2(x + (sw if j == 0 else -sw), 0)
			var pts := PackedVector2Array([Vector2(x, -legl - 2), Vector2(x + 1.0, -legl * 0.45), f + Vector2(0, -2)])
			Ink.brush(ci, xf, pts, 5.6 + 1.5 * s["racine"], Ink.encre(), 1.0, 1.0)
			Ink.brush(ci, xf, pts, 3.4 + 1.5 * s["racine"], Color("5b4636") if j == 0 else Color("3f3026"), 1.0, 1.0)
			if s["racine"] > 0.2:
				for k in 3:
					var q := Vector2(x + 0.5, -legl * (0.25 + k * 0.22))
					Ink.brush(ci, xf, PackedVector2Array([q + Vector2(-3, -1), q + Vector2(3, 1.5)]), 1.6, Art.ec("racine"), 1.0, 1.0)
			Ink.part(ci, xf, Ink.leaf(f + Vector2(-3, -1.5), 0.0, 9.0, 4.0), {"clair": Color("5b4636"), "ombre": Color("3f3026")}, 1.0, 1.0, 0.0)
		# --- Cape ---
		var cape := _cape(top, legl, sh, hem, p, dom, sway)
		var cpal := {"clair": lv["ombre"].lightened(0.12), "ombre": lv["ombre"].darkened(0.35), "reflet": lv["clair"]}
		Ink.part(ci, xf, cape, cpal, 2.2, 1.0, 0.6)
		var op := PackedVector2Array([Vector2(1.0, top + 5.0), Vector2(5.0, top + 5.0), Vector2(hem * 0.55, -legl + 4.0), Vector2(-hem * 0.1, -legl + 4.0)])
		Ink.part(ci, xf, op, {"clair": K.CREME, "ombre": K.CREME.darkened(0.18), "reflet": Color.WHITE}, 1.0, 1.0, 0.4)
		var hp := PackedVector2Array()
		for i in range(2, cape.size()):
			hp.append(cape[i] + Vector2(0, -3.0))
		Ink.brush(ci, xf, hp, 2.6, acc if dom != "aube" else Art.c("or"), 1.0, 1.0)
		_cape_overlay(ci, xf, top, legl, hem, s, t, cpal)
		# Collerette / épaulières selon la branche.
		_shoulders(ci, xf, Vector2(0, top + 3.0), sh, p, dom, s, lv, dark, t, sway)
		if sec != "" and s[sec] > 0.15:
			_shoulders(ci, xf, Vector2(-2, top + 6.0), sh * 0.8, p * 0.6, sec, s, K.leaves(sec), {"clair": K.leaves(sec)["ombre"], "ombre": K.leaves(sec)["ombre"].darkened(0.3)}, t, sway)
		# Cœur sur la poitrine.
		var core := Vector2(4.0, top + 16.0 + 6.0 * p)
		if p > 0.3:
			var k := (p - 0.3) / 0.7
			if not Ink.mono:
				for i in 5:
					var a := -PI * 0.5 + (i - 2) * 0.7
					var vein := PackedVector2Array([core, core + Vector2.from_angle(a) * 6.0 * k + Vector2(1, 2), core + Vector2.from_angle(a) * 12.0 * k])
					Ink.brush(ci, xf, vein, 1.2, Color(gl, 0.8 * k), 1.0, 0.0)
				Ink.halo(ci, xf * core, 8.0 * u * (0.6 + k), gl, 0.8 + k)
			Ink.part(ci, xf, Ink.oval(core, 2.6 + 1.6 * k, 3.2 + 1.8 * k, 14), {"clair": gl, "ombre": gl.darkened(0.3), "reflet": Color.WHITE}, 1.0, 1.0, 1.0)
		# --- Masque ---
		var mask := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			var d := Vector2(cos(a), sin(a))
			var r := Vector2(rm * 0.86, rm)
			if d.y > 0.0:
				r.x *= 1.0 - 0.35 * d.y * d.y
				r.y *= 1.0 + 0.12 * d.y
			mask.append(mc + d * r)
		Ink.part(ci, xf, mask, {"clair": Color("fbf6e8"), "ombre": Color("d9ccb0"), "reflet": Color.WHITE}, 2.0, 1.0, 1.0)
		Ink.brush(ci, xf, PackedVector2Array([mc + Vector2(rm * 0.38, -rm * 0.25), mc + Vector2(rm * 0.5, rm * 0.25), mc + Vector2(rm * 0.36, rm * 0.36)]), 1.2, Color("c9b99a"), 0.4, 0.4)
		if p > 0.2:
			var k := clampf((p - 0.2) / 0.5, 0.0, 1.0)
			Ink.flat(ci, xf, Ink.leaf(mc + Vector2(rm * 0.08, -rm * 0.95), PI * 0.5, rm * 0.6 * k, 3.0), acc)
			for q: Vector2 in [mc + Vector2(-rm * 0.18, rm * 0.2), mc + Vector2(rm * 0.62, rm * 0.18)]:
				Ink.flat(ci, xf, Ink.leaf(q, PI * 0.5 - 0.1, rm * 0.45 * k, 2.4 * (0.8 if q.x > mc.x + rm * 0.3 else 1.0)), acc2 if q.x > mc.x + rm * 0.3 else acc)
		if p > 0.7:
			var k := (p - 0.7) / 0.3
			for q: Vector2 in [mc + Vector2(-rm * 0.48, -rm * 0.45), mc + Vector2(rm * 0.62, -rm * 0.5)]:
				Ink.flat(ci, xf, Ink.oval(q, 1.4 * k, 1.4 * k, 8), acc)
		K.slit(ci, xf, mc + Vector2(-rm * 0.12, -rm * 0.08), -0.25, 8.0 + 1.0 * p, 4.6, gl, 0.6 + 0.6 * p + cast)
		K.slit(ci, xf, mc + Vector2(rm * 0.52, -rm * 0.1), -0.32, 5.6, 3.6, gl, 0.6 + 0.6 * p + cast)
		# Coiffe selon la branche.
		_headgear(ci, xf, mc, rm, s, dom, lv, t, sway, p)
		if p > 0.25 and s["spore"] < 0.5:
			Sylve._antler(ci, xf, mc + Vector2(rm * 0.35, -rm * 0.8), 1.0, p, _tipkind(dom), acc, gl, t, false)
	if bras:
		# --- Arme : une vraie arme par forme d'attaque, animée par « a » (0 → 1 : une attaque ; < 0 : repos) ---
		var forme: String = o.get("forme", "graine" if dom == "aucun" or p < 0.3 else FORME_DE[dom])
		var mods: Array = o.get("mods", [])
		var a: float = o.get("a", -1.0)
		var sp := Vector2(sh - 3.0, top + 6.0)
		var hand := Arme.pose(forme, sp, top, p, a, t)
		var c := {"p": p, "t": t, "u": u, "acc": acc, "gl": gl, "lv": lv, "a": a, "vol": o.get("vol", true)}
		# Visée : le bras et l'arme pivotent autour de l'épaule vers la cible (vers le haut : négatif).
		var vise: float = o.get("vise", 0.0)
		if vise != 0.0:
			xf = xf * Transform2D(vise, sp - sp.rotated(vise))
		var devant: bool = Arme.DEVANT.has(forme)
		var armed := {}
		if not devant:
			armed = Arme.draw(ci, xf, hand, forme, mods, c)
		var arm := PackedVector2Array([sp, sp.lerp(hand, 0.5) + (hand - sp).orthogonal().normalized() * -2.0, hand])
		Ink.brush(ci, xf, arm, 8.4, Ink.encre(), 1.0, 0.5)
		Ink.brush(ci, xf, arm, 6.2, K.CREME, 1.0, 0.5)
		Ink.part(ci, xf, Ink.oval(hand, 2.8, 2.6, 10), {"clair": Color("5b4636"), "ombre": Color("3f3026")}, 1.0)
		if devant:
			armed = Arme.draw(ci, xf, hand, forme, mods, c)
		Arme.ornaments(ci, armed)
	if corps:
		# Feuilles-glyphes en orbite, à maturité.
		if p > 0.7 and not Ink.mono:
			var k := (p - 0.7) / 0.3
			for i in 3:
				var ga := t * 1.1 + i * TAU / 3.0
				var q := Vector2(cos(ga) * (hem + 12.0), top + 10.0 + sin(ga) * 8.0)
				Ink.halo(ci, xf * q, 6.0 * u, gl, k)
				Ink.flat(ci, xf, Ink.leaf(q + Vector2(-3, 0), ga + PI * 0.5, 7.0, 3.6), Color(gl.lerp(Color.WHITE, 0.3), k), 0.6)


## Repères du dessin (unités locales, pieds en 0, regard vers +x) : centre du masque, cœur, épaule,
## haut du corps, et le facteur d'échelle du repère (h × facteur = px pour 100 unités).
static func anchors(o: Dictionary) -> Dictionary:
	var p := K.progress(o)
	var w := weights(o)
	var legl := 10.0 + 14.0 * p
	var ch := 30.0 + 26.0 * p
	var top := -legl - ch
	var rm := 17.0 - 2.0 * p
	var sh: float = 9.0 + 5.0 * p + 3.0 * w["racine"] * p
	return {"mask": Vector2(3.0, top - rm * 0.55), "rm": rm, "core": Vector2(4.0, top + 16.0 + 6.0 * p), "shoulder": Vector2(sh - 3.0, top + 6.0), "top": top, "scale": 0.62 + 0.38 * p}


## Pointe des bois selon la branche dominante (Sylve._tip connaît ronce, seve, vent et le reste).
static func _tipkind(dom: String) -> String:
	return dom


## Cape : du cou à un ourlet dont la découpe dit la branche.
static func _cape(top: float, legl: float, sh: float, hem: float, p: float, dom: String, sway: float) -> PackedVector2Array:
	var cape := PackedVector2Array([Vector2(-sh, top + 4.0), Vector2(sh, top + 4.0)])
	var nt := 4 + roundi(4.0 * p)
	var depth := 5.0 + 6.0 * p
	match dom:
		"ronce":
			nt += 2
			depth *= 1.3
		"vent":
			depth *= 1.6
		"racine":
			depth *= 0.5
		"seve", "spore":
			depth *= 0.7
	cape.append(Vector2(hem + 1.0 * sway, -legl + 2.0))
	var sub := 3 if dom == "seve" or dom == "spore" else 1
	var n := nt * sub
	for i in n + 1:
		var k := i / float(n)
		var x := lerpf(hem, -hem - 6.0 * p, k)
		var y := -legl + 2.0 + sway * k * 1.5
		if i > 0 and i < n:
			if sub == 3:
				y += depth * sin(PI * fposmod(k * nt, 1.0))
			elif i % 2 == 1:
				y += depth
				if dom == "vent":
					x -= 3.0
		cape.append(Vector2(x, y))
	cape.append(Vector2(-hem - 6.0 * p + sway, -legl + 2.0))
	return cape


static func _cape_overlay(ci: CanvasItem, xf: Transform2D, top: float, legl: float, hem: float, s: Dictionary, t: float, cpal: Dictionary) -> void:
	for x: float in [-5.0, 4.0]:
		Ink.brush(ci, xf, PackedVector2Array([Vector2(x * 0.5, top + 8.0), Vector2(x, (top - legl) * 0.5), Vector2(x * 1.5, -legl)]), 1.2, cpal["ombre"].darkened(0.1))
	if s["ronce"] > 0.15:
		var a := Vector2(-hem * 0.8, -legl - 2.0)
		var b := Vector2(hem * 0.2, top + 10.0)
		var pts := PackedVector2Array()
		for i in 9:
			var k := i / 8.0
			pts.append(a.lerp(b, k) + Vector2(0, sin(k * 9.0) * 2.0))
		Ink.brush(ci, xf, pts, 3.6, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, xf, pts, 2.2, Color("6b2a40"), 1.0, 1.0)
		for i in [2, 4, 6]:
			Ink.part(ci, xf, Ink.thorn(pts[i], -PI * 0.6 + (i % 4) * 0.6, 3.6 * s["ronce"] + 1.0, 1.8), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.6, 1.0, 0.0)
		for i in roundi(3.0 * s["ronce"]):
			Ink.part(ci, xf, Ink.oval(pts[1 + i * 3] + Vector2(1, 3), 2.0, 2.0, 10), {"clair": Color("d4485a"), "ombre": Color("7a1e30"), "reflet": Color.WHITE}, 0.7)
	if s["racine"] > 0.15:
		for q: Vector3 in [Vector3(-hem * 0.5, top + 14.0, 5.0), Vector3(-hem * 0.2, (top - legl) * 0.45, 4.0), Vector3(-hem * 0.75, -legl - 6.0, 4.0)]:
			Ink.flat(ci, xf, Ink.lumpy(Vector2(q.x, q.y), q.z * (0.6 + 0.6 * s["racine"]), q.z * 0.7, 12, 0.25, 4.0), Color(Art.FEUILLES_BUILD["racine"]["clair"], 0.95))
		for j in 4:
			var x := -hem + j * hem * 0.45
			Ink.tendril(ci, xf, Vector2(x, -legl + 2.0), PI * 0.5, 4.0 + 8.0 * s["racine"], 0.6, 1.4, Art.ec("racine", "sombre").lightened(0.2), sin(t + j) * 0.3)
	if s["seve"] > 0.15 and not Ink.mono:
		for j in 3:
			var x := -hem * 0.7 + j * hem * 0.35
			Ink.brush(ci, xf, PackedVector2Array([Vector2(x * 0.3, top + 8.0), Vector2(x * 0.7, (top - legl) * 0.5), Vector2(x, -legl - 1.0)]), 1.4, Color(Art.ec("seve", "clair"), 0.8 * s["seve"]), 0.0, 0.0)
	if s["spore"] > 0.15:
		for q: Vector2 in [Vector2(-hem * 0.5, top + 14.0), Vector2(-hem * 0.25, (top - legl) * 0.55), Vector2(-hem * 0.7, -legl - 7.0), Vector2(-hem * 0.05, -legl - 10.0)]:
			Ink.flat(ci, xf, Ink.oval(q, 2.2 * s["spore"] + 0.8, 1.8 * s["spore"] + 0.6, 10), Color("efe2f5"))
	if s["vent"] > 0.15:
		for r in 2:
			for j in 4:
				var q := Vector2(-hem * 0.85 + j * hem * 0.35, top + 14.0 + r * 12.0)
				Ink.part(ci, xf, Ink.leaf(q, PI * 0.55, 8.0 * s["vent"] + 3.0, 4.0), {"clair": Color("c8daea"), "ombre": Color("6e88a8")}, 0.7, 1.0, 0.0)
	if s["aube"] > 0.15 and not Ink.mono:
		Ink.brush(ci, xf, PackedVector2Array([Vector2(1.0, top + 5.0), Vector2(hem * 0.3, (top - legl) * 0.5), Vector2(hem * 0.55, -legl + 3.0)]), 1.6, Art.c("or"), 0.0, 0.0)


## Collerette, épaulières : la pièce de tenue qui dit la branche au premier coup d'œil.
static func _shoulders(ci: CanvasItem, xf: Transform2D, b: Vector2, sh: float, p: float, br: String, s: Dictionary, lv: Dictionary, dark: Dictionary, t: float, sway: float) -> void:
	var k := clampf(p, 0.0, 1.0)
	match br:
		"ronce":
			for i in 3 + roundi(4.0 * k):
				var a := PI * (0.12 + 0.76 * i / (2.0 + 4.0 * k))
				K.leaf(ci, xf, b, a, 9.0 + 6.0 * k, 5.0, lv if i % 2 == 0 else dark, 0.05, 1.0)
			for i in 3:
				Ink.part(ci, xf, Ink.thorn(b + Vector2(sh * 0.6 + i * 2.0, 1.0), -PI * 0.5 + 0.4 * (i - 0.5), 6.0 + 8.0 * k, 3.0, 0.1), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.9, 1.0, 0.0)
		"seve":
			for i in 5:
				var a := PI * (0.05 + 0.9 * i / 4.0)
				K.leaf(ci, xf, b, a, 10.0 + 7.0 * k, 8.0, {"clair": Color(Art.ec("seve", "clair"), 0.9), "ombre": Art.ec("seve"), "reflet": Color.WHITE}, 0.06, 0.9)
		"racine":
			for q: Vector2 in [Vector2(sh * 0.55, 2.0), Vector2(-sh * 0.6, 2.5)]:
				Ink.part(ci, xf, Ink.lumpy(b + q, 6.0 + 4.0 * k, 4.6 + 2.0 * k, 14, 0.12, 3.0), BARK, 1.6, 1.0, 0.4)
				Ink.flat(ci, xf, Ink.lumpy(b + q + Vector2(-1, -3.0 - 1.5 * k), 4.0 + 2.0 * k, 1.8, 10, 0.3, 5.0), Art.FEUILLES_BUILD["racine"]["clair"])
		"vent":
			for r in 2:
				for i in 5:
					var a := PI * (0.1 + 0.8 * i / 4.0)
					K.leaf(ci, xf, b + Vector2(0, r * 3.0), a, (11.0 + 7.0 * k) * (1.0 - r * 0.2), 4.4, {"clair": Color("e8f2fa") if r == 0 else Color("a4bcd4"), "ombre": Color("6e88a8"), "reflet": Color.WHITE}, 0.03, 0.9)
		"spore":
			for q: Vector2 in [Vector2(sh * 0.55, 1.0), Vector2(-sh * 0.6, 2.0)]:
				var cap := PackedVector2Array()
				for i in 13:
					var a := PI + PI * i / 12.0
					cap.append(b + q + Vector2(cos(a) * (6.0 + 3.0 * k), sin(a) * (4.0 + 2.0 * k)))
				Ink.part(ci, xf, cap, {"clair": Color("a07cc0"), "ombre": Color("4a3560"), "reflet": Color("e2d0f2")}, 1.4, 1.0, 0.5)
				Ink.flat(ci, xf, Ink.oval(b + q + Vector2(-1, -2.5), 1.3, 1.1, 8), Color("efe2f5"))
		"aube":
			for i in 4:
				var a := -PI * (0.25 + 0.17 * i)
				var q := b + Vector2(sh * 0.3 - i * 3.0, 2.0)
				var sh2 := Ink.thorn(q, a, 8.0 + 7.0 * k, 4.0)
				Ink.part(ci, xf, sh2, {"clair": Color(Color("fffde6"), 0.9), "ombre": Color("d9b860"), "reflet": Color.WHITE}, 0.9, 1.0, 1.0)
			if not Ink.mono:
				Ink.halo(ci, xf * (b + Vector2(0, -4)), 8.0 * xf.get_scale().abs().x, Art.ec("lumiere"), 0.5 * k)
		_:
			for i in 3 + roundi(4.0 * k):
				var a := PI * (0.15 + 0.7 * i / (2.0 + 4.0 * k)) + 0.05 * sway
				K.leaf(ci, xf, b, a, 9.0 + 7.0 * k, 5.0 + 2.0 * k, lv if i % 2 == 0 else dark, 0.05, 1.0)


## Coiffe : pousse au début, puis couronne d'épines, chapeau-champignon, plumes, mousse, pétales.
static func _headgear(ci: CanvasItem, xf: Transform2D, mc: Vector2, rm: float, s: Dictionary, dom: String, lv: Dictionary, t: float, sway: float, p: float) -> void:
	if p < 0.6:
		var k := 1.0 - p / 0.6
		Ink.brush(ci, xf, PackedVector2Array([mc + Vector2(0, -rm * 1.05), mc + Vector2(1, -rm * 1.4)]), 2.2, lv["ombre"], 1.0, 0.4)
		K.leaf(ci, xf, mc + Vector2(1, -rm * 1.4), -2.4 + 0.1 * sway, 9.0 * k, 5.0 * k, lv)
		K.leaf(ci, xf, mc + Vector2(1, -rm * 1.4), -0.7 + 0.1 * sway, 8.0 * k, 4.6 * k, lv)
	if s["ronce"] > 0.2:
		for i in 5:
			var a := -PI * (0.85 - i * 0.17)
			var q := mc + Vector2(-3, -1) + Vector2.from_angle(a) * rm * 1.12
			Ink.part(ci, xf, Ink.thorn(q, a, 4.0 + 6.0 * s["ronce"], 2.6), {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.3)}, 0.8, 1.0, 0.0)
	if s["racine"] > 0.2:
		Ink.flat(ci, xf, Ink.lumpy(mc + Vector2(-6, -rm * 1.02), rm * 0.7 * s["racine"] + 2.0, 3.0, 14, 0.3, 6.0), Art.FEUILLES_BUILD["racine"]["clair"])
	if s["vent"] > 0.2:
		for i in 3:
			var a := PI * 1.1 + i * 0.12 + 0.1 * sin(t * 2.5 + i)
			K.leaf(ci, xf, mc + Vector2(-rm * 0.7, -rm * 0.6), a, 10.0 + 10.0 * s["vent"], 4.0, {"clair": Color("e8f2fa"), "ombre": Color("8fb4e0"), "reflet": Color.WHITE}, -0.04, 0.9)
	if s["spore"] > 0.2:
		# Chapeau-champignon : large bord, pois clairs.
		var k: float = s["spore"]
		var c0 := mc + Vector2(-2, -rm * 0.85)
		var cap := PackedVector2Array()
		for i in 21:
			var a := PI + PI * i / 20.0
			cap.append(c0 + Vector2(cos(a) * rm * (1.0 + 0.7 * k), sin(a) * rm * (0.55 + 0.35 * k)))
		cap.append(c0 + Vector2(rm * 0.9, rm * 0.12))
		cap.append(c0 + Vector2(-rm * 0.9, rm * 0.12))
		Ink.part(ci, xf, cap, {"clair": Color("a07cc0"), "ombre": Color("4a3560"), "reflet": Color("e2d0f2")}, 2.0, 1.0, 0.6)
		for q: Vector2 in [Vector2(-0.5, -0.45), Vector2(0.15, -0.7), Vector2(0.6, -0.3), Vector2(-0.1, -0.2)]:
			Ink.flat(ci, xf, Ink.oval(c0 + Vector2(q.x * rm * (1.0 + 0.7 * k), q.y * rm * (0.55 + 0.35 * k)), 2.2, 1.8, 10), Color("efe2f5"))
		if not Ink.mono:
			for j in 3:
				var kk := fposmod(t * 0.4 + j * 0.33, 1.0)
				ci.draw_circle(xf * (c0 + Vector2(-rm + j * rm, 4.0 + kk * 16.0)), 1.1 * xf.get_scale().abs().x, Color(Color("d6c0ff"), 0.8 * (1.0 - kk)))
	if s["seve"] > 0.2:
		for i in 4:
			var a := -PI * (0.95 - i * 0.12)
			K.leaf(ci, xf, mc + Vector2(-3, -1) + Vector2.from_angle(a) * rm * 1.05, a, 6.0 + 6.0 * s["seve"], 4.6, {"clair": Color(Art.ec("seve", "clair"), 0.9), "ombre": Art.ec("seve"), "reflet": Color.WHITE}, 0.0, 0.8)


## Ailes de phalène (Aube), translucides, avec un œil doré.
static func _wings(ci: CanvasItem, xf: Transform2D, b: Vector2, k: float, t: float) -> void:
	var flap := 0.08 * sin(t * 2.0)
	for j in 2:
		var a := -PI * (0.78 + 0.1 * j) + flap
		var l := (18.0 + 26.0 * k) * (1.0 - j * 0.25)
		var wing := Ink.leaf(b, a, l, l * 0.75, 0.05)
		Ink.part(ci, xf, wing, {"clair": Color(Color("fff4c8"), 0.85), "ombre": Color(Color("d9b860"), 0.7), "reflet": Color.WHITE}, 1.2, 1.0, 0.8)
		var eye := b + Vector2.from_angle(a) * l * 0.6
		Ink.flat(ci, xf, Ink.oval(eye, l * 0.12, l * 0.12, 12), Art.FEUILLES_BUILD["aube"]["accent"], 0.6)
		Ink.flat(ci, xf, Ink.oval(eye, l * 0.05, l * 0.05, 8), Color("6e5a2e"))
