## Autel caché et secret d'une région (« altars » et « secrets » de data/regions/<id>.json) : des ruines couvertes de cendre qu'on
## devine en s'approchant. Le joueur s'y tient quelques secondes pour le raviver : un point d'arbre
## (Game.grant_points, une seule fois) et une greffe qui tombe au sol (main.drop_graft).
##
## Drapeaux (Game.flags) : « <kind>_<id>_vu » quand le joueur l'a aperçu (carte de la tâche E),
## « <kind>_<id> » une fois ravivé. kind vaut « autel » ou « secret ».
## Un secret n'apparaît qu'à courte distance, presque invisible : une lueur dans la cendre.
extends Node2D

const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")
const Prompt = preload("res://scripts/prompt.gd")
const Lieux = preload("res://scripts/world_art/lieux.gd")
const LieuxBake = preload("res://scripts/world_bake/lieux_bake.gd")

## Distance où un autel commence à se dessiner, et où il est entièrement visible.
const REVEAL := {"autel": 520.0, "secret": 230.0}
const CLEAR := {"autel": 300.0, "secret": 110.0}
## Rayon où se tenir et temps à y passer pour le raviver.
const ZONE := 70.0
const HOLD := {"autel": 1.5, "secret": 2.5}

var main
var kind := "autel"
var data: Dictionary = {}
var id := ""
## Région de l'autel ou du secret.
var region := ""
var active := false
var progress := 0.0
var seen := 0.0
var t := 0.0
var _was_near := false
## La table de pierre (autel seulement), dans le calque trié en profondeur : le héros passe devant ou
## derrière. Elle s'efface avec la visibilité (modulate).
var body: Node2D


class Body extends Node2D:
	var altar

	func _draw() -> void:
		altar.draw_table(self)


## Crée les autels et secrets des régions (Content.rewards()) et les ajoute sous « parent ».
static func spawn_all(m, parent: Node) -> Array:
	var out: Array = []
	var r := Content.rewards()
	for pair in [["autel", r.get("altars", [])], ["secret", r.get("secrets", [])]]:
		for a in pair[1]:
			if not Regions.exists(str(a.get("region", ""))):
				continue
			var n = load("res://scripts/altar.gd").new()
			n.main = m
			n.kind = pair[0]
			n.data = a
			n.id = str(a["id"])
			n.region = str(a.get("region", ""))
			n.position = position_of(a, m)
			parent.add_child(n)
			out.append(n)
	return out


## Position dans le monde : distance à la graine et écart au milieu du secteur, hors des buissons.
static func position_of(a: Dictionary, m = null) -> Vector2:
	var ang: float = Regions.angle_of(str(a["region"])) + float(a.get("side", 0.0)) * Regions.half_width()
	var p := Vector2.from_angle(ang) * float(a["dist"])
	var h := 2800.0
	p = p.clamp(Vector2(-h, -h), Vector2(h, h))
	if m != null and m.flora != null:
		p = m.flora.push_out(p, ZONE)
	return p


func flag() -> String:
	return "%s_%s" % [kind, id]


func _ready() -> void:
	# Groupes lus par la carte et les objectifs (tâche E) : nœuds avec une propriété « id ».
	add_to_group(kind)
	active = Game.flags.get(flag(), false)
	seen = 1.0 if active or Game.flags.get(flag() + "_vu", false) else 0.0
	if kind == "autel":
		body = Body.new()
		body.altar = self
		body.name = "Table_" + id
		LieuxBake.prepare(body)
		var layer: Node = main.get("actors_layer") if main != null else null
		if layer != null:
			body.position = position
			layer.add_child(body)
			tree_exiting.connect(func(): if is_instance_valid(body): body.queue_free())
		else:
			add_child(body)


## Animation seulement.
func _process(delta: float) -> void:
	t += delta
	var v := visibility()
	if v > 0.0 or _was_near:
		queue_redraw()
		if body != null:
			body.modulate.a = v
			body.visible = v > 0.01
			body.queue_redraw()
			_keep_baked()
	_was_near = v > 0.0


## Part de visibilité (0 à 1) selon la distance au joueur ; un autel déjà vu reste discret mais visible.
func visibility() -> float:
	if main == null or main.player == null:
		return 0.0
	var d: float = main.player.position.distance_to(position)
	var v := 1.0 - smoothstep(CLEAR[kind], REVEAL[kind], d)
	if kind == "autel" and seen > 0.0:
		v = maxf(v, 0.55)
	return v


## Logique à pas fixe : découverte, puis ravivement en restant dans la zone.
func _physics_process(delta: float) -> void:
	if main == null or main.player == null:
		return
	# Les drapeaux font foi : une partie chargée après la création des autels (« Continuer ») les
	# retrouve ravivés, sans rejouer leur récompense ni leur vague de vie.
	if not active and Game.flags.get(flag(), false):
		active = true
		progress = HOLD[kind]
		seen = 1.0
	elif seen <= 0.0 and Game.flags.get(flag() + "_vu", false):
		seen = 1.0
	var d: float = main.player.position.distance_to(position)
	if seen <= 0.0 and d < CLEAR[kind]:
		seen = 1.0
		Game.flags[flag() + "_vu"] = true
	if active:
		return
	if d < ZONE:
		progress += delta
		if progress >= HOLD[kind]:
			activate()
	else:
		progress = maxf(0.0, progress - delta * 2.0)


## Ravive l'autel : point d'arbre, greffe au sol, vague de vie.
func activate() -> void:
	if active:
		return
	active = true
	progress = HOLD[kind]
	Game.flags[flag()] = true
	Game.flags[flag() + "_vu"] = true
	Game.grant_points(int(data.get("points", 1)), kind, flag())
	var g := str(data.get("graft", ""))
	if g == "":
		g = Game.roll_graft(kind)
	if g != "" and not Game.has_graft(g):
		main.drop_graft(position + Vector2(0, 46), g)
	Sfx.play("coeur", position)
	main.revive(position, 160.0, Art.c("or"), 0.8)
	main.fx.ring(position, 20.0, 180.0, 0.8, Art.c("or"), 5.0)
	main.fx.pickup(position, "seve", 12, main.player.position)
	main.screen_fx.glow(Art.c("or"), 0.3, 1.0)
	main.request_autosave()
	queue_redraw()


## Dessin au sol. L'autel se reconnaît à sa silhouette : une table de pierre (deux pierres dressées, une
## dalle posée dessus ; nœud Body, dans le calque trié en profondeur) sur une ombre de terre battue. Il
## donne une greffe : son accent est l'or du butin.
## - éteint : pierre terne, cendre sur la dalle, une braise dessous, anneau d'or en tirets ;
## - en cours : l'anneau d'or se remplit, la cendre s'envole, la braise devient or, le signe gravé luit ;
## - ravivé : pierre claire, herbe au pied, une pousse dorée sur la dalle, lueur, éclats.
func _draw() -> void:
	var v := visibility()
	if v <= 0.01:
		return
	if kind == "secret":
		if active:
			_draw_secret_lit(v)
		else:
			_draw_secret(v)
		return
	var k := 1.0 if active else clampf(progress / HOLD[kind], 0.0, 1.0)
	# Terre battue autour de la table.
	draw_colored_polygon(Art.ellipse(Vector2(0, 2), 54.0, 26.0, 28), Color(Art.c("contour"), 0.22 * v))
	_ring(Vector2(0, 4), ZONE, k, v)
	if not active and progress <= 0.0:
		_invite(ZONE, v)


## Jeu d'images cuites : un par région (table éteinte et ravivée).
func _bake_key() -> String:
	return "autel/" + region


func _keep_baked() -> void:
	var key := _bake_key()
	if LieuxBake.ready(key):
		return
	var reg := region
	var jobs := []
	for on in [0, 1]:
		var rv: bool = on == 1
		jobs.append({"key": "t%d" % on, "box": Lieux.altar_box(), "paint": func(ci): Lieux.altar_table(ci, reg, Vector2.ZERO, rv)})
	LieuxBake.request(self, key, jobs)


## La table de pierre (cuite, la ravivée fondue sur l'éteinte avec l'avancée), son signe qui luit, la
## cendre et la braise, ou la pousse dorée.
func draw_table(c: CanvasItem) -> void:
	var k := 1.0 if active else clampf(progress / HOLD[kind], 0.0, 1.0)
	var key := _bake_key()
	if k < 1.0 and not LieuxBake.draw(c, key, "t0"):
		Lieux.altar_table(c, region, Vector2.ZERO, false)
	if k > 0.0 and not LieuxBake.draw(c, key, "t1", Vector2.ZERO, 1.0, Color(1, 1, 1, k)) and k >= 0.5:
		Lieux.altar_table(c, region, Vector2.ZERO, true)
	Lieux.altar_glyph(c, Vector2.ZERO, k, t)
	var top := Vector2(-11, -27)
	if active:
		_draw_sprout(c, top)
		return
	# Tas de cendre qui s'envole à mesure qu'on s'y tient, braise dessous qui vire à l'or.
	var or_ := Art.c("butin")
	var ash := Art.c("brume").lightened(0.1)
	var heap := 1.0 - Anim.ease_in(k)
	if heap > 0.02:
		c.draw_colored_polygon(Art.ellipse(top, 12.0 * heap, 4.5 * heap, 14), ash)
		c.draw_colored_polygon(Art.ellipse(top + Vector2(-2, -2), 7.0 * heap, 3.0 * heap, 12), ash.lightened(0.15))
	var ember := Art.ec("cendre").lerp(or_, k)
	c.draw_circle(top + Vector2(0, -1), 2.5 + 2.0 * k + sin(t * 3.0) * 0.8, Color(ember, 0.55 + 0.25 * sin(t * 4.0)))
	if k > 0.0:
		for i in 6:
			var u := fposmod(t * 0.9 + i / 6.0, 1.0)
			var p := top + Vector2(sin(i * 2.1 + t) * 10.0 + 18.0 * u * (1.0 if i % 2 == 0 else -1.0), -2.0 - 40.0 * u)
			c.draw_circle(p, 1.6, Color(ash, k * (1.0 - u)))


## Anneau de progression commun aux autels et au secret : fond sombre, or qui se remplit.
func _ring(c: Vector2, r: float, k: float, v: float) -> void:
	var or_ := Art.c("butin")
	if active:
		draw_arc(c, r, 0.0, TAU, 56, Color(or_, v * (0.35 + 0.1 * sin(t * 2.0))), Art.TRAIT, true)
		return
	draw_arc(c, r, 0.0, TAU, 56, Color(Art.c("contour"), 0.35 * v), Art.TRAIT_FORT, true)
	if k > 0.0:
		draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * k, 56, Color(or_, v), Art.TRAIT_FORT, true)
		draw_circle(c + Vector2.from_angle(-PI / 2.0 + TAU * k) * r, 3.0, Color(or_.lightened(0.45), v))
	else:
		for i in 14:
			var a0 := TAU * i / 14.0 + t * 0.15
			draw_arc(c, r, a0, a0 + TAU / 14.0 * 0.45, 4, Color(or_, v * (0.25 + 0.1 * sin(t * 2.0))), Art.TRAIT, true)


## Forme en volume avec contour, à l'opacité de l'autel.
func _vol(pts: PackedVector2Array, col: Color, v: float) -> void:
	if v >= 0.99:
		Art.volume(self, pts, col, 0.6)
		Art.outline(self, pts, Art.c("contour"), Art.TRAIT_FIN)
	else:
		draw_colored_polygon(pts, Color(col.darkened(0.2), v))
		Art.outline(self, pts, Color(Art.c("contour"), v), Art.TRAIT_FIN)


## Une pousse dorée qui sort de l'offrande, sa lueur et des éclats.
func _draw_sprout(c: CanvasItem, base: Vector2) -> void:
	var or_ := Art.c("butin")
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	c.draw_circle(base + Vector2(0, -14), 34.0, Color(or_, 0.08 + 0.04 * b))
	c.draw_circle(base + Vector2(0, -14), 20.0, Color(or_, 0.12 + 0.05 * b))
	var sway := sin(t * 1.6) * 1.5
	c.draw_line(base, base + Vector2(sway, -26), Art.c("decor_vivant").lightened(0.3), 2.5, true)
	for side in [-1.0, 1.0]:
		var lf := _leaf(base + Vector2(sway * 0.6, -14 - 4 * side), 13.0, -PI / 2.0 + side * 0.9)
		c.draw_colored_polygon(lf, or_.darkened(0.1 if side > 0 else 0.0))
		Art.outline(c, lf, Color(Art.c("contour"), 0.6), Art.TRAIT_FIN)
	c.draw_circle(base + Vector2(sway, -28), 3.5, or_.lightened(0.5))
	for i in 3:
		var u := fposmod(t * 0.5 + i / 3.0, 1.0)
		var p := base + Vector2(sin(i * 2.4) * 18.0, -10.0 - 34.0 * u)
		_sparkle_on(c, p, 3.0 * sin(PI * u), 1.0)


func _leaf(p: Vector2, l: float, a: float) -> PackedVector2Array:
	var d := Vector2.from_angle(a)
	var n := d.orthogonal()
	var pts := PackedVector2Array()
	for i in 7:
		var u := i / 6.0
		pts.append(p + d * l * u + n * l * 0.34 * sin(u * PI))
	for i in range(5, 0, -1):
		var u := i / 6.0
		pts.append(p + d * l * u - n * l * 0.34 * sin(u * PI))
	return pts


## Éclat en étoile à quatre branches.
func _sparkle(p: Vector2, r: float, v: float) -> void:
	_sparkle_on(self, p, r, v)


func _sparkle_on(c: CanvasItem, p: Vector2, r: float, v: float) -> void:
	if r <= 0.2:
		return
	var col := Color(Art.c("butin").lightened(0.5), v)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 2), p + Vector2(r * 0.4, 0), p + Vector2(0, r * 2), p + Vector2(-r * 0.4, 0)]), col)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 2, 0), p + Vector2(0, r * 0.4), p + Vector2(r * 2, 0), p + Vector2(0, -r * 0.4)]), col)


## Secret encore enfoui : quelques étincelles d'or dans un petit tas de cendre, qui grandissent
## quand on s'y tient.
func _draw_secret(v: float) -> void:
	var k := clampf(progress / HOLD[kind], 0.0, 1.0)
	var or_ := Art.c("butin")
	draw_colored_polygon(Art.ellipse(Vector2(0, 2), 20.0, 8.0, 14), Color(Art.c("brume"), v * 0.6))
	for i in 5:
		var a := TAU * i / 5.0 + t * 0.4
		var r := 10.0 + 6.0 * sin(t * 1.7 + i)
		draw_circle(Vector2.from_angle(a) * r * Vector2(1.0, 0.5), 1.5 + 0.7 * sin(t * 5.0 + i * 2.0), Color(or_, v * 0.75))
	draw_circle(Vector2.ZERO, 5.0 + 3.0 * k, Color(or_, v * (0.25 + 0.15 * sin(t * 3.0) + 0.4 * k)))
	_sparkle(Vector2(0, -4), 2.0 + 2.5 * k + 0.6 * sin(t * 3.0), v)
	if progress > 0.0:
		_ring(Vector2.ZERO, 30.0, k, v)
	else:
		_invite(30.0, v)


## Invite commune (prompt.gd) à l'approche : le cercle respire et un chevron indique où se tenir.
func _invite(r: float, v: float) -> void:
	if main == null or main.get("player") == null:
		return
	var dist: float = main.player.position.distance_to(position)
	Prompt.draw(self, r, 0.0, t, Prompt.nearness(dist, r) * v)


## Secret ravivé : une fleur d'or éclose dans une dalle fendue.
func _draw_secret_lit(v: float) -> void:
	var or_ := Art.c("butin")
	var slab := PackedVector2Array([Vector2(-26, 4), Vector2(-20, -8), Vector2(18, -10), Vector2(28, 2), Vector2(14, 12), Vector2(-16, 12)])
	_vol(slab, Art.c("interactif").darkened(0.25), v)
	draw_polyline(PackedVector2Array([Vector2(-6, -9), Vector2(-1, -1), Vector2(-5, 5), Vector2(1, 11)]), Color(Art.c("contour"), v), Art.TRAIT_FIN, true)
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	draw_circle(Vector2(0, -14), 26.0, Color(or_, v * (0.1 + 0.05 * b)))
	draw_line(Vector2(-1, -1), Vector2(0, -16), Color(Art.c("decor_vivant").lightened(0.3), v), 2.0, true)
	for i in 6:
		var a := TAU * i / 6.0 + t * 0.2
		draw_colored_polygon(_leaf(Vector2(0, -18), 9.0, a), Color(or_.lerp(Art.c("interactif"), 0.3 * (i % 2)), v))
	draw_circle(Vector2(0, -18), 3.0, Color(Art.c("interactif").lightened(0.4), v))
	_sparkle(Vector2(12, -28), 2.0 + 0.8 * sin(t * 3.0), v)
