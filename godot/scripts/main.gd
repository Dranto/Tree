## Scène principale : assemble le monde, le joueur, les Flétris et l'interface.
extends Node2D

const WORLD_HALF := Regions.WORLD_HALF
## Correspondance entre l'arbre de vie et le monde : un nœud ravive la région
## située dans la même direction que lui, à une distance proportionnelle à son anneau.
const TREE_TO_WORLD := 2.1

const Ground = preload("res://scripts/ground.gd")
const WorldEdge = preload("res://scripts/world_edge.gd")
const Flora = preload("res://scripts/flora.gd")
const Fx = preload("res://scripts/fx.gd")
const ScreenFx = preload("res://scripts/screen_fx.gd")
const Ambience = preload("res://scripts/ambience.gd")
const Player = preload("res://scripts/player.gd")
const MoveMarker = preload("res://scripts/move_marker.gd")
const TargetMarker = preload("res://scripts/target_marker.gd")
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
const FinaleArena = preload("res://scripts/finale_arena.gd")
const Regions = preload("res://scripts/regions.gd")
const Content = preload("res://scripts/content.gd")
## Menace des ennemis, apparitions et choix de difficulté : res://data/difficulty.json.
const Difficulty = preload("res://scripts/difficulty.gd")
const QuestUi = preload("res://scripts/quest_ui.gd")
const Sanctuary = preload("res://scripts/sanctuary.gd")
const LostSap = preload("res://scripts/lost_sap.gd")
const Altar = preload("res://scripts/altar.gd")
const GraftPickup = preload("res://scripts/graft_pickup.gd")

## Apparitions par région (sortes du roncier, part selon la distance) : res://data/enemies.json.
var region_spawn: Dictionary = _region_spawns()
## Flétris ordinaires (poids, niveau minimal, nombre maximal en vie) : « ordinary » de enemies.json.
var ordinary_spawn: Dictionary = Content._load("enemies").get("ordinary", {})

## Une élite vient d'être vaincue (contrat partagé : butin, objectif « vaincre trois élites »).
signal elite_killed(enemy)
## Dernier état connu de la purification du Cœur de chaque région (identifiant -> vrai).
var regions_purified := {}
const BuildBot = preload("res://scripts/build_bot.gd")

var world_half := WORLD_HALF
var ground
var world_edge
var flora
var fx
var screen_fx
## Signatures visuelles des attaques du héros (skill_fx.gd).
var skill_fx: SkillFx
## Attaque de base : signatures (fouet, fourche, ricochet…) et zones au sol (ronces vives, traînée),
## voir attack_fx.gd. C'est le nœud du dessus ; son jumeau du sol est sous les acteurs.
var attack_fx: AttackFx
var player
var hud
var tree_ui
var pause_menu
## Objectifs : suivi à l'écran, journal (J), carte (M) et fin de la tranche (quest_ui.gd).
var quest_ui
var orbs_layer: Node2D
## Repère au sol de la destination du clic droit (mode de déplacement « moba »).
var move_marker: Node2D
var target_marker: Node2D
var enemies_layer: Node2D
var projectiles_layer: Node2D
## Calque trié en profondeur (Y-sort) : arbres du décor, Flétris et joueur.
var actors_layer: Node2D
## Flétris rangés par cases, reconstruite à chaque pas de jeu (voir enemies_near).
var grid = SpatialGrid.new()
var enemies: Array = []
## Dégâts du coup de racines en cours (contexte de l'évènement « root »), 0 hors de ce coup.
var root_hit_base := 0.0
## Coup en cours d'une forme ou d'une compétence d'Aube (attack.gd › beam, skills/lance_aube.gd) :
## chance de critique ajoutée, et part de dégâts en plus quand il est critique (« incandescence »).
var hit_crit_bonus := 0.0
var hit_crit_extra := 0.0
## Ennemis trop gros pour la grille spatiale (boss) : testés à part dans enemies_near.
var big_enemies: Array = []
## Cœur de flétrissure et arène de la Mère-Ronce (région de Ronce).
var heart
var arena
## Grand Cœur (celui du centre, au pied de l'arène) et arène de chaque région (identifiant -> nœud),
## dans l'ordre des régions.
var hearts: Dictionary = {}
var arenas: Dictionary = {}
## Tous les Cœurs de chaque région (identifiant -> liste, trois depuis le jalon 10), et tous ensemble.
var region_hearts: Dictionary = {}
var all_hearts: Array = []
## Arène de la finale, sous la graine (finale_arena.gd) : ouverte quand toutes les régions sont purifiées.
var finale
## Sanctuaires (sanctuary.gd), points de renaissance ; et sève perdue au sol (lost_sap.gd, ou null).
var sanctuaries: Array = []
var lost_sap = null
var camera: Camera2D
## Autels et secrets de la région (altar.gd), sous les personnages.
var altars: Array = []
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
## Robot « zone complète » (tests/zone_test.gd, voir zone_bot.gd) : joue la zone jusqu'au boss.
var zone_bot = null
## Sauvegarde à reprendre même en mode robot (tests de reprise) ; vide sinon.
var resume_from := ""
var deaths := 0
## Sauvegarde automatique (désactivée en autotest) : périodique et après chaque changement.
const AUTOSAVE_EVERY := 60.0
var autosave_enabled := true
var autosave_timer := AUTOSAVE_EVERY
var autosave_pending := false
## Banc de performance (« -- --benchmark ») : le robot joue face à 120 Flétris pendant
## bench_time secondes (après BENCH_WARMUP de mise en route), puis le temps par image s'affiche.
## Options (docs/performances.md) : « --bench-time=S » (durée), « --hide=sol,ennemis,... »
## (cache des calques pour mesurer leur coût), « --profile » (temps par script, avec
## tools/perf-profile.sh qui instrumente une copie du projet).
const BENCH_ENEMIES := 120
const BENCH_WARMUP := 3.0
var bench_time := 30.0
var benchmark := false
## Scène du banc (« --bench-scene=coeur » ou « boss », vide : 120 Flétris). « coeur » : le siège
## du Cœur avec ses vagues jusqu'à la purification ; « boss » : le combat de la Mère-Ronce, du
## début à la victoire. Le héros a le build du robot du boss (niveau 12, points dans Ronce).
var bench_scene := ""
var bench_clock := 0.0
var bench_last_usec := 0
var bench_frames: PackedFloat32Array = PackedFloat32Array()
var bench_cpu := {"process": 0.0, "physics": 0.0, "samples": 0}
## Temps de chaque image découpé : scripts et dessins (de process_frame à frame_pre_draw), puis
## rendu (de frame_pre_draw à frame_post_draw), en microsecondes cumulées.
var bench_seg := {"script": 0, "render": 0, "n": 0}
var _seg_start := 0
var _seg_pre := 0


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
		_benchmark_setup()
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
	# Le décor du bord du monde, juste au-dessus du sol (voir world_edge.gd).
	world_edge = WorldEdge.new()
	world_edge.main = self
	add_child(world_edge)
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
	# Signatures des attaques du héros : une moitié sous les acteurs, l'autre au-dessus des projectiles.
	var sfx_pair := SkillFx.make_pair()
	add_child(sfx_pair[0])
	skill_fx = sfx_pair[1]
	var afx_pair := AttackFx.make_pair(self)
	add_child(afx_pair[0])
	attack_fx = afx_pair[1]
	# Repère de destination du déplacement au clic droit (mode « moba »), sous les acteurs.
	move_marker = MoveMarker.new()
	move_marker.main = self
	add_child(move_marker)
	# Cible de l'attaque automatique et portée, sous les acteurs.
	target_marker = TargetMarker.new()
	target_marker.main = self
	add_child(target_marker)
	add_child(actors_layer)
	enemies_layer = Node2D.new()
	enemies_layer.y_sort_enabled = true
	actors_layer.add_child(enemies_layer)
	player = Player.new()
	player.main = self
	actors_layer.add_child(player)
	projectiles_layer = Node2D.new()
	add_child(projectiles_layer)
	add_child(skill_fx)
	add_child(attack_fx)
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
	camera = cam

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
		hud_layer.visible = not open
		# Transition : l'écran s'ouvre depuis un voile sombre, à l'ouverture comme à la fermeture.
		screen_fx.fade(Art.c("decor"), 0.7, 0.0, ScreenFx.FADE_PANEL))

	# Effets d'écran (vignette de dégâts, transitions) : au-dessus de l'arbre, sous le menu pause.
	screen_fx = ScreenFx.new()
	screen_fx.main = self
	add_child(screen_fx)

	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 20
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	pause_menu = PauseMenu.new()
	pause_menu.main = self
	pause_layer.add_child(pause_menu)

	# Les Cœurs et l'arène de chaque région (data/regions/<id>.json) : leurs marques au sol se
	# dessinent sous les personnages. heart et arena restent ceux de la région suivie (la première).
	for id in Regions.ids():
		var list: Array = []
		var h = null
		for i in Regions.heart_count(id):
			var hi = Heart.new()
			hi.main = self
			hi.region = id
			hi.index = i
			list.append(hi)
			all_hearts.append(hi)
			add_child(hi)
			move_child(hi, actors_layer.get_index())
		for hi in list:
			if h == null or hi.great:
				h = hi
		var a = BossArena.new()
		a.main = self
		a.heart = h
		a.region = id
		hearts[id] = h
		region_hearts[id] = list
		arenas[id] = a
		add_child(a)
		move_child(a, actors_layer.get_index())
		if heart == null or id == focus_region():
			heart = h
			arena = a
	# La finale, sous la graine (hors du carré du monde, voir finale_arena.gd). Le robot des boss la
	# joue avec « -- --autotest=boss --region=finale ».
	finale = FinaleArena.new()
	finale.main = self
	add_child(finale)
	move_child(finale, actors_layer.get_index())
	if focus_region() == "finale":
		arena = finale
	_place_sanctuaries()
	var rewards_layer := Node2D.new()
	add_child(rewards_layer)
	move_child(rewards_layer, actors_layer.get_index())
	altars = Altar.spawn_all(self, rewards_layer)

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
	if resume_from != "":
		loaded = SaveGame.load_into(self, resume_from)
	elif not autotest and Flow.continue_requested and not "--new-game" in OS.get_cmdline_user_args():
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
	# Après la reprise de la partie : le premier contrôle des objectifs rattrape l'état sans annonce.
	quest_ui = QuestUi.new()
	quest_ui.main = self
	add_child(quest_ui)
	Game.tree_changed.connect(request_autosave)
	if autotest_boss:
		arena.autotest_begin()
	_set_direct_to_screen(get_tree().current_scene == self and (benchmark or "--rendu-direct" in OS.get_cmdline_user_args()))
	# En jeu et dans le banc, les carrés de sol salis sont refaits peu à peu (pas pendant une capture).
	if get_tree().current_scene == self and (not autotest or benchmark):
		ground.tile_budget = ground.TILE_BUDGET
	if benchmark and bench_scene == "coeur":
		_bench_coeur_begin()
	if benchmark:
		_benchmark_hide({"sol": ground, "decor": trees_layer, "fleurs": flora, "ennemis": enemies_layer,
			"joueur": player, "acteurs": actors_layer, "effets": fx, "ambiance": ambience, "hud": hud_layer, "monde": self})


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
	_set_direct_to_screen(false)
	save_game()


func _setup_input() -> void:
	_keys("move_up", [KEY_W, KEY_UP])
	_keys("move_down", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	# Esquive et barre de compétences (clics gauche et droit, A E R F et 1 à 4, réassignables) :
	# settings.gd, qui les adapte au mode de déplacement. L'attaque de base part toute seule.
	Settings.apply_bindings()
	_keys("toggle_tree", [KEY_TAB, KEY_T])


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
	_death_fx_step()
	elapsed += delta
	# La musique suit la vie du sol sous le joueur ; sous la graine, celle de la finale
	# (data/audio.json › regions › finale, la musique du monde tant qu'elle n'est pas écrite).
	var under := underground()
	if under:
		Music.set_mood(finale.music_life(), "finale")
	else:
		Music.set_mood(ground.life_at(player.position), Regions.region_at(player.position))
	autosave_timer -= delta
	if autosave_timer <= 0.0:
		save_game()
	if autotest:
		_autotest_step(delta)
	enemies = enemies.filter(func(e): return is_instance_valid(e) and not e.dead)
	if benchmark:
		player.invuln = maxf(player.invuln, 1.0)
		while bench_scene == "" and enemies.size() < BENCH_ENEMIES:
			_spawn_enemy()
	_rebuild_grid()
	_separate()
	_push_out_of_bushes()
	_watch_region_state()
	_sync_lost_sap()

	# Apparitions : plus nombreuses et plus serrées au fond du roncier, calmes près de la graine.
	# Elles suivent le niveau et la zone, jamais le temps passé (data/difficulty.json).
	var depth := _region_depth(player.position)
	spawn_timer -= delta * Difficulty.spawn_speedup(depth)
	# Rien ne naît pendant un combat de boss, ni sous la graine.
	if spawn_paused or under:
		spawn_timer = maxf(spawn_timer, 0.5)
	var cap := Difficulty.spawn_cap(Game.level, depth)
	if spawn_timer <= 0.0:
		spawn_timer = Difficulty.spawn_interval(Game.level)
		for i in Difficulty.spawn_burst(Game.level, depth):
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
	# Même calcul, même ordre que de pousser les nœuds un à un, mais sur des tableaux locaux :
	# lire et écrire la position d'un nœud coûte cher, et ce calcul touche des centaines de paires
	# par pas (docs/performances.md). Les positions sont recopiées dans les nœuds à la fin.
	var n := enemies.size()
	var pos := PackedVector2Array()
	var rad := PackedFloat64Array()
	var anchored := PackedByteArray()
	pos.resize(n)
	rad.resize(n)
	anchored.resize(n)
	var cells := {}
	for i in n:
		var e = enemies[i]
		pos[i] = e.position
		rad[i] = e.radius
		anchored[i] = 1 if e.anchored else 0
		var key := Vector2i(floori(pos[i].x / SpatialGrid.CELL), floori(pos[i].y / SpatialGrid.CELL))
		if cells.has(key):
			cells[key].append(i)
		else:
			cells[key] = PackedInt32Array([i])
	var moved := false
	for i in n:
		# Même recherche que grid.query(position, rayon + MAX_RADIUS), avec la position du moment.
		var reach: float = rad[i] + Enemy.MAX_RADIUS
		var c0 := pos[i] - Vector2(reach, reach)
		var c1 := pos[i] + Vector2(reach, reach)
		var lo := Vector2i(floori(c0.x / SpatialGrid.CELL), floori(c0.y / SpatialGrid.CELL))
		var hi := Vector2i(floori(c1.x / SpatialGrid.CELL), floori(c1.y / SpatialGrid.CELL))
		for cy in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var list = cells.get(Vector2i(cx, cy))
				if list == null:
					continue
				for j in list:
					if j <= i:
						continue
					var d: Vector2 = pos[j] - pos[i]
					var min_d: float = rad[i] + rad[j]
					var l2 := d.length_squared()
					if l2 < min_d * min_d and l2 > 0.01:
						var l := sqrt(l2)
						var push := d / l * (min_d - l) * 0.5
						# Un ennemi ancré (Nid) ne bouge pas : l'autre est poussé deux fois plus.
						if anchored[i]:
							pos[j] += push * (0.0 if anchored[j] else 2.0)
						elif anchored[j]:
							pos[i] -= push * 2.0
						else:
							pos[i] -= push
							pos[j] += push
						moved = true
	if moved:
		for i in n:
			if enemies[i].position != pos[i]:
				enemies[i].position = pos[i]


## Les buissons d'épines du roncier sont des obstacles pour le joueur et les ennemis.
func _push_out_of_bushes() -> void:
	for e in enemies:
		if not e.anchored:
			e.position = flora.push_out(e.position, e.radius)
	player.position = flora.push_out(player.position, player.radius)


## Suit les drapeaux d'aventure posés par les Cœurs de flétrissure : la terre de chaque région
## s'apaise d'un cran par Cœur purifié.
func _watch_region_state() -> void:
	for id in Regions.ids():
		var done := Regions.hearts_done(id, Game.flags)
		# Tous les Cœurs purifiés sans le drapeau de la région (drapeaux posés un à un par un test ou
		# une sauvegarde bricolée) : il est posé, l'arène s'ouvre.
		if done >= Regions.heart_count(id) and not Game.flags.get(Regions.heart_flag(id), false):
			Game.flags[Regions.heart_flag(id)] = true
		var k := float(done) / float(maxi(1, Regions.heart_count(id)))
		if k != float(regions_purified.get(id, 0.0)):
			regions_purified[id] = k
			ground.set_purified(id, k)


# --- Régions du monde (voir regions.gd) ---

## Région suivie par les robots et le mode « -- --autotest=boss » : celle de « -- --region=<id> »,
## sinon la première. main.heart et main.arena sont les siens.
static func focus_region() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--region="):
			return arg.substr(9)
	return Regions.ids()[0] if not Regions.ids().is_empty() else ""


## Arène où un combat de boss a lieu (celle d'une région ou la finale), ou null.
func active_arena():
	for a in arenas.values():
		if a.in_combat():
			return a
	if finale != null and finale.in_combat():
		return finale
	return null


## Vrai quand le joueur est sous la graine (arène de la finale, hors du carré du monde).
func underground() -> bool:
	return finale != null and player != null and finale.holds(player.position)


## Borne une position au monde carré (± world_half) ; sous la graine, l'arène de la finale la tient.
func clamp_to_world(pos: Vector2) -> Vector2:
	if finale != null and finale.holds(pos):
		return pos
	return pos.clamp(Vector2(-world_half, -world_half), Vector2(world_half, world_half))


## Position à montrer sur la carte du monde : sous la graine, la brèche à son pied.
func map_position(pos: Vector2) -> Vector2:
	return finale.descent_point() if finale != null and finale.holds(pos) else pos


## Vrai pendant un combat de boss, dans n'importe quelle région.
func in_boss_fight() -> bool:
	return active_arena() != null


## Cœur assiégé en ce moment, ou null.
func siege_heart():
	for h in all_hearts:
		if h.state == "siege":
			return h
	return null


## Cœur de la région à purifier le plus proche de « from » (le Grand Cœur quand tous le sont), ou null.
func next_heart(region: String, from: Vector2):
	var best = null
	var best_d := INF
	for h in region_hearts.get(region, []):
		if h.state == "purifie" or h.flag_set():
			continue
		var d: float = h.center.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = h
	return best if best != null else hearts.get(region)


## Apparitions de chaque région (« spawn » de data/regions/<id>.json).
static func _region_spawns() -> Dictionary:
	var out := {}
	for id in Regions.ids():
		var sp := Regions.section(id, "spawn")
		if not sp.is_empty():
			out[id] = sp
	return out


## Région du monde à cette position : son identifiant ("ronce" dans le roncier), "" ailleurs.
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


## Menace d'un ennemi né à cet endroit : niveau du joueur, profondeur dans la région et Cœurs
## de flétrissure purifiés (voir difficulty.gd). Sans position : là où se tient le joueur.
func threat(pos = null) -> float:
	var at: Vector2 = player.position if pos == null else pos
	return Difficulty.threat(Game.level, _region_depth(at), hearts_purified())


## Ancien nom de threat(), gardé le temps du jalon 4 : menace là où se tient le joueur.
func power() -> float:
	return threat()


## Nombre de régions dont tous les Cœurs de flétrissure sont purifiés (la menace en tient compte).
func hearts_purified() -> int:
	var n := 0
	for id in Regions.ids():
		if Game.flags.get(Regions.heart_flag(id), false):
			n += 1
	return n


func _spawn_enemy() -> void:
	var pos := Vector2.ZERO
	# La vie repousse les Flétris : on évite de les faire naître en terre ravivée.
	for attempt in 4:
		var a := rng.randf() * TAU
		pos = player.position + Vector2.from_angle(a) * rng.randf_range(760.0, 980.0)
		pos = pos.clamp(Vector2(-WORLD_HALF, -WORLD_HALF), Vector2(WORLD_HALF, WORLD_HALF))
		if ground.life_at(pos) < 0.5:
			break
	var e = spawn_enemy_kind(_pick_kind(pos), pos, threat(pos))
	_roll_elite(e, pos)


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
## « max_alive » en même temps. Réglages : section « elites » de difficulty.json.
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
	if Game.flags.get(Regions.heart_flag(reg), false):
		share *= float(sp.get("purified_factor", 1.0))
	if rng.randf() >= share:
		return ""
	# Les colosses d'une région (« min_dist ») vivent loin de la graine : près d'elle, on tire parmi
	# les autres sortes. Sans ce garde, un héros de niveau 3 qui part vers une région voisine de
	# celles de Sève et d'Aube tombait sur des Souches, des Quartz et des Menhirs à 150-170 PV.
	var min_dist: Dictionary = sp.get("min_dist", {})
	var kinds := {}
	var total := 0.0
	for k in sp.get("kinds", {}):
		if pos.length() >= float(min_dist.get(k, 0.0)):
			kinds[k] = float(sp["kinds"][k])
			total += kinds[k]
	var pick := rng.randf() * total
	var id := ""
	for k in kinds:
		id = k
		pick -= kinds[k]
		if pick <= 0.0:
			break
	if id == "":
		return ""
	if Enemy.KINDS[Enemy.kind_index(id)].get("behavior", "") == "nest":
		var nests := enemies.filter(func(e): return e.behavior == "nest").size()
		if pos.length() < float(sp.get("nest_min_dist", 0.0)) or nests >= int(sp.get("max_nests", 3)):
			# Trop près de la graine ou trop de nids : une des deux sortes de repli, à pile ou face.
			var fallback: Array = sp.get("nest_fallback", ["chargeur", "tireur"])
			id = fallback[0] if rng.randf() < 0.5 else fallback[1]
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
	e.setup(kind, threat(pos))
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
	# Un ennemi ébloui (Aube) est plus souvent frappé en critique.
	var crit: bool = rng.randf() < s["crit"] + hit_crit_bonus + dazzle_of(e)
	if crit:
		dmg *= s["crit_mult"] * (1.0 + hit_crit_extra)
	# Les étincelles du coup prennent la couleur de son élément (charte) : racines, épines de Ronce, lumière d'Aube.
	fx.hit_element = "racine" if root_hit_base > 0.0 or branch == "racine" else ("epine" if branch == "ronce" else ("lumiere" if branch == "aube" else ""))
	e.take_damage(dmg, crit)
	fx.hit_element = ""
	Sfx.play(enemy_sound(e, "sound_crit" if crit else "sound_hit", "critique" if crit else "impact"), e.position)
	if s["poison"] > 0.0:
		e.apply_poison(dmg * s["poison"], 3.0)
	if s["bleed"] > 0.0 and not e.dead:
		e.apply_status("saignement", dmg * s["bleed"], BLEED_BASE_DURATION * s["bleed_duration"])
	if s["lifesteal"] > 0.0:
		player.heal(dmg * s["lifesteal"])
	if crit and can_explode:
		Game.fire("crit", enemy_ctx(e, base))


## Chance de critique en plus contre un ennemi ébloui (état « ebloui » d'Aube), 0 sinon.
func dazzle_of(e) -> float:
	if "dazzle_time" in e:
		return e.dazzle_value if e.dazzle_time > 0.0 else 0.0
	if "statuses" in e:
		return float(e.statuses.get("ebloui", {}).get("value", 0.0))
	return 0.0


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
		"cible_eblouie": 1.0 if dazzle_of(e) > 0.0 else 0.0,
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


## Son d'un ennemi : celui de sa sorte dans enemies.json (« sound_hit », « sound_crit », « sound_death »),
## à défaut « fallback ». Les boss n'ont pas de sorte : leur son vient de leur script.
func enemy_sound(e, key: String, fallback: String) -> String:
	var k = e.get("kind")
	if k is int and k >= 0 and k < Enemy.KINDS.size():
		return str(Enemy.KINDS[k].get(key, fallback))
	return fallback


func on_enemy_killed(e) -> void:
	Game.kills += 1
	Sfx.play(enemy_sound(e, "sound_death", "mort"), e.position)
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
	# Chaque Flétri purifié rend un peu de vie au sol. Les tirages se font tout de suite (même
	# suite de hasard), les effets peuvent attendre quelques pas lors d'une mort en série.
	var pos: Vector2 = e.position
	var r: float = e.radius
	var col: Color = e.color
	var flower := Vector2.INF
	if rng.randf() < 0.6:
		flower = pos + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14))
	# La vie rendue au sol reste immédiate : le sol regroupe les retouches d'une même image en un
	# seul nouveau rendu de ses carrés (ground.gd), les étaler en ferait plusieurs.
	ground.paint(pos, 46.0 + r, 0.3)
	death_fx(func():
		if flower != Vector2.INF:
			flora.add_flower(flower)
		fx.ring(pos, r, r * 2.5, 0.35, Color(0.85, 0.95, 0.75, 0.8), 3.0)
		fx.death(pos, r, col, ground.life_at(pos) > 0.45))
	Game.fire("kill", enemy_ctx(e, 0.0))


## Effets d'une mort (fleur, anneau, éclats, restes) : tout de suite, sauf lors d'une
## mort en série (purification du Cœur, grande attaque) où ils sont étalés sur les pas suivants,
## DEATH_FX_PER_STEP au plus par pas de jeu. Sans cela, 40 morts d'un coup faisaient une image
## de plus de 100 ms (docs/performances.md).
const DEATH_FX_PER_STEP := 6
var _death_fx_left := DEATH_FX_PER_STEP
var _death_fx_queue: Array[Callable] = []

func death_fx(c: Callable) -> void:
	if _death_fx_left > 0 and _death_fx_queue.is_empty():
		_death_fx_left -= 1
		c.call()
	else:
		_death_fx_queue.append(c)


func _death_fx_step() -> void:
	_death_fx_left = DEATH_FX_PER_STEP
	while _death_fx_left > 0 and not _death_fx_queue.is_empty():
		_death_fx_left -= 1
		_death_fx_queue.pop_front().call()


## Fait tomber une greffe au sol, à ramasser (contrat de la tâche B). id vide : une greffe tirée
## parmi celles des élites (Game.roll_graft("elite")). Ne fait rien (renvoie null) s'il n'y a rien
## à donner, ou si la greffe est déjà possédée ou déjà au sol.
func drop_graft(pos: Vector2, id := ""):
	if id == "":
		id = Game.roll_graft("elite")
	if id == "" or Game.has_graft(id) or not Content.grafts().has(id):
		return null
	for g in orbs_layer.get_children():
		if g is GraftPickup and g.graft_id == id and not g.is_queued_for_deletion():
			return null
	var g = GraftPickup.new()
	g.main = self
	g.graft_id = id
	g.position = pos
	Game.grafts_on_ground[id] = true
	orbs_layer.call_deferred("add_child", g)
	return g


## Greffes au sol pas encore ramassées, pour la sauvegarde : [[x, y, greffe], …].
func export_ground_grafts() -> Array:
	var out: Array = []
	for g in orbs_layer.get_children():
		if g is GraftPickup and not g.is_queued_for_deletion():
			out.append([g.position.x, g.position.y, g.graft_id])
	return out


func import_ground_grafts(list: Array) -> void:
	for g in orbs_layer.get_children():
		if g is GraftPickup:
			g.queue_free()
	for item in list:
		if item is Array and item.size() >= 3:
			var g = drop_graft(Vector2(float(item[0]), float(item[1])), str(item[2]))
			if g != null:
				g.pop = 0.0


func _on_elite_killed(e) -> void:
	fx.ring(e.position, e.radius, e.radius * 4.0, 0.6, Color("f2c75a"), 5.0)
	fx.text(e.position + Vector2(0, -e.radius - 30), e.elite_name + " vaincu", Color("f2c75a"), 18, 1.6)
	if rng.randf() < float(Enemy.ELITES.get("graft_chance", 0.0)):
		drop_graft(e.position)
	elite_killed.emit(e)


func player_died() -> void:
	deaths += 1
	if Objectives.main == self:
		Objectives.note_death()
	# Robot d'équilibrage : la mort est seulement comptée, le joueur repart sur place avec toute
	# sa vie. Sinon chaque mort vide l'écran et offre des ennemis frais et faciles, et le build
	# qui meurt le plus semble le plus fort.
	if build_bot != null:
		player.hp = Game.stats["max_hp"]
		player.invuln = 1.0
		return
	# Un combat en cours se remet à zéro : siège du Cœur à recommencer, Mère-Ronce rendormie
	# (elle disparaît avec les autres ennemis, voir boss_arena._fight_lost).
	var reset := ""
	var fight = active_arena()
	if fight != null:
		reset = "boss"
	else:
		for h in all_hearts:
			if h.reset_siege():
				reset = "coeur"
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for p in projectiles_layer.get_children():
		p.queue_free()
	# L'expérience non dépensée reste au sol ; celle d'une mort précédente, pas reprise, est perdue.
	# Les points et les nœuds de l'arbre ne sont jamais perdus.
	var lost := float(Game.flags.get("seve_perdue", 0.0))
	var dropped := Game.xp
	Game.xp = 0.0
	# Tombé face à la Mère-Ronce : la sève attend devant l'arène, pour la reprendre sans relancer
	# le combat. Ailleurs, là où le joueur est tombé.
	var sap_at: Vector2 = fight.entrance() if reset == "boss" else player.position
	if dropped > 0.0:
		Game.flags["seve_perdue"] = dropped
		Game.flags["seve_perdue_x"] = sap_at.x
		Game.flags["seve_perdue_y"] = sap_at.y
	else:
		_clear_lost_sap_flags()
	_sync_lost_sap()
	var spot = current_sanctuary()
	player.respawn(respawn_point())
	player.reset_physics_interpolation()
	camera.reset_smoothing()
	if spot != null:
		spot.inside = true   # déjà dans le cercle : pas de second message « tu renaîtras ici »
	Sfx.play("chute")
	# Mort puis renaissance : l'écran tombe dans le noir rougeâtre et remonte, la sève jaillit au sanctuaire.
	screen_fx.fade(Art.c("decor").darkened(0.5), 1.0, 0.0, ScreenFx.FADE_DEATH)
	fx.ring(player.position, 16.0, 150.0, 0.9, Art.ec("seve"), 5.0)
	fx.pickup(player.position, "seve", 10)
	hud.show_death({"place": spot.place if spot != null else "de la Graine", "dropped": dropped, "lost": lost, "reset": reset})
	# Les annonces de l'endroit où il est tombé n'ont plus lieu d'être.
	hud.drop_combat_banners()
	request_autosave()


# --- Sanctuaires et sève perdue ---

## Pose les sanctuaires (la Graine et ceux des régions), écartés des buissons d'épines (la graine
## reste au centre).
func _place_sanctuaries() -> void:
	for site in Sanctuary.sites():
		var s = Sanctuary.new()
		s.main = self
		s.setup(site)
		var pos: Vector2 = Sanctuary.site_position(site)
		if pos != Vector2.ZERO:
			for i in 6:
				pos = flora.push_out(pos, Sanctuary.RADIUS + 10.0)
		s.position = pos
		s.frozen = build_bot != null or benchmark
		add_child(s)
		move_child(s, actors_layer.get_index())
		sanctuaries.append(s)


## Sanctuaire d'identifiant donné, ou null.
func sanctuary(id: String):
	for s in sanctuaries:
		if s.id == id:
			return s
	return null


## Sanctuaire où le joueur renaîtra : le dernier ravivé ou visité (Game.flags["renaissance"]),
## la Graine par défaut.
func current_sanctuary():
	var s = sanctuary(str(Game.flags.get("renaissance", "graine")))
	if s == null or not s.is_lit():
		s = sanctuary("graine")
	return s


## Point de renaissance : centre du sanctuaire courant (la graine sans sanctuaire).
func respawn_point() -> Vector2:
	var s = current_sanctuary()
	return s.position if s != null else Vector2.ZERO


func _clear_lost_sap_flags() -> void:
	for k in ["seve_perdue", "seve_perdue_x", "seve_perdue_y"]:
		Game.flags.erase(k)


## Fait correspondre le nœud de la sève perdue aux drapeaux (partie chargée, nouvelle partie, mort).
func _sync_lost_sap() -> void:
	var amount := float(Game.flags.get("seve_perdue", 0.0))
	var pos := Vector2(float(Game.flags.get("seve_perdue_x", 0.0)), float(Game.flags.get("seve_perdue_y", 0.0)))
	if lost_sap != null and (not is_instance_valid(lost_sap) or amount <= 0.0 or lost_sap.position != pos or lost_sap.amount != amount):
		if is_instance_valid(lost_sap):
			lost_sap.queue_free()
		lost_sap = null
	if amount > 0.0 and lost_sap == null:
		lost_sap = LostSap.new()
		lost_sap.main = self
		lost_sap.position = pos
		lost_sap.amount = amount
		orbs_layer.add_child(lost_sap)


## Le joueur a touché sa sève perdue : il reprend toute son expérience.
func recover_sap() -> void:
	if lost_sap == null or not is_instance_valid(lost_sap):
		return
	var amount: float = lost_sap.amount
	var at: Vector2 = lost_sap.position
	_clear_lost_sap_flags()
	_sync_lost_sap()
	Game.add_xp(amount)
	Sfx.play("seve", at)
	# La sève revient à lui : onde, gerbe qui file vers le joueur et éclat doré sur les bords.
	fx.ring(at, 10.0, 120.0, 0.6, Color("e8d36b"), 5.0)
	fx.ring(at, 4.0, 60.0, 0.35, Art.c("danger_eclair"), 3.0)
	fx.pickup(at, "seve", 16, player.position)
	screen_fx.glow(Art.c("or"), 0.25, 0.8)
	hud.banner("Sève reprise : %d d'expérience." % roundi(amount))
	request_autosave()


func _on_node_allocated(node: Dictionary) -> void:
	if node["id"] == 0:
		return
	var world_pos: Vector2 = node["pos"] * TREE_TO_WORLD
	var radius := 200.0
	if node["type"] == "notable":
		radius = 280.0
	elif node["type"] == "keystone":
		radius = 380.0
	revive(world_pos, radius, Game.tree.node_color(node))


## Vague de vie : l'herbe avance depuis le point ravivé (ground.WAVE_TIME secondes),
## les arbres et ronces reverdissent et les fleurs éclosent au passage du front.
func revive(world_pos: Vector2, radius: float, tint: Color, strength := 0.9) -> void:
	ground.paint_wave(world_pos, radius, strength)
	flora.spawn_patch(world_pos, radius * 0.8, int(radius / 18.0), tint, ground.WAVE_TIME, radius)


func _on_level_up(lvl: int) -> void:
	fx.ring(player.position, 20.0, 160.0, 0.6, Art.c("or"), 5.0)
	fx.pickup(player.position, "seve", 12)
	hud.banner("Niveau %d : un point à placer dans l'Arbre de vie (%s)" % [lvl, hud.key_label("toggle_tree")])
	request_autosave()
	player.heal(Game.stats["max_hp"] * 0.25, true)


# --- Mode de test automatique ---

## Commandes du robot : tourne autour de la graine en visant le Flétri le plus proche.
func bot_input(p) -> Dictionary:
	if zone_bot != null:
		return zone_bot.input(self, p)
	if autotest_boss:
		return arena.bot_input(p)
	if benchmark and bench_scene == "coeur":
		return _bench_coeur_input(p)
	var target: Vector2 = p.position + Vector2.RIGHT * 100.0
	var best := INF
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			var d: float = e.position.distance_squared_to(p.position)
			if d < best:
				best = d
				target = e.position
	if build_bot != null and build_bot.run:
		return build_bot.run_input(self, p, target, best)
	if build_bot != null:
		var styled: Dictionary = build_bot.steer(p, target, best, Game.stats["max_hp"])
		if not styled.is_empty():
			return styled
	var orbit := Vector2.from_angle(elapsed * 0.35) * minf(900.0, 200.0 + elapsed * 20.0)
	var mv: Vector2 = orbit - p.position
	mv = mv.normalized() if mv.length() > 40.0 else Vector2.ZERO
	return {"move": mv, "aim": target, "dash": best < 50.0 * 50.0}


func _autotest_step(delta: float) -> void:
	if zone_bot != null:
		zone_bot.step(self, delta)
		return
	if autotest_boss:
		if benchmark:
			if arena.state == "vaincue" and bench_clock > BENCH_WARMUP + 1.0:
				_finish_benchmark()
		else:
			arena.autotest_step(delta)
		return
	autotest_time += delta
	if build_bot != null and build_bot.run:
		# Partie complète : expérience réelle depuis le niveau 1 (voir build_bot.run_step).
		if build_bot.run_step(self, delta) and not autotest_done:
			autotest_done = true
			get_tree().quit()
		return
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
	if bench_clock > BENCH_WARMUP and bench_frames.is_empty():
		Prof.reset()
	if bench_clock > BENCH_WARMUP and bench_last_usec > 0:
		bench_frames.append((now - bench_last_usec) / 1000.0)
		bench_cpu["process"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		bench_cpu["physics"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		bench_cpu["samples"] += 1
	bench_last_usec = now
	if bench_clock >= BENCH_WARMUP + bench_time:
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
	match bench_scene:
		"coeur":
			print("BENCHMARK vague du Cœur, %.0f s, %d images (siège : %s)" % [bench_clock - BENCH_WARMUP, n, heart.state])
		"boss":
			print("BENCHMARK combat du boss, %.0f s, %d images (arène : %s)" % [bench_clock - BENCH_WARMUP, n, arena.state])
		_:
			print("BENCHMARK %d Flétris, %.0f s, %d images" % [BENCH_ENEMIES, bench_time, n])
	print("BENCHMARK temps par image : moyen %.2f ms (%.1f images/s), 99e centile %.2f ms, pire %.2f ms" % [avg, 1000.0 / maxf(avg, 0.001), p99, worst])
	print("BENCHMARK scripts par image : _process %.2f ms, _physics_process %.2f ms" % [bench_cpu["process"] / k, bench_cpu["physics"] / k])
	var sn: float = maxf(1.0, bench_seg["n"])
	print("BENCHMARK découpage par image : scripts et dessins %.2f ms, rendu %.2f ms" % [bench_seg["script"] / 1000.0 / sn, bench_seg["render"] / 1000.0 / sn])
	print("BENCHMARK rendu de la dernière image : %d appels de rendu, %d objets" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	for line in Prof.report(n):
		print(line)
	var sil = Enemy.Silhouettes
	print("BENCHMARK silhouettes : %d dessins en cache, %d calculées pour le cache (%d maillages gardés), %d calculées en action" % [sil.hits, sil.misses, sil._meshes.size() + sil._old.size(), sil.live])
	print("BENCHMARK partie : niveau %d, tués %d, fleurs %d" % [Game.level, Game.kills, flora.flowers.size()])
	get_tree().quit()


## Rendu direct à l'écran : le jeu est dessiné droit dans la fenêtre, sans passer par la texture
## du viewport puis une recopie plein écran. Mêmes pixels (tests/direct_screen_test.gd), mais
## l'image n'est plus lisible par get_texture(). Gain mesuré : 5 à 15 ms par image en rendu
## logiciel selon la résolution (docs/performances.md). Actif seulement dans le banc, ou en jeu avec
## l'option --rendu-direct : sur certaines machines (Windows, jeu intégré à l'éditeur de Godot 4.4+),
## la fenêtre ne montrait plus rien de neuf et restait figée sur l'écran titre.
func _set_direct_to_screen(on: bool) -> void:
	RenderingServer.viewport_set_render_direct_to_screen(get_viewport().get_viewport_rid(), on)



## Options du banc et découpage de chaque image (voir bench_seg).
func _benchmark_setup() -> void:
	Prof.on = "--profile" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench-scene="):
			bench_scene = a.substr(14)
			# Durées par défaut : le siège dure 30 s, puis la purification ; le boss, 60 s de combat.
			bench_time = 36.0 if bench_scene == "coeur" else 60.0
			autotest_boss = bench_scene == "boss"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench-time="):
			bench_time = maxf(1.0, float(a.substr(13)))
	get_tree().process_frame.connect(func(): _seg_start = Time.get_ticks_usec())
	RenderingServer.frame_pre_draw.connect(func(): _seg_pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func():
		if bench_clock > BENCH_WARMUP and _seg_start > 0 and _seg_pre >= _seg_start:
			bench_seg["script"] += _seg_pre - _seg_start
			bench_seg["render"] += Time.get_ticks_usec() - _seg_pre
			bench_seg["n"] += 1)


## « --hide=sol,ennemis » : cache ces calques pendant le banc (la différence de temps dit leur coût).
func _benchmark_hide(layers: Dictionary) -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--hide="):
			continue
		for key in a.substr(7).split(","):
			if layers.has(key):
				layers[key].visible = false
			else:
				push_warning("--hide : calque inconnu « %s » (%s)" % [key, ", ".join(layers.keys())])


## Banc « coeur » : le build du robot du boss, le héros posé au bord de la zone du Cœur.
func _bench_coeur_begin() -> void:
	while Game.level < 12:
		Game.add_xp(Game.xp_to_next())
	while Game.points > 0:
		var options: Array = []
		for n in Game.tree.nodes:
			if n["branch"] == 0 and n["border"] < 0 and Game.can_allocate(n["id"]):
				options.append(n)
		if options.is_empty():
			break
		options.sort_custom(func(a, b):
			if (a["type"] == "keystone") != (b["type"] == "keystone"):
				return a["type"] == "keystone"
			return a["ring"] < b["ring"] if a["ring"] != b["ring"] else a["id"] < b["id"])
		Game.allocate(options[0]["id"])
	player.hp = Game.stats["max_hp"]
	player.position = heart.center + Vector2(0, heart.zone * 0.6)


## Banc « coeur » : le robot reste dans la zone et vise le Flétri le plus proche.
func _bench_coeur_input(p) -> Dictionary:
	var target: Vector2 = p.position + Vector2.RIGHT * 100.0
	var best := INF
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			var d: float = e.position.distance_squared_to(p.position)
			if d < best:
				best = d
				target = e.position
	var spot: Vector2 = heart.center + Vector2.from_angle(elapsed * 0.5) * heart.zone * 0.6
	var mv: Vector2 = spot - p.position
	mv = mv.normalized() if mv.length() > 30.0 else Vector2.ZERO
	return {"move": mv, "aim": target, "dash": false}
