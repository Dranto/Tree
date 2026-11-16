## Arène de la Mère-Ronce : un cercle de ronces au-delà du Cœur de flétrissure.
##
## - "fermee"  : tant que le Cœur n'est pas purifié, un mur de ronces mortes en interdit l'entrée ;
## - "ouverte" : le Cœur est purifié, le mur s'écarte ; y entrer réveille la Mère-Ronce ;
## - "combat"  : le mur se referme derrière le joueur ; en phase 3 il se resserre ;
## - "vaincue" : Game.flags["ronce_boss_vaincu"] est posé, l'arène refleurit.
##
## Mourir pendant le combat ramène à la graine (main.player_died) : la Mère-Ronce se rendort
## avec toute sa vie, mais le Cœur reste purifié et l'arène ouverte.
## Ce nœud est au niveau du sol (sous les personnages) ; la Mère-Ronce (boss.gd) est rangée avec
## les ennemis.
extends Node2D

const Boss = preload("res://scripts/boss.gd")
const BossBar = preload("res://scripts/boss_bar.gd")
const Content = preload("res://scripts/content.gd")

const FLAG := "ronce_boss_vaincu"
const RADIUS := 470.0
## Rayon final en phase 3 : plus petit que la portée des fouets, il n'y a plus d'anneau à l'abri.
const RADIUS_MIN := 310.0
## Distance entre le Cœur et le centre de l'arène, vers l'extérieur du monde.
const OFFSET := 800.0
const SHRINK_WARN := 1.6
const SHRINK_SPEED := 30.0
const WALL_DAMAGE := 8.0
## Points du boss si data/rewards.json ne les donne pas.
const REWARD_POINTS := 2
const PHASE_NAMES := ["Phase 1 sur 3", "Phase 2 sur 3 : les bourgeons éclosent", "Phase 3 sur 3 : les ronces se resserrent"]

var main
var heart
var center := Vector2.ZERO
var radius := RADIUS
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
var auto_done := false
var auto_shots := {}
var auto_boss_left := 1.0


func _ready() -> void:
	var dir: Vector2 = heart.center.normalized() if heart.center.length() > 1.0 else Vector2.UP
	var limit: float = main.world_half - RADIUS - 60.0
	center = (heart.center + dir * OFFSET).clamp(Vector2(-limit, -limit), Vector2(limit, limit))
	var shape := RandomNumberGenerator.new()
	shape.seed = 97
	for i in 72:
		_wall.append([shape.randf_range(-0.03, 0.03), shape.randf_range(0.7, 1.3), shape.randf_range(-1.0, 1.0)])
	Game.seed_rng(rng, 4)
	bar = BossBar.new()
	bar.marks = Boss.PHASE_LIMITS
	main.hud.get_parent().add_child(bar)


func in_combat() -> bool:
	return state == "combat"


## Point devant la brèche, côté Cœur, hors de la zone qui réveille la Mère-Ronce : là où l'on
## reprend une partie sauvegardée pendant le combat, et où la sève attend après une mort dans l'arène.
func entrance() -> Vector2:
	var dir: Vector2 = (heart.center - center).normalized() if heart.center.distance_to(center) > 1.0 else Vector2.DOWN
	return center + dir * (RADIUS + 70.0)


func _process(delta: float) -> void:
	t += delta
	if not frozen and main.player.position.distance_squared_to(center) < 1900.0 * 1900.0:
		queue_redraw()


func _physics_process(delta: float) -> void:
	if frozen:
		return
	var p = main.player
	var to: Vector2 = p.position - center
	var d := to.length()
	# Les drapeaux font foi (partie chargée, Cœur purifié à l'instant).
	if Game.flags.get(FLAG, false):
		if state != "vaincue":
			state = "vaincue"
			gap_open = 1.0
	elif state == "fermee" and Game.flags.get(heart.FLAG, false):
		state = "ouverte"
	match state:
		"fermee":
			if d < RADIUS + p.radius + 16.0:
				var out: Vector2 = to / d if d > 0.01 else (heart.center - center).normalized()
				p.position = center + out * (RADIUS + p.radius + 16.0)
		"ouverte":
			gap_open = minf(1.0, gap_open + delta / 1.5)
			if d < RADIUS - 70.0 and not main.benchmark:
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
	bar.show_bar("La Mère-Ronce", boss.hp / boss.max_hp, PHASE_NAMES[boss.phase - 1], Color("c84b44"))


func _start_fight() -> void:
	state = "combat"
	radius = RADIUS
	shrinking = false
	shrink_warn = 0.0
	main.spawn_paused = true
	# Les ronces se referment : les Flétris restés dehors ne prennent pas part au combat.
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead and e.position.distance_to(center) > RADIUS:
			e.dead = true
			e.queue_free()
	boss = Boss.new()
	boss.main = main
	boss.arena = self
	boss.position = center
	main.enemies_layer.add_child(boss)
	main.enemies.append(boss)
	main.big_enemies.append(boss)
	main.hud.banner("La Mère-Ronce s'éveille.", "combat")
	main.fx.ring(center, 30.0, RADIUS, 0.8, Color(1.0, 0.45, 0.3, 0.8), 6.0)
	# Entrée dans l'arène : les ronces se referment, l'écran rougit sur les bords et tremble.
	main.screen_fx.glow(Art.c("danger"), 0.45, main.screen_fx.FADE_ARENA * 1.6)
	main.fx.shake(0.45)
	main.fx.hitstop(0.05)


## Le joueur est mort : la Mère-Ronce a disparu avec les autres ennemis. Elle reviendra avec toute
## sa vie ; le Cœur reste purifié et l'arène ouverte.
func _fight_lost() -> void:
	defeats += 1
	state = "ouverte"
	boss = null
	radius = RADIUS
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
	Game.flags[FLAG] = true
	# Récompense (data/rewards.json) : points d'arbre, donnés une seule fois, et une greffe au sol.
	main.hud.banner("La Mère-Ronce est vaincue !")
	var reward: Dictionary = Content.rewards().get("boss", {}).get("ronce", {})
	Game.grant_points(int(reward.get("points", REWARD_POINTS)), "boss", "ronce_boss")
	if str(reward.get("graft", "")) != "":
		main.drop_graft(center, str(reward["graft"]))
	for i in 3:
		main.fx.ring(center, 40.0, RADIUS * (0.5 + 0.3 * i), 0.9 + 0.4 * i, Color(0.6, 1.0, 0.55, 0.9), 6.0)
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
	radius = maxf(RADIUS_MIN, radius - SHRINK_SPEED * delta)
	if radius <= RADIUS_MIN:
		shrinking = false


func _life_wave_step(delta: float) -> void:
	if life_wave < 0.0:
		return
	life_wave += delta
	life_step -= delta
	if life_step <= 0.0:
		life_step = 0.12
		var r := lerpf(120.0, RADIUS * 1.25, clampf(life_wave / 2.0, 0.0, 1.0))
		main.ground.paint(center, r, 0.3)
		main.flora.spawn_patch(center, r, 7, Color("e0675e"))
	if life_wave >= 2.0:
		life_wave = -1.0


func _draw() -> void:
	var alive := state == "vaincue"
	var fight := state == "combat"
	# Sol de l'arène.
	if alive:
		draw_circle(center, RADIUS * 0.5, Color(0.55, 0.95, 0.5, 0.08 + 0.03 * sin(t * 2.0)))
	else:
		draw_circle(center, radius, Color(0.08, 0.02, 0.03, 0.3 if fight else 0.2))
	# Annonce du resserrement : le futur bord clignote au sol.
	if shrinking:
		var blink := 0.5 + 0.5 * sin(t * 12.0)
		draw_arc(center, RADIUS_MIN, 0.0, TAU, 96, Color(1.0, 0.35, 0.2, 0.35 + 0.5 * blink), 5.0)
		for i in 24:
			var dir := Vector2.from_angle(TAU * i / 24.0)
			draw_line(center + dir * (radius - 24.0), center + dir * lerpf(radius - 24.0, RADIUS_MIN + 8.0, 0.3 + 0.2 * blink), Color(1.0, 0.35, 0.2, 0.35), 3.0)
	# Mur de ronces : une brèche s'ouvre du côté du Cœur quand l'arène est ouverte.
	var n := _wall.size()
	var gate: float = (heart.center - center).angle()
	var stem := Color("2c2226")
	var thorn := Color("8a7f78")
	if fight:
		stem = Color("3d1f24")
		thorn = Color("e0a090")
	elif alive:
		stem = Color("2f6b2a")
		thorn = Color("468f38")
	var pts := PackedVector2Array()
	var pts2 := PackedVector2Array()
	for i in n + 1:
		var w: Array = _wall[i % n]
		var a := TAU * i / n
		var off := absf(wrapf(a - gate, -PI, PI))
		if off < 0.42 * gap_open:
			_wall_strip(pts, pts2, stem)
			pts = PackedVector2Array()
			pts2 = PackedVector2Array()
			continue
		var dir := Vector2.from_angle(a)
		var r: float = radius * (1.0 + w[0])
		pts.append(center + dir * r)
		pts2.append(center + dir * (r + 16.0 + 8.0 * w[2]))
		var len: float = 16.0 * w[1]
		var lean := Vector2.from_angle(a + 0.5 * w[2])
		draw_line(center + dir * r, center + dir * r - lean * len, thorn, 3.0)
		draw_line(center + dir * (r + 14.0), center + dir * (r + 14.0) + lean * len, thorn, 3.0)
		if alive and i % 3 == 0:
			var rose := center + dir * (r + 8.0)
			for j in 5:
				draw_circle(rose + Vector2.from_angle(TAU * j / 5.0 + i) * 5.0, 4.5, Color("e0675e").lerp(Color("f48fb1"), 0.5 + 0.5 * w[2]))
			draw_circle(rose, 3.0, Color("fff3c4"))
	_wall_strip(pts, pts2, stem)
	if state == "ouverte" or state == "fermee":
		_draw_sleeper()
	elif alive:
		_draw_rosebush()


func _wall_strip(pts: PackedVector2Array, pts2: PackedVector2Array, stem: Color) -> void:
	if pts.size() >= 2:
		draw_polyline(pts, stem, 13.0)
		draw_polyline(pts2, stem.darkened(0.25), 9.0)


## La Mère-Ronce endormie : un bouton fermé au centre de l'arène, tant que le combat n'a pas lieu.
func _draw_sleeper() -> void:
	var r := Boss.RADIUS * 0.75
	var c := center + Vector2(0, -r * 0.4)
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		draw_line(center, center + Vector2.from_angle(a) * r * 1.9 * Vector2(1.0, 0.7), Color("1c1418"), 9.0)
	for i in 8:
		var a := TAU * i / 8.0
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * r * 0.4
		draw_colored_polygon(PackedVector2Array([c, c + dir * r * 0.6 + side, c + dir * r * 1.05, c + dir * r * 0.6 - side]), Color("3a2630") if i % 2 == 0 else Color("4a2a36"))
	draw_circle(c, r * 0.45, Color("2a1c22"))
	if state == "ouverte":
		draw_circle(c, r * 0.2, Color(1.0, 0.6, 0.3, 0.45 + 0.35 * sin(t * 2.0)))


## Après la victoire : un grand rosier en fleurs à la place de la Mère-Ronce.
func _draw_rosebush() -> void:
	var r := Boss.RADIUS
	var c := center + Vector2(0, -r * 0.4)
	for i in 7:
		var a := TAU * i / 7.0
		draw_circle(c + Vector2.from_angle(a) * r * 0.55, r * 0.5, Color("2f6b2a") if i % 2 == 0 else Color("3b7d31"))
	draw_circle(c, r * 0.6, Color("468f38"))
	for i in 9:
		var a := TAU * i / 9.0 + 0.4
		var rose := c + Vector2.from_angle(a) * r * (0.35 + 0.5 * (i % 3) / 2.0)
		for j in 5:
			draw_circle(rose + Vector2.from_angle(TAU * j / 5.0 + i) * 7.0, 6.5, Color("e0675e") if i % 2 == 0 else Color("f48fb1"))
		draw_circle(rose, 4.0, Color("fff3c4"))


# --- Robot du mode « -- --autotest=boss » ---

## Prépare le combat : un build de test (niveau 12, points placés dans Ronce), le Cœur déjà
## purifié et le joueur posé dans l'arène.
func autotest_begin() -> void:
	while Game.level < 12:
		Game.add_xp(Game.xp_to_next())
	while Game.points > 0:
		var options: Array = []
		for n in Game.tree.nodes:
			if n["branch"] == 0 and Game.can_allocate(n["id"]):
				options.append(n)
		if options.is_empty():
			break
		options.sort_custom(func(a, b):
			if (a["type"] == "keystone") != (b["type"] == "keystone"):
				return a["type"] == "keystone"
			return a["ring"] < b["ring"] if a["ring"] != b["ring"] else a["id"] < b["id"])
		Game.allocate(options[0]["id"])
	Game.flags[heart.FLAG] = true
	main.player.hp = Game.stats["max_hp"]
	main.player.position = center + (heart.center - center).normalized() * (RADIUS - 110.0)
	main.player.reset_physics_interpolation()
	print("AUTOTEST boss : niveau %d, %d nœuds de Ronce, dégâts %.1f, vie %d" % [Game.level, Game.allocated.size() - 1, Game.stats["damage"], int(Game.stats["max_hp"])])


## Le robot tourne autour de la Mère-Ronce et choisit, parmi quelques pas possibles, l'endroit
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
	var ring := minf(250.0, radius - 60.0)
	# Tant que l'arène est large, l'anneau extérieur est hors de portée des fouets.
	if boss.attack == "fouets" and radius - 60.0 > Boss.WHIP["length"] + 40.0:
		ring = Boss.WHIP["length"] + 50.0
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
		var score: float = minf(boss.danger_time(c), 2.0) * 100.0 - c.distance_to(pref) * 0.2
		for e in boss.minions:
			if is_instance_valid(e) and not e.dead and e.position.distance_to(c) < 70.0:
				score -= 60.0
		if score > best_score:
			best_score = score
			best_pos = c
	var move: Vector2 = best_pos - p.position
	return {"move": move.normalized() if move.length() > 4.0 else Vector2.ZERO, "aim": target, "dash": here < 0.2}


## Suit le combat : captures à chaque phase, puis fin sur une victoire, une défaite, ou un échec
## si le combat dure plus de 3 minutes.
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
	elif auto_time >= 180.0:
		_autotest_end("ÉCHEC, combat non terminé", 1)


func _autotest_end(result: String, code: int) -> void:
	auto_done = true
	var left := 0.0 if state == "vaincue" else auto_boss_left
	print("AUTOTEST boss : %s en %.1f s  (vie du boss %d %%, vie du joueur %d, drapeaux %s)" % [result, auto_time, roundi(left * 100.0), int(main.player.hp), JSON.stringify(Game.flags)])
	await get_tree().create_timer(1.0).timeout
	await main._capture("boss_fin")
	get_tree().quit(code)
