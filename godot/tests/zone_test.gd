## Robot « zone complète » : une nouvelle partie jouée par le robot (scripts/zone_bot.gd) jusqu'à
## la Mère-Ronce et la fin de la tranche, en passant par des sauvegardes et des reprises à chaque
## objectif principal, des reprises en plein siège et en plein combat, une mort pendant le siège et
## une mort face au boss, une greffe ramassée pendant une transition et des changements de
## résolution. À chaque image, il vérifie que l'écran reste lisible et cohérent :
## - le cadre d'objectif, le journal, la carte et la flèche suivent l'objectif en cours ;
## - une seule annonce à la fois, jamais sur le cadre d'objectif ni sur une barre de combat ;
## - pendant le combat de boss, seules les informations du combat restent ;
## - rien par-dessus l'écran de mort et la séquence de fin.
## Échoue sur un blocage (aucun objectif principal accompli pendant STALL secondes de jeu), un
## état incohérent ou une reprise qui ne retrouve pas la partie.
##
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/zone_test.gd -- --seed=1
## tools/zone.sh lance 5 graines en parallèle et cherche aussi les erreurs de script.
## Sauvegarde dans user://tests/ : la partie du joueur n'est pas touchée.
extends SceneTree


const DT := 1.0 / 60.0
## Temps de jeu maximal, et temps sans objectif principal accompli au-delà duquel c'est un blocage.
const MAX_TIME := 2700.0
const STALL := 720.0
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(3440, 1440), Vector2i(1920, 1080)]

var failures := 0
var game
var obj
var save
var main
var bot
var seed_n := 1
## Région jouée (« -- --region=<id> », Ronce par défaut) et ses drapeaux.
var region := "ronce"
var path := ""
var t := 0.0
var last_progress := 0.0
var pending_reload := ""
## Évènements provoqués une seule fois par partie (mort au siège, reprise au boss…).
var done_events := {}
## Défauts vus à chaque image : nom -> [nombre, première fois (s), détail].
var violations := {}
var reloads := 0
## Morts des scènes de jeu déjà quittées (chaque reprise repart de zéro).
var deaths_before := 0
var boss_fight_time := 0.0
var _log_next := 0.0
var _main_done_before := 0


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


## Greffe au sol (graft_pickup.gd). Les scripts du jeu se chargent à l'exécution : ils
## utilisent les autoloads, inconnus à la compilation d'un script lancé par « -s ».
func _is_graft(n) -> bool:
	return n.get("graft_id") != null


func _new_main(resume := "") -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.zone_bot = bot
	main.resume_from = resume
	root.add_child(main)
	await _frames(3)


func _run() -> void:
	game = root.get_node("Game")
	obj = root.get_node("Objectives")
	save = root.get_node("SaveGame")
	seed_n = game.forced_seed if game.forced_seed >= 0 else 1
	path = "user://tests/zone_%d.json" % seed_n
	save.delete_save(path)
	game.reset()
	region = load("res://scripts/main.gd").focus_region()
	# Le build du robot : « fouet » pour Ronce, sinon le premier build de la branche de la région.
	var build := "fouet"
	if region != "ronce":
		var all: Dictionary = load("res://scripts/build_bot.gd").load_all()
		for k in all:
			if str(all[k].get("branch", "")) == load("res://scripts/regions.gd").branch_of(region):
				build = k
				break
	bot = load("res://scripts/zone_bot.gd").new(build, region)
	await _new_main()
	obj.completed.connect(_on_completed)
	print("ZONE graine %d : nouvelle partie" % seed_n)
	check(obj.current(region).get("id", "") == obj.main_list()[0]["id"] or obj.current(region).get("region", "") == region, "nouvelle partie : l'aventure commence par le premier nœud")
	check(main.hud.hint_visible(), "l'aide de départ est affichée")

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
		_invariants()
		await _forced_events()
		if pending_reload != "":
			var why := pending_reload
			pending_reload = ""
			await _reload(why)
		if _finished():
			break
		if t - last_progress > STALL:
			check(false, "BLOCAGE : aucun objectif principal accompli depuis %d s (objectif « %s », robot : %s, niveau %d)" % [int(t - last_progress), obj.current(region).get("id", ""), bot.goal, game.level])
			break
		if t > MAX_TIME:
			check(false, "partie trop longue (%d s), objectif « %s »" % [int(t), obj.current().get("id", "")])
			break

	await _final()
	for k in violations:
		var v: Array = violations[k]
		check(false, "%s : %d image(s), la première à %d s (%s)" % [k, v[0], int(v[1]), v[2]])
	print("ZONE graine %d : %d s de jeu, niveau %d, %d morts, %d reprises" % [seed_n, int(t), game.level, int(game.flags.get("stat_morts", 0)), reloads])
	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	save.delete_save(path)
	quit(1 if failures > 0 else 0)


func _on_completed(id: String) -> void:
	var o: Dictionary = obj.get_def(id)
	print("ZONE %4d s  objectif accompli : %s (niveau %d)" % [int(t), id, game.level])
	if o.get("main", false):
		last_progress = t
		# Quitter et reprendre à chaque étape de l'aventure.
		pending_reload = "après « %s »" % id


func _track() -> void:
	if main.arena.in_combat():
		boss_fight_time += DT
	else:
		boss_fight_time = 0.0
	if t >= _log_next:
		_log_next += 60.0
		print("ZONE %4d s  niveau %2d  objectif %-14s robot : %-32s vie %d/%d  morts %d" % [int(t), game.level, obj.current(region).get("id", "—"), bot.goal, int(main.player.hp), int(game.stats["max_hp"]), main.deaths])
		if _is_heart_step(obj.current(region)):
			print("       Cœur : %s, %.1f s tenues, joueur à %d px du centre (zone %d), %d ennemis" % [main.heart.state, main.heart.progress, int(main.player.position.distance_to(main.heart.center)), int(main.heart.zone), main.enemies.size()])


func _finished() -> bool:
	if not obj.current(region).is_empty() or not game.flags.get(region + "_fin_vue", false):
		return false
	for g in main.orbs_layer.get_children():
		if _is_graft(g):
			return false
	return true


# --- Ce qui doit rester vrai à chaque image ---

func _bad(name: String, detail := "") -> void:
	if not violations.has(name):
		violations[name] = [0, t, detail]
		print("  DÉFAUT à %d s : %s %s" % [int(t), name, detail])
	violations[name][0] += 1


func _invariants() -> void:
	var hud = main.hud
	var q = main.quest_ui
	var banner: String = hud.visible_banner()
	var tracker_on: bool = q._tracker_layer.visible
	if main.arena.in_combat():
		if tracker_on:
			_bad("cadre d'objectif visible pendant le boss")
		if hud._corner.visible:
			_bad("infos de partie visibles pendant le boss")
		if hud.hint_visible():
			_bad("aide de départ pendant le boss")
		if banner != "" and hud.banner_kind != "combat":
			_bad("annonce hors combat pendant le boss", banner)
	if hud.death_screen.is_showing() and banner != "":
		_bad("annonce sur l'écran de mort", banner)
	if hud.hint_visible() and hud.hint_time > 0.6:
		for e in main.enemies_near(main.player.position, hud.HINT_ENEMY_NEAR):
			_bad("aide de départ pendant un combat")
			break
	if banner != "":
		var r: Rect2 = hud._banner.get_global_rect()
		if tracker_on and r.intersects(q.tracker._panel.get_global_rect()):
			_bad("annonce sur le cadre d'objectif", banner)
		for bar in [main.heart.bar, main.arena.bar]:
			if bar.visible and r.intersects(_bar_rect(bar)):
				_bad("annonce sur une barre de combat", banner)
	for bar in [main.heart.bar, main.arena.bar]:
		if bar.visible and tracker_on and q.tracker._panel.get_global_rect().intersects(_bar_rect(bar)):
			_bad("cadre d'objectif sur une barre de combat")
	# Le cadre suit l'objectif en cours.
	var cur: Dictionary = obj.followed()
	var want: String = cur.get("title", "Tous les objectifs sont accomplis")
	if q.tracker._title.text != want:
		_bad("cadre d'objectif en retard", "%s au lieu de %s" % [q.tracker._title.text, want])


## Rectangle à l'écran du cadre d'une barre de combat (boss_bar.gd).
func _bar_rect(bar) -> Rect2:
	for c in bar.get_children():
		if c is Control and c.visible and c.size.x > 0.0:
			return c.get_global_rect()
	return Rect2()


## Vrai pour l'étape « purifier le Cœur » de la région (sa cible est le Cœur).
func _is_heart_step(o: Dictionary) -> bool:
	return str(o.get("target", {}).get("type", "")) == "heart"


## État du monde, de l'objectif, du journal et de la carte cohérents entre eux.
func _coherence(where: String) -> void:
	obj.check()
	var problems: Array = []
	# Objectifs de la région jouée et objectifs communs : les autres régions attendent leur tour.
	var mains: Array = obj.main_list().filter(func(o): return str(o.get("region", "")) in ["", region])
	var cur: Dictionary = obj.current(region)
	var ci: int = mains.find(cur)
	# Une étape franchie plus loin dans la suite ne compte que dans la même région que l'objectif
	# en cours (ou pour un objectif commun) : celles d'une autre région se jouent à part.
	var cur_reg := str(cur.get("region", ""))
	for i in mains.size():
		if ci >= 0 and i > ci and mains[i].get("milestone", false) and obj.is_done(mains[i]["id"]) \
				and (cur_reg == "" or str(mains[i].get("region", "")) == cur_reg):
			problems.append("objectif en cours « %s » alors que l'étape « %s » est franchie" % [cur["id"], mains[i]["id"]])
	for o in obj.list():
		if obj.condition_met(o) and not obj.is_done(o["id"]):
			problems.append("« %s » rempli mais pas accompli" % o["id"])
	var purified: bool = game.flags.get(main.heart.flag, false)
	var beaten: bool = game.flags.get(main.arena.flag, false)
	if purified != (main.heart.state == "purifie"):
		problems.append("Cœur %s, drapeau %s" % [main.heart.state, purified])
	if beaten and main.arena.state != "vaincue":
		problems.append("arène %s, boss vaincu" % main.arena.state)
	if not beaten and purified and not main.arena.state in ["ouverte", "combat"]:
		problems.append("arène %s, Cœur purifié" % main.arena.state)
	if not purified and main.arena.state != "fermee":
		problems.append("arène %s, Cœur pas purifié" % main.arena.state)
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
	# Suivi, journal et carte lisent le même objectif.
	var q = main.quest_ui
	q.tracker.refresh()
	# Le cadre et le journal suivent la région où se tient le joueur (Objectives.followed).
	var shown: Dictionary = obj.followed()
	var want: String = shown.get("title", "Tous les objectifs sont accomplis")
	if q.tracker._title.text != want:
		problems.append("cadre « %s » au lieu de « %s »" % [q.tracker._title.text, want])
	if not shown.is_empty() and q.tracker._head.text.find("%d / " % obj.current_rank(obj.followed_region())) < 0:
		problems.append("rang du cadre « %s »" % q.tracker._head.text)
	q.journal.refresh()
	var titles: Array = q.journal.find_children("*", "Label", true, false).map(func(l): return l.text)
	# Le journal déplie la section de l'objectif suivi : son titre y est, les autres sections sont repliées.
	var fol: Dictionary = obj.followed()
	if not fol.is_empty() and not titles.any(func(x): return str(x).begins_with(fol["title"])):
		problems.append("journal sans « %s »" % fol["title"])
	check(problems.is_empty(), "%s : état cohérent %s" % [where, "" if problems.is_empty() else str(problems)])


# --- Sauvegarde et reprise ---

func _snapshot() -> Dictionary:
	return {
		"level": game.level, "xp": game.xp, "points": game.points, "kills": game.kills,
		"uids": game.allocated_uids(), "inventory": game.graft_inventory.duplicate(),
		"grafts": game.grafts.duplicate(), "flags": game.flags.duplicate(true),
		"ground": main.export_ground_grafts(),
	}


## Greffes au sol : mêmes greffes, au même endroit à quelques pixels près (une greffe proche du
## joueur est déjà attirée vers lui pendant les images qui suivent le chargement).
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
	var in_fight: bool = main.arena.in_combat()
	bot.hold = true
	var before := _snapshot()
	check(save.save_now(main, path), "reprise %s : sauvegarde écrite" % why)
	deaths_before += main.deaths
	var old = main
	root.remove_child(old)
	old.free()
	game.reset()
	await _new_main(path)
	var after := _snapshot()
	var diff: Array = []
	for k in before:
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
	if in_fight:
		check(not main.arena.in_combat() and main.player.position.distance_to(main.arena.entrance()) < 2.0 \
			and main.player.hp >= game.stats["max_hp"] - 0.1, "reprise en plein combat : devant l'arène, vie pleine, Mère-Ronce rendormie")
	_coherence("reprise %s" % why)
	bot.hold = false


# --- Évènements provoqués ---

func _forced_events() -> void:
	var heart = main.heart
	var arena = main.arena
	if heart.state == "siege" and heart.progress > 12.0 and not done_events.has("mort_siege"):
		done_events["mort_siege"] = true
		_kill_player()
		await physics_frame
		check(heart.state == "fletri" and heart.progress == 0.0, "mort pendant le siège : le Cœur se rendort")
		check(main.hud.death_screen.is_showing(), "mort pendant le siège : écran de mort")
		check(_is_heart_step(obj.current(region)), "mort pendant le siège : l'objectif reste le Cœur")
		_coherence("mort pendant le siège")
	elif heart.state == "siege" and heart.progress > 8.0 and done_events.has("mort_siege") and not done_events.has("reprise_siege"):
		done_events["reprise_siege"] = true
		pending_reload = "en plein siège"
	elif arena.in_combat() and boss_fight_time > 6.0 and not done_events.has("reprise_boss"):
		done_events["reprise_boss"] = true
		pending_reload = "en plein combat de boss"
	elif arena.in_combat() and is_instance_valid(arena.boss) and arena.boss.phase >= 2 and not done_events.has("mort_boss"):
		done_events["mort_boss"] = true
		game.xp += 5.0  # de la sève à laisser au sol
		_kill_player()
		await physics_frame
		await physics_frame
		check(not arena.in_combat() and arena.state == "ouverte" and not main.spawn_paused, "mort face au boss : arène rouverte, Mère-Ronce rendormie")
		var sap = main.lost_sap
		check(sap != null and sap.position.distance_to(arena.center) > arena.max_radius - 70.0 + 20.0,
			"sève perdue dans l'arène : posée devant l'entrée, hors de la zone qui réveille la Mère-Ronce")
		check(main.quest_ui.tracker_shown(), "mort face au boss : le cadre d'objectif revient")
		_coherence("mort face au boss")
		pending_reload = "avec la sève au sol"
	elif t > 40.0 and not done_events.has("resolution"):
		done_events["resolution"] = true
		await _resolutions("en exploration")
	elif arena.in_combat() and boss_fight_time > 3.0 and done_events.has("reprise_boss") and not done_events.has("resolution_boss"):
		done_events["resolution_boss"] = true
		await _resolutions("pendant le boss")
	# Greffe ramassée pendant une transition : l'Arbre s'ouvre au moment où elle tombe.
	if not done_events.has("greffe_arbre"):
		for g in main.orbs_layer.get_children():
			if _is_graft(g) and not g.is_queued_for_deletion() and g.pop > 0.0:
				done_events["greffe_arbre"] = true
				await _graft_while_tree_open(g)
				break


func _kill_player() -> void:
	main.player.hp = 0.0
	main.player_died()


## L'Arbre de vie s'ouvre (jeu en pause) au moment où une greffe tombe ; elle est ramassée
## pendant que l'Arbre est ouvert : l'inventaire de l'Arbre la montre, l'annonce attend la fermeture.
func _graft_while_tree_open(g) -> void:
	var id: String = g.graft_id
	main.tree_ui.toggle()
	await process_frame
	check(paused and main.tree_ui.visible, "greffe en vol : l'Arbre s'ouvre et met le jeu en pause")
	g.pick_up()
	await process_frame
	check(game.has_graft(id) and not game.grafts_on_ground.has(id), "greffe ramassée Arbre ouvert : elle est dans l'inventaire")
	check(game.free_grafts().has(id), "et posable dans l'Arbre")
	main.tree_ui.toggle()
	await process_frame
	check(not paused, "l'Arbre se referme, le jeu reprend")
	var queued: bool = main.hud.banner_queue.any(func(b): return str(b[0]).begins_with("Greffe trouvée")) or main.hud.banner_text.begins_with("Greffe trouvée")
	check(queued, "l'annonce de la greffe est faite après la fermeture")


## Changement de résolution en cours de partie : l'interface reste dans l'écran.
func _resolutions(where: String) -> void:
	var start: Vector2i = root.size
	for res in RESOLUTIONS:
		root.size = res
		await _frames(3)
		var view: Rect2 = root.get_visible_rect()
		var out: Array = []
		var rects := {
			"cadre d'objectif": main.quest_ui.tracker._panel.get_global_rect() if main.quest_ui._tracker_layer.visible else Rect2(),
			"annonce": main.hud._banner.get_global_rect() if main.hud.visible_banner() != "" else Rect2(),
			"barre du boss": _bar_rect(main.arena.bar) if main.arena.bar.visible else Rect2(),
			"barre du Cœur": _bar_rect(main.heart.bar) if main.heart.bar.visible else Rect2(),
		}
		for s in main.hud._slots:
			rects["emplacement %d" % s.index] = s.get_global_rect()
		for k in rects:
			var r: Rect2 = rects[k]
			if r.size != Vector2.ZERO and not view.grow(1.0).encloses(r):
				out.append("%s %s hors de %s" % [k, r, view])
		check(out.is_empty(), "résolution %dx%d %s : interface dans l'écran %s" % [res.x, res.y, where, "" if out.is_empty() else str(out)])
	root.size = start
	await _frames(2)


# --- Fin ---

func _ending() -> void:
	var q = main.quest_ui
	check(not main.hud.get_parent().visible and not q._tracker_layer.visible, "fin de la tranche : rien de l'interface de jeu par-dessus")
	check(paused and game.flags.get(region + "_fin_vue", false), "fin de la tranche : jeu en pause, fin notée comme vue")
	# Une greffe ramassée pendant la séquence de fin (transition) n'est pas perdue.
	for g in main.orbs_layer.get_children():
		if _is_graft(g) and not g.is_queued_for_deletion():
			var id: String = g.graft_id
			g.pick_up()
			check(game.has_graft(id), "greffe ramassée pendant la fin : dans l'inventaire")
	q.ending.set_time(30.0)
	q.ending._on_continue()
	await _frames(2)
	check(not paused and main.hud.get_parent().visible and q._tracker_layer.visible, "« Continuer à jouer » : l'interface revient")
	_coherence("après la fin")
	pending_reload = "après la fin"


func _final() -> void:
	print("Bilan")
	for o in obj.main_list():
		if str(o.get("region", "")) in ["", region]:
			check(obj.is_done(o["id"]), "objectif principal « %s » accompli" % o["title"])
	check(game.flags.get(region + "_fin_vue", false) and not obj.ending_due(), "fin vue une seule fois")
	var boss_graft := str(load("res://scripts/content.gd").rewards().get("boss", {}).get(region, {}).get("graft", ""))
	check(boss_graft == "" or game.has_graft(boss_graft), "greffe du boss dans l'inventaire")
	check(done_events.has("mort_siege") and done_events.has("mort_boss") and done_events.has("reprise_boss"), "morts et reprises provoquées en route (%s)" % ", ".join(done_events.keys()))
	check(reloads >= 8, "au moins 8 reprises (%d)" % reloads)
	var deaths: int = deaths_before + main.deaths
	check(int(game.flags.get("stat_morts", 0)) == deaths, "les %d morts sont toutes comptées dans la partie (%d)" % [deaths, int(game.flags.get("stat_morts", 0))])
