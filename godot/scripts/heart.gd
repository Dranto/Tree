## Cœur de flétrissure d'une région (un par région, posé par main.gd) : une structure qui fait
## naître des Flétris tant qu'elle vit. Pour la purifier, le Porte-Graine tient la zone qui l'entoure
## pendant hold_time secondes, sous des vagues d'ennemis. La purification pose
## Game.flags["<région>_coeur_purifie"], lance une grande vague de vie et ouvre l'arène du boss de la
## région (boss_arena.gd). Ses réglages (zone, durée, vagues, textes) sont lus dans la section
## « heart » de data/regions/<région>.json ; sans elle, ceux du Cœur de Ronce.
##
## Ce nœud est au niveau du sol (sous les personnages) : il dessine la zone à tenir. Le Cœur
## lui-même (Body) est rangé dans le calque trié en profondeur, avec les arbres et les personnages.
extends Node2D

signal purified

const BossBar = preload("res://scripts/boss_bar.gd")
const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

## Position de repli sans scène de jeu (main.region_center) : dans la direction de la branche
## Ronce de l'arbre (milieu de son secteur), à mi-distance du bord du monde.
const FALLBACK_CENTER := Vector2(750.0, -1299.0)
## Hors de la zone, l'avancée retombe lentement (jamais d'un coup, même après une mort).
const DECAY := 0.5
## Rayon du Cœur lui-même (obstacle).
const BODY_RADIUS := 44.0
## Le Cœur ne s'anime et ne fait naître des Flétris que si le joueur est à moins de WAKE.
const WAKE := 800.0
## Grande vague de vie à la purification : durée.
const LIFE_TIME := 2.2

var main
## Région du Cœur (data/regions/<région>.json) et son drapeau de purification.
var region := "ronce"
var flag := "ronce_coeur_purifie"
var title := "Cœur de flétrissure"
## Rayon de la zone à tenir, et durée à y passer.
var zone := 240.0
var hold_time := 30.0
## Flétris nés au repos : un toutes les spawn_every secondes, idle_max en même temps au plus.
var spawn_every := 3.5
var idle_max := 6
var idle_kind := "fletri"
## Vagues pendant le siège : une toutes les wave_every secondes, de plus en plus fournies
## (wave_base + wave_growth par vague). Chaque ennemi est l'une des deux sortes de wave_kinds (la
## seconde avec la chance second_share) ; à partir de la vague big_from, le premier est big_kind.
var wave_every := 6.0
var wave_base := 4
var wave_growth := 2
var wave_kinds: Array = ["fletri", "cendreux"]
var second_share := 0.4
var big_kind := "colosse"
var big_from := 2
## Grande vague de vie à la purification : rayon final et couleur des fleurs.
var life_radius := 820.0
var life_color := Color.WHITE
var wake_banner := "Le Cœur de flétrissure s'éveille : tiens la zone !"
var purified_banner := "Le Cœur est purifié : l'arène s'ouvre."
var center := FALLBACK_CENTER
## "fletri" (en sommeil), "siege" (zone tenue, vagues) ou "purifie".
var state := "fletri"
## Secondes passées à tenir la zone (0 à hold_time).
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


## Lit les réglages du Cœur dans le fichier de la région (appelé par _ready).
func configure(id: String) -> void:
	region = id
	flag = Regions.heart_flag(id)
	var h := Regions.section(id, "heart")
	title = str(h.get("name", title))
	zone = float(h.get("zone", zone))
	hold_time = float(h.get("hold_time", hold_time))
	var w: Dictionary = h.get("waves", {})
	wave_every = float(w.get("every", wave_every))
	wave_base = int(w.get("base", wave_base))
	wave_growth = int(w.get("growth", wave_growth))
	wave_kinds = w.get("kinds", wave_kinds)
	second_share = float(w.get("second_share", second_share))
	big_kind = str(w.get("big", big_kind))
	big_from = int(w.get("big_from", big_from))
	var idle: Dictionary = h.get("idle", {})
	spawn_every = float(idle.get("every", spawn_every))
	idle_max = int(idle.get("max", idle_max))
	idle_kind = str(idle.get("kind", idle_kind))
	life_radius = float(h.get("life_radius", life_radius))
	life_color = Regions.color(h.get("life_color", "saignement/clair"))
	wake_banner = str(h.get("wake_banner", wake_banner))
	purified_banner = str(h.get("purified_banner", purified_banner))


func _ready() -> void:
	configure(region)
	if main.has_method("region_center"):
		center = main.region_center(region)
	# Tirage propre à chaque Cœur (celui de la première région garde l'ancien).
	Game.seed_rng(rng, 3 + 10 * maxi(0, Regions.ids().find(region)))
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
	# Rien à animer quand le Cœur est loin de l'écran (avec trois régions, deux Cœurs tombaient
	# souvent à moins de 1600 px du joueur sans être visibles) : on regarde le cadre de la caméra.
	if not frozen and main.player.position.distance_squared_to(center) < 1600.0 * 1600.0 and _near_view():
		queue_redraw()
		body.queue_redraw()


## Le Cœur (zone comprise, plus une marge) touche le cadre visible.
func _near_view() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return view.grow(zone + 420.0).has_point(center)


func _physics_process(delta: float) -> void:
	if frozen:
		return
	# Le drapeau fait foi : une partie chargée retrouve le Cœur déjà purifié.
	if Game.flags.get(flag, false) and state != "purifie":
		_set_purified(false)
	if state == "purifie":
		_life_wave_step(delta)
		return
	if main.benchmark and main.bench_scene != "coeur":
		return
	var p = main.player
	var to: Vector2 = p.position - center
	var d := to.length()
	if d < BODY_RADIUS + p.radius and d > 0.01:
		p.position = center + to / d * (BODY_RADIUS + p.radius)
	spawned = spawned.filter(func(e): return is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion())
	if d < zone:
		if state == "fletri":
			state = "siege"
			wave_index = 0
			wave_timer = 1.0
			main.hud.banner(wake_banner, "combat")
		progress += delta
	else:
		progress = maxf(0.0, progress - delta * DECAY)
		if state == "siege" and progress <= 0.0:
			state = "fletri"
	if state == "siege":
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_timer = wave_every
			_spawn_wave()
		update_bar(d < zone)
		if progress >= hold_time:
			purify()
	else:
		bar.hide_bar()
		if d < WAKE:
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				spawn_timer = spawn_every
				if spawned.size() < idle_max:
					_spawn(center + Vector2.from_angle(rng.randf() * TAU) * (BODY_RADIUS + 30.0), idle_kind)


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
	bar.show_bar(title, 1.0 - progress / hold_time,
		"Tiens la zone : %d s" % ceili(hold_time - progress) if inside else "Reviens dans la zone : la flétrissure regagne du terrain", Art.ec("cendre", "sombre").lerp(Art.c("danger"), 0.5))


## Une vague arrive d'un même côté, en arc, juste hors de la zone.
func _spawn_wave() -> void:
	var count := wave_base + wave_growth * wave_index
	var base := rng.randf() * TAU
	for i in count:
		var kind: String = wave_kinds[1] if rng.randf() < second_share else wave_kinds[0]
		if wave_index >= big_from and i == 0:
			kind = big_kind
		var a := base + rng.randf_range(-0.7, 0.7)
		_spawn(center + Vector2.from_angle(a) * rng.randf_range(zone + 190.0, zone + 300.0), kind)
	main.fx.ring(center, BODY_RADIUS, zone, 0.5, Color(Art.ec("cendre"), 0.7), 4.0)
	wave_index += 1


func _spawn(pos: Vector2, kind: String) -> void:
	var e = main.spawn_enemy_at(pos, EnemyScript.kind_index(kind))
	spawned.append(e)


## Purifie le Cœur : drapeau, vague de vie, ennemis proches purifiés, arène ouverte.
func purify() -> void:
	if state == "purifie":
		return
	Game.flags[flag] = true
	_set_purified(true)
	Sfx.play("coeur", center)
	main.hud.banner(purified_banner)
	var reward: Dictionary = Content.rewards().get("coeur", {}).get(region, {})
	Game.grant_points(int(reward.get("points", 1)), "coeur", region + "_coeur")
	for i in 3:
		main.fx.ring(center, BODY_RADIUS, life_radius * (0.4 + 0.3 * i), 0.9 + 0.5 * i, Color(Art.ec("seve"), 0.9), 6.0)
	for e in main.enemies_near(center, zone + 420.0):
		e.take_damage(e.hp + 1.0, false)
	main.request_autosave()
	purified.emit()


func _set_purified(with_wave: bool) -> void:
	state = "purifie"
	progress = hold_time
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
		var r := lerpf(140.0, life_radius, k)
		main.ground.paint(center, r, 0.3)
		main.flora.spawn_patch(center, r, 7, life_color)
	if life_wave >= LIFE_TIME:
		life_wave = -1.0


## Zone à tenir, au sol : quelques veines de corruption, un anneau en tirets couleur de braise,
## et l'arc de sève qui se remplit avec l'avancée. Purifié : une clairière qui respire.
func _draw() -> void:
	var seve := Art.ec("seve")
	if state == "purifie":
		var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"])
		draw_circle(center, zone * 0.62, Color(seve, 0.05 + 0.03 * b))
		draw_arc(center, zone * 0.62, 0.0, TAU, 72, Color(seve, 0.12 + 0.06 * b), Art.TRAIT, true)
		return
	var k := clampf(progress / hold_time, 0.0, 1.0)
	var braise := Art.ec("cendre")
	var siege := state == "siege"
	draw_circle(center, zone, Color(Art.ec("cendre", "sombre"), 0.16 if siege else 0.1))
	for v in _veins:
		var a: float = v[0]
		var pts := PackedVector2Array()
		for i in 7:
			var u := i / 6.0
			pts.append(center + Vector2.from_angle(a + v[2] * u * u) * lerpf(BODY_RADIUS * 0.6, zone * v[1], u))
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
		draw_arc(center, zone, a0, a0 + TAU / dashes * 0.55, 4, ring, Art.TRAIT_FORT if siege else Art.TRAIT, true)
	if k > 0.0:
		draw_arc(center, zone - 10.0, 0.0, TAU, 96, Color(Art.c("contour"), 0.35), 8.0, true)
		draw_arc(center, zone - 10.0, -PI / 2.0, -PI / 2.0 + TAU * k, 96, seve, 6.0, true)
		draw_circle(center + Vector2.from_angle(-PI / 2.0 + TAU * k) * (zone - 10.0), 5.0, Art.ec("seve", "clair"))


## Le Cœur lui-même, dessiné par les dessins de sa région (Regions.art : scripts/region_art/<art>.gd,
## region_art.gd par défaut) : flétri, il bat (plus vite pendant le siège) et vire au vert à mesure
## qu'il cède ; purifié, il devient la plante de sa région (la rose du roncier par défaut).
func draw_body(c: CanvasItem) -> void:
	var art: GDScript = Regions.art(region) if Regions.exists(region) else load(Regions.BASE_ART)
	# Dessiné un peu plus grand que son obstacle : on le repère de loin.
	var r := BODY_RADIUS * 1.25 * pulse()
	var lift := Vector2(0, -r * 0.6)
	if state == "purifie":
		art.draw_heart_purified(c, self, lift, BODY_RADIUS * 1.3)
	else:
		art.draw_heart(c, self, lift, r)


## Battement du Cœur (autour de 1) : plus rapide pendant le siège.
func pulse() -> float:
	return 1.0 + 0.05 * sin(t * (7.0 if state == "siege" else TAU / Anim.DUREE["respiration"]))


## Avancée de la purification (0 à 1).
func ratio() -> float:
	return clampf(progress / hold_time, 0.0, 1.0)
