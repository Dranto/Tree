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
## Rayon de l'île qui reste après l'effondrement (« arena › radius_collapse »).
var collapse_radius := 380.0
## Effondrement en cours : temps écoulé (-1 : aucun) sur collapse_time.
var collapse_t := -1.0
var collapse_time := 3.6
## Avancée visible de l'effondrement (0 : creux entier, 1 : île au-dessus du gouffre) ; la
## floraison le referme après la victoire.
var collapse_k := 0.0


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
	var shape := RandomNumberGenerator.new()
	shape.seed = 61
	for i in 72:
		_wall.append([shape.randf_range(-0.03, 0.03), shape.randf_range(0.7, 1.3), shape.randf_range(-1.0, 1.0)])
	Game.seed_rng(rng, 77)
	bar = BossBar.new()
	var probe = boss_script.new()
	bar.marks = probe.phase_limits
	probe.free()
	main.hud.get_parent().add_child(bar)
	if Game.flags.get(flag, false):
		bloom = 1.0


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
	var p: Vector2 = main.player.position
	if holds(p) or (state != "fermee" and p.distance_squared_to(DESCENT) < 1600.0 * 1600.0):
		queue_redraw()


func _physics_process(delta: float) -> void:
	if frozen:
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
			descend()
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


## Remonte le joueur au pied de la graine sans annonce (l'épilogue commence, voir quest_ui.gd).
func bring_up() -> void:
	if holds(main.player.position):
		hold = 0.0
		armed = false
		_move_player(entrance())


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
	SteamBridge.unlock(SteamBridge.boss_achievement("finale"))
	Game.flags["stat_finale_fin"] = main.elapsed
	Game.grant_points(reward_points, "boss", "finale_boss")
	for i in 4:
		main.fx.ring(center, 40.0, max_radius * (0.45 + 0.25 * i), 0.9 + 0.4 * i, Color(Art.ec("seve", "clair"), 0.9), 6.0)
	main.screen_fx.glow(Art.ec("seve"), 0.6, 2.2)
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
	bloom = clampf(life_wave / 3.0, 0.0, 1.0)
	# Le creux effondré se referme à mesure qu'il refleurit.
	collapse_k = minf(collapse_k, 1.0 - bloom)
	radius = lerpf(max_radius, collapse_radius, collapse_k)
	if life_wave >= 3.0:
		life_wave = -1.0
		bloom = 1.0


# --- Dessin ---
#
# Charte : le fond reste sourd et sombre. Le creux est une terre noire de cendre, nervurée de
# veines de sève éteintes qui convergent vers le centre ; un mur de grosses racines brunes le borde,
# des radicelles pendent du plafond (au bord). La racine pivot de la graine plonge au nord, jusqu'au
# boss. Une fois vaincue, les veines s'allument de sève, des fleurs et des pousses claires naissent.

func _draw() -> void:
	if state != "fermee":
		_draw_breach()
	if main != null and main.player != null and not holds(main.player.position) and not frozen:
		return
	_draw_cave()


## La brèche au pied de la graine : une fente sombre entre des racines, d'où monte une lueur de cendre
## (ou de sève, une fois la finale gagnée), et l'anneau qui se remplit pendant que le joueur s'y tient.
func _draw_breach() -> void:
	var c := DESCENT
	var won := state == "vaincue"
	var glow_col := Art.ec("seve") if won else Art.ec("cendre")
	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	draw_colored_polygon(Art.ellipse(c, DESCENT_RADIUS * 1.25, DESCENT_RADIUS * 0.62, 24), Color(Art.c("contour"), 0.55))
	draw_colored_polygon(Art.ellipse(c, DESCENT_RADIUS * 0.95, DESCENT_RADIUS * 0.42, 24), Color(0.02, 0.015, 0.012))
	draw_colored_polygon(Art.ellipse(c + Vector2(0, 3), DESCENT_RADIUS * 0.6, DESCENT_RADIUS * 0.2, 18), Color(glow_col, 0.25 + 0.25 * pulse))
	# Racines de la graine qui bordent la fente.
	var bark := Art.ec("racine", "sombre").lerp(Art.c("decor"), 0.3)
	for i in 7:
		var a := PI + PI * (i + 0.5) / 7.0
		var from := c + Vector2(cos(a) * DESCENT_RADIUS * 1.5, sin(a) * DESCENT_RADIUS * 0.7)
		var to := c + Vector2(cos(a) * DESCENT_RADIUS * 0.75, sin(a) * DESCENT_RADIUS * 0.3 + 4.0)
		draw_line(from, to, bark, 7.0 - 0.6 * (i % 3), true)
		draw_line(from, to, bark.lightened(0.15), 2.0, true)
	for i in 3:
		var a := PI * (0.2 + 0.3 * i)
		var from := c + Vector2(cos(a) * DESCENT_RADIUS * 1.4, sin(a) * DESCENT_RADIUS * 0.66)
		draw_line(from, from.lerp(c, 0.4), bark, 5.0, true)
	# Braises (ou gouttes de sève) qui montent de la fente.
	for i in 6:
		var f := fposmod(t * 0.45 + i * 0.17, 1.0)
		var x := (i - 2.5) * DESCENT_RADIUS * 0.22 + 5.0 * sin(t * 1.3 + i)
		draw_circle(c + Vector2(x, -f * 60.0), 2.5 * (1.0 - f) + 1.0, Color(Art.ec("seve" if won else "cendre", "clair"), 0.8 * (1.0 - f)))
	# L'anneau d'interaction : il se remplit pendant que le joueur s'y tient.
	if state == "ouverte":
		var col := Art.c("interactif")
		draw_arc(c, DESCENT_RADIUS + 10.0, 0.0, TAU, 40, Color(col, 0.25 + 0.2 * pulse), Art.TRAIT_FIN, true)
		if hold > 0.0 and not holds(main.player.position):
			draw_arc(c, DESCENT_RADIUS + 10.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(hold / DESCENT_HOLD, 0.0, 1.0), 40, col, Art.TRAIT, true)


const DrawBatch = preload("res://scripts/draw_batch.gd")
var _floor_batch = DrawBatch.new()


func _draw_cave() -> void:
	var c := center
	var r := max_radius
	var life := bloom
	# Terre autour du creux : tout ce que l'écran peut voir, sourd et sombre.
	var earth := Art.c("decor").darkened(0.35)
	# Une couronne de 4 000 px de rayon (qui contient le carré de 5 600 px de côté) jusqu'au bord du
	# sol du creux, que le sol recouvre de toute façon : mêmes pixels, sans remplir deux fois le centre.
	_floor_batch.exact = true
	_floor_batch.ring(c, 4000.0, r, earth)
	_floor_batch.flush(self)
	var rng_d := RandomNumberGenerator.new()
	rng_d.seed = 5
	# Racines enfouies dans la terre, qui rayonnent du creux.
	var deep := Art.ec("racine", "sombre").darkened(0.45)
	for i in 26:
		var a := TAU * i / 26.0 + rng_d.randf_range(-0.1, 0.1)
		var from := c + Vector2.from_angle(a) * (r + 40.0)
		var mid := c + Vector2.from_angle(a + rng_d.randf_range(-0.2, 0.2)) * (r + rng_d.randf_range(300.0, 700.0))
		var to := c + Vector2.from_angle(a + rng_d.randf_range(-0.3, 0.3)) * (r + rng_d.randf_range(900.0, 1700.0))
		draw_polyline(PackedVector2Array([from, mid, to]), deep, rng_d.randf_range(6.0, 16.0), true)
	for i in 70:
		var q := c + Vector2.from_angle(rng_d.randf() * TAU) * rng_d.randf_range(r + 80.0, r + 1800.0)
		draw_circle(q, rng_d.randf_range(3.0, 9.0), Color(earth.lightened(0.12), 0.6))
	# Sol du creux : cendre tassée, plus claire au centre ; verdit avec la floraison.
	var floor_dead := Art.c("sol_mort").darkened(0.25)
	var floor_alive := Art.c("sol_vivant")
	# Dix teintes concentriques, tracées en couronnes (lot « exact » : mêmes pixels que des disques
	# empilés, mais sans redessiner dix fois le centre : le coût en rendu logiciel suit les pixels).
	_floor_batch.exact = true
	# Effondrement fini : le sol s'arrête au bord de l'île (le gouffre recouvre le reste ; en rendu
	# logiciel, le coût suit les pixels remplis).
	var keep := radius + 2.0 if collapse_k >= 1.0 else r
	for i in 10:
		var col := floor_dead.lerp(floor_alive, life).lightened(0.016 * i)
		var outer_i := minf(r * (1.0 - i / 10.0), keep)
		if i < 9 and outer_i > r * (1.0 - (i + 1) / 10.0):
			_floor_batch.ring(c, outer_i, r * (1.0 - (i + 1) / 10.0), col)
		else:
			_floor_batch.draw_circle(c, r * 0.1, col)
	_floor_batch.flush(self)
	# Veines de sève qui convergent vers le centre : éteintes, puis allumées.
	var vein_off := Art.ec("seve", "sombre").darkened(0.5)
	for i in 12:
		var a := TAU * i / 12.0 + 0.13
		var pts := PackedVector2Array()
		for j in 7:
			var u := j / 6.0
			pts.append(c + Vector2.from_angle(a + 0.25 * sin(u * 4.0 + i)) * lerpf(r * 0.95, 70.0, u))
		draw_polyline(pts, vein_off.lerp(Art.ec("seve", "sombre").lerp(Art.ec("seve"), 0.45), life), 3.0 + 0.5 * life, true)
		if life > 0.0:
			draw_polyline(pts, Color(Art.ec("seve", "clair"), 0.3 * life), 1.0, true)
	# Taches de cendre, qui pâlissent avec la floraison.
	for i in 18:
		var q := c + Vector2.from_angle(rng_d.randf() * TAU) * rng_d.randf_range(90.0, r * 0.88)
		draw_colored_polygon(Art.ellipse(q, rng_d.randf_range(14.0, 30.0), rng_d.randf_range(8.0, 16.0), 12), Color(Art.ec("cendre", "sombre"), 0.35 * (1.0 - life)))
	_draw_abyss()
	# La racine pivot de la graine plonge du nord jusqu'au centre.
	var tap := PackedVector2Array([c + Vector2(-34, -r - 60), c + Vector2(-20, -r * 0.55), c + Vector2(-10, -90), c + Vector2(10, -90), c + Vector2(22, -r * 0.55), c + Vector2(40, -r - 60)])
	Art.volume(self, tap, Art.ec("racine", "sombre").lerp(Art.ec("racine"), 0.3 + 0.4 * life), 0.4)
	# Annonce du resserrement (phase 3) : le futur bord clignote au sol.
	if shrinking:
		var blink := 0.5 + 0.5 * sin(t * 12.0)
		draw_arc(c, min_radius, 0.0, TAU, 96, Color(Art.c("danger"), 0.35 + 0.5 * blink), 5.0)
		for i in 24:
			var dir := Vector2.from_angle(TAU * i / 24.0)
			draw_line(c + dir * (radius - 24.0), c + dir * lerpf(radius - 24.0, min_radius + 8.0, 0.3 + 0.2 * blink), Color(Art.c("danger"), 0.35), 3.0)
	_draw_wall()
	# Le puits de lumière où l'on arrive (et d'où l'on remonte, hors combat).
	if state != "combat":
		var lp := landing()
		var col := Art.ec("seve", "clair") if state == "vaincue" else Art.c("interactif")
		draw_colored_polygon(Art.ellipse(lp, DESCENT_RADIUS * 1.1, DESCENT_RADIUS * 0.5, 22), Color(col, 0.16 + 0.06 * sin(t * 2.0)))
		draw_arc(lp, DESCENT_RADIUS, 0.0, TAU, 36, Color(col, 0.4), Art.TRAIT_FIN, true)
		if armed and hold > 0.0:
			draw_arc(lp, DESCENT_RADIUS + 8.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(hold / DESCENT_HOLD, 0.0, 1.0), 36, col, Art.TRAIT, true)
	# Floraison : fleurs et pousses claires sur le sol ravivé.
	if life > 0.0:
		var rf := RandomNumberGenerator.new()
		rf.seed = 19
		for i in 90:
			var q := c + Vector2.from_angle(rf.randf() * TAU) * sqrt(rf.randf()) * r * 0.92
			if rf.randf() > life:
				continue
			var tint: Color = [life_color, Art.ec("lumiere", "clair"), Art.ec("poison", "clair"), Art.ec("epine", "clair")][i % 4]
			for k in 5:
				draw_circle(q + Vector2.from_angle(TAU * k / 5.0) * 3.2, 2.4, Color(tint, 0.85))
			draw_circle(q, 1.8, Art.c("butin"))
	# Le boss endormi, puis ce qui pousse à sa place : dessinés par son script (BossBase).
	if state == "ouverte" or state == "fermee":
		boss_script.draw_sleeper(self)
	elif state == "vaincue":
		boss_script.draw_victory(self)


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
	var outer := max_radius + 30.0
	var inner := radius
	var abyss := Color(0.025, 0.018, 0.02)
	_floor_batch.exact = true
	_floor_batch.ring(c, outer, inner, abyss)
	_floor_batch.flush(self)
	# La lueur des braises au fond, plus vive près de l'île.
	# Le fond rougeoie : des bandes de braise, plus vives au milieu du gouffre, qui ondulent.
	var glow := Art.ec("cendre", "sombre")
	var mid := (inner + outer) * 0.5
	for j in 2:
		var w := (outer - inner) * (0.6 - 0.3 * j)
		draw_arc(c, mid + 6.0 * sin(t * 0.8 + j), 0.0, TAU, 96, Color(glow.lerp(Art.ec("cendre"), 0.4 * j), (0.4 + 0.15 * j) * k), w, true)
	# Sous la lèvre de l'île, l'ombre de la falaise, puis son bord éclairé par en dessous.
	draw_arc(c, inner + 10.0, 0.0, TAU, 96, Color(0.0, 0.0, 0.0, 0.6 * k), 18.0, true)
	# La lèvre de l'île : de la terre arrachée, en dents irrégulières sous le mur.
	var lip := Art.c("sol_mort").darkened(0.5)
	for i in 40:
		var a := TAU * i / 40.0
		var a2 := a + TAU / 40.0
		var drop := rng_a.randf_range(14.0, 34.0) * k
		draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a) * inner, c + Vector2.from_angle(a2) * inner, c + Vector2.from_angle((a + a2) * 0.5) * (inner + drop)]), lip)
	draw_arc(c, inner, 0.0, TAU, 96, Color(Art.ec("cendre", "clair"), 0.65 * k), 3.0, true)
	# Les blocs qui tombent (puis flottent, très bas, en dérivant), de plus en plus petits.
	var earth := Art.c("sol_mort").darkened(0.3)
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
		draw_colored_polygon(block, col)
		if f < 1.0:
			draw_polyline(block + PackedVector2Array([block[0]]), Color(Art.c("contour"), 0.6 * (1.0 - f)), 1.5, true)
	# Des braises montent du gouffre.
	for i in 24:
		var f := fposmod(t * 0.3 + i * 0.173, 1.0)
		var a := TAU * i / 24.0 + 0.4 * sin(i * 3.1)
		var q := c + Vector2.from_angle(a) * lerpf(inner + 30.0, outer - 20.0, fposmod(i * 0.618, 1.0)) - Vector2(0, f * 60.0)
		draw_circle(q, 2.0 + 1.5 * (1.0 - f), Color(Art.ec("cendre", "clair"), 0.7 * sin(PI * f) * k))


## Le mur de racines : de grosses racines brunes couchées en cercle, des radicelles qui pendent.
## Il suit le rayon courant (resserrement), ou reste au bord du gouffre après l'effondrement.
func _draw_wall() -> void:
	var c := center
	# Après l'effondrement, le mur reste de l'autre côté du gouffre (l'île n'a plus que sa lèvre).
	var wr := lerpf(radius, max_radius, collapse_k)
	var bark := Art.ec("racine", "sombre").lerp(Art.c("decor"), 0.25)
	var light := Art.ec("racine").darkened(0.15)
	var n := _wall.size()
	draw_arc(c, wr + 26.0, 0.0, TAU, 96, Color(Art.c("contour"), 0.8), 46.0, true)
	for i in n:
		var w: Array = _wall[i]
		var a := TAU * i / n + float(w[0])
		var a2 := a + TAU / n * 1.6
		var rr := wr + 18.0 + 8.0 * float(w[2])
		var p1 := c + Vector2.from_angle(a) * rr
		var p2 := c + Vector2.from_angle(a2) * (rr + 6.0)
		var width := 18.0 * float(w[1])
		draw_line(p1, p2, bark, width, true)
		draw_line(p1 + Vector2(0, -width * 0.25), p2 + Vector2(0, -width * 0.25), Color(light, 0.45), width * 0.25, true)
		# Radicelles qui pendent vers l'intérieur, une racine sur trois.
		if i % 3 == 0:
			var tip := c + Vector2.from_angle(a + 0.02) * (rr - 30.0 - 14.0 * float(w[1]))
			draw_line(p1, tip, bark.lightened(0.05), 3.0, true)
			if bloom > 0.0:
				draw_circle(tip, 3.5 * bloom, Color(Art.ec("seve", "clair"), 0.8 * bloom))
	# Lueurs de sève prisonnières des racines (éteintes avant la victoire).
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0
		var q := c + Vector2.from_angle(a) * (wr + 20.0)
		var on := 0.25 + 0.75 * bloom
		draw_circle(q, 5.0, Color(Art.ec("seve" if bloom > 0.0 else "cendre", "clair"), (0.25 + 0.2 * sin(t * 1.7 + i)) * on))


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
