## Test de la région de Vent (jalon 7, tâche E) : géométrie et décor des hauts plateaux, rafales
## (poussée, projectiles, réglage des options), les quatre Flétris des plateaux (Piqueur, Souffleur,
## Planeur de cendre, Menhir), le Cœur des rafales, puis le Harfang de cendre (attaques, piqué hors
## d'atteinte, tempête, victoire) et la sauvegarde de ses drapeaux.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/plateaux_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
## Chargés au lancement (load) : ils citent des autoloads, inconnus quand ce script est compilé.
var Wind
var Enemy
var Plateau

var failures := 0
var main
var game


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


func _place(pos: Vector2) -> void:
	main.player.position = pos
	main.player.hp = 1.0e6


func _clear() -> void:
	for e in main.enemies:
		if is_instance_valid(e) and not e.get("behavior") == "boss":
			e.queue_free()
	main.enemies = main.enemies.filter(func(e): return is_instance_valid(e) and e.get("behavior") == "boss")


func _run() -> void:
	game = root.get_node("Game")
	Wind = load("res://scripts/wind.gd")
	Enemy = load("res://scripts/enemy.gd")
	Plateau = load("res://scripts/decor_plateau.gd")
	var settings = root.get_node("Settings")
	var save = root.get_node("SaveGame")
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true      # ni sauvegarde lue ni écrite
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _steps(2)
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.autosave_enabled = false
	var p = main.player
	var wind_setting: float = settings.wind
	settings.wind = 1.0

	print("Géométrie et décor")
	check("vent" in Regions.ids(), "la région de Vent est chargée (data/regions/vent.json)")
	var c := Regions.center("vent")
	check(main.region_at(c) == "vent" and main.region_at(Regions.center("ronce")) == "ronce", "region_at distingue les plateaux et le roncier")
	check(Regions.angle_of("vent") == Regions.angle_of("vent") and absf(angle_difference(c.angle(), Regions.angle_of("vent"))) < 0.01, "les plateaux sont dans le secteur de la branche Vent")
	var stones := 0
	var grass := 0
	var twisted := 0
	for t in main.flora.trees:
		if main.region_at(t.position) != "vent":
			continue
		if is_instance_of(t, Plateau.Stone):
			stones += 1
		elif is_instance_of(t, Plateau.Grass):
			grass += 1
		elif is_instance_of(t, Plateau.Twisted):
			twisted += 1
	check(stones > 20, "des rochers font obstacle sur les plateaux (%d)" % stones)
	check(twisted > 10 and grass > 60, "arbres tordus (%d) et herbe couchée (%d)" % [twisted, grass])
	var stone = null
	for b in main.flora.bushes:
		if main.region_at(b.position) == "vent":
			stone = b
			break
	check(stone != null and main.flora.push_out(stone.position, 10.0) != stone.position, "un rocher repousse ce qui le touche")
	check(main.hearts.has("vent") and main.arenas.has("vent"), "un Cœur et une arène pour la région")
	check(main.sanctuary("vent_col") != null and main.sanctuary("vent_col").region == "vent", "le sanctuaire du Col est posé")

	print("Rafales")
	var w = Wind.active
	check(w != null and w.region == "vent", "les rafales soufflent sur les plateaux")
	_place(c + Vector2(260, 0))
	w.state = "calme"
	w.timer = 0.05
	await _steps(5)
	check(w.state == "annonce", "une rafale s'annonce avant de souffler")
	w.timer = 0.01
	await _steps(30)
	check(w.state == "rafale" and w.strength > 0.5, "la rafale souffle (force %.2f)" % w.strength)
	_place(c + Vector2(260, 0))
	p.set_physics_process(false)
	var before: Vector2 = p.position
	await _steps(20)
	var pushed: Vector2 = p.position - before
	check(pushed.length() > 10.0 and pushed.normalized().dot(w.dir) > 0.9, "le joueur est poussé dans le sens du vent (%d px)" % int(pushed.length()))
	var shot = main.spawn_projectile(p.position, w.dir.orthogonal() * 400.0, 1.0, 0)
	shot.life = 10.0
	var v0: Vector2 = shot.vel
	await _steps(10)
	check(is_instance_valid(shot) and (shot.vel - v0).dot(w.dir) > 5.0, "les projectiles sont déviés par la rafale")
	settings.wind = 0.0
	w.timer = 2.0
	before = p.position
	await _steps(20)
	check(p.position.distance_to(before) < 0.5, "rafales coupées dans les options : plus de poussée")
	settings.wind = 1.0
	_place(Vector2.ZERO)
	before = p.position
	await _steps(10)
	check(p.position.distance_to(before) < 0.5, "hors de la région, le vent ne pousse pas")
	w.state = "calme"
	w.timer = 1.0e9
	w.strength = 0.0
	p.set_physics_process(true)
	p.invuln = 0.0

	print("Flétris des plateaux")
	# Le joueur ne tire pas : les Flétris doivent vivre le temps de montrer leurs attaques.
	p.fire_cd = 1.0e9
	for k in ["plongeur", "souffleur", "planeur", "menhir"]:
		check(Enemy.kind_index(k) >= 0, "sorte « %s » dans enemies.json" % k)
	var spot := c + Vector2(0, -400)
	# Piqueur : il tourne, annonce un piqué et fond sur le joueur.
	_place(spot)
	var diver = main.spawn_enemy_kind("plongeur", spot + Vector2(300, 0), 1.0)
	diver.cd = 0.0
	check(await _until(func(): return diver.state == "windup", 120), "le Piqueur annonce son piqué")
	var dir_locked: Vector2 = diver.attack_dir
	check(await _until(func(): return diver.state == "charge", 120), "puis il pique en ligne droite")
	var hp0: float = p.hp
	p.invuln = 0.0
	check(await _until(func(): return diver.state == "recover", 120) and diver.attack_dir == dir_locked, "il dépasse sa cible et remonte")
	check(p.hp < hp0, "le piqué blesse le joueur pris dans le couloir")
	diver.queue_free()
	await _steps(2)
	_clear()
	# Souffleur : il gonfle, souffle, et repousse le joueur pris dans le cône.
	_place(spot)
	p.invuln = 0.0
	p.set_physics_process(false)
	var blower = main.spawn_enemy_kind("souffleur", spot + Vector2(200, 0), 1.0)
	blower.cd = 0.0
	check(await _until(func(): return blower.state == "windup", 120), "le Souffleur annonce son souffle (cône au sol)")
	before = p.position
	# Aucun dégât étranger (vent, tornade) ne doit rendre le joueur invulnérable à l'instant du souffle.
	check(await _until(func():
		p.invuln = 0.0
		return blower.state == "recover", 120), "puis il souffle")
	await _steps(10)
	check((p.position - before).dot(Vector2.LEFT) > 60.0, "le joueur pris dans le souffle est repoussé (%d px)" % int((p.position - before).dot(Vector2.LEFT)))
	p.set_physics_process(true)
	blower.queue_free()
	await _steps(2)
	_clear()
	# Planeur : hors d'atteinte quand le joueur est proche, touchable de loin.
	_place(spot)
	var glider = main.spawn_enemy_kind("planeur", spot + Vector2(400, 0), 1.0)
	glider.set_physics_process(false)
	glider.state = ""
	var g_hp: float = glider.hp
	glider.take_damage(5.0, false)
	check(glider.hp < g_hp, "de loin, le Planeur est touché")
	glider.position = spot + Vector2(80, 0)
	glider.set_physics_process(true)
	await _steps(2)
	check(glider.state == "vol", "le joueur approche : il prend de la hauteur")
	g_hp = glider.hp
	glider.take_damage(5.0, false)
	check(glider.hp == g_hp, "en vol haut, les coups directs ne le touchent pas")
	glider.take_damage(2.0, false, true)
	check(glider.hp < g_hp, "le poison et le saignement passent toujours")
	glider.cd = 0.0
	glider.position = spot + Vector2(420, 0)
	check(await _until(func(): return glider.state == "windup", 120), "de loin, il vise")
	check(await _until(func(): return main.projectiles_layer.get_children().any(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("vent_feather.gd")), 120), "et crache des plumes de cendre")
	glider.queue_free()
	await _steps(2)
	_clear()
	# Menhir : lourd, ne se laisse pas repousser (champ lu par les compétences de Vent).
	var menhir = main.spawn_enemy_kind("menhir", spot + Vector2(300, 0), 1.0)
	check(menhir.data.get("no_push", false) == true and menhir.resist.get("vent", 0.0) > 0.0, "le Menhir est lourd (no_push) et résiste au Vent")
	menhir.queue_free()
	await _steps(2)
	_clear()

	print("Cœur des rafales")
	p.fire_cd = 0.0
	var heart = main.hearts["vent"]
	# Les deux autres Cœurs de la région sont déjà purifiés : le Grand Cœur ouvre l'arène.
	for h in main.region_hearts["vent"]:
		if h != heart:
			game.flags[h.flag] = true
	var arena = main.arenas["vent"]
	check(heart.state == "fletri" and arena.state == "fermee", "Cœur flétri, arène fermée")
	_place(heart.center + Vector2(heart.zone * 0.6, 0))
	await _steps(90)
	check(heart.state == "siege" and heart.spawned.size() > 0, "tenir la zone lance le siège et une vague")
	heart.progress = heart.hold_time - 0.2
	await _steps(30)
	check(heart.state == "purifie" and game.flags.get("vent_coeur_purifie", false) == true, "Cœur purifié, drapeau vent_coeur_purifie")
	check(arena.state == "ouverte", "l'aire du Harfang s'ouvre")
	_clear()

	print("Le Harfang de cendre")
	p.fire_cd = 1.0e9
	_place(arena.center + Vector2(0, 250))
	await _steps(5)
	var boss = arena.boss
	check(arena.state == "combat" and is_instance_valid(boss) and boss.get_script().resource_path.ends_with("boss_vent.gd"), "entrer dans l'aire réveille le Harfang")
	check(boss in main.enemies_near(boss.position + Vector2(boss.radius + 4.0, 0), 8.0), "enemies_near le trouve")
	_place(arena.center + Vector2(0, 330))
	check(await _until(func(): return boss.attack != "" and boss.stage == "annonce"), "une attaque est annoncée avant de frapper")
	await _until(func(): return boss.attack == "")
	# Battement : repousse le joueur pris dans le cercle.
	boss.gap = 1.0e9
	_place(arena.center + Vector2(0, 120))
	p.invuln = 0.0
	p.set_physics_process(false)
	boss._begin("battement")
	check(await _until(func(): return boss.stage == "frappe", 200), "le battement d'ailes frappe après son annonce")
	await _steps(15)
	check(p.position.distance_to(arena.center) > 160.0, "le battement repousse le joueur (%d px du centre)" % int(p.position.distance_to(arena.center)))
	p.set_physics_process(true)
	await _until(func(): return boss.attack == "")
	# Phase 2 : le piqué.
	boss.take_damage(boss.max_hp * 0.4, false)
	check(await _until(func(): return boss.phase == 2), "sous 66 % de vie : phase 2")
	await _until(func(): return boss.transition <= 0.0)
	boss.gap = 1.0e9
	_place(arena.center + Vector2(150, 150))
	boss._begin("pique")
	await _steps(5)
	check(boss.airborne(), "le Harfang s'envole pour piquer")
	var bhp: float = boss.hp
	boss.take_damage(50.0, false)
	check(boss.hp == bhp, "en vol, il est hors d'atteinte")
	check(boss.danger_time(p.position) < INF, "son ombre menace le joueur (le robot l'évite)")
	check(await _until(func(): return boss.dive_step == "pose", 300), "il fond sur son ombre et se pose")
	check(boss.anchor.distance_to(arena.center) > 60.0, "il s'est posé loin du centre")
	bhp = boss.hp
	boss.take_damage(10.0, false)
	check(absf((bhp - boss.hp) - 10.0 * boss.DIVE["landed_mult"]) < 0.01, "posé, il prend plus de dégâts")
	check(await _until(func(): return boss.attack == "", 300) and boss.anchor.distance_to(arena.center) < 1.0, "puis il revient au centre")
	# Phase 3 : la tempête.
	boss.take_damage(boss.max_hp * 0.3, false)
	check(await _until(func(): return boss.phase == 3), "sous 33 % de vie : phase 3")
	await _until(func(): return boss.transition <= 0.0)
	boss.gap = 1.0e9
	boss._begin("tempete")
	check(await _until(func(): return boss.tornadoes.size() == 2, 200), "la tempête fait naître deux tornades")
	_place(arena.center + Vector2(300, 0))
	p.set_physics_process(false)
	before = p.position
	await _steps(30)
	check(p.position.distance_to(before) > 5.0, "le vent tournant pousse le joueur le long du bord")
	p.set_physics_process(true)
	boss.gap = 0.5
	check(await _until(func(): return boss.tornadoes.is_empty(), 900), "les tornades se dissipent")

	print("Victoire")
	_clear()
	var points: int = game.points
	boss.take_damage(boss.max_hp + 1.0, false)
	check(boss.dead and game.flags.get("vent_boss_vaincu", false) == true, "Harfang vaincu : drapeau vent_boss_vaincu")
	check(game.points == points + 2, "2 points d'arbre gagnés")
	check(arena.state == "vaincue" and not main.spawn_paused, "l'aire refleurit, les naissances reprennent")
	# Le ralenti de la mort du boss (moments.gd) allonge le temps réel : attendre qu'il ait disparu.
	var boss_ref: WeakRef = weakref(boss)   # une capture libérée par le boss lui-même ferait une erreur au dernier appel
	await _until(func(): return boss_ref.get_ref() == null, 600)
	check(not is_instance_valid(boss), "le Harfang a disparu")

	print("Sauvegarde")
	var data: Dictionary = JSON.parse_string(JSON.stringify(save.capture(main)))
	game.reset()
	check(not game.flags.has("vent_coeur_purifie") and not game.flags.has("vent_boss_vaincu"), "nouvelle partie : drapeaux effacés")
	save.apply(data, main)
	await _steps(3)
	check(game.flags.get("vent_coeur_purifie", false) == true and game.flags.get("vent_boss_vaincu", false) == true, "les drapeaux de Vent sont sauvegardés et rechargés")

	settings.wind = wind_setting
	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
