## L'Ancien pétrifié (boss de Racine), direction « Bestiaire d'herbier » : le plus vieux chêne de la forêt,
## changé en pierre par la Flétrissure et remis debout par ses racines, comme le Menhir et le Tertre. Un
## fût de pierre veinée aux plaques d'écorce, enserré de racines de bois mort qui le portent comme des
## jambes et l'enlacent ; un visage creusé dans la pierre (arcades lourdes, yeux de braise, bouche-
## crevasse, barbe de radicelles) ; une cime de branches pétrifiées chargées de feuillage de pierre ;
## des scarabées perce-écorce accrochés à l'écorce. Phase 2 : la cime se fend de braise. Phase 3 : des
## plaques d'écorce sont tombées, la braise court dans les fentes du fût, la cime se dégarnit.
## Vue de trois quarts, tournée vers la droite (le boss retourne l'image).
##
## Ce script ne dessine aucune sorte (son nom commence par « _ ») : boss_racine.gd le cuit en sprites
## (boss_bake.gd) par groupes, et dessine en direct ce qui bouge vite (bras-branches, pieu, yeux).
##   sol    : racines qui plongent dans la roche, l'ombre (pose : phase) ;
##   corps  : l'Ancien (pose : phase, t ; die 0 → 1 : l'écorce de pierre tombe, le bois vivant
##            apparaît) ; « dort » : endormi, la cime basse, les yeux clos ;
##   vaincu : une clairière moussue et un jeune chêne.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const R = preload("res://scripts/creature_art/racine/outils.gd")

## 100 unités en px du jeu (1600×900) : ~200 px de haut (~240 px en 1080p) avec la cime.
const HEIGHT := 130.0
const IDLE := 6
const LOOP := 3.0
const DEATH := 8
## Yeux (unités, tournés vers la droite) : dessinés en direct par le boss. [centre, angle, long, large]
const EYES := [[Vector2(4, -84), -0.12, 11.0, 4.6], [Vector2(26, -82), 0.05, 9.0, 4.0]]
## Épaules des bras-branches (fond, devant) et cime (pour les pierres de l'éboulis).
const SHOULDERS := [Vector2(-30, -92), Vector2(34, -90)]
const CROWN := Vector2(0, -128)


static func groups() -> Dictionary:
	var sol := []
	var corps := []
	for ph in [1, 2, 3]:
		sol.append(["p%d" % ph, {"phase": ph}])
		for i in IDLE:
			corps.append(["p%d" % ph, {"phase": ph, "t": LOOP * i / IDLE}])
	for i in DEATH:
		corps.append(["mort", {"phase": 3, "die": (i + 0.5) / DEATH}])
	corps.append(["dort", {"sleep": true}])
	return {
		"sol": {"rect": Rect2(-120, -34, 240, 66), "poses": sol},
		"corps": {"rect": Rect2(-100, -184, 200, 196), "poses": corps},
		"vaincu": {"rect": Rect2(-90, -90, 180, 110), "poses": [["vaincu", {}]]},
	}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	match str(o.get("groupe", "corps")):
		"sol":
			draw_ground(ci, feet, h, o)
		"vaincu":
			draw_victory(ci, feet, h, o)
		_:
			draw_body(ci, feet, h, o)


static func _rage(o: Dictionary) -> float:
	if o.get("sleep", false):
		return 0.0
	return [0.0, 0.5, 1.0][clampi(int(o.get("phase", 1)), 1, 3) - 1]


# --- Sol ---

static func draw_ground(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var base := Ink.frame(feet, h, false)
	var rage := _rage(o)
	Ink.ground_shadow(ci, base, Vector2(0, 2), 84.0)
	if Ink.mono:
		return
	# Roche fendue sous lui, dalles soulevées.
	Ink.flat(ci, base, Ink.lumpy(Vector2(0, 3), 92.0, 26.0, 40, 0.1, 7.0), Color(Art.bc("racine", "ombre").darkened(0.5), 0.45))
	var slab := R.pal("cendre")
	for i in 7:
		var a := TAU * (i + 0.3) / 7.0
		var p := Vector2(cos(a) * (70.0 + 14.0 * (i % 2)), sin(a) * 22.0 + 4.0)
		var pts := Ink.lumpy(p, 12.0 + 3.0 * (i % 3), 6.0, 7, 0.25, 3.0, i)
		Ink.part(ci, base, pts, {"clair": slab["clair"].darkened(0.25), "ombre": slab["ombre"].darkened(0.2), "reflet": slab["reflet"]}, 1.6, 1.0, 0.3)
	# Racines qui plongent dans la roche, braise dans les fissures dès la phase 2.
	var wood := R.pal("bois")
	for i in 8:
		var a := TAU * (i + 0.6) / 8.0
		var pts := PackedVector2Array()
		for j in 6:
			var u := j / 5.0
			var w := a + 0.25 * sin(u * 3.0 + i)
			pts.append(Vector2(cos(w), sin(w) * 0.32) * (36.0 + (40.0 + 12.0 * (i % 3)) * u) + Vector2(0, 4))
		Ink.brush(ci, base, pts, 10.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, base, pts, 7.0, wood["ombre"], 1.0, 0.0)
		Ink.brush(ci, base, pts.slice(0, 4), 2.0, wood["clair"], 1.0, 0.0)
		if rage > 0.0 and i % 2 == 0:
			var tip := pts[5]
			Ink.brush(ci, base, PackedVector2Array([tip, tip + Vector2(cos(a) * 14.0, sin(a) * 4.0)]), 2.0 + 1.5 * rage, Art.bc("braise"), 1.0, 0.0)


# --- Corps ---

static func draw_body(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var die: float = o.get("die", 0.0)
	var sleep: bool = o.get("sleep", false)
	var rage := _rage(o)
	var dk := Anim.ease_in_out(die) if die > 0.0 else 0.0
	var base := Ink.frame(feet, h, false)
	var cyc := sin(t * TAU / LOOP)
	# Il respire à peine (de la pierre) : la cime se balance, le fût se soulève d'un rien.
	var breath := 1.0 + 0.012 * cyc
	var sag := dk * 0.5 + (0.12 if sleep else 0.0)
	var xf := base * Transform2D(0.0, Vector2(1.0 + 0.1 * sag, breath * (1.0 - sag * 0.35)), 0.0, Vector2.ZERO)
	var stone := R.pal("pierre")
	var pale := R.pal("cendre")
	var wood := R.pal("bois")
	var far_wood := {"clair": wood["ombre"], "ombre": wood["ombre"].darkened(0.3), "reflet": wood["clair"]}

	# Racines-jambes du fond.
	_root_leg(ci, base, Vector2(-30, -26), Vector2(-86, 2), 13.0, far_wood, sag)
	_root_leg(ci, base, Vector2(18, -30), Vector2(40, 8), 12.0, far_wood, sag)
	# Le fût : pierre noueuse, pied évasé (contreforts), taille plus fine, bosses.
	var trunk := PackedVector2Array([
		Vector2(-58, -6), Vector2(-40, -22), Vector2(-36, -46), Vector2(-42, -72), Vector2(-36, -98),
		Vector2(-40, -112), Vector2(-18, -118), Vector2(8, -120), Vector2(36, -114), Vector2(40, -100),
		Vector2(34, -74), Vector2(40, -48), Vector2(36, -22), Vector2(56, -6), Vector2(20, 2), Vector2(-22, 2)])
	Ink.part(ci, xf, trunk, stone, 3.4, 1.0, 0.7)
	# Fil du bois devenu pierre : des stries qui montent en se tordant.
	if not Ink.mono:
		for i in 6:
			var x := -26.0 + i * 10.0
			Ink.brush(ci, xf, PackedVector2Array([Vector2(x * 1.3, -6), Vector2(x, -40), Vector2(x * 1.1 + 4.0, -80), Vector2(x * 0.9, -112)]), 1.8, stone["ombre"].darkened(0.25))
	# Plaques d'écorce de pierre (plus claires, bord encré). En phase 3 certaines sont tombées (braise
	# dessous) ; à la mort elles tombent toutes et le bois vivant apparaît.
	var plates := [Vector2(-22, -30), Vector2(14, -24), Vector2(-26, -66), Vector2(-14, -104), Vector2(-4, -42)]
	for i in plates.size():
		var p: Vector2 = plates[i]
		var fallen := (rage >= 1.0 and i % 3 == 1) or dk > 0.25 + 0.08 * i
		var plate := Ink.lumpy(p, 11.0, 8.0, 7, 0.2, 3.0, i * 1.3)
		if fallen:
			if dk > 0.0:
				# Le bois vivant sous la pierre.
				Ink.flat(ci, xf, plate, Art.bc("racine", "bois").lerp(Art.ec("seve", "clair"), 0.25 * dk), 1.2)
				# La plaque tombe.
				var drop := Vector2(sin(i * 2.0) * 10.0 * dk, 120.0 * dk * dk)
				if p.y + drop.y < 6.0:
					Ink.part(ci, xf, Transform2D(i * 0.6 * dk, drop) * plate, pale, 1.6, 1.0, 0.3)
			else:
				Ink.flat(ci, xf, plate, Art.bc("ronge"), 1.4)
				if not Ink.mono:
					Ink.flat(ci, xf, Ink.lumpy(p, 6.0, 3.5, 7, 0.2, 3.0, i), Art.bc("braise"))
		else:
			Ink.part(ci, xf, plate, {"clair": pale["clair"].darkened(0.12), "ombre": pale["ombre"], "reflet": pale["reflet"]}, 1.6, 1.0, 0.3)
			Ink.brush(ci, xf, PackedVector2Array([p + Vector2(-6, -1), p + Vector2(0, 2), p + Vector2(6, -2)]), 1.4, Ink.encre())
	# Lichens clairs.
	if not Ink.mono:
		for q in [Vector2(-30, -40), Vector2(-20, -84), Vector2(28, -64), Vector2(-4, -16)]:
			Ink.flat(ci, xf, Ink.lumpy(q, 5.0, 3.4, 10, 0.3, 4.0, q.x), Art.bc("racine", "feuille").lightened(0.15))
	# Fentes de braise du fût : une en phase 1, plus nombreuses ensuite.
	var slits := [[Vector2(-30, -10), Vector2(-24, -30), Vector2(-30, -46)]]
	if rage > 0.0:
		slits.append([Vector2(28, -18), Vector2(22, -40), Vector2(30, -58)])
	if rage >= 1.0:
		slits.append([Vector2(-8, -60), Vector2(-2, -76), Vector2(-10, -96)])
		slits.append([Vector2(12, -34), Vector2(20, -44)])
	var glow := (0.4 + 0.6 * rage) * (1.0 - dk) * (0.0 if sleep else 1.0)
	for s in slits:
		var pts := PackedVector2Array(s)
		Ink.brush(ci, xf, pts, 4.6 + 2.5 * rage, Ink.encre())
		if not Ink.mono and glow > 0.0:
			Ink.brush(ci, xf, pts, 1.6 + 2.6 * rage, Color(Art.bc("braise"), glow))
	# Racines qui enlacent le fût et le tiennent debout (l'idée du Menhir).
	for i in 2:
		var y0 := -8.0 - i * 26.0
		var pts := PackedVector2Array()
		for j in 7:
			var u := j / 6.0
			pts.append(Vector2(lerpf(-42.0, 40.0, u), y0 - 30.0 * u + 7.0 * sin(u * PI) + (14.0 * u if i == 1 else 0.0)))
		Ink.brush(ci, xf, pts, 8.0, Ink.encre(), 0.6, 0.0)
		Ink.brush(ci, xf, pts, 5.4, wood["clair"].darkened(0.1 * i), 0.6, 0.0)
		Ink.brush(ci, xf, pts.slice(1, 5), 1.4, wood["reflet"])
	# Scarabées perce-écorce accrochés à l'écorce (la famille de Racine).
	if dk < 0.5:
		_beetle(ci, xf, Vector2(-34, -54), 0.5, t)
		if rage > 0.0:
			_beetle(ci, xf, Vector2(32, -96), -0.3, t + 1.0)
	# Visage : arcades lourdes, orbites, bouche-crevasse, barbe de radicelles.
	for e in EYES:
		var p: Vector2 = e[0]
		Ink.flat(ci, xf, Ink.leaf(p - Vector2(3, 0), e[1], e[2] + 6.0, e[3] + 5.0), Art.bc("ronge"), 1.4)
		if sleep:
			Ink.brush(ci, xf, PackedVector2Array([p, p + Vector2.from_angle(e[1]) * e[2]]), 2.2, Ink.encre())
	# Arcades lourdes : deux corniches de pierre qui surplombent les yeux, froncées vers le milieu.
	for i in EYES.size():
		var e: Array = EYES[i]
		var c: Vector2 = e[0] + Vector2(1, -7)
		var ledge := PackedVector2Array([c + Vector2(-11, 1), c + Vector2(-4, -5), c + Vector2(10, -2 + 4.0 * i), c + Vector2(12, 2 + 3.0 * i), c + Vector2(-2, 1)])
		Ink.part(ci, xf, ledge, pale, 1.8, 1.0, 0.4)
	var mouth := PackedVector2Array([Vector2(0, -62), Vector2(9, -58), Vector2(18, -63), Vector2(27, -59)])
	Ink.brush(ci, xf, mouth, 6.0, Ink.encre(), 0.4, 0.4)
	if not Ink.mono and glow > 0.0:
		Ink.brush(ci, xf, mouth, 1.8, Color(Art.bc("braise"), glow * 0.8))
	for i in 6:
		var p := Vector2(-2.0 + i * 5.6, -56.0 + absf(i - 2.5) * 0.8)
		var sway := 2.0 * sin(t * TAU / LOOP + i)
		var hair := PackedVector2Array([p, p + Vector2(sway * 0.5, 7.0), p + Vector2(sway, 13.0 + (i % 2) * 4.0)])
		Ink.brush(ci, xf, hair, 3.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, xf, hair, 1.6, Art.bc("racine", "feuille"), 1.0, 0.0)
	# Racines-jambes du devant.
	_root_leg(ci, base, Vector2(-14, -20), Vector2(-50, 10), 15.0, wood, sag)
	_root_leg(ci, base, Vector2(28, -22), Vector2(86, 4), 14.0, wood, sag)
	# La cime.
	_crown(ci, xf, t, rage, dk, sleep)


## Racine-jambe : du fût (hanche) au sol (pied), arquée, griffes de radicelles.
static func _root_leg(ci: CanvasItem, base: Transform2D, hip: Vector2, foot: Vector2, w: float, pal: Dictionary, sag: float) -> void:
	var f := foot.lerp(Vector2(foot.x * 1.15, foot.y), sag)
	var knee := Vector2(lerpf(hip.x, f.x, 0.55), minf(hip.y, f.y) - 10.0 * (1.0 - sag))
	var pts := PackedVector2Array([hip, knee, f])
	Ink.brush(ci, base, pts, w + 4.0, Ink.encre(), 1.0, 0.5)
	Ink.brush(ci, base, pts, w, pal["ombre"], 1.0, 0.45)
	Ink.brush(ci, base, PackedVector2Array([hip.lerp(knee, 0.2), knee, knee.lerp(f, 0.4)]), w * 0.4, pal["clair"], 0.0, 0.0)
	var out := 1.0 if f.x > hip.x else -1.0
	for i in 3:
		var toe := PackedVector2Array([f, f + Vector2(out * (6.0 + 4.0 * i), -1.0 + 3.0 * i), f + Vector2(out * (10.0 + 6.0 * i), 2.0 + 3.0 * i)])
		Ink.brush(ci, base, toe, 4.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, base, toe, 2.4, pal["ombre"], 1.0, 0.0)


## Scarabée perce-écorce (petit, le dos vers nous) accroché en p, tourné de a.
static func _beetle(ci: CanvasItem, xf: Transform2D, p: Vector2, a: float, t: float) -> void:
	var bx := xf * Transform2D(a, p)
	for s in [-1.0, 1.0]:
		for j in 3:
			var hip := Vector2(-3.0 + j * 3.0, s * 3.0)
			Ink.brush(ci, bx, PackedVector2Array([hip, hip + Vector2(-1.0 + j, s * 6.0)]), 1.6, Ink.encre())
	Ink.part(ci, bx, Ink.oval(Vector2.ZERO, 7.0, 5.0, 14), R.pal("bois"), 1.2, 1.0, 0.8)
	Ink.brush(ci, bx, PackedVector2Array([Vector2(-6, 0), Vector2(6, 0)]), 1.0, Ink.encre())
	Ink.part(ci, bx, Ink.oval(Vector2(8, 0), 2.6, 2.4, 10), R.pal("bois"), 1.0, 1.0, 0.0)
	Ink.part(ci, bx, Ink.thorn(Vector2(10, 0), -0.4 + 0.1 * sin(t * 3.0), 6.0, 2.4, -0.3), R.pal("os"), 0.8, 1.0, 0.0)


## Cime : maîtresses branches de pierre, feuillage pétrifié en masses, fendu de braise (phase 2),
## dégarni (phase 3) ; à la mort elle s'effondre et des feuilles vertes reviennent.
static func _crown(ci: CanvasItem, xf: Transform2D, t: float, rage: float, dk: float, sleep: bool) -> void:
	var wood := R.pal("bois")
	var stone := R.pal("pierre")
	var pale := R.pal("cendre")
	var sway := sin(t * TAU / LOOP) * 1.5
	var droop := (14.0 if sleep else 0.0) + 40.0 * dk
	var top := Vector2(0, -116)
	# Branches maîtresses.
	var limbs := [[Vector2(-10, -116), Vector2(-56, -150)], [Vector2(4, -118), Vector2(6, -168)], [Vector2(16, -114), Vector2(60, -146)], [Vector2(-20, -112), Vector2(-80, -122)], [Vector2(26, -110), Vector2(84, -118)]]
	for i in limbs.size():
		var a: Vector2 = limbs[i][0]
		var b: Vector2 = limbs[i][1] + Vector2(sway * (0.5 + 0.2 * i), droop * (0.6 + 0.2 * (i % 2)))
		var mid := a.lerp(b, 0.5) + Vector2(0, -8)
		var pts := PackedVector2Array([a, mid, b])
		Ink.brush(ci, xf, pts, 12.0, Ink.encre(), 1.0, 0.2)
		Ink.brush(ci, xf, pts, 8.4, stone["ombre"].lerp(wood["ombre"], 0.5), 1.0, 0.2)
		Ink.brush(ci, xf, PackedVector2Array([a, mid]), 2.2, stone["clair"], 0.0, 0.0)
		# Rameau cassé.
		Ink.brush(ci, xf, PackedVector2Array([mid, mid + Vector2(8.0 * signf(b.x - a.x + 0.1), -12.0)]), 4.0, Ink.encre(), 1.0, 0.0)
	# Masses de feuillage pétrifié (blocs de pierre pâle en grappes), fendues.
	var lobes := [[0.0, -164.0, 26.0], [-38.0, -150.0, 22.0], [38.0, -150.0, 22.0], [-66.0, -128.0, 17.0], [66.0, -128.0, 17.0], [-18.0, -138.0, 20.0], [20.0, -140.0, 20.0]]
	var thin := 0.85 if rage >= 1.0 else 1.0
	for li in lobes.size():
		var l: Array = lobes[li]
		if rage >= 1.0 and li in [3, 4] and dk == 0.0:
			continue
		var q := Vector2(l[0] * (1.0 + 0.04 * sway / 1.5), l[1]) + Vector2(sway * 0.8, droop * (0.7 + 0.1 * (li % 3)))
		var rr: float = l[2] * thin
		if dk > 0.0:
			q += Vector2((li - 3) * 8.0 * dk, 110.0 * dk * dk * (0.6 + 0.1 * li))
		var mass := Ink.lumpy(q, rr * 1.12, rr * 0.86, 36, 0.09, 11.0, li * 0.9)
		var col := {"clair": pale["clair"].darkened(0.04 * (li % 3)), "ombre": pale["ombre"].lerp(stone["ombre"], 0.3), "reflet": pale["reflet"]}
		Ink.part(ci, xf, mass, col, 2.6, 1.0, 0.5)
		# Fente : de braise dès la phase 2.
		var sd := 1.0 if li % 2 == 0 else -1.0
		var crack := PackedVector2Array([q + Vector2(-0.55 * sd, -0.25) * rr, q + Vector2(-0.12 * sd, 0.05) * rr, q + Vector2(0.15 * sd, -0.12) * rr, q + Vector2(0.5 * sd, 0.2) * rr])
		Ink.brush(ci, xf, crack, 3.4, Ink.encre())
		if not Ink.mono and rage > 0.0 and li % 2 == 0 and dk == 0.0:
			Ink.brush(ci, xf, crack, 1.6 + 1.2 * rage, Art.bc("braise"))
		# Feuilles de chêne sèches encore accrochées.
		if li % 3 == 0 and dk < 0.5:
			Ink.part(ci, xf, Ink.leaf(q + Vector2(rr * 0.6, rr * 0.3), 0.9 + 0.1 * sin(t * 2.0 + li), 12.0, 6.0, 0.1), R.pal("feuille"), 1.2, 1.0, 0.3)
	# À la mort : des pousses vertes percent la pierre (vert sève : le vivant revient).
	if dk > 0.4:
		var g := (dk - 0.4) / 0.6
		var green := {"clair": Art.ec("seve"), "ombre": Art.ec("seve").darkened(0.45), "reflet": Art.ec("seve", "clair")}
		for i in 5:
			var foot := Vector2(-28.0 + i * 14.0, -60.0 - 16.0 * (i % 2))
			var tip := foot + Vector2(3.0 * sin(i * 1.7), -22.0 * g)
			Ink.brush(ci, xf, PackedVector2Array([foot, tip]), 2.6, green["ombre"], 1.0, 0.0)
			Ink.part(ci, xf, Ink.leaf(tip, -PI * 0.5 + (0.7 if i % 2 else -0.7), 11.0 * g + 1.0, 6.0 * g + 0.5), green, 1.0, 1.0, 0.5)


# --- Vaincu ---

## Une clairière moussue, des débris de pierre couverts de mousse, un jeune chêne.
static func draw_victory(ci: CanvasItem, feet: Vector2, h: float, _o := {}) -> void:
	var base := Ink.frame(feet, h, false)
	var moss := {"clair": Art.ec("racine", "clair").darkened(0.05), "ombre": Art.ec("racine", "clair").darkened(0.45), "reflet": Art.ec("racine", "clair").lightened(0.35)}
	Ink.flat(ci, base, Ink.lumpy(Vector2(0, 0), 70.0, 22.0, 40, 0.06, 9.0), Color(Art.c("decor_vivant").darkened(0.2), 0.7))
	var pale := R.pal("cendre")
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := Vector2(cos(a) * 58.0, sin(a) * 18.0)
		var rock := Ink.lumpy(p, 10.0, 7.0, 9, 0.2, 3.0, i)
		Ink.part(ci, base, rock, pale, 1.6, 1.0, 0.3)
		Ink.part(ci, base, Ink.lumpy(p + Vector2(0, -5), 7.0, 3.0, 10, 0.2, 4.0, i), moss, 1.0, 1.0, 0.3)
	var bark := {"clair": Color("8a6a46"), "ombre": Color("5a4430"), "reflet": Color("c9a77a")}
	var trunk := PackedVector2Array([Vector2(-6, 0), Vector2(-4, -30), Vector2(-3, -56), Vector2(3, -56), Vector2(4, -30), Vector2(7, 0)])
	Ink.part(ci, base, trunk, bark, 1.8, 1.0, 0.4)
	for b in [[Vector2(0, -44), Vector2(-16, -58)], [Vector2(1, -48), Vector2(16, -62)]]:
		Ink.brush(ci, base, PackedVector2Array([b[0], b[1]]), 4.4, Ink.encre(), 1.0, 0.0)
		Ink.brush(ci, base, PackedVector2Array([b[0], b[1]]), 2.6, bark["clair"], 1.0, 0.0)
	for l in [[0, -74, 18], [-16, -64, 14], [16, -64, 14], [-8, -54, 12], [9, -54, 12]]:
		Ink.part(ci, base, Ink.lumpy(Vector2(l[0], l[1]), l[2], l[2] * 0.85, 40, 0.05, 11.0, l[0]), moss, 2.0, 1.0, 0.6)
