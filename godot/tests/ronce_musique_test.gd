## La Mère-Ronce sur son morceau (ronce.wav d'Antoine, assets/music/hand/ronce.json) :
##   - le morceau est complet : approche, intro d'une mesure, trois drops (le troisième pour la phase
##     exaltée), fin ; 160 BPM ;
##   - l'approche monte avec la distance à l'enceinte ouverte, rien quand elle est fermée ;
##   - à l'entrée, elle charge pendant la mesure d'avant le drop, invulnérable, et frappe sur le drop ;
##   - chaque phase joue sa partition (SCORE) : aucun coup sauté, chaque frappe sur un coup, toutes les
##     percussions retenues par la phase attaquent, et la charge monte d'une phase à l'autre ;
##   - à chaque changement de phase, elle attend tout le drop (invulnérable) et reprend sur sa mesure ;
##   - au cycle 2 (-- --cycle=2), la phase exaltée a son drop et sa partition, la plus chargée.
## Sans son (tests sans fenêtre) : la même grille sur le temps du jeu (boss_sync.gd).
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/ronce_musique_test.gd [-- --cycle=2]
## Ne lit ni n'écrit la sauvegarde.
extends SceneTree

const BossTrack = preload("res://scripts/boss_track.gd")

var failures := 0
var main


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _steps(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, limit := 900) -> bool:
	for i in limit:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _run() -> void:
	var cycle: int = root.get_node("Cycles").current()
	print("Cycle %d" % cycle)
	_check_data()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	await _steps(3)
	await _fight(cycle)
	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)


func _check_data() -> void:
	print("Morceau de la Mère-Ronce")
	var d := BossTrack.track_data("ronce")
	check(not d.is_empty() and float(d["bpm"]) == 160.0 and int(d["bar_beats"]) == 4, "ronce.json : 160 BPM, 4/4")
	var clips: Dictionary = d.get("clips", {})
	for c in ["approche", "intro", "drop_1", "drop_2", "drop_3", "fin"]:
		check(clips.has(c) and ResourceLoader.exists("res://assets/music/hand/" + str(clips[c]["fichier"])), "clip %s présent" % c)
	check(int(clips["intro"]["boucle_depuis"]) == 1, "l'intro est la mesure d'avant le drop (une mesure)")
	check(bool(clips["approche"]["boucle"]) and int(clips["approche"]["boucle_depuis"]) == 8, "l'approche boucle sur ses 8 dernières mesures")
	for c in clips:
		var info: Dictionary = clips[c]
		var bars := int(info["mesures"])
		if bool(info["boucle"]):
			check(int(info["echantillons"]) == bars * 66150, "%s : %d mesures entières (%d échantillons)" % [c, bars, int(info["echantillons"])])
	for s in ["boucle_1", "boucle_2", "boucle_3", "boucle_4"]:
		var sec: Dictionary = d["sections"].get(s, {})
		check(sec.has("coups") and (sec["coups"]["kick"] as Array).size() == int(sec["mesures"][1]) - int(sec["mesures"][0]) + 1, "%s : coups de batterie relevés mesure par mesure" % s)


func _fight(cycle: int) -> void:
	var game = root.get_node("Game")
	var arena = main.arenas.get("ronce")
	var p = main.player
	print("Approche")
	p.position = arena.entrance()
	await _steps(2)
	check(arena.state == "fermee" and arena.approach_level() == 0.0, "enceinte fermée : pas d'approche")
	for h in main.region_hearts["ronce"]:
		game.flags[h.flag] = true
	await _steps(3)
	check(arena.state == "ouverte", "Cœurs purifiés : l'enceinte s'ouvre")
	var near: float = arena.approach_level()
	p.position = arena.center + (arena.entrance() - arena.center).normalized() * (arena.max_radius + 700.0)
	var mid: float = arena.approach_level()
	p.position = arena.center + (arena.entrance() - arena.center).normalized() * (arena.max_radius + 1600.0)
	var far: float = arena.approach_level()
	check(near > 0.85 and mid > 0.1 and mid < near and far == 0.0, "l'approche monte avec la distance (%.2f loin, %.2f, %.2f à l'entrée)" % [far, mid, near])

	print("Entrée et charge")
	p.position = arena.center + Vector2(0, 250)
	p.hp = 1.0e6
	p.invuln = 1.0e6
	await _steps(3)
	var boss = arena.boss
	check(is_instance_valid(boss) and boss.sync != null, "la Mère-Ronce s'éveille, calée sur son morceau")
	if not is_instance_valid(boss):
		return
	var sync = boss.sync
	check(sync.intro_bars == 1 and sync.stage == "intro", "l'intro : une mesure (la dernière avant le drop)")
	var hp0: float = boss.hp
	boss.take_damage(500.0, false)
	check(boss.hp == hp0 and boss.music_waiting(), "pendant la charge, elle ne prend pas de coups")
	await _steps(20)
	check(boss.charge >= 0.0 and boss.charge_energy() >= 0.0, "elle charge")
	check(await _until(func(): return not boss.music_waiting(), int(2.5 * sync.bar * 60.0)), "puis le combat part")
	check(absf(sync.bars_now() - 1.0) < 0.05, "sur le drop : la mesure 2 du morceau (%.2f)" % sync.bars_now())
	boss.take_damage(10.0, false)
	check(boss.hp < hp0, "elle prend des coups dès le drop")

	var weights := {}
	for ph in [1, 2, 3, 4]:
		if ph == 4 and cycle < 2:
			break
		if ph > 1:
			var limit: float = float(boss.phase_limits[ph - 2])
			boss.hp = boss.max_hp * (limit - 0.02)
			check(await _until(func(): return boss.phase == ph, 300), "phase %d" % ph)
			await _steps(2)
			check(sync.stage == "drop" and boss.music_waiting(), "phase %d : elle attend le drop, invulnérable" % ph)
			var h1: float = boss.hp
			boss.take_damage(500.0, false)
			check(boss.hp == h1, "phase %d : pas de coups pendant le drop" % ph)
			var resume: int = sync.resume_bar
			check(await _until(func(): return not boss.music_waiting(), int(4.0 * sync.bar * 60.0)), "phase %d : le combat reprend après le drop" % ph)
			check(absf(sync.bars_now() - resume) < 0.05, "phase %d : reprise sur la mesure %d (%.2f)" % [ph, resume, sync.bars_now()])
		await _play_phase(boss, ph, weights)
	for ph in weights:
		if weights.has(ph - 1):
			check(weights[ph] > weights[ph - 1], "phase %d plus chargée que la phase %d (%.2f > %.2f par temps)" % [ph, ph - 1, weights[ph], weights[ph - 1]])
	boss.take_damage(boss.max_hp * 4.0, false)
	await _steps(3)
	check(boss.dead and arena.state == "vaincue", "victoire")


## Joue une boucle entière de la phase : chaque frappe tombe sur la partition, aucun coup sauté, et
## toutes les percussions que la phase retient portent une attaque.
func _play_phase(boss, ph: int, weights: Dictionary) -> void:
	var sync = boss.sync
	await _steps(2)
	check(boss.score_phase == ph, "phase %d : la partition mène le combat" % ph)
	var loop: String = boss.SCORE[ph]["loop"]
	var sec: Dictionary = sync.data["sections"][loop]
	var bars: int = int(sec["mesures"][1]) - int(sec["mesures"][0]) + 1
	check(boss.score_len == bars * 4.0, "phase %d : la partition suit %s (%d mesures)" % [ph, loop, bars])
	# Percussions retenues par la phase (DRUMS_POWER) : toutes ont une attaque.
	var pw: Dictionary = boss.DRUMS_POWER[ph]
	var want := 0
	for src in ["kick", "kick_doux", "caisse", "charleston", "caisse_douce"]:
		var grid := 1
		if src == "caisse":
			if int(pw["roll"]) <= 0:
				continue
			grid = int(pw["roll_grid"])
		elif src == "charleston":
			grid = int(pw["spark_grid"])
		elif src == "caisse_douce" and int(pw["prick"]) <= 0:
			continue
		for m in bars:
			var phrase: Dictionary = boss.SCORE[ph]["phrases"][floori(m / 4.0) % boss.SCORE[ph]["phrases"].size()]
			var g := 1 if phrase.get("deluge", false) else grid
			for six in sec["coups"][src][m]:
				if int(six) % g == 0:
					want += 1
	check(boss.score_drums.size() == want, "phase %d : chaque percussion retenue attaque (%d attaques, %d coups)" % [ph, boss.score_drums.size(), want])
	weights[ph] = boss.score_weight()
	var skipped0: int = boss.score_skipped
	var played0: int = boss.score_played
	var drums0: Dictionary = boss.drums_played.duplicate()
	var off: Array = []
	var was: String = boss.stage
	var frames := int(bars * sync.bar * 60.0)
	# Le héros frappe de lui-même : la vie de la phase est tenue pour jouer toute la boucle.
	var keep: float = boss.hp
	for i in frames:
		main.player.hp = 1.0e6
		boss.hp = maxf(boss.hp, keep)
		if boss.phase != ph:
			break
		if boss.stage == "frappe" and was == "annonce" and boss.attack != "racines":
			var local := fposmod(boss.beats_now() - boss.score_origin, boss.score_len)
			if not boss.score_hits.any(func(h): return absf(h["beat"] - local) < 0.1 or absf(h["beat"] - local + boss.score_len) < 0.1):
				off.append(snappedf(local, 0.01))
		was = boss.stage
		await physics_frame
	check(off.is_empty() and boss.score_skipped == skipped0, "phase %d : chaque frappe sur un coup de la partition, aucun sauté (hors partition : %s, sautés : %d)" % [ph, off, boss.score_skipped - skipped0])
	check(boss.score_played - played0 >= boss.score_hits.size() - 1, "phase %d : la partition joue (%d attaques sur %d coups)" % [ph, boss.score_played - played0, boss.score_hits.size()])
	var played := {}
	for k in boss.drums_played:
		played[k] = int(boss.drums_played[k]) - int(drums0.get(k, 0))
	check(played.get("pouls", 0) + played.get("onde", 0) > 0 and played.get("aiguille", 0) > 0, "phase %d : la batterie attaque (%s)" % [ph, played])
