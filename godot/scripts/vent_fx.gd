## Dessins de la branche Vent, selon la charte (élément « vent » : couleur #a4bcd4, motif « rafales ») :
## lame de vent (projectile), signatures des compétences (tornade, ruée, appel d'air) et de la
## bourrasque, icônes. Purement visuel : la logique est dans scripts/skills/ et attack.gd.
##
## skill_fx.gd et attack_fx.gd confient à VentFx les signatures qu'il connaît (draws / draw) ;
## Art._icon_body lui confie les icônes de Vent (icon). Les dessins sont statiques (instant e["t"]) :
## la galerie les fige.
class_name VentFx
extends RefCounted

## Durée par défaut de chaque signature (secondes) ; la tornade et la ruée donnent la leur.
const DUREE := {"tornade": 3.5, "ruee": 0.4, "appel_air": 0.95, "bourrasque": 0.26}
## Icônes de Vent : compétences, puis formes de l'attaque.
const ICONES_COMPETENCES := ["tornade", "ruee", "appel_air"]
const ICONES_ATTAQUES := ["attaque_lame", "attaque_bourrasque"]


static func draws(id: String) -> bool:
	return DUREE.has(id)


## Dessine la signature id à son instant (e["t"], e["dur"]). on_ground : partie au sol (sous les
## acteurs) ou au-dessus. La bourrasque (attack_fx.gd) n'a qu'une partie, dessinée au-dessus.
static func draw(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var k: float = clampf(e["t"] / maxf(e["dur"], 0.001), 0.0, 1.0)
	match e["id"]:
		"tornade":
			_tornade(ci, e, k, on_ground)
		"ruee":
			_ruee(ci, e, k, on_ground)
		"appel_air":
			_appel_air(ci, e, k, on_ground)
		"bourrasque":
			if not on_ground:
				_bourrasque(ci, e, k)


# --- Projectile ---

## Lame de vent : un croissant clair, bord tranchant devant, deux filets d'air qui le suivent.
## Dessinée vers dir ; le projectile la fait tourner par sa rotation (rien n'est redessiné).
static func draw_lame(ci: CanvasItem, dir: Vector2, r: float) -> void:
	var col := Art.ec("vent")
	var clair := Art.ec("vent", "clair")
	var sombre := Art.ec("vent", "sombre")
	var a0 := dir.angle()
	ci.draw_circle(Vector2.ZERO, r * 2.0, Color(col, 0.14))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 11:
		var a := a0 - 1.35 + 2.7 * i / 10.0
		outer.append(Vector2.from_angle(a) * r * 1.7)
	for i in range(10, -1, -1):
		var a := a0 - 1.1 + 2.2 * i / 10.0
		inner.append(Vector2.from_angle(a) * r * 1.0 + dir * r * 0.15)
	var body := outer.duplicate()
	body.append_array(inner)
	var edge := outer.duplicate()
	ci.draw_colored_polygon(body, col)
	ci.draw_polyline(edge, sombre, maxf(1.5, r * 0.2), true)
	ci.draw_polyline(edge, clair, maxf(1.0, r * 0.12), true)
	# Filets d'air : deux arcs de part et d'autre, comme une rafale enroulée (motif de l'élément).
	for sgn: int in [-1, 1]:
		var c := dir.rotated(sgn * 2.2) * r * 1.2
		ci.draw_arc(c, r * 0.7, a0 + sgn * 1.2, a0 + sgn * 2.6, 6, Color(clair, 0.7), maxf(1.0, r * 0.15), true)


# --- Compétences ---

## Tornade : un entonnoir d'anneaux qui tournent, plus larges en haut ; au sol, une tache de
## poussière soulevée et des stries qui s'enroulent vers l'œil. Elle apparaît en se resserrant et
## se défait à la fin (anneaux qui s'écartent et pâlissent).
static func _tornade(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 70.0)
	var t: float = e["t"]
	var dur: float = e["dur"]
	var col := Art.ec("vent")
	var clair := Art.ec("vent", "clair")
	var sombre := Art.ec("vent", "sombre")
	var appear := Anim.ease_out(clampf(t / 0.3, 0.0, 1.0))
	var fade := clampf((t - (dur - 0.4)) / 0.4, 0.0, 1.0)
	var a := 1.0 - fade
	var spin := t * 7.0 + float(e.get("seed", 0))
	if on_ground:
		ci.draw_colored_polygon(Art.ellipse(p, r * appear, r * 0.5 * appear, 24), Color(sombre, 0.22 * a))
		for i in 5:
			var a0 := spin * 0.6 + i * TAU / 5.0
			var pts := PackedVector2Array()
			for j in 6:
				var q := j / 5.0
				var ang := a0 + q * 1.6
				pts.append(p + Vector2(cos(ang), sin(ang) * 0.5) * r * appear * (1.0 - 0.75 * q))
			ci.draw_polyline(pts, Color(clair, 0.45 * a), Art.TRAIT_FIN, true)
		return
	# Entonnoir : du pied (au sol, étroit) jusqu'au sommet (large), chaque anneau décalé par le vent.
	var rings := 6
	for i in rings:
		var q := i / float(rings - 1)
		var w := r * (0.28 + 0.75 * q) * appear * (1.0 + 0.35 * fade)
		var h := w * 0.32
		var c := p + Vector2(sin(spin * 0.5 + q * 2.4) * r * 0.12, -q * r * 1.05 * appear)
		var al := (0.55 + 0.3 * q) * a
		ci.draw_colored_polygon(Art.ellipse(c, w, h, 18), Color(col, 0.16 * al))
		var s0 := spin + q * 1.3
		ci.draw_arc(c, w, s0, s0 + 2.4, 12, Color(clair, al), Art.TRAIT_FIN + 1.0 - q, true)
		ci.draw_arc(c, w * 0.92, s0 + PI, s0 + PI + 1.6, 10, Color(sombre, 0.6 * al), Art.TRAIT_FIN, true)
	# Débris qui tournent dans l'entonnoir (feuilles mortes et poussière).
	for i in 6:
		var q := fposmod(i * 0.37 + t * 0.6, 1.0)
		var ang := spin * 1.3 + i * 1.7
		var c := p + Vector2(cos(ang) * r * (0.3 + 0.7 * q), -q * r * 1.0 + sin(ang) * r * 0.2 * q) * appear
		ci.draw_circle(c, 2.0 + 1.5 * (1.0 - q), Color(sombre.lightened(0.2), 0.8 * a))


## Ruée : le héros laisse une traînée d'air en fuseau, bordée de rafales, et l'air se referme derrière.
static func _ruee(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var from: Vector2 = e.get("from", e["pos"])
	var to: Vector2 = e["pos"]
	var w: float = e.get("w", 48.0)
	var d := to - from
	if d.length() < 2.0:
		return
	var dir := d.normalized()
	var n := dir.orthogonal()
	var col := Art.ec("vent")
	var clair := Art.ec("vent", "clair")
	var a := 1.0 - Anim.ease_in(k)
	# La queue rattrape la tête : la traînée se referme depuis le départ.
	var tail := from.lerp(to, Anim.ease_in(k))
	if on_ground:
		var pts := PackedVector2Array([tail, to + n * w * 0.6 * a, to + dir * w * 0.4, to - n * w * 0.6 * a])
		Art.safe_polygon(ci, pts, Color(col, 0.2 * a))
		return
	for i in 5:
		var off := (i - 2) / 2.0
		var s := tail.lerp(to, 0.15 + 0.1 * absf(off))
		ci.draw_line(s + n * off * w * 0.5, to - dir * 12.0 + n * off * w * 0.3, Color(clair, (0.8 - 0.25 * absf(off)) * a), 2.0, true)
	for sgn: int in [-1, 1]:
		var c := to - dir * w * 0.3 + n * sgn * w * 0.55
		ci.draw_arc(c, w * 0.3, dir.angle() + sgn * 0.6, dir.angle() + sgn * 2.4, 8, Color(clair, 0.9 * a), Art.TRAIT_FIN + 0.5, true)


## Appel d'air : des bras de vent s'enroulent en spirale vers le centre pendant l'aspiration
## (anticipation), puis l'air éclate en anneau blanc (coup) et retombe (fin).
static func _appel_air(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 230.0)
	var t: float = e["t"]
	var pull: float = e.get("pull", 0.6)
	var col := Art.ec("vent")
	var clair := Art.ec("vent", "clair")
	var sombre := Art.ec("vent", "sombre")
	if t < pull:
		var q := t / pull
		if on_ground:
			ci.draw_circle(p, r, Color(sombre, 0.12 * (1.0 - q * 0.5)))
			ci.draw_arc(p, r, 0.0, TAU, 48, Color(col, 0.5), Art.TRAIT_FIN, true)
			return
		for i in 6:
			var pts := PackedVector2Array()
			for j in 9:
				var s := j / 8.0
				var rad := r * (1.0 - q * 0.7) * (1.0 - 0.8 * s)
				pts.append(p + Vector2.from_angle(i * TAU / 6.0 + s * 2.2 + q * 3.0) * rad)
			ci.draw_polyline(pts, Color(clair, 0.35 + 0.5 * q), Art.TRAIT_FIN + 1.0, true)
		ci.draw_circle(p, 6.0 + 10.0 * q, Color(clair, 0.3 + 0.4 * q))
		return
	var q := clampf((t - pull) / maxf(e["dur"] - pull, 0.01), 0.0, 1.0)
	var a := 1.0 - q
	if on_ground:
		ci.draw_circle(p, r * 0.45 * (0.6 + 0.6 * q), Color(col, 0.18 * a))
		return
	var g := Anim.ease_out(q)
	ci.draw_arc(p, r * 0.45 * (0.3 + 0.9 * g), 0.0, TAU, 40, Color(Art.c("danger_eclair"), 0.8 * a), 2.0 + 6.0 * a, true)
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0 + 0.2)
		Art._gust(ci, p + d * r * 0.45 * (0.5 + 0.7 * g), 18.0 * a + 4.0, Color(clair, a), 2.0)


# --- Attaque de base ---

## Bourrasque : un cône d'air part devant le héros ; trois rafales filent jusqu'au bord, le cône pâlit.
static func _bourrasque(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var dir: Vector2 = e.get("dir", Vector2.RIGHT)
	var r: float = e.get("r", 175.0)
	var arc: float = minf(float(e.get("arc", 1.3)), TAU)
	var col := Art.ec("vent")
	var clair := Art.ec("vent", "clair")
	var g := Anim.ease_out(clampf(k / 0.6, 0.0, 1.0))
	var a := 1.0 - clampf((k - 0.5) / 0.5, 0.0, 1.0)
	var a0 := dir.angle() - arc / 2.0
	var steps := maxi(6, int(arc * 8.0))
	var wedge := PackedVector2Array([p])
	for i in steps + 1:
		wedge.append(p + Vector2.from_angle(a0 + arc * i / steps) * r * g)
	if e.get("empowered", false):
		ci.draw_arc(p, r * g, a0, a0 + arc, steps, Color(Art.c("or"), 0.8 * a), 4.0, true)
	ci.draw_colored_polygon(wedge, Color(col, 0.2 * a))
	ci.draw_arc(p, r * g, a0, a0 + arc, steps, Color(clair, 0.85 * a), 2.5, true)
	var lines := 3 if arc < TAU else 8
	for i in lines:
		var ang := a0 + arc * (i + 0.5) / lines
		var head := p + Vector2.from_angle(ang) * r * g * 0.92
		Art._gust(ci, head - Vector2.from_angle(ang) * 14.0, 26.0 * a + 6.0, Color(clair, a), 2.0)


# --- Icônes ---

## Dessine l'icône de Vent id (voir Art.icon) ; faux si id n'en est pas une.
static func icon(ci: CanvasItem, id: String, p: Vector2, s: float, col: Color, clair: Color, sombre: Color, lw: float) -> bool:
	var relief := col == sombre
	var P := func(x: float, y: float) -> Vector2: return p + Vector2(x, y) * s
	match id:
		"tornade":
			# Entonnoir : quatre traits de plus en plus courts, du haut vers la pointe au sol.
			for i in 4:
				var y := -0.75 + i * 0.42
				var half := 0.85 - i * 0.2
				var x0 := 0.1 * sin(i * 1.3)
				ci.draw_line(P.call(x0 - half, y), P.call(x0 + half, y), col, lw * (1.6 - i * 0.2), true)
			ci.draw_circle(P.call(0.05, 0.9), s * 0.1, col)
			if not relief:
				ci.draw_arc(P.call(0.55, -0.55), s * 0.2, PI * 0.5, PI * 2.0, 8, clair, lw * 0.8, true)
		"ruee":
			# Une flèche fuselée, et trois traînées d'air derrière elle.
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.9, -0.1), P.call(0.1, -0.5), P.call(0.25, -0.1), P.call(0.1, 0.3)]), col)
			for i in 3:
				var y := -0.45 + i * 0.35
				ci.draw_line(P.call(-0.9 + i * 0.12, y + 0.1), P.call(0.05, y * 0.4 - 0.05), col if i != 1 or relief else clair, lw * 1.1, true)
		"appel_air":
			# Spirale qui s'enroule vers un point.
			var pts := PackedVector2Array()
			for i in 22:
				var q := i / 21.0
				pts.append(p + Vector2.from_angle(q * TAU * 1.6) * s * (0.95 - 0.8 * q))
			ci.draw_polyline(pts, col, lw * 1.4, true)
			ci.draw_circle(p, s * 0.16, col if relief else clair)
		"attaque_lame":
			# Un croissant tranchant qui part vers le haut à droite, avec sa flèche de retour.
			var c0: Vector2 = P.call(-0.1, 0.1)
			var pts := PackedVector2Array()
			for i in 11:
				pts.append(c0 + Vector2.from_angle(lerpf(-PI * 1.05, 0.05, i / 10.0)) * s * 0.85)
			for i in range(10, -1, -1):
				pts.append(c0 + Vector2.from_angle(lerpf(-PI * 0.85, -0.15, i / 10.0)) * s * 0.5 + Vector2(0, -s * 0.05))
			ci.draw_colored_polygon(pts, col)
			ci.draw_arc(P.call(-0.1, 0.55), s * 0.38, PI * 0.15, PI * 0.95, 8, col if relief else clair, lw, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.5, 0.45), P.call(-0.62, 0.78), P.call(-0.32, 0.72)]), col if relief else clair)
		"attaque_bourrasque":
			# Un cône ouvert vers le haut à droite, traversé de deux rafales.
			var c0: Vector2 = P.call(-0.7, 0.7)
			var pts := PackedVector2Array([c0])
			for i in 9:
				pts.append(c0 + Vector2.from_angle(lerpf(-PI * 0.5, 0.0, i / 8.0)) * s * 1.55)
			ci.draw_colored_polygon(pts, Color(col, 0.55) if not relief else col)
			Art._gust(ci, P.call(-0.05, 0.05), s * 0.9, col.lightened(0.2) if relief else clair, lw)
			Art._gust(ci, P.call(0.15, 0.5), s * 0.6, col.lightened(0.2) if relief else clair, lw * 0.9)
		_:
			return false
	return true
