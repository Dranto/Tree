## Robot d'équilibrage : apprend les nœuds d'un build type décrit dans res://data/builds.json.
##   tools/godot.sh --xvfb -- --autotest=build:fouet [--build-time=180] [--build-level=20] [--seed=N]
## À chaque point gagné, le robot apprend le prochain nœud du plus court chemin vers la
## première cible pas encore acquise. Quand les cibles sont épuisées (ou absentes de l'arbre),
## il complète avec le nœud de Ronce disponible le plus proche de la graine. À la fin, il affiche
## les ennemis vaincus par minute, que tools/balance.sh compare entre les builds.
##
## Mode « partie complète » (« -- --autotest=run:<build> », tools/balance.sh --run) : le robot part
## du niveau 1 avec l'expérience réelle, avance dans la région de Ronce à mesure qu'il monte de
## niveau (il assiège le Cœur de flétrissure au niveau HEART_LEVEL), ramasse les essences et note
## chaque minute son niveau, la menace des ennemis, le temps pour tuer un Flétri ordinaire, les
## dégâts reçus et ses morts. Il s'arrête au niveau RUN_LEVEL ou au bout de --build-time secondes.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const Content = preload("res://scripts/content.gd")
const Difficulty = preload("res://scripts/difficulty.gd")
const Thorn = preload("res://scripts/enemy_thorn.gd")
const Feather = preload("res://scripts/vent_feather.gd")

const TreePlanner = preload("res://scripts/tree_planner.gd")
const BUILDS_PATH := "res://data/builds.json"
const DEFAULT_TIME := 180.0
## Niveau de départ : le build est mesuré en milieu de partie (assez de points pour ses grappes),
## avec la difficulté qui va avec ce niveau.
const DEFAULT_LEVEL := 20
## Secondes comptées en plus pour chaque mort dans le score (ennemis vaincus par minute).
const DEATH_PENALTY := 10.0
## Distance à la graine au-delà de laquelle les robots « melee » et « tank » ne poursuivent plus.
const LEASH := 1100.0
## En partie complète : distance au point d'ancrage au-delà de laquelle ils ne poursuivent plus.
const RUN_LEASH := 520.0
## Distance au mur de l'arène ouverte en deçà de laquelle le robot s'en écarte.
const ARENA_MARGIN := 260.0

var name := ""
## Branche du build (builds.json › branch) et région où il s'enfonce en partie complète.
var branch := "ronce"
var region := "ronce"
var targets: Array = []
var choices: Dictionary = {}
## Façon de jouer du robot : « distance » (tourne autour de la graine en tirant, par défaut),
## « melee » (va au contact pour le fouet), « tank » (reste au milieu des ennemis pour les épines).
var style := "distance"
var duration := DEFAULT_TIME
var start_level := DEFAULT_LEVEL
var _started := false
var missing: Array = []

## --- Partie complète ---
const RUN_TIME := 4200.0
const RUN_LEVEL := 25
## Niveau où le robot va assiéger le Cœur de flétrissure de Ronce (il renonce trois niveaux plus tard).
const HEART_LEVEL := 15
## Décalage de son chemin par rapport à l'axe de la région (radians) : il longe le Cœur et
## l'arène au lieu de leur passer dessus.
const PATH_OFFSET := 0.18
var run := false
var _recovering := false
## « --run-freeze » (avec --build-level=N) : niveau figé, le robot mesure seulement l'expérience
## gagnée par minute à ce niveau (pour régler la courbe d'expérience de difficulty.json).
var freeze := false
var _xp_gained := 0.0
var _t := 0.0
var _prev_hp := -1.0
var _deaths_seen := 0
var _minute_dmg := 0.0
var _minute_kills := 0
var _kills_seen := 0
var _ttk: Array = []
var _hit: Dictionary = {}
var _level_seen := 1
var _level_start := 0.0
var _next_sample := 60.0
var _deaths_before_20 := 0
var level_times: Array = []


## Lit le build demandé sur la ligne de commande, ou renvoie null s'il n'y en a pas.
static func from_cmdline():
	var wanted := ""
	var time := -1.0
	var level := DEFAULT_LEVEL
	var is_run := false
	var freeze := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest=build:"):
			wanted = a.trim_prefix("--autotest=build:")
		elif a.begins_with("--autotest=run:"):
			wanted = a.trim_prefix("--autotest=run:")
			is_run = true
		elif a == "--run-freeze":
			freeze = true
		elif a.begins_with("--build-time="):
			time = float(a.trim_prefix("--build-time="))
		elif a.begins_with("--build-level="):
			level = int(a.trim_prefix("--build-level="))
	if wanted == "":
		return null
	var all := load_all()
	if not all.has(wanted):
		push_error("Build inconnu « %s » (dans %s : %s)" % [wanted, BUILDS_PATH, ", ".join(all.keys())])
		return null
	var bot = new()
	bot.name = wanted
	bot.targets = all[wanted].get("targets", [])
	bot.choices = all[wanted].get("choices", {})
	bot.style = all[wanted].get("style", "distance")
	bot.branch = str(all[wanted].get("branch", "ronce"))
	bot.region = bot.branch if Regions.exists(bot.branch) else (Regions.ids()[0] if not Regions.ids().is_empty() else "")
	bot.run = is_run
	if is_run:
		bot.targets = all[wanted].get("opening", []) + bot.targets
	bot.duration = time if time > 0.0 else (RUN_TIME if is_run else DEFAULT_TIME)
	bot.start_level = level if (not is_run or freeze) else 1
	bot.freeze = is_run and freeze
	return bot


static func load_all() -> Dictionary:
	var out := {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(BUILDS_PATH))
	if data is Dictionary:
		for k in data:
			if not str(k).begins_with("_"):
				out[k] = data[k]
	return out


## Dépense les points disponibles selon le build (au premier appel : passe au niveau de départ).
func spend(game) -> void:
	if not _started:
		_started = true
		game.points += maxi(0, start_level - game.level)
		game.level = maxi(game.level, start_level)
	var guard := 0
	while game.points > 0 and guard < 50:
		guard += 1
		var id := _next(game)
		if id < 0 or not game.allocate(id):
			return
		_choose(game, id)


func _next(game) -> int:
	var tree = game.tree
	for uid in targets:
		var target: int = tree.id_for_uid(uid)
		if target < 0:
			if not uid in missing:
				missing.append(uid)
			continue
		if game.allocated.has(target):
			continue
		var path: Array = TreePlanner.shortest_path(tree, game.allocated, target, TreePlanner.with_mutations(tree, game.allocated))
		if path.is_empty():
			path = TreePlanner.shortest_path(tree, game.allocated, target)
		for id in path:
			if game.can_allocate(id):
				return id
			break  # chemin bloqué (exclusion, nœud verrouillé) : cible suivante
	# Cibles épuisées : le nœud de la branche du build disponible le plus proche de la graine.
	var best := -1
	var best_ring := 999
	var bi := maxi(0, Content.tree().get("branches", []).find(branch))
	for n in tree.nodes:
		if n["branch"] == bi and n["border"] < 0 and n["ring"] < best_ring and game.can_allocate(n["id"]):
			best = n["id"]
			best_ring = n["ring"]
	if best < 0:
		for n in tree.nodes:
			if game.can_allocate(n["id"]):
				return n["id"]
	return best


## Choix des maîtrises et mutations (interface de la tâche A, si elle est présente).
func _choose(game, id: int) -> void:
	var uid: String = game.tree.nodes[id]["uid"]
	var list: Array = game.tree.nodes[id].get("choices", [])
	if list.is_empty() or not game.has_method("set_choice"):
		return
	if not choices.has(uid):
		game.set_choice(id, 0)  # choix non prévu par le build : le premier
		return
	for i in list.size():
		if str(list[i].get("id", i)) == str(choices[uid]):
			game.set_choice(id, i)
			return
	push_warning("Build %s : choix « %s » introuvable sur %s" % [name, choices[uid], uid])


## Déplacement du robot selon le style du build. Renvoie {} pour garder le jeu « à distance » par défaut.
## « center » et « leash » : la laisse (la graine et LEASH par défaut ; en partie complète, le point
## d'ancrage du robot, qui avance dans la région).
func steer(player, target: Vector2, best_d2: float, max_hp: float, melee_keep := 90.0,
		center := Vector2.ZERO, leash := LEASH) -> Dictionary:
	if style == "distance" or best_d2 == INF:
		return {}
	# Laisse : le robot ne poursuit pas un Flétri au-delà de « leash » px de son centre (sinon il
	# dérive jusqu'aux régions voisines, plus peuplées, et la mesure ne compare plus les builds).
	if target.distance_to(center) > leash:
		var off: Vector2 = player.position - center
		var back: Vector2 = -off.normalized() if off.length() > leash * 0.8 else Vector2.ZERO
		return {"move": back, "aim": target, "dash": false}
	var d := sqrt(best_d2)
	var low: bool = player.hp < max_hp * 0.35
	var keep := melee_keep if style == "melee" else 35.0
	var mv := Vector2.ZERO
	if low:
		mv = (player.position - target).normalized()
	elif d > keep:
		mv = (target - player.position).normalized()
	elif run and style == "melee" and d < keep * 0.5:
		# Partie complète : le corps à corps frappe à distance d'arme, il ne reste pas au contact
		# (sinon un Flétri qu'on ne repousse pas, comme le Menhir, le frappe sans arrêt). Le mode
		# « builds » garde l'ancien jeu, sur lequel ses chiffres de référence ont été réglés.
		mv = (player.position - target).normalized()
	return {"move": mv, "aim": target, "dash": low and d < 60.0}


func report(game, elapsed: float, deaths: int) -> String:
	# Une mort coûte DEATH_PENALTY secondes : le robot repart sur place avec toute sa vie
	# (voir main.player_died), donc un build qui meurt souvent ne doit pas en tirer avantage.
	var per_min: float = game.kills / maxf((elapsed + deaths * DEATH_PENALTY) / 60.0, 0.001)
	var line := "BUILD %s : %.0f s, niveau %d, %d nœuds, %d tués, %d morts, %.1f tués/min (mort = 10 s perdues)" % [
		name, elapsed, game.level, game.allocated.size(), game.kills, deaths, per_min]
	if not missing.is_empty():
		line += "\nBUILD %s : %d cibles absentes de l'arbre (%s)" % [name, missing.size(), ", ".join(missing)]
	if OS.get_environment("BALANCE_DEBUG") != "":
		var names := []
		for id in game.allocated:
			names.append(game.tree.nodes[id]["uid"])
		line += "\nDEBUG nodes=%s\nDEBUG stats=%s" % [", ".join(names), str(game.stats)]
	return line


# --- Partie complète ---

## Point autour duquel le robot se bat : il quitte la graine et s'enfonce dans la région de son build
## à mesure qu'il monte de niveau, comme un joueur qui avance dans l'aventure.
func run_anchor(main) -> Vector2:
	var heart = main.next_heart(region, main.player.position) if main.has_method("next_heart") else main.heart
	if Game.level >= HEART_LEVEL and Game.level < HEART_LEVEL + 3 and heart != null and heart.state != "purifie" \
			and not Game.flags.get(Regions.heart_flag(region), false):
		return heart.center
	var k := clampf((Game.level - 2) / 18.0, 0.0, 1.0)
	var dist := lerpf(150.0, 2200.0, k)
	return Vector2.from_angle(Regions.angle_of(region) + PATH_OFFSET) * dist


## Commandes du robot en partie complète, à la façon d'un joueur prudent : il s'éloigne de la
## foule quand sa vie baisse, revient vers son point d'ancrage s'il s'en écarte, ramasse les
## essences quand aucun ennemi n'est proche, et sinon joue le style du build.
func run_input(main, p, target: Vector2, best_d2: float) -> Dictionary:
	var anchor := run_anchor(main)
	var to_anchor: Vector2 = anchor - p.position
	var max_hp: float = Game.stats["max_hp"]
	var near_enemy := best_d2 < 60.0 * 60.0
	# Danger : les ennemis proches poussent le robot, d'autant plus fort qu'ils sont près.
	var away := Vector2.ZERO
	var crowd := 0
	for e in main.enemies_near(p.position, 220.0):
		var d: Vector2 = p.position - e.position
		var l := maxf(d.length(), 8.0)
		away += d / (l * l)
		if l < 140.0:
			crowd += 1
	away = away.normalized() if away.length() > 0.0 else Vector2.ZERO
	var hp_ratio: float = p.hp / max_hp
	# Attaques annoncées : il s'écarte d'une épine qui arrive et du couloir d'une charge.
	var dodge := _dodge(main, p)
	# L'arène du boss : la partie complète ne mesure pas le combat de boss, le robot n'y entre pas
	# (une poursuite au corps à corps l'y menait une fois le Cœur purifié, et il y mourait en boucle).
	var arena = main.arenas.get(region) if "arenas" in main else null
	# Déjà enfermé dans un combat (il y est entré avant que l'arène ne s'ouvre au robot) : il se
	# bat comme le robot du boss ; fuir le pousserait contre le mur, qui blesse à chaque pas.
	var fight = main.active_arena() if main.has_method("active_arena") else null
	if fight != null:
		return fight.bot_input(p)
	if arena != null and arena.state == "ouverte" \
			and p.position.distance_to(arena.center) < arena.radius + ARENA_MARGIN:
		return {"move": (p.position - arena.center).normalized(), "aim": target, "dash": false}
	if dodge != Vector2.ZERO:
		var mv_d := dodge.normalized()
		if to_anchor.length() > 300.0:
			mv_d = (mv_d + to_anchor.normalized() * 0.7).normalized()
		return {"move": mv_d, "aim": target, "dash": dodge.length() > 1.5}
	# Vie basse : il décroche et ne revient au combat qu'une fois remis (comme un joueur prudent).
	if hp_ratio < 0.4:
		_recovering = true
	elif hp_ratio > 0.85:
		_recovering = false
	if _recovering:
		# Repli vers la terre déjà parcourue (vers la graine), jamais vers le fond du roncier.
		var safe: Vector2 = anchor * 0.5
		var flee: Vector2 = away * 1.5 + (safe - p.position).normalized()
		if flee == Vector2.ZERO:
			flee = Vector2.from_angle(main.elapsed * 0.5)
		return {"move": flee.normalized(), "aim": target, "dash": near_enemy}
	if to_anchor.length() > 420.0:
		var back := (to_anchor.normalized() + away * 0.6).normalized()
		return {"move": back, "aim": target, "dash": near_enemy and hp_ratio < 0.7}
	if best_d2 > 150.0 * 150.0 or crowd == 0:
		var orb := _nearest_orb(main, p.position, 360.0)
		if orb != Vector2.INF:
			return {"move": (orb - p.position).normalized(), "aim": target, "dash": false}
	# Le style du build : seulement quand il a de quoi le jouer (le tank attend d'avoir assez d'épines).
	var play := style
	if style == "tank" and (Game.stats["thorns"] < 25.0 or hp_ratio < 0.5):
		play = "distance"
	if play != "distance" and not (crowd >= 5 and hp_ratio < 0.7):
		# Laisse autour du point d'ancrage (celle de la graine le retiendrait loin de sa région).
		var styled := steer(p, target, best_d2, max_hp, 125.0, anchor, RUN_LEASH)
		if not styled.is_empty():
			return styled
	var orbit: Vector2 = anchor + Vector2.from_angle(main.elapsed * 0.35) * 200.0
	var mv: Vector2 = orbit - p.position
	mv = mv.normalized() if mv.length() > 40.0 else Vector2.ZERO
	mv = (mv + away * 1.2).normalized() if away != Vector2.ZERO else mv
	return {"move": mv, "aim": target, "dash": near_enemy}


## Direction d'esquive (longueur > 1,5 : danger imminent, il faut l'esquive), ou zéro.
func _dodge(main, p) -> Vector2:
	var out := Vector2.ZERO
	for th in main.projectiles_layer.get_children():
		# Épines des Cracheurs et plumes des Planeurs de cendre (région de Vent).
		if th.get_script() != Thorn and th.get_script() != Feather:
			continue
		var rel: Vector2 = p.position - th.position
		var v: Vector2 = th.vel
		if rel.length() > 220.0 or v.dot(rel) <= 0.0:
			continue
		# Distance au plus près de la trajectoire.
		var along := rel.dot(v.normalized())
		var miss := (rel - v.normalized() * along).length()
		if miss < p.radius + 22.0:
			var side := v.orthogonal().normalized()
			if side.dot(rel - v.normalized() * along) < 0.0:
				side = -side
			out += side * (2.0 if along < 90.0 else 1.0)
	for e in main.enemies_near(p.position, 480.0):
		if e.behavior == "charger" and e.state == "windup":
			var lane: Vector2 = (p.position - e.position).normalized()
			out += lane.orthogonal() * (2.0 if e.windup_ratio() > 0.6 else 1.0)
	return out


func _nearest_orb(main, from: Vector2, max_d: float) -> Vector2:
	var best := Vector2.INF
	var best_d := max_d * max_d
	for o in main.orbs_layer.get_children():
		var d: float = o.position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = o.position
	return best


## Un pas de la partie complète : dépense des points, mesures, relevé de chaque minute.
## Renvoie vrai quand la partie est finie.
func run_step(main, delta: float) -> bool:
	spend(Game)
	_t += delta
	if freeze:
		_xp_gained += Game.xp
		Game.xp = 0.0
		if _t >= duration:
			print("RUNRATE %s niveau=%d xp_min=%.1f tues_min=%.1f morts=%d" % [name, Game.level, _xp_gained / (_t / 60.0), Game.kills / (_t / 60.0), main.deaths])
			return true
		return false
	var p = main.player
	# Dégâts reçus : baisse de la vie d'un pas à l'autre (une mort compte la vie qui restait).
	if main.deaths > _deaths_seen:
		if OS.get_environment("RUN_DEBUG") != "":
			var kinds := {}
			for e in main.enemies_near(p.position, 200.0):
				kinds[e.kind_id] = kinds.get(e.kind_id, 0) + 1
			print("RUNDEATH t=%.0f niveau=%d vie_avant=%.0f recup=%s pos=%s profondeur=%.2f autour=%s" % [_t, Game.level, _prev_hp, _recovering, p.position.round(), main._region_depth(p.position), kinds])
		_minute_dmg += maxf(_prev_hp, 0.0)
		if Game.level < 20:
			_deaths_before_20 += main.deaths - _deaths_seen
		_deaths_seen = main.deaths
	elif _prev_hp >= 0.0 and p.hp < _prev_hp:
		_minute_dmg += _prev_hp - p.hp
	_prev_hp = p.hp
	# Temps pour tuer un Flétri ordinaire : du premier coup reçu à sa mort.
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead and "kind" in e and e.kind == 0 and e.hp < e.max_hp:
			var id: int = e.get_instance_id()
			if not _hit.has(id):
				_hit[id] = [_t, weakref(e)]
	for id in _hit.keys():
		var e = _hit[id][1].get_ref()
		if e == null or e.dead:
			_ttk.append(_t - float(_hit[id][0]))
			_hit.erase(id)
	while Game.level > _level_seen:
		level_times.append(_t - _level_start)
		print("RUNLEVEL %s %d %.1f %.1f %.1f" % [name, _level_seen, _t - _level_start, _t, Difficulty.target_minutes(_level_seen) * 60.0])
		_level_seen += 1
		_level_start = _t
	if _t >= _next_sample:
		_next_sample += 60.0
		_sample(main)
	if Game.level >= RUN_LEVEL or _t >= duration:
		_sample(main)
		print("RUNEND %s temps=%.0f niveau=%d morts=%d morts_avant_20=%d noeuds=%d tues=%d" % [
			name, _t, Game.level, main.deaths, _deaths_before_20, Game.allocated.size(), Game.kills])
		return true
	return false


func _sample(main) -> void:
	var total := 0.0
	var n := 0
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead and "power" in e:
			total += e.power
			n += 1
	# Médiane : un ennemi touché une fois puis laissé derrière (fuite) ne fausse pas la mesure.
	var ttk := -1.0
	if not _ttk.is_empty():
		_ttk.sort()
		ttk = _ttk[_ttk.size() / 2]
	var kills: int = Game.kills - _kills_seen
	_kills_seen = Game.kills
	var depth := 0.0
	if main.has_method("_region_depth"):
		depth = main._region_depth(main.player.position)
	print("RUN %s min=%.0f niveau=%d xp=%.0f/%.0f menace=%.2f ttk=%.2f degats=%.0f vie_max=%.0f morts=%d tues=%d ennemis=%d profondeur=%.2f coeur=%d" % [
		name, _t / 60.0, Game.level, Game.xp, Game.xp_to_next(), total / maxf(1, n), ttk, _minute_dmg,
		Game.stats["max_hp"], main.deaths, kills, n, depth, 1 if Game.flags.get(Regions.heart_flag(region), false) else 0])
	if OS.get_environment("RUN_DEBUG") != "":
		var alive := {}
		for e in main.enemies:
			if is_instance_valid(e) and not e.dead and "kind_id" in e:
				alive[e.kind_id] = alive.get(e.kind_id, 0) + 1
		print("RUNKINDS min=%.0f lieu=%s %s" % [_t / 60.0, main.region_at(main.player.position), alive])
	_ttk.clear()
	_minute_dmg = 0.0
