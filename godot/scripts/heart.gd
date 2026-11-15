## Cœur de flétrissure de la région de Ronce : une structure qui fait naître des Flétris tant
## qu'elle vit. Pour la purifier, le Porte-Graine tient la zone qui l'entoure pendant HOLD_TIME
## secondes, sous des vagues d'ennemis. La purification pose Game.flags["ronce_coeur_purifie"],
## lance une grande vague de vie et ouvre l'arène de la Mère-Ronce (boss_arena.gd).
##
## Ce nœud est au niveau du sol (sous les personnages) : il dessine la zone à tenir. Le Cœur
## lui-même (Body) est rangé dans le calque trié en profondeur, avec les arbres et les personnages.
extends Node2D

signal purified

const BossBar = preload("res://scripts/boss_bar.gd")

const FLAG := "ronce_coeur_purifie"
## Position de repli tant que main.region_center("ronce") n'existe pas : dans la direction de la
## branche Ronce de l'arbre (milieu de son secteur), à mi-distance du bord du monde.
const FALLBACK_CENTER := Vector2(750.0, -1299.0)
## Rayon de la zone à tenir, et durée à y passer.
const ZONE := 240.0
const HOLD_TIME := 30.0
## Hors de la zone, l'avancée retombe lentement (jamais d'un coup, même après une mort).
const DECAY := 0.5
## Rayon du Cœur lui-même (obstacle).
const BODY_RADIUS := 44.0
## Le Cœur ne s'anime et ne fait naître des Flétris que si le joueur est à moins de WAKE.
const WAKE := 800.0
const SPAWN_EVERY := 3.5
const MAX_IDLE_SPAWNS := 6
## Vagues pendant le siège : une toutes les WAVE_EVERY secondes, de plus en plus fournies.
const WAVE_EVERY := 6.0
const WAVE_BASE := 4
const WAVE_GROWTH := 2
## Grande vague de vie à la purification : rayon final et durée.
const LIFE_RADIUS := 820.0
const LIFE_TIME := 2.2

var main
var center := FALLBACK_CENTER
## "fletri" (en sommeil), "siege" (zone tenue, vagues) ou "purifie".
var state := "fletri"
## Secondes passées à tenir la zone (0 à HOLD_TIME).
var progress := 0.0
var wave_index := 0
var wave_timer := 0.0
var spawn_timer := 2.0
## Flétris nés du Cœur encore en vie.
var spawned: Array = []
## Avancée de la vague de vie (secondes), -1 quand elle est finie ou n'a pas eu lieu.
var life_wave := -1.0
var life_step := 0.0
var t := 0.0
## Figé par les tests visuels : la logique ne tourne plus, l'état posé reste affiché.
var frozen := false
var rng := RandomNumberGenerator.new()
var body: Node2D
var bar
## Veines de corruption au sol : [angle, longueur, courbure], tirées une fois.
var _veins: Array = []


## Le Cœur lui-même, dessiné autour de son pied dans le calque trié en profondeur.
class Body extends Node2D:
	var heart

	func _draw() -> void:
		heart.draw_body(self)


func _ready() -> void:
	if main.has_method("region_center"):
		center = main.region_center("ronce")
	Game.seed_rng(rng, 3)
	var shape := RandomNumberGenerator.new()
	shape.seed = 41
	for i in 11:
		_veins.append([TAU * i / 11.0 + shape.randf_range(-0.2, 0.2), shape.randf_range(0.55, 1.0), shape.randf_range(-0.5, 0.5)])
	body = Body.new()
	body.heart = self
	body.position = center
	main.actors_layer.add_child(body)
	bar = BossBar.new()
	main.hud.get_parent().add_child(bar)


func is_purified() -> bool:
	return state == "purifie"


func _process(delta: float) -> void:
	t += delta
	# Rien à animer quand le Cœur est loin de l'écran.
	if not frozen and main.player.position.distance_squared_to(center) < 1600.0 * 1600.0:
		queue_redraw()
		body.queue_redraw()


func _physics_process(delta: float) -> void:
	if frozen:
		return
	# Le drapeau fait foi : une partie chargée retrouve le Cœur déjà purifié.
	if Game.flags.get(FLAG, false) and state != "purifie":
		_set_purified(false)
	if state == "purifie":
		_life_wave_step(delta)
		return
	if main.benchmark:
		return
	var p = main.player
	var to: Vector2 = p.position - center
	var d := to.length()
	if d < BODY_RADIUS + p.radius and d > 0.01:
		p.position = center + to / d * (BODY_RADIUS + p.radius)
	spawned = spawned.filter(func(e): return is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion())
	if d < ZONE:
		if state == "fletri":
			state = "siege"
			wave_index = 0
			wave_timer = 1.0
			main.hud.banner("Le Cœur de flétrissure s'éveille : tiens la zone !")
		progress += delta
	else:
		progress = maxf(0.0, progress - delta * DECAY)
		if state == "siege" and progress <= 0.0:
			state = "fletri"
	if state == "siege":
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_timer = WAVE_EVERY
			_spawn_wave()
		update_bar(d < ZONE)
		if progress >= HOLD_TIME:
			purify()
	else:
		bar.hide_bar()
		if d < WAKE:
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				spawn_timer = SPAWN_EVERY
				if spawned.size() < MAX_IDLE_SPAWNS:
					_spawn(center + Vector2.from_angle(rng.randf() * TAU) * (BODY_RADIUS + 30.0), 0)


## Barre du siège : ce qu'il reste de flétrissure, et le temps à tenir encore.
func update_bar(inside: bool) -> void:
	bar.show_bar("Cœur de flétrissure", 1.0 - progress / HOLD_TIME,
		"Tiens la zone : %d s" % ceili(HOLD_TIME - progress) if inside else "Reviens dans la zone : la flétrissure regagne du terrain", Color("b0503a"))


## Une vague arrive d'un même côté, en arc, juste hors de la zone.
func _spawn_wave() -> void:
	var count := WAVE_BASE + WAVE_GROWTH * wave_index
	var base := rng.randf() * TAU
	for i in count:
		var kind := 1 if rng.randf() < 0.4 else 0
		if wave_index >= 2 and i == 0:
			kind = 2
		var a := base + rng.randf_range(-0.7, 0.7)
		_spawn(center + Vector2.from_angle(a) * rng.randf_range(ZONE + 190.0, ZONE + 300.0), kind)
	main.fx.ring(center, BODY_RADIUS, ZONE, 0.5, Color(1.0, 0.45, 0.25, 0.7), 4.0)
	wave_index += 1


func _spawn(pos: Vector2, kind: int) -> void:
	var e = main.spawn_enemy_at(pos, kind)
	spawned.append(e)


## Purifie le Cœur : drapeau, vague de vie, ennemis proches purifiés, arène ouverte.
func purify() -> void:
	if state == "purifie":
		return
	Game.flags[FLAG] = true
	_set_purified(true)
	Sfx.play("coeur", center)
	main.hud.banner("Le Cœur est purifié : l'arène de la Mère-Ronce s'ouvre.")
	for i in 3:
		main.fx.ring(center, BODY_RADIUS, LIFE_RADIUS * (0.4 + 0.3 * i), 0.9 + 0.5 * i, Color(0.6, 1.0, 0.55, 0.9), 6.0)
	for e in main.enemies_near(center, ZONE + 420.0):
		e.take_damage(e.hp + 1.0, false)
	main.request_autosave()
	purified.emit()


func _set_purified(with_wave: bool) -> void:
	state = "purifie"
	progress = HOLD_TIME
	spawned = []
	life_wave = 0.0 if with_wave else -1.0
	life_step = 0.0
	if bar != null:
		bar.hide_bar()
	queue_redraw()
	body.queue_redraw()


## La vie avance en vague depuis le Cœur : le sol reverdit par anneaux de plus en plus larges.
func _life_wave_step(delta: float) -> void:
	if life_wave < 0.0:
		return
	life_wave += delta
	life_step -= delta
	if life_step <= 0.0:
		life_step = 0.12
		var k := clampf(life_wave / LIFE_TIME, 0.0, 1.0)
		var r := lerpf(140.0, LIFE_RADIUS, k)
		main.ground.paint(center, r, 0.3)
		main.flora.spawn_patch(center, r, 7, Color("e0675e"))
	if life_wave >= LIFE_TIME:
		life_wave = -1.0


## Zone à tenir, au sol : veines de corruption, anneau, et arc qui se remplit avec l'avancée.
func _draw() -> void:
	if state == "purifie":
		var glow := 0.10 + 0.04 * sin(t * 2.0)
		draw_circle(center, ZONE * 0.55, Color(0.55, 0.95, 0.5, glow))
		return
	var k := clampf(progress / HOLD_TIME, 0.0, 1.0)
	var ember := Color(0.95, 0.4, 0.2)
	draw_circle(center, ZONE, Color(0.1, 0.03, 0.03, 0.22))
	for v in _veins:
		var a: float = v[0]
		var pts := PackedVector2Array()
		for i in 7:
			var u := i / 6.0
			pts.append(center + Vector2.from_angle(a + v[2] * u * u) * lerpf(BODY_RADIUS * 0.6, ZONE * v[1], u))
		# La vie remonte les veines depuis le bord à mesure que la zone est tenue.
		draw_polyline(pts, Color(0.16, 0.07, 0.08, 0.85).lerp(Color(0.3, 0.55, 0.25, 0.8), k), 7.0)
		draw_polyline(pts, ember.lerp(Color(0.6, 1.0, 0.5), k) * Color(1, 1, 1, 0.35 + 0.2 * sin(t * 3.0 + a)), 2.0)
	var pulse := 0.5 + 0.5 * sin(t * (5.0 if state == "siege" else 2.0))
	var ring := ember.lerp(Color(1.0, 0.8, 0.5), pulse * 0.5)
	ring.a = 0.55 if state == "siege" else 0.3
	# Anneau en tirets : la limite de la zone.
	var dashes := 48
	for i in dashes:
		var a0 := TAU * i / dashes + t * 0.08
		draw_arc(center, ZONE, a0, a0 + TAU / dashes * 0.6, 4, ring, 3.0)
	if k > 0.0:
		draw_arc(center, ZONE - 9.0, -PI / 2.0, -PI / 2.0 + TAU * k, 96, Color(0.55, 0.95, 0.5, 0.9), 7.0)


## Le Cœur : bulbe de cendre hérissé d'épines, fendu de braises ; bouton de rose une fois purifié.
func draw_body(c: CanvasItem) -> void:
	var k := clampf(progress / HOLD_TIME, 0.0, 1.0)
	var beat := 1.0 + 0.05 * sin(t * (7.0 if state == "siege" else 2.4))
	var r := BODY_RADIUS * beat
	var lift := Vector2(0, -r * 0.55)
	if state == "purifie":
		c.draw_circle(lift, r * 1.7, Color(0.6, 1.0, 0.55, 0.12 + 0.04 * sin(t * 2.0)))
		for i in 6:
			var a := TAU * i / 6.0 + 0.3
			c.draw_colored_polygon(_petal(lift, a, r * 1.25, r * 0.55), Color("3b7d31"))
		for i in 7:
			var a := TAU * i / 7.0 + t * 0.15
			c.draw_colored_polygon(_petal(lift, a, r * 0.95, r * 0.5), Color("e0675e").lerp(Color("f48fb1"), 0.5 + 0.5 * sin(i * 2.1)))
		c.draw_circle(lift, r * 0.42, Color("f2d06b"))
		c.draw_circle(lift, r * 0.22, Color("fff3c4"))
		return
	# Racines noueuses au pied.
	for i in 7:
		var a := PI * (0.08 + 0.84 * i / 6.0)
		c.draw_line(Vector2.ZERO, Vector2(cos(a) * r * 1.5, sin(a) * r * 0.45), Color("1a1416"), 7.0)
	# Épines dressées autour du bulbe.
	var husk := Color("2a2026").lerp(Color("35502c"), k)
	for i in 14:
		var a := TAU * i / 14.0 + 0.1 * sin(t * 1.5 + i)
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * r * 0.16
		c.draw_colored_polygon(PackedVector2Array([lift + dir * r * 0.85 + side, lift + dir * r * 1.5, lift + dir * r * 0.85 - side]), husk.darkened(0.25))
	var pts := PackedVector2Array()
	for i in 22:
		var a := TAU * i / 22.0
		pts.append(lift + Vector2.from_angle(a) * r * (1.0 + 0.07 * sin(a * 4.0 + t * 2.0)))
	c.draw_colored_polygon(pts, husk)
	# Fissures de braise : elles virent au vert à mesure que le Cœur cède.
	var crack := Color("ff7a3a").lerp(Color("9af07a"), k)
	crack.a = 0.65 + 0.35 * sin(t * (9.0 if state == "siege" else 3.0))
	for i in 5:
		var a := -PI / 2.0 + (i - 2) * 0.55
		var p0 := lift + Vector2.from_angle(a) * r * 0.2
		var p1 := lift + Vector2.from_angle(a + 0.25) * r * 0.6
		var p2 := lift + Vector2.from_angle(a - 0.1) * r * 0.92
		c.draw_polyline(PackedVector2Array([p0, p1, p2]), crack, 3.0)
	c.draw_circle(lift, r * 0.3, Color(crack.r, crack.g, crack.b, 0.35))
	c.draw_circle(lift, r * 0.16, crack)


func _petal(origin: Vector2, angle: float, length: float, width: float) -> PackedVector2Array:
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal() * width
	return PackedVector2Array([origin, origin + dir * length * 0.55 + side, origin + dir * length, origin + dir * length * 0.55 - side])
