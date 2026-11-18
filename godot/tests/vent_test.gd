## Test de la branche Vent : compétences (tornade, ruée, appel d'air), formes de l'attaque (lames de
## vent, bourrasque), modificateurs (élan, repousse), actions (rafale, tornade), « no_push »,
## grappes et builds de la branche.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/vent_test.gd
extends SceneTree

const AttackScript = preload("res://scripts/attack.gd")
const Planner = preload("res://scripts/tree_planner.gd")
const Content = preload("res://scripts/content.gd")
const DT := 1.0 / 60.0

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


## Fait avancer les compétences de n pas (le joueur ne tourne pas : seules les actions du test comptent).
func _ticks(n: int) -> void:
	for i in n:
		main._rebuild_grid()
		p._tick_skills(DT)
		await physics_frame


func _spawn(pos: Vector2, hp := 1.0e6):
	var e = Enemy.new()
	e.main = main
	e.position = pos
	e.setup(0, 50.0)
	e.hp = hp
	e.max_hp = hp
	main.enemies_layer.add_child(e)
	main.enemies.append(e)
	e.set_physics_process(false)
	main._rebuild_grid()
	return e


func _clear() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	for c in main.projectiles_layer.get_children():
		c.queue_free()
	p.attack_rt = {}
	main._rebuild_grid()


func _with(effects: Array) -> void:
	game.effects.rebuild([{"id": "test", "ring": 1, "effects": effects}])
	game.stats = game.effects.stats
	game.stats["crit"] = 0.0


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
	p.aim_point = Vector2(300, 0)
	_clear()

	_test_data()
	await _test_tornade()
	await _test_ruee()
	await _test_appel()
	await _test_lame()
	await _test_bourrasque()
	await _test_actions()
	_test_tree()

	game.test_skills = {}
	game.reset()
	main.queue_free()
	await process_frame
	print("RÉSULTAT : ", "tout est bon" if failures == 0 else "%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


func _test_data() -> void:
	print("Données")
	var skills := Content.skills()
	for id in ["tornade", "ruee", "appel_air"]:
		check(skills.has(id) and skills[id]["branch"] == "vent", "compétence « %s » de la branche Vent" % id)
		check(ResourceLoader.exists("res://scripts/skills/%s.gd" % id), "compétence « %s » a son fichier" % id)
		check(Art.ELEMENT_DE_COMPETENCE.get(id) == "vent", "compétence « %s » : élément vent" % id)
	for f in ["lame", "bourrasque"]:
		check(AttackScript.forms().get(f, {}).get("branch") == "vent", "forme « %s » de la branche Vent" % f)
		check(Art.icon_ids().has("attaque_" + f), "forme « %s » a son icône" % f)
	for m in ["elan", "repousse"]:
		check(AttackScript.mods().has(m), "modificateur « %s »" % m)
	var grafts: Dictionary = Content._load("grafts")
	for g in ["greffe_plume_vive", "greffe_girouette", "greffe_alize", "greffe_cerf_volant", "greffe_oeil_tempete", "greffe_souffle_ancien"]:
		check(grafts.has(g), "greffe « %s » (citée par la région de Vent)" % g)
	var n := 0
	for g in grafts:
		if not g.begins_with("_") and str(grafts[g].get("color", "")) != "" and g in ["greffe_plume_vive", "greffe_girouette", "greffe_alize", "greffe_cerf_volant", "greffe_oeil_tempete", "greffe_souffle_ancien", "greffe_vortex", "greffe_bise", "greffe_trombe", "greffe_vent_coupant"]:
			n += 1
	check(n == 10, "10 greffes de Vent (%d)" % n)


func _test_tornade() -> void:
	print("Tornade")
	_clear()
	_with([{"skill": "tornade"}])
	var on_path = _spawn(Vector2(200, 0))
	var near = _spawn(Vector2(200, 110))
	var far = _spawn(Vector2(-400, 0))
	var y0: float = near.position.y
	p.aim = Vector2.RIGHT
	p.cast("tornade", game.stats)
	await _ticks(120)
	check(on_path.hp < on_path.max_hp, "la tornade blesse ce qu'elle traverse")
	check(near.position.y < y0, "elle aspire les ennemis proches (%.0f → %.0f)" % [y0, near.position.y])
	check(far.hp == far.max_hp, "rien derrière le joueur")
	var tor = p.skill_object("tornade")
	await _ticks(200)
	check(tor.live.is_empty(), "elle se dissipe au bout de sa durée")
	# Mutation : la tornade tourne autour du joueur.
	_with([{"skill": "tornade"}, {"skill_mod": "tornade", "param": "orbit", "op": "set", "value": true, "text": "x"}])
	p.cast("tornade", game.stats)
	await _ticks(30)
	var d: float = tor.live[0]["pos"].distance_to(p.position)
	check(absf(d - 130.0) < 1.0, "Tourbillon gardien : la tornade tourne autour du joueur (%.0f px)" % d)
	await _ticks(400)
	# Le Menhir (« no_push ») ne bouge pas.
	_clear()
	_with([{"skill": "tornade"}])
	var rock = _spawn(Vector2(200, 100))
	rock.data = rock.data.duplicate()
	rock.data["no_push"] = true
	var at: Vector2 = rock.position
	p.cast("tornade", game.stats)
	await _ticks(90)
	check(rock.position == at, "un ennemi « no_push » n'est pas aspiré")
	await _ticks(300)


func _test_ruee() -> void:
	print("Ruée")
	_clear()
	_with([{"skill": "ruee"}])
	var a = _spawn(Vector2(100, 0))
	var b = _spawn(Vector2(220, 10))
	var c = _spawn(Vector2(100, 300))
	p.position = Vector2.ZERO
	p.invuln = 0.0
	p.aim = Vector2.RIGHT
	p.cast("ruee", game.stats)
	check(p.invuln > 0.1, "intouchable pendant la ruée")
	await _ticks(30)
	var k: Dictionary = p.skill("ruee")
	check(absf(p.position.x - float(k["length"])) < 2.0, "le joueur avance de %d px (%.0f)" % [int(k["length"]), p.position.x])
	check(a.hp < a.max_hp and b.hp < b.max_hp, "tout ce qui est sur le passage est frappé")
	check(absf((a.max_hp - a.hp) - p.skill_damage("ruee") * p.main.branch_factor(a, "vent")) < 0.5, "une seule fois par ennemi")
	check(c.hp == c.max_hp, "rien hors du passage")
	check(absf(a.position.y) > 20.0, "les ennemis sont écartés de la route")
	p.position = Vector2.ZERO
	p.invuln = 1e9
	# Sillage de tempête : une tornade naît au bout de la ruée.
	_with([{"skill": "ruee"}, {"skill_mod": "ruee", "param": "wake", "op": "set", "value": 0.6, "text": "x"}])
	var tor = p.skill_object("tornade")
	var before: int = tor.live.size()
	p.cast("ruee", game.stats)
	await _ticks(30)
	check(tor.live.size() == before + 1, "Sillage de tempête : une tornade au bout de la ruée")
	p.position = Vector2.ZERO
	await _ticks(300)


func _test_appel() -> void:
	print("Appel d'air")
	_clear()
	_with([{"skill": "appel_air"}])
	var e1 = _spawn(Vector2(300, 180))
	var e2 = _spawn(Vector2(440, -120))
	var out = _spawn(Vector2(300, 600))
	p.aim_point = Vector2(300, 0)
	p.cast("appel_air", game.stats)
	await _ticks(10)
	check(e1.hp == e1.max_hp, "rien tant que l'air aspire")
	await _ticks(40)
	check(e1.position.distance_to(Vector2(300, 0)) < 70.0 and e2.position.distance_to(Vector2(300, 0)) < 70.0,
		"les ennemis sont regroupés au centre (%.0f, %.0f px)" % [e1.position.distance_to(Vector2(300, 0)), e2.position.distance_to(Vector2(300, 0))])
	check(e1.hp < e1.max_hp and e2.hp < e2.max_hp, "puis l'air éclate sur eux")
	check(out.hp == out.max_hp and out.position == Vector2(300, 600), "hors du rayon, rien")
	_with([{"skill": "appel_air"}, {"skill_mod": "appel_air", "param": "root", "op": "set", "value": 1.5, "text": "x"}])
	p.cast("appel_air", game.stats)
	await _ticks(50)
	check(e1.root_time > 0.5, "Œil calme : les ennemis regroupés sont immobilisés")


func _test_lame() -> void:
	print("Lames de vent")
	_clear()
	p.position = Vector2.ZERO
	_with([{"attack_form": "lame"}])
	check(game.attack()["form"] == "lame", "la forme « lame » s'active")
	var e = _spawn(Vector2(150, 0))
	AttackScript.fire(p, e)
	var shots: Array = main.projectiles_layer.get_children().filter(func(c): return not c.is_queued_for_deletion())
	check(shots.size() == int(game.stats["projectiles"]) and shots[0].returning, "une lame qui revient par projectile")
	var one: float = shots[0].damage * main.branch_factor(e, "vent")
	var hp0: float = e.hp
	for i in 30:
		main._rebuild_grid()
		await physics_frame
	check(absf((hp0 - e.hp) - one) < 0.5, "l'aller touche une fois")
	var gone := false
	for i in 120:
		main._rebuild_grid()
		await physics_frame
		if not is_instance_valid(shots[0]) or shots[0].is_queued_for_deletion():
			gone = true
			break
	check(absf((hp0 - e.hp) - 2.0 * one) < 0.5, "le retour touche encore (%.1f dégâts, attendu %.1f)" % [hp0 - e.hp, 2.0 * one])
	check(gone, "la lame disparaît en revenant au joueur")
	# Élan : bonus en mouvement seulement.
	_with([{"attack_form": "lame"}, {"attack_mod": "elan", "value": 0.3}])
	p.still_time = 5.0
	var still: float = AttackScript.hit_damage(p, game.attack())
	p.still_time = 0.0
	var moving: float = AttackScript.hit_damage(p, game.attack())
	check(absf(moving - still * 1.3) < 0.01, "élan : +30 % en mouvement")
	_clear()


func _test_bourrasque() -> void:
	print("Bourrasque et repousse")
	_clear()
	_with([{"attack_form": "bourrasque"}])
	var front = _spawn(Vector2(120, 0))
	var back = _spawn(Vector2(-120, 0))
	AttackScript.fire(p, front)
	check(front.hp < front.max_hp and back.hp == back.max_hp, "le cône frappe devant, pas derrière")
	check(front.position.x > 150.0, "et repousse (%.0f px)" % front.position.x)
	_clear()
	_with([{"attack_mod": "repousse", "value": 30}])
	var e = _spawn(Vector2(100, 0))
	AttackScript.apply_on_hit(main, {"form": "graine", "repousse": 30.0}, e, 1.0, e.position)
	check(absf(e.position.x - 130.0) < 0.1, "repousse : l'ennemi recule de 30 px")
	_clear()


func _test_actions() -> void:
	print("Actions de Vent")
	_clear()
	_with([])
	var e = _spawn(Vector2(80, 0))
	var EffectActions = load("res://scripts/effect_actions.gd")
	EffectActions.run("gust", {"radius": 150, "factor": 1.0, "push": 60}, {"main": main, "stats": game.stats})
	check(e.hp < e.max_hp and e.position.x > 130.0, "rafale : blesse et repousse")
	var tor = p.skill_object("tornade")
	var n: int = tor.live.size()
	EffectActions.run("tornado", {"factor": 0.5, "at": "enemy"}, {"main": main, "stats": game.stats, "enemy": e})
	check(tor.live.size() == n + 1 and tor.live[-1]["pos"] == e.position, "tornade : naît sur l'ennemi")
	await _ticks(300)
	_clear()


func _test_tree() -> void:
	print("Arbre")
	var t = game.tree
	var owned := {0: true}
	var want := {"c:vent:lames:l1": 4, "c:vent:course:r6": 6, "c:vent:cyclone:t1": 7, "key:rafale": 6, "key:pas_du_vent": 9, "c:vent:appel:p1": 12}
	for uid in want:
		check(t.by_uid.has(uid), "nœud %s présent" % uid)
		if t.by_uid.has(uid):
			var d: int = Planner.shortest_path(t, owned, t.by_uid[uid]).size()
			check(d <= want[uid], "%s à %d points de la graine (au plus %d)" % [uid, d, want[uid]])
	var builds: Dictionary = Content._load("builds")
	var vent := 0
	for b in builds:
		if not b.begins_with("_") and builds[b].get("branch") == "vent":
			vent += 1
			for uid in builds[b]["targets"]:
				check(t.by_uid.has(uid), "build %s : cible %s présente" % [b, uid])
	check(vent >= 2, "au moins deux builds de Vent (%d)" % vent)
