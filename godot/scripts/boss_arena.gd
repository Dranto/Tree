## Arène du boss d'une région (une par région, posée par main.gd) : un cercle muré au-delà du Cœur de
## flétrissure (Regions.arena_center). Réglée par la section « boss » de data/regions/<région>.json
## (script du boss, nom, barre, phases, taille de l'arène, textes) ; sans elle, l'arène de la
## Mère-Ronce. Son sol et son mur sont dessinés par les dessins de la région (Regions.art : ronces du
## roncier par défaut, champignons de Spore, pierres levées de Vent…).
##
## - "fermee"  : tant que les Cœurs de la région ne sont pas tous purifiés, son mur (de ronces mortes dans le roncier) en interdit l'entrée ;
## - "ouverte" : le Cœur est purifié, le mur s'écarte ; y entrer réveille le boss ;
## - "combat"  : le mur se referme derrière le joueur ; il peut se resserrer (start_shrink) ;
## - "vaincue" : Game.flags["<région>_boss_vaincu"] est posé, l'arène refleurit.
##
## Mourir pendant le combat ramène à la graine (main.player_died) : le boss se rendort avec toute
## sa vie, mais le Cœur reste purifié et l'arène ouverte.
## Ce nœud est au niveau du sol (sous les personnages) ; le boss (boss_<région>.gd, BossBase) est
## rangé avec les ennemis.
extends Node2D

const BossBar = preload("res://scripts/boss_bar.gd")
const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")

const SHRINK_WARN := 1.6
const SHRINK_SPEED := 30.0
const WALL_DAMAGE := 8.0
## Points du boss si « boss › reward » du fichier de la région ne les donne pas.
const REWARD_POINTS := 2

var main
var heart
## Région de l'arène, son drapeau et son boss (script BossBase, nom, barre, phases, textes).
var region := "ronce"
var flag := "ronce_boss_vaincu"
var boss_script: GDScript
var boss_name := "La Mère-Ronce"
var bar_color := Color("c84b44")
var phase_names: Array = ["Phase 1 sur 3", "Phase 2 sur 3 : les bourgeons éclosent", "Phase 3 sur 3 : les ronces se resserrent"]
## Rayon de l'arène, rayon final quand elle se resserre, et distance entre le Cœur et son centre
## (vers l'extérieur du monde).
var max_radius := 470.0
var min_radius := 310.0
var offset := 800.0
## Fleurs de la vague de vie après la victoire.
var life_color := Color("e0675e")
var center := Vector2.ZERO
var radius := 470.0
var state := "fermee"
var boss
var bar
var t := 0.0
## Ouverture du mur (0 fermé, 1 ouvert), animée.
var gap_open := 0.0
var shrink_warn := 0.0
var shrinking := false
## Vague de vie après la victoire (secondes), -1 sinon.
var life_wave := -1.0
var life_step := 0.0
## Combats perdus depuis le lancement (sert au robot du mode autotest).
var defeats := 0
## Figée par les tests visuels.
var frozen := false
## Forme du mur : un décalage et une taille par ronce, tirés une fois.
var _wall: Array = []
var rng := RandomNumberGenerator.new()

# Robot du mode « -- --autotest=boss ».
var auto_time := 0.0
## Durée maximale du combat du robot (« -- --autotest=boss ») avant l'échec.
var auto_max := 300.0
var auto_done := false
var auto_shots := {}
var auto_boss_left := 1.0


## Lit les réglages de l'arène et de son boss dans le fichier de la région (appelé par _ready).
func configure(id: String) -> void:
	region = id
	flag = Regions.boss_flag(id)
	var b := Regions.section(id, "boss")
	boss_script = load(str(b.get("script", "res://scripts/boss_ronce.gd")))
	boss_name = str(b.get("name", boss_name))
	bar_color = Regions.color(b.get("bar_color", "#c84b44"))
	phase_names = b.get("phases", phase_names)
	var ar: Dictionary = b.get("arena", {})
	max_radius = float(ar.get("radius", max_radius))
	min_radius = float(ar.get("radius_min", min_radius))
	offset = float(ar.get("offset", offset))
	life_color = Regions.color(ar.get("life_color", "#e0675e"))
	radius = max_radius


func _ready() -> void:
	configure(region)
	if Regions.exists(region):
		center = Regions.arena_center(region)
	else:
		var dir: Vector2 = heart.center.normalized() if heart.center.length() > 1.0 else Vector2.UP
		var limit: float = main.world_half - max_radius - Regions.WORLD_MARGIN
		center = (heart.center + dir * offset).clamp(Vector2(-limit, -limit), Vector2(limit, limit))
	var shape := RandomNumberGenerator.new()
	shape.seed = 97
	for i in 72:
		_wall.append([shape.randf_range(-0.03, 0.03), shape.randf_range(0.7, 1.3), shape.randf_range(-1.0, 1.0)])
	Game.seed_rng(rng, 4 + 10 * maxi(0, Regions.ids().find(region)))
	bar = BossBar.new()
	# Marques des phases sur la barre : celles du boss (lues sur un boss jamais posé dans le monde).
	var probe = boss_script.new()
	bar.marks = probe.phase_limits
	probe.free()
	main.hud.get_parent().add_child(bar)


func in_combat() -> bool:
	return state == "combat"


## Point devant la brèche, côté Cœur, hors de la zone qui réveille la Mère-Ronce : là où l'on
## reprend une partie sauvegardée pendant le combat, et où la sève attend après une mort dans l'arène.
func entrance() -> Vector2:
	var dir: Vector2 = (heart.center - center).normalized() if heart.center.distance_to(center) > 1.0 else Vector2.DOWN
	return center + dir * (max_radius + 70.0)


func _process(delta: float) -> void:
	t += delta
	# Redessinée seulement quand elle touche le cadre de la caméra : les murs des régions (champignons,
	# pierres levées) coûtent plus cher que l'ancien mur de ronces.
	if not frozen and main.player.position.distance_squared_to(center) < 1900.0 * 1900.0 and _near_view():
		queue_redraw()


## L'arène (mur compris, plus une marge) touche le cadre visible.
func _near_view() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return view.grow(max_radius + 120.0).has_point(center)


func _physics_process(delta: float) -> void:
	if frozen:
		return
	var p = main.player
	var to: Vector2 = p.position - center
	var d := to.length()
	# Les drapeaux font foi (partie chargée, Cœur purifié à l'instant).
	if Game.flags.get(flag, false):
		if state != "vaincue":
			state = "vaincue"
			gap_open = 1.0
	elif state == "fermee" and Game.flags.get(Regions.heart_flag(region), false):
		state = "ouverte"
	match state:
		"fermee":
			if d < max_radius + p.radius + 16.0:
				var out: Vector2 = to / d if d > 0.01 else (heart.center - center).normalized()
				p.position = center + out * (max_radius + p.radius + 16.0)
		"ouverte":
			gap_open = minf(1.0, gap_open + delta / 1.5)
			if d < max_radius - 70.0 and (not main.benchmark or main.bench_scene == "boss"):
				_start_fight()
		"combat":
			if not is_instance_valid(boss) or boss.is_queued_for_deletion():
				_fight_lost()
				return
			gap_open = maxf(0.0, gap_open - delta / 0.6)
			_shrink_step(delta)
			var limit: float = radius - p.radius - 10.0
			if d > limit:
				p.position = center + to / maxf(d, 0.01) * limit
				p.take_hit(WALL_DAMAGE * boss.damage_scale, null)
			update_bar()
		"vaincue":
			bar.hide_bar()
			_life_wave_step(delta)


func update_bar() -> void:
	bar.show_bar(boss_name, boss.hp / boss.max_hp, phase_names[mini(boss.phase, phase_names.size()) - 1], bar_color)


func _start_fight() -> void:
	state = "combat"
	radius = max_radius
	shrinking = false
	shrink_warn = 0.0
	main.spawn_paused = true
	# Le mur se referme : les Flétris restés dehors ne prennent pas part au combat.
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead and e.position.distance_to(center) > max_radius:
			e.dead = true
			e.queue_free()
	boss = boss_script.new()
	boss.main = main
	boss.arena = self
	boss.region = region
	boss.position = center
	main.enemies_layer.add_child(boss)
	main.enemies.append(boss)
	main.big_enemies.append(boss)
	main.fx.ring(center, 30.0, max_radius, 0.8, Color(1.0, 0.45, 0.3, 0.8), 6.0)
	# Entrée dans l'arène : le mur se referme, l'écran rougit sur les bords et tremble.
	main.screen_fx.glow(Art.c("danger"), 0.45, main.screen_fx.FADE_ARENA * 1.6)
	main.fx.shake(0.45)
	main.fx.hitstop(0.05)


## Le joueur est mort : la Mère-Ronce a disparu avec les autres ennemis. Elle reviendra avec toute
## sa vie ; le Cœur reste purifié et l'arène ouverte.
func _fight_lost() -> void:
	defeats += 1
	state = "ouverte"
	boss = null
	radius = max_radius
	shrinking = false
	shrink_warn = 0.0
	main.spawn_paused = false
	bar.hide_bar()


## Appelé par la Mère-Ronce quand elle meurt : drapeau, points d'arbre, l'arène refleurit.
func boss_defeated() -> void:
	state = "vaincue"
	gap_open = 1.0
	shrinking = false
	shrink_warn = 0.0
	main.spawn_paused = false
	Game.flags[flag] = true
	SteamBridge.unlock(SteamBridge.boss_achievement(region))
	# Récompense (« boss › reward » de la région) : points d'arbre, donnés une seule fois, et une greffe au sol.
	var reward: Dictionary = Content.rewards().get("boss", {}).get(region, {})
	Game.grant_points(int(reward.get("points", REWARD_POINTS)), "boss", region + "_boss")
	if str(reward.get("graft", "")) != "":
		main.drop_graft(center, str(reward["graft"]))
	for i in 3:
		main.fx.ring(center, 40.0, max_radius * (0.5 + 0.3 * i), 0.9 + 0.4 * i, Color(0.6, 1.0, 0.55, 0.9), 6.0)
	# Sortie de l'arène : un éclat de sève sur les bords de l'écran, qui s'éteint doucement.
	main.screen_fx.glow(Art.ec("seve"), 0.5, 1.6)
	life_wave = 0.0
	life_step = 0.0
	bar.hide_bar()
	main.request_autosave()


## Phase 3 : le nouveau bord est annoncé au sol, puis le mur avance jusqu'à lui.
func start_shrink() -> void:
	shrink_warn = SHRINK_WARN
	shrinking = true


func _shrink_step(delta: float) -> void:
	if not shrinking:
		return
	if shrink_warn > 0.0:
		shrink_warn -= delta
		return
	radius = maxf(min_radius, radius - SHRINK_SPEED * delta)
	if radius <= min_radius:
		shrinking = false


func _life_wave_step(delta: float) -> void:
	if life_wave < 0.0:
		return
	life_wave += delta
	life_step -= delta
	if life_step <= 0.0:
		life_step = 0.12
		var r := lerpf(120.0, max_radius * 1.25, clampf(life_wave / 2.0, 0.0, 1.0))
		main.ground.paint(center, r, 0.3)
		main.flora.spawn_patch(center, r, 7, life_color)
	if life_wave >= 2.0:
		life_wave = -1.0


func _draw() -> void:
	# Sol et mur de l'arène : les dessins de la région (Regions.art, region_art.gd par défaut).
	var art: GDScript = Regions.art(region) if Regions.exists(region) else load(Regions.BASE_ART)
	art.draw_arena_floor(self, self)
	# Annonce du resserrement : le futur bord clignote au sol.
	if shrinking:
		var blink := 0.5 + 0.5 * sin(t * 12.0)
		draw_arc(center, min_radius, 0.0, TAU, 96, Color(1.0, 0.35, 0.2, 0.35 + 0.5 * blink), 5.0)
		for i in 24:
			var dir := Vector2.from_angle(TAU * i / 24.0)
			draw_line(center + dir * (radius - 24.0), center + dir * lerpf(radius - 24.0, min_radius + 8.0, 0.3 + 0.2 * blink), Color(1.0, 0.35, 0.2, 0.35), 3.0)
	art.draw_arena_wall(self, self)
	# Le boss endormi, puis ce qui pousse à sa place : dessinés par son script (BossBase).
	if state == "ouverte" or state == "fermee":
		boss_script.draw_sleeper(self)
	elif state == "vaincue":
		boss_script.draw_victory(self)


# --- Robot du mode « -- --autotest=boss » ---

## Prépare le combat : un build de test (niveau 12, points placés dans la branche de la région), le
## Cœur déjà purifié et le joueur posé dans l'arène.
func autotest_begin() -> void:
	autotest_build(12, Regions.branch_of(region))
	Game.flags[Regions.heart_flag(region)] = true
	main.player.hp = Game.stats["max_hp"]
	main.player.position = center + (heart.center - center).normalized() * (max_radius - 110.0)
	main.player.reset_physics_interpolation()
	print("AUTOTEST boss : niveau %d, %d nœuds de la branche, dégâts %.1f, vie %d" % [Game.level, Game.allocated.size() - 1, Game.stats["damage"], int(Game.stats["max_hp"])])


## Build de test des robots de boss : monte au niveau « level » et place tous les points dans la
## branche « branch » (nœuds clés d'abord, puis ceux qui augmentent les dégâts ou la cadence).
static func autotest_build(level: int, branch: String) -> void:
	while Game.level < level:
		Game.add_xp(Game.xp_to_next())
	var bi := maxi(0, Content.tree().get("branches", []).find(branch))
	while Game.points > 0:
		var options: Array = []
		for n in Game.tree.nodes:
			if n["branch"] == bi and n["border"] < 0 and Game.can_allocate(n["id"]):
				options.append(n)
		if options.is_empty():
			break
		options.sort_custom(func(a, b):
			if (a["type"] == "keystone") != (b["type"] == "keystone"):
				return a["type"] == "keystone"
			# Puis les nœuds qui augmentent les dégâts ou la cadence : un robot qui se contente
			# de la première grappe venue allongeait le combat de plusieurs minutes (région Vent).
			var sa := _autotest_node_score(a)
			var sb := _autotest_node_score(b)
			if sa != sb:
				return sa > sb
			return a["ring"] < b["ring"] if a["ring"] != b["ring"] else a["id"] < b["id"])
		Game.allocate(options[0]["id"])


## Intérêt d'un nœud pour le build de test : nombre d'effets qui touchent aux dégâts, à la cadence
## ou à l'attaque de base.
static func _autotest_node_score(n: Dictionary) -> int:
	var score := 0
	for e in n.get("effects", []):
		if e is Dictionary:
			if e.has("attack_form") or e.has("attack_mod"):
				score += 1
			elif str(e.get("stat", "")) in ["damage", "projectile_damage", "fire_rate", "crit_chance", "crit_mult"]:
				score += 1
	return score


## Le robot tourne autour du boss et choisit, parmi quelques pas possibles, l'endroit
## que les attaques annoncées toucheront le plus tard.
func bot_input(p) -> Dictionary:
	if state != "combat" or not is_instance_valid(boss) or boss.dead:
		var mv: Vector2 = center - p.position
		return {"move": mv.normalized() if state == "ouverte" and mv.length() > 60.0 else Vector2.ZERO, "aim": center, "dash": false}
	var target: Vector2 = boss.position
	var best_d := 240.0 * 240.0
	for e in boss.minions:
		if is_instance_valid(e) and not e.dead:
			var d2: float = e.position.distance_squared_to(p.position)
			if d2 < best_d:
				best_d = d2
				target = e.position
	var rel: Vector2 = p.position - center
	var ring: float = boss.bot_ring(radius)
	# Attaque de base au corps à corps (le fouet de Ronce, ~135 px) : le robot se rapproche pour
	# toucher le boss, sauf quand celui-ci annonce une attaque que l'anneau lointain évite.
	var reach: float = p.attack_range()
	if boss.attack == "" or boss.stage == "annonce":
		var melee_ring: float = boss.radius + maxf(reach * 0.4, 60.0)
		if melee_ring < ring:
			ring = maxf(melee_ring, boss.radius + 55.0)
	var pref := center + Vector2.from_angle(rel.angle() + 0.45) * ring
	var here: float = boss.danger_time(p.position)
	var best_pos: Vector2 = p.position
	var best_score := -INF
	var options: Array = [p.position, p.position + (pref - p.position).limit_length(90.0)]
	for i in 12:
		options.append(p.position + Vector2.from_angle(TAU * i / 12.0) * 90.0)
	for o in options:
		var c: Vector2 = o
		var dc := c.distance_to(center)
		if dc > radius - 40.0 or dc < boss.radius + 50.0:
			continue
		var score: float = minf(boss.danger_time(c), 2.0) * 100.0 - c.distance_to(pref) * 0.5
		for e in boss.minions:
			if is_instance_valid(e) and not e.dead and e.position.distance_to(c) < 70.0:
				score -= 60.0
		if score > best_score:
			best_score = score
			best_pos = c
	var move: Vector2 = best_pos - p.position
	return {"move": move.normalized() if move.length() > 4.0 else Vector2.ZERO, "aim": target, "dash": here < 0.2}


## Suit le combat : captures à chaque phase, puis fin sur une victoire, une défaite, ou un échec
## si le combat dure plus de 5 minutes.
func autotest_step(delta: float) -> void:
	if auto_done:
		return
	auto_time += delta
	if state == "combat" and is_instance_valid(boss) and not boss.dead:
		auto_boss_left = boss.hp / boss.max_hp
		if int(auto_time / 10.0) != int((auto_time - delta) / 10.0):
			print("AUTOTEST boss : %3d s  phase %d  vie du boss %d %%  vie du joueur %d" % [int(auto_time), boss.phase, roundi(auto_boss_left * 100.0), int(main.player.hp)])
		var key := "boss_phase%d" % boss.phase
		if not auto_shots.has(key) and boss.attack != "" and boss.stage == "annonce":
			auto_shots[key] = true
			main._capture(key)
	if state == "vaincue":
		_autotest_end("victoire", 0)
	elif defeats > 0:
		_autotest_end("défaite", 0)
	elif auto_time >= auto_max:
		_autotest_end("ÉCHEC, combat non terminé", 1)


func _autotest_end(result: String, code: int) -> void:
	auto_done = true
	var left := 0.0 if state == "vaincue" else auto_boss_left
	print("AUTOTEST boss : %s en %.1f s  (vie du boss %d %%, vie du joueur %d, drapeaux %s)" % [result, auto_time, roundi(left * 100.0), int(main.player.hp), JSON.stringify(Game.flags)])
	await get_tree().create_timer(1.0).timeout
	await main._capture("boss_fin")
	get_tree().quit(code)
