## Boss exaltés de Ronce, Spore et Vent (NG+, jalon 14 B1) : au cycle 2, la phase exaltée arrive en
## bas de la vie, l'attaque nouvelle y est annoncée puis frappe ; la brèche protège, la bande blesse.
## Au cycle 1, rien ne change (trois phases, pas d'attaque nouvelle).
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/exalte_b1_test.gd -- --cycle=2
## (une région : … -- --cycle=2 --region=spore ; par défaut les trois l'une après l'autre).
## Ne lit ni n'écrit la sauvegarde.
extends SceneTree

const REGIONS := ["ronce", "spore", "vent"]

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


## Retire les tirs de la batterie (Amanite-Mère sur son morceau) et l'invulnérabilité qui suit un coup.
## Tient la vie du boss à « hold ».
func _hold(b, hold: float) -> bool:
	if is_instance_valid(b):
		b.hp = maxf(b.hp, hold)
	return true


## La vie du boss (_b) est tenue à _keep : le héros (_p), qui frappe de lui-même, ne l'achève pas.
var _b
var _p
var _keep := 0.0


func _quiet() -> bool:
	if is_instance_valid(_b):
		_b.hp = maxf(_b.hp, _keep)
		_b.spores = []
		_b.pricks = []
		_b.waves = []
	_p.invuln = 0.0
	# Le héros ne doit pas tomber (sa mort relancerait le combat) : ce qu'il perd se lit sur _hp0.
	_p.hp = maxf(_p.hp, 1.0e4)
	return true


func _until(cond: Callable, limit := 900) -> bool:
	for i in limit:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _run() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--region="):
			only = a.get_slice("=", 1)
	var cycle: int = root.get_node("Cycles").current()
	print("Cycle %d" % cycle)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	await _steps(3)
	for r in REGIONS:
		if only == "" or only == r:
			await _region(r, cycle)
	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)


func _region(region: String, cycle: int) -> void:
	print("Région " + region)
	var game = root.get_node("Game")
	var arena = main.arenas.get(region)
	if arena == null:
		check(false, "arène de %s trouvée" % region)
		return
	for h in main.region_hearts[region]:
		game.flags[h.flag] = true
	await _steps(5)
	var p = main.player
	p.position = arena.center + Vector2(0, 250)
	p.hp = 1.0e6
	await _steps(5)
	var boss = arena.boss
	check(is_instance_valid(boss), "le boss se réveille")
	if not is_instance_valid(boss):
		return
	check(boss.exalted == (cycle >= 2), "exalté seulement à partir du cycle 2")
	check(boss.phase_limits.size() == (3 if cycle >= 2 else 2), "une phase de plus au cycle 2")
	if cycle < 2:
		boss.take_damage(boss.max_hp * 2.0, false)
		await _steps(150)
		return
	# Jusqu'à la phase exaltée.
	await _until(func(): return boss.intro <= 0.0, 600)
	for want in [2, 3, 4]:
		boss.hp = boss.max_hp * (float(boss.phase_limits[want - 2]) - 0.01)
		check(await _until(func(): return boss.phase == want and boss.transition <= 0.0 and not boss.music_waiting(), 1200), "phase %d" % want)
	check(boss.is_exalted_phase() and boss.exalted_phase_seen, "phase exaltée entrée et annoncée")
	var names: Array = arena.exalted_phase_names
	check(names.size() == 4, "quatre noms de phase au cycle exalté")
	# L'attaque nouvelle est annoncée puis frappe (le joueur ne craint rien : vie énorme).
	var att: String = boss.EXALTED_ATTACK
	# Le héros frappe de lui-même : la vie du boss est tenue dans la phase exaltée le temps de l'attendre.
	var keep: float = boss.hp
	check(await _until(func(): return _hold(boss, keep) and boss.attack == att, 1800), "« %s » est lancée en phase exaltée" % att)
	check(boss.exalted_attacks >= 1, "le compteur de l'attaque nouvelle monte")
	var hp0: float = p.hp
	match region:
		"ronce":
			await _until(func(): return not boss.embraces.is_empty(), 60)
			var e: Dictionary = boss.embraces[boss.embraces.size() - 1]
			# Attendre la fin du suivi, puis se mettre sur la bande, loin de la brèche.
			await _until(func(): return e["fuse"] < e["total"] * 0.3, 300)
			var band: float = (boss.EMBRACE["inner"] + boss.EMBRACE["outer"]) / 2.0
			p.position = e["pos"] + Vector2.from_angle(e["gap"] + PI) * band
			check(boss.danger_time(p.position) < 2.0, "le robot voit la bande menacée")
			p.invuln = 0.0
			await _until(func(): return e["fuse"] <= 0.0, 300)
			await _steps(2)
			check(p.hp < hp0, "sur la bande : l'étreinte blesse")
		"spore":
			_b = boss
			_p = p
			_keep = keep
			await _until(func(): return _quiet() and _b.stage == "frappe", 300)
			await _until(func(): return _quiet() and not _b.rings.is_empty(), 120)
			var g: Dictionary = boss.rings[0]
			# Dans la brèche du premier anneau : il passe sans toucher.
			p.position = boss.anchor + Vector2.from_angle(g["gap"]) * (g["r"] + 120.0)
			var first: Dictionary = g
			await _until(func(): return _quiet() and first["r"] > _b.anchor.distance_to(_p.position) + 40.0, 300)
			check(not first["hit"], "dans la brèche : l'anneau passe sans toucher")
			# Sur la bande d'un anneau suivant, loin de sa brèche.
			await _until(func(): return _quiet() and (_b.rings.size() >= 2 or _b.ring_gaps.is_empty()), 200)
			var g2: Dictionary = boss.rings[boss.rings.size() - 1]
			p.position = boss.anchor + Vector2.from_angle(g2["gap"] + PI) * (g2["r"] + 60.0)
			p.invuln = 0.0
			p.hp = 1.0e5
			hp0 = p.hp
			# Sur son morceau, la batterie tire aussi : ses spores (et l'invulnérabilité qui suit un coup)
			# ne doivent pas cacher l'anneau.
			await _until(func(): return _quiet() and (g2["hit"] or g2["r"] > _b.anchor.distance_to(_p.position) + 40.0), 300)
			check(g2["hit"] and p.hp < hp0, "sur la bande, hors de la brèche : l'anneau blesse")
		"vent":
			await _until(func(): return boss.swoop_step == "vise", 200)
			check(boss.airborne(), "hors d'atteinte pendant la rasante")
			await _until(func(): return boss.swoop_t < boss.swoop_total * 0.3, 200)
			p.position = boss.swoop_from.lerp(boss.swoop_to, 0.5)
			p.invuln = 0.0
			check(boss.danger_time(p.position) < 2.0, "le robot voit la ligne menacée")
			await _until(func(): return boss.swoop_step != "rase" and boss.swoop_step != "vise" or boss.swoop_left < int(boss.PHASES[4]["passes"]), 300)
			check(p.hp < hp0, "sur la ligne : la rasante blesse")
			await _until(func(): return boss.attack != "rasante", 900)
			check(boss.anchor.distance_to(boss.home) < 1.0, "il revient au centre")
	boss.take_damage(boss.max_hp * 2.0, false)
	check(boss.dead, "il meurt en phase exaltée")
	await _steps(150)
	p.position = main.respawn_point()
