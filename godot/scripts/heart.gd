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
const Content = preload("res://scripts/content.gd")

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


## Le joueur est mort pendant le siège : le Cœur se rendort, tout est à recommencer.
## Renvoie true s'il y avait un siège en cours.
func reset_siege() -> bool:
	if state != "siege":
		return false
	state = "fletri"
	progress = 0.0
	wave_index = 0
	wave_timer = 0.0
	spawn_timer = 2.0
	spawned = []
	bar.hide_bar()
	return true


## Barre du siège : ce qu'il reste de flétrissure, et le temps à tenir encore.
func update_bar(inside: bool) -> void:
	bar.show_bar("Cœur de flétrissure", 1.0 - progress / HOLD_TIME,
		"Tiens la zone : %d s" % ceili(HOLD_TIME - progress) if inside else "Reviens dans la zone : la flétrissure regagne du terrain", Art.ec("cendre", "sombre").lerp(Art.c("danger"), 0.5))


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
	main.fx.ring(center, BODY_RADIUS, ZONE, 0.5, Color(Art.ec("cendre"), 0.7), 4.0)
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
	var reward: Dictionary = Content.rewards().get("coeur", {}).get("ronce", {})
	Game.grant_points(int(reward.get("points", 1)), "coeur", "ronce_coeur")
	for i in 3:
		main.fx.ring(center, BODY_RADIUS, LIFE_RADIUS * (0.4 + 0.3 * i), 0.9 + 0.5 * i, Color(Art.ec("seve"), 0.9), 6.0)
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
		main.flora.spawn_patch(center, r, 7, Art.ec("saignement", "clair"))
	if life_wave >= LIFE_TIME:
		life_wave = -1.0


## Zone à tenir, au sol : quelques veines de corruption, un anneau en tirets couleur de braise,
## et l'arc de sève qui se remplit avec l'avancée. Purifié : une clairière qui respire.
func _draw() -> void:
	var seve := Art.ec("seve")
	if state == "purifie":
		var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
		draw_circle(center, ZONE * 0.62, Color(seve, 0.05 + 0.03 * b))
		draw_arc(center, ZONE * 0.62, 0.0, TAU, 72, Color(seve, 0.12 + 0.06 * b), Art.TRAIT, true)
		return
	var k := clampf(progress / HOLD_TIME, 0.0, 1.0)
	var braise := Art.ec("cendre")
	var siege := state == "siege"
	draw_circle(center, ZONE, Color(Art.ec("cendre", "sombre"), 0.16 if siege else 0.1))
	for v in _veins:
		var a: float = v[0]
		var pts := PackedVector2Array()
		for i in 7:
			var u := i / 6.0
			pts.append(center + Vector2.from_angle(a + v[2] * u * u) * lerpf(BODY_RADIUS * 0.6, ZONE * v[1], u))
		# La vie remonte les veines depuis le bord à mesure que la zone est tenue.
		draw_polyline(pts, Color(Art.c("ennemi").darkened(0.45), 0.7).lerp(Color(Art.c("decor_vivant"), 0.7), k), 5.0, true)
		var glow := braise.lerp(seve, k)
		glow.a = 0.25 + 0.2 * sin(t * 3.0 + a)
		draw_polyline(pts, glow, Art.TRAIT_FIN, true)
	var pulse := 0.5 + 0.5 * sin(t * (5.0 if siege else 2.0))
	var ring := braise.lerp(Art.ec("cendre", "clair"), pulse * 0.5)
	ring.a = 0.7 if siege else 0.4
	# Anneau en tirets : la limite de la zone, qui tourne lentement.
	var dashes := 40
	for i in dashes:
		var a0 := TAU * i / dashes + t * 0.08
		draw_arc(center, ZONE, a0, a0 + TAU / dashes * 0.55, 4, ring, Art.TRAIT_FORT if siege else Art.TRAIT, true)
	if k > 0.0:
		draw_arc(center, ZONE - 10.0, 0.0, TAU, 96, Color(Art.c("contour"), 0.35), 8.0, true)
		draw_arc(center, ZONE - 10.0, -PI / 2.0, -PI / 2.0 + TAU * k, 96, seve, 6.0, true)
		draw_circle(center + Vector2.from_angle(-PI / 2.0 + TAU * k) * (ZONE - 10.0), 5.0, Art.ec("seve", "clair"))


## Le Cœur : un bulbe anguleux de Flétri (forme cassée, contour clair), couronné d'épines et fendu
## de braises ; des braises en montent et se voient de loin. Il vire au vert à mesure qu'il cède.
## Purifié : une grande rose en volume.
func draw_body(c: CanvasItem) -> void:
	var k := clampf(progress / HOLD_TIME, 0.0, 1.0)
	var siege := state == "siege"
	var beat := 1.0 + 0.05 * sin(t * (7.0 if siege else TAU / Anim.DUREE["respiration"]))
	# Dessiné un peu plus grand que son obstacle : on le repère de loin.
	var r := BODY_RADIUS * 1.25 * beat
	var lift := Vector2(0, -r * 0.6)
	if state == "purifie":
		_draw_rose(c, lift, BODY_RADIUS * 1.3)
		return
	Art.shadow(c, Vector2(0, 2), r * 1.2)
	# Racines noueuses au pied.
	var root := Art.c("ennemi").darkened(0.55)
	for i in 6:
		var a := PI * (0.08 + 0.84 * i / 5.0)
		var tip := Vector2(cos(a) * r * 1.55, sin(a) * r * 0.42)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-6, -2), tip, Vector2(6, -2)]), root)
	# Couronne d'épines, en volume (un côté clair, un côté sombre).
	var husk := Art.c("ennemi").lerp(Art.c("decor_vivant").darkened(0.2), k)
	for i in 12:
		var a := TAU * i / 12.0 - PI / 2.0 + 0.05 * sin(t * 1.5 + i)
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var base := lift + d * r * 0.8
		var tip := base + d * r * (0.8 if i % 2 == 0 else 0.55) * (1.0 if d.y < 0.3 else 0.7)
		c.draw_colored_polygon(PackedVector2Array([base + n * r * 0.2, tip, base]), husk.lightened(0.1))
		c.draw_colored_polygon(PackedVector2Array([base, tip, base - n * r * 0.2]), husk.darkened(0.35))
	# Bulbe anguleux : polygone cassé, volume, contour clair des Flétris.
	var pts := PackedVector2Array()
	var n_pts := 9
	for i in n_pts:
		var a := TAU * i / n_pts - PI / 2.0
		var rr := r * (1.0 if i % 2 == 0 else 0.82) * (1.0 + 0.04 * sin(t * 2.0 + i))
		pts.append(lift + Vector2.from_angle(a) * rr)
	Art.volume(c, pts, husk, 0.5)
	Art.outline(c, pts, Art.c("ennemi_contour").lerp(Art.ec("seve", "clair"), k), Art.TRAIT_FORT)
	# Fissures de braise : elles virent au vert à mesure que le Cœur cède.
	var crack := Art.ec("cendre").lerp(Art.ec("seve"), k)
	crack.a = 0.7 + 0.3 * sin(t * (9.0 if siege else 3.0))
	for i in 5:
		var a := -PI / 2.0 + (i - 2) * 0.62 + PI
		var p0 := lift + Vector2.from_angle(a) * r * 0.2
		var p1 := lift + Vector2.from_angle(a + 0.3) * r * 0.55
		var p2 := lift + Vector2.from_angle(a - 0.1) * r * 0.8
		c.draw_polyline(PackedVector2Array([p0, p1, p2]), crack, Art.TRAIT, true)
	# Œil de braise au centre.
	c.draw_circle(lift, r * 0.34, Color(crack.r, crack.g, crack.b, 0.3))
	var eye := PackedVector2Array([lift + Vector2(-r * 0.24, 0), lift + Vector2(0, -r * 0.13), lift + Vector2(r * 0.24, 0), lift + Vector2(0, r * 0.13)])
	c.draw_colored_polygon(eye, Art.ec("cendre", "clair").lerp(Art.ec("seve", "clair"), k))
	c.draw_circle(lift, r * 0.07, Art.c("contour"))
	# Braises qui montent : on repère le Cœur de loin.
	var ember_col := Art.ec("cendre", "clair").lerp(Art.ec("seve", "clair"), k)
	for i in 10:
		var u := fposmod(t * (0.35 if not siege else 0.6) + i / 10.0, 1.0)
		var p := lift + Vector2(sin(i * 2.7 + t * 1.1) * r * (0.5 + 0.6 * u), -r * 0.8 - 160.0 * u)
		var sz := 3.2 * (1.0 - u * 0.6)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -sz * 1.4), p + Vector2(sz, 0), p + Vector2(0, sz * 1.1), p + Vector2(-sz, 0)]), Color(ember_col, sin(PI * u) * 0.9))


## Le Cœur purifié : une rose ouverte, feuilles dessous, pétales en deux rangs, cœur d'or.
func _draw_rose(c: CanvasItem, lift: Vector2, r: float) -> void:
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
	Art.shadow(c, Vector2(0, 2), r * 1.3)
	Art.glow(c, lift, r * (2.0 + 0.1 * b), "seve")
	var leaf := Art.c("decor_vivant")
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var lf := _petal(lift, a, r * 1.45, r * 0.42)
		Art.volume(c, lf, leaf.darkened(0.1 * (i % 2)), 0.5)
		Art.outline(c, lf, Art.c("contour"), Art.TRAIT_FIN)
	var petal := Art.ec("saignement", "clair").lerp(Art.c("interactif"), 0.35)
	for row in 2:
		var n := 6 - row
		for i in n:
			var a := TAU * i / n + row * 0.5 + t * 0.06 * (1 - 2 * row)
			var pp := _petal(lift, a, r * (1.0 - row * 0.32), r * (0.5 - row * 0.1))
			Art.volume(c, pp, petal.lightened(0.1 * row), 0.7)
			Art.outline(c, pp, Color(Art.c("contour"), 0.7), Art.TRAIT_FIN)
	Art.volume_circle(c, lift, r * 0.28, Art.c("or"), 0.8)
	for i in 5:
		var u := fposmod(t * 0.3 + i / 5.0, 1.0)
		var p := lift + Vector2(sin(i * 2.3 + t) * r * 0.6, -r * 0.4 - 90.0 * u)
		c.draw_circle(p, 2.0, Color(Art.ec("seve", "clair"), sin(PI * u)))


func _petal(origin: Vector2, angle: float, length: float, width: float) -> PackedVector2Array:
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal() * width
	return PackedVector2Array([origin, origin + dir * length * 0.55 + side, origin + dir * length, origin + dir * length * 0.55 - side])
