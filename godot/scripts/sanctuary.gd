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
const Prompt = preload("res://scripts/prompt.gd")

## Rayon du cercle où se tenir.
const RADIUS := 64.0
## Secondes à passer dans le cercle pour raviver le sanctuaire.
const LIGHT_TIME := 3.0
## Vitesse à laquelle l'avancée retombe hors du cercle (secondes perdues par seconde).
const DECAY := 1.0
## Rayon de la vague de vie lancée quand le sanctuaire est ravivé.
const LIFE_RADIUS := 170.0
const STONES := 7
const LIT_COLOR := Color("b6f28a")
const EMBER := Color("c8734a")

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
	main.fx.ring(position, 12.0, RADIUS * 2.4, 0.8, Color(LIT_COLOR, 0.9), 5.0)
	main.fx.pickup(position, "seve", 14, main.player.position)
	main.screen_fx.glow(Color(LIT_COLOR), 0.3, 1.0)
	main.revive(position, LIFE_RADIUS, LIT_COLOR)
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


func _draw() -> void:
	var lit := is_lit()
	var k := clampf(progress / LIGHT_TIME, 0.0, 1.0)
	# Dalle de terre battue et cercle tracé au sol.
	draw_circle(Vector2.ZERO, RADIUS + 10.0, Color(0.1, 0.09, 0.07, 0.35))
	var line := Color(0.55, 0.5, 0.42, 0.45).lerp(Color(LIT_COLOR, 0.55), 1.0 if lit else k * 0.6)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, line, 2.0)
	if lit:
		var glow := 0.12 + 0.05 * sin(t * 2.2) + 0.35 * flash
		draw_circle(Vector2.ZERO, RADIUS * 0.9, Color(LIT_COLOR, glow * 0.5))
		draw_circle(Vector2.ZERO, RADIUS * 0.45, Color(LIT_COLOR, glow))
	else:
		# Invite commune (prompt.gd) : le cercle respire à l'approche, puis l'anneau se remplit.
		var dist: float = main.player.position.distance_to(position)
		Prompt.draw(self, RADIUS, k, t, Prompt.nearness(dist, RADIUS), LIT_COLOR)
	# Pierres dressées, mousse verte une fois ravivé.
	for i in STONES:
		var s: Array = _stones[i]
		var a: float = TAU * i / STONES + s[0] - PI / 2.0
		var c := Vector2.from_angle(a) * (RADIUS - 6.0)
		var h: float = 15.0 * s[1]
		var w := 6.5
		var stone := Color("4a4640").lerp(Color("5d6a50"), 1.0 if lit else k * 0.5)
		var tilt: float = s[2] * 3.0
		var pts := PackedVector2Array([
			c + Vector2(-w, 3), c + Vector2(w, 3), c + Vector2(w * 0.7 + tilt, -h), c + Vector2(tilt, -h - 4.0), c + Vector2(-w * 0.8 + tilt, -h + 1.0)])
		draw_colored_polygon(pts, stone)
		draw_polyline(PackedVector2Array([pts[4], pts[3], pts[2]]), stone.lightened(0.25), 1.5)
		if lit:
			draw_circle(c + Vector2(tilt * 0.5 - 2.0, -h * 0.4), 3.0, Color("7fb35e"))
	# Vasque de pierre au centre.
	draw_circle(Vector2(0, 2), 13.0, Color("3a3732"))
	draw_circle(Vector2(0, 0), 10.0, Color("2a2724"))
	if lit:
		# Flamme de sève : trois langues qui ondulent.
		for j in 3:
			var sway := sin(t * (3.0 + j) + j * 1.7) * 2.5
			var hgt := 26.0 - j * 6.0 + 2.0 * sin(t * 5.0 + j)
			var wid := 9.0 - j * 2.2
			var col := LIT_COLOR.lerp(Color("fff3c4"), j * 0.45)
			var flame := PackedVector2Array()
			for q in 10:
				var u := q / 9.0
				var side := sin(u * PI) * wid * (1.0 - u * 0.3)
				flame.append(Vector2(-side + sway * u, -u * hgt))
			for q in range(8, 0, -1):
				var u := q / 9.0
				var side := sin(u * PI) * wid * (1.0 - u * 0.3)
				flame.append(Vector2(side + sway * u, -u * hgt))
			draw_colored_polygon(flame, Color(col, 0.85))
	else:
		# Braise presque éteinte, qui rougeoie à mesure qu'on s'y tient.
		var ember := EMBER.darkened(0.5).lerp(LIT_COLOR, k)
		draw_circle(Vector2(0, -1), 4.0 + 3.0 * k, Color(ember, 0.6 + 0.3 * sin(t * 4.0)))
