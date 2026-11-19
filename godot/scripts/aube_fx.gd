## Dessins de la branche Aube, selon la charte (élément « lumiere » : couleur #fffb3d, motif « rayons ») :
## rayon d'aube (attaque de base), signatures des compétences (aurore, prisme, lance d'aube), icônes.
## Purement visuel : la logique est dans scripts/skills/ et attack.gd (beam_line).
##
## skill_fx.gd et attack_fx.gd confient à AubeFx les signatures qu'il connaît (draws / draw) ;
## Art._icon_body lui confie les icônes d'Aube (icon). Les dessins sont statiques (instant e["t"]) :
## la galerie les fige.
class_name AubeFx
extends RefCounted

## Durée par défaut de chaque signature (secondes) ; le prisme et la charge de la lance donnent la leur.
const DUREE := {"rayon": 0.18, "aurore": 0.6, "prisme": 6.0, "lance_charge": 0.3, "lance_aube": 0.45}
## Icônes d'Aube : compétences, puis forme de l'attaque.
const ICONES_COMPETENCES := ["aurore", "prisme", "lance_aube"]
const ICONES_ATTAQUES := ["attaque_rayon"]


static func draws(id: String) -> bool:
	return DUREE.has(id)


## Dessine la signature id à son instant (e["t"], e["dur"]). on_ground : partie au sol (sous les
## acteurs) ou au-dessus. Le rayon (attack_fx.gd) n'a qu'une partie, dessinée au-dessus.
static func draw(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var k: float = clampf(e["t"] / maxf(e["dur"], 0.001), 0.0, 1.0)
	match e["id"]:
		"rayon":
			if not on_ground:
				_beam(ci, e["pos"], e.get("dir", Vector2.RIGHT), e.get("len", 520.0), e.get("w", 14.0), k, e.get("empowered", false))
		"lance_aube":
			_lance(ci, e, k, on_ground)
		"lance_charge":
			if not on_ground:
				_charge(ci, e, k)
		"aurore":
			_aurore(ci, e, k, on_ground)
		"prisme":
			_prisme(ci, e, on_ground)


# --- Rayons ---

## Un rayon : halo doré, cœur blanc, pointe qui s'élargit en étoile ; il naît d'un coup et s'amincit.
static func _beam(ci: CanvasItem, from: Vector2, dir: Vector2, length: float, w: float, k: float, empowered := false) -> void:
	var col := Art.ec("lumiere")
	var clair := Art.ec("lumiere", "clair")
	var a := 1.0 - Anim.ease_in(k)
	var thin := 1.0 - 0.7 * k
	var to := from + dir * length
	if empowered:
		ci.draw_line(from, to, Color(Art.c("or"), 0.5 * a), w * 1.8 * thin, true)
	ci.draw_line(from, to, Color(col, 0.35 * a), w * 1.3 * thin, true)
	ci.draw_line(from, to, Color(col, 0.85 * a), w * 0.6 * thin, true)
	ci.draw_line(from, to, Color(clair, a), maxf(1.5, w * 0.25 * thin), true)
	ci.draw_circle(from, w * 0.55 * thin, Color(clair, a))
	# Étoile à la pointe : quatre éclats.
	for i in 4:
		var d := dir.rotated(PI / 4.0 + i * PI / 2.0)
		ci.draw_line(to - d * w * 0.6, to + d * w * 0.6, Color(clair, 0.8 * a), Art.TRAIT_FIN, true)


static func _lance(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var from: Vector2 = e["pos"]
	var dir: Vector2 = e.get("dir", Vector2.RIGHT)
	var length: float = e.get("len", 900.0)
	var w: float = e.get("w", 44.0)
	if on_ground:
		# Le sol brûle de lumière le long du trait, puis s'éteint.
		var n := dir.orthogonal()
		var a := 1.0 - k
		var pts := PackedVector2Array([from + n * w * 0.7, from + dir * length + n * w * 0.3,
			from + dir * length - n * w * 0.3, from - n * w * 0.7])
		ci.draw_colored_polygon(pts, Color(Art.ec("lumiere", "sombre"), 0.25 * a))
		return
	_beam(ci, from, dir, length, w, k, false)
	# Anneaux de lumière qui filent le long du trait.
	var clair := Art.ec("lumiere", "clair")
	for i in 3:
		var q := fposmod(k * 2.0 + i / 3.0, 1.0)
		var c := from + dir * length * q
		ci.draw_arc(c, w * 0.7 * (1.0 - k), 0.0, TAU, 16, Color(clair, 0.7 * (1.0 - k)), Art.TRAIT_FIN, true)


## Charge de la lance : des grains de lumière convergent vers la pointe, devant le héros.
static func _charge(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var dir: Vector2 = e.get("dir", Vector2.RIGHT)
	var tip: Vector2 = e["pos"] + dir * 26.0
	var col := Art.ec("lumiere")
	var clair := Art.ec("lumiere", "clair")
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0 + k * 2.0)
		var r := 46.0 * (1.0 - Anim.ease_in(k))
		ci.draw_circle(tip + d * r, 2.5, Color(col, 0.4 + 0.6 * k))
	ci.draw_circle(tip, 4.0 + 10.0 * k, Color(col, 0.35))
	ci.draw_circle(tip, 2.0 + 5.0 * k, clair)


# --- Compétences ---

## Aurore : un anneau de lumière s'ouvre autour du héros, hérissé de rayons, puis pâlit ; au sol,
## une flaque dorée qui s'efface.
static func _aurore(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 210.0)
	var col := Art.ec("lumiere")
	var clair := Art.ec("lumiere", "clair")
	var g := Anim.ease_out(clampf(k / 0.7, 0.0, 1.0))
	var a := 1.0 - Anim.ease_in(k)
	if on_ground:
		ci.draw_circle(p, r * g, Color(col, 0.16 * a))
		return
	ci.draw_arc(p, r * g, 0.0, TAU, 48, Color(clair, 0.9 * a), 2.0 + 5.0 * a, true)
	ci.draw_arc(p, r * g * 0.92, 0.0, TAU, 48, Color(col, 0.6 * a), Art.TRAIT, true)
	for i in 12:
		var d := Vector2.from_angle(i * TAU / 12.0 + 0.13)
		var long := 0.14 if i % 2 == 0 else 0.08
		ci.draw_line(p + d * r * g * (1.0 - long), p + d * r * g * (1.0 + long), Color(clair, a), Art.TRAIT_FIN + 1.0, true)


## Prisme : un cristal en losange qui flotte et tourne lentement, avec ses reflets ; au sol, son
## ombre et une tache de lumière. Il pâlit dans sa dernière demi-seconde.
static func _prisme(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var t: float = e["t"]
	var dur: float = e["dur"]
	var col := Art.ec("lumiere")
	var clair := Art.ec("lumiere", "clair")
	var sombre := Art.ec("lumiere", "sombre")
	var appear := Anim.ease_out(clampf(t / 0.25, 0.0, 1.0))
	var a := 1.0 - clampf((t - (dur - 0.5)) / 0.5, 0.0, 1.0)
	if on_ground:
		ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, 6), 18.0 * appear, 7.0 * appear, 14), Color(Art.c("ombre"), 0.5 * a))
		ci.draw_circle(p, 40.0 * appear, Color(col, 0.1 * a))
		return
	var lift := Vector2(0, -26.0 - 4.0 * sin(t * 3.0)) * appear
	var c := p + lift
	var turn := sin(t * 1.7) * 0.35
	var hw := 11.0 * appear * (0.75 + 0.25 * cos(turn))
	var hh := 19.0 * appear
	var top := c + Vector2(0, -hh)
	var bottom := c + Vector2(0, hh)
	var left := c + Vector2(-hw, 0)
	var right := c + Vector2(hw, 0)
	ci.draw_circle(c, 26.0 * appear, Color(col, 0.18 * a))
	# Deux facettes : la gauche éclairée, la droite dans l'ombre.
	ci.draw_colored_polygon(PackedVector2Array([top, c + Vector2(hw * sin(turn) * 0.5, 0), bottom, left]), Color(col, a))
	ci.draw_colored_polygon(PackedVector2Array([top, right, bottom, c + Vector2(hw * sin(turn) * 0.5, 0)]), Color(col.darkened(0.25), a))
	ci.draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(sombre, a), Art.TRAIT_FIN, true)
	ci.draw_line(top + Vector2(-2, 6), left + Vector2(4, -1), Color(clair, a), Art.TRAIT_FIN, true)
	# Reflets qui tournent autour du cristal.
	for i in 3:
		var d := Vector2.from_angle(t * 2.0 + i * TAU / 3.0)
		ci.draw_circle(c + d * Vector2(22.0, 9.0) * appear, 1.8, Color(clair, 0.8 * a))


# --- Icônes ---

## Dessine l'icône d'Aube id (voir Art.icon) ; faux si id n'en est pas une.
static func icon(ci: CanvasItem, id: String, p: Vector2, s: float, col: Color, clair: Color, sombre: Color, lw: float) -> bool:
	var relief := col == sombre
	var P := func(x: float, y: float) -> Vector2: return p + Vector2(x, y) * s
	match id:
		"aurore":
			# Un anneau ouvert, hérissé de huit rayons.
			ci.draw_arc(p, s * 0.5, 0.0, TAU, 20, col, lw * 1.4, true)
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8.0)
				ci.draw_line(p + d * s * 0.72, p + d * s * (0.98 if i % 2 == 0 else 0.86), col, lw * 1.2, true)
			if not relief:
				ci.draw_circle(p, s * 0.2, clair)
		"prisme":
			# Un cristal en losange, une facette claire, un rayon qui en sort.
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.2, -0.85), P.call(0.3, -0.1), P.call(-0.2, 0.75), P.call(-0.7, -0.1)]), col)
			if not relief:
				ci.draw_colored_polygon(PackedVector2Array([P.call(-0.2, -0.85), P.call(-0.2, 0.75), P.call(-0.7, -0.1)]), clair)
			ci.draw_line(P.call(0.3, -0.1), P.call(0.95, -0.55), col, lw * 1.2, true)
			ci.draw_line(P.call(0.3, -0.1), P.call(0.95, 0.3), col, lw, true)
		"lance_aube":
			# Une lance de lumière en diagonale, pointe en étoile en haut à droite.
			ci.draw_line(P.call(-0.85, 0.85), P.call(0.55, -0.55), col, lw * 2.4, true)
			ci.draw_line(P.call(-0.85, 0.85), P.call(0.55, -0.55), col if relief else clair, lw * 0.9, true)
			for i in 4:
				var d := Vector2.from_angle(i * PI / 2.0)
				ci.draw_line(P.call(0.62, -0.62) - d * s * 0.32, P.call(0.62, -0.62) + d * s * 0.32, col, lw, true)
		"attaque_rayon":
			# Deux rayons parallèles qui partent vers le haut à droite depuis un point lumineux.
			ci.draw_circle(P.call(-0.6, 0.6), s * 0.28, col)
			ci.draw_line(P.call(-0.6, 0.6), P.call(0.9, -0.9), col, lw * 1.8, true)
			ci.draw_line(P.call(-0.35, 0.75), P.call(0.95, -0.4), col, lw, true)
			if not relief:
				ci.draw_circle(P.call(-0.6, 0.6), s * 0.12, clair)
		_:
			return false
	return true
