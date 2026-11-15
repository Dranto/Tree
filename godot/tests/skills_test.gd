## Test des compétences de Ronce, des états des ennemis et de la barre de compétences.
## Lancer : tools/godot.sh --headless -s res://tests/skills_test.gd
## La partie est jouée en mode robot (aucune sauvegarde lue ni écrite) ; le robot est ensuite
## coupé pour que seules les actions du test aient lieu.
extends SceneTree

## Chargés à l'exécution : les autoloads (Game, Settings) n'existent pas encore à la compilation.
var MainScene
var Enemy

var failures := 0
var game
var main


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
		await physics_frame


func _spawn(pos: Vector2, kind := 0, power := 50.0):
	var e = Enemy.new()
	e.main = main
	e.position = pos
	e.setup(kind, power)
	main.enemies_layer.add_child(e)
	main.enemies.append(e)
	return e


func _clear_enemies() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()


func _run() -> void:
	MainScene = load("res://scenes/main.tscn")
	Enemy = load("res://scripts/enemy.gd")
	game = root.get_node("Game")
	var settings = root.get_node("Settings")
	main = MainScene.instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(2)
	main.autotest = false
	main.spawn_timer = 1e9
	_clear_enemies()
	var p = main.player
	p.set_physics_process(false)
	p.invuln = 1e9
	p.position = Vector2.ZERO

	print("Barre de compétences")
	game.reset()
	check(p.bar.size() == 6 and p.bar.count("") == 6, "partie neuve : 6 emplacements vides")
	check(p.unlocked_slots() == 4, "4 emplacements débloqués au départ")
	await process_frame
	var hud = main.hud
	var states: Array = hud._slots.map(func(s): return s.name_label.text)
	check(states == ["libre", "libre", "libre", "libre", "verrouillé", "verrouillé"],
		"emplacements vides : 4 « libre » puis 2 « verrouillé » (%s)" % ", ".join(states))
	game.test_skills = {"fouet": true, "racines": true, "haie": true, "nova": true, "cloud": true}
	game.recompute()
	game.tree_changed.emit()
	check(p.bar.slice(0, 4) == ["nova", "cloud", "fouet", "racines"], "compétences acquises rangées dans l'ordre de skills.json (%s)" % str(p.bar))
	check(p.unbarred_skills() == ["haie"], "la 5e compétence attend un emplacement")
	p.cycle_slot(1)
	check(p.bar[1] == "haie" and p.unbarred_skills() == ["cloud"], "clic sur un emplacement : échange avec une compétence sans place")
	check(game.flags.get("barre", "").begins_with("nova,haie,"), "la barre est gardée dans les drapeaux de la partie")
	p.cycle_slot(4)
	check(p.bar[4] == "", "un emplacement verrouillé ne reçoit rien")
	game.test_skills.erase("racines")
	game.recompute()
	game.tree_changed.emit()
	check(not p.bar.has("racines") and p.bar.has("fouet"), "compétence perdue : sa place est reprise par une compétence sans place")
	game.test_skills["racines"] = true
	game.recompute()
	game.tree_changed.emit()

	print("Touches")
	check(InputMap.has_action("slot_1") and InputMap.has_action("slot_6"), "actions slot_1 à slot_6")
	var before: Array = settings.slot_keys.duplicate()
	settings.set_slot_key(3, KEY_Q)
	check(settings.slot_keys[3] == KEY_Q and settings.slot_keys[0] == KEY_NONE, "une touche réassignée est retirée de l'ancien emplacement")
	var has_q := false
	for ev in InputMap.action_get_events("slot_4"):
		if ev is InputEventKey and ev.physical_keycode == KEY_Q:
			has_q = true
	check(has_q, "l'action suit la nouvelle touche")
	check(settings.key_owner(KEY_W) == "move_up", "une touche de déplacement est signalée comme prise")
	for i in before.size():
		settings.slot_keys[i] = before[i]
	settings.apply_bindings()

	print("Saignement")
	var e = _spawn(Vector2(400, 0))
	await _frames(2)
	for i in 7:
		e.apply_status("saignement", 10.0 + i, 3.0)
	check(e.bleed_stacks.size() == Enemy.BLEED_MAX_STACKS, "cumulable %d fois au plus" % Enemy.BLEED_MAX_STACKS)
	var weakest := 1e9
	for st in e.bleed_stacks:
		weakest = minf(weakest, st[0])
	check(weakest >= 12.0, "au-delà, les piqûres les plus faibles sont remplacées")
	e.set_physics_process(false)   # pas de temps maîtrisé à la main
	e.bleed_clock = 0.0
	var hp0: float = e.hp
	e._bleed_step(0.25)
	check(e.hp == hp0, "pas de dégâts avant l'à-coup")
	e._bleed_step(0.25)
	check(absf((hp0 - e.hp) - 70.0 * 0.5) < 0.01, "un à-coup toutes les 0,5 s, somme des piqûres (%.1f dégâts, attendu 35)" % (hp0 - e.hp))
	e.set_physics_process(true)
	await _frames(160)
	check(e.bleed_stacks.is_empty(), "le saignement s'arrête à la fin de sa durée")

	print("Enracinement")
	_clear_enemies()
	e = _spawn(Vector2(300, 0), 1)
	await _frames(2)
	e.apply_status("enracine", 1.0, 1.0)
	var at: Vector2 = e.position
	await _frames(30)
	check(e.position.distance_to(at) < 1.0, "un ennemi enraciné ne bouge pas")
	await _frames(40)
	check(e.position.distance_to(at) > 10.0, "il repart à la fin de l'enracinement")

	print("Fouet")
	_clear_enemies()
	var front = _spawn(Vector2(100, 0))
	var back = _spawn(Vector2(-100, 0))
	await _frames(2)
	p.aim = Vector2.RIGHT
	p.cast("fouet", game.stats)
	check(front.hp < front.max_hp and front.bleed_stacks.size() == 1, "l'ennemi devant est touché et saigne")
	check(back.hp == back.max_hp, "l'ennemi derrière n'est pas touché")
	check(p.cds["fouet"] > 0.0, "la compétence se recharge")

	print("Racines")
	_clear_enemies()
	var inside = _spawn(Vector2(300, 0))
	var outside = _spawn(Vector2(300, 400))
	await _frames(2)
	p.aim_point = Vector2(300, 0)
	p.cast("racines", game.stats)
	check(inside.root_time > 0.0 and inside.hp < inside.max_hp, "les ennemis de la zone sont blessés et enracinés")
	check(outside.root_time <= 0.0, "les autres non")

	print("Haie")
	_clear_enemies()
	var walker = _spawn(Vector2(0, 260))
	await _frames(2)
	p.aim = Vector2.DOWN
	p.cast("haie", game.stats)
	await _frames(150)
	check(walker.position.y > 120.0, "la haie bloque l'ennemi (y = %.0f)" % walker.position.y)
	check(walker.hp < walker.max_hp, "la haie blesse au contact")

	print("Familles d'attaque et effets déclenchés")
	_clear_enemies()
	var base_fouet: float = p.skill_damage("fouet")
	game.effects.rebuild([{"id": 1, "effects": [{"stat": "melee_damage", "op": "inc", "value": 0.5}]}])
	game.stats = game.effects.stats
	check(absf(p.skill_damage("fouet") - base_fouet * 1.5) < 0.01, "melee_damage s'applique au fouet")
	check(absf(p.skill_damage("racines") - game.stats["damage"] * 1.0) < 0.01, "mais pas aux racines (zone)")
	game.effects.rebuild([{"id": 1, "effects": [
		{"on": "melee_hit", "do": "apply_status", "status": "enracine", "value": 1, "duration": 2, "text": "x"},
		{"on": "root", "do": "heal", "value": 0.1, "text": "x"},
		{"on": "bleed_tick", "do": "explode", "radius": 80, "factor": 0.5, "text": "x"},
	]}])
	game.stats = game.effects.stats
	var target = _spawn(Vector2(100, 0))
	var neighbor = _spawn(Vector2(140, 40))
	await _frames(2)
	p.hp = 10.0
	p.aim = Vector2.RIGHT
	p.cast("fouet", game.stats)
	check(target.root_time > 0.0, "melee_hit -> apply_status : le coup de fouet enracine")
	check(p.hp > 10.0, "root -> heal : l'enracinement soigne")
	var n_hp: float = neighbor.hp
	await _frames(32)
	check(neighbor.hp < n_hp, "bleed_tick -> explode : l'à-coup touche les voisins")

	print("Se battre chez soi")
	var plain: float = p.skill_damage("fouet")
	check(not main.has_method("region_at") or main.region_at(p.position) != "ronce" or p.fighting_at_home() == (main.ground.life_at(p.position) > 0.45),
		"bonus inactif hors de la région de Ronce")
	check(absf(plain - p.skill_damage("fouet")) < 0.001, "dégâts stables sans changement de terrain")

	game.test_skills = {}
	game.reset()
	main.queue_free()
	await process_frame
	print("RÉSULTAT : ", "tout est bon" if failures == 0 else "%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)
