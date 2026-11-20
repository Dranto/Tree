## Dessins de la branche Racine, selon la charte (élément « racine » : couleur #857a44, motif
## « nœuds » ; bois sombre, mousse claire) : signatures des compétences (bouclier d'écorce, ancrage,
## pieux), coup de massue, secousse, aubier, icônes. Purement visuel : la logique est dans
## scripts/skills/ et attack.gd.
##
## skill_fx.gd et attack_fx.gd confient à RacineFx les signatures qu'il connaît (draws / draw) ;
## Art._icon_body lui confie les icônes de Racine (icon). Les dessins sont statiques (instant
## e["t"]) : la galerie les fige. Les polygones restent convexes et jamais plats (pas d'échec de
## triangulation) : les plaques et les pieux sont des quadrilatères ou des triangles de taille sûre.
class_name RacineFx
extends RefCounted

## Durée par défaut de chaque signature (secondes) ; l'écorce, l'ancrage et les pieux donnent la leur.
const DUREE := {
	"ecorce": 5.0, "ecorce_eclat": 0.5, "ecorce_riposte": 0.25,
	"ancrage": 3.0, "ancrage_arrache": 0.55, "pieu": 0.55,
	"massue": 0.32, "secousse": 0.4, "aubier": 0.35,
}
## Icônes de Racine : compétences, puis formes de l'attaque.
const ICONES_COMPETENCES := ["ecorce", "ancrage", "pieux"]
const ICONES_ATTAQUES := ["attaque_massue"]
## Bois de l'écorce (plus chaud que l'élément) et pierre de la forêt pétrifiée.
const BOIS := Color("6b5232")
const PIERRE := Color("8d8a7c")


static func draws(id: String) -> bool:
	return DUREE.has(id)


## Joue le son « id » s'il existe (la tâche « son » peut l'ajouter), sinon « fallback ».
static func sound(id: String, fallback: String, pos := Vector2.INF) -> void:
	var loop = Engine.get_main_loop()
	var sfx = loop.root.get_node_or_null("Sfx") if loop is SceneTree else null
	if sfx != null:
		sfx.play(id if sfx.streams.has(id) else fallback, pos)


## Dessine la signature id à son instant (e["t"], e["dur"]). on_ground : partie au sol (sous les
## acteurs) ou au-dessus.
static func draw(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var k: float = clampf(e["t"] / maxf(e["dur"], 0.001), 0.0, 1.0)
	match e["id"]:
		"ecorce":
			_ecorce(ci, e, on_ground)
		"ecorce_eclat":
			_ecorce_eclat(ci, e, k, on_ground)
		"ecorce_riposte":
			if not on_ground:
				_riposte(ci, e, k)
		"ancrage":
			_ancrage(ci, e, on_ground)
		"ancrage_arrache":
			_arrache(ci, e, k, on_ground)
		"pieu":
			_pieu(ci, e, on_ground)
		"massue":
			_massue(ci, e, k, on_ground)
		"secousse":
			_secousse(ci, e, k, on_ground)
		"aubier":
			if not on_ground:
				_aubier(ci, e, k)


# --- Outils de dessin ---

## Plaque d'écorce : un morceau d'anneau (de l'angle a0 à a1, entre les rayons r0 et r1) fendu
## de deux sillons clairs. Quadrilatère convexe tant que a1 - a0 < PI.
static func plaque(ci: CanvasItem, c: Vector2, r0: float, r1: float, a0: float, a1: float, col: Color, sillon: Color) -> void:
	if r1 - r0 < 1.0 or a1 - a0 < 0.05:
		return
	var steps := 4
	var pts := PackedVector2Array()
	for i in steps + 1:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / steps)) * r1)
	for i in steps + 1:
		pts.append(c + Vector2.from_angle(lerpf(a1, a0, float(i) / steps)) * r0)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(Art.c("contour"), col.a * 0.9), Art.TRAIT_FIN, true)
	for j in 2:
		var a := lerpf(a0, a1, 0.33 + 0.34 * j)
		ci.draw_line(c + Vector2.from_angle(a) * (r0 + 2.0), c + Vector2.from_angle(a) * (r1 - 2.0), sillon, 1.0, true)


## Racine qui court au sol de « from » vers « to » : un trait qui s'amincit, ondulé, avec des nœuds
## (motif de l'élément) ; « grow » de 0 à 1 la fait pousser.
static func racine(ci: CanvasItem, from: Vector2, to: Vector2, w: float, grow: float, seed: float, a := 1.0) -> void:
	var d := to - from
	var l := d.length()
	if l < 4.0 or grow <= 0.01:
		return
	var dir := d / l
	var n := dir.orthogonal()
	var steps := 8
	var prev := from
	var sombre := Art.ec("racine", "sombre")
	var col := Art.ec("racine")
	for i in range(1, steps + 1):
		var q := float(i) / steps * grow
		var wave := sin(q * 7.0 + seed) * 7.0 * sin(PI * q)
		var at := from + dir * l * q + n * wave
		var ww := maxf(1.0, w * (1.0 - 0.75 * q))
		ci.draw_line(prev, at, Color(sombre, a), ww + 2.0, true)
		ci.draw_line(prev, at, Color(col, a), ww, true)
		if i % 3 == 0:
			ci.draw_circle(at, ww * 0.75 + 1.0, Color(sombre, a))
		prev = at
	ci.draw_circle(prev, maxf(1.0, w * 0.2), Color(Art.ec("racine", "clair"), 0.7 * a))


## Pieu de bois : une pointe taillée (triangle) sur un fût (quadrilatère), ombré d'un côté.
static func pieu(ci: CanvasItem, base: Vector2, h: float, w: float, lean: float, a := 1.0) -> void:
	if h < 3.0 or w < 1.5:
		return
	var up := Vector2(sin(lean), -cos(lean))
	var side := Vector2(-up.y, up.x)
	var top := base + up * h * 0.72
	var tip := base + up * h
	var body := PackedVector2Array([base - side * w, base + side * w, top + side * w * 0.9, top - side * w * 0.9])
	var head := PackedVector2Array([top - side * w * 0.9, top + side * w * 0.9, tip])
	ci.draw_colored_polygon(body, Color(BOIS, a))
	ci.draw_colored_polygon(PackedVector2Array([base, base + side * w, top + side * w * 0.9, top]), Color(Art.ec("racine", "sombre"), a))
	ci.draw_colored_polygon(head, Color(Art.ec("epine", "clair").darkened(0.15), a))
	ci.draw_polyline(PackedVector2Array([base - side * w, top - side * w * 0.9, tip, top + side * w * 0.9, base + side * w]),
		Color(Art.c("contour"), 0.9 * a), Art.TRAIT_FIN, true)
	# Un nœud du bois et une touche de mousse.
	ci.draw_circle(base + up * h * 0.38 - side * w * 0.3, w * 0.22, Color(Art.ec("racine", "sombre"), a))
	ci.draw_circle(base + up * h * 0.12 + side * w * 0.4, w * 0.25, Color(Art.ec("racine", "clair"), 0.8 * a))


# --- Compétences ---

## Bouclier d'écorce : des plaques d'écorce tournent lentement autour du héros, d'autant moins
## nombreuses que le bouclier s'use (e["part"]). Au sol, une ombre brune.
static func _ecorce(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 28.0)
	var t: float = e["t"]
	var part: float = clampf(float(e.get("part", 1.0)), 0.0, 1.0)
	var appear := Anim.pop(clampf(t / 0.25, 0.0, 1.0))
	var c := p + Vector2(0, -r * 0.2)
	if on_ground:
		ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, r * 0.35), r * 1.1 * appear + 1.0, r * 0.45 * appear + 1.0, 20), Color(BOIS, 0.25))
		return
	var plates := 3 + int(round(4.0 * part))
	var span := TAU / 7.0 * 0.82
	var col := BOIS.lightened(0.1)
	var sillon := Color(Art.ec("racine", "clair"), 0.8)
	for i in plates:
		var a0 := i * TAU / 7.0 + t * 0.5 + float(e.get("seed", 0)) * 0.01
		plaque(ci, c, r * 0.95 * appear, r * 1.3 * appear, a0, a0 + span, Color(col, 0.75 + 0.2 * part), sillon)
	# Reflet de mousse qui glisse sur la carapace.
	var ga := t * 1.3
	ci.draw_arc(c, r * 1.35 * appear, ga, ga + 0.5, 6, Color(Art.ec("racine", "clair"), 0.5 * part), 2.0, true)


## Éclatement de l'écorce : les plaques s'envolent en étoile et retombent, un anneau brun s'élargit.
static func _ecorce_eclat(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 150.0)
	var a := 1.0 - k
	var g := Anim.ease_out(k)
	if on_ground:
		ci.draw_circle(p, r * g + 1.0, Color(BOIS, 0.18 * a))
		return
	ci.draw_arc(p, r * g, 0.0, TAU, 40, Color(Art.ec("racine", "clair"), 0.8 * a), 2.0 + 4.0 * a, true)
	for i in 7:
		var ang := i * TAU / 7.0 + float(e.get("seed", 0)) * 0.01
		var at := p + Vector2.from_angle(ang) * r * 0.75 * g
		plaque(ci, at, 4.0, 4.0 + 8.0 * a + 3.0, ang - 0.35, ang + 0.35, Color(BOIS, a), Color(Art.ec("racine", "clair"), a))


## Riposte de l'écorce : trois échardes filent du héros vers l'agresseur.
static func _riposte(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var from: Vector2 = e["pos"]
	var to: Vector2 = e.get("to", from + Vector2.RIGHT * 60.0)
	var d := to - from
	if d.length() < 2.0:
		return
	var dir := d.normalized()
	for i in 3:
		var q := clampf(k * 1.3 - i * 0.15, 0.0, 1.0)
		if q <= 0.0 or q >= 1.0:
			continue
		var at := from.lerp(to, q) + dir.orthogonal() * (i - 1) * 6.0
		var n := dir.orthogonal()
		ci.draw_colored_polygon(PackedVector2Array([at + dir * 9.0, at - dir * 6.0 + n * 2.5, at - dir * 6.0 - n * 2.5]), Art.ec("epine", "clair"))


## Ancrage : au sol, des racines courent du héros jusqu'au bord de la zone et un cercle de terre
## remuée pulse à chaque à-coup ; au-dessus, des racines enserrent les pieds du héros.
static func _ancrage(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 190.0)
	var t: float = e["t"]
	var dur: float = e["dur"]
	var grow := Anim.ease_out(clampf(t / 0.35, 0.0, 1.0))
	var fade := 1.0 - clampf((t - (dur - 0.35)) / 0.35, 0.0, 1.0)
	var seed := float(e.get("seed", 0))
	if on_ground:
		ci.draw_circle(p, r * grow + 1.0, Color(Art.ec("racine", "sombre"), 0.16 * fade))
		var pulse := fmod(t, 0.5) / 0.5
		ci.draw_arc(p, r * (0.6 + 0.4 * pulse) * grow, 0.0, TAU, 40, Color(Art.ec("racine"), 0.35 * (1.0 - pulse) * fade), 3.0, true)
		ci.draw_arc(p, r * grow, 0.0, TAU, 48, Color(Art.ec("racine", "clair"), 0.45 * fade), 2.0, true)
		for i in 9:
			var ang := i * TAU / 9.0 + seed * 0.37
			var len := r * (0.75 + 0.25 * sin(seed + i * 2.1))
			racine(ci, p, p + Vector2.from_angle(ang) * len, 7.0, grow * fade, seed + i, fade)
		return
	# Racines autour des pieds : trois arcs qui montent sur le héros.
	for i in 3:
		var a0 := PI * 0.15 + i * 0.35
		ci.draw_arc(p + Vector2(0, 6), 13.0 + i * 2.0, a0, a0 + PI * 0.7 * grow, 8, Color(Art.ec("racine", "sombre"), 0.95 * fade), 4.0, true)
		ci.draw_arc(p + Vector2(0, 6), 13.0 + i * 2.0, a0, a0 + PI * 0.7 * grow, 8, Color(Art.ec("racine"), fade), 2.2, true)


## Arrachement (mutation de l'ancrage) : la terre se fend en étoile, des mottes volent.
static func _arrache(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 190.0)
	var a := 1.0 - k
	var g := Anim.ease_out(k)
	var seed := float(e.get("seed", 0))
	if on_ground:
		for i in 7:
			var ang := i * TAU / 7.0 + seed * 0.1
			var tip := p + Vector2.from_angle(ang) * r * (0.5 + 0.5 * g)
			ci.draw_line(p, tip, Color(Art.ec("racine", "sombre"), 0.8 * a), 4.0 * a + 1.0, true)
		return
	ci.draw_arc(p, r * g, 0.0, TAU, 40, Color(Art.ec("racine", "clair"), 0.85 * a), 3.0 + 3.0 * a, true)
	for i in 10:
		var ang := i * TAU / 10.0 + seed * 0.2
		var at := p + Vector2.from_angle(ang) * r * 0.8 * g + Vector2(0, -sin(PI * k) * 26.0)
		ci.draw_circle(at, 4.0 * a + 1.5, Color(PIERRE.darkened(0.2), a))


## Pieu : la terre se fend (au sol), puis un grand pieu et deux petits jaillissent, tiennent,
## et redescendent dans les 0,2 dernières secondes.
static func _pieu(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 46.0)
	var t: float = e["t"]
	var dur: float = e["dur"]
	var seed := float(e.get("seed", 0))
	var rise := Anim.pop(clampf(t / 0.12, 0.0, 1.0))
	var sink := clampf((t - (dur - 0.2)) / 0.2, 0.0, 1.0)
	var h := rise * (1.0 - sink)
	if on_ground:
		var a := 1.0 - sink
		ci.draw_colored_polygon(Art.ellipse(p, r * 0.8 + 1.0, r * 0.35 + 1.0, 16), Color(Art.ec("racine", "sombre"), 0.35 * a))
		for i in 4:
			var ang := seed * 0.3 + i * TAU / 4.0
			ci.draw_line(p, p + Vector2(cos(ang) * r * 0.9, sin(ang) * r * 0.4), Color(Art.ec("racine", "sombre"), 0.7 * a), 2.0, true)
		# Onde de choc au jaillissement.
		if t < 0.25:
			var q := t / 0.25
			ci.draw_arc(p, r * (0.4 + 0.8 * q), 0.0, TAU, 24, Color(Art.ec("racine", "clair"), 0.6 * (1.0 - q)), 2.5, true)
		return
	if h <= 0.02:
		return
	var big := r * 1.35
	pieu(ci, p + Vector2(-r * 0.32, r * 0.08), big * 0.55 * h, r * 0.11, -0.35 + sin(seed) * 0.08)
	pieu(ci, p + Vector2(r * 0.34, r * 0.1), big * 0.6 * h, r * 0.12, 0.3 + cos(seed) * 0.08)
	pieu(ci, p + Vector2(0, r * 0.15), big * h, r * 0.17, sin(seed * 1.7) * 0.1)


## Coup de massue : un secteur brun balayé, la massue (manche et tête noueuse) au bout de l'arc,
## et à la fin un nuage de poussière et de cailloux à l'impact.
static func _massue(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var dir: Vector2 = e.get("dir", Vector2.RIGHT)
	var r: float = e.get("r", 150.0)
	var arc: float = e.get("arc", 1.7)
	var flip := -1.0 if e.get("flip", false) else 1.0
	var sweep := Anim.ease_in(clampf(k / 0.55, 0.0, 1.0))
	var a0 := dir.angle() - flip * arc / 2.0
	var head := a0 + flip * arc * sweep
	var fade := 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
	if on_ground:
		var wedge := PackedVector2Array([p])
		var steps := maxi(4, int(arc * 8.0))
		for i in steps + 1:
			wedge.append(p + Vector2.from_angle(lerpf(a0, head, float(i) / steps)) * r)
		if absf(head - a0) > 0.05:
			ci.draw_colored_polygon(wedge, Color(Art.ec("racine"), 0.14 * fade))
		if k > 0.5:
			var q := (k - 0.5) / 0.5
			var at := p + Vector2.from_angle(head) * r * 0.8
			ci.draw_colored_polygon(Art.ellipse(at, 18.0 + 22.0 * q, 8.0 + 10.0 * q, 14), Color(PIERRE, 0.35 * (1.0 - q)))
		return
	var hand := p + Vector2.from_angle(head) * r * 0.25
	var tip := p + Vector2.from_angle(head) * r * 0.82
	var d := (tip - hand).normalized()
	var n := d.orthogonal()
	if e.get("empowered", false):
		ci.draw_line(hand, tip, Color(Art.c("or"), 0.8 * fade), 12.0, true)
	ci.draw_line(hand, tip, Color(Art.c("contour"), 0.9 * fade), 7.0, true)
	ci.draw_line(hand, tip, Color(BOIS, fade), 4.5, true)
	# Tête noueuse : un gros nœud ovale et deux bosses.
	var hr := 13.0 + (5.0 if e.get("empowered", false) else 0.0)
	ci.draw_colored_polygon(Art.ellipse(tip, hr + 2.0, hr * 0.8 + 2.0, 14), Color(Art.c("contour"), 0.9 * fade))
	ci.draw_colored_polygon(Art.ellipse(tip, hr, hr * 0.8, 14), Color(BOIS.lightened(0.08), fade))
	ci.draw_circle(tip + n * hr * 0.55 + d * 2.0, hr * 0.35, Color(Art.ec("racine", "sombre"), fade))
	ci.draw_circle(tip - n * hr * 0.4 - d * 3.0, hr * 0.28, Color(Art.ec("racine", "sombre"), fade))
	ci.draw_circle(tip + d * hr * 0.3, hr * 0.22, Color(Art.ec("racine", "clair"), 0.85 * fade))
	# Traînée de l'arc, épaisse et sourde.
	ci.draw_arc(p, r * 0.82, head - flip * 0.45 * sweep, head, 8, Color(Art.ec("racine", "clair"), 0.45 * fade), 5.0, true)
	if k > 0.5:
		var q := (k - 0.5) / 0.5
		for i in 5:
			var ang := head + (i - 2) * 0.35
			ci.draw_circle(tip + Vector2.from_angle(ang) * (10.0 + 26.0 * q) + Vector2(0, -sin(PI * q) * 12.0), 2.5 * (1.0 - q) + 1.0,
				Color(PIERRE.darkened(0.1), 1.0 - q))


## Secousse : un anneau de terre soulevée et quelques cailloux au point d'impact.
static func _secousse(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 80.0)
	var a := 1.0 - k
	var g := Anim.ease_out(k)
	if on_ground:
		ci.draw_colored_polygon(Art.ellipse(p, r * g + 1.0, r * 0.5 * g + 1.0, 20), Color(Art.ec("racine", "sombre"), 0.25 * a))
		ci.draw_polyline(Art.ellipse(p, r * g + 1.0, r * 0.5 * g + 1.0, 20), Color(Art.ec("racine", "clair"), 0.6 * a), 2.0, true)
		return
	for i in 6:
		var ang := i * TAU / 6.0 + 0.4
		var at := p + Vector2(cos(ang) * r * 0.7 * g, sin(ang) * r * 0.35 * g - sin(PI * k) * 18.0)
		ci.draw_circle(at, 3.0 * a + 1.0, Color(PIERRE, a))


## Aubier : un éclat d'écorce se referme un instant sur le héros (le bouclier se remplit).
static func _aubier(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"] + Vector2(0, -4)
	var a := 1.0 - k
	ci.draw_arc(p, 20.0 + 6.0 * k, 0.0, TAU, 24, Color(Art.ec("racine", "clair"), 0.7 * a), 2.0, true)
	for i in 4:
		var a0 := i * TAU / 4.0 + k
		plaque(ci, p, 18.0, 23.0, a0, a0 + 0.8, Color(BOIS, 0.7 * a), Color(Art.ec("racine", "clair"), 0.6 * a))


# --- Icônes ---

## Dessine l'icône de Racine id (voir Art.icon) ; faux si id n'en est pas une.
static func icon(ci: CanvasItem, id: String, p: Vector2, s: float, col: Color, clair: Color, sombre: Color, lw: float) -> bool:
	var relief := col == sombre
	var P := func(x: float, y: float) -> Vector2: return p + Vector2(x, y) * s
	match id:
		"ecorce":
			# Un écu d'écorce : pointe en bas, deux sillons, un nœud clair.
			var shield := PackedVector2Array([P.call(-0.7, -0.7), P.call(0.7, -0.7), P.call(0.68, 0.05), P.call(0.0, 0.82), P.call(-0.68, 0.05)])
			ci.draw_colored_polygon(shield, col)
			var groove := sombre if not relief else col.darkened(0.4)
			ci.draw_line(P.call(-0.28, -0.55), P.call(-0.22, 0.45), groove, lw * 0.8, true)
			ci.draw_line(P.call(0.25, -0.55), P.call(0.2, 0.4), groove, lw * 0.8, true)
			ci.draw_circle(P.call(0.0, -0.1), s * 0.14, col if relief else clair)
		"ancrage":
			# Une souche trapue d'où partent trois racines.
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.38, -0.65), P.call(0.38, -0.65), P.call(0.48, 0.25), P.call(-0.48, 0.25)]), col)
			for x in [-0.75, 0.0, 0.75]:
				ci.draw_line(P.call(x * 0.45, 0.2), P.call(x, 0.78), col, lw * 1.4, true)
			ci.draw_arc(P.call(0, -0.62), s * 0.22, 0.0, PI, 8, sombre if not relief else col.darkened(0.4), lw * 0.7, true)
			ci.draw_circle(P.call(0.0, -0.2), s * 0.11, col if relief else clair)
		"pieux":
			# Trois pieux taillés qui sortent d'une ligne de sol.
			for j in 3:
				var x := -0.55 + 0.55 * j
				var h := 0.9 if j == 1 else 0.6
				var w := 0.16 if j == 1 else 0.12
				ci.draw_colored_polygon(PackedVector2Array([P.call(x - w, 0.65), P.call(x + w, 0.65), P.call(x + w, 0.65 - h), P.call(x, 0.65 - h - 0.3), P.call(x - w, 0.65 - h)]), col)
			ci.draw_line(P.call(-0.85, 0.7), P.call(0.85, 0.7), sombre if not relief else col, lw, true)
			if not relief:
				ci.draw_circle(P.call(0.0, -0.4), s * 0.07, clair)
		"attaque_massue":
			# Une massue en diagonale : manche fin, tête noueuse en haut à droite.
			ci.draw_line(P.call(-0.7, 0.7), P.call(0.15, -0.15), col, lw * 1.6, true)
			ci.draw_colored_polygon(Art.ellipse(P.call(0.38, -0.38), s * 0.42, s * 0.34, 14), col)
			ci.draw_circle(P.call(0.6, -0.18), s * 0.14, col)
			ci.draw_circle(P.call(0.18, -0.62), s * 0.12, col)
			if not relief:
				ci.draw_circle(P.call(0.42, -0.42), s * 0.12, clair)
		_:
			return false
	return true
