## Greffe tombée au sol (autel, boss, secret, élite) : ramassée au contact, elle entre dans
## l'inventaire (Game.give_graft). Dessin vectoriel distinct de l'essence d'expérience :
## un médaillon doré qui flotte, cerclé d'épines qui tournent, avec la forme de la greffe au centre.
extends Node2D

const Content = preload("res://scripts/content.gd")

## Distance de ramassage et d'attraction (pixels).
const PICK := 34.0
const PULL := 130.0
## Taille du dessin (le médaillon fait 27 px de diamètre avant mise à l'échelle).
const SCALE := 1.45

var main
var graft_id := ""
var t := 0.0
## Petit saut à l'apparition (secondes restantes).
var pop := 0.6


func _ready() -> void:
	Game.grafts_on_ground[graft_id] = true


## Animation seulement (flottement, rotation, saut d'apparition).
func _process(delta: float) -> void:
	t += delta
	pop = maxf(0.0, pop - delta)
	queue_redraw()


## Logique à pas fixe : attirée doucement par le joueur, ramassée au contact.
func _physics_process(delta: float) -> void:
	if main == null or main.player == null or pop > 0.3:
		return
	var to: Vector2 = main.player.position - position
	var d := to.length()
	if d < PULL:
		position += to / maxf(d, 1.0) * minf(d, 260.0 * delta)
	if d < PICK:
		pick_up()


func pick_up() -> void:
	if is_queued_for_deletion():
		return
	Game.grafts_on_ground.erase(graft_id)
	if Game.give_graft(graft_id):
		Sfx.play("greffe", position)
		if main != null and main.fx != null:
			# Impact : onde dorée et gerbe d'éclats qui file vers le Porte-Graine (retour).
			main.fx.ring(position, 10.0, 90.0, 0.5, Art.c("or"), 4.0)
			main.fx.ring(position, 4.0, 46.0, 0.3, Art.c("danger_eclair"), 3.0)
			main.fx.pickup(position, "epine", 10, main.player.position)
			main.fx.shake(0.12)
		# La greffe jaillit, tourne autour du héros et le rejoint (world_fx.gd).
		if main != null and main.get("world_fx") != null:
			main.world_fx.graft_pickup(position, graft_id)
	queue_free()


func _draw() -> void:
	var g: Dictionary = Content.grafts().get(graft_id, {})
	var col := Color(str(g.get("color", "#f2d06b")))
	var lift := -6.0 - 4.0 * sin(t * 2.4) - 30.0 * sin(clampf(pop / 0.6, 0.0, 1.0) * PI)
	# Ombre au sol, qui rétrécit quand la greffe monte.
	draw_set_transform(Vector2(0, 12), 0.0, Vector2(SCALE, SCALE * 0.35))
	draw_circle(Vector2.ZERO, 13.0 + lift * 0.15, Color(0, 0, 0, 0.3))
	# Anticipation : le médaillon gonfle un instant quand le joueur approche.
	var near := 1.0 - smoothstep(PICK, PULL, main.player.position.distance_to(position)) if main != null and main.player != null else 0.0
	var sc := SCALE * (1.0 + 0.12 * near * (0.5 + 0.5 * sin(t * 9.0)))
	draw_set_transform(Vector2(0, lift), 0.0, Vector2(sc, sc))
	draw_circle(Vector2.ZERO, 24.0, Color(1.0, 0.86, 0.45, 0.10 + 0.05 * sin(t * 4.0)))
	# Couronne d'épines qui tourne.
	for i in 6:
		var a := t * 0.8 + TAU * i / 6.0
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * 3.2
		draw_colored_polygon(PackedVector2Array([dir * 13.0 + side, dir * 21.0, dir * 13.0 - side]), Color("e0675e").darkened(0.15))
	draw_circle(Vector2.ZERO, 13.5, Color("3a2a1a"))
	draw_arc(Vector2.ZERO, 13.5, 0.0, TAU, 28, Color("f2d06b"), 2.0, true)
	draw_shape(self, str(g.get("shape", "feuille")), Vector2.ZERO, 8.5, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Forme d'une greffe (champ « shape » de grafts.json), centrée sur p, dans un disque de rayon s.
## Partagée avec l'inventaire de l'écran de l'arbre.
static func draw_shape(c: CanvasItem, shape: String, p: Vector2, s: float, col: Color) -> void:
	var dark := col.darkened(0.55)
	match shape:
		"epine":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.42, s * 0.75), p + Vector2(-s * 0.42, s * 0.75)]), col)
			c.draw_line(p + Vector2(0, -s * 0.5), p + Vector2(0, s * 0.6), dark, maxf(1.0, s * 0.12))
		"racine":
			var w := maxf(1.5, s * 0.22)
			c.draw_line(p + Vector2(0, -s), p + Vector2(0, s * 0.2), col, w)
			c.draw_line(p + Vector2(0, s * 0.2), p + Vector2(-s * 0.7, s * 0.9), col, w)
			c.draw_line(p + Vector2(0, s * 0.2), p + Vector2(s * 0.7, s * 0.9), col, w)
			c.draw_line(p + Vector2(0, -s * 0.2), p + Vector2(s * 0.55, -s * 0.55), col, w * 0.8)
		"fleur":
			for i in 5:
				var a := TAU * i / 5.0 - PI / 2.0
				c.draw_circle(p + Vector2.from_angle(a) * s * 0.52, s * 0.4, col)
			c.draw_circle(p, s * 0.34, Color("fff3c4"))
		"coeur":
			var pts := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				var x := 16.0 * pow(sin(a), 3)
				var y := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
				pts.append(p + Vector2(x, y) * s / 17.0)
			c.draw_colored_polygon(pts, col)
		# Greffes de cycle (New Game+) : dessins à l'encre de l'herbier, trait sombre autour.
		"fruit":
			# Le fruit de la graine : rond, une queue et une feuille, un reflet.
			var ink := Color(col.darkened(0.7), 0.95)
			var w := maxf(1.0, s * 0.12)
			var body := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				var r := s * (0.72 - 0.08 * cos(a * 2.0 + PI) * (1.0 if sin(a) < 0.0 else 0.0))
				body.append(p + Vector2(0, s * 0.15) + Vector2(cos(a) * r, sin(a) * r * 0.92))
			c.draw_colored_polygon(body, col)
			body.append(body[0])
			c.draw_polyline(body, ink, w, true)
			c.draw_line(p + Vector2(0, -s * 0.5), p + Vector2(s * 0.12, -s * 0.95), ink, w * 1.2, true)
			var leaf := PackedVector2Array()
			for i in 10:
				var a := TAU * i / 10.0
				leaf.append(p + Vector2(s * 0.42, -s * 0.85) + Vector2(cos(a) * s * 0.34, sin(a) * s * 0.15).rotated(-0.45))
			c.draw_colored_polygon(leaf, Color("7fa35b"))
			c.draw_circle(p + Vector2(-s * 0.28, -s * 0.05), s * 0.14, Color(1, 1, 1, 0.55))
		"fanee":
			# Fleur fanée : pétales qui retombent d'un côté, cœur assombri, tige courbée.
			var ink := Color(col.darkened(0.7), 0.95)
			var w := maxf(1.0, s * 0.1)
			c.draw_line(p + Vector2(0, s * 0.1), p + Vector2(-s * 0.3, s * 0.95), ink, w * 1.3, true)
			for i in 5:
				var a := -PI / 2.0 + TAU * i / 5.0
				var droop := 0.35 * maxf(0.0, cos(a - PI / 2.0))
				var q := p + Vector2.from_angle(a) * s * 0.5 + Vector2(0, s * droop)
				var pet := PackedVector2Array()
				for k in 10:
					var b := TAU * k / 10.0
					pet.append(q + Vector2(cos(b) * s * 0.36, sin(b) * s * 0.24).rotated(a + droop))
				c.draw_colored_polygon(pet, col if i % 2 == 0 else col.darkened(0.12))
				pet.append(pet[0])
				c.draw_polyline(pet, ink, w * 0.8, true)
			c.draw_circle(p, s * 0.26, col.darkened(0.45))
			c.draw_arc(p, s * 0.26, 0.0, TAU, 14, ink, w * 0.8, true)
		"cerne":
			# Rondelle de bois : cernes concentriques à l'encre, une fente.
			var ink := Color(col.darkened(0.7), 0.95)
			var w := maxf(1.0, s * 0.1)
			c.draw_circle(p, s * 0.88, col)
			for k in 3:
				c.draw_arc(p + Vector2(s * 0.04 * k, s * 0.03 * k), s * (0.66 - 0.2 * k), 0.0, TAU, 24, col.darkened(0.3 + 0.08 * k), w * 0.8, true)
			c.draw_circle(p + Vector2(s * 0.1, s * 0.08), s * 0.08, ink)
			c.draw_arc(p, s * 0.88, 0.0, TAU, 28, ink, w * 1.2, true)
			c.draw_line(p + Vector2(s * 0.88, 0).rotated(-0.6), p + Vector2(s * 0.45, 0).rotated(-0.55), ink, w, true)
		"pepin":
			# Pépin ailé : une graine en goutte et son aile nervurée.
			var ink := Color(col.darkened(0.7), 0.95)
			var w := maxf(1.0, s * 0.1)
			var wing := PackedVector2Array([p + Vector2(-s * 0.1, s * 0.35), p + Vector2(-s * 0.55, -s * 0.2), p + Vector2(-s * 0.35, -s * 0.95),
				p + Vector2(s * 0.15, -s * 0.75), p + Vector2(s * 0.2, s * 0.2)])
			c.draw_colored_polygon(wing, Color(col.lightened(0.35), 0.85))
			wing.append(wing[0])
			c.draw_polyline(wing, ink, w * 0.8, true)
			for k in 3:
				c.draw_line(p + Vector2(0, s * 0.3), p + Vector2(-s * (0.45 - 0.25 * k), -s * (0.25 + 0.25 * k)), Color(ink, 0.6), w * 0.6, true)
			var seed := PackedVector2Array()
			for i in 14:
				var a := TAU * i / 14.0
				seed.append(p + Vector2(s * 0.12, s * 0.5) + Vector2(cos(a) * s * 0.3, sin(a) * s * 0.4 - (s * 0.15 if sin(a) < 0.0 else 0.0)).rotated(0.3))
			c.draw_colored_polygon(seed, col.darkened(0.25))
			seed.append(seed[0])
			c.draw_polyline(seed, ink, w, true)
		_:
			# Feuille, nervure au milieu.
			var leaf := PackedVector2Array()
			for i in 14:
				var a := TAU * i / 14.0
				leaf.append(p + Vector2(sin(a) * s * 0.5, -cos(a) * s).rotated(0.5))
			c.draw_colored_polygon(leaf, col)
			c.draw_line(p + Vector2(0, s * 0.95).rotated(0.5), p + Vector2(0, -s * 0.95).rotated(0.5), dark, maxf(1.0, s * 0.12))
