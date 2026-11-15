## Scène principale : assemble le monde, le joueur, les Flétris et l'interface.
extends Node2D

const WORLD_HALF := 2900.0
## Correspondance entre l'arbre de vie et le monde : un nœud ravive la région
## située dans la même direction que lui, à une distance proportionnelle à son anneau.
const TREE_TO_WORLD := 2.1

const Ground = preload("res://scripts/ground.gd")
const Flora = preload("res://scripts/flora.gd")
const Fx = preload("res://scripts/fx.gd")
const Ambience = preload("res://scripts/ambience.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Orb = preload("res://scripts/orb.gd")
const Hud = preload("res://scripts/hud.gd")
const TreeUI = preload("res://scripts/tree_ui.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const SpatialGrid = preload("res://scripts/spatial_grid.gd")
const BLEED_BASE_DURATION := 4.0
const Heart = preload("res://scripts/heart.gd")
const BossArena = preload("res://scripts/boss_arena.gd")
const Regions = preload("res://scripts/regions.gd")
const Content = preload("res://scripts/content.gd")

## Apparitions par région (sortes du roncier, part selon la distance) : res://data/enemies.json.
var region_spawn: Dictionary = Content._load("enemies").get("spawn", {})
## Flétris ordinaires (poids, niveau minimal, nombre maximal en vie) : « ordinary » de enemies.json.
var ordinary_spawn: Dictionary = Content._load("enemies").get("ordinary", {})

## Une élite vient d'être vaincue (contrat partagé : butin, objectif « vaincre trois élites »).
signal elite_killed(enemy)
## Dernier état connu de la purification du Cœur de Ronce (contrat avec la tâche D).
var ronce_purified := false
const BuildBot = preload("res://scripts/build_bot.gd")

var world_half := WORLD_HALF
var ground
var flora
var fx
var player
var hud
var tree_ui
var pause_menu
var orbs_layer: Node2D
var enemies_layer: Node2D
var projectiles_layer: Node2D
## Calque trié en profondeur (Y-sort) : arbres du décor, Flétris et joueur.
var actors_layer: Node2D
## Flétris rangés par cases, reconstruite à chaque pas de jeu (voir enemies_near).
var grid = SpatialGrid.new()
var enemies: Array = []
## Dégâts du coup de racines en cours (contexte de l'évènement « root »), 0 hors de ce coup.
var root_hit_base := 0.0
## Ennemis trop gros pour la grille spatiale (boss) : testés à part dans enemies_near.
var big_enemies: Array = []
## Cœur de flétrissure et arène de la Mère-Ronce (région de Ronce).
var heart
var arena
## Vrai pendant un combat de boss : plus aucun Flétri ne naît autour du joueur.
var spawn_paused := false
var spawn_timer := 1.5
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
## Mode de test automatique (lancer avec « -- --autotest ») : un robot joue, apprend des nœuds
## et enregistre des captures dans godot/autotest/ avant de quitter.
var autotest := false
## « -- --autotest=boss » : le robot est posé dans l'arène de la Mère-Ronce avec un build de test.
var autotest_boss := false
var autotest_time := 0.0
var autotest_shots := [3.0, 25.0, 55.0]
var autotest_done := false
## Robot d'équilibrage (« -- --autotest=build:<nom> », voir build_bot.gd) : joue un build type.
var build_bot = null
var deaths := 0
## Sauvegarde automatique (désactivée en autotest) : périodique et après chaque changement.
const AUTOSAVE_EVERY := 60.0
var autosave_enabled := true
var autosave_timer := AUTOSAVE_EVERY
var autosave_pending := false
## Banc de performance (« -- --benchmark ») : le robot joue face à 120 Flétris pendant
## BENCH_TIME secondes (après BENCH_WARMUP de mise en route), puis le temps par image s'affiche.
const BENCH_ENEMIES := 120
const BENCH_WARMUP := 3.0
const BENCH_TIME := 30.0
var benchmark := false
var bench_clock := 0.0
var bench_last_usec := 0
var bench_frames: PackedFloat32Array = PackedFloat32Array()
var bench_cpu := {"process": 0.0, "physics": 0.0, "samples": 0}


func _ready() -> void:
	Game.seed_rng(rng)
	_setup_input()
	# Un banc de test peut activer le robot avant d'ajouter la scène (pas de sauvegarde dans ce mode).
	autotest_boss = "--autotest=boss" in OS.get_cmdline_user_args()
	autotest = autotest or autotest_boss or "--autotest" in OS.get_cmdline_user_args()
	benchmark = "--benchmark" in OS.get_cmdline_user_args()
	build_bot = BuildBot.from_cmdline()
	if build_bot != null:
		autotest = true
		autotest_shots = []
	if benchmark:
		# Le robot joue, sans captures ni fin de partie, et rien n'est sauvegardé.
		autotest = true
		autotest_shots = []
		autotest_done = true
		if Game.forced_seed < 0:
			rng.seed = 1
	if autotest:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://autotest"))

	ground = Ground.new()
	add_child(ground)
	# Les arbres du décor, les Flétris et le joueur partagent un calque trié en profondeur :
	# un personnage plus haut à l'écran qu'un arbre passe derrière lui.
	actors_layer = Node2D.new()
	actors_layer.y_sort_enabled = true
	var trees_layer := Node2D.new()
	trees_layer.y_sort_enabled = true
	actors_layer.add_child(trees_layer)
	flora = Flora.new()
	flora.ground = ground
	flora.trees_parent = trees_layer
	add_child(flora)
	orbs_layer = Node2D.new()
	add_child(orbs_layer)
	add_child(actors_layer)
	enemies_layer = Node2D.new()
	enemies_layer.y_sort_enabled = true
	actors_layer.add_child(enemies_layer)
	player = Player.new()
	player.main = self
	actors_layer.add_child(player)
	projectiles_layer = Node2D.new()
	add_child(projectiles_layer)
	fx = Fx.new()
	fx.main = self
	add_child(fx)
	var ambience = Ambience.new()
	ambience.main = self
	add_child(ambience)

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
	# L'arbre couvre tout l'écran : le monde et le HUD ne sont plus dessinés tant qu'il est ouvert.
	tree_ui.toggled.connect(func(open: bool):
		visible = not open
		hud_layer.visible = not open)

	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 20
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	pause_menu = PauseMenu.new()
	pause_menu.main = self
	pause_layer.add_child(pause_menu)

	# Région de Ronce : leurs marques au sol se dessinent sous les personnages.
	heart = Heart.new()
	heart.main = self
	arena = BossArena.new()
	arena.main = self
	arena.heart = heart
	for n in [heart, arena]:
		add_child(n)
		move_child(n, actors_layer.get_index())

	Sfx.listener = player
	Music.start()
	Game.node_allocated.connect(_on_node_allocated)
	Game.leveled_up.connect(_on_level_up)

	# Une oasis de départ autour de la graine.
	ground.paint(Vector2.ZERO, 260.0, 1.0)
	flora.spawn_patch(Vector2.ZERO, 200.0, 14, Color("7fd36b"))

	# Reprise de la partie sauvegardée : seulement si l'écran titre l'a demandé (« Continuer »).
	# « Nouvelle partie » repart de zéro, et la première sauvegarde automatique remplace l'ancienne.
	autosave_enabled = not autotest
	var loaded := false
	if not autotest and Flow.continue_requested and not "--new-game" in OS.get_cmdline_user_args():
		loaded = SaveGame.load_into(self)
		if not loaded and SaveGame.last_error != "aucune sauvegarde":
			hud.banner("Sauvegarde illisible (%s) : nouvelle partie." % SaveGame.last_error)
	if not loaded:
		Game.reset()
	else:
		hud.banner("Partie reprise : niveau %d" % Game.level)
		player.reset_physics_interpolation()
		cam.reset_smoothing()
	Flow.continue_requested = false
	Game.tree_changed.connect(request_autosave)
	if autotest_boss:
		arena.autotest_begin()


## Demande une sauvegarde automatique, regroupée sur une seconde (fonctionne aussi en pause).
func request_autosave() -> void:
	if not autosave_enabled or autosave_pending:
		return
	autosave_pending = true
	await get_tree().create_timer(1.0, true).timeout
	autosave_pending = false
	if is_inside_tree():
		save_game()


func save_game() -> void:
	autosave_timer = AUTOSAVE_EVERY
	if autosave_enabled:
		SaveGame.save_now(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


## Quitter la scène (« Retour au titre » ou « Quitter » du menu pause) sauvegarde la partie.
func _exit_tree() -> void:
	Sfx.listener = null
	save_game()


func _setup_input() -> void:
	_keys("move_up", [KEY_W, KEY_UP])
	_keys("move_down", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_keys("dash", [KEY_SPACE, KEY_SHIFT])
	# Emplacements de la barre de compétences : touches 1 à 6 et A E R, réassignables (settings.gd).
	Settings.apply_bindings()
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


## Mesure du banc de performance : une fois par image affichée.
func _process(delta: float) -> void:
	if benchmark:
		_benchmark_frame(delta)


## Logique de jeu à pas fixe (60 pas par seconde, quelle que soit la machine).
## Le joueur, les Flétris, les graines, les essences et les nuages avancent aussi dans
## leur _physics_process ; l'affichage est interpolé entre deux pas (project.godot).
func _physics_process(delta: float) -> void:
	elapsed += delta
	# La musique suit la vie du sol sous le joueur.
	Music.set_mood(ground.life_at(player.position))
	autosave_timer -= delta
	if autosave_timer <= 0.0:
		save_game()
	if autotest:
		_autotest_step(delta)
	enemies = enemies.filter(func(e): return is_instance_valid(e) and not e.dead)
	if benchmark:
		player.invuln = maxf(player.invuln, 1.0)
		while enemies.size() < BENCH_ENEMIES:
			_spawn_enemy()
	_rebuild_grid()
	_separate()
	_push_out_of_bushes()
	_watch_region_state()

	spawn_timer -= delta * (1.0 + 0.6 * _region_depth(player.position))
	if spawn_paused:
		spawn_timer = maxf(spawn_timer, 0.5)
	var cap := mini(120, 16 + Game.level * 5)
	if spawn_timer <= 0.0:
		spawn_timer = maxf(0.22, 1.3 - Game.level * 0.05 - elapsed / 600.0)
		var burst := 1 + int(Game.level / 4.0)
		for i in burst:
			if enemies.size() < cap:
				_spawn_enemy()


func _rebuild_grid() -> void:
	grid.clear()
	for i in enemies.size():
		var e = enemies[i]
		e.index = i
		grid.insert(e, e.position)


## Flétris vivants dont le corps touche le disque donné (centre, rayon), trouvés par la grille.
## Avec touch_body = false, c'est leur centre qui doit être dans le disque.
func enemies_near(center: Vector2, radius: float, touch_body := true) -> Array:
	var out: Array = []
	# Marge : les Flétris ont pu bouger depuis la reconstruction de la grille.
	for e in grid.query(center, radius + Enemy.MAX_RADIUS + 8.0):
		if is_instance_valid(e) and not e.dead:
			var r: float = radius + (e.radius if touch_body else 0.0)
			if e.radius <= Enemy.MAX_RADIUS and e.position.distance_squared_to(center) < r * r:
				out.append(e)
	for e in big_enemies:
		if is_instance_valid(e) and not e.dead:
			var r: float = radius + (e.radius if touch_body else 0.0)
			if e.position.distance_squared_to(center) < r * r:
				out.append(e)
	return out


## Évite que les Flétris s'empilent en un seul point (voisins trouvés par la grille).
func _separate() -> void:
	for a in enemies:
		for b in grid.query(a.position, a.radius + Enemy.MAX_RADIUS):
			if b.index <= a.index:
				continue
			var d: Vector2 = b.position - a.position
			var min_d: float = a.radius + b.radius
			var l2 := d.length_squared()
			if l2 < min_d * min_d and l2 > 0.01:
				var l := sqrt(l2)
				var push := d / l * (min_d - l) * 0.5
				# Un ennemi ancré (Nid) ne bouge pas : l'autre est poussé deux fois plus.
				if a.anchored:
					b.position += push * (0.0 if b.anchored else 2.0)
				elif b.anchored:
					a.position -= push * 2.0
				else:
					a.position -= push
					b.position += push


## Les buissons d'épines du roncier sont des obstacles pour le joueur et les ennemis.
func _push_out_of_bushes() -> void:
	for e in enemies:
		if not e.anchored:
			e.position = flora.push_out(e.position, e.radius)
	player.position = flora.push_out(player.position, player.radius)


## Suit les drapeaux d'aventure posés par le Cœur de flétrissure (tâche D) : la région change d'état.
func _watch_region_state() -> void:
	var purified := bool(Game.flags.get("ronce_coeur_purifie", false))
	if purified != ronce_purified:
		ronce_purified = purified
		ground.set_purified(1.0 if purified else 0.0)


# --- Régions du monde (voir regions.gd) ---

## Région du monde à cette position : "ronce" dans le roncier, "" ailleurs.
func region_at(pos: Vector2) -> String:
	return Regions.region_at(pos)


## Centre d'une région (là où se dresse son Cœur de flétrissure).
func region_center(id: String) -> Vector2:
	return Regions.center(id)


## Profondeur dans une région, de 0 (au bord, près de la graine) à 1 (au fond).
func _region_depth(pos: Vector2) -> float:
	var reg := region_at(pos)
	if reg == "" or not region_spawn.has(reg):
		return 0.0
	return clampf((pos.length() - Regions.INNER) / (float(region_spawn[reg].get("far", 2400.0)) - Regions.INNER), 0.0, 1.0)


## Facteur des dégâts d'une branche de l'arbre sur un ennemi : les ennemis du roncier
## ignorent 25 % des dégâts de Ronce (« resist » dans enemies.json), ce qui pousse à mélanger
## les branches. Sans branche (""), ou pour un ennemi sans résistances, le facteur vaut 1.
func branch_factor(e, branch: String) -> float:
	if branch == "" or not ("resist" in e):
		return 1.0
	return 1.0 - float(e.resist.get(branch, 0.0))


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
	var e = spawn_enemy_kind(_pick_kind(pos), pos, _enemy_power(pos))
	_roll_elite(e, pos)


## Puissance d'un ennemi né ici (threat(pos) de la tâche A quand elle existe).
func _enemy_power(pos: Vector2) -> float:
	return call("threat", pos) if has_method("threat") else power()


## Sorte d'ennemi à faire naître ici : une sorte du roncier, ou un Flétri ordinaire.
func _pick_kind(pos: Vector2):
	var reg := region_at(pos)
	if region_spawn.has(reg):
		var regional := _region_kind(reg, pos)
		if regional != "":
			return regional
	return _ordinary_kind()


## Flétri ordinaire tiré selon les poids de « ordinary », parmi les sortes permises à ce niveau
## et pas déjà trop nombreuses.
func _ordinary_kind() -> String:
	var kinds: Dictionary = ordinary_spawn.get("kinds", {"fletri": 1.0})
	var min_level: Dictionary = ordinary_spawn.get("min_level", {})
	var max_alive: Dictionary = ordinary_spawn.get("max_alive", {})
	var allowed := {}
	var total := 0.0
	for k in kinds:
		if Game.level < int(min_level.get(k, 1)):
			continue
		if max_alive.has(k) and enemies.filter(func(e): return e.get("kind_id") == k).size() >= int(max_alive[k]):
			continue
		allowed[k] = float(kinds[k])
		total += float(kinds[k])
	var pick := rng.randf() * total
	for k in allowed:
		pick -= allowed[k]
		if pick <= 0.0:
			return k
	return "fletri"


## Tirage d'une élite : rare près de la graine, un peu moins au fond d'une région ; au plus
## « max_alive » en même temps. Réglages : section « elites » de enemies.json.
func _roll_elite(e, pos: Vector2) -> void:
	var cfg: Dictionary = Enemy.ELITES
	if cfg.is_empty() or Game.level < int(cfg.get("min_level", 1)) or not e.can_be_elite():
		return
	var chance := lerpf(float(cfg.get("chance", 0.01)), float(cfg.get("chance_far", 0.03)), _region_depth(pos))
	if rng.randf() >= chance:
		return
	if enemies.filter(func(x): return x.get("elite") == true).size() >= int(cfg.get("max_alive", 2)):
		return
	make_elite(e, rng.randf() < float(cfg.get("two_affixes", 0.0)) and Game.level >= int(cfg.get("two_affixes_level", 1)))


## Fait d'un ennemi une élite à un ou deux modificateurs tirés selon leurs poids.
func make_elite(e, two := false) -> void:
	var pool: Array = e.allowed_affixes()
	var picked: Array = []
	for n in (2 if two else 1):
		var total := 0.0
		for a in pool:
			total += float(Enemy.ELITES["affixes"][a].get("weight", 1.0))
		var pick := rng.randf() * total
		for a in pool:
			pick -= float(Enemy.ELITES["affixes"][a].get("weight", 1.0))
			if pick <= 0.0:
				picked.append(a)
				pool.erase(a)
				break
	e.make_elite(picked)


## Sorte du roncier à faire naître ici, ou "" pour un Flétri ordinaire. La part des ennemis de la
## région grandit avec la distance à la graine, et baisse une fois son Cœur purifié.
func _region_kind(reg: String, pos: Vector2) -> String:
	var sp: Dictionary = region_spawn[reg]
	var share := lerpf(sp.get("share_near", 0.25), sp.get("share_far", 0.8), _region_depth(pos))
	if Game.flags.get(reg + "_coeur_purifie", false):
		share *= float(sp.get("purified_factor", 1.0))
	if rng.randf() >= share:
		return ""
	var kinds: Dictionary = sp.get("kinds", {})
	var total := 0.0
	for k in kinds:
		total += float(kinds[k])
	var pick := rng.randf() * total
	var id := ""
	for k in kinds:
		id = k
		pick -= float(kinds[k])
		if pick <= 0.0:
			break
	if Enemy.KINDS[Enemy.kind_index(id)].get("behavior", "") == "nest":
		var nests := enemies.filter(func(e): return e.behavior == "nest").size()
		if pos.length() < float(sp.get("nest_min_dist", 0.0)) or nests >= int(sp.get("max_nests", 3)):
			id = "chargeur" if rng.randf() < 0.5 else "tireur"
	return id


## Fait naître un ennemi d'une sorte donnée (indice ou identifiant de enemies.json).
## « parent » : le Nid qui l'a fait naître (il compte ses petits).
func spawn_enemy_kind(kind, pos: Vector2, pwr: float, parent = null):
	var e = Enemy.new()
	e.main = self
	e.position = pos
	e.setup(kind, pwr)
	enemies_layer.add_child(e)
	enemies.append(e)
	if parent != null:
		parent.young.append(e)
	return e


## Fait naître un Flétri d'un type donné à un endroit précis (vagues du Cœur, petits du boss).
func spawn_enemy_at(pos: Vector2, kind: int):
	var e = Enemy.new()
	e.main = self
	e.position = pos
	e.setup(kind, power())
	enemies_layer.add_child(e)
	enemies.append(e)
	return e


func spawn_projectile(pos: Vector2, vel: Vector2, damage: float, pierce: int, size := 1.0):
	var p = Projectile.new()
	p.main = self
	p.position = pos
	p.vel = vel
	p.damage = damage
	p.pierce = pierce
	p.radius *= size
	projectiles_layer.add_child(p)
	return p


## Applique un coup du joueur : critique, poison, vol de vie, effets déclenchés par un critique.
## « branch » : branche de l'arbre d'où vient le coup (« ronce » pour les épines, la Couronne
## d'épines et les compétences de Ronce), pour les résistances des ennemis de région.
func player_hit_enemy(e, base: float, can_explode := true, branch := "") -> void:
	var s: Dictionary = Game.stats
	var dmg := base * branch_factor(e, branch)
	var crit: bool = rng.randf() < s["crit"]
	if crit:
		dmg *= s["crit_mult"]
	e.take_damage(dmg, crit)
	Sfx.play("critique" if crit else "impact", e.position)
	if s["poison"] > 0.0:
		e.apply_poison(dmg * s["poison"], 3.0)
	if s["bleed"] > 0.0 and not e.dead:
		e.apply_status("saignement", dmg * s["bleed"], BLEED_BASE_DURATION * s["bleed_duration"])
	if s["lifesteal"] > 0.0:
		player.heal(dmg * s["lifesteal"])
	if crit and can_explode:
		Game.fire("crit", enemy_ctx(e, base))


## Contexte d'un évènement qui vise un ennemi, avec les états des conditions « cible_… ».
func enemy_ctx(e, base: float) -> Dictionary:
	# La Mère-Ronce garde ses états dans « statuses » plutôt que dans bleed_stacks / root_time.
	var bleeding := 0.0
	var rooted := 0.0
	if "bleed_stacks" in e:
		bleeding = float(e.bleed_stacks.size())
		rooted = e.root_time
	elif "statuses" in e:
		bleeding = float(e.statuses.get("saignement", {}).get("stacks", 0))
		rooted = float(e.statuses.get("enracine", {}).get("time", 0.0))
	return {
		"main": self, "enemy": e, "base": base,
		"cible_empoisonnee": e.poison_time,
		"cible_saignante": bleeding,
		"cible_enracinee": rooted,
	}


## Un coup au corps à corps (fouet) a touché un ennemi.
func on_melee_hit(e, base: float) -> void:
	Game.fire("melee_hit", enemy_ctx(e, base))


## À-coup de saignement sur un ennemi (appelé par enemy.gd).
func on_bleed_tick(e, amount: float) -> void:
	Game.fire("bleed_tick", enemy_ctx(e, amount))


## Un ennemi vient d'être enraciné (appelé par enemy.gd).
func on_enemy_rooted(e) -> void:
	Game.fire("root", enemy_ctx(e, root_hit_base))


func damage_area(center: Vector2, radius: float, amount: float, knockback: float, branch := "") -> void:
	for e in enemies_near(center, radius):
		if e.dead:
			continue
		var d: Vector2 = e.position - center
		player_hit_enemy(e, amount, true, branch)
		if knockback > 0.0 and d.length() > 0.1 and not e.anchored:
			e.position += d.normalized() * knockback


func on_enemy_killed(e) -> void:
	Game.kills += 1
	Sfx.play("mort", e.position)
	# Une élite laisse une gerbe d'essences, et parfois une greffe (tâche B).
	var is_elite: bool = e.get("elite") == true
	var n_orbs := 6 if is_elite else 1
	for i in n_orbs:
		var o = Orb.new()
		o.main = self
		o.position = e.position + (Vector2.from_angle(TAU * i / n_orbs) * 22.0 if n_orbs > 1 else Vector2.ZERO)
		o.value = e.xp_value / n_orbs
		orbs_layer.call_deferred("add_child", o)
	if is_elite:
		_on_elite_killed(e)
	# Chaque Flétri purifié rend un peu de vie au sol.
	ground.paint(e.position, 46.0 + e.radius, 0.3)
	if rng.randf() < 0.6:
		flora.add_flower(e.position + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14)))
	fx.ring(e.position, e.radius, e.radius * 2.5, 0.35, Color(0.85, 0.95, 0.75, 0.8), 3.0)
	fx.death(e.position, e.radius, e.color, ground.life_at(e.position) > 0.45)
	Game.fire("kill", enemy_ctx(e, 0.0))


func _on_elite_killed(e) -> void:
	fx.ring(e.position, e.radius, e.radius * 4.0, 0.6, Color("f2c75a"), 5.0)
	fx.text(e.position + Vector2(0, -e.radius - 30), e.elite_name + " vaincu", Color("f2c75a"), 18, 1.6)
	if rng.randf() < float(Enemy.ELITES.get("graft_chance", 0.0)) and has_method("drop_graft") and Game.has_method("roll_graft"):
		var id: String = Game.call("roll_graft", "elite")
		if id != "":
			call("drop_graft", e.position, id)
	elite_killed.emit(e)


func player_died() -> void:
	deaths += 1
	# Robot d'équilibrage : la mort est seulement comptée, le joueur repart sur place avec toute
	# sa vie. Sinon chaque mort vide l'écran et offre des ennemis frais et faciles, et le build
	# qui meurt le plus semble le plus fort.
	if build_bot != null:
		player.hp = Game.stats["max_hp"]
		player.invuln = 1.0
		return
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for p in projectiles_layer.get_children():
		p.queue_free()
	Game.xp = 0.0
	player.respawn()
	player.reset_physics_interpolation()
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
	revive(world_pos, radius, Game.tree.branch_color(node["branch"]))


## Vague de vie : l'herbe avance depuis le point ravivé (ground.WAVE_TIME secondes),
## les arbres et ronces reverdissent et les fleurs éclosent au passage du front.
func revive(world_pos: Vector2, radius: float, tint: Color, strength := 0.9) -> void:
	ground.paint_wave(world_pos, radius, strength)
	flora.spawn_patch(world_pos, radius * 0.8, int(radius / 18.0), tint, ground.WAVE_TIME, radius)


func _on_level_up(lvl: int) -> void:
	fx.ring(player.position, 20.0, 160.0, 0.6, Color("f0e6b4"), 5.0)
	hud.banner("Niveau %d : un point à placer dans l'Arbre de vie (Tab)" % lvl)
	request_autosave()
	player.heal(Game.stats["max_hp"] * 0.25)


# --- Mode de test automatique ---

## Commandes du robot : tourne autour de la graine en visant le Flétri le plus proche.
func bot_input(p) -> Dictionary:
	if autotest_boss:
		return arena.bot_input(p)
	var target: Vector2 = p.position + Vector2.RIGHT * 100.0
	var best := INF
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			var d: float = e.position.distance_squared_to(p.position)
			if d < best:
				best = d
				target = e.position
	if build_bot != null:
		var styled: Dictionary = build_bot.steer(p, target, best, Game.stats["max_hp"])
		if not styled.is_empty():
			return styled
	var orbit := Vector2.from_angle(elapsed * 0.35) * minf(900.0, 200.0 + elapsed * 20.0)
	var mv: Vector2 = orbit - p.position
	mv = mv.normalized() if mv.length() > 40.0 else Vector2.ZERO
	return {"move": mv, "aim": target, "dash": best < 50.0 * 50.0}


func _autotest_step(delta: float) -> void:
	if autotest_boss:
		arena.autotest_step(delta)
		return
	autotest_time += delta
	if build_bot != null:
		# Niveau figé : tous les builds se mesurent avec les mêmes points et la même difficulté.
		Game.xp = 0.0
		build_bot.spend(Game)
		if autotest_time >= build_bot.duration and not autotest_done:
			autotest_done = true
			print(build_bot.report(Game, autotest_time, deaths))
			get_tree().quit()
		return
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
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://autotest/%s.png" % shot_name)
	print("AUTOTEST capture %s  niveau=%d  noeuds=%d  ennemis=%d  monde=%.1f%%  vie=%d  fps=%d" % [shot_name, Game.level, Game.allocated.size(), enemies.size(), minf(100.0, ground.ratio() / 0.67 * 100.0), int(player.hp), Engine.get_frames_per_second()])


func _finish_autotest() -> void:
	pause_menu.open()
	await get_tree().create_timer(0.4).timeout
	await _capture("pause")
	pause_menu.close()
	tree_ui.toggle()
	await get_tree().create_timer(0.5).timeout
	await _capture("tree")
	print("AUTOTEST fini : tués=%d" % Game.kills)
	get_tree().quit()


# --- Banc de performance ---

## Appelé à chaque image : mesure le temps écoulé depuis l'image précédente. À chaque pas de jeu,
## _physics_process garde 120 Flétris en jeu et rend le joueur invulnérable (pas de mort qui viderait l'écran).
func _benchmark_frame(delta: float) -> void:
	var now := Time.get_ticks_usec()
	bench_clock += delta
	if bench_clock > BENCH_WARMUP and bench_last_usec > 0:
		bench_frames.append((now - bench_last_usec) / 1000.0)
		bench_cpu["process"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		bench_cpu["physics"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		bench_cpu["samples"] += 1
	bench_last_usec = now
	if bench_clock >= BENCH_WARMUP + BENCH_TIME:
		_finish_benchmark()


func _finish_benchmark() -> void:
	benchmark = false
	var sorted := bench_frames.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for v in sorted:
		total += v
	var avg := total / maxf(1.0, n)
	var p99: float = sorted[mini(n - 1, int(n * 0.99))] if n > 0 else 0.0
	var worst: float = sorted[n - 1] if n > 0 else 0.0
	var k: float = maxf(1.0, bench_cpu["samples"])
	print("BENCHMARK %d Flétris, %.0f s, %d images" % [BENCH_ENEMIES, BENCH_TIME, n])
	print("BENCHMARK temps par image : moyen %.2f ms (%.1f images/s), 99e centile %.2f ms, pire %.2f ms" % [avg, 1000.0 / maxf(avg, 0.001), p99, worst])
	print("BENCHMARK scripts par image : _process %.2f ms, _physics_process %.2f ms" % [bench_cpu["process"] / k, bench_cpu["physics"] / k])
	print("BENCHMARK partie : niveau %d, tués %d, fleurs %d" % [Game.level, Game.kills, flora.flowers.size()])
	get_tree().quit()
