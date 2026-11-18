## Test de la branche Spore : compétences Vesse-de-loup, Essaim, Éclosion et Nuage de spores qui suit
## (Brouillard vivant), formes de l'attaque Spores lobées et Dards fongiques, modificateurs « saut »
## et « bouffée », action « cloud », et contenu de la branche (builds, greffes, nœuds flétris).
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/spore_test.gd
extends SceneTree

const AttackScript = preload("res://scripts/attack.gd")
const Content = preload("res://scripts/content.gd")
const EffectActions = preload("res://scripts/effect_actions.gd")

var MainScene
var Enemy
var failures := 0
var game
var main
var p


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


## n pas de jeu, avec le pas des compétences acquises (le joueur est figé pendant le test).
func _steps(n: int) -> void:
	for i in n:
		for k in ["vesse", "essaim"]:
			var obj = p.skill_object(k)
			if obj != null:
				obj.tick(1.0 / 60.0)
		await physics_frame


func _with(effects: Array) -> void:
	game.effects.rebuild([{"id": "test", "ring": 1, "effects": effects}])
	game.stats = game.effects.stats


func _spawn(pos: Vector2, hp := 1.0e6):
	var e = Enemy.new()
	e.main = main
	e.position = pos
	e.setup(0, 50.0)
	e.hp = hp
	e.max_hp = hp
	e.set_physics_process(false)
	e.speed = 0.0
	main.enemies_layer.add_child(e)
	main.enemies.append(e)
	main._rebuild_grid()
	return e


func _clear() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	for c in main.projectiles_layer.get_children():
		c.queue_free()
	main.attack_fx.zones.clear()
	main.attack_fx.effects.clear()
	main.fx.clouds.clear()
	p.attack_rt = {}
	main._rebuild_grid()


func _zones(group: String) -> Array:
	return main.attack_fx.zones.filter(func(z): return z.get("group", z["kind"]) == group)


func _run() -> void:
	MainScene = load("res://scenes/main.tscn")
	Enemy = load("res://scripts/enemy.gd")
	game = root.get_node("Game")
	game.reset()
	main = MainScene.instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(2)
	main.autotest = false
	main.spawn_timer = 1e9
	p = main.player
	p.set_physics_process(false)
	p.invuln = 1e9
	p.position = Vector2.ZERO
	p.aim = Vector2.RIGHT
	p.aim_point = Vector2(200, 0)
	_clear()

	_test_content()
	await _test_vesse()
	await _test_essaim()
	await _test_eclosion()
	await _test_cloud_follow()
	await _test_forms()
	await _test_mods()
	await _test_action()

	print("ÉCHECS : %d" % failures if failures > 0 else "Tout est bon.")
	quit(1 if failures > 0 else 0)


func _test_content() -> void:
	print("Contenu de la branche")
	var tree = game.tree
	for uid in ["key:cloud", "key:brouillard", "key:pandemie", "key:chair_fongique", "c:spore:nuee:n1", "c:spore:propagation:c1",
			"c:spore:toxines:t1", "c:spore:nuee:n6", "c:spore:graines:a2", "c:spore:graines:a3"]:
		check(tree.id_for_uid(uid) >= 0, "nœud %s présent" % uid)
	var h2: int = tree.id_for_uid("c:spore:coeur:h2")
	var h3: int = tree.id_for_uid("c:spore:coeur:h3")
	check(tree.nodes[h2]["requires_flag"] == "spore_coeur_purifie" and tree.nodes[h3]["requires_flag"] == "spore_boss_vaincu",
		"nœuds flétris liés au Cœur et au boss de Spore")
	var grafts: Dictionary = Content.grafts()
	var n := 0
	for g in ["greffe_vesse", "greffe_mycelium", "greffe_amadou", "greffe_lichen", "greffe_truffe", "greffe_sporange",
			"greffe_essaim_double", "greffe_eclosion", "greffe_spore_lourde", "greffe_aiguille"]:
		if grafts.has(g):
			n += 1
	check(n == 10, "10 greffes de Spore (%d)" % n)
	var builds: Dictionary = Content._load("builds")
	var spore := 0
	for b in builds:
		if not str(b).begins_with("_") and builds[b].get("branch", "") == "spore":
			spore += 1
	check(spore == 3, "3 builds de Spore (%d)" % spore)


func _test_vesse() -> void:
	print("Vesse-de-loup")
	game.test_skills = {"vesse": true}
	game.recompute()
	_with([])
	var obj = p.skill_object("vesse")
	obj.shrooms.clear()
	p.aim_point = Vector2(200, 0)
	p.cast("vesse", game.stats)
	check(obj.shrooms.size() == 1 and obj.shrooms[0]["pos"].distance_to(Vector2(200, 0)) < 1.0, "un champignon pousse au point visé")
	var e = _spawn(Vector2(200, 40))
	await _steps(10)
	check(obj.shrooms.size() == 1 and e.hp == e.max_hp, "pas encore armé : il attend (0,5 s)")
	await _steps(30)
	check(obj.shrooms.is_empty(), "armé, il éclate quand un ennemi s'approche")
	check(e.hp < e.max_hp, "l'éclatement blesse l'ennemi")
	check(_zones("vesse").size() == 1, "il laisse un nuage de spores")
	var before: float = e.hp
	await _steps(40)
	check(e.hp < before and e.poison_time > 0.0, "le nuage ronge et empoisonne")
	_clear()
	# Au plus « max » champignons : en planter un de plus fait éclater le plus ancien.
	obj.shrooms.clear()
	var k: Dictionary = p.skill("vesse")
	for i in int(k["max"]) + 1:
		p.aim_point = Vector2(100 + i * 50, 0)
		p.cast("vesse", game.stats)
	check(obj.shrooms.size() == int(k["max"]), "au plus %d champignons à la fois" % int(k["max"]))
	check(_zones("vesse").size() == 1, "le plus ancien a éclaté")
	obj.shrooms.clear()
	_clear()


func _test_essaim() -> void:
	print("Essaim")
	game.test_skills = {"essaim": true}
	game.recompute()
	_with([])
	var obj = p.skill_object("essaim")
	obj.chains.clear()
	var list := []
	for i in 5:
		list.append(_spawn(Vector2(150 + i * 120, 0)))
	p.aim_point = Vector2(150, 0)
	p.cast("essaim", game.stats)
	check(list[0].hp < list[0].max_hp and list[0].poison_time > 0.0, "le premier ennemi est touché et empoisonné")
	await _steps(60)
	var hit := list.filter(func(e): return e.poison_time > 0.0).size()
	check(hit == 5, "l'essaim saute d'ennemi en ennemi (%d sur 5)" % hit)
	check(obj.chains.is_empty(), "l'essaim s'arrête quand il n'a plus d'ennemi à portée")
	_clear()
	# Sauts limités.
	game.test_skills = {"essaim": true}
	_with([{"skill_mod": "essaim", "param": "jumps", "op": "set", "value": 1, "text": "test"}])
	list = []
	for i in 4:
		list.append(_spawn(Vector2(150 + i * 120, 0)))
	p.cast("essaim", game.stats)
	await _steps(60)
	hit = list.filter(func(e): return e.poison_time > 0.0).size()
	check(hit == 2, "un seul saut : deux ennemis touchés (%d)" % hit)
	_clear()


func _test_eclosion() -> void:
	print("Éclosion")
	game.test_skills = {"eclosion": true}
	game.recompute()
	_with([])
	var a = _spawn(Vector2(100, 0))
	var b = _spawn(Vector2(-100, 0))
	var c = _spawn(Vector2(100, 60))
	a.apply_poison(50.0, 4.0)
	await _frames(1)
	var before_a: float = a.hp
	var before_b: float = b.hp
	p.cast("eclosion", game.stats)
	var lost_a: float = before_a - a.hp
	var lost_b: float = before_b - b.hp
	check(lost_a > 150.0, "le poison restant éclot d'un coup (%.0f dégâts, ~200 de poison restant)" % lost_a)
	check(lost_b > 0.0 and lost_b < lost_a / 5.0, "un ennemi sans poison ne prend qu'un petit coup")
	check(a.poison_time <= 0.0, "le poison est consommé")
	check(c.poison_time > 0.0, "les spores empoisonnent le voisin")
	_clear()
	# Mutation « keep » : la moitié du poison reste.
	_with([{"skill_mod": "eclosion", "param": "keep", "op": "set", "value": 0.5, "text": "test"}])
	a = _spawn(Vector2(100, 0))
	a.apply_poison(50.0, 4.0)
	p.cast("eclosion", game.stats)
	check(a.poison_time > 1.0, "Éclosion lente : la moitié du poison reste (%.1f s)" % a.poison_time)
	_clear()


func _test_cloud_follow() -> void:
	print("Nuage de spores qui suit (Brouillard vivant)")
	game.test_skills = {"cloud": true}
	game.recompute()
	_with([{"skill_mod": "cloud", "param": "follow", "op": "set", "value": true, "text": "test"}])
	p.aim_point = Vector2(300, 0)
	p.cast("cloud", game.stats)
	check(main.fx.clouds.size() == 1 and main.fx.clouds[0]["pos"].distance_to(p.position) < 1.0, "le nuage naît sur le joueur")
	p.position = Vector2(80, 50)
	await _frames(2)
	check(main.fx.clouds[0]["pos"].distance_to(p.position) < 1.0, "le nuage suit le joueur")
	p.position = Vector2.ZERO
	_with([])
	p.cast("cloud", game.stats)
	check(main.fx.clouds[-1]["pos"].distance_to(Vector2(300, 0)) < 1.0, "sans la mutation, il naît au point visé")
	_clear()


func _test_forms() -> void:
	print("Formes de Spore")
	_with([{"attack_form": "spore_lobee"}])
	check(str(AttackScript.current()["form"]) == "spore_lobee", "Spores lobées actives")
	var near = _spawn(Vector2(100, 0))
	var far = _spawn(Vector2(250, 0))
	AttackScript.fire(p, far)
	await _frames(10)
	check(near.hp == near.max_hp, "la spore passe au-dessus des ennemis en vol")
	await _frames(40)
	check(far.hp < far.max_hp, "elle éclate à l'arrivée et blesse la cible")
	check(_zones("lobee").size() >= 1, "elle laisse un petit nuage")
	var before: float = far.hp
	await _frames(40)
	check(far.hp < before and far.poison_time > 0.0, "le nuage ronge et empoisonne")
	_clear()

	_with([{"attack_form": "dard"}])
	check(str(AttackScript.current()["form"]) == "dard", "Dards fongiques actifs")
	var d1 = _spawn(Vector2(80, 0))
	var d2 = _spawn(Vector2(160, 0))
	AttackScript.fire(p, Vector2(300, 0))
	await _frames(15)
	check(d1.hp < d1.max_hp and d2.hp < d2.max_hp, "le dard perfore un ennemi")
	var gd: float = AttackScript.interval(game.stats, {"form": "graine", "mods": {}, "factor": 0.0})
	var dd: float = AttackScript.interval(game.stats)
	check(dd < gd, "les dards partent plus vite que les graines")
	_clear()


func _test_mods() -> void:
	print("Modificateurs de Spore")
	# Saut : seulement vers un ennemi empoisonné.
	_with([{"attack_mod": "saut", "value": 1}])
	var first = _spawn(Vector2(60, 0))
	var clean = _spawn(Vector2(60, 90))
	var sick = _spawn(Vector2(60, -150))
	sick.apply_poison(1.0, 10.0)
	AttackScript.fire(p, first)
	await _frames(25)
	check(sick.hp < sick.max_hp, "saut : le projectile rejoint l'ennemi empoisonné")
	check(clean.hp == clean.max_hp, "saut : il ignore l'ennemi sain, même plus proche")
	_clear()

	# Bouffée : un ennemi tué libère un petit nuage.
	_with([{"attack_mod": "bouffee", "value": 0.5}])
	var weak = _spawn(Vector2(60, 0), 1.0)
	AttackScript.fire(p, weak)
	await _frames(10)
	check((not is_instance_valid(weak) or weak.dead) and _zones("bouffee").size() == 1, "bouffée : l'ennemi tué libère un nuage")
	_clear()


func _test_action() -> void:
	print("Action « cloud »")
	_with([])
	var e = _spawn(Vector2(30, 0))
	EffectActions.run("cloud", {"radius": 100, "duration": 2, "factor": 1.0}, {"main": main, "stats": game.stats})
	check(_zones("effet").size() == 1, "un nuage autour du joueur")
	await _frames(40)
	check(e.hp < e.max_hp and e.poison_time > 0.0, "il ronge et empoisonne")
	_clear()
