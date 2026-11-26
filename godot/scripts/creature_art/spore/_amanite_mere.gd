## L'Amanite-Mère (boss de Spore), direction « Bestiaire d'herbier » (refonte des personnages, vague 2,
## B2) : la mère des Flétris du marais. Une amanite géante vue de trois quarts : chapeau violet de la
## région (Art.bc("spore")) semé de verrues pâles, lames ocre dessous, pied fibreux à collerette
## déchirée, planté dans une volve qui trempe dans la vase. Le visage est sur le pied, sous la
## collerette : deux fentes de braise et une bouche de lames. Autour du pied, ses enfants : de petites
## vesses et des chapeaux qui poussent dans la vase, un réseau de myxomycète ocre qui rampe au sol.
## Vivant : respiration du chapeau, collerette qui flotte, spores qui tombent des lames, bulles de vase.
##
## Annonces (même timing que le combat, aucune zone au sol ici) : « nuages » et « onde » gonflent le
## chapeau et allument les lames ; « spirale » soulève le chapeau ; les pores fument (nuages).
## Phase 2 : chapeau soulevé, lames qui luisent. Phase 3 : chapeau fendu, braise dans les fentes,
## mycélium qui sort de terre. Mort : le chapeau s'affaisse et se vide de ses spores.
##
## Pose (o) : t, k (0 → 1), attack, phase, die (0 → 1), swell, recoil (0 → 1), hit, poison, flip,
## ash (0 → 1), mono. Dessin statique : la même pose donne le même dessin.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const O = preload("res://scripts/creature_art/spore/outils.gd")
const FletriArt = preload("res://scripts/fletri_art.gd")

## 100 unités en px du jeu (1600×900) : le chapeau culmine ~150 px au-dessus des pieds.
const HEIGHT := 150.0


## Une couleur de la pose : poison (teinte d'état), puis cendre pendant la mort.
static func tint(col: Color, o: Dictionary) -> Color:
	var c := col
	if o.get("poison", false):
		c = c.lerp(Art.ec("poison"), 0.3)
	var ash: float = o.get("ash", 0.0)
	if ash > 0.0:
		c = c.lerp(FletriArt.ash_color(), ash)
	return c


static func pal(p: Dictionary, o: Dictionary) -> Dictionary:
	var out := {}
	for key in p:
		out[key] = tint(p[key], o)
	return out


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var k: float = o.get("k", 0.0)
	var attack: String = o.get("attack", "")
	var phase: int = o.get("phase", 1)
	var die: float = o.get("die", 0.0)
	var swell: float = o.get("swell", 1.0)
	var hit: float = o.get("hit", 0.0)
	var flip: bool = o.get("flip", false)
	var prev_mono := Ink.mono
	if o.has("mono"):
		Ink.mono = bool(o["mono"])
	Ink.flash = hit
	var alive := 1.0 - die
	var sag := Anim.ease_out(die)
	var kk := Anim.ease_out(k)
	# Couches : « body » (cuit par pose, sans le temps : la respiration est une transformation posée par
	# le boss), « live » (ce qui bouge sans cesse, dessiné en direct par-dessus), « all » (les deux).
	var layer: String = o.get("layer", "all")
	var body := layer != "live"
	var live := layer != "body"
	var lean := 3.0
	var base := Ink.frame(feet, h, flip)
	if body:
		Ink.ground_shadow(ci, base, Vector2(4, 0), 66.0)
	var flesh := pal(O.flesh(), o)
	var pale := pal(O.cap_pal(), o)
	var vase := pal(O.vase_pal(), o)
	var gill_c := tint(Art.bc("spore", "detail"), o)
	var xf := base
	# Vase du pied : une flaque luisante où trempe la volve, qui bouillonne.
	if body:
		O.puddle(ci, xf, Vector2(2, -1), 64.0, alive, 1.3)
	if live:
		O.bubbles(ci, xf, Vector2(2, -1), 50.0, t, alive, 7)
	# Myxomycète : un réseau ocre qui rampe dans la vase (phase 2 et plus), et le mycélium qui sort
	# de terre en phase 3, en filaments pâles qui ondulent.
	if body and phase >= 2 and not Ink.mono:
		var myxo := Color(tint(Art.bc("spore", "detail"), o), 0.8 * alive)
		for i in 7:
			var a := PI * (0.05 + 0.9 * i / 6.0) + 0.12 * sin(i * 2.7)
			var pts := PackedVector2Array()
			for j in 5:
				var u := j / 4.0
				var r := 34.0 + 40.0 * u * (0.8 + 0.3 * fposmod(i * 0.61, 1.0))
				pts.append(Vector2(cos(a + 0.18 * sin(u * 3.0 + i)) * r, -2.0 + sin(a) * r * Art.OMBRE_APLATI * 0.9))
			Ink.brush(ci, xf, pts, 2.6 - 0.2 * (i % 3), myxo, 1.0, 0.0)
			Ink.flat(ci, xf, Ink.lumpy(pts[pts.size() - 1], 3.0, 2.0, 9, 0.3, 3.0, i), myxo)
	if live and phase >= 3 and alive > 0.0:
		var fil := tint(Art.bc("spore", "spore"), o)
		for i in 9:
			var a := TAU * i / 9.0 + 0.2
			var pts := PackedVector2Array()
			for j in 6:
				var u := j / 5.0
				var r := 30.0 + 52.0 * u
				pts.append(Vector2(cos(a + 0.25 * sin(u * 4.0 + t + i)) * r, sin(a + 0.25 * sin(u * 4.0 + t + i)) * r * Art.OMBRE_APLATI - 2.0))
			ci.draw_polyline(xf * pts, Color(fil, 0.8 * alive), 1.6 * xf.get_scale().abs().x, true)
	# Enfants du fond : vesses et chapeaux qui poussent derrière la volve.
	if body:
		_body(ci, xf, o, flesh, pale, vase, gill_c, sag, kk, lean)
	var top_y := -60.0 + 22.0 * sag
	var face_y := top_y + 20.0
	var glow := (0.15 + 0.45 * kk) * alive
	var shut := Ink.blink(t, 0.7) * alive
	if live and alive > 0.0:
		for e: Vector2 in [Vector2(-2 + lean, face_y), Vector2(10 + lean, face_y - 1.5)]:
			var w := 4.2 if e.x > 5.0 else 3.4
			Ink.ember(ci, xf, PackedVector2Array([e + Vector2(-w, 0.8), e + Vector2(0, -1.6 * (1.0 - shut)), e + Vector2(w, -0.6), e + Vector2(0, 1.2)]), glow)
	var lift: float = o.get("lift", 0.0)
	var cap_c := Vector2(lean * 1.4, top_y - 2.0 - lift * 10.0)
	var rx := 60.0 * swell * (1.0 + 0.16 * sag)
	var ry := 40.0 * swell * (1.0 - 0.45 * sag)
	var under := 9.0 + 12.0 * lift
	var cxf := Transform2D(0.05 + 0.12 * sag, cap_c)
	if live and phase >= 3 and alive > 0.0:
		Ink.sparks(ci, xf, cxf * Vector2(-rx * 0.28, -ry * 0.45), Vector2(0, -1), 4, t, 1.6, alive)
		Ink.sparks(ci, xf, cxf * Vector2(rx * 0.36, -ry * 0.36), Vector2(0, -1), 3, t + 0.5, 1.4, alive)
	# Spores qui tombent des lames (vivant), et pores qui fument pendant l'annonce des nuages.
	if live and not Ink.mono and alive > 0.0:
		var sp := tint(Art.bc("spore", "spore"), o)
		var s := xf.get_scale().abs().x
		for i in 6:
			var u := fposmod(t * 0.35 + i * 0.173, 1.0)
			var x := (fposmod(i * 0.618, 1.0) * 2.0 - 1.0) * rx * 0.8
			var q := cxf * Vector2(x + sin(t * 1.3 + i) * 3.0, under * 0.6 + u * 40.0)
			ci.draw_circle(xf * q, 1.3 * s, Color(sp, 0.7 * (1.0 - u) * alive))
		if attack == "nuages":
			for i in 3:
				O.spore_puff(ci, xf, cxf * Vector2((i - 1) * rx * 0.45, -ry * (0.7 + 0.15 * (1 - absf(i - 1)))), fposmod(t * 1.5 + i / 3.0, 1.0), kk * alive, 5, 34.0)
	# Mort : les spores s'échappent en bouffées qui montent et pâlissent.
	if live and die > 0.0 and not Ink.mono:
		var sp2 := Art.bc("spore", "spore")
		var s := xf.get_scale().abs().x
		for i in 10:
			var a := TAU * i / 10.0 + 0.3
			var u := clampf(die * 1.3 - (i % 3) * 0.12, 0.0, 1.0)
			if u <= 0.0 or u >= 1.0:
				continue
			var q := cxf * (Vector2.from_angle(a) * Vector2(rx, ry) * (0.4 + 0.7 * u) - Vector2(0, 40.0 * u))
			ci.draw_circle(xf * q, (6.0 + 12.0 * u) * s, Color(sp2.lerp(Art.ec("seve", "clair"), u), 0.5 * (1.0 - u)))
	Ink.flash = 0.0
	Ink.mono = prev_mono


## Corps (couche « body », cuite par pose) : enfants du fond, volve, pied, visage, collerette,
## lames, chapeau, verrues, fentes, enfants de devant. Sans le temps.
static func _body(ci: CanvasItem, xf: Transform2D, o: Dictionary, flesh: Dictionary, pale: Dictionary, vase: Dictionary, gill_c: Color, sag: float, kk: float, lean: float) -> void:
	var attack: String = o.get("attack", "")
	var phase: int = o.get("phase", 1)
	var swell: float = o.get("swell", 1.0)
	var lift: float = o.get("lift", 0.0)
	var alive := 1.0 - float(o.get("die", 0.0))
	_brood(ci, xf, o, 0.0, false)
	# Volve : la coupe déchirée d'où sort le pied, maculée de vase.
	var volve := PackedVector2Array()
	for i in 15:
		var a := PI + PI * i / 14.0
		var jag := 1.0 if i % 2 == 0 else 0.86
		volve.append(Vector2(cos(a) * 32.0 * jag, -14.0 + sin(a) * 9.0 * jag))
	for i in 11:
		var a := PI * i / 10.0
		volve.append(Vector2(cos(a) * 34.0, -8.0 + sin(a) * 9.0))
	var volve_pal := {"clair": pale["ombre"].lerp(vase["clair"], 0.35), "ombre": vase["ombre"], "reflet": pale["clair"]}
	Ink.part(ci, xf, volve, volve_pal, 2.6, 1.0, 0.4)
	for i in 4:
		var x := -22.0 + i * 14.0
		Ink.brush(ci, xf, PackedVector2Array([Vector2(x, -12 + absf(i - 1.5) * 1.5), Vector2(x + 1.5, -5), Vector2(x - 1.0, 0)]), 1.4, vase["ombre"].darkened(0.25))
	# Pied : colonne fibreuse, évasée en bas, qui penche un peu vers le regard.
	var top_y := -60.0 + 22.0 * sag
	var stem := PackedVector2Array([
		Vector2(-22, -10), Vector2(-17, -26), Vector2(-14, -42), Vector2(-13 + lean, top_y),
		Vector2(13 + lean, top_y), Vector2(14, -42), Vector2(18, -26), Vector2(23, -10), Vector2(0, -7)])
	var stem_pal := {"clair": pale["clair"].lerp(flesh["reflet"], 0.25), "ombre": pale["ombre"].lerp(flesh["ombre"], 0.3), "reflet": Color.WHITE}
	Ink.part(ci, xf, stem, stem_pal, 3.0, 1.0, 0.5)
	# Flanc d'ombre et fibres du pied.
	Ink.flat(ci, xf, PackedVector2Array([Vector2(6 + lean, top_y), Vector2(13 + lean, top_y), Vector2(14, -42), Vector2(18, -26), Vector2(23, -10), Vector2(10, -8), Vector2(8, -40)]), Color(stem_pal["ombre"], 0.7))
	for i in 6:
		var x := -15.0 + i * 6.0
		Ink.brush(ci, xf, PackedVector2Array([Vector2(x + lean * 0.9, top_y + 6), Vector2(x + lean * 0.4 + sin(i * 1.9), -34), Vector2(x * 1.2, -12)]), 1.0, Color(stem_pal["ombre"].darkened(0.2), 0.8))
	# Visage sous la collerette, tourné vers le regard : fentes de braise, bouche de lames.
	var face_y := top_y + 20.0
	for e: Vector2 in [Vector2(-2 + lean, face_y), Vector2(10 + lean, face_y - 1.5)]:
		var w := 4.2 if e.x > 5.0 else 3.4
		Ink.flat(ci, xf, Ink.oval(e, w + 1.4, 3.0, 12), tint(Art.bc("ronge"), o), 0.8)
	var mouth_c := Vector2(5 + lean, face_y + 11.0)
	var gape := 2.5 + 3.5 * kk * float(attack in ["onde", "nuages"]) + 2.5 * sag
	Ink.flat(ci, xf, Ink.oval(mouth_c, 7.5, gape, 14), tint(Art.bc("ronge"), o), 1.0)
	if not Ink.mono:
		for i in 5:
			var x := mouth_c.x - 5.0 + i * 2.5
			Ink.brush(ci, xf, PackedVector2Array([Vector2(x, mouth_c.y - gape * 0.8), Vector2(x, mouth_c.y + gape * 0.6)]), 0.9, gill_c.lerp(Art.bc("braise"), 0.5 * kk))
	# Collerette : un anneau de voile déchiré qui pend sous le chapeau et flotte.
	var ring_y := top_y + 4.0
	var skirt := PackedVector2Array()
	for i in 17:
		var u := float(i) / 16.0
		var x := lerpf(-19.0, 19.0, u) + lean
		var hang := 9.0 + 3.0 * sin(i * 2.3) 
		skirt.append(Vector2(x * (1.0 + 0.1 * sin(PI * u)), ring_y + hang * (0.6 + 0.4 * sin(PI * u)) + (2.5 if i % 2 else 0.0)))
	skirt.append(Vector2(16 + lean, ring_y - 2))
	skirt.append(Vector2(-16 + lean, ring_y - 2))
	Ink.part(ci, xf, skirt, pale, 2.0, 1.0, 0.5)
	for i in 5:
		var x := -12.0 + i * 6.0 + lean
		Ink.brush(ci, xf, PackedVector2Array([Vector2(x, ring_y), Vector2(x + 0.8, ring_y + 8.0)]), 0.9, pale["ombre"].darkened(0.15))
	# Chapeau : lames dessous (en trois quarts, un croissant d'ocre), dôme violet par-dessus.
	var cap_c := Vector2(lean * 1.4, top_y - 2.0 - lift * 10.0)
	var rx := 60.0 * swell * (1.0 + 0.16 * sag)
	var ry := 40.0 * swell * (1.0 - 0.45 * sag)
	var tilt := 0.05 + 0.12 * sag
	var cxf := Transform2D(tilt, cap_c)
	# Dessous : bord du chapeau et lames, plus large quand il se soulève.
	var under := 9.0 + 12.0 * lift
	var gills := Ink.oval(Vector2(0, 0), rx * 0.96, under, 30)
	Ink.part(ci, xf, cxf * gills, {"clair": gill_c, "ombre": gill_c.darkened(0.45)}, 2.4, 0.4, 0.0)
	if not Ink.mono:
		var hot := clampf(kk * float(attack in ["nuages", "onde", "spirale"]) + 0.35 * float(phase >= 2), 0.0, 1.0) * alive
		for i in 15:
			var a := PI * (i + 0.5) / 15.0
			var q := Vector2(-cos(a) * rx * 0.9, sin(a) * under * 0.9)
			Ink.brush(ci, xf, cxf * PackedVector2Array([Vector2(0, -under * 0.3), q]), 1.1, gill_c.darkened(0.35).lerp(Art.bc("braise"), hot))
		if hot > 0.0:
			Ink.halo(ci, xf * (cxf * Vector2(0, under * 0.4)), rx * 0.55 * xf.get_scale().abs().x, Art.bc("braise"), hot * 0.45)
	# Dôme : demi-ellipse haute, bord légèrement ondulé, affaissé et retombant à la mort.
	var dome := PackedVector2Array()
	for i in 25:
		var u := PI * i / 24.0
		var edge := 1.0 + 0.025 * sin(i * 1.7)
		dome.append(Vector2(-cos(u) * rx * edge, -sin(u) * ry))
	for i in range(1, 12):
		var u := PI * i / 12.0
		var droop := 4.0 + 10.0 * sag * sin(u)
		dome.append(Vector2(cos(u) * rx, sin(u) * (under * 0.5) + droop * 0.4))
	if phase >= 3:
		# Fendu : deux encoches dans le bord.
		for idx in [5, 19]:
			dome[idx] = dome[idx].lerp(Vector2(0, -ry * 0.3), 0.3)
	var dw := cxf * dome
	Ink.part(ci, xf, dw, flesh, 3.4, 1.0, 0.8)
	# Stries du bord (typiques des amanites) et ombre propre du côté opposé à la lumière.
	if not Ink.mono:
		for i in 13:
			var u := PI * (0.06 + 0.88 * i / 12.0)
			var p0 := Vector2(-cos(u) * rx * 0.97, -sin(u) * ry * 0.18)
			var p1 := Vector2(-cos(u) * rx * 0.86, -sin(u) * ry * 0.42)
			Ink.brush(ci, xf, cxf * PackedVector2Array([p0, p1]), 1.0, Color(flesh["ombre"].darkened(0.3), 0.6))
	# Verrues : lambeaux du voile, pâles du côté de la lumière, posés en perspective sur le dôme.
	var warts := [Vector3(-0.5, 0.45, 7.0), Vector3(-0.18, 0.78, 6.5), Vector3(0.22, 0.7, 6.0), Vector3(0.55, 0.4, 5.5),
		Vector3(-0.72, 0.18, 5.0), Vector3(0.02, 0.42, 5.5), Vector3(-0.32, 0.18, 4.5), Vector3(0.38, 0.14, 4.0),
		Vector3(0.78, 0.15, 3.8), Vector3(-0.05, 0.92, 4.5), Vector3(0.45, 0.82, 3.5), Vector3(-0.6, 0.7, 3.5)]
	for i in warts.size():
		var w: Vector3 = warts[i]
		var p := Vector2(w.x * rx, -w.y * ry * (1.0 - 0.15 * sag))
		var lit := clampf(0.5 - w.x * 0.6 + w.y * 0.3, 0.0, 1.0)
		var wr := w.z * (1.0 - 0.35 * sag) * (0.7 + 0.3 * w.y)
		Ink.flat(ci, xf, cxf * Ink.lumpy(p + Vector2(0.8, 1.0), wr, wr * 0.62, 10, 0.25, 3.0, i), Color(flesh["ombre"].darkened(0.4), 0.85))
		Ink.flat(ci, xf, cxf * Ink.lumpy(p, wr * 0.86, wr * 0.52, 10, 0.25, 3.0, i), pale["ombre"].lerp(pale["clair"], 0.3 + 0.7 * lit), 0.7)
	# Fentes de braise (phase 3) : le chapeau craque, des braises s'échappent.
	if phase >= 3 and alive > 0.0:
		var crack1 := PackedVector2Array([Vector2(-rx * 0.05, -ry * 0.62), Vector2(-rx * 0.28, -ry * 0.42), Vector2(-rx * 0.34, -ry * 0.2), Vector2(-rx * 0.5, -ry * 0.12)])
		var crack2 := PackedVector2Array([Vector2(rx * 0.12, -ry * 0.5), Vector2(rx * 0.36, -ry * 0.34), Vector2(rx * 0.62, -ry * 0.26)])
		for cr in [crack1, crack2]:
			Ink.brush(ci, xf, cxf * cr, 4.2, Ink.encre(), 0.0, 0.0)
			Ink.brush(ci, xf, cxf * cr, 2.4, Art.bc("braise"), 0.0, 0.0)
			Ink.brush(ci, xf, cxf * cr, 0.9, Art.bc("braise_coeur"), 0.0, 0.0)
	# Enfants du premier plan, devant le pied.
	_brood(ci, xf, o, 0.0, true)


## Les enfants de la Mère : vesses et chapeaux qui poussent dans la vase autour de la volve
## (front : ceux de devant). Ils frémissent, s'allument pendant les annonces et se fanent à la mort.
static func _brood(ci: CanvasItem, xf: Transform2D, o: Dictionary, t: float, front: bool) -> void:
	var die: float = o.get("die", 0.0)
	var k: float = o.get("k", 0.0)
	var attack: String = o.get("attack", "")
	var phase: int = o.get("phase", 1)
	var glow := Anim.ease_out(k) * float(attack == "invocation" or attack == "nuages")
	var flesh := pal(O.flesh(), o)
	# [x, y (au sol), taille, vesse ?, phase où il apparaît]
	var kids := [[-44.0, -8.0, 1.0, true, 1], [40.0, -10.0, 0.8, false, 1], [-30.0, -16.0, 0.6, false, 2], [52.0, -4.0, 0.7, true, 2],
		[-56.0, 2.0, 0.75, false, 1], [24.0, 6.0, 0.9, true, 1], [-14.0, 8.0, 0.55, false, 3], [60.0, 8.0, 0.5, false, 3]]
	for i in kids.size():
		var kd: Array = kids[i]
		var y: float = kd[1]
		if (y > -2.0) != front or phase < int(kd[4]):
			continue
		var sz: float = kd[2] * (1.0 - 0.6 * Anim.ease_out(die))
		var p := Vector2(kd[0], y)
		var sway := 0.15 * sin(t * 1.4 + i * 1.7)
		if kd[3]:
			O.puffball(ci, xf, p + Vector2(0, -8.0 * sz), 9.0 * sz, 8.0 * sz, flesh, glow, 5, i)
		else:
			O.cap(ci, xf, p, -PI / 2.0 + sway * 0.6, 14.0 * sz, 16.0 * sz, sway, glow, true)


## Endormie : un gros bouton fermé dans sa volve, à moitié dans la vase (h px pour 100 unités).
## open : l'arène est ouverte, le bouton bat doucement.
static func draw_sleeper(ci: CanvasItem, feet: Vector2, h: float, t: float, open: bool) -> void:
	var xf := Ink.frame(feet, h, false)
	Ink.ground_shadow(ci, xf, Vector2(2, 0), 46.0)
	O.puddle(ci, xf, Vector2(2, -1), 50.0, 1.0, 0.4)
	var pulse := 0.5 + 0.5 * sin(t * 2.0) if open else 0.0
	var egg := PackedVector2Array()
	for i in 30:
		var a := TAU * i / 30.0
		var s := Vector2(cos(a), sin(a))
		egg.append(Vector2(s.x * 30.0 * (1.0 + 0.04 * pulse), -38.0 + s.y * 36.0 * (1.0 - 0.12 * maxf(-s.y, 0.0))))
	Ink.part(ci, xf, egg, O.flesh(), 3.0, 1.0, 0.7)
	# Le voile blanc qui enveloppe encore le bouton, déchiré en verrues.
	for w: Vector3 in [Vector3(-12, -60, 5.0), Vector3(6, -66, 4.5), Vector3(16, -50, 4.0), Vector3(-4, -46, 3.5), Vector3(-18, -38, 3.5), Vector3(10, -34, 3.0)]:
		Ink.flat(ci, xf, Ink.lumpy(Vector2(w.x, w.y), w.z, w.z * 0.65, 10, 0.25, 3.0, w.x), Art.bc("spore", "chapeau"), 0.7)
	var volve := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		volve.append(Vector2(cos(a) * 30.0 * (1.0 if i % 2 == 0 else 0.88), -10.0 + sin(a) * 6.0 * (1.0 if i % 2 == 0 else 0.6) * -1.0))
	for i in 9:
		var a := PI * i / 8.0
		volve.append(Vector2(cos(a) * 31.0, -6.0 + sin(a) * 7.0))
	Ink.part(ci, xf, volve, {"clair": Art.bc("spore", "chapeau_ombre").lerp(Art.bc("spore", "vase"), 0.35), "ombre": Art.bc("spore", "vase").darkened(0.4)}, 2.4, 1.0, 0.0)
	# Une fente de braise dans le bouton : elle dort, mais couve.
	Ink.ember(ci, xf, PackedVector2Array([Vector2(-6, -40), Vector2(2, -42.0 - 2.0 * pulse), Vector2(9, -40), Vector2(2, -38.5)]), 0.1 + 0.3 * pulse)


## Guérie (après la victoire) : un cercle de fées, amanites saines et pâles dans la mousse, une vesse
## vivante au milieu ; aucune braise, la sève verte luit au pied (vivant).
static func draw_healed(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, c)
	var moss := {"clair": Art.c("decor_vivant").lightened(0.1), "ombre": Art.c("decor_vivant").darkened(0.2)}
	Ink.flat(ci, xf, Ink.lumpy(Vector2.ZERO, 62.0, 62.0 * Art.OMBRE_APLATI, 26, 0.12, 5.0, 0.3), Color(moss["ombre"], 0.75))
	Ink.flat(ci, xf, Ink.lumpy(Vector2(-8, -4), 44.0, 44.0 * Art.OMBRE_APLATI, 22, 0.12, 5.0, 1.1), Color(moss["clair"], 0.6))
	Ink.halo(ci, xf * Vector2(0, -6), 34.0 * s, Art.ec("seve", "clair"), 0.9 + 0.2 * sin(t * 1.5))
	var cap_ok := {"clair": Art.bc("spore", "chapeau"), "ombre": Art.bc("spore", "chapeau_ombre"), "reflet": Color.WHITE}
	var stem_ok := Art.bc("spore", "chapeau").darkened(0.08)
	var ring := []
	for i in 9:
		var ang := TAU * i / 9.0 + 0.2
		ring.append(Vector2(cos(ang), sin(ang) * 0.42) * 52.0)
	ring.sort_custom(func(a, b): return a.y < b.y)
	for i in ring.size():
		var p: Vector2 = ring[i]
		var sz := 0.8 + 0.25 * fposmod(i * 0.618, 1.0)
		var sway := 0.06 * sin(t * 1.2 + i)
		var top := p + Vector2(sway * 10.0, -15.0 * sz)
		Ink.brush(ci, xf, PackedVector2Array([p, top]), 4.6 * sz, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, xf, PackedVector2Array([p, top]), 3.0 * sz, stem_ok, 1.0, 1.0)
		var dome := PackedVector2Array()
		for j in 11:
			var u := PI * j / 10.0
			dome.append(top + Vector2(-cos(u) * 9.0 * sz, -sin(u) * 6.5 * sz))
		dome.append(top + Vector2(0, 2.0 * sz))
		Ink.part(ci, xf, dome, cap_ok, 1.4, 1.0, 0.7)
		Ink.flat(ci, xf, Ink.oval(top + Vector2(-2.5, -3.5) * sz, 1.6 * sz, 1.1 * sz, 8), Color.WHITE.lerp(cap_ok["clair"], 0.3))
	# Au centre : une vesse saine, pâle, sans braise.
	O.puffball(ci, xf, Vector2(0, -9), 9.0, 8.0, {"clair": Art.bc("spore", "chapeau"), "ombre": Art.bc("spore", "chapeau_ombre"), "reflet": Color.WHITE}, 0.0, 6, 2.0)
	Ink.flat(ci, xf, Ink.oval(Vector2(1, -17), 2.0, 1.0, 10), Art.ec("seve", "clair"))
