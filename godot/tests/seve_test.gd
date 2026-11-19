## Test de la branche Sève : compétences (liane buveuse, fontaine de sève, cocon de sève), forme de
## l'attaque (perles de sève), modificateurs (sangsue, rosée), « no_drain », greffes, grappes et
## builds de la branche.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/seve_test.gd
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
	await _test_liane()
	await _test_fontaine()
	await _test_cocon()
	await _test_perle()
	await _test_mods()
	_test_tree()

	game.test_skills = {}
	game.reset()
	main.queue_free()
	await process_frame
	print("RÉSULTAT : ", "tout est bon" if failures == 0 else "%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


const SEVE_GRAFTS := ["greffe_rosee", "greffe_bourgeon", "greffe_sureau", "greffe_mousse", "greffe_source_vive", "greffe_coeur_de_saule", "greffe_seve_amere", "greffe_coque"]


func _test_data() -> void:
	print("Données")
	var skills := Content.skills()
	for id in ["liane", "fontaine", "cocon"]:
		check(skills.has(id) and skills[id]["branch"] == "seve", "compétence « %s » de la branche Sève" % id)
		check(ResourceLoader.exists("res://scripts/skills/%s.gd" % id), "compétence « %s » a son fichier" % id)
		check(Art.ELEMENT_DE_COMPETENCE.get(id) == "seve", "compétence « %s » : élément sève" % id)
		check(Art.icon_ids().has(id), "compétence « %s » a son icône" % id)
	check(AttackScript.forms().get("perle", {}).get("branch") == "seve", "forme « perle » de la branche Sève")
	check(Art.icon_ids().has("attaque_perle"), "forme « perle » a son icône")
	for m in ["sangsue", "rosee"]:
		check(AttackScript.mods().has(m), "modificateur « %s »" % m)
	var grafts: Dictionary = Content._load("grafts")
	for g in SEVE_GRAFTS:
		check(grafts.has(g), "greffe « %s »" % g)
	# Greffes citées par la région de Sève (thread « Créer la région Sève ») : une de chaque source.
	for pair in [["greffe_rosee", "autel"], ["greffe_bourgeon", "autel"], ["greffe_sureau", "autel"], ["greffe_mousse", "autel"],
			["greffe_source_vive", "secret"], ["greffe_coeur_de_saule", "boss"]]:
		check(grafts.get(pair[0], {}).get("sources", []).has(pair[1]), "greffe « %s » : source %s" % pair)


func _test_liane() -> void:
	print("Liane buveuse")
	_clear()
	_with([{"skill": "liane"}])
	var a = _spawn(Vector2(300, 20))
	var b = _spawn(Vector2(330, -40))
	var c = _spawn(Vector2(280, 90))
	var d = _spawn(Vector2(300, 150))
	var far = _spawn(Vector2(-300, 0))
	p.aim_point = Vector2(300, 0)
	p.hp = 10.0
	p.cast("liane", game.stats)
	var obj = p.skill_object("liane")
	check(obj.live.size() == 3, "trois lianes accrochées (%d)" % obj.live.size())
	await _ticks(60)
	check(a.hp < a.max_hp and b.hp < b.max_hp and c.hp < c.max_hp, "les trois plus proches sont blessés")
	check(d.hp == d.max_hp and far.hp == far.max_hp, "pas les autres")
	check(p.hp > 10.0, "la vie bue revient au joueur (%.1f)" % p.hp)
	await _ticks(200)
	check(obj.live.is_empty(), "les lianes lâchent au bout de leur durée")
	# « no_drain » : blessé sans rien rendre.
	_clear()
	_with([{"skill": "liane"}])
	var boss = _spawn(Vector2(300, 0))
	boss.data = boss.data.duplicate()
	boss.data["no_drain"] = true
	p.hp = 10.0
	p.cast("liane", game.stats)
	await _ticks(60)
	check(boss.hp < boss.max_hp and absf(p.hp - 10.0) < 0.001, "un ennemi « no_drain » ne rend rien (%.2f)" % p.hp)
	await _ticks(200)
	# Mutation « jump » : la liane passe à l'ennemi le plus proche quand le sien meurt.
	_clear()
	_with([{"skill": "liane"}, {"skill_mod": "liane", "param": "jump", "op": "set", "value": true, "text": "x"},
		{"skill_mod": "liane", "param": "count", "op": "set", "value": 1, "text": "x"}])
	var weak = _spawn(Vector2(300, 0), 1.0)
	var next = _spawn(Vector2(360, 0))
	p.cast("liane", game.stats)
	await _ticks(30)
	check((not is_instance_valid(weak) or weak.dead) and next.hp < next.max_hp, "Liane sauteuse : la liane passe au suivant")
	await _ticks(200)
	p.hp = game.stats["max_hp"]


func _test_fontaine() -> void:
	print("Fontaine de sève")
	_clear()
	_with([{"skill": "fontaine"}])
	var inside = _spawn(Vector2(60, 0))
	var out = _spawn(Vector2(400, 0))
	p.position = Vector2.ZERO
	p.hp = 10.0
	p.cast("fontaine", game.stats)
	var obj = p.skill_object("fontaine")
	await _ticks(60)
	var k: Dictionary = p.skill("fontaine")
	var want: float = 10.0 + game.stats["max_hp"] * float(k["regen"]) * 1.0
	check(absf(p.hp - want) < 1.0, "dans la source, le joueur régénère (%.1f, attendu %.1f)" % [p.hp, want])
	check(inside.hp < inside.max_hp and out.hp == out.max_hp, "elle ronge les ennemis dedans, pas dehors")
	p.position = Vector2(600, 0)
	var h: float = p.hp
	await _ticks(30)
	check(absf(p.hp - h) < 0.01, "hors de la source, rien")
	await _ticks(400)
	check(obj.live.is_empty(), "elle s'assèche au bout de sa durée")
	# Mutation « follow ».
	_with([{"skill": "fontaine"}, {"skill_mod": "fontaine", "param": "follow", "op": "set", "value": true, "text": "x"}])
	p.position = Vector2.ZERO
	p.cast("fontaine", game.stats)
	p.position = Vector2(500, 0)
	await _ticks(2)
	check(obj.inside(), "Source vagabonde : la source suit le joueur")
	await _ticks(400)
	# Mutation « geyser » : à la fin, la source jaillit (3 × dégâts de la compétence).
	_clear()
	_with([{"skill": "fontaine"}, {"skill_mod": "fontaine", "param": "geyser", "op": "set", "value": 3.0, "text": "x"}])
	p.position = Vector2.ZERO
	var g = _spawn(Vector2(60, 0))
	p.cast("fontaine", game.stats)
	var burst: float = 3.0 * p.skill_damage("fontaine") * main.branch_factor(g, "seve")
	await _ticks(355)
	var before: float = g.hp
	await _ticks(10)
	check(before - g.hp >= burst * 0.95, "geyser : la source jaillit à la fin (%.1f, attendu %.1f)" % [before - g.hp, burst])
	p.hp = game.stats["max_hp"]


func _test_cocon() -> void:
	print("Cocon de sève")
	_clear()
	_with([{"skill": "cocon"}])
	p.position = Vector2.ZERO
	p.invuln = 0.0
	p.hp = game.stats["max_hp"]
	p.cast("cocon", game.stats)
	var obj = p.skill_object("cocon")
	var full: float = game.stats["max_hp"] * float(p.skill("cocon")["shield"])
	check(absf(obj.shield - full) < 0.01, "bouclier de %.0f" % full)
	p.take_hit(10.0, null)
	check(p.hp == game.stats["max_hp"] and absf(obj.shield - (full - 10.0)) < 0.01, "le cocon boit le coup")
	p.invuln = 0.0
	p.take_hit(full * 2.0, null)
	check(obj.shield == 0.0 and p.hp < game.stats["max_hp"], "percé, le reste du coup passe")
	# Fin du cocon : le reste soigne et l'éclatement blesse.
	p.invuln = 1e9
	p.hp = 20.0
	var e = _spawn(Vector2(80, 0))
	p.cast("cocon", game.stats)
	await _ticks(int(float(p.skill("cocon")["duration"]) * 60.0) + 5)
	check(obj.shield == 0.0, "le cocon se défait à la fin")
	check(absf(p.hp - (20.0 + full)) < 1.0, "le bouclier restant soigne (%.1f)" % p.hp)
	check(e.hp < e.max_hp, "l'éclatement blesse autour")
	# Mutation « reflect ».
	_with([{"skill": "cocon"}, {"skill_mod": "cocon", "param": "reflect", "op": "set", "value": 0.6, "text": "x"}])
	var foe = _spawn(Vector2(30, 0))
	p.invuln = 0.0
	p.cast("cocon", game.stats)
	p.take_hit(10.0, foe)
	check(absf((foe.max_hp - foe.hp) - 6.0) < 0.5, "Cocon épineux : 60 %% renvoyés (%.1f)" % (foe.max_hp - foe.hp))
	p.invuln = 1e9
	await _ticks(300)
	p.hp = game.stats["max_hp"]


func _test_perle() -> void:
	print("Perles de sève")
	_clear()
	p.position = Vector2.ZERO
	_with([{"attack_form": "perle"}])
	check(game.attack()["form"] == "perle", "la forme « perle » s'active")
	var e = _spawn(Vector2(150, 0))
	var side = _spawn(Vector2(170, 30))
	p.hp = 10.0
	AttackScript.fire(p, e)
	var shots: Array = main.projectiles_layer.get_children().filter(func(c): return not c.is_queued_for_deletion())
	check(shots.size() == int(game.stats["projectiles"]) and shots[0].style == "perle", "une perle par projectile")
	var dmg: float = shots[0].damage
	for i in 40:
		main._rebuild_grid()
		await physics_frame
	check(e.hp < e.max_hp, "la perle touche")
	check(side.hp < side.max_hp, "et éclabousse autour")
	var f: Dictionary = AttackScript.forms()["perle"]
	check(absf(p.hp - (10.0 + dmg * float(f["leech"]))) < 0.05, "elle rend un peu de vie (%.2f)" % p.hp)
	_clear()
	p.hp = game.stats["max_hp"]


func _test_mods() -> void:
	print("Sangsue et rosée")
	_clear()
	_with([{"attack_mod": "sangsue", "value": 0.1}])
	var e = _spawn(Vector2(100, 0))
	p.hp = 10.0
	AttackScript.apply_on_hit(main, {"form": "graine", "sangsue": 0.1}, e, 20.0, e.position)
	check(absf(p.hp - 12.0) < 0.01, "sangsue : 10 %% des dégâts rendus (%.2f)" % p.hp)
	var dead = _spawn(Vector2(100, 0), 1.0)
	dead.dead = true
	p.hp = 10.0
	p.t = 100.0
	AttackScript.apply_on_hit(main, {"form": "graine", "rosee": 0.05}, dead, 20.0, dead.position)
	var once: float = p.hp
	check(absf(once - (10.0 + game.stats["max_hp"] * 0.05)) < 0.01, "rosée : un ennemi tué rend 5 %% de la vie (%.1f)" % once)
	AttackScript.apply_on_hit(main, {"form": "graine", "rosee": 0.05}, dead, 20.0, dead.position)
	check(p.hp == once, "rosée : au plus quatre fois par seconde")
	p.t = 101.0
	AttackScript.apply_on_hit(main, {"form": "graine", "rosee": 0.05}, dead, 20.0, dead.position)
	check(p.hp > once, "rosée : de nouveau après le délai")
	dead.dead = false
	_clear()
	p.hp = game.stats["max_hp"]


func _test_tree() -> void:
	print("Arbre")
	var t = game.tree
	var owned := {0: true}
	var want := {"c:seve:perles:p1": 4, "c:seve:lianes:n1": 6, "c:seve:sources:f1": 8, "c:seve:ecorce:c1": 9,
		"c:seve:cocon:k1": 12, "c:seve:rosee:r1": 15, "c:seve:coeur:h1": 15, "key:bloom": 5}
	for uid in want:
		check(t.by_uid.has(uid), "nœud %s présent" % uid)
		if t.by_uid.has(uid):
			var d: int = Planner.shortest_path(t, owned, t.by_uid[uid]).size()
			check(d <= want[uid], "%s à %d points de la graine (au plus %d)" % [uid, d, want[uid]])
	for flag in ["seve_coeur_purifie", "seve_boss_vaincu"]:
		var found := false
		for n in t.nodes:
			if str(n.get("requires_flag", "")) == flag:
				found = true
		check(found, "un nœud flétri attend « %s »" % flag)
	var builds: Dictionary = Content._load("builds")
	var seve := 0
	for b in builds:
		if not b.begins_with("_") and builds[b].get("branch") == "seve":
			seve += 1
			for uid in builds[b]["targets"]:
				check(t.by_uid.has(uid), "build %s : cible %s présente" % [b, uid])
	check(seve >= 3, "au moins trois builds de Sève (%d)" % seve)
