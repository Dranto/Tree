## Arène de la finale (main.finale), sous la graine. Réglée par data/finale.json › boss.
##
## L'arène n'est pas dans le carré du monde : c'est un creux entre les racines de la graine, posé
## loin au sud du monde (CAVE), où rien d'autre n'existe. On y entre par une brèche au pied de la
## graine (descent_point) : s'y tenir DESCENT_HOLD secondes fait descendre le joueur ; dans l'arène,
## se tenir dans le puits de lumière où l'on est arrivé fait remonter (hors combat).
##
## - "fermee"  : une région au moins n'est pas purifiée ; rien ne se voit au pied de la graine ;
## - "ouverte" : toutes les régions sont purifiées (Regions.all_purified) : drapeau finale_ouverte,
##               la brèche s'ouvre ; descendre, puis s'avancer vers le centre, réveille le boss ;
## - "combat"  : le mur de racines tient le joueur ; en phase 3 (seconde forme du boss), le creux
##               s'effondre (start_collapse) : le sol au-delà de radius_collapse tombe dans le
##               gouffre, il ne reste qu'une île plus étroite autour d'elle ;
## - "vaincue" : drapeau finale_vaincue ; le creux refleurit et l'épilogue suit (quest_ui.gd).
##
## Même interface que boss_arena.gd (dont elle hérite le combat, la barre et le robot du mode
## « -- --autotest=boss --region=finale ») : state, center, radius, in_combat(), entrance(),
## bot_input(p), plus holds(pos) (la position est-elle sous la graine ?) et descent_point().
## Mourir pendant le combat ramène au dernier sanctuaire ; la sève attend près de la brèche.
extends "res://scripts/boss_arena.gd"

const FINALE_PATH := "finale"
## Centre du creux sous la graine : hors du monde (± Regions.WORLD_HALF), assez loin pour que
## l'écran le plus large n'en voie jamais le bord.
const CAVE := Vector2(0.0, Regions.WORLD_HALF + 3000.0)
## Brèche au pied de la graine (le sanctuaire de la Graine est au centre).
const DESCENT := Vector2(0.0, 150.0)
const DESCENT_RADIUS := 52.0
## Secondes à se tenir dans la brèche (ou dans le puits de lumière) pour descendre (ou remonter).
const DESCENT_HOLD := 1.0
## Le combat commence quand le joueur s'avance à moins de radius - WAKE_MARGIN du centre.
const WAKE_MARGIN := 170.0
## Niveau du build de test du robot (« -- --autotest=boss --region=finale »).
const AUTOTEST_LEVEL := 20
## Le combat du robot dure plus longtemps qu'en région (seconde forme) : durée maximale.
const AUTOTEST_MAX_TIME := 330.0
## Effondrement : part de sa durée où le futur bord s'annonce (rien ne bouge), puis où le sol tombe.
const COLLAPSE_WARN := 0.3
const COLLAPSE_FALL := 0.6

var reward_points := 3
## Temps passé dans la brèche ou le puits (0 → DESCENT_HOLD).
var hold := 0.0
## Le joueur a quitté le puits depuis son arrivée : y revenir le fait remonter.
var armed := false
## Floraison du creux après la victoire (0 → 1).
var bloom := 0.0
## La floraison part du point où elle est morte (centre du disque de vie qui grandit dans le creux).
var bloom_from := Vector2.ZERO
## Remontée animée après la victoire (la fin commence) : portée par un geyser de sève dans le creux,
## éclair de sève, puis le héros sort de la brèche ; ASCENT_SWITCH : instant du passage (s).
var ascending := false
var ascent_t := 0.0
var _ascent_from := Vector2.ZERO
const ASCENT := 3.4
const ASCENT_SWITCH := 1.5
const ASCENT_RISE := 300.0
## Rayon de l'île qui reste après l'effondrement (« arena › radius_collapse »).
var collapse_radius := 380.0
## Effondrement en cours : temps écoulé (-1 : aucun) sur collapse_time.
var collapse_t := -1.0
var collapse_time := 3.6
## Avancée visible de l'effondrement (0 : creux entier, 1 : île au-dessus du gouffre) ; la
## floraison le referme après la victoire.
var collapse_k := 0.0
## Descente calée sur le morceau de la Flétrissure (boss_sync.gd) : de la brèche au creux pendant la
## première moitié de l'intro (plongée dans la brèche, éclair de sève, chute lente dans le puits de
## lumière), puis l'invocation du boss pendant la seconde moitié. La Flétrissure : 8 mesures
## (10,7 s) à chaque essai ; une fiche qui donne aussi une intro_court la réserve aux essais suivants.
var descending := false
## Hauteur (px) d'où le héros tombe dans le puits de lumière.
const SHAFT_DROP := 520.0
var _fell := false
var _last_bar := -1
## Décor du creux et de la brèche (world_art/finale_creux.gd) : deux enfants derrière l'arène, cuits.
const FinaleCreux = preload("res://scripts/world_art/finale_creux.gd")
var _creux
var _breche
## Secousse du creux (racines qui frémissent, poussière qui tombe) : instant (t) et force (0 → 1) ;
## lancée par un changement de phase, l'effondrement, ou une percussion de la batterie (lue sur le boss).
var _shake_at := -100.0
var _shake_power := 0.0
var _last_phase := 0
var _last_drum := -1.0


func configure(_id: String) -> void:
	region = FINALE_PATH
	flag = Objectives.FINALE_WON
	auto_max = AUTOTEST_MAX_TIME
	var data: Dictionary = Content._load("finale")
	var b: Dictionary = data.get("boss", {})
	boss_script = load(str(b.get("script", "res://scripts/boss_finale.gd")))
	boss_name = str(b.get("name", "La Flétrissure")) # i18n
	bar_color = Regions.color(b.get("bar_color", "cendre"))
	phase_names = b.get("phases", ["Phase 1 sur 3", "Phase 2 sur 3", "Phase 3 sur 3"]) # i18n
	# Cycle 2 et après : l'Exaltation, une phase de plus (boss_finale.gd › EXALTED_ATTACK).
	exalted_phase_names = b.get("phases_exaltees", [])
	reward_points = int(b.get("reward", {}).get("points", 3))
	var ar: Dictionary = b.get("arena", {})
	max_radius = float(ar.get("radius", 520.0))
	min_radius = float(ar.get("radius_min", 370.0))
	collapse_radius = float(ar.get("radius_collapse", 380.0))
	life_color = Regions.color(ar.get("life_color", "seve/clair"))
	radius = max_radius


func _ready() -> void:
	configure(FINALE_PATH)
	center = CAVE
	Game.seed_rng(rng, 77)
	bar = BossBar.new()
	var probe = boss_script.new()
	bar.marks = probe.phase_limits
	probe.free()
	main.hud.get_parent().add_child(bar)
	if Game.flags.get(flag, false):
		bloom = 1.0
	for m in ["creux", "breche"]:
		var n = FinaleCreux.new()
		n.name = "Creux" if m == "creux" else "Breche"  # i18n: non
		n.mode = m
		n.arena = self
		n.r = max_radius
		n.visible = false
		add_child(n)
		if m == "creux":
			_creux = n
			# Sa terre opaque cache le sol du monde : ses carrés ne sont pas rendus dessous (ground.gd › covers).
			if main.get("ground") != null:
				main.ground.covers.append(n)
		else:
			_breche = n


## La position est-elle sous la graine (dans le creux de la finale, mur compris) ?
func holds(pos: Vector2) -> bool:
	return pos.distance_squared_to(center) < (max_radius + 400.0) * (max_radius + 400.0)


## Brèche au pied de la graine, dans le monde.
func descent_point() -> Vector2:
	return DESCENT


## Point du monde à côté de la brèche : là où l'on reprend une partie sauvegardée sous la graine,
## et où la sève attend après une mort pendant le combat.
func entrance() -> Vector2:
	return DESCENT + Vector2(0.0, DESCENT_RADIUS + 70.0)


## Point d'arrivée dans le creux (le puits de lumière), au sud du boss.
func landing() -> Vector2:
	return center + Vector2(0.0, max_radius - 95.0)


## Vie de la musique sous la graine (Music.set_mood) : la terre morte, puis vivante après la victoire.
func music_life() -> float:
	return bloom


func _process(delta: float) -> void:
	t += delta
	if frozen:
		return
	_react_step()
	var p: Vector2 = main.player.position
	if holds(p) or (state != "fermee" and p.distance_squared_to(DESCENT) < 1600.0 * 1600.0):
		queue_redraw()


func _physics_process(delta: float) -> void:
	if frozen:
		return
	if sync != null:
		sync.tick(delta)
	if descending:
		_descent_step()
		return
	if ascending:
		_ascent_step(delta)
		_life_wave_step(delta)
		queue_redraw()
		return
	var p = main.player
	var under := holds(p.position)
	# Les drapeaux font foi (partie chargée).
	if Game.flags.get(flag, false):
		if state != "vaincue":
			state = "vaincue"
			gap_open = 1.0
	elif state == "vaincue":
		state = "fermee"
		bloom = 0.0
	if state == "fermee" and Regions.all_purified(Game.flags):
		_open()
	match state:
		"fermee":
			if under:
				_ascend()
		"ouverte":
			if under:
				_keep_inside(p, max_radius)
				if p.position.distance_to(center) < max_radius - WAKE_MARGIN and (not main.benchmark or main.bench_scene == "boss"):
					armed = false
					hold = 0.0
					_start_fight()
				else:
					_shaft_step(p, delta)
			else:
				_breach_step(p, delta)
		"combat":
			if not is_instance_valid(boss) or boss.is_queued_for_deletion():
				_fight_lost()
				return
			_shrink_step(delta)
			var falling := collapse_t >= 0.0
			_collapse_step(delta)
			var d: float = p.position.distance_to(center)
			var limit: float = radius - p.radius - 10.0
			if d > limit:
				p.position = center + (p.position - center) / maxf(d, 0.01) * limit
				# Pendant l'effondrement, le sol qui tombe pousse le joueur sans le blesser.
				if not falling:
					p.take_hit(WALL_DAMAGE * boss.damage_scale, null)
			update_bar()
		"vaincue":
			bar.hide_bar()
			if under:
				_keep_inside(p, max_radius)
				_shaft_step(p, delta)
			_life_wave_step(delta)


## Toutes les régions sont purifiées : la brèche s'ouvre (annoncée une seule fois par partie).
func _open() -> void:
	state = "ouverte"
	if not Game.flags.get(Objectives.FINALE_OPEN, false):
		Game.flags[Objectives.FINALE_OPEN] = true
		main.request_autosave()


## Seconde forme du boss : le creux s'effondre en « duration » secondes (le futur bord s'annonce
## d'abord, puis le sol tombe dans le gouffre jusqu'à collapse_radius).
func start_collapse(duration: float) -> void:
	shrinking = false
	collapse_t = 0.0
	collapse_time = maxf(duration, 0.5)


func _collapse_step(delta: float) -> void:
	if collapse_t < 0.0:
		return
	var before := collapse_t / collapse_time
	collapse_t += delta
	var u := collapse_t / collapse_time
	if before < COLLAPSE_WARN and u >= COLLAPSE_WARN:
		main.fx.shake(9.0)
		shake_creux(1.0)
		main.fx.ring(center, collapse_radius, max_radius + 40.0, 0.7, Color(Art.ec("cendre", "clair"), 0.8), 8.0)
	var fall := clampf((u - COLLAPSE_WARN) / COLLAPSE_FALL, 0.0, 1.0)
	collapse_k = Anim.ease_out(fall)
	radius = lerpf(max_radius, collapse_radius, collapse_k)
	if fall >= 1.0:
		collapse_t = -1.0
		collapse_k = 1.0
		radius = collapse_radius


func _reset_collapse() -> void:
	collapse_t = -1.0
	collapse_k = 0.0


func _start_fight() -> void:
	_reset_collapse()
	super._start_fight()


func _keep_inside(p, r: float) -> void:
	var to: Vector2 = p.position - center
	var limit: float = r - p.radius - 10.0
	if to.length() > limit:
		p.position = center + to.limit_length(limit)


## Dans la brèche au pied de la graine : descendre après DESCENT_HOLD secondes.
func _breach_step(p, delta: float) -> void:
	if p.position.distance_to(DESCENT) < DESCENT_RADIUS:
		hold += delta
		if hold >= DESCENT_HOLD:
			begin_descent()
	else:
		hold = 0.0


## Dans le creux, hors combat : revenir dans le puits de lumière fait remonter.
func _shaft_step(p, delta: float) -> void:
	var inside: bool = p.position.distance_to(landing()) < DESCENT_RADIUS
	if not inside:
		armed = true
		hold = 0.0
	elif armed:
		hold += delta
		if hold >= DESCENT_HOLD:
			_ascend()


## Descend sous la graine : les Flétris du monde disparaissent (rien ne suit le joueur), il arrive
## dans le puits de lumière, au bord du creux.
func descend() -> void:
	hold = 0.0
	armed = false
	for e in main.enemies:
		if is_instance_valid(e) and not e is BossBase:
			e.dead = true
			e.queue_free()
	main.enemies = main.enemies.filter(func(e): return is_instance_valid(e) and not e.dead)
	_move_player(landing())
	main.screen_fx.fade(Art.c("decor").darkened(0.6), 1.0, 0.0, main.screen_fx.FADE_DEATH)
	main.fx.ring(landing(), 12.0, 140.0, 0.8, Color(Art.ec("seve", "clair"), 0.8), 4.0)


## Le morceau joue pendant la descente (boss_track.gd suit l'arène dès la brèche).
func music_on() -> bool:
	return descending or in_combat()


## Entrée dans la brèche, la Flétrissure à combattre : la descente suit l'intro du morceau, et le combat
## commence à son premier temps de batterie. Sans morceau : la descente d'avant (un fondu).
func begin_descent() -> void:
	if state != "ouverte":
		descend()
		return
	sync = BossSync.for_region(region)
	if sync == null:
		descend()
		return
	var first := defeats == 0 and int(Game.flags.get("stat_finale_essais", 0)) == 0
	# Le creux se cuit pendant la plongée (l'éclair de sève cache l'image de la cuisson).
	if _creux != null:
		_creux.request("fletri")
		_creux.request_tiles()
	sync.start("intro" if first else "intro_court")
	descending = true
	_fell = false
	_last_bar = -1
	hold = 0.0
	armed = false
	for e in main.enemies:
		if is_instance_valid(e) and not e is BossBase:
			e.dead = true
			e.queue_free()
	main.enemies = main.enemies.filter(func(e): return is_instance_valid(e) and not e.dead)
	var p = main.player
	if p.has_method("clear_destination"):
		p.clear_destination()
	p.set_physics_process(false)
	main.screen_fx.glow(Art.ec("cendre"), 0.4, 1.2)


## Mesures de la plongée (la première moitié de l'intro) : dans la brèche, puis dans le puits.
func _plunge_bars() -> float:
	return sync.intro_bars * 0.5


## Avancée de la descente (0 → 1) ; -1 hors descente.
func descent_k() -> float:
	if not descending or sync == null:
		return -1.0
	return clampf(sync.bars_now() / _plunge_bars(), 0.0, 1.0)


func _descent_step() -> void:
	var p = main.player
	p.invuln = maxf(p.invuln, 0.5)
	var b: float = sync.bars_now()
	var u := descent_k()
	# Sur chaque mesure, une onde de lumière (la brèche, puis le puits) : le monde respire avec l'intro.
	var bi := int(floor(b))
	if bi != _last_bar:
		_last_bar = bi
		var at: Vector2 = DESCENT if not _fell else landing()
		main.fx.ring(at, 10.0, 90.0 + 70.0 * u, 0.9, Color(Art.ec("seve" if _fell else "cendre", "clair"), 0.55 + 0.3 * u), 4.0)
	if u < 0.5:
		# Il s'enfonce dans la brèche : la lueur monte, il s'efface dans la fente.
		p.position = DESCENT
		p.modulate.a = 1.0 - smoothstep(0.25, 0.5, u)
	else:
		if not _fell:
			# Éclair de sève : le héros passe sous la graine, sans écran noir.
			_fell = true
			_move_player(landing() + Vector2(0.0, -SHAFT_DROP))
			main.screen_fx.fade(Art.ec("seve", "clair"), 0.85, 0.0, 1.1)
			main.fx.shake(4.0)
		var v := clampf((u - 0.5) / 0.5, 0.0, 1.0)
		p.position = landing() + Vector2(0.0, -SHAFT_DROP * (1.0 - Anim.ease_out(v)))
		p.modulate.a = smoothstep(0.0, 0.3, v)
	queue_redraw()
	if b >= _plunge_bars():
		# Il touche le fond du puits : la Flétrissure s'éveille pendant la fin de l'intro.
		descending = false
		p.modulate.a = 1.0
		p.position = landing()
		p.set_physics_process(true)
		main.fx.ring(landing(), 12.0, 180.0, 0.7, Color(Art.ec("seve", "clair"), 0.9), 5.0)
		_start_fight()


## Remonte au pied de la graine.
func _ascend() -> void:
	hold = 0.0
	armed = false
	_move_player(entrance())
	main.screen_fx.fade(Art.c("decor").darkened(0.6), 1.0, 0.0, main.screen_fx.FADE_PANEL)


func _move_player(at: Vector2) -> void:
	var p = main.player
	p.position = at
	if p.has_method("clear_destination"):
		p.clear_destination()
	p.reset_physics_interpolation()
	if main.camera != null:
		main.camera.reset_smoothing()


## Remonte le joueur au pied de la graine (l'épilogue commence, voir quest_ui.gd) : sans coupure,
## un geyser de sève le soulève dans le creux, un éclair de sève, et il sort de la brèche.
func bring_up() -> void:
	if ascending or not holds(main.player.position):
		return
	hold = 0.0
	armed = false
	ascending = true
	ascent_t = 0.0
	var p = main.player
	_ascent_from = p.position
	if p.has_method("clear_destination"):
		p.clear_destination()
	p.set_physics_process(false)
	main.fx.ring(_ascent_from, 10.0, 160.0, 0.8, Color(Art.ec("seve", "clair"), 0.9), 5.0)
	main.screen_fx.glow(Art.ec("seve"), 0.45, 1.4)


## Achève la remontée tout de suite (captures, robots pressés).
func finish_ascent() -> void:
	if not ascending:
		return
	ascending = false
	var p = main.player
	_move_player(entrance())
	p.modulate.a = 1.0
	p.set_physics_process(true)


## Vrai tant que le héros n'est pas encore sorti de la brèche (la fin dans le monde attend).
func ascent_waiting() -> bool:
	return ascending and ascent_t < ASCENT_SWITCH


## Avancée de la remontée (0 → 1), -1 hors remontée.
func ascent_k() -> float:
	return clampf(ascent_t / ASCENT, 0.0, 1.0) if ascending else -1.0


func _ascent_step(delta: float) -> void:
	var p = main.player
	p.invuln = maxf(p.invuln, 0.5)
	var before := ascent_t
	ascent_t += delta
	_ascent_particles(before)
	if ascent_t < ASCENT_SWITCH:
		# Le geyser le soulève, de plus en plus vite, et il se fond dans la lumière.
		var u := ascent_t / ASCENT_SWITCH
		p.position = _ascent_from + Vector2(0.0, -ASCENT_RISE * Anim.ease_in(u))
		p.modulate.a = 1.0 - smoothstep(0.55, 1.0, u)
		if int(before * 4.0) != int(ascent_t * 4.0):
			main.fx.ring(_ascent_from, 8.0, 70.0 + 90.0 * u, 0.6, Color(Art.ec("seve", "clair"), 0.8), 3.0 + 3.0 * u)
		return
	if before < ASCENT_SWITCH:
		# Éclair de sève : il passe de sous la graine à la brèche, sans écran noir.
		_move_player(DESCENT)
		main.screen_fx.fade(Art.ec("seve", "clair"), 0.85, 0.0, 1.2)
		main.fx.shake(0.35)
		for i in 3:
			main.fx.ring(DESCENT, 12.0, 160.0 + 110.0 * i, 0.7 + 0.25 * i, Color(Art.ec("seve", "clair"), 0.9), 5.0)
	# Il sort de la fente, porté par la sève, et se pose à côté.
	var v := clampf((ascent_t - ASCENT_SWITCH) / (ASCENT - ASCENT_SWITCH), 0.0, 1.0)
	var hop := sin(PI * minf(1.0, v * 1.4)) * 70.0
	p.position = DESCENT.lerp(entrance(), Anim.ease_in_out(v)) + Vector2(0.0, -hop)
	p.modulate.a = smoothstep(0.0, 0.35, v)
	if ascent_t >= ASCENT:
		ascending = false
		p.modulate.a = 1.0
		p.position = entrance()
		p.set_physics_process(true)
		main.fx.ring(entrance(), 10.0, 120.0, 0.6, Color(Art.ec("seve", "clair"), 0.8), 4.0)


## La Flétrissure meurt : drapeau, points (« boss › reward »), le creux refleurit. L'épilogue suit
## (quest_ui.gd), et le monde entier reverdit.
func boss_defeated() -> void:
	state = "vaincue"
	gap_open = 1.0
	shrinking = false
	collapse_t = -1.0
	shrink_warn = 0.0
	main.spawn_paused = false
	Game.flags[flag] = true
	SteamBridge.unlock_finale(Cycles.current())
	Game.flags["stat_finale_fin"] = main.elapsed
	Game.grant_points(reward_points, "boss", "finale_boss")
	for i in 4:
		main.fx.ring(center, 40.0, max_radius * (0.45 + 0.25 * i), 0.9 + 0.4 * i, Color(Art.ec("seve", "clair"), 0.9), 6.0)
	main.screen_fx.glow(Art.ec("seve"), 0.6, 2.2)
	bloom_from = boss.anchor if is_instance_valid(boss) else center
	_prng.seed = 1717
	life_wave = 0.0
	bar.hide_bar()
	main.request_autosave()


func _fight_lost() -> void:
	_reset_collapse()
	super._fight_lost()
	Game.flags["stat_finale_essais"] = int(Game.flags.get("stat_finale_essais", 0)) + 1


## Floraison du creux, sur trois secondes (le sol du monde n'est pas touché ici).
func _life_wave_step(delta: float) -> void:
	if life_wave < 0.0:
		return
	life_wave += delta
	_life_particles()
	bloom = clampf(life_wave / 3.0, 0.0, 1.0)
	# Le creux effondré se referme à mesure qu'il refleurit.
	collapse_k = minf(collapse_k, 1.0 - bloom)
	radius = lerpf(max_radius, collapse_radius, collapse_k)
	if life_wave >= 3.0:
		life_wave = -1.0
		bloom = 1.0


# --- Dessin ---
#
# Le décor fixe (paroi en strates, six poches des régions, racines de la graine, sol en couches,
# brèche) est dessiné et cuit par world_art/finale_creux.gd, dans deux enfants derrière l'arène.
# Ici, en direct : la lueur de la brèche, le gouffre de l'effondrement, les radicelles qui frémissent
# et la poussière qui tombe (secousses : phases, percussions), le puits de lumière, le front de vie.

func _draw() -> void:
	if state != "fermee":
		_draw_breach()
	if main != null and main.player != null and not holds(main.player.position) and not frozen:
		return
	_draw_cave()
	_draw_life_front()
	# Remontée : le geyser de sève qui le soulève.
	if ascending and ascent_t < ASCENT_SWITCH:
		var u := ascent_t / ASCENT_SWITCH
		var base := _ascent_from
		for j in 5:
			var w := 70.0 * (1.0 - 0.15 * j) * (0.6 + 0.4 * u)
			var hgt := 200.0 + (ASCENT_RISE + 500.0) * u * (1.0 - 0.1 * j)
			draw_rect(Rect2(base.x - w * 0.5, base.y - hgt, w, hgt), Color(Art.ec("seve", "clair"), 0.07 + 0.12 * u), true)
		for i in 24:
			var f := fposmod(t * (0.7 + 1.2 * u) + i * 0.137, 1.0)
			draw_circle(base + Vector2((i - 11.5) * 5.0 + 6.0 * sin(t * 3.0 + i), -f * (300.0 + 600.0 * u)), 2.0 + 2.5 * (1.0 - f), Color(Art.ec("seve", "clair"), 0.9 * (1.0 - f)))
	# Le puits de lumière pendant la chute : des gouttes de sève qui tombent avec le héros.
	var dk := descent_k()
	if dk >= 0.5:
		var top := landing() + Vector2(0.0, -SHAFT_DROP - 200.0)
		var v := (dk - 0.5) / 0.5
		draw_rect(Rect2(top.x - 46.0, top.y, 92.0, SHAFT_DROP + 200.0), Color(Art.ec("seve", "clair"), 0.12 * (1.0 - v) + 0.05), true)
		for i in 18:
			var f := fposmod(t * 0.5 + i * 0.173, 1.0)
			draw_circle(top + Vector2((i - 8.5) * 5.5, f * (SHAFT_DROP + 200.0)), 2.5 * (1.0 - f) + 1.0, Color(Art.ec("seve", "clair"), 0.8 * sin(PI * f)))


## La brèche au pied de la graine : une fente sombre entre des racines, d'où monte une lueur de cendre
## (ou de sève, une fois la finale gagnée), et l'anneau qui se remplit pendant que le joueur s'y tient.
func _draw_breach() -> void:
	var c := DESCENT
	var won := state == "vaincue"
	var glow_col := Art.ec("seve") if won else Art.ec("cendre")
	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	# La terre ouverte et les racines sont cuites (finale_creux.gd › paint_breche, nœud « Breche ») ;
	# ici, la lueur qui monte du fond.
	draw_colored_polygon(Art.ellipse(c + Vector2(0, 11), DESCENT_RADIUS * 0.62, DESCENT_RADIUS * 0.17, 18), Color(glow_col, 0.22 + 0.22 * pulse))
	draw_colored_polygon(Art.ellipse(c + Vector2(0, 12), DESCENT_RADIUS * 0.3, DESCENT_RADIUS * 0.08, 14), Color(glow_col.lightened(0.3), 0.25 + 0.3 * pulse))
	# Braises (ou gouttes de sève) qui montent de la fente.
	for i in 6:
		var f := fposmod(t * 0.45 + i * 0.17, 1.0)
		var x := (i - 2.5) * DESCENT_RADIUS * 0.22 + 5.0 * sin(t * 1.3 + i)
		draw_circle(c + Vector2(x, -f * 60.0), 2.5 * (1.0 - f) + 1.0, Color(Art.ec("seve" if won else "cendre", "clair"), 0.8 * (1.0 - f)))
	# Descente : une colonne de lueur monte de la fente, de plus en plus haute et vive.
	var dk := descent_k()
	if dk >= 0.0 and dk < 0.5:
		var k := dk / 0.5
		for j in 5:
			var w := DESCENT_RADIUS * (0.9 - 0.15 * j)
			var hgt := 120.0 + 520.0 * k * (1.0 - 0.12 * j)
			draw_rect(Rect2(c.x - w * 0.5, c.y - hgt, w, hgt), Color(Art.ec("cendre", "clair"), 0.06 + 0.1 * k), true)
		for i in 14:
			var f := fposmod(t * 0.8 + i * 0.137, 1.0)
			draw_circle(c + Vector2((i - 6.5) * 5.0, -f * (200.0 + 400.0 * k)), 2.0 + 2.0 * (1.0 - f), Color(Art.ec("cendre", "clair"), 0.9 * (1.0 - f) * k))
	# Remontée : un geyser de sève jaillit de la fente et retombe à mesure que le héros se pose.
	if ascending and ascent_t >= ASCENT_SWITCH:
		var v := clampf((ascent_t - ASCENT_SWITCH) / (ASCENT - ASCENT_SWITCH), 0.0, 1.0)
		var k := 1.0 - v * v
		for j in 5:
			var w := DESCENT_RADIUS * (1.0 - 0.15 * j)
			var hgt := (520.0 + 200.0 * v) * (1.0 - 0.12 * j) * k
			draw_rect(Rect2(c.x - w * 0.5, c.y - hgt, w, hgt), Color(Art.ec("seve", "clair"), 0.08 + 0.12 * k), true)
		for i in 20:
			var f := fposmod(t * 1.1 + i * 0.137, 1.0)
			var spread := (i - 9.5) * 6.0 * (1.0 + f)
			draw_circle(c + Vector2(spread, -f * 520.0 * k + f * f * 160.0), 2.0 + 2.5 * (1.0 - f), Color(Art.ec("seve", "clair"), 0.9 * (1.0 - f) * k))
	# L'anneau d'interaction : il se remplit pendant que le joueur s'y tient.
	if state == "ouverte" and dk < 0.0:
		var col := Art.c("interactif")
		draw_arc(c, DESCENT_RADIUS + 10.0, 0.0, TAU, 40, Color(col, 0.25 + 0.2 * pulse), Art.TRAIT_FIN, true)
		if hold > 0.0 and not holds(main.player.position):
			draw_arc(c, DESCENT_RADIUS + 10.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(hold / DESCENT_HOLD, 0.0, 1.0), 40, col, Art.TRAIT, true)


var _prng := RandomNumberGenerator.new()


## Particules du front de vie dans le creux : des lueurs de sève filent sur le front, des pétales
## éclosent derrière lui, et quelques lueurs rejoignent le héros.
func _life_particles() -> void:
	if Settings.reduce_effects or not holds(main.player.position):
		return
	var u := clampf(life_wave / 3.0, 0.0, 1.0)
	if u >= 1.0:
		return
	var r := lerpf(20.0, max_radius * 2.0, Anim.ease_out(u))
	var fx = main.fx
	for i in 4:
		var a := _prng.randf() * TAU
		var at := bloom_from + Vector2.from_angle(a) * r
		if at.distance_to(center) > max_radius:
			continue
		fx.mote(at, Vector2.from_angle(a) * _prng.randf_range(200.0, 420.0), _prng.randf_range(0.25, 0.5), 2.5, Color(Art.ec("seve", "clair"), 0.95))
		var b := bloom_from + Vector2.from_angle(a + 0.3) * r * _prng.randf_range(0.5, 0.95)
		if b.distance_to(center) < max_radius:
			var tint: Color = [Art.ec("seve", "clair"), Art.ec("lumiere", "clair"), Art.ec("vent", "clair"), Art.ec("poison", "clair")][_prng.randi() % 4]
			fx.petal(b, Vector2(_prng.randf_range(-40.0, 40.0), -_prng.randf_range(60.0, 140.0)), _prng.randf_range(1.2, 2.0), _prng.randf_range(6.0, 9.5), Color(tint, 0.9))
	if _prng.randf() < 0.5:
		var a := _prng.randf() * TAU
		fx.glow_mote(bloom_from + Vector2.from_angle(a) * r * 0.7, Vector2.from_angle(a) * 60.0, 1.6, 3.0, Color(Art.ec("seve", "clair"), 0.9), true)


## Particules de la remontée : le geyser crache des gouttes et des pétales qui tourbillonnent autour
## du héros ; à la sortie de la brèche, une gerbe ; puis la sève qui retombe en pluie autour de lui.
func _ascent_particles(before: float) -> void:
	if Settings.reduce_effects:
		return
	var fx = main.fx
	var sap := Art.ec("seve", "clair")
	var p = main.player
	if ascent_t < ASCENT_SWITCH:
		var u := ascent_t / ASCENT_SWITCH
		for i in 2 + int(4.0 * u):
			fx.mote(_ascent_from + Vector2(_prng.randf_range(-30.0, 30.0), 0.0), Vector2(_prng.randf_range(-50.0, 50.0), -_prng.randf_range(500.0, 900.0)), _prng.randf_range(0.4, 0.8), _prng.randf_range(2.0, 3.5), Color(sap, 0.95))
		var a := ascent_t * 9.0
		for j in 2:
			var aa := a + PI * j
			fx.petal(p.position + Vector2(cos(aa) * 60.0, sin(aa) * 30.0), Vector2(-sin(aa) * 160.0, -120.0), 1.0, 7.5, Color(Art.ec("lumiere" if j == 0 else "seve", "clair"), 0.9))
		return
	if before < ASCENT_SWITCH:
		for i in 70:
			var a := _prng.randf() * TAU
			var tint: Color = [sap, Art.ec("lumiere", "clair"), Art.ec("vent", "clair"), Art.ec("poison", "clair"), Art.ec("epine", "clair")][i % 5]
			if i % 2 == 0:
				fx.petal(DESCENT, Vector2.from_angle(a) * _prng.randf_range(150.0, 520.0) + Vector2(0, -200.0), _prng.randf_range(1.4, 2.6), _prng.randf_range(6.0, 10.0), Color(tint, 0.95))
			else:
				fx.mote(DESCENT, Vector2.from_angle(a) * _prng.randf_range(300.0, 800.0), _prng.randf_range(0.3, 0.7), 3.0, Color(sap, 0.95))
		return
	var v := clampf((ascent_t - ASCENT_SWITCH) / (ASCENT - ASCENT_SWITCH), 0.0, 1.0)
	for i in int(5.0 * (1.0 - v)) + 1:
		var a := -PI / 2.0 + _prng.randf_range(-0.6, 0.6)
		fx.mote(DESCENT + Vector2(_prng.randf_range(-20.0, 20.0), 0.0), Vector2.from_angle(a) * _prng.randf_range(400.0, 800.0) * (1.0 - 0.5 * v), _prng.randf_range(0.3, 0.6), 2.5, Color(sap, 0.9))
	if _prng.randf() < 0.6:
		fx.petal(p.position + Vector2(_prng.randf_range(-120.0, 120.0), -_prng.randf_range(80.0, 200.0)), Vector2(_prng.randf_range(-50.0, 50.0), 20.0), 2.0, _prng.randf_range(6.0, 9.0), Color([sap, Art.ec("lumiere", "clair"), Art.ec("vent", "clair")][_prng.randi() % 3], 0.9))


## La vie qui part de là où elle est morte : un disque de sève qui grandit dans le creux, son front
## lumineux, et des pousses qui naissent derrière lui.
func _draw_life_front() -> void:
	if state != "vaincue" or life_wave < 0.0:
		return
	var u := clampf(life_wave / 3.0, 0.0, 1.0)
	var r := lerpf(20.0, max_radius * 2.0, Anim.ease_out(u))
	var sap := Art.ec("seve", "clair")
	draw_circle(bloom_from, r, Color(Art.ec("seve"), 0.10 * (1.0 - u)))
	draw_arc(bloom_from, r, 0.0, TAU, 96, Color(sap, 0.7 * (1.0 - u)), 10.0 * (1.0 - u) + 2.0, true)
	draw_arc(bloom_from, r * 0.93, 0.0, TAU, 96, Color(sap, 0.3 * (1.0 - u)), 4.0, true)
	for i in 60:
		var a := TAU * i / 60.0 + 0.37 * sin(i * 3.7)
		var d := r * (0.25 + 0.7 * fposmod(i * 0.618, 1.0))
		var q := bloom_from + Vector2.from_angle(a) * d
		if q.distance_to(center) > max_radius - 20.0:
			continue
		var g := clampf((r - d) / 120.0, 0.0, 1.0)
		draw_line(q, q + Vector2(-3.0, -10.0) * g, Color(Art.ec("seve"), 0.85), 2.0, true)
		draw_line(q, q + Vector2(3.0, -12.0) * g, Color(Art.ec("seve"), 0.85), 2.0, true)
		draw_circle(q + Vector2(0, -12.0 * g), 2.5 * g, Color(sap if i % 3 else Art.ec("lumiere", "clair"), 0.9))


const DrawBatch = preload("res://scripts/draw_batch.gd")
var _floor_batch = DrawBatch.new()


func _draw_cave() -> void:
	var c := center
	var r := max_radius
	# Le creux (terre, paroi en strates, sol, racines) est cuit : nœud « Creux », derrière l'arène.
	_draw_abyss()
	# Annonce du resserrement (phase 3) : le futur bord clignote au sol.
	if shrinking:
		var blink := 0.5 + 0.5 * sin(t * 12.0)
		draw_arc(c, min_radius, 0.0, TAU, 96, Color(Art.c("danger"), 0.35 + 0.5 * blink), 5.0)
		for i in 24:
			var dir := Vector2.from_angle(TAU * i / 24.0)
			draw_line(c + dir * (radius - 24.0), c + dir * lerpf(radius - 24.0, min_radius + 8.0, 0.3 + 0.2 * blink), Color(Art.c("danger"), 0.35), 3.0)
	# Ce qui bouge sur la paroi : radicelles qui frémissent, poussière qui tombe après une secousse.
	var sk := _shake_now()
	FinaleCreux.draw_hanging(self, c, r, t, sk, bloom)
	FinaleCreux.draw_dust(self, c, r, t - _shake_at, _shake_power)
	FinaleCreux.draw_embers(self, c, r, t, sk, bloom)
	# Lueurs de sève prises dans les racines du pied de la paroi (éteintes avant la victoire).
	for i in 12:
		var q := c + Vector2.from_angle(TAU * (i + 0.5) / 12.0) * (r + 12.0)
		var on := 0.25 + 0.75 * bloom
		draw_circle(q, 3.0 + 1.5 * sk, Color(Art.ec("seve" if bloom > 0.0 else "cendre", "clair"), (0.2 + 0.2 * sin(t * 1.7 + i) + 0.3 * sk) * on))
	# Le puits de lumière où l'on arrive (et d'où l'on remonte, hors combat).
	if state != "combat":
		var lp := landing()
		var col := Art.ec("seve", "clair") if state == "vaincue" else Art.c("interactif")
		# La lumière qui tombe de la brèche, très haut au-dessus.
		var beam := Color(FinaleCreux.cc("lumiere"), 0.05 + 0.015 * sin(t * 1.3))
		draw_colored_polygon(PackedVector2Array([lp + Vector2(-30, -230), lp + Vector2(30, -230), lp + Vector2(DESCENT_RADIUS * 1.1, 0), lp + Vector2(-DESCENT_RADIUS * 1.1, 0)]), beam)
		for i in 7:
			var f := fposmod(t * 0.12 + i * 0.143, 1.0)
			draw_circle(lp + Vector2(18.0 * sin(i * 2.1 + t * 0.4) * (0.4 + f), -230.0 * (1.0 - f)), 1.6, Color(FinaleCreux.cc("lumiere"), 0.5 * sin(PI * f)))
		draw_colored_polygon(Art.ellipse(lp, DESCENT_RADIUS * 1.1, DESCENT_RADIUS * 0.5, 22), Color(col, 0.16 + 0.06 * sin(t * 2.0)))
		draw_arc(lp, DESCENT_RADIUS, 0.0, TAU, 36, Color(col, 0.4), Art.TRAIT_FIN, true)
		if armed and hold > 0.0:
			draw_arc(lp, DESCENT_RADIUS + 8.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(hold / DESCENT_HOLD, 0.0, 1.0), 36, col, Art.TRAIT, true)
	# Le boss endormi, puis ce qui pousse à sa place : dessinés par son script (BossBase).
	if state == "ouverte" or state == "fermee":
		boss_script.draw_sleeper(self)
	elif state == "vaincue":
		boss_script.draw_victory(self)


## Secousse du creux (0 → 1) : changement de phase, effondrement, percussion.
func shake_creux(power: float) -> void:
	if Settings.reduce_effects:
		power *= 0.4
	if power >= _shake_now():
		_shake_at = t
		_shake_power = power


func _shake_now() -> float:
	var u := t - _shake_at
	return 0.0 if u < 0.0 else _shake_power * exp(-u * 3.0)


## Le décor réagit au combat (lecture seule : la phase du boss, l'éclair de ses coups de batterie).
func _react_step() -> void:
	if state != "combat" or not is_instance_valid(boss):
		_last_phase = 0
		_last_drum = -1.0
		return
	var ph: int = boss.phase
	if _last_phase > 0 and ph != _last_phase:
		shake_creux(1.0)
	_last_phase = ph
	var df = boss.get("drum_flash")
	if df != null:
		if float(df) >= 0.0 and (_last_drum < 0.0 or float(df) < _last_drum):
			shake_creux(0.35)
		_last_drum = float(df)


## L'effondrement (seconde forme du boss) : d'abord le futur bord clignote et le sol se fend, puis
## la couronne de sol entre l'île et l'ancien mur tombe en blocs dans un gouffre où rougeoient des
## braises ; des débris flottent encore au-dessus, des braises en montent.
func _draw_abyss() -> void:
	var c := center
	var warn := collapse_t >= 0.0 and collapse_t / collapse_time < COLLAPSE_WARN
	var k := collapse_k
	if not warn and k <= 0.0:
		return
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 23
	var crack := Art.ec("cendre")
	if warn:
		var u := collapse_t / (collapse_time * COLLAPSE_WARN)
		var blink := 0.5 + 0.5 * sin(t * 14.0)
		draw_arc(c, collapse_radius, 0.0, TAU, 96, Color(Art.c("danger"), 0.4 + 0.5 * blink), 5.0)
		for i in 20:
			var a := TAU * i / 20.0 + rng_a.randf_range(-0.08, 0.08)
			var from := c + Vector2.from_angle(a) * collapse_radius
			var to := c + Vector2.from_angle(a + rng_a.randf_range(-0.1, 0.1)) * lerpf(collapse_radius, max_radius, u)
			draw_line(from, to, Color(crack, 0.5 + 0.4 * blink), 3.0, true)
		return
	# Le gouffre s'ouvre jusqu'au pied de la paroi (la paroi cuite continue de descendre dedans).
	var outer := max_radius + 6.0
	var inner := radius
	var abyss := Color(0.025, 0.018, 0.02)
	_floor_batch.exact = true
	_floor_batch.ring(c, outer, inner, abyss)
	_floor_batch.flush(self)
	var n := 72
	var strata := [FinaleCreux.cc("strate_bas").darkened(0.2), FinaleCreux.cc("strate_bas").darkened(0.45)]
	# Au nord, la paroi plonge dans le gouffre (vue de face) ; au sud, la falaise de l'île (vue de face
	# aussi) : deux bandes de strates qui s'enfoncent dans le noir, plus profondes à mesure qu'il s'ouvre.
	var depth := 70.0 * k
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var hn := maxf(0.0, -sin((a0 + a1) * 0.5))
		var hs := maxf(0.0, sin((a0 + a1) * 0.5))
		var d0 := Vector2.from_angle(a0)
		var d1 := Vector2.from_angle(a1)
		if hn > 0.05 and depth > 2.0:
			var e0 := c + d0 * outer
			var e1 := c + d1 * outer
			for j in 2:
				var dd := Vector2(0, depth * hn * (j + 1) * 0.5)
				draw_colored_polygon(PackedVector2Array([e0 + Vector2(0, depth * hn * j * 0.5), e1 + Vector2(0, depth * hn * j * 0.5), e1 + dd, e0 + dd]), Color(strata[j], 0.9 * (1.0 - 0.4 * j)))
		if hs > 0.05 and depth > 2.0:
			var i0 := c + d0 * inner
			var i1 := c + d1 * inner
			for j in 2:
				var dd := Vector2(0, depth * hs * (j + 1) * 0.5)
				var col: Color = FinaleCreux.cc("strate_haut").darkened(0.1) if j == 0 else strata[1]
				draw_colored_polygon(PackedVector2Array([i0 + Vector2(0, depth * hs * j * 0.5), i1 + Vector2(0, depth * hs * j * 0.5), i1 + dd, i0 + dd]), col)
	# Le fond rougeoie : des bandes de braise, plus vives au milieu du gouffre, qui ondulent.
	# (loin en dessous : décalées vers le bas, sourdes, la braise vive seulement au fond)
	var glow := Art.ec("cendre", "sombre")
	var mid := (inner + outer) * 0.5
	for j in 3:
		var w := (outer - inner) * (0.42 - 0.12 * j)
		draw_arc(c + Vector2(0, depth * (0.8 + 0.3 * j)), mid + 4.0 * sin(t * 0.8 + j), 0.0, TAU, 96, Color(glow.lerp(Art.ec("cendre"), 0.35 * j).darkened(0.35 - 0.15 * j), (0.16 + 0.08 * j) * k), w, true)
	# La lèvre de l'île : de la terre arrachée, en dents irrégulières, bord éclairé.
	var lip := FinaleCreux.cc("sol").darkened(0.35)
	for i in 40:
		var a := TAU * i / 40.0
		var a2 := a + TAU / 40.0
		var drop := rng_a.randf_range(10.0, 26.0) * k * (0.4 + 0.6 * maxf(0.0, sin(a)))
		if drop > 1.0:
			draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a) * inner, c + Vector2.from_angle(a2) * inner, c + Vector2.from_angle((a + a2) * 0.5) * (inner + drop * 0.5) + Vector2(0, drop * 0.6)]), lip)
	draw_arc(c, inner, 0.0, TAU, 96, Color(Art.c("contour"), 0.8 * k), 4.0, true)
	# Le bord de l'île, lisible tout autour (on tomberait), plus clair face à la lumière.
	draw_arc(c, inner - 3.0, 0.0, TAU, 96, Color(Art.ec("cendre", "clair"), 0.35 * k), 2.0, true)
	draw_arc(c, inner - 3.0, PI * 1.05, PI * 1.75, 48, Color(FinaleCreux.cc("lumiere"), 0.4 * k), 2.0, true)
	# Les blocs qui tombent (puis flottent, très bas, en dérivant), de plus en plus petits.
	var earth := FinaleCreux.cc("strate_haut")
	for i in 30:
		var a := rng_a.randf() * TAU
		var d0 := rng_a.randf_range(collapse_radius + 20.0, max_radius - 10.0)
		var size := rng_a.randf_range(14.0, 34.0)
		var delay := rng_a.randf_range(0.0, 0.5)
		var f := clampf((k - delay) / (1.0 - delay), 0.0, 1.0) if k < 1.0 else 1.0
		var shrink := lerpf(1.0, 0.35, f)
		var drift := Vector2.from_angle(a) * (d0 + 30.0 * f) + Vector2(4.0 * sin(t * 0.7 + i), 3.0 * cos(t * 0.5 + i)) * f
		var q := c + drift
		var col := earth.lerp(abyss, 0.65 * f)
		var block := PackedVector2Array()
		for v in 5:
			block.append(q + Vector2.from_angle(TAU * v / 5.0 + i + 0.3 * f) * size * shrink * (0.7 + 0.3 * ((v + i) % 3) / 2.0))
		draw_colored_polygon(block, col.darkened(0.35))
		draw_colored_polygon(Transform2D(0.0, Vector2(0.7, 0.7), 0.0, q * 0.3 + Vector2(-2, -3)) * block, col)
		if f < 1.0:
			draw_polyline(block + PackedVector2Array([block[0]]), Color(Art.c("contour"), 0.6 * (1.0 - f)), 1.5, true)
	# Des braises montent du gouffre.
	for i in 24:
		var f := fposmod(t * 0.3 + i * 0.173, 1.0)
		var a := TAU * i / 24.0 + 0.4 * sin(i * 3.1)
		var q := c + Vector2.from_angle(a) * lerpf(inner + 30.0, outer - 20.0, fposmod(i * 0.618, 1.0)) - Vector2(0, f * 60.0)
		draw_circle(q, 2.0 + 1.5 * (1.0 - f), Color(Art.ec("cendre", "clair"), 0.7 * sin(PI * f) * k))


# --- Robot (mode « -- --autotest=boss --region=finale » et robot d'aventure) ---

## Prépare le combat : toutes les régions purifiées, un build de test (niveau AUTOTEST_LEVEL,
## points dans la branche de la première région), le joueur posé dans le puits de lumière.
func autotest_begin() -> void:
	autotest_build(AUTOTEST_LEVEL, Regions.branch_of(Regions.ids()[0]) if not Regions.ids().is_empty() else "ronce")
	for id in Regions.ids():
		Game.flags[Regions.heart_flag(id)] = true
		Game.flags[Regions.boss_flag(id)] = true
		Game.flags[Regions.ending_flag(id)] = true
	_open()
	main.player.hp = Game.stats["max_hp"]
	descend()
	print("AUTOTEST finale : niveau %d, %d nœuds, dégâts %.1f, vie %d" % [Game.level, Game.allocated.size() - 1, Game.stats["damage"], int(Game.stats["max_hp"])])


## Hors combat : mener le joueur à la brèche (dans le monde), puis vers le boss (sous la graine).
## En combat : le robot des boss (boss_arena.gd).
func bot_input(p) -> Dictionary:
	if state == "combat":
		return super.bot_input(p)
	var target: Vector2
	if holds(p.position):
		target = center if state == "ouverte" else landing()
	else:
		target = DESCENT if state == "ouverte" else p.position
	var mv: Vector2 = target - p.position
	var stop := 8.0 if target == DESCENT or target == landing() else 60.0
	return {"move": mv.normalized() if mv.length() > stop else Vector2.ZERO, "aim": center if holds(p.position) else DESCENT, "dash": false}
