## Test de la vibration de la manette (jalon Éclat, tâche H) : dosage de data/feel.json › rumble,
## plafond contre la vibration continue, rumble_scale à 0 = rien, clavier ou sans manette = rien,
## réglage enregistré et relu, accroches (coup reçu, critique, esquive, boss).
## Lancer : tools/godot.sh --headless -s res://tests/rumble_test.gd
extends SceneTree

var failures := 0
var settings
var rumble
var sent: Array = []


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _reset(t: float) -> void:
	rumble.clock = t
	rumble._history.clear()
	rumble._until = 0.0
	rumble._mag = 0.0
	rumble._last_at = -100.0
	sent.clear()


func _run() -> void:
	settings = root.get_node("Settings")
	rumble = root.get_node("Rumble")
	rumble.sink = func(dev, w, s, d): sent.append([dev, w, s, d])
	var saved: float = settings.rumble_scale
	settings.set_device("manette")
	settings.rumble_scale = 0.7

	print("Réglage")
	var cfg := ConfigFile.new()
	check(is_equal_approx(settings.rumble_scale, 0.7), "défaut 0,7")
	settings.set_rumble(2.0)
	check(is_equal_approx(settings.rumble_scale, 1.0), "borné à 1")
	settings.set_rumble(-1.0)
	check(is_equal_approx(settings.rumble_scale, 0.0), "borné à 0")
	settings.set_rumble(0.4)
	check(is_equal_approx(settings.rumble_scale, 0.4), "valeur enregistrée en mémoire")

	print("Dosage")
	settings.rumble_scale = 0.5
	_reset(10.0)
	check(rumble.pulse(0.8, 0.4, 0.2), "une impulsion part")
	check(sent.size() == 1 and is_equal_approx(sent[0][1], 0.4) and is_equal_approx(sent[0][2], 0.2) and is_equal_approx(sent[0][3], 0.2), "multipliée par rumble_scale")
	_reset(10.0)
	rumble.pulse(1.0, 1.0, 50.0)
	check(sent[0][3] <= 0.9 + 0.001, "durée plafonnée")
	_reset(10.0)
	settings.rumble_scale = 1.0
	rumble.pulse(2.0, 3.0, 0.1)
	check(sent[0][1] <= 1.0 and sent[0][2] <= 1.0, "moteurs bornés à 1")
	for n in ["heavy", "crit", "crit_heavy", "elite_kill", "dash", "boss_phase", "boss_kill", "heart", "level_up", "preview"]:
		_reset(20.0)
		check(rumble.play(n) and sent.size() == 1, "événement « %s » défini" % n)
	_reset(20.0)
	check(not rumble.play("inconnu"), "événement inconnu : rien")
	_reset(20.0)
	rumble.hurt(0.02)
	var petit: float = maxf(sent[0][1], sent[0][2])
	_reset(20.0)
	rumble.hurt(0.5)
	var gros: float = maxf(sent[0][1], sent[0][2])
	check(gros > petit * 1.5, "coup reçu : plus la vie perdue est grande, plus ça vibre")
	_reset(20.0)
	rumble.play("dash")
	var dash: float = maxf(sent[0][1], sent[0][2])
	check(dash < petit + 0.001 or dash < 0.2, "l'esquive est très légère")

	print("Plafond")
	settings.rumble_scale = 1.0
	_reset(30.0)
	var ok := 0
	for i in 40:
		rumble.clock = 30.0 + i * 0.025
		if rumble.pulse(0.3, 0.3, 0.1):
			ok += 1
	var total := 0.0
	for s in sent:
		total += s[3]
	check(ok < 40 and total <= 1.0 * 0.5 * 1.2 + 0.2, "mêlée d'une seconde : vibration limitée (%d impulsions, %.2f s)" % [ok, total])
	_reset(40.0)
	rumble.pulse(0.5, 0.5, 0.3)
	rumble.clock = 40.1
	check(not rumble.pulse(0.2, 0.2, 0.1), "plus faible pendant une impulsion : ignorée")
	rumble.clock = 40.12
	check(rumble.pulse(1.0, 1.0, 0.5), "nettement plus forte : remplace l'autre")
	_reset(50.0)
	for i in 8:
		rumble.clock = 50.0 + i * 0.1
		rumble.pulse(0.3, 0.3, 0.1)
	rumble.clock = 50.85
	check(rumble.play("boss_kill"), "la mort d'un boss vibre même après une mêlée")
	_reset(60.0)
	rumble.pulse(0.3, 0.3, 0.1)
	rumble.clock = 61.5
	check(rumble.pulse(0.3, 0.3, 0.1), "la fenêtre se vide : ça vibre de nouveau")

	print("Rien à vibrer")
	_reset(70.0)
	settings.rumble_scale = 0.0
	check(not rumble.pulse(1.0, 1.0, 0.3) and sent.is_empty(), "rumble_scale = 0 : rien")
	check(not rumble.play("boss_kill") and not rumble.hurt(0.5), "… ni par les événements")
	settings.rumble_scale = 0.7
	settings.set_device("clavier")
	check(not rumble.pulse(1.0, 1.0, 0.3) and sent.is_empty(), "clavier et souris : rien")
	check(rumble.target() == -1, "aucun appareil visé au clavier")
	settings.set_device("manette")
	rumble.sink = Callable()
	check(not rumble.pulse(1.0, 1.0, 0.3), "sans manette branchée (sans sink) : rien")
	check(rumble.target() == Input.get_connected_joypads()[0] if not Input.get_connected_joypads().is_empty() else rumble.target() == -1, "appareil = première manette branchée, ou aucun")
	rumble.sink = func(dev, w, s, d): sent.append([dev, w, s, d])
	paused_check()

	print("Accroches")
	var fx_src := FileAccess.get_file_as_string("res://scripts/fx.gd")
	check("Rumble.hurt(frac)" in fx_src and "Rumble.play(\"heavy\")" in fx_src, "fx.gd : coup reçu, coup lourd, critique")
	var mo_src := FileAccess.get_file_as_string("res://scripts/moments.gd")
	for n in ["elite_kill", "boss_phase", "boss_kill", "heart"]:
		check("Rumble.play(\"%s\")" % n in mo_src, "moments.gd : %s" % n)
	check("Rumble.play(\"dash\")" in FileAccess.get_file_as_string("res://scripts/player.gd"), "player.gd : esquive")
	_reset(80.0)
	var game = root.get_node("Game")
	game.leveled_up.emit(2)
	check(sent.size() == 1, "montée de niveau : impulsion")

	settings.rumble_scale = saved
	rumble.sink = Callable()
	print("rumble_test : ", "OK" if failures == 0 else "%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


func paused_check() -> void:
	_reset(90.0)
	paused = true
	check(not rumble.pulse(1.0, 1.0, 0.3) and sent.is_empty(), "jeu en pause : rien")
	paused = false
