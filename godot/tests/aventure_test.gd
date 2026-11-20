## Robot d'aventure : une nouvelle partie jouée d'un bout à l'autre par le robot de zone
## (scripts/zone_bot.gd) : les régions l'une après l'autre, dans l'ordre d'un joueur (de la plus
## facile à la plus dure), chaque Cœur assiégé, chaque boss battu, puis la finale quand le jeu en a
## une (main.finale, épilogue et générique : main.quest_ui.epilogue). À chaque étape principale
## accomplie, et à la fin de chaque région, la partie est sauvegardée puis rechargée : elle doit
## être retrouvée à l'identique et rester cohérente (Cœurs, arènes, objectifs, finale).
##
## Blocages signalés clairement (BLOCAGE …) et fatals, sauf avec --continue-on-block, qui force la
## région bloquée (drapeaux posés) pour voir la suite :
## - objectif inatteignable : aucun objectif principal accompli pendant STALL secondes de jeu ;
## - boss qui ne meurt pas : un combat de boss plus long que BOSS_MAX secondes ;
## - joueur coincé : il ne bouge presque pas pendant STUCK_TIME secondes alors qu'il a un but ;
## - région trop longue (REGION_MAX), trop de morts (DEATHS_MAX) ;
## - sauvegarde ou chargement qui casse : reprise différente de la partie sauvegardée, état incohérent.
##
## Lancer : tools/aventure.sh (voir le README), ou à la main :
##   tools/godot.sh --headless --fixed-fps 60 -s res://tests/aventure_test.gd -- --autotest=aventure[:<build>] --seed=1
## Options : --variante=N (le N-ième build de chaque autre branche, 0 par défaut), --ordre=a,b,c,
## --jusqua=<région> (s'arrête après cette région), --continue-on-block.
## Sauvegarde dans user://tests/ : la partie du joueur n'est pas touchée.
extends SceneTree


const DT := 1.0 / 60.0
const Regions = preload("res://scripts/regions.gd")
## Ordre d'un joueur, de la région la plus facile à la plus dure (les autres, dans l'ordre des secteurs, ensuite).
const ORDER := ["ronce", "spore", "aube", "vent", "seve"]
## Secondes de jeu sans objectif principal accompli au-delà desquelles c'est un blocage.
const STALL := 900.0
## Durée maximale d'un combat de boss, d'une région entière, et nombre de morts maximal par région.
const BOSS_MAX := 420.0
const REGION_MAX := 3000.0
const DEATHS_MAX := 40
## Joueur coincé : déplacement inférieur à STUCK_DIST pendant STUCK_TIME secondes.
const STUCK_TIME := 60.0
const STUCK_DIST := 60.0
## Niveau au-delà duquel le robot ne reçoit plus d'expérience en plus : il suit le niveau d'un joueur
## qui enchaîne les régions (cap = CAP_BASE + CAP_STEP × régions déjà faites).
const CAP_BASE := 20
const CAP_STEP := 3
## Durée maximale de la finale (combat, épilogue et générique compris).
const FINALE_MAX := 900.0

var failures := 0
var game
var obj
var save
var main
var bot
var seed_n := 1
var path := ""
var t := 0.0
var last_progress := 0.0
var pending_reload := ""
var order: Array = []
var idx := 0
var variant := 0
var first_build := ""
var stop_after := ""
var keep_going := false
var reloads := 0
var deaths_before := 0
var boss_fight_time := 0.0
var _log_next := 0.0
## Journal de chaque région : id -> {debut, fin, niveau_debut, niveau_fin, morts, boss, forcee…}.
var report: Dictionary = {}
var blocks: Array = []
## Défauts vus pendant le jeu : nom -> [nombre, première fois (s)].
var _stuck_pos := Vector2.INF
var _stuck_since := 0.0
var _region_start_deaths := 0
var _boss_total := 0.0
var _finale_start := -1.0
var _finale_done := false
var stopping := false
var _wall_start := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Greffe au sol (graft_pickup.gd) : les scripts du jeu se chargent à l'exécution.
func _is_graft(n) -> bool:
	return n.get("graft_id") != null


func _new_main(resume := "") -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.zone_bot = bot
	main.resume_from = resume
	root.add_child(main)
	await _frames(3)


func _args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest=aventure:"):
			first_build = a.trim_prefix("--autotest=aventure:")
		elif a.begins_with("--variante="):
			variant = int(a.trim_prefix("--variante="))
		elif a.begins_with("--ordre="):
			for r in a.trim_prefix("--ordre=").split(","):
				if r != "":
					order.append(r)
		elif a.begins_with("--jusqua="):
			stop_after = a.trim_prefix("--jusqua=")
		elif a == "--continue-on-block":
			keep_going = true


## Régions jouées : l'ordre demandé (ou ORDER), complété par les autres régions du monde.
func _order() -> Array:
	var out: Array = []
	for r in (order if not order.is_empty() else ORDER):
		if Regions.exists(r) and not r in out:
			out.append(r)
	for r in Regions.ids():
		if not r in out:
			out.append(r)
	return out


## Build du robot pour une région : celui demandé (« --autotest=aventure:<build> ») s'il joue la
## branche de la région, sinon le N-ième build de cette branche (--variante).
func _build_for(region: String) -> String:
	var all: Dictionary = load("res://scripts/build_bot.gd").load_all()
	var branch := Regions.branch_of(region)
	if first_build != "" and all.has(first_build) and str(all[first_build].get("branch", "")) == branch:
		return first_build
	var mine: Array = []
	for k in all:
		if str(all[k].get("branch", "")) == branch:
			mine.append(k)
	if mine.is_empty():
		return all.keys()[0] if not all.is_empty() else "fouet"
	return mine[variant % mine.size()]


func _region() -> String:
	return order[idx] if idx < order.size() else ""


func _start_region() -> void:
	var r := _region()
	bot.set_region(r, _build_for(r))
	bot.level_cap = CAP_BASE + CAP_STEP * idx
	_region_start_deaths = deaths_before + main.deaths
	_boss_total = 0.0
	last_progress = t
	_stuck_pos = Vector2.INF
	report[r] = {"debut": t, "niveau_debut": game.level, "build": bot.builder.name, "reprises": 0,
		"boss": 0.0, "forcee": false}
	print("AVENTURE %4d s  région %d/%d : %s, build « %s », niveau %d" % [int(t), idx + 1, order.size(), r, bot.builder.name, game.level])


func _run() -> void:
	_wall_start = Time.get_ticks_msec()
	game = root.get_node("Game")
	obj = root.get_node("Objectives")
	save = root.get_node("SaveGame")
	_args()
	seed_n = game.forced_seed if game.forced_seed >= 0 else 1
	path = "user://tests/aventure_%d_%d.json" % [seed_n, variant]
	save.delete_save(path)
	game.reset()
	order = _order()
	bot = load("res://scripts/zone_bot.gd").new("fouet", order[0])
	await _new_main()
	obj.completed.connect(_on_completed)
	print("AVENTURE graine %d : nouvelle partie, régions %s" % [seed_n, " > ".join(order)])
	_start_region()

	while true:
		await physics_frame
		if main == null or not is_instance_valid(main):
			break
		if not paused:
			t += DT
		_track()
		if main.quest_ui.ending.active:
			await _ending()
			continue
		var epi = main.quest_ui.get("epilogue")
		if epi != null and epi.active:
			await _epilogue(epi)
			continue
		if pending_reload != "":
			var why := pending_reload
			pending_reload = ""
			await _reload(why)
		if idx >= order.size():
			if _finale_over():
				break
			if _finale_blocked():
				break
			continue
		var reason := _blocked()
		if reason != "":
			_block(reason)
			if keep_going and idx < order.size():
				await _force_region()
				continue
			break
		if _region_done():
			await _finish_region()
			if stopping:
				print("AVENTURE : arrêt demandé après %s" % stop_after)
				break

	await _final()
	var seconds := (Time.get_ticks_msec() - _wall_start) / 1000
	print("AVENTURE graine %d : %d s de jeu (%d s de calcul), niveau %d, %d morts, %d reprises" % [seed_n, int(t), seconds, game.level, deaths_before + (main.deaths if main != null and is_instance_valid(main) else 0), reloads])
	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	save.delete_save(path)
	quit(1 if failures > 0 else 0)


func _on_completed(id: String) -> void:
	var o: Dictionary = obj.get_def(id)
	print("AVENTURE %4d s  objectif accompli : %s (niveau %d)" % [int(t), id, game.level])
	if o.get("main", false):
		last_progress = t
		# Quitter et reprendre à chaque étape de l'aventure.
		pending_reload = "après « %s »" % id


# --- Suivi et détection des blocages ---

func _fighting() -> bool:
	return main.in_boss_fight() or (main.get("finale") != null and main.finale.in_combat())


func _track() -> void:
	if _fighting():
		boss_fight_time += DT
		_boss_total += DT
	else:
		boss_fight_time = 0.0
	if t >= _log_next:
		_log_next += 60.0
		var cur: Dictionary = obj.current(_region()) if idx < order.size() else obj.current()
		print("AVENTURE %4d s  %-6s niveau %2d  objectif %-16s robot : %-30s vie %d/%d  morts %d  à %d px de la graine" % [int(t), _region() if idx < order.size() else "finale", game.level, cur.get("id", "—"), bot.goal, int(main.player.hp), int(game.stats["max_hp"]), deaths_before + main.deaths, int(main.player.position.length())])


## Raison d'un blocage de la région en cours, "" sinon.
func _blocked() -> String:
	var r := _region()
	var cur: Dictionary = obj.current(r)
	var info := "objectif « %s », robot : %s, niveau %d, %d points, %d nœuds appris, position %s" % [cur.get("id", "—"), bot.goal, game.level, game.points, game.allocated.size(), main.player.position.round()]
	if t - last_progress > STALL:
		if bot.goal.begins_with("apprendre"):
			info += "\n    " + _learn_debug()
		return "objectif inatteignable ? aucun objectif principal accompli depuis %d s (%s)" % [int(t - last_progress), info]
	if boss_fight_time > BOSS_MAX:
		return "le boss ne meurt pas : combat de plus de %d s (%s)" % [int(BOSS_MAX), info]
	if t - float(report[r]["debut"]) > REGION_MAX:
		return "région trop longue : plus de %d s (%s)" % [int(REGION_MAX), info]
	var deaths: int = deaths_before + main.deaths - _region_start_deaths
	if deaths > DEATHS_MAX:
		return "trop de morts dans la région : %d (%s)" % [deaths, info]
	# Joueur coincé : pas de progrès sur la carte alors que le robot a un but, hors combat et repli.
	var p: Vector2 = main.player.position
	var moving_goal: bool = not _fighting() and not main.hud.death_screen.is_showing() and bot.goal != "" \
		and not bot.goal.begins_with("apprendre") and not bot.goal.begins_with("monter") and not bot.hold
	if not moving_goal or _stuck_pos == Vector2.INF or p.distance_to(_stuck_pos) > STUCK_DIST:
		_stuck_pos = p
		_stuck_since = t
	elif t - _stuck_since > STUCK_TIME:
		return "joueur coincé : il n'a pas bougé de %d px en %d s (%s)" % [STUCK_DIST, STUCK_TIME, info]
	return ""


## Pourquoi le robot n'apprend pas le nœud suivant : chemin, nœuds acquis, nœuds apprenables.
func _learn_debug() -> String:
	var TP = load("res://scripts/tree_planner.gd")
	var out := []
	for uid in bot.builder.targets.slice(0, 2):
		var id: int = game.tree.id_for_uid(uid)
		if id < 0:
			out.append("%s : absent" % uid)
			continue
		var path: Array = TP.shortest_path(game.tree, game.allocated, id)
		var avail := path.filter(func(n): return game.can_allocate(n))
		out.append("%s : acquis %s, chemin %s, apprenables %s" % [uid, game.allocated.has(id), path.map(func(n): return game.tree.nodes[n]["uid"]), avail.size()])
	var bi: int = Content_tree_branches().find(Regions.branch_of(_region()))
	for n in game.tree.nodes:
		if n["branch"] == bi and n["type"] == "keystone":
			var path: Array = TP.shortest_path(game.tree, game.allocated, n["id"])
			var locks := path.map(func(m): return "%s=%s" % [game.tree.nodes[m]["uid"], game.lock_reason(m)])
			out.append("nœud clé %s : acquis %s, verrou %s, chemin %s" % [n["uid"], game.allocated.has(n["id"]), game.lock_reason(n["id"]), locks])
	return "cibles du build « %s » : %s" % [bot.builder.name, " | ".join(out)]


func Content_tree_branches() -> Array:
	return load("res://scripts/content.gd").tree().get("branches", [])


func _block(reason: String) -> void:
	var r := _region() if idx < order.size() else "finale"
	print("  BLOCAGE [%s] %s" % [r, reason])
	blocks.append("%s : %s" % [r, reason])
	failures += 1


## --continue-on-block : la région bloquée est forcée (drapeaux posés) pour jouer la suite.
func _force_region() -> void:
	var r := _region()
	print("AVENTURE : région %s forcée (drapeaux du Cœur, du boss et de la fin) pour continuer" % r)
	game.flags[Regions.heart_flag(r)] = true
	game.flags[Regions.boss_flag(r)] = true
	game.flags[Regions.ending_flag(r)] = true
	report[r]["forcee"] = true
	await _reload("région %s forcée" % r)
	obj.check()
	await _finish_region()


func _region_done() -> bool:
	var r := _region()
	if not obj.current(r).is_empty() or not game.flags.get(Regions.ending_flag(r), false):
		return false
	for g in main.orbs_layer.get_children():
		if _is_graft(g):
			return false
	return true


func _finish_region() -> void:
	var r := _region()
	var rep: Dictionary = report[r]
	rep["fin"] = t
	rep["niveau_fin"] = game.level
	rep["morts"] = deaths_before + main.deaths - _region_start_deaths
	rep["boss"] = _boss_total
	print("AVENTURE %4d s  région %s finie en %d s, niveau %d → %d, %d morts, combats de boss %d s%s" % [int(t), r, int(t - float(rep["debut"])), rep["niveau_debut"], game.level, rep["morts"], int(_boss_total), " (FORCÉE)" if rep["forcee"] else ""])
	await _reload("région %s purifiée" % r)
	idx += 1
	if stop_after != "" and r == stop_after:
		stopping = true
		return
	if idx >= order.size():
		_begin_finale()
		return
	_start_region()


# --- Finale ---

func _begin_finale() -> void:
	_finale_start = t
	last_progress = t
	_stuck_pos = Vector2.INF
	bot.finale = true
	bot.goal = ""
	var f = main.get("finale")
	if f == null:
		print("AVENTURE : pas de finale dans ce jeu (main.finale absent) : l'aventure s'arrête au dernier boss")
	else:
		print("AVENTURE %4d s  finale : état « %s »" % [int(t), f.state])


func _finale_over() -> bool:
	var f = main.get("finale")
	if f == null:
		return true
	if _finale_done:
		return true
	if game.flags.get("finale_vaincue", false):
		# Épilogue et générique : le jeu les lance seul ; le robot les passe (voir _epilogue).
		var epi = main.quest_ui.get("epilogue")
		if epi == null or (not epi.active and t - _finale_start > 1.0 and game.flags.get("finale_vaincue", false) and _epilogue_seen):
			_finale_done = true
			return true
	return false


var _epilogue_seen := false


func _finale_blocked() -> bool:
	if _finale_start < 0.0:
		return false
	var f = main.get("finale")
	if f == null:
		return false
	if t - _finale_start > FINALE_MAX or boss_fight_time > BOSS_MAX:
		_block("la finale ne se termine pas : %d s, état « %s », robot : %s, niveau %d, position %s" % [int(t - _finale_start), f.state, bot.goal, game.level, main.player.position.round()])
		return true
	return false


## Épilogue, statistiques et générique de la finale : le robot les fait défiler, puis continue.
func _epilogue(epi) -> void:
	_epilogue_seen = true
	check(paused or epi.visible, "épilogue : affiché")
	check(not main.hud.get_parent().visible and not main.quest_ui._tracker_layer.visible, "épilogue : rien de l'interface de jeu par-dessus")
	epi.set_time(1.0e6)
	epi._on_continue()
	await _frames(2)
	check(not epi.active, "épilogue : « Continuer à jouer » le ferme")
	pending_reload = "après l'épilogue"


## Séquence « région purifiée » : la regarder, puis « Continuer à jouer ».
func _ending() -> void:
	var q = main.quest_ui
	check(not main.hud.get_parent().visible and not q._tracker_layer.visible, "fin de région : rien de l'interface de jeu par-dessus")
	check(paused, "fin de région : jeu en pause")
	for g in main.orbs_layer.get_children():
		if _is_graft(g) and not g.is_queued_for_deletion():
			var id: String = g.graft_id
			g.pick_up()
			check(game.has_graft(id), "greffe ramassée pendant la fin : dans l'inventaire")
	q.ending.set_time(30.0)
	q.ending._on_continue()
	await _frames(2)
	check(not paused and main.hud.get_parent().visible and q._tracker_layer.visible, "« Continuer à jouer » : l'interface revient")
	pending_reload = "après la fin de région"


# --- Sauvegarde et reprise ---

func _snapshot() -> Dictionary:
	return {
		"level": game.level, "xp": game.xp, "points": game.points, "kills": game.kills,
		"uids": game.allocated_uids(), "inventory": game.graft_inventory.duplicate(),
		"grafts": game.grafts.duplicate(), "flags": game.flags.duplicate(true),
		"ground": main.export_ground_grafts(),
	}


## Greffes de l'inventaire et du sol, triées : de quoi comparer deux états sans compter l'endroit.
func _graft_ids(snap: Dictionary) -> Array:
	var ids: Array = []
	for g in snap["inventory"]:
		ids.append(str(g))
	for g in snap["ground"]:
		ids.append(str(g[2]))
	ids.sort()
	return ids


func _same_ground(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i][2]) != str(b[i][2]) or Vector2(a[i][0], a[i][1]).distance_to(Vector2(b[i][0], b[i][1])) > 20.0:
			return false
	return true


func _same(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < 0.01
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b


func _reload(why: String) -> void:
	reloads += 1
	if idx < order.size() and report.has(_region()):
		report[_region()]["reprises"] += 1
	bot.hold = true
	var before := _snapshot()
	var saved: bool = save.save_now(main, path)
	check(saved, "reprise %s : sauvegarde écrite" % why)
	deaths_before += main.deaths
	var old = main
	root.remove_child(old)
	old.free()
	game.reset()
	await _new_main(path)
	var after := _snapshot()
	var diff: Array = []
	# Une greffe au sol près du joueur est ramassée dans les images qui suivent le chargement : ce
	# n'est pas un défaut de la sauvegarde tant que « inventaire + sol » est inchangé.
	var grafts_same := _graft_ids(before) == _graft_ids(after)
	for k in before:
		if grafts_same and (k == "inventory" or k == "ground"):
			continue
		if k == "flags":
			for f in before["flags"]:
				if not _same(before["flags"][f], after["flags"].get(f)):
					diff.append("%s: %s -> %s" % [f, before["flags"][f], after["flags"].get(f)])
			for f in after["flags"]:
				if not before["flags"].has(f):
					diff.append("%s ajouté" % f)
		elif k == "ground" and _same_ground(before[k], after[k]):
			pass
		elif not _same(before[k], after[k]):
			diff.append("%s: %s -> %s" % [k, before[k], after[k]])
	check(diff.is_empty(), "reprise %s : partie retrouvée à l'identique %s" % [why, "" if diff.is_empty() else str(diff)])
	_coherence("reprise %s" % why)
	_stuck_pos = Vector2.INF
	bot.hold = false


## État du monde cohérent avec les drapeaux, dans toutes les régions (et la finale, si elle existe).
func _coherence(where: String) -> void:
	obj.check()
	var problems: Array = []
	for o in obj.list():
		if obj.condition_met(o) and not obj.is_done(o["id"]):
			problems.append("« %s » rempli mais pas accompli" % o["id"])
	for id in Regions.ids():
		var heart = main.hearts[id]
		var arena = main.arenas[id]
		var purified: bool = game.flags.get(Regions.heart_flag(id), false)
		var beaten: bool = game.flags.get(Regions.boss_flag(id), false)
		if purified != (heart.state == "purifie"):
			problems.append("%s : Cœur %s, drapeau %s" % [id, heart.state, purified])
		if beaten and arena.state != "vaincue":
			problems.append("%s : arène %s, boss vaincu" % [id, arena.state])
		if not beaten and purified and not arena.state in ["ouverte", "combat"]:
			problems.append("%s : arène %s, Cœur purifié" % [id, arena.state])
		if not purified and arena.state != "fermee":
			problems.append("%s : arène %s, Cœur pas purifié" % [id, arena.state])
	var fin = main.get("finale")
	if fin != null:
		var all: bool = Regions.all_purified(game.flags)
		if game.flags.get("finale_vaincue", false):
			if fin.state != "vaincue":
				problems.append("finale %s, drapeau finale_vaincue" % fin.state)
		elif all and not fin.state in ["ouverte", "combat"]:
			problems.append("finale %s, toutes les régions purifiées" % fin.state)
		elif not all and fin.state != "fermee":
			problems.append("finale %s, régions pas toutes purifiées" % fin.state)
	for a in main.altars:
		if a.active != bool(game.flags.get(a.flag(), false)):
			problems.append("%s : actif %s, drapeau %s" % [a.flag(), a.active, game.flags.get(a.flag(), false)])
	for s in main.sanctuaries:
		if s.is_lit() != bool(game.flags.get("sanctuaire_" + s.id, false)):
			problems.append("sanctuaire %s" % s.id)
	var sap := float(game.flags.get("seve_perdue", 0.0))
	var has_sap: bool = main.lost_sap != null and is_instance_valid(main.lost_sap)
	if (sap > 0.0) != has_sap:
		problems.append("sève perdue %s, nœud %s" % [sap, has_sap])
	check(problems.is_empty(), "%s : état cohérent %s" % [where, "" if problems.is_empty() else str(problems)])


# --- Bilan ---

func _final() -> void:
	print("Bilan")
	var done := 0
	for r in order:
		if report.has(r) and report[r].has("fin"):
			done += 1
	check(done == order.size() or not blocks.is_empty() or stop_after != "", "toutes les régions sont finies (%d sur %d)" % [done, order.size()])
	if blocks.is_empty() and stop_after == "":
		check(Regions.all_purified(game.flags), "les boss de toutes les régions sont vaincus")
		for r in order:
			var o: Array = obj.main_list().filter(func(x): return str(x.get("region", "")) == r)
			for x in o:
				check(obj.is_done(x["id"]), "objectif principal « %s » accompli" % x["title"])
		var deaths: int = deaths_before + (main.deaths if main != null and is_instance_valid(main) else 0)
		check(int(game.flags.get("stat_morts", 0)) == deaths, "les %d morts sont toutes comptées dans la partie (%d)" % [deaths, int(game.flags.get("stat_morts", 0))])
		var fin = main.get("finale") if main != null and is_instance_valid(main) else null
		if fin != null:
			check(game.flags.get("finale_vaincue", false), "finale vaincue")
			check(_epilogue_seen, "épilogue et générique passés")
		check(reloads >= order.size() * 3, "au moins %d reprises (%d)" % [order.size() * 3, reloads])
	print("=== AVENTURE : résumé (graine %d) ===" % seed_n)
	for r in order:
		if not report.has(r):
			print("  %-6s non jouée" % r)
		elif not report[r].has("fin"):
			var rp: Dictionary = report[r]
			print("  %-6s INCOMPLÈTE depuis %d s, niveau %d, build %s" % [r, int(rp["debut"]), rp["niveau_debut"], rp["build"]])
		else:
			var rp: Dictionary = report[r]
			print("  %-6s %4d s  niveau %2d → %2d  %2d morts  boss %3d s  %2d reprises  build %s%s" % [r, int(float(rp["fin"]) - float(rp["debut"])), rp["niveau_debut"], rp["niveau_fin"], rp["morts"], int(rp["boss"]), rp["reprises"], rp["build"], "  FORCÉE" if rp["forcee"] else ""])
	if _finale_start >= 0.0:
		print("  finale %4d s  %s" % [int(t - _finale_start), "vaincue" if game.flags.get("finale_vaincue", false) else "pas vaincue"])
	for b in blocks:
		print("  BLOCAGE : " + b)
