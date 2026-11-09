## Scène principale : assemble le monde, le joueur, les Flétris et l'interface.
extends Node2D

const WORLD_HALF := 2900.0
## Correspondance entre l'arbre de vie et le monde : un nœud ravive la région
## située dans la même direction que lui, à une distance proportionnelle à son anneau.
const TREE_TO_WORLD := 2.1

const Ground = preload("res://scripts/ground.gd")
const Flora = preload("res://scripts/flora.gd")
const Fx = preload("res://scripts/fx.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Orb = preload("res://scripts/orb.gd")
const Hud = preload("res://scripts/hud.gd")
const TreeUI = preload("res://scripts/tree_ui.gd")

var world_half := WORLD_HALF
var ground
var flora
var fx
var player
var hud
var tree_ui
var orbs_layer: Node2D
var enemies_layer: Node2D
var projectiles_layer: Node2D
var enemies: Array = []
var spawn_timer := 1.5
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
## Mode de test automatique (lancer avec « -- --autotest ») : un robot joue, apprend des nœuds
## et enregistre des captures dans godot/autotest/ avant de quitter.
var autotest := false
var autotest_time := 0.0
var autotest_shots := [3.0, 25.0, 55.0]
var autotest_done := false


func _ready() -> void:
	rng.randomize()
	_setup_input()
	autotest = "--autotest" in OS.get_cmdline_user_args()
	if autotest:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://autotest"))

	ground = Ground.new()
	add_child(ground)
	flora = Flora.new()
	flora.ground = ground
	add_child(flora)
	orbs_layer = Node2D.new()
	add_child(orbs_layer)
	enemies_layer = Node2D.new()
	add_child(enemies_layer)
	projectiles_layer = Node2D.new()
	add_child(projectiles_layer)
	player = Player.new()
	player.main = self
	add_child(player)
	fx = Fx.new()
	fx.main = self
	add_child(fx)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)
	cam.make_current()

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = Hud.new()
	hud.main = self
	hud_layer.add_child(hud)

	var tree_layer := CanvasLayer.new()
	tree_layer.layer = 10
	tree_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tree_layer)
	tree_ui = TreeUI.new()
	tree_layer.add_child(tree_ui)

	Game.node_allocated.connect(_on_node_allocated)
	Game.leveled_up.connect(_on_level_up)

	# Une oasis de départ autour de la graine.
	ground.paint(Vector2.ZERO, 260.0, 1.0)
	flora.spawn_patch(Vector2.ZERO, 200.0, 14, Color("7fd36b"))


func _setup_input() -> void:
	_keys("move_up", [KEY_W, KEY_UP])
	_keys("move_down", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_keys("dash", [KEY_SPACE, KEY_SHIFT])
	_keys("skill_nova", [KEY_Q])
	_keys("skill_cloud", [KEY_E])
	_keys("skill_bloom", [KEY_R])
	_keys("toggle_tree", [KEY_TAB, KEY_T])
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", ev)


## Les touches sont des positions physiques (QWERTY) : W A S D devient Z Q S D sur un clavier AZERTY.
func _keys(action: String, list: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in list:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	elapsed += delta
	if autotest:
		_autotest_step(delta)
	enemies = enemies.filter(func(e): return is_instance_valid(e) and not e.dead)
	_separate()

	spawn_timer -= delta
	var cap := mini(120, 16 + Game.level * 5)
	if spawn_timer <= 0.0:
		spawn_timer = maxf(0.22, 1.3 - Game.level * 0.05 - elapsed / 600.0)
		var burst := 1 + int(Game.level / 4.0)
		for i in burst:
			if enemies.size() < cap:
				_spawn_enemy()


## Évite que les Flétris s'empilent en un seul point.
func _separate() -> void:
	var n := enemies.size()
	for i in n:
		var a = enemies[i]
		for j in range(i + 1, n):
			var b = enemies[j]
			var d: Vector2 = b.position - a.position
			var min_d: float = a.radius + b.radius
			var l2 := d.length_squared()
			if l2 < min_d * min_d and l2 > 0.01:
				var l := sqrt(l2)
				var push := d / l * (min_d - l) * 0.5
				a.position -= push
				b.position += push


func power() -> float:
	return 1.0 + 0.12 * (Game.level - 1) + elapsed / 240.0


func _spawn_enemy() -> void:
	var pos := Vector2.ZERO
	# La vie repousse les Flétris : on évite de les faire naître en terre ravivée.
	for attempt in 4:
		var a := rng.randf() * TAU
		pos = player.position + Vector2.from_angle(a) * rng.randf_range(760.0, 980.0)
		pos = pos.clamp(Vector2(-WORLD_HALF, -WORLD_HALF), Vector2(WORLD_HALF, WORLD_HALF))
		if ground.life_at(pos) < 0.5:
			break
	var kind := 0
	var roll := rng.randf()
	if Game.level >= 4 and roll < 0.12:
		kind = 2
	elif roll < 0.4:
		kind = 1
	var e = Enemy.new()
	e.main = self
	e.position = pos
	e.setup(kind, power())
	enemies_layer.add_child(e)
	enemies.append(e)


func spawn_projectile(pos: Vector2, vel: Vector2, damage: float, pierce: int, big: bool) -> void:
	var p = Projectile.new()
	p.main = self
	p.position = pos
	p.vel = vel
	p.damage = damage
	p.pierce = pierce
	if big:
		p.radius = 13.0
	projectiles_layer.add_child(p)


## Applique un coup du joueur : critique, poison, vol de vie, éclat d'aube.
func player_hit_enemy(e, base: float, can_explode := true) -> void:
	var s: Dictionary = Game.stats
	var dmg := base
	var crit: bool = rng.randf() < s["crit"]
	if crit:
		dmg *= s["crit_mult"]
	e.take_damage(dmg, crit)
	if s["poison"] > 0.0:
		e.apply_poison(dmg * s["poison"], 3.0)
	if s["lifesteal"] > 0.0:
		player.heal(dmg * s["lifesteal"])
	if crit and can_explode and Game.has_key("eclat"):
		var r: float = 80.0 * s["area"]
		fx.ring(e.position, 10.0, r, 0.3, Color("f2d06b"), 4.0)
		for o in enemies:
			if o != e and is_instance_valid(o) and not o.dead and o.position.distance_to(e.position) < r:
				player_hit_enemy(o, base * 0.6, false)


func damage_area(center: Vector2, radius: float, amount: float, knockback: float) -> void:
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			var d: Vector2 = e.position - center
			if d.length() < radius + e.radius:
				player_hit_enemy(e, amount)
				if knockback > 0.0 and d.length() > 0.1:
					e.position += d.normalized() * knockback


func on_enemy_killed(e) -> void:
	Game.kills += 1
	var o = Orb.new()
	o.main = self
	o.position = e.position
	o.value = e.xp_value
	orbs_layer.call_deferred("add_child", o)
	# Chaque Flétri purifié rend un peu de vie au sol.
	ground.paint(e.position, 46.0 + e.radius, 0.3)
	if rng.randf() < 0.6:
		flora.add_flower(e.position + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14)))
	fx.ring(e.position, e.radius, e.radius * 2.5, 0.35, Color(0.85, 0.95, 0.75, 0.8), 3.0)
	if Game.has_key("contagion") and e.poison_time > 0.0:
		fx.ring(e.position, 10.0, 110.0, 0.4, Color("b48ae0"), 4.0)
		for other in enemies:
			if other != e and is_instance_valid(other) and not other.dead and other.position.distance_to(e.position) < 110.0:
				other.apply_poison(e.poison_dps, 3.0)
	if Game.has_key("pas_du_vent"):
		player.dash_cd = maxf(0.0, player.dash_cd - 0.3)


func player_died() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for p in projectiles_layer.get_children():
		p.queue_free()
	Game.xp = 0.0
	player.respawn()
	fx.text(player.position + Vector2(0, -60), "Tu t'es flétri… L'Arbre te fait renaître.", Color("f0e6b4"), 22, 3.0)


func _on_node_allocated(node: Dictionary) -> void:
	if node["id"] == 0:
		return
	var world_pos: Vector2 = node["pos"] * TREE_TO_WORLD
	var radius := 200.0
	if node["type"] == "notable":
		radius = 280.0
	elif node["type"] == "keystone":
		radius = 380.0
	ground.paint(world_pos, radius, 0.9)
	flora.spawn_patch(world_pos, radius * 0.8, int(radius / 18.0), Game.tree.branch_color(node["branch"]))


func _on_level_up(lvl: int) -> void:
	fx.ring(player.position, 20.0, 160.0, 0.6, Color("f0e6b4"), 5.0)
	hud.banner("Niveau %d : un point à placer dans l'Arbre de vie (Tab)" % lvl)
	player.heal(Game.stats["max_hp"] * 0.25)


# --- Mode de test automatique ---

## Commandes du robot : tourne autour de la graine en visant le Flétri le plus proche.
func bot_input(p) -> Dictionary:
	var target: Vector2 = p.position + Vector2.RIGHT * 100.0
	var best := INF
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			var d: float = e.position.distance_squared_to(p.position)
			if d < best:
				best = d
				target = e.position
	var orbit := Vector2.from_angle(elapsed * 0.35) * minf(900.0, 200.0 + elapsed * 20.0)
	var mv: Vector2 = orbit - p.position
	mv = mv.normalized() if mv.length() > 40.0 else Vector2.ZERO
	return {"move": mv, "aim": target, "dash": best < 50.0 * 50.0}


func _autotest_step(delta: float) -> void:
	autotest_time += delta
	Game.add_xp(delta * 6.0)
	while Game.points > 0:
		var options: Array = []
		for n in Game.tree.nodes:
			if Game.can_allocate(n["id"]):
				options.append(n)
		if options.is_empty():
			break
		options.sort_custom(func(a, b): return a["type"] == "keystone" and b["type"] != "keystone")
		var pick: Dictionary = options[0] if options[0]["type"] == "keystone" else options[rng.randi() % options.size()]
		Game.allocate(pick["id"])
	if autotest_shots.size() > 0 and autotest_time >= autotest_shots[0]:
		_capture("play_%02d" % int(autotest_shots.pop_front()))
	if autotest_time >= 60.0 and not autotest_done:
		autotest_done = true
		_finish_autotest()


func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://autotest/%s.png" % shot_name)
	print("AUTOTEST capture %s  niveau=%d  noeuds=%d  ennemis=%d  monde=%.1f%%  vie=%d  fps=%d" % [shot_name, Game.level, Game.allocated.size(), enemies.size(), minf(100.0, ground.ratio() / 0.67 * 100.0), int(player.hp), Engine.get_frames_per_second()])


func _finish_autotest() -> void:
	tree_ui.toggle()
	await get_tree().create_timer(0.5).timeout
	await _capture("tree")
	print("AUTOTEST fini : tués=%d" % Game.kills)
	get_tree().quit()
