## Robot « zone complète » : joue une région (celle de « -- --region=<id> », Ronce par défaut) d'une
## nouvelle partie jusqu'à son boss, en suivant l'objectif principal en cours de cette région
## (Objectives.current(region)), comme un joueur qui lit le cadre d'objectif. Utilisé par tests/zone_test.gd (tools/zone.sh), qui le fait passer par des
## sauvegardes, des reprises et des morts en route.
##
## Le robot gagne de l'expérience plus vite qu'un joueur (LEVEL_SECONDS par niveau, en plus des
## Flétris vaincus) : le but est la fiabilité de l'aventure, pas l'équilibrage (tools/balance.sh).
## Il apprend d'abord le chemin vers le nœud clé le plus proche de la branche de la région, puis
## son build (« fouet » pour Ronce).
##
## Sans état dans le jeu : il ne garde que ses mesures, et survit donc aux reprises (le test lui
## rattache la nouvelle scène de jeu).
extends RefCounted

const BuildBot = preload("res://scripts/build_bot.gd")
const TreePlanner = preload("res://scripts/tree_planner.gd")
const Content = preload("res://scripts/content.gd")
const GraftPickup = preload("res://scripts/graft_pickup.gd")
const Regions = preload("res://scripts/regions.gd")

## Secondes de jeu par niveau gagnées en plus des ennemis vaincus.
const LEVEL_SECONDS := 18.0
## Niveaux attendus avant d'assiéger le Cœur et d'entrer dans l'arène.
const HEART_LEVEL := 14
const BOSS_LEVEL := 17
## Vie (part de la vie maximale) sous laquelle le robot décroche, et au-dessus de laquelle il revient.
const FLEE_BELOW := 0.35
const BACK_ABOVE := 0.8

var builder
## Région jouée (celle dont le Cœur et l'arène sont visés : voir set_region).
var region := "ronce"
## Robot d'aventure (tests/aventure_test.gd) : tant que la finale existe (main.finale) et que le
## robot a fini les régions, il va l'affronter (« finale » vaut vrai).
var finale := false
## Niveau au-delà duquel le robot ne reçoit plus d'expérience en plus des ennemis vaincus (robot
## d'aventure : il avance au niveau d'un joueur qui enchaîne les régions, pas plus vite).
var level_cap := 100000
## Ce que fait le robot en ce moment (journal du test).
var goal := ""
var recovering := false
## Détection d'un blocage contre un obstacle : position et temps du dernier progrès.
var _last_pos := Vector2.INF
var _still := 0.0
var _detour := 0.0
var _detour_dir := Vector2.ZERO
var _t := 0.0
## Vrai pendant une vérification du test : le robot ne joue plus et le jeu ne lui donne rien.
var hold := false


func _init(build := "fouet", reg := "") -> void:
	region = reg if reg != "" else ("ronce" if Regions.exists("ronce") else Regions.ids()[0])
	var all := BuildBot.load_all()
	set_build(build)


## Change de build (les nœuds déjà appris restent) : sa branche sert de repli quand ses cibles
## sont épuisées.
func set_build(build: String) -> void:
	var all := BuildBot.load_all()
	builder = BuildBot.new()
	builder.name = build
	builder.targets = all.get(build, {}).get("targets", []).duplicate()
	builder.choices = all.get(build, {}).get("choices", {})
	builder.branch = str(all.get(build, {}).get("branch", Regions.branch_of(region)))
	builder.start_level = 1


## Passe à une autre région (robot d'aventure) avec le build donné.
func set_region(reg: String, build: String) -> void:
	region = reg
	finale = false
	goal = ""
	recovering = false
	_detour = 0.0
	_still = 0.0
	_last_pos = Vector2.INF
	set_build(build)


## Cœur de la région jouée à purifier (le plus proche du joueur, ou celui qu'il assiège), et arène.
func heart_of(main):
	var s = main.siege_heart()
	if s != null and s.region == region:
		return s
	return main.next_heart(region, main.player.position)


func arena_of(main):
	return main.arenas.get(region, main.arena) if "arenas" in main else main.arena


## Nœud clé de la branche de la région le plus proche des nœuds appris (uid), "" s'il y en a déjà
## un d'appris.
func _nearest_keystone() -> String:
	var ronce: int = Content.tree().get("branches", []).find(Regions.branch_of(region))
	var best := ""
	var best_len := 1 << 30
	for n in Game.tree.nodes:
		if n["branch"] != ronce or n["type"] != "keystone" or n["border"] >= 0:
			continue
		if Game.allocated.has(n["id"]):
			return ""
		var path: Array = TreePlanner.shortest_path(Game.tree, Game.allocated, n["id"])
		if not path.is_empty() and path.size() < best_len:
			best_len = path.size()
			best = n["uid"]
	return best


## Un pas de jeu : expérience en plus, points dépensés.
func step(main, delta: float) -> void:
	if hold:
		return
	_t += delta
	if main.in_boss_fight() or main.siege_heart() != null:
		pass  # pas d'expérience offerte pendant un combat : il se joue au niveau atteint
	elif Game.level < level_cap:
		Game.add_xp(Game.xp_to_next() * delta / LEVEL_SECONDS)
	if Game.points > 0:
		var key := _nearest_keystone()
		if key != "":
			# L'objectif « nœud clé » passe avant le build, même si le build le prévoit plus loin.
			builder.targets.erase(key)
			builder.targets.push_front(key)
		builder.spend(Game)


## Où aller pour l'objectif en cours (ou null : rester à se battre là où il est).
func _goal_pos(main, p):
	if main.lost_sap != null and is_instance_valid(main.lost_sap) and not main.in_boss_fight():
		goal = "sève perdue"
		return main.lost_sap.position
	# Greffe au sol (autel, boss, élite) : la ramasser.
	for g in main.orbs_layer.get_children():
		if g is GraftPickup and not g.is_queued_for_deletion() and g.position.distance_to(p.position) < 900.0:
			goal = "greffe " + g.graft_id
			return g.position
	if finale:
		return _finale_pos(main)
	var o: Dictionary = Objectives.current(region)
	var id: String = o.get("id", "")
	# Ce qu'il faut faire se lit dans la cible de l'objectif : rien (apprendre), un lieu, le Cœur
	# ou l'arène.
	match str(o.get("target", {}).get("type", "none")) if not o.is_empty() else "fini":
		"none", "seed":
			goal = "apprendre (%s)" % id
			return null
		"group":
			goal = id
			return Objectives.target_pos(o)
		"heart":
			if Game.level < HEART_LEVEL:
				goal = "monter de niveau avant le Cœur"
				return null
			goal = "siège du Cœur"
			var c: Vector2 = heart_of(main).center
			return c - c.normalized() * 130.0
		"arena":
			if Game.level < BOSS_LEVEL and not main.in_boss_fight():
				goal = "monter de niveau avant le boss"
				return null
			goal = "boss"
			return arena_of(main).center
	goal = "fini"
	return arena_of(main).center


## La finale (main.finale, sous la graine) : le robot marche sur la graine, qui descend dans l'arène.
func _finale_pos(main):
	var f = main.get("finale")
	if f == null or f.state in ["fermee", "vaincue"]:
		goal = "finale fermée" if f != null and f.state == "fermee" else "finale finie"
		return null
	goal = "finale"
	return null


## Commandes du robot : {"move", "aim", "dash"}.
func input(main, p) -> Dictionary:
	if hold:
		return {"move": Vector2.ZERO, "aim": p.position + Vector2.RIGHT, "dash": false}
	var target: Vector2 = p.position + Vector2.RIGHT * 100.0
	var best := INF
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead:
			var d: float = e.position.distance_squared_to(p.position)
			if d < best:
				best = d
				target = e.position
	var fight = main.active_arena()
	if fight != null:
		goal = "boss"
		return fight.bot_input(p)
	# Finale (sous la graine) : son robot mène à la graine puis au boss, ouverte ou en combat.
	var fin = main.get("finale") if finale else null
	if fin != null and fin.state in ["ouverte", "combat"]:
		goal = "finale"
		return fin.bot_input(p)
	var where = _goal_pos(main, p)
	var hp_ratio: float = p.hp / Game.stats["max_hp"]
	if hp_ratio < FLEE_BELOW:
		recovering = true
	elif hp_ratio > BACK_ABOVE:
		recovering = false
	var away := Vector2.ZERO
	for e in main.enemies_near(p.position, 200.0):
		var d: Vector2 = p.position - e.position
		var l := maxf(d.length(), 8.0)
		away += d / (l * l)
	away = away.normalized() if away.length() > 0.0 else Vector2.ZERO
	# Siège du Cœur : rester dans la zone prime sur tout le reste (sortir fait reculer le siège).
	if goal == "siège du Cœur" and where != null:
		var from_c: float = p.position.distance_to(heart_of(main).center)
		if from_c > heart_of(main).zone - 50.0:
			var back: Vector2 = ((where as Vector2) - p.position).normalized()
			return {"move": _unstick(p, back).normalized(), "aim": target, "dash": best < 45.0 * 45.0}
	var dodge: Vector2 = builder._dodge(main, p)
	if dodge != Vector2.ZERO:
		return {"move": dodge.normalized(), "aim": target, "dash": dodge.length() > 1.5}
	var mv := Vector2.ZERO
	# En siège, il tient la zone tant qu'il le peut : il ne décroche qu'au tout dernier moment.
	var sieging: bool = goal == "siège du Cœur" and heart_of(main).state == "siege"
	if recovering and not (sieging and hp_ratio > 0.2):
		# Repli vers son point de renaissance (un sanctuaire ravivé rend toute la vie en y entrant).
		var safe: Vector2 = main.respawn_point()
		mv = (safe - p.position).normalized() + away * 1.5
		goal = "repli"
	elif where != null:
		var to: Vector2 = (where as Vector2) - p.position
		if to.length() > 24.0:
			mv = to.normalized() + away * (0.3 if sieging else 0.8)
	else:
		# Se battre autour du point de renaissance, en tournant.
		var orbit: Vector2 = main.respawn_point() + Vector2.from_angle(_t * 0.35) * 260.0
		var to: Vector2 = orbit - p.position
		mv = (to.normalized() if to.length() > 40.0 else Vector2.ZERO) + away
	mv = _unstick(p, mv)
	return {"move": mv.normalized() if mv.length() > 0.05 else Vector2.ZERO, "aim": target, "dash": best < 45.0 * 45.0}


## Contre un buisson d'épines ou un mur, le robot fait un détour sur le côté pendant un instant.
func _unstick(p, mv: Vector2) -> Vector2:
	var dt := 1.0 / 60.0
	if _detour > 0.0:
		_detour -= dt
		return _detour_dir
	if mv.length() < 0.1:
		_still = 0.0
		_last_pos = p.position
		return mv
	if _last_pos == Vector2.INF or p.position.distance_to(_last_pos) > 40.0:
		_last_pos = p.position
		_still = 0.0
	else:
		_still += dt
		if _still > 1.5:
			_still = 0.0
			_detour = 0.9
			var side := mv.orthogonal().normalized()
			_detour_dir = (side * (1.0 if randf() < 0.5 else -1.0) - mv.normalized() * 0.3).normalized()
			return _detour_dir
	return mv
