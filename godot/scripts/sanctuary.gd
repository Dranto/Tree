## Sanctuaire : un cercle de pierres dressées autour d'une flamme de sève éteinte.
##
## On le ravive en se tenant dans le cercle LIGHT_TIME secondes (l'avancée retombe si on en sort).
## Ravivé, il pose Game.flags["sanctuaire_<id>"] = true, devient le point de renaissance
## (Game.flags["renaissance"] = id, lu par main.respawn_point) et rend toute la vie.
## Revenir dans le cercle d'un sanctuaire déjà ravivé en refait le point de renaissance et
## rend aussi toute la vie. Celui de la Graine est ravivé dès le départ.
##
## Les sanctuaires sont posés par main.gd à partir de SITES ; chacun est un nœud au niveau du sol
## (sous les personnages). Ils ne font rien pour le robot d'équilibrage ni pendant le banc de
## performance (frozen), pour ne pas changer leurs mesures.
extends Node2D

const Regions = preload("res://scripts/regions.gd")

## Rayon du cercle où se tenir.
const RADIUS := 64.0
## Secondes à passer dans le cercle pour raviver le sanctuaire.
const LIGHT_TIME := 3.0
## Vitesse à laquelle l'avancée retombe hors du cercle (secondes perdues par seconde).
const DECAY := 1.0
## Rayon de la vague de vie lancée quand le sanctuaire est ravivé.
const LIFE_RADIUS := 170.0
const STONES := 7

## Emplacements : « dist » depuis la graine et « angle » (radians) par rapport à l'axe de la région.
## Ils restent hors de la zone du Cœur et de l'arène, et sont écartés des buissons d'épines.
const SITES := [
	{"id": "graine", "name": "de la Graine", "region": "", "dist": 0.0, "angle": 0.0},
	{"id": "lisiere", "name": "de la Lisière", "region": "ronce", "dist": 820.0, "angle": -0.3},
	{"id": "ravin", "name": "du Ravin", "region": "ronce", "dist": 1250.0, "angle": 0.3},
	{"id": "veille", "name": "de la Veille", "region": "ronce", "dist": 1700.0, "angle": -0.38},
	{"id": "epine", "name": "de l'Épine", "region": "ronce", "dist": 2200.0, "angle": 0.3},
]

var main
var id := ""
## Complément du nom : « sanctuaire de la Lisière ».
var place := ""
## Secondes passées dans le cercle (jusqu'à LIGHT_TIME).
var progress := 0.0
## Le joueur était dans le cercle au pas précédent.
var inside := false
var frozen := false
var t := 0.0
## Éclat qui suit le moment où le sanctuaire est ravivé (1 puis retombe à 0).
var flash := 0.0
var _stones: Array = []


## Position d'un emplacement de SITES dans le monde (avant l'écart des buissons).
static func site_position(site: Dictionary) -> Vector2:
	if site["region"] == "":
		return Vector2.ZERO
	return Vector2.from_angle(Regions.angle_of(site["region"]) + float(site["angle"])) * float(site["dist"])


func setup(site: Dictionary) -> void:
	id = site["id"]
	place = site["name"]
	name = "Sanctuaire_" + id
	# Groupe lu par les objectifs et la carte (tâche E) : chaque nœud a une propriété « id ».
	add_to_group("sanctuaire")
	var shape := RandomNumberGenerator.new()
	shape.seed = hash(id)
	for i in STONES:
		_stones.append([shape.randf_range(-0.12, 0.12), shape.randf_range(0.8, 1.25), shape.randf_range(-0.4, 0.4)])


func title() -> String:
	return "sanctuaire " + place


func is_lit() -> bool:
	return bool(Game.flags.get("sanctuaire_" + id, false))


func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta / 1.2)
	if main.player.position.distance_squared_to(position) < 1300.0 * 1300.0:
		queue_redraw()


func _physics_process(delta: float) -> void:
	if frozen:
		return
	# La Graine est ravivée d'office (le drapeau est effacé par une nouvelle partie : on le repose).
	if id == "graine" and not is_lit():
		Game.flags["sanctuaire_graine"] = true
	var p = main.player
	var near: bool = p.position.distance_squared_to(position) < RADIUS * RADIUS
	if is_lit():
		progress = LIGHT_TIME
		if near and not inside:
			rest(false)
		inside = near
		return
	inside = near
	if near:
		progress += delta
		if progress >= LIGHT_TIME:
			light()
	else:
		progress = maxf(0.0, progress - delta * DECAY)


## Ravive le sanctuaire : drapeau, vague de vie, point de renaissance, toute la vie rendue.
func light() -> void:
	Game.flags["sanctuaire_" + id] = true
	progress = LIGHT_TIME
	inside = true
	flash = 1.0
	Sfx.play("floraison", position)
	main.fx.ring(position, 12.0, RADIUS * 2.4, 0.8, Color(Art.ec("seve"), 0.9), 5.0)
	main.revive(position, LIFE_RADIUS, Art.ec("seve"))
	rest(true)


## Le joueur se repose ici : toute sa vie, et il renaîtra ici.
func rest(just_lit: bool) -> void:
	var p = main.player
	p.heal(Game.stats["max_hp"])
	var before := str(Game.flags.get("renaissance", "graine"))
	Game.flags["renaissance"] = id
	if just_lit:
		main.hud.banner("Sanctuaire %s ravivé : tu renaîtras ici." % place)
	elif before != id:
		main.hud.banner("Tu renaîtras au sanctuaire %s." % place)
	else:
		return
	main.request_autosave()


## Calque de dessin : appelle une fonction du sanctuaire avec lui-même comme toile.
## Les pierres ne sont redessinées que quand l'avancée change ; seule la flamme s'anime à chaque image.
class Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


var _stones_layer: Layer
var _flame_layer: Layer
## Avancée (en soixantièmes) au dernier dessin des pierres.
var _stones_key := -1


func _ready() -> void:
	_stones_layer = Layer.new()
	_stones_layer.fn = _draw_stones
	_stones_layer.show_behind_parent = true
	add_child(_stones_layer)
	_flame_layer = Layer.new()
	_flame_layer.fn = _draw_center
	add_child(_flame_layer)


func _k() -> float:
	return 1.0 if is_lit() else clampf(progress / LIGHT_TIME, 0.0, 1.0)


## Dessin (charte : un cercle de pierres claires, ce qui s'utilise est clair et chaud).
## Trois états lisibles sans texte :
## - éteint : pierres ternes, runes mortes, une braise sombre au centre ;
## - en cours : l'anneau d'or se remplit et les runes s'allument une à une ;
## - ravivé : pierres claires aux runes de sève, lueur, étincelles et colonne de lumière qu'on voit de loin.
## La dalle, l'anneau et les pierres ne changent qu'avec l'avancée : ils sont sur un calque redessiné
## à ce moment-là. Le centre (flamme, runes qui palpitent) est sur un calque animé. Ici : ce qui tourne
## ou passe (tirets de l'anneau éteint, onde du ravivement), au-dessus des pierres.
func _draw() -> void:
	var lit := is_lit()
	var k := _k()
	var key := int(k * 60.0) + (100 if lit else 0)
	if key != _stones_key and _stones_layer != null:
		_stones_key = key
		_stones_layer.queue_redraw()
	if _flame_layer != null:
		_flame_layer.queue_redraw()
	var or_ := Art.c("butin")
	var ring_r := RADIUS + 12.0
	if not lit and k <= 0.0:
		# Éteint : l'anneau d'or est à peine esquissé, en tirets qui tournent, pour inviter à entrer.
		for i in 16:
			var a0 := TAU * i / 16.0 + t * 0.15
			draw_arc(Vector2.ZERO, ring_r, a0, a0 + TAU / 16.0 * 0.45, 4, Color(or_, 0.28 + 0.12 * sin(t * 2.0)), Art.TRAIT)
	if flash > 0.0:
		var u := 1.0 - flash
		draw_arc(Vector2.ZERO, ring_r + 70.0 * Anim.ease_out(u), 0.0, TAU, 64, Color(Art.ec("seve", "clair"), flash), Art.TRAIT_FORT * flash + 1.0, true)


## Dalle, anneau de progression, pierres et socle : redessinés seulement quand l'avancée change.
func _draw_plate(ci: CanvasItem, lit: bool, k: float) -> void:
	var pierre := Art.c("interactif")
	var or_ := Art.c("butin")
	# Dalle : un disque de terre battue, un anneau de pavés et un cercle gravé.
	ci.draw_circle(Vector2.ZERO, RADIUS + 16.0, Color(Art.c("contour"), 0.28))
	ci.draw_circle(Vector2.ZERO, RADIUS + 8.0, Color(Art.c("decor_vivant") if lit else Art.c("decor"), 0.35))
	ci.draw_arc(Vector2.ZERO, RADIUS * 0.82, 0.0, TAU, 48, Color(pierre.darkened(0.55), 0.55), 9.0)
	ci.draw_arc(Vector2.ZERO, RADIUS * 0.82, 0.0, TAU, 48, Color(pierre, 0.10 + 0.12 * k), 1.5)
	ci.draw_arc(Vector2.ZERO, RADIUS * 0.42, 0.0, TAU, 32, Color(pierre, 0.12 + 0.2 * k), Art.TRAIT_FIN)
	# Anneau de progression : fond sombre, or qui se remplit, tête brillante ; plein une fois ravivé.
	var ring_r := RADIUS + 12.0
	ci.draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64, Color(Art.c("contour"), 0.45), Art.TRAIT_FORT, true)
	if k > 0.0:
		var col := or_ if not lit else or_.lerp(Art.ec("seve", "clair"), 0.3)
		ci.draw_arc(Vector2.ZERO, ring_r, -PI / 2.0, -PI / 2.0 + TAU * k, 64, col, Art.TRAIT_FORT, true)
		if not lit:
			var head := Vector2.from_angle(-PI / 2.0 + TAU * k) * ring_r
			ci.draw_circle(head, 5.0, Color(or_, 0.35))
			ci.draw_circle(head, 3.0, or_.lightened(0.45))


## Pierres dressées : stèles gravées, en volume ; chacune s'allume quand l'avancée la dépasse.
## Socle central. Redessiné seulement quand l'avancée change.
func _draw_stones(ci: CanvasItem) -> void:
	var lit := is_lit()
	var k := _k()
	_draw_plate(ci, lit, k)
	var seve := Art.ec("seve")
	var pierre := Art.c("interactif")
	for i in STONES:
		var s: Array = _stones[i]
		var c := _stone_pos(i)
		var on := clampf((k * STONES - i) * 1.5, 0.0, 1.0)
		var h: float = 20.0 * s[1]
		var w := 7.5
		var tilt: float = s[2] * 2.5
		var stone := PackedVector2Array([c + Vector2(-w, 4), c + Vector2(-w * 0.9 + tilt * 0.6, -h * 0.65), c + Vector2(tilt, -h),
			c + Vector2(w * 0.9 + tilt * 0.6, -h * 0.65), c + Vector2(w, 4)])
		Art.shadow(ci, c + Vector2(0, 2), w)
		Art.volume(ci, stone, pierre.darkened(0.42).lerp(pierre, on), 0.4 + 0.5 * on)
		Art.outline(ci, stone, Art.c("contour"), Art.TRAIT_FIN)
		var rune := Color(Art.c("contour"), 0.55).lerp(seve, on)
		var m := c + Vector2(tilt * 0.5, -h * 0.42)
		ci.draw_line(m + Vector2(0, -5), m + Vector2(0, 5), rune, Art.TRAIT_FIN, true)
		ci.draw_line(m + Vector2(-3, -1), m + Vector2(3, -4), rune, Art.TRAIT_FIN, true)
		if lit and s[1] > 1.0:
			# Un peu de mousse au pied des plus hautes.
			ci.draw_colored_polygon(Art.ellipse(c + Vector2(-w * 0.4, 2.5), 5.0, 2.2, 8), Art.c("decor_vivant").lightened(0.15))
	# Socle central et sa coupe.
	Art.shadow(ci, Vector2(0, 2), 13.0)
	Art.volume_circle(ci, Vector2(0, -2), 13.0, pierre.darkened(0.5).lerp(pierre.darkened(0.15), k), 0.6)
	ci.draw_circle(Vector2(0, -3), 8.0, Art.c("contour").lerp(Art.ec("seve", "sombre"), k))


func _stone_pos(i: int) -> Vector2:
	var a: float = TAU * i / STONES + _stones[i][0] - PI / 2.0
	return Vector2.from_angle(a) * (RADIUS - 4.0)


## Centre animé : lueur des runes allumées, braise ou flamme de sève, étincelles, colonne de lumière.
func _draw_center(ci: CanvasItem) -> void:
	var lit := is_lit()
	var k := _k()
	var seve := Art.ec("seve")
	var seve_clair := Art.ec("seve", "clair")
	if lit:
		# Le sol du cercle respire doucement (sous les pierres : le calque des pierres est dessus,
		# on ne garde donc ici qu'un disque intérieur).
		var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
		ci.draw_circle(Vector2.ZERO, RADIUS * 0.5, Color(seve, 0.05 + 0.04 * b + 0.25 * flash))
	for i in STONES:
		var on := clampf((k * STONES - i) * 1.5, 0.0, 1.0)
		if on <= 0.0:
			continue
		# Les runes allumées palpitent l'une après l'autre.
		var pulse := 0.5 + 0.5 * sin(t * 2.4 - i * 0.9)
		var s: Array = _stones[i]
		var m := _stone_pos(i) + Vector2(s[2] * 1.25, -20.0 * s[1] * 0.42)
		ci.draw_circle(m, 6.0, Color(seve, 0.2 * on * pulse))
	if lit:
		_draw_flame(ci, seve, seve_clair)
	else:
		# Braise presque éteinte, qui reprend à mesure qu'on s'y tient.
		var ember := Art.ec("seve", "sombre").lerp(seve, k)
		ci.draw_circle(Vector2(0, -3), 3.0 + 3.0 * k, Color(ember, 0.55 + 0.3 * sin(t * 4.0)))
		if k > 0.0:
			Art.glow(ci, Vector2(0, -6), 22.0 * k, "seve")


## Flamme de sève sur le socle, étincelles qui montent et colonne de lumière qui se voit de loin.
func _draw_flame(ci: CanvasItem, seve: Color, seve_clair: Color) -> void:
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	# Colonne de lumière : deux bandes qui s'effacent vers le haut.
	var al := 0.16 + 0.06 * b
	for band in [[7.0, Color(seve, al * 0.6)], [2.5, Color(seve_clair, al)]]:
		var hw: float = band[0]
		var c0: Color = band[1]
		ci.draw_polygon(PackedVector2Array([Vector2(-hw, -14), Vector2(hw, -14), Vector2(hw, -170), Vector2(-hw, -170)]),
			PackedColorArray([c0, c0, Color(c0, 0.0), Color(c0, 0.0)]))
	Art.glow(ci, Vector2(0, -10), 34.0 * (1.0 + 0.08 * b + 0.4 * flash), "seve")
	for j in 3:
		var sway := sin(t * (3.0 + j) + j * 1.7) * 2.5
		var hgt := 26.0 - j * 6.0 + 2.0 * sin(t * 5.0 + j)
		var wid := 8.0 - j * 2.0
		var col := seve.lerp(seve_clair, j * 0.45)
		var flame := PackedVector2Array()
		for q in 8:
			var u := q / 7.0
			flame.append(Vector2(-sin(u * PI) * wid * (1.0 - u * 0.3) + sway * u, -4.0 - u * hgt))
		for q in range(6, 0, -1):
			var u := q / 7.0
			flame.append(Vector2(sin(u * PI) * wid * (1.0 - u * 0.3) + sway * u, -4.0 - u * hgt))
		ci.draw_colored_polygon(flame, Color(col, 0.85))
	# Étincelles qui montent du socle et s'éteignent.
	for i in 6:
		var u := fposmod(t * 0.45 + i / 6.0, 1.0)
		var p := Vector2(sin(i * 2.3 + t * 1.3) * 14.0, -10.0 - 70.0 * u)
		ci.draw_circle(p, 1.8, Color(seve_clair, sin(PI * u)))
