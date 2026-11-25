## Sanctuaire : un cercle de pierres levées autour d'une pierre creuse (vasque) où la flamme de sève
## est éteinte (refonte du monde, vague 1 C : formes de world_art/lieux.gd, vues de trois quarts).
##
## On le ravive en se tenant dans le cercle LIGHT_TIME secondes (l'avancée retombe si on en sort).
## Ravivé, il pose Game.flags["sanctuaire_<id>"] = true, devient le point de renaissance
## (Game.flags["renaissance"] = id, lu par main.respawn_point) et rend toute la vie.
## Revenir dans le cercle d'un sanctuaire déjà ravivé en refait le point de renaissance et
## rend aussi toute la vie. Celui de la Graine est ravivé dès le départ.
##
## Les sanctuaires sont posés par main.gd à partir de sites() ; chacun est un nœud au niveau du sol
## (sous les personnages). Ils ne font rien pour le robot d'équilibrage ni pendant le banc de
## performance (frozen), pour ne pas changer leurs mesures.
extends Node2D

const Regions = preload("res://scripts/regions.gd")
const Prompt = preload("res://scripts/prompt.gd")
const Lieux = preload("res://scripts/world_art/lieux.gd")
const LieuxBake = preload("res://scripts/world_bake/lieux_bake.gd")

## Crochet visuel (sans logique de jeu) pour les événements du monde (tâche E) : le sanctuaire vient
## d'être ravivé (on_lit).
signal lit

## Rayon du cercle où se tenir.
const RADIUS := 64.0
## Secondes à passer dans le cercle pour raviver le sanctuaire.
const LIGHT_TIME := 3.0
## Vitesse à laquelle l'avancée retombe hors du cercle (secondes perdues par seconde).
const DECAY := 1.0
## Rayon de la vague de vie lancée quand le sanctuaire est ravivé.
const LIFE_RADIUS := 170.0
const STONES := Lieux.STONES

## Sanctuaire de la Graine, au centre du monde. Les autres sont décrits par les régions
## (« sanctuaries » de data/regions/<id>.json) : « dist » depuis la graine et « side » (ou « angle »,
## en radians) par rapport à l'axe de la région. Ils restent hors de la zone du Cœur et de l'arène,
## et sont écartés des buissons d'épines.
const SEED_SITE := {"id": "graine", "name": "de la Graine", # i18n
	 "region": "", "dist": 0.0, "angle": 0.0}


var main
var id := ""
## Région du sanctuaire ("" pour celui de la Graine).
var region := ""
## Complément du nom : « sanctuaire de la Lisière ».
var place := ""
## Secondes passées dans le cercle (jusqu'à LIGHT_TIME).
var progress := 0.0
## Le joueur était dans le cercle au pas précédent.
var inside := false
var frozen := false
var t := 0.0
## Temps depuis le dernier dessin : redessiné 15 fois par seconde au plus, sauf pendant l'onde du
## ravivement (docs/performances.md).
var _since_draw := 1.0
## Éclat qui suit le moment où le sanctuaire est ravivé (1 puis retombe à 0).
var flash := 0.0
var _stones: Array = []


## Tous les emplacements : la Graine, puis ceux de chaque région (dans l'ordre des régions).
static func sites() -> Array:
	var out: Array = [SEED_SITE]
	for reg in Regions.ids():
		for site in Regions.def(reg).get("sanctuaries", []):
			var s: Dictionary = site.duplicate()
			s["region"] = reg
			out.append(s)
	return out


## Position d'un emplacement dans le monde (avant l'écart des buissons).
static func site_position(site: Dictionary) -> Vector2:
	if site["region"] == "":
		return Vector2.ZERO
	return Regions.place(site["region"], site)


func setup(site: Dictionary) -> void:
	id = site["id"]
	region = str(site.get("region", ""))
	place = site["name"]
	name = "Sanctuaire_" + id
	# Groupe lu par les objectifs et la carte (tâche E) : chaque nœud a une propriété « id ».
	add_to_group("sanctuaire")
	var shape := RandomNumberGenerator.new()
	shape.seed = hash(id)
	for i in STONES:
		_stones.append([shape.randf_range(-0.12, 0.12), shape.randf_range(0.8, 1.25), shape.randf_range(-0.4, 0.4)])


func title() -> String:
	return Loc.t("sanctuaire %s") % Loc.data(place)


func is_lit() -> bool:
	return bool(Game.flags.get("sanctuaire_" + id, false))


func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta / 1.2)
	_since_draw += delta
	if (_since_draw >= 1.0 / 15.0 - 0.001 or flash > 0.0) and main.player.position.distance_squared_to(position) < 1300.0 * 1300.0 and _near_view():
		_since_draw = 0.0
		queue_redraw()
		_redraw_pieces()
		_keep_baked()


## Le sanctuaire (plus une marge) touche le cadre visible : hors de l'écran, rien à animer.
func _near_view() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return view.grow(LIFE_RADIUS + 300.0).has_point(position)


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
		# Dans le cercle d'un sanctuaire ravivé, oublier et changer de build sont gratuits (Game.refund_cost).
		if near:
			Game.at_sanctuary = true
		elif inside:
			Game.at_sanctuary = false
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
	Game.at_sanctuary = true
	flash = 1.0
	Sfx.play("floraison", position)
	main.fx.ring(position, 12.0, RADIUS * 2.4, 0.8, Color(Art.ec("seve"), 0.9), 5.0)
	main.fx.pickup(position, "seve", 14, main.player.position)
	main.screen_fx.glow(Art.ec("seve"), 0.3, 1.0)
	# Colonne de lumière qui s'élève puis retombe en pluie de lueurs (world_fx.gd).
	if main.get("world_fx") != null:
		main.world_fx.sanctuary_lit(position)
	main.revive(position, LIFE_RADIUS, Art.ec("seve"))
	rest(true)
	on_lit()


## Crochet visuel : le sanctuaire vient d'être ravivé (la flamme jaillit, les pierres brillent).
func on_lit() -> void:
	flash = 1.0
	lit.emit()


## Le joueur se repose ici : toute sa vie, et il renaîtra ici.
func rest(just_lit: bool) -> void:
	var p = main.player
	p.heal(Game.stats["max_hp"], true)
	var before := str(Game.flags.get("renaissance", "graine"))
	Game.flags["renaissance"] = id
	# Plus d'annonce : la flamme qui s'allume dit qu'on renaîtra ici. Un autre sanctuaire déjà
	# ravivé reprend la renaissance avec une onde douce.
	if not just_lit and before == id:
		return
	if not just_lit:
		main.fx.ring(position, 10.0, RADIUS * 1.6, 0.6, Color(Art.ec("seve", "clair"), 0.8), 3.0)
	main.request_autosave()


## Calque de dessin : appelle une fonction du sanctuaire avec lui-même comme toile.
## La dalle et l'anneau ne sont redessinés que quand l'avancée change.
class Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


## Une pierre levée (i de 0 à STONES - 1) ou la vasque du centre (i = -1) : chacune est un nœud du calque
## trié en profondeur (main.actors_layer), posé à son pied, pour que le héros passe devant ou derrière.
class Piece extends Node2D:
	var sanct
	var i := -1
	## Allumage (en trentièmes) au dernier dessin.
	var drawn := -1

	func _draw() -> void:
		sanct.draw_piece(self, i)


var _stones_layer: Layer
var _pieces: Array = []
## Avancée (en soixantièmes) au dernier dessin de la dalle.
var _stones_key := -1


func _ready() -> void:
	_stones_layer = Layer.new()
	_stones_layer.fn = _draw_plate
	_stones_layer.show_behind_parent = true
	add_child(_stones_layer)
	var layer: Node = main.get("actors_layer") if main != null else null
	for i in range(-1, STONES):
		var pc := Piece.new()
		pc.sanct = self
		pc.i = i
		pc.name = "Pierre%d" % i if i >= 0 else "Vasque"  # i18n: non (nom de nœud)
		LieuxBake.prepare(pc)
		if layer != null:
			pc.position = position + _piece_pos(i)
			layer.add_child(pc)
		else:
			pc.position = _piece_pos(i)
			add_child(pc)
		_pieces.append(pc)
	tree_exiting.connect(_free_pieces)


func _free_pieces() -> void:
	for pc in _pieces:
		if is_instance_valid(pc) and pc.get_parent() != self:
			pc.queue_free()
	_pieces.clear()


func _k() -> float:
	return 1.0 if is_lit() else clampf(progress / LIGHT_TIME, 0.0, 1.0)


## Allumage de la pierre i (0 à 1) : les pierres s'allument l'une après l'autre avec l'avancée.
func stone_on(i: int) -> float:
	return clampf((_k() * STONES - i) * 1.5, 0.0, 1.0)


## Pied d'une pierre (sur un vrai cercle du monde, juste dans l'anneau d'or) ou de la vasque (i = -1).
func _piece_pos(i: int) -> Vector2:
	if i < 0:
		return Vector2(0, 4)
	var a: float = TAU * i / STONES + _stones[i][0] - PI / 2.0
	return Vector2.from_angle(a) * Lieux.SANCT_R


## Penche d'une pierre : vers l'extérieur du cercle (même valeur pour la cuisson et le dessin).
static func stone_lean(i: int) -> float:
	return cos(TAU * i / STONES - PI / 2.0) * 0.08


## Jeu d'images cuites : un par région (celui de la Graine : « sanct/ »).
func _bake_key() -> String:
	return "sanct/" + region


func _keep_baked() -> void:
	var key := _bake_key()
	if LieuxBake.ready(key):
		return
	var reg := region
	var jobs := []
	for i in STONES:
		var lean := stone_lean(i)
		for on in [0, 1]:
			var lit_on: bool = on == 1
			jobs.append({"key": "s%d%d" % [i, on], "box": Lieux.stone_box(), "paint": func(ci): Lieux.sanct_stone(ci, reg, Vector2.ZERO, i, lit_on, lit_on, lean)})
	for on in [0, 1]:
		var lit_on: bool = on == 1
		jobs.append({"key": "v%d" % on, "box": Lieux.vasque_box(), "paint": func(ci): Lieux.sanct_vasque(ci, reg, Vector2.ZERO, lit_on)})
	LieuxBake.request(self, key, jobs)


## Redessine la vasque (flamme) et les pierres dont l'allumage a changé (ou qui palpitent).
func _redraw_pieces() -> void:
	var lit_now := is_lit()
	for pc in _pieces:
		if pc.i < 0:
			pc.queue_redraw()
			continue
		var on := stone_on(pc.i)
		var key := int(on * 30.0)
		if (on > 0.0 and (lit_now or flash > 0.0)) or key != pc.drawn:
			pc.drawn = key
			pc.queue_redraw()


## Dessin d'une pierre ou de la vasque : image cuite éteinte, fondue dans l'image allumée selon son
## allumage ; lueur de la graine gravée et flamme dessinées en direct.
func draw_piece(c: CanvasItem, i: int) -> void:
	var key := _bake_key()
	var lit_now := is_lit()
	if i < 0:
		if not LieuxBake.draw(c, key, "v%d" % int(lit_now)):
			Lieux.sanct_vasque(c, region, Vector2.ZERO, lit_now)
		Lieux.sanct_flame(c, Vector2.ZERO, lit_now, _k(), t, flash)
		return
	var on := stone_on(i)
	var lean := stone_lean(i)
	if on < 1.0 and not LieuxBake.draw(c, key, "s%d0" % i):
		Lieux.sanct_stone(c, region, Vector2.ZERO, i, false, false, lean)
	if on > 0.0 and not LieuxBake.draw(c, key, "s%d1" % i, Vector2.ZERO, 1.0, Color(1, 1, 1, on)) and on >= 0.5:
		Lieux.sanct_stone(c, region, Vector2.ZERO, i, true, true, lean)
	Lieux.sanct_rune(c, Vector2.ZERO, i, minf(1.0, on + flash), t, lean)


## Dessin au sol (charte : ce qui s'utilise est clair et chaud). Trois états lisibles sans texte :
## - éteint : pierres ternes, graines gravées mortes, une braise froide dans la vasque, l'anneau d'or en
##   tirets qui tournent pour inviter à entrer ;
## - en cours : l'anneau d'or se remplit, les pierres s'allument une à une, la flamme reprend ;
## - ravivé : pierres claires aux graines de sève, herbe à leur pied, flamme et colonne de lumière.
## La dalle et l'anneau ne changent qu'avec l'avancée : ils sont sur un calque redessiné à ce moment-là.
## Ici : ce qui tourne ou passe (tirets de l'anneau éteint, onde du ravivement).
func _draw() -> void:
	var lit_now := is_lit()
	var k := _k()
	var key := int(k * 60.0) + (100 if lit_now else 0)
	if key != _stones_key and _stones_layer != null:
		_stones_key = key
		_stones_layer.queue_redraw()
	var or_ := Art.c("butin")
	var ring_r := RADIUS + 12.0
	if not lit_now and k <= 0.0:
		for i in 16:
			var a0 := TAU * i / 16.0 + t * 0.15
			draw_arc(Vector2.ZERO, ring_r, a0, a0 + TAU / 16.0 * 0.45, 4, Color(or_, 0.28 + 0.12 * sin(t * 2.0)), Art.TRAIT)
		# Invite commune (prompt.gd) : le cercle respire et un chevron indique où se tenir.
		if main != null and main.get("player") != null:
			var dist: float = main.player.position.distance_to(position)
			Prompt.draw(self, RADIUS, 0.0, t, Prompt.nearness(dist, RADIUS))
	if lit_now:
		var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
		draw_circle(Vector2.ZERO, RADIUS * 0.5, Color(Art.ec("seve"), 0.04 + 0.03 * b + 0.25 * flash))
	if flash > 0.0:
		var u := 1.0 - flash
		draw_arc(Vector2.ZERO, ring_r + 70.0 * Anim.ease_out(u), 0.0, TAU, 64, Color(Art.ec("seve", "clair"), flash), Art.TRAIT_FORT * flash + 1.0, true)


## Dalle de pierre au sol et anneau de progression : redessinés seulement quand l'avancée change.
func _draw_plate(ci: CanvasItem) -> void:
	var lit_now := is_lit()
	var k := _k()
	var or_ := Art.c("butin")
	Lieux.sanct_dalle(ci, region, Vector2.ZERO, RADIUS + 16.0, lit_now)
	# Anneau de progression : fond sombre, or qui se remplit, tête brillante ; plein une fois ravivé.
	var ring_r := RADIUS + 12.0
	ci.draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64, Color(Art.c("contour"), 0.45), Art.TRAIT_FORT, true)
	if k > 0.0:
		var col := or_ if not lit_now else or_.lerp(Art.ec("seve", "clair"), 0.3)
		ci.draw_arc(Vector2.ZERO, ring_r, -PI / 2.0, -PI / 2.0 + TAU * k, 64, col, Art.TRAIT_FORT, true)
		if not lit_now:
			var head := Vector2.from_angle(-PI / 2.0 + TAU * k) * ring_r
			ci.draw_circle(head, 5.0, Color(or_, 0.35))
			ci.draw_circle(head, 3.0, or_.lightened(0.45))
