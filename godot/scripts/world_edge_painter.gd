## Dessin du bord du monde (voir world_edge.gd) : le dégradé de fond et le décor de chaque région, pour
## une tuile du bord. Une instance dessine une tuile ; les fonctions statiques disent quelle région
## tient quelle direction et de quelle couleur est le fond.
##
## Les formes sont posées dans le repère du côté : « u » le long du bord (de gauche à droite en regardant
## vers l'extérieur), « d » la profondeur au-delà du bord du monde. Tout est vu de dessus, comme le reste
## du jeu, donc un côté ne se distingue d'un autre que par l'orientation des formes.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")

## Profondeur du bord (px) : l'écran le plus large (3440 x 1440) posé contre le bord du monde ne voit pas plus loin.
const DEPTH := 2000.0
## Longueur d'une tuile le long du bord.
const CHUNK := 1000.0
## Pas du dégradé de fond le long du bord.
const STEP := 125.0
## Profondeurs des rangées du dégradé de fond.
const ROWS := [0.0, 60.0, 160.0, 320.0, 560.0, 900.0, 1300.0, 1650.0, 2000.0]
## Largeur (rad) sur laquelle un décor en remplace un autre à la frontière de deux régions.
const BLEND := 0.14
## Côtés : normale sortante et tangente (dans l'ordre : nord, est, sud, ouest).
const NORMALS := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
const TANGENTS := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]

## Couleurs de chaque thème : « mid » (à 450 px du bord), « far » (au loin), « glow » (lumière du décor).
const THEMES := {
	"ronce": {"mid": Color("2a1519"), "far": Color("0b0608"), "glow": Color("c2403f")},
	"spore": {"mid": Color("14262e"), "far": Color("060c10"), "glow": Color("5fd6c0")},
	"vent": {"mid": Color("39424f"), "far": Color("090c11"), "glow": Color("c4d2e0")},
	"seve": {"mid": Color("1a3a30"), "far": Color("060f0c"), "glow": Color("d3dc72")},
	"aube": {"mid": Color("b8a27e"), "far": Color("14122a"), "glow": Color("f2d06b")},
	"racine": {"mid": Color("352a20"), "far": Color("0c0907"), "glow": Color("c8924f")},
}
const DEFAULT_THEME := "ronce"

## Région → {angle, near, theme}, relue quand la liste des régions change.
static var regs: Dictionary = {}
static var _regs_key := ""

var b: DrawBatch
var side := 0
var index := 0
var u0 := 0.0
var u1 := 0.0
## Profondeur maximale dessinée (la carte du monde n'a besoin que du début du bord).
var max_d := DEPTH
## Vrai : on dessine le décor ; faux : le dégradé de fond seulement.
var decor_pass := true
var rng := RandomNumberGenerator.new()
## Région dont on dessine le décor, et ses couleurs.
var rid := ""
var theme: Dictionary = {}
var far := Color.BLACK
var glow := Color.WHITE


# --- Régions et couleurs ---

static func load_regions() -> void:
	var key := ",".join(Regions.ids())
	if key == _regs_key and not regs.is_empty():
		return
	_regs_key = key
	regs = {}
	for id in Regions.ids():
		var th := str(Regions.def(id).get("edge", id))
		if not THEMES.has(th):
			th = DEFAULT_THEME
		var g := Regions.section(id, "ground")
		var near: Color = Regions.color(g.get("dead_dark", "sol_mort"), Regions.named_colors(g)).darkened(0.25)
		regs[id] = {"angle": Regions.angle_of(id), "near": near, "theme": th}


static func _wrap(a: float) -> float:
	return fposmod(a + PI, TAU) - PI


## Poids de la région « id » dans la direction « angle » : 1 dans son secteur, qui passe à 0 en
## 2 x BLEND radians autour de ses bords ; aux frontières, les deux voisines font 1 à elles deux.
## Si la direction n'a aucune région (monde incomplet), la plus proche prend tout.
static func weight(id: String, angle: float) -> float:
	var h := Regions.half_width()
	var w := clampf((h + BLEND - absf(_wrap(angle - float(regs[id]["angle"])))) / (2.0 * BLEND), 0.0, 1.0)
	if w > 0.0 or regs.size() >= 6:
		return w
	var best := ""
	var best_d := 9.0
	for o in regs:
		var dist := absf(_wrap(angle - float(regs[o]["angle"])))
		if clampf((h + BLEND - dist) / (2.0 * BLEND), 0.0, 1.0) > 0.0:
			return 0.0
		if dist < best_d:
			best_d = dist
			best = o
	return 1.0 if best == id else 0.0


## Couleur du fond à la profondeur « d » dans la direction « angle » : du ton du sol mort au bord du monde
## vers « mid » puis « far », mélangée entre régions voisines ; transparente au bord même (le sol du
## monde y passe encore) puis opaque.
static func base_color(angle: float, d: float) -> Color:
	var out := Color(0, 0, 0, 0)
	var sum := 0.0
	for id in regs:
		var w := weight(id, angle)
		if w <= 0.0:
			continue
		var t: Dictionary = THEMES[regs[id]["theme"]]
		var near: Color = regs[id]["near"]
		var c: Color
		if d <= 450.0:
			c = near.lerp(t["mid"], smoothstep(0.0, 450.0, d))
		else:
			c = (t["mid"] as Color).lerp(t["far"], smoothstep(450.0, DEPTH, d))
		out += Color(c.r * w, c.g * w, c.b * w, 0.0)
		sum += w
	if sum <= 0.0:
		return Color(0.05, 0.05, 0.05, clampf(d / 100.0, 0.0, 1.0))
	out = Color(out.r / sum, out.g / sum, out.b / sum, 1.0)
	out.a = smoothstep(0.0, 100.0, d)
	return out


static func to_world(side_: int, u: float, d: float) -> Vector2:
	return NORMALS[side_] * (Regions.WORLD_HALF + d) + TANGENTS[side_] * u


static func chunk_count() -> int:
	return int(ceil(2.0 * (Regions.WORLD_HALF + DEPTH) / CHUNK))


static func chunk_u0(i: int) -> float:
	return -(Regions.WORLD_HALF + DEPTH) + i * CHUNK


## Rectangle du monde qui contient la tuile (côté, rang) sur toute sa profondeur.
static func chunk_rect(side_: int, i: int, depth := DEPTH) -> Rect2:
	var a := chunk_u0(i)
	var r := Rect2(to_world(side_, a, 0.0), Vector2.ZERO)
	for u in [a, a + CHUNK]:
		for d in [0.0, depth]:
			r = r.expand(to_world(side_, u, d))
	return r


## Dessine la tuile (côté, rang) dans « batch », jusqu'à la profondeur « depth ».
static func build(batch: DrawBatch, side_: int, i: int, depth: float, decor: bool) -> void:
	load_regions()
	var c = new()
	c.b = batch
	c.side = side_
	c.index = i
	c.u0 = chunk_u0(i)
	c.u1 = c.u0 + CHUNK
	c.max_d = depth
	c.decor_pass = decor
	c.paint()


# --- Une tuile ---

func paint() -> void:
	var half := Regions.WORLD_HALF
	# Hors du trapèze (coins en onglet) : rien à dessiner.
	if u1 < -(half + max_d) or u0 > half + max_d:
		return
	if not decor_pass:
		_gradient()
		return
	var here := {}
	for k in 13:
		for r in [0.0, 0.5, 1.0]:
			var p := to_world(side, lerpf(u0, u1, k / 12.0), r * max_d)
			for id in regs:
				if weight(id, p.angle()) > 0.0:
					here[id] = true
	# Le décor de chaque région présente, dans l'ordre des régions (les mêmes à chaque partie).
	for id in Regions.ids():
		if not here.has(id):
			continue
		rid = id
		theme = THEMES[regs[id]["theme"]]
		far = theme["far"]
		glow = theme["glow"]
		rng.seed = hash("%s/%d/%d" % [regs[id]["theme"], side, index])
		match regs[id]["theme"]:
			"spore":
				_marais()
			"vent":
				_plateau()
			"seve":
				_vallee()
			"aube":
				_aube()
			"racine":
				_racines()
			_:
				_ronces()
		if b.points.size() > 40000:
			break


## Le fond : un quadrillage de quadrilatères aux couleurs de sommet (dégradé), du bord vers le noir.
func _gradient() -> void:
	var half := Regions.WORLD_HALF
	var cols := int(ceil(CHUNK / STEP))
	for r in ROWS.size() - 1:
		var d0: float = ROWS[r]
		var d1: float = ROWS[r + 1]
		if d0 >= max_d:
			break
		d1 = minf(d1, max_d)
		for i in cols:
			var ua := u0 + i * STEP
			var ub := ua + STEP
			# Coins en onglet : le côté ne dépasse pas la diagonale (|u| ≤ half + d).
			var pts := PackedVector2Array()
			var cs := PackedColorArray()
			for q in [[ua, d0], [ub, d0], [ub, d1], [ua, d1]]:
				var uu := clampf(q[0], -(half + q[1]), half + q[1])
				var p := to_world(side, uu, q[1])
				pts.append(p)
				cs.append(base_color(p.angle(), q[1]))
			if pts[0].distance_squared_to(pts[1]) < 1.0 and pts[2].distance_squared_to(pts[3]) < 1.0:
				continue
			b.draw_primitive(pts, cs)


# --- Aides de dessin ---

func P(u: float, d: float) -> Vector2:
	return to_world(side, u, d)


## Vrai si une forme centrée en (u, d), de demi-taille « pad », est à dessiner dans cette tuile et pour
## cette région (dans la tuile, dans le trapèze, pas trop profond, et tirée au sort selon le poids de la
## région à cet endroit : le même tirage à chaque partie).
func ok(u: float, d: float, pad := 0.0) -> bool:
	if d > max_d or u < u0 or u >= u1 or absf(u) > Regions.WORLD_HALF + d - pad:
		return false
	var w := weight(rid, P(u, d).angle())
	if w <= 0.0:
		return false
	if w >= 1.0:
		return true
	return fposmod(sin(u * 12.9898 + d * 78.233) * 43758.5453, 1.0) < w


## Un tirage de profondeur entre lo et hi, plus serré près de lo quand « bias » dépasse 1.
func depth(lo: float, hi: float, bias := 1.0) -> float:
	return lo + (hi - lo) * pow(rng.randf(), bias)


## Couleur qui se perd dans le noir avec la profondeur.
func fade(c: Color, d: float, k := 1.0) -> Color:
	var t := clampf((d - 250.0) / 1500.0, 0.0, 0.9) * k
	return Color(c.r + (far.r - c.r) * t, c.g + (far.g - c.g) * t, c.b + (far.b - c.b) * t, c.a)


## Polygone (repère du côté), éventuellement décalé dans le repère du monde (lumière venue d'en haut à gauche).
func poly(pts: PackedVector2Array, col: Color, shift := Vector2.ZERO) -> void:
	var w := PackedVector2Array()
	for p in pts:
		w.append(P(p.x, p.y) + shift)
	if w.size() >= 3:
		b.draw_colored_polygon(w, col)


func blob(u: float, d: float, rx: float, ry: float, col: Color, rot := 0.0, shift := Vector2.ZERO, n := 14) -> void:
	var pts := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var a := TAU * i / n
		var x := cos(a) * rx
		var y := sin(a) * ry
		pts.append(Vector2(u + x * cr - y * sr, d + x * sr + y * cr))
	poly(pts, col, shift)


## Trait effilé : de la largeur w0 à la largeur w1 le long d'un chemin (repère du côté).
func stroke(path: PackedVector2Array, w0: float, w1: float, col: Color, shift := Vector2.ZERO) -> void:
	var n := path.size()
	if n < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var dir := Vector2.ZERO
		if i > 0:
			dir += (path[i] - path[i - 1]).normalized()
		if i < n - 1:
			dir += (path[i + 1] - path[i]).normalized()
		if dir.length_squared() < 0.0001:
			dir = Vector2.RIGHT
		var nm := dir.normalized().orthogonal()
		var w := lerpf(w0, w1, float(i) / (n - 1)) * 0.5
		left.append(path[i] + nm * w)
		right.append(path[i] - nm * w)
	right.reverse()
	left.append_array(right)
	poly(left, col, shift)


## Chemin sinueux de « a » vers « b » en « n » points, écart latéral « wob ».
func wander(a: Vector2, to: Vector2, n: int, wob: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var nm := (to - a).normalized().orthogonal()
	var phase := rng.randf() * TAU
	for i in n + 1:
		var t := float(i) / n
		out.append(a.lerp(to, t) + nm * sin(phase + t * 3.4) * wob * sin(t * PI) + nm * rng.randf_range(-wob, wob) * 0.25)
	return out


# --- Ronce : un mur de ronces ---

func _ronces() -> void:
	# Fond : masses sombres, pour qu'il n'y ait pas de trou entre les tiges.
	for k in 26:
		var u := rng.randf_range(u0, u1)
		var d := depth(40.0, 1300.0, 1.4)
		var r := rng.randf_range(70.0, 170.0)
		if ok(u, d, r):
			blob(u, d, r * 1.3, r, fade(Color(0.075, 0.04, 0.05, 0.9), d), rng.randf() * PI)
	for k in 64:
		var u := rng.randf_range(u0, u1)
		var d := depth(30.0, 1500.0, 1.5)
		var ang := rng.randf() * TAU
		var len := rng.randf_range(150.0, 360.0) * (1.0 + d / 1500.0)
		var path := wander(Vector2(u, d), Vector2(u, d) + Vector2.from_angle(ang) * len, 6, len * 0.22)
		if not ok(u, d, 40.0):
			continue
		var w0 := rng.randf_range(9.0, 15.0) * (1.0 + d / 1800.0)
		stroke(path, w0 + 6.0, 4.0, fade(Color(0.03, 0.015, 0.02, 0.75), d), Vector2(3, 5))
		stroke(path, w0, w0 * 0.3, fade(Color(0.17, 0.085, 0.1), d))
		stroke(path, w0 * 0.4, 1.0, fade(Color(0.3, 0.15, 0.17, 0.8), d), Vector2(-w0 * 0.18, -w0 * 0.18))
		# Épines : de petits triangles de part et d'autre, tous les quelques pas.
		for i in range(1, path.size() - 1):
			var dir := (path[i + 1] - path[i - 1]).normalized()
			var nm := dir.orthogonal()
			for sgn in [-1.0, 1.0]:
				if rng.randf() < 0.75:
					var base: Vector2 = path[i]
					var tip: Vector2 = base + (nm * sgn * 1.0 + dir * 0.6).normalized() * rng.randf_range(14.0, 26.0) * (1.0 + d / 2500.0)
					poly(PackedVector2Array([base - dir * 4.0, base + dir * 4.0, tip]), fade(Color(0.36, 0.19, 0.2), d))
		# Baies : un point rouge qui luit, ici et là.
		if rng.randf() < 0.28 and d < 1100.0:
			var tip2: Vector2 = path[path.size() - 1]
			blob(tip2.x, tip2.y, 16.0, 16.0, fade(Color(glow, 0.12), d), 0.0, Vector2.ZERO, 10)
			blob(tip2.x, tip2.y, 5.5, 5.5, fade(Color(0.72, 0.17, 0.2), d), 0.0, Vector2.ZERO, 8)
			blob(tip2.x - 1.5, tip2.y - 1.5, 1.8, 1.8, Color(1, 0.7, 0.7, 0.7 * (1.0 - d / 1400.0)), 0.0, Vector2.ZERO, 6)


# --- Spore : les eaux du marais ---

func _marais() -> void:
	# Brume de spores, grandes taches pâles à peine visibles.
	for k in 7:
		var u := rng.randf_range(u0, u1)
		var d := depth(150.0, 1500.0)
		var rx := rng.randf_range(220.0, 480.0)
		if ok(u, d, 0.0):
			blob(u, d, rx, rx * 0.4, Color(glow, 0.045), rng.randf_range(-0.3, 0.3), Vector2.ZERO, 12)
	# Reflets longs et fins sur l'eau.
	for k in 22:
		var u := rng.randf_range(u0, u1)
		var d := depth(60.0, 1700.0, 1.2)
		var len := rng.randf_range(60.0, 200.0)
		if ok(u, d, len):
			var a := PackedVector2Array([Vector2(u - len, d), Vector2(u, d + rng.randf_range(-4.0, 4.0)), Vector2(u + len, d)])
			stroke(a, 1.0, 1.0, fade(Color(glow, 0.2), d, 0.7))
	# Roseaux au bord : petites touffes d'aiguilles.
	for k in 22:
		var u := rng.randf_range(u0, u1)
		var d := depth(30.0, 420.0, 1.2)
		if not ok(u, d, 40.0):
			continue
		for j in rng.randi_range(5, 9):
			var ang := rng.randf() * TAU
			var len := rng.randf_range(24.0, 62.0)
			var tip := Vector2(u, d) + Vector2.from_angle(ang) * len
			stroke(PackedVector2Array([Vector2(u, d), (Vector2(u, d) + tip) * 0.5, tip]), 3.5, 0.6, fade(Color(0.2, 0.32, 0.22), d))
	# Nénuphars : une feuille ronde échancrée, parfois une fleur.
	for k in 46:
		var u := rng.randf_range(u0, u1)
		var d := depth(60.0, 1500.0, 1.3)
		var rx := rng.randf_range(16.0, 38.0) * (1.0 + d / 1500.0)
		if not ok(u, d, rx):
			continue
		var rot := rng.randf() * TAU
		blob(u, d, rx, rx * 0.82, fade(Color(0.1, 0.22, 0.17), d), rot, Vector2(3, 4), 12)
		blob(u, d, rx, rx * 0.82, fade(Color(0.17, 0.4, 0.3), d), rot, Vector2.ZERO, 14)
		var nx := Vector2.from_angle(rot)
		poly(PackedVector2Array([Vector2(u, d), Vector2(u, d) + nx * rx * 1.1 + nx.orthogonal() * rx * 0.2, Vector2(u, d) + nx * rx * 1.1 - nx.orthogonal() * rx * 0.2]), fade(Color(0.05, 0.11, 0.1), d))
		if rng.randf() < 0.18:
			blob(u, d, 6.0, 6.0, fade(Color(0.9, 0.7, 0.9, 0.9), d), 0.0, Vector2.ZERO, 8)
	# Champignons géants : un chapeau vu de dessus, avec ses lamelles, ses taches et un halo de spores.
	for k in 9:
		var u := rng.randf_range(u0, u1)
		var d := depth(240.0, 1500.0)
		var r := rng.randf_range(60.0, 150.0) * (1.0 + d / 2200.0)
		if not ok(u, d, r):
			continue
		blob(u, d, r * 1.9, r * 1.9, Color(glow, 0.035), 0.0, Vector2.ZERO, 14)
		blob(u, d, r * 1.05, r * 1.0, fade(Color(0.02, 0.04, 0.06, 0.6), d), 0.0, Vector2(6, 10), 16)
		blob(u, d, r, r * 0.97, fade(Color(0.2, 0.15, 0.32), d), 0.0, Vector2.ZERO, 18)
		blob(u, d, r * 0.78, r * 0.75, fade(Color(0.3, 0.23, 0.46), d), 0.0, Vector2(-r * 0.05, -r * 0.07), 18)
		for j in 14:
			var a := TAU * j / 14.0 + rng.randf_range(-0.1, 0.1)
			var v := Vector2.from_angle(a)
			stroke(PackedVector2Array([Vector2(u, d) + v * r * 0.3, Vector2(u, d) + v * r * 0.92]), 2.0, 2.0, fade(Color(0.12, 0.09, 0.2, 0.6), d))
		for j in rng.randi_range(3, 6):
			var a2 := rng.randf() * TAU
			var rr := r * rng.randf_range(0.1, 0.62)
			blob(u + cos(a2) * rr, d + sin(a2) * rr, r * rng.randf_range(0.07, 0.14), r * 0.08, fade(Color(0.72, 0.66, 0.92, 0.85), d), 0.0, Vector2.ZERO, 8)
	# Spores qui luisent.
	for k in 40:
		var u := rng.randf_range(u0, u1)
		var d := depth(40.0, 1400.0)
		if ok(u, d, 6.0):
			var s := rng.randf_range(2.0, 5.0)
			blob(u, d, s * 3.0, s * 3.0, fade(Color(glow, 0.1), d), 0.0, Vector2.ZERO, 8)
			blob(u, d, s, s, fade(Color(glow, 0.7), d), 0.0, Vector2.ZERO, 6)


# --- Vent : le bord d'un plateau, la mer de nuages ---

func _plateau() -> void:
	# Mer de nuages : bancs allongés le long du bord.
	for k in 22:
		var u := rng.randf_range(u0, u1)
		var d := depth(140.0, 1700.0)
		var rx := rng.randf_range(160.0, 480.0)
		if ok(u, d, 0.0):
			blob(u, d, rx, rx * rng.randf_range(0.09, 0.17), Color(glow, rng.randf_range(0.05, 0.14) * (1.0 - d / 2400.0)), rng.randf_range(-0.06, 0.06), Vector2.ZERO, 14)
	# Rochers flottants : éclat de roche, face éclairée, ombre portée sur les nuages.
	for k in 4:
		var u := rng.randf_range(u0, u1)
		var d := depth(380.0, 1450.0)
		var r := rng.randf_range(34.0, 90.0)
		if not ok(u, d, r):
			continue
		var pts := PackedVector2Array()
		var n := rng.randi_range(6, 8)
		for i in n:
			var a := TAU * i / n
			pts.append(Vector2(u, d) + Vector2.from_angle(a) * r * rng.randf_range(0.65, 1.1))
		blob(u, d, r * 1.1, r * 0.7, fade(Color(0.02, 0.03, 0.05, 0.4), d), 0.0, Vector2(18, 34), 12)
		poly(pts, fade(Color(0.2, 0.23, 0.29), d))
		var top := PackedVector2Array()
		for i in 3:
			top.append(pts[i] * 0.88 + Vector2(u, d) * 0.12)
		top.append(Vector2(u, d))
		poly(top, fade(Color(0.42, 0.47, 0.54), d), Vector2(-4, -4))
	# Traînées de vent : fines lignes ondulées.
	for k in 22:
		var u := rng.randf_range(u0, u1)
		var d := depth(60.0, 1500.0)
		var len := rng.randf_range(180.0, 420.0)
		if not ok(u, d, len * 0.5):
			continue
		var path := PackedVector2Array()
		for i in 8:
			var t := float(i) / 7.0
			path.append(Vector2(u + (t - 0.5) * len, d + sin(t * TAU + u) * 8.0))
		stroke(path, 1.0, 3.0 if rng.randf() < 0.5 else 1.5, fade(Color(glow, 0.16), d))
	# Le bord du plateau lui-même : une lèvre de roche en dents, une ombre sur la chute.
	var lip := _cliff(Color(0.18, 0.2, 0.25), Color(0.5, 0.55, 0.62, 0.8), Color(0.1, 0.11, 0.15, 0.7), 34.0, 96.0, 42.0)
	_shadow_below(lip, 110.0, Color(0.02, 0.03, 0.05, 0.6))


## Lèvre de falaise le long du bord du monde : une bande de roche aux dents irrégulières (hauteur entre
## lo et hi), son arête claire et ses stries ; seulement là où la région tient le bord. Renvoie la ligne
## de crête (repère du côté).
func _cliff(fill: Color, edge: Color, stria: Color, lo: float, hi: float, step: float) -> PackedVector2Array:
	var lip := PackedVector2Array()
	var x := u0
	while x <= u1 + 0.1:
		lip.append(Vector2(x, rng.randf_range(lo, hi)))
		x += step
	for i in lip.size() - 1:
		var p: Vector2 = lip[i]
		var q: Vector2 = lip[i + 1]
		if not ok((p.x + q.x) * 0.5, 40.0, 0.0):
			continue
		poly(PackedVector2Array([Vector2(p.x, 0.0), p, q, Vector2(q.x, 0.0)]), fill)
		stroke(PackedVector2Array([p, q]), 3.0, 3.0, edge, Vector2(0, -2))
		stroke(PackedVector2Array([p + Vector2(0, -14.0), p * 0.4 + Vector2(0, -14.0)]), 2.0, 1.0, stria)
	return lip


## Bande d'ombre sous une ligne de crête (repère du côté), de hauteur h.
func _shadow_below(line: PackedVector2Array, h: float, col: Color) -> void:
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var c: Vector2 = line[i + 1]
		if not ok((a.x + c.x) * 0.5, 40.0, 0.0):
			continue
		b.draw_primitive(PackedVector2Array([P(a.x, a.y), P(c.x, c.y), P(c.x, c.y + h), P(a.x, a.y + h)]), PackedColorArray([col, col, Color(col, 0.0), Color(col, 0.0)]))


# --- Sève : la vallée vue d'en haut ---

func _vallee() -> void:
	# Brume verte.
	for k in 9:
		var u := rng.randf_range(u0, u1)
		var d := depth(120.0, 1600.0)
		var rx := rng.randf_range(220.0, 520.0)
		if ok(u, d, 0.0):
			blob(u, d, rx, rx * 0.35, Color(glow, 0.04), rng.randf_range(-0.4, 0.4), Vector2.ZERO, 12)
	# Cimes touffues : des couronnes rondes par grappes, plus claires du côté de la lumière.
	for k in 52:
		var u := rng.randf_range(u0, u1)
		var d := depth(30.0, 1700.0, 1.25)
		var r := rng.randf_range(34.0, 96.0) * (1.0 + d / 2200.0)
		if not ok(u, d, r):
			continue
		var dark := Color(0.07, 0.17, 0.13).lerp(Color(0.1, 0.22, 0.16), rng.randf())
		blob(u, d, r * 1.05, r * 1.0, fade(Color(0.02, 0.05, 0.04, 0.55), d), 0.0, Vector2(6, 9), 14)
		blob(u, d, r, r * 0.95, fade(dark, d), 0.0, Vector2.ZERO, 16)
		blob(u, d, r * 0.7, r * 0.62, fade(dark.lightened(0.18), d), 0.0, Vector2(-r * 0.12, -r * 0.16), 14)
		blob(u, d, r * 0.3, r * 0.26, fade(dark.lightened(0.34), d), 0.0, Vector2(-r * 0.22, -r * 0.28), 10)
	# Fils de sève : traînées lumineuses qui serpentent entre les cimes.
	for k in 7:
		var u := rng.randf_range(u0, u1)
		var d := depth(80.0, 1100.0)
		var len := rng.randf_range(200.0, 420.0)
		var ang := rng.randf() * TAU
		if not ok(u, d, 40.0):
			continue
		var path := wander(Vector2(u, d), Vector2(u, d) + Vector2.from_angle(ang) * len, 7, len * 0.25)
		stroke(path, 12.0, 6.0, fade(Color(glow, 0.07), d))
		stroke(path, 3.5, 1.5, fade(Color(glow, 0.55), d))
		for j in 3:
			var q: Vector2 = path[rng.randi_range(1, path.size() - 2)]
			blob(q.x, q.y, 3.0, 3.0, fade(Color(1, 1, 0.8, 0.9), d), 0.0, Vector2.ZERO, 6)
	# Le haut de la vallée : une haie de mousse et de pierres moussues le long du bord.
	for k in 24:
		var u := rng.randf_range(u0, u1)
		var d := rng.randf_range(10.0, 80.0)
		var r := rng.randf_range(26.0, 50.0)
		if ok(u, d, r):
			blob(u, d, r, r * 0.7, Color(0.16, 0.25, 0.18), rng.randf() * PI, Vector2.ZERO, 10)
			blob(u, d, r * 0.6, r * 0.42, Color(0.26, 0.38, 0.25), rng.randf() * PI, Vector2(-3, -4), 10)


# --- Aube : le ciel de verre ---

func _aube() -> void:
	# Lueurs d'aube : de grandes nappes dorées, plus fortes près du bord.
	for k in 9:
		var u := rng.randf_range(u0, u1)
		var d := depth(100.0, 1100.0)
		var rx := rng.randf_range(260.0, 560.0)
		if ok(u, d, 0.0):
			blob(u, d, rx, rx * 0.5, Color(glow, 0.1 * (1.0 - d / 1500.0)), rng.randf_range(-0.5, 0.5), Vector2.ZERO, 12)
	# Rayons : de fins éventails qui s'ouvrent vers le large.
	for k in 8:
		var u := rng.randf_range(u0, u1)
		var d := rng.randf_range(80.0, 400.0)
		var len := rng.randf_range(500.0, 1000.0)
		var spread := rng.randf_range(40.0, 110.0)
		if ok(u, d, spread):
			var tilt := rng.randf_range(-0.25, 0.25) * len
			poly(PackedVector2Array([Vector2(u - 4.0, d), Vector2(u + 4.0, d), Vector2(u + tilt + spread, d + len), Vector2(u + tilt - spread, d + len)]), Color(glow, 0.06))
	# Éclats de verre qui flottent : losanges, une face claire, une face sombre.
	for k in 20:
		var u := rng.randf_range(u0, u1)
		var d := depth(240.0, 1700.0, 1.1)
		var r := rng.randf_range(14.0, 50.0)
		if not ok(u, d, r):
			continue
		var rot := rng.randf() * TAU
		var v := Vector2.from_angle(rot)
		var o := v.orthogonal()
		var a := Vector2(u, d) + v * r
		var c := Vector2(u, d) - v * r
		var l := Vector2(u, d) + o * r * 0.38
		var rr := Vector2(u, d) - o * r * 0.38
		poly(PackedVector2Array([a, l, c]), fade(Color(0.24, 0.35, 0.42), d))
		poly(PackedVector2Array([a, c, rr]), fade(Color(0.74, 0.87, 0.92), d))
		stroke(PackedVector2Array([a, c]), 1.5, 1.5, fade(Color(0.95, 0.99, 1.0, 0.9), d))
		if rng.randf() < 0.4:
			blob(u, d, r * 1.3, r * 1.3, fade(Color(glow, 0.05), d), 0.0, Vector2.ZERO, 8)
	# Le bord de la falaise : une lèvre de calcaire pâle, hérissée d'aiguilles de verre.
	var lip := _cliff(Color(0.55, 0.52, 0.44), Color(0.88, 0.84, 0.7, 0.9), Color(0.32, 0.3, 0.26, 0.6), 30.0, 80.0, 50.0)
	_shadow_below(lip, 150.0, Color(0.16, 0.12, 0.08, 0.5))
	for i in range(1, lip.size() - 1, 2):
		var base: Vector2 = lip[i]
		if rng.randf() < 0.65 and ok(base.x, base.y, 20.0):
			var hgt := rng.randf_range(50.0, 190.0)
			var wid := rng.randf_range(8.0, 18.0)
			var lean := rng.randf_range(-0.35, 0.35) * hgt
			var tip := base + Vector2(lean, hgt)
			poly(PackedVector2Array([base + Vector2(-wid, 0), base + Vector2(wid, 0), tip]), Color(0.25, 0.35, 0.42), Vector2(7, 9))
			poly(PackedVector2Array([base + Vector2(-wid, 0), base, tip]), Color(0.45, 0.58, 0.64))
			poly(PackedVector2Array([base, base + Vector2(wid, 0), tip]), Color(0.82, 0.92, 0.96))
			stroke(PackedVector2Array([base, tip]), 1.5, 1.0, Color(1, 1, 1, 0.85))


# --- Racine : la forêt pétrifiée ---

func _racines() -> void:
	# Troncs de pierre : une coupe ronde, des cernes, des fentes.
	for k in 5:
		var u := rng.randf_range(u0, u1)
		var d := depth(380.0, 1500.0)
		var r := rng.randf_range(70.0, 170.0) * (1.0 + d / 2400.0)
		if not ok(u, d, r):
			continue
		blob(u, d, r * 1.05, r, fade(Color(0.03, 0.025, 0.02, 0.6), d), 0.0, Vector2(8, 12), 18)
		blob(u, d, r, r * 0.97, fade(Color(0.25, 0.23, 0.2), d), 0.0, Vector2.ZERO, 20)
		blob(u, d, r * 0.8, r * 0.77, fade(Color(0.33, 0.3, 0.26), d), 0.0, Vector2(-r * 0.04, -r * 0.05), 20)
		for j in 3:
			var rr := r * (0.28 + j * 0.2)
			var ring := PackedVector2Array()
			for i in 17:
				var a := TAU * i / 16.0
				ring.append(Vector2(u, d) + Vector2.from_angle(a) * rr)
			stroke(ring, 2.0, 2.0, fade(Color(0.16, 0.14, 0.11, 0.6), d))
		var ca := rng.randf() * TAU
		stroke(wander(Vector2(u, d), Vector2(u, d) + Vector2.from_angle(ca) * r * 0.95, 4, r * 0.2), 4.0, 1.0, fade(Color(0.07, 0.06, 0.05, 0.9), d))
		for j in 3:
			var ang := rng.randf() * TAU
			blob(u + cos(ang) * r * 0.6, d + sin(ang) * r * 0.6, 9.0, 6.0, fade(Color(glow, 0.45), d), ang, Vector2.ZERO, 8)
	# Racines géantes : épaisses au loin, fines là où elles viennent mourir au bord du monde.
	for k in 9:
		var u := rng.randf_range(u0, u1)
		var d0 := depth(80.0, 700.0)
		if not ok(u, d0, 60.0):
			continue
		var far_pt := Vector2(u, d0) + Vector2(rng.randf_range(-260.0, 260.0), rng.randf_range(420.0, 900.0))
		var path := wander(Vector2(u, d0), far_pt, 7, 120.0)
		var w1 := rng.randf_range(34.0, 62.0) * (1.0 + far_pt.y / 3000.0)
		stroke(path, 6.0, w1 + 10.0, fade(Color(0.02, 0.015, 0.01, 0.6), far_pt.y), Vector2(5, 9))
		stroke(path, 5.0, w1, fade(Color(0.2, 0.15, 0.11), far_pt.y))
		stroke(path, 2.0, w1 * 0.4, fade(Color(0.36, 0.27, 0.19), far_pt.y), Vector2(-w1 * 0.12, -w1 * 0.12))
		# Radicelles.
		for i in range(1, path.size() - 1):
			if rng.randf() < 0.55:
				var side_v := (path[i + 1] - path[i - 1]).normalized().orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
				var q: Vector2 = path[i]
				stroke(wander(q, q + side_v * rng.randf_range(50.0, 130.0), 3, 14.0), 5.0, 1.0, fade(Color(0.24, 0.18, 0.13), q.y))
	# Aiguilles de pierre, au bord.
	for k in 18:
		var u := rng.randf_range(u0, u1)
		var d := rng.randf_range(12.0, 160.0)
		if ok(u, d, 20.0):
			var hgt := rng.randf_range(30.0, 90.0)
			var wid := rng.randf_range(7.0, 15.0)
			poly(PackedVector2Array([Vector2(u - wid, d), Vector2(u + wid, d), Vector2(u + rng.randf_range(-12.0, 12.0), d + hgt)]), Color(0.3, 0.28, 0.25), Vector2(-3, -3))
			poly(PackedVector2Array([Vector2(u, d), Vector2(u + wid, d), Vector2(u + rng.randf_range(-12.0, 12.0), d + hgt)]), Color(0.18, 0.16, 0.14))
