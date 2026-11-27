## Test des moments forts (jalon Éclat, tâche A, scripts/moments.gd) : impact frames « encre » et
## « region », priorités (un moment plus fort remplace un plus faible, jamais l'inverse), options à 0
## (contour sans éclair, caméra immobile, vitesse normale), plafond de 3 éclairs par seconde sur un
## combat de boss simulé, ralenti réservé aux Cœurs et aux boss, et vitesse du jeu toujours revenue à 1.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/moments_test.gd
extends SceneTree

const Content = preload("res://scripts/content.gd")

var failures := 0
var main
var settings


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


## Attend « sec » secondes du temps réel des moments (leur horloge : delta ramené à l'échelle du jeu,
## plafonné à 0,1 s par image). Pas l'horloge murale : sur une machine chargée, une image longue
## faisait dépasser l'attente alors que les moments n'avaient pas encore avancé.
## Garde-fou : au plus 20 images par seconde attendue, plus 120.
func _wait_real(sec: float) -> void:
	var end: float = main.moments._clock + sec
	var guard := int(sec * 20.0) + 120
	while main.moments._clock < end and guard > 0:
		guard -= 1
		await process_frame


## Termine tout moment en cours (impact frame, ralenti, caméra, arrêt sur image).
func _settle(m) -> void:
	m._end_frame()
	m._slow = {}
	m._zoom = {}
	m._focus = {}
	m._kick = Vector2.ZERO
	m._flashes = []
	m._crit_cd = 0.0
	main.fx._hitstop_left = 0.0
	main.fx._hitstop_cd = 0.0
	main.fx._apply_time()


func _run() -> void:
	settings = root.get_node("Settings")
	var saved := [settings.reduce_effects, settings.hitstop_scale, settings.flash_scale, settings.shake_scale]
	settings.reduce_effects = false
	settings.hitstop_scale = 1.0
	settings.flash_scale = 1.0
	settings.shake_scale = 1.0

	print("Données")
	var feel := Content.feel()
	for section in ["impact_frame", "camera", "slowmo"]:
		check(feel.get(section) is Dictionary, "feel.json › %s présent" % section)
	check(int(feel["impact_frame"].get("max_per_second", 9)) <= 3, "au plus 3 éclairs par seconde (WCAG 2.3.1)")
	for key in ["boss_phase", "boss_kill", "heart"]:
		check(float(feel["slowmo"].get(key, 0)) > 0.0 and float(feel["slowmo"].get(key, 0)) <= 2.0, "ralenti « %s » bref (%.1f s)" % [key, float(feel["slowmo"].get(key, 0))])
	for key in ["crit", "elite", "siege", "wave"]:
		check(not feel["slowmo"].has(key) and not feel["slowmo"].has(key + "_kill"), "pas de ralenti pour « %s »" % key)

	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(2)
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	main.player.invuln = 1.0e9
	var at := Vector2(-1500, 600)
	main.player.position = at
	var m = main.moments
	var p = main.player
	check(m != null, "main.moments existe")
	await _frames(2)
	_settle(m)

	print("Impact frame « encre »")
	var e = main.spawn_enemy_at(at + Vector2(60, 0), 0)
	await _frames(1)
	var z0: int = p.z_index
	var n0: int = m.impact_frames
	check(m.impact_frame(0.5, [e], "encre"), "lancée")
	check(m.impact_frames == n0 + 1 and m.last_seq == ["A", "A"], "deux images papier/encre (%s)" % [m.last_seq])
	check(p.z_index == 4001 and p.material == m._mat, "le héros passe devant le fond, en silhouette")
	check(e.z_index == 4001 and e.material == m._mat, "la cible aussi")
	var ink := Color(str(feel["impact_frame"]["encre"]))
	var paper := Color(str(feel["impact_frame"]["papier"]))
	check(m.shown_back.is_equal_approx(Color(paper, 1.0)) and m.shown_sil.is_equal_approx(ink), "fond papier clair, silhouettes à l'encre")
	check(not m.impact_frame(0.3, [e], "encre"), "un moment plus faible n'interrompt pas celui en cours")
	await _frames(1)
	check(m.in_impact_frame(), "encore là après quelques images : chaque image dure frame_time")
	await _wait_real(float(feel["impact_frame"]["frame_time"]) * 2.0 + 0.1)
	check(not m.in_impact_frame(), "finie après ses deux images")
	check(p.z_index == z0 and p.material == null and e.material == null, "héros et cible rendus tels quels")
	_settle(m)
	m.impact_frame(0.9, [e], "encre")
	check(m.last_seq == ["A", "B", "A"], "coup très fort : alternance avec la variante inverse (%s)" % [m.last_seq])
	await _frames(2)
	check(m.shown_back.is_equal_approx(Color(ink, 1.0)) and m.shown_sil.is_equal_approx(paper), "variante inverse : fond encre, silhouettes papier")
	_settle(m)

	print("Impact frame « region »")
	var cols: Array = m.colors("region", "A", "ronce")
	check(cols[1].is_equal_approx(Color(str(feel["impact_frame"]["region_colors"]["ronce"]))), "Ronce : silhouettes rouge sang")
	check(absf(fposmod(cols[0].h - cols[1].h, 1.0) - 0.5) < 0.02, "fond dans la couleur complémentaire")
	for id in ["spore", "vent", "seve", "aube", "racine", "finale"]:
		var c: Array = m.colors("region", "A", id)
		check(not c[0].is_equal_approx(c[1]) and c[1] != Color.MAGENTA, "%s : couleurs propres (%s sur %s)" % [id, c[1].to_html(false), c[0].to_html(false)])
	m.impact_frame(0.5, [e], "encre")
	check(m.impact_frame(0.9, [e], "region", "spore") and m.last_style == "region", "un moment plus fort remplace le plus faible")
	_settle(m)

	print("Options à 0")
	settings.flash_scale = 0.0
	var o0: int = m.outline_frames
	m.impact_frame(1.0, [e], "region", "ronce")
	check(m.outline_frames == o0 + 1 and p.material == null and m.shown_back.a == 0.0, "éclairs à 0 : contour lumineux, sans fond ni inversion")
	_settle(m)
	settings.flash_scale = 1.0
	settings.reduce_effects = true
	m.impact_frame(1.0, [e], "encre")
	check(p.material == null, "« Réduire les effets » : contour seulement")
	settings.reduce_effects = false
	_settle(m)
	settings.shake_scale = 0.0
	m.camera_kick(Vector2.RIGHT, 1.0)
	m.zoom_pulse(1.0, 0.5)
	m.focus(at + Vector2(500, 0), 0.5)
	await _frames(2)
	check(main.camera.offset == Vector2.ZERO and main.camera.zoom == Vector2.ONE, "secousse à 0 : caméra immobile")
	settings.shake_scale = 1.0
	settings.hitstop_scale = 0.0
	check(not m.slowmo(1.0, 0.3) and Engine.time_scale == 1.0, "arrêts à 0 : pas de ralenti")
	settings.hitstop_scale = 1.0
	_settle(m)

	print("Caméra")
	m.camera_kick(Vector2.RIGHT, 1.0)
	m.zoom_pulse(1.0, 0.4)
	await _wait_real(0.06)
	check(main.camera.offset.x > 1.0, "à-coup dans le sens du coup (%.1f px)" % main.camera.offset.x)
	check(main.camera.zoom.x > 1.0 and main.camera.zoom.x <= 1.0 + float(feel["camera"]["zoom_max"]) + 0.001, "zoom bref, vers l'avant seulement (%.3f)" % main.camera.zoom.x)
	await _wait_real(0.5)
	await _frames(2)
	check(main.camera.zoom == Vector2.ONE and main.camera.offset.length() < 0.5, "retour au cadrage normal")
	_settle(m)

	print("Ralenti")
	var s0: int = m.slowmos
	var el = main.spawn_enemy_at(at + Vector2(-60, 0), 0)
	main.make_elite(el)
	await _frames(1)
	main.elite_killed.emit(el)
	check(m.in_impact_frame() and m.last_seq.size() == 3 and m.last_style == "encre", "mort d'élite : impact frame « encre » forte")
	check(m.slowmos == s0 and not m.in_slowmo(), "mort d'élite : pas de ralenti")
	_settle(m)
	main.fx.impact(at + Vector2(60, 0), 50.0, true, 14.0, "", true)
	check(m.in_impact_frame() and not m.in_slowmo(), "critique lourd : impact frame sans ralenti")
	_settle(m)
	main.fx.boss_phase(at, 60.0)
	check(m.in_slowmo() and m.last_style == "region", "phase de boss : impact frame « region » et ralenti")
	await _wait_real(0.3)
	check(Engine.time_scale < 0.9, "le jeu ralentit (%.2f)" % Engine.time_scale)
	check(not m.slowmo(0.5, 0.9), "un ralenti plus léger n'en remplace pas un plus profond")
	await _wait_real(float(feel["slowmo"]["boss_phase"]) + 0.2)
	check(not m.in_slowmo() and is_equal_approx(Engine.time_scale, 1.0), "vitesse revenue à 1 après le ralenti")
	_settle(m)
	var h = main.heart
	h.main = main
	var hs0: int = m.slowmos
	# Matériau des lieux cuits (refonte du monde, vague 1 C) : rendu tel quel après la silhouette.
	var h_mat = h.body.material
	h.purify()
	check(m.slowmos == hs0 + 1 and m.last_style == "region" and m.in_impact_frame(), "Cœur purifié : impact frame « region » et ralenti")
	check(h.body.material == m._mat, "le Cœur passe en silhouette")
	_settle(m)
	await _frames(1)
	check(h.body.material == h_mat, "le Cœur rendu tel quel")

	print("Combat de boss simulé : au plus 3 éclairs par seconde")
	var stamps: Array = []
	var end: float = m._clock + 2.6
	var i := 0
	var guard := 600
	while m._clock < end and guard > 0:
		guard -= 1
		i += 1
		var before: int = m._flashes.size()
		match i % 4:
			0:
				main.fx.impact(at + Vector2(60, 0), 50.0, true, 14.0, "", true)
			1:
				main.elite_killed.emit(el)
			2:
				main.fx.boss_phase(at, 60.0)
			3:
				main.fx.boss_kill(at, 60.0)
		if m._flashes.size() > before:
			for k in m._flashes.size() - before:
				stamps.append(m._clock)
		await process_frame
	var worst := 0
	for a in stamps:
		var n := 0
		for b in stamps:
			if b >= a and b - a < 1.0:
				n += 1
		worst = maxi(worst, n)
	check(stamps.size() >= 4, "des éclairs ont bien eu lieu (%d)" % stamps.size())
	check(worst <= 3, "jamais plus de 3 éclairs par seconde (au plus %d)" % worst)
	await _wait_real(float(feel["slowmo"]["boss_kill"]) + 0.3)
	await _frames(3)
	check(not m.in_slowmo() and is_equal_approx(Engine.time_scale, 1.0), "après le combat, la vitesse est revenue à 1 (%.2f)" % Engine.time_scale)
	check(p.z_index == z0 and p.material == null, "le héros est rendu tel quel")

	print("Pause")
	m.slowmo(1.0, 0.3)
	await _wait_real(0.2)
	paused = true
	await _frames(2)
	check(is_equal_approx(Engine.time_scale, 1.0), "menu ouvert : le jeu n'est pas ralenti derrière")
	paused = false
	_settle(m)

	main.queue_free()
	await _frames(2)
	check(is_equal_approx(Engine.time_scale, 1.0), "scène fermée : vitesse 1")
	settings.reduce_effects = saved[0]
	settings.hitstop_scale = saved[1]
	settings.flash_scale = saved[2]
	settings.shake_scale = saved[3]
	print("moments_test : %s" % ("OK" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
