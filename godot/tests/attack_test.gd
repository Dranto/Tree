## Test de l'attaque de base (attack.gd, data/attack.json) : forme de départ identique à l'ancien tir,
## priorité entre formes, cumul des modificateurs, chaque forme et chaque modificateur en jeu,
## salve déclenchée par un évènement, nœud de type « attack » et aperçu du planificateur sans effet
## de bord. Le test pose sa propre grappe : il ne dépend pas du contenu des branches.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/attack_test.gd
extends SceneTree

const SkillTree = preload("res://scripts/skill_tree.gd")
const Content = preload("res://scripts/content.gd")
const TreePlanner = preload("res://scripts/tree_planner.gd")
const AttackScript = preload("res://scripts/attack.gd")

var MainScene
var Enemy
var failures := 0
var game
var main
var p
var bid := ""
## Touffes de traînée posées par le dernier tir de _volley_damage.
var _tufts := 0


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


## Grappe de test : un nœud qui change la forme, un qui ajoute un modificateur.
func _cluster() -> Dictionary:
	return {
		"id": "att", "name": "Grappe d'attaque", "ring": 2, "angle": 0.5, "entry": ["f"],
		"nodes": [
			{"id": "f", "type": "attack", "name": "Fouet de test", "at": [0, 0], "effects": [{"attack_form": "fouet"}]},
			{"id": "m", "type": "attack", "name": "Fourche de test", "at": [0.7, 0], "links": ["f"], "effects": [{"attack_mod": "fourche", "value": 2}]},
		],
	}


## Remplace les effets de la partie par ceux d'un nœud imaginaire (anneau 1).
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
	p.attack_rt = {}
	main._rebuild_grid()


func _shots() -> Array:
	return main.projectiles_layer.get_children().filter(func(c): return not c.is_queued_for_deletion())


func _run() -> void:
	MainScene = load("res://scenes/main.tscn")
	Enemy = load("res://scripts/enemy.gd")
	game = root.get_node("Game")
	var b: Dictionary = SkillTree.BRANCHES[SkillTree.BRANCHES.size() - 1]
	bid = b["id"]
	var real_clusters = b.get("clusters", [])
	b["clusters"] = real_clusters + [_cluster()]
	var errors := PackedStringArray()
	Content._check_clusters([_cluster()], "test", {}, errors)
	check(errors.is_empty(), "la grappe d'attaque de test est valide (%s)" % ", ".join(errors))
	game.tree.build()
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
	_test_resolve()
	await _test_graine()
	await _test_forms()
	await _test_mods()
	await _test_echoes()
	await _test_every_mod_every_form()
	_test_synergies()
	await _test_node_and_planner()

	b["clusters"] = real_clusters
	print("ÉCHECS : %d" % failures if failures > 0 else "Tout est bon.")
	quit(1 if failures > 0 else 0)


func _test_data() -> void:
	print("Données")
	check(AttackScript.validate().is_empty(), "attack.json est valide (%s)" % ", ".join(AttackScript.validate()))
	for f in ["graine", "echarde", "fouet", "ronce_vive"]:
		check(AttackScript.forms().has(f), "la forme « %s » existe" % f)
		check(f == "graine" or Art.icon_ids().has("attaque_" + f), "la forme « %s » a son icône" % f)
	for m in ["fourche", "ricochet", "eclat", "saignement", "enracine", "trainee", "renforcee", "taille", "portee", "repetition", "volee", "poison"]:
		check(AttackScript.mods().has(m), "le modificateur « %s » existe" % m)
	var errs := PackedStringArray()
	Content._check_effects([{"attack_form": "inconnue"}, {"attack_mod": "fourche"}, {"attack_mod": "volee", "value": 0.5}, {"attack_mod": "fourche", "value": 1, "if": {"state": "immobile"}}], "test", errs)
	check(errs.size() == 4, "check_data refuse une forme inconnue, une valeur absente, un « une sur N » sous 1 et une condition (%d erreurs)" % errs.size())


func _test_resolve() -> void:
	print("Priorité des formes et cumul des modificateurs")
	check(AttackScript.resolve([], [])["form"] == "graine", "sans effet : la forme de départ, graine")
	var st := AttackScript.resolve([{"form": "graine", "priority": null, "ring": 9, "order": 0}, {"form": "echarde", "priority": null, "ring": 3, "order": 1}], [])
	check(st["form"] == "echarde", "une forme de priorité plus haute l'emporte sur la graine, même plus près de la graine")
	st = AttackScript.resolve([{"form": "fouet", "priority": null, "ring": 6, "order": 0}, {"form": "echarde", "priority": null, "ring": 4, "order": 1}], [])
	check(st["form"] == "fouet", "à priorité égale, le nœud le plus loin de la graine l'emporte")
	st = AttackScript.resolve([{"form": "fouet", "priority": null, "ring": 4, "order": 0}, {"form": "echarde", "priority": null, "ring": 4, "order": 1}], [])
	check(st["form"] == "echarde", "à égalité d'anneau, la dernière source l'emporte")
	st = AttackScript.resolve([{"form": "fouet", "priority": null, "ring": 9, "order": 0}, {"form": "ronce_vive", "priority": 5, "ring": 2, "order": 1}], [])
	check(st["form"] == "ronce_vive", "la « priority » écrite sur l'effet passe devant")
	st = AttackScript.resolve([], [
		{"attack_mod": "fourche", "value": 1}, {"attack_mod": "fourche", "value": 1},
		{"attack_mod": "renforcee", "value": 5}, {"attack_mod": "renforcee", "value": 3, "factor": 3.0},
		{"attack_mod": "enracine", "value": 0.5}, {"attack_mod": "enracine", "value": 0.5},
		{"attack_mod": "taille", "value": 0.2}, {"attack_mod": "taille", "value": 0.3},
		{"attack_mod": "inconnu", "value": 1},
	])
	check(st["mods"]["fourche"] == 2.0, "les fourches s'additionnent")
	check(st["mods"]["renforcee"] == 3.0 and st["factor"] == 3.0, "« une sur N » : le plus petit N, le plus grand facteur")
	check(absf(st["mods"]["enracine"] - 0.6) < 0.001, "la chance d'enraciner est plafonnée (0,6)")
	check(absf(st["mods"]["taille"] - 0.5) < 0.001, "la taille s'additionne comme un « inc »")
	check(not st["mods"].has("inconnu"), "un modificateur inconnu est ignoré")
	check(AttackScript.mod({"form": "fouet", "mods": {"fourche": 2.0}, "factor": 0.0}, "fourche") == 2.0, "la fourche agit aussi sur le fouet (tous les modificateurs sur toutes les formes)")


func _test_graine() -> void:
	print("Graine : les mêmes chiffres que l'ancien tir")
	game.reset()
	var s: Dictionary = game.stats
	check(game.attack()["form"] == "graine" and game.attack()["mods"].is_empty(), "partie neuve : graine sans modificateur")
	check(absf(AttackScript.interval(s) - 1.0 / s["fire_rate"]) < 1e-6, "cadence : 1 / vitesse d'attaque")
	AttackScript.fire(p, Vector2(300, 0))
	var shots := _shots()
	check(shots.size() == int(s["projectiles"]), "autant de graines que la statistique « projectiles »")
	var g = shots[0]
	check(absf(g.damage - s["damage"] * s["projectile_damage"]) < 1e-4, "dégâts : dégâts × dégâts des projectiles (%s)" % g.damage)
	check(absf(g.vel.length() - 640.0) < 0.01 and absf(g.life - 1.1) < 1e-4, "vitesse 640 et durée 1,1 s")
	check(g.pierce == int(s["pierce"]) and absf(g.radius - 6.0 * s["projectile_size"]) < 1e-4, "perforation et taille inchangées")
	check(g.position.is_equal_approx(Vector2(18, 0)) and g.attack.size() == 1, "part à 18 px vers la cible, sans modificateur")
	_clear()
	# Trois graines : éventail de 0,14 rad, comme avant.
	_with([{"stat": "projectiles", "op": "add", "value": 2}])
	AttackScript.fire(p, Vector2(300, 0))
	var angles: Array = _shots().map(func(c): return snappedf(c.vel.angle(), 0.001))
	angles.sort()
	check(angles == [-0.14, 0.0, 0.14], "trois graines en éventail de 0,14 rad (%s)" % str(angles))
	_clear()


func _test_forms() -> void:
	print("Formes")
	# Échardes : rafale de trois, perforantes, portée courte.
	_with([{"attack_form": "echarde"}])
	check(game.attack()["form"] == "echarde", "un effet attack_form change la forme")
	AttackScript.fire(p, Vector2(300, 0))
	check(_shots().size() == 1, "échardes : un premier tir tout de suite")
	AttackScript.step(p, 0.07)
	AttackScript.step(p, 0.07)
	var shots := _shots()
	check(shots.size() == 3, "puis la rafale complète (%d)" % shots.size())
	check(shots[0].style == "echarde" and shots[0].pierce == int(game.stats["pierce"]) + 2, "échardes perforantes (+2)")
	check(absf(shots[0].life * shots[0].vel.length() - 400.0) < 1.0, "portée courte (400 px)")
	_clear()

	# Fouet : arc au corps à corps, devant seulement.
	_with([{"attack_form": "fouet"}])
	var front = _spawn(Vector2(80, 0))
	var back = _spawn(Vector2(-80, 0))
	var far = _spawn(Vector2(400, 0))
	AttackScript.fire(p, front)
	check(front.hp < front.max_hp, "fouet : l'ennemi devant est touché")
	check(back.hp == back.max_hp and far.hp == far.max_hp, "derrière et loin : épargnés")
	check(_shots().is_empty(), "le fouet ne lance aucun projectile")
	check(main.attack_fx.effects.any(func(e): return e["id"] == "fouet"), "le coup de fouet a sa signature")
	check(absf(AttackScript.interval(game.stats) - 1.0 / (game.stats["fire_rate"] * 0.8)) < 1e-6, "cadence propre au fouet (×0,8)")
	_clear()

	# Ronces vives : la graine plante une ronce piégeuse là où elle tombe.
	_with([{"attack_form": "ronce_vive"}])
	AttackScript.fire(p, Vector2(-300, 0))
	check(_shots()[0].plant, "ronce vive : la graine sait qu'elle doit se planter")
	await _frames(70)
	var traps: Array = main.attack_fx.zones.filter(func(z): return z["kind"] == "piege")
	check(traps.size() == 1, "un piège planté au bout de sa course")
	if traps.size() == 1:
		var e = _spawn(traps[0]["pos"])
		await _frames(40)
		check(e.hp < e.max_hp and e.root_time > 0.0 or e.hp < e.max_hp, "un ennemi dans la ronce est blessé (%d)" % int(e.max_hp - e.hp))
	_clear()


func _test_echoes() -> void:
	print("Formes cumulées : la principale et les échos")
	var st := AttackScript.resolve([{"form": "echarde", "priority": null, "ring": 4, "order": 0}, {"form": "fouet", "priority": null, "ring": 4, "order": 1},
		{"form": "echarde", "priority": null, "ring": 2, "order": 2}], [])
	check(st["form"] == "fouet" and st["echoes"] == ["echarde"], "la forme principale reste, l'autre part en écho (une seule fois)")
	check(AttackScript.resolve([], [])["echoes"].is_empty(), "sans forme acquise : aucun écho")
	_with([{"attack_form": "echarde"}, {"attack_form": "fouet"}])
	st = game.attack()
	check(st["form"] == "fouet" and st["echoes"] == ["echarde"], "en jeu : fouet principal, échardes en écho")
	var e = _spawn(Vector2(80, 0))
	var est := AttackScript.echo_state(st, "echarde")
	var period := AttackScript.interval(game.stats, est)
	check(absf(period - 1.0 / game.stats["fire_rate"]) < 1e-6, "l'écho tire à sa propre cadence (%s s)" % period)
	AttackScript.step(p, period * 0.4)
	check(_shots().is_empty(), "le premier tir de l'écho est décalé")
	AttackScript.step(p, period * 0.2)
	var shots := _shots()
	check(shots.size() == 1 and shots[0].style == "echarde", "puis l'écho tire ses échardes (%d)" % shots.size())
	var main_st := AttackScript.resolve([{"form": "echarde", "priority": null, "ring": 1, "order": 0}], [])
	if shots.size() == 1:
		check(absf(shots[0].damage - AttackScript.hit_damage(p, main_st)) < 1e-4, "l'écho garde son plein bonus : mêmes dégâts que la forme seule (%s)" % shots[0].damage)
	for i in 4:
		AttackScript.step(p, 0.05)
	check(_shots().size() == 3, "toute la rafale de l'écho part (%d)" % _shots().size())
	AttackScript.fire(p, e)
	check(e.hp < e.max_hp, "la forme principale frappe toujours (fouet)")
	_clear()
	# Personne à portée de l'écho : il attend.
	_spawn(Vector2(600, 0))
	for i in 20:
		AttackScript.step(p, 0.1)
	check(_shots().is_empty(), "sans ennemi à sa portée, l'écho ne tire pas")
	_clear()
	# Un modificateur agit sur toutes les formes où il s'applique.
	_with([{"attack_form": "echarde"}, {"attack_form": "fouet"}, {"attack_mod": "fourche", "value": 1}])
	st = game.attack()
	check(AttackScript.mod(st, "fourche") == 1.0 and AttackScript.mod(AttackScript.echo_state(st, "echarde"), "fourche") == 1.0, "la fourche agit sur le fouet principal et sur l'écho d'échardes")
	check(AttackScript.applies_any("fourche", st), "l'infobulle ne dit pas « sans effet » quand un écho en profite")
	var lines := AttackScript.describe(st)
	check(lines.size() >= 2 and lines[1].begins_with("En écho"), "la description cite l'écho (%s)" % (lines[1] if lines.size() > 1 else ""))
	var before := AttackScript.resolve([{"form": "fouet", "priority": null, "ring": 1, "order": 0}], [])
	var d := AttackScript.diff(before, AttackScript.resolve([{"form": "fouet", "priority": null, "ring": 1, "order": 0}, {"form": "echarde", "priority": null, "ring": 0, "order": 1}], []))
	check(not d.is_empty() and "en écho" in str(d[0]["text"]), "l'aperçu annonce la nouvelle forme en écho (%s)" % str(d))
	# Arbre changé : les tirs en file d'un écho perdu se perdent.
	_spawn(Vector2(80, 0))
	AttackScript.fire(p, Vector2(300, 0), AttackScript.echo_state(st, "echarde"))
	_with([{"attack_form": "fouet"}])
	var n := _shots().size()
	for i in 4:
		AttackScript.step(p, 0.05)
	check(_shots().size() == n, "un écho retiré ne finit pas sa rafale")
	_clear()


## Tous les modificateurs se combinent avec toutes les formes : pour chaque forme et chaque
## modificateur autrefois réservé à certaines formes, un tir avec le modificateur fait plus de
## dégâts (ou sème une traînée) qu'un tir sans.
func _test_every_mod_every_form() -> void:
	print("Chaque modificateur sur chaque forme")
	for name in AttackScript.mods():
		check(not AttackScript.mods()[name].has("forms"), "« %s » n'est réservé à aucune forme" % name)
	var cases := {"fourche": 2, "ricochet": 2, "saut": 2, "trainee": 0.6, "refraction": 2, "secousse": 0.6}
	var bad: Array = []
	await _volley_damage([{"attack_form": "graine", "priority": 99}], "graine")   # mise en route
	for form in AttackScript.forms():
		var base := await _volley_damage([{"attack_form": form, "priority": 99}], form)
		for name in cases:
			var with := await _volley_damage([{"attack_form": form, "priority": 99}, {"attack_mod": name, "value": cases[name]}], form)
			# La traînée se juge à ses touffes (un coup qui repousse peut écarter les ennemis).
			var ok: bool = _tufts > 0 if name == "trainee" else with > base + 0.5
			if not ok:
				bad.append("%s + %s (%d contre %d)" % [form, name, int(with), int(base)])
	check(bad.is_empty(), "chaque forme profite de fourche, ricochet, saut, traînée, réfraction et secousse (%s)" % ", ".join(bad))
	_with([])


## Dégâts totaux d'une attaque (avec ses rafales et ce qu'elle fait naître) sur un petit groupe
## d'ennemis empoisonnés, en 80 pas de jeu.
func _volley_damage(effects: Array, form: String) -> float:
	_clear()
	_with(effects)
	main.rng.seed = 7
	var foes: Array = []
	# La cible, un ennemi sur le chemin, une couronne serrée autour de la cible, et des ennemis plus loin.
	var spots: Array = [Vector2(110, 0), Vector2(58, 0)]
	for i in 8:
		spots.append(Vector2(110, 0) + Vector2.from_angle(i * TAU / 8.0 + 0.2) * 48.0)
	spots.append_array([Vector2(190, 0), Vector2(250, 20), Vector2(300, -60), Vector2(280, 90)])
	for at in spots:
		var e = _spawn(at)
		e.apply_poison(0.001, 30.0)
		foes.append(e)
	await _frames(1)
	AttackScript.fire(p, foes[0])
	for i in 80:
		AttackScript.step(p, 1.0 / 60.0)
		await _frames(1)
	_tufts = main.attack_fx.zones.filter(func(z): return z["kind"] == "trainee").size()
	var total := 0.0
	for e in foes:
		if is_instance_valid(e):
			total += e.max_hp - e.hp
	_clear()
	return total


func _test_synergies() -> void:
	print("Synergies")
	check(AttackScript.validate_synergies().is_empty(), "synergies.json est valide (%s)" % ", ".join(AttackScript.validate_synergies()))
	check(AttackScript.synergies().size() >= 10, "au moins dix synergies (%d)" % AttackScript.synergies().size())
	var st := AttackScript.resolve([{"form": "rayon", "priority": null, "ring": 1, "order": 0}, {"form": "lame", "priority": null, "ring": 1, "order": 1}], [])
	check("aube_tranchante" in st["synergies"], "rayon d'aube + lames de vent : « Aube tranchante »")
	check(absf(float(st["mods"].get("incandescence", 0.0)) - 0.25) < 1e-6, "la synergie ajoute son modificateur d'attaque")
	var alone := AttackScript.resolve([{"form": "rayon", "priority": null, "ring": 1, "order": 0}], [])
	check(alone["synergies"].is_empty() and not alone["mods"].has("incandescence"), "une seule forme : pas de synergie")
	var crit0: float = game.stats["crit"]
	_with([{"attack_form": "rayon"}, {"attack_form": "lame"}])
	check(absf(game.stats["crit"] - 0.05 - 0.04) < 1e-6 or absf(game.stats["crit"] - crit0 - 0.04) < 1e-6, "la synergie ajoute ses statistiques (critique %s)" % game.stats["crit"])
	var arsenal := AttackScript.resolve([{"form": "rayon", "priority": null, "ring": 1, "order": 0}, {"form": "lame", "priority": null, "ring": 1, "order": 1}, {"form": "massue", "priority": null, "ring": 1, "order": 2}], [])
	check("arsenal" in arsenal["synergies"] and "massue_solaire" in arsenal["synergies"], "trois formes : « Arsenal », et la massue avec une forme d'Aube (%s)" % str(arsenal["synergies"]))
	var hints := AttackScript.synergy_hints([{"attack_form": "lame"}], game.attack())
	check(hints.any(func(h): return "Aube tranchante" in str(h[0]) and h[1]), "l'infobulle d'un nœud cite ses synergies, actives en or (%d)" % hints.size())
	var d := AttackScript.diff(alone, st)
	check(d.any(func(x): return x["stat"] == "synergy"), "l'aperçu annonce la synergie gagnée")
	var errs := PackedStringArray()
	Content._check_effects([{"stat": "inconnue", "op": "inc", "value": 1}], "test", errs)
	check(not errs.is_empty(), "check_data vérifie les effets d'une synergie comme ceux d'un nœud")
	_with([])


func _test_mods() -> void:
	print("Modificateurs")
	# Fourche : au premier coup, deux branches de plus.
	_with([{"attack_mod": "fourche", "value": 2}])
	_spawn(Vector2(60, 0))
	AttackScript.fire(p, Vector2(300, 0))
	await _frames(4)
	var forks := _shots().filter(func(c): return c.forked)
	check(forks.size() >= 2, "fourche : deux branches de plus (%d)" % forks.size())
	_clear()

	# Ricochet : rebond vers un autre ennemi.
	_with([{"attack_mod": "ricochet", "value": 1}])
	_spawn(Vector2(60, 0))
	var second = _spawn(Vector2(60, 150))
	AttackScript.fire(p, Vector2(300, 0))
	await _frames(25)
	check(second.hp < second.max_hp, "ricochet : le second ennemi est touché")
	_clear()

	# Saignement, poison, enracinement au coup.
	_with([{"attack_mod": "saignement", "value": 0.5}, {"attack_mod": "poison", "value": 0.5}, {"attack_mod": "enracine", "value": 1.0}])
	var e = _spawn(Vector2(60, 0))
	for i in 12:
		AttackScript.fire(p, e)
		await _frames(6)
	check(e.bleed_stacks.size() > 0, "saignement au coup")
	check(e.poison_time > 0.0, "poison au coup")
	# Enracinement : testé sans projectile ni hasard du tir (avant : 12 tirs à 60 %, instable quand les
	# projectiles s'accumulaient sans toucher). Chance 1 : toujours ; chance plafonnée du jeu (60 %)
	# avec un tirage à graine fixe : ni jamais, ni toujours.
	e.root_time = 0.0
	AttackScript.apply_on_hit(main, {"enracine": 1.0}, e, 1.0, e.position)
	check(e.root_time > 0.0, "enracinement : chance 1, l'ennemi est retenu")
	main.rng.seed = 12345
	var rooted := 0
	for i in 40:
		e.root_time = 0.0
		AttackScript.apply_on_hit(main, {"enracine": 0.6}, e, 1.0, e.position)
		if e.root_time > 0.0:
			rooted += 1
	check(rooted > 8 and rooted < 40, "enracinement : environ 60 %% des coups (%d sur 40)" % rooted)
	_clear()

	# Éclat : l'ennemi tué éclate en épines.
	_with([{"attack_mod": "eclat", "value": 0.5}])
	_spawn(Vector2(60, 0), 1.0)
	AttackScript.fire(p, Vector2(300, 0))
	await _frames(4)
	var shards := _shots().filter(func(c): return c.style == "eclat")
	check(shards.size() == int(AttackScript.mods()["eclat"]["count"]), "éclat : %d épines" % shards.size())
	_clear()

	# Traînée d'épines au sol.
	_with([{"attack_mod": "trainee", "value": 0.5}])
	AttackScript.fire(p, Vector2(300, 0))
	await _frames(20)
	check(main.attack_fx.zones.filter(func(z): return z["kind"] == "trainee").size() >= 3, "traînée : des touffes d'épines semées")
	_clear()

	# Renforcée (une sur 2) et volée (une sur 3).
	_with([{"attack_mod": "renforcee", "value": 2}, {"attack_mod": "volee", "value": 3}])
	AttackScript.fire(p, Vector2(300, 0))
	check(_shots().size() == 1 and not _shots()[0].empowered, "1re attaque : normale")
	_clear()
	p.attack_rt = {"count": 1, "queue": []}
	AttackScript.fire(p, Vector2(300, 0))
	var shots := _shots()
	check(shots.size() == 1 + 2 and shots[0].empowered and absf(shots[0].damage - game.stats["damage"] * game.stats["projectile_damage"] * 2.0) < 1e-3, "2e attaque : renforcée (+2 graines, dégâts ×2)")
	_clear()
	p.attack_rt = {"count": 2, "queue": []}
	AttackScript.fire(p, Vector2(300, 0))
	check(_shots().size() == 10, "3e attaque : volée en couronne (%d)" % _shots().size())
	_clear()

	# Taille, portée, répétition.
	_with([{"attack_mod": "taille", "value": 0.5}, {"attack_mod": "portee", "value": 0.5}, {"attack_mod": "repetition", "value": 1}])
	AttackScript.fire(p, Vector2(300, 0))
	var g = _shots()[0]
	check(absf(g.radius - 9.0) < 1e-3 and absf(g.life - 1.65) < 1e-3, "taille ×1,5 et portée ×1,5")
	AttackScript.step(p, 0.15)
	check(_shots().size() == 2, "répétition : l'attaque repart une fois")
	_clear()

	# Salve sur un évènement : « chaque coup reçu devient une salve ».
	_with([{"on": "hurt", "do": "attack_salvo", "count": 8, "text": "x"}])
	game.fire("hurt", {"main": main, "base": 5.0})
	check(_shots().size() == 8, "action attack_salvo : 8 graines tout autour (%d)" % _shots().size())
	_clear()
	_with([])


func _test_node_and_planner() -> void:
	print("Nœud de type « attack » et aperçu de l'arbre")
	game.reset()
	var tree = game.tree
	var f: int = tree.id_for_uid("c:%s:att:f" % bid)
	var m: int = tree.id_for_uid("c:%s:att:m" % bid)
	check(f > 0 and m > 0 and tree.nodes[f]["type"] == "attack", "les nœuds d'attaque sont dans l'arbre")
	check(tree.nodes[f]["attack_form"] == "fouet", "le nœud retient la forme qu'il donne (icône)")
	check(load("res://scripts/tree_art.gd").icon_of(tree.nodes[f]) == "attaque_fouet" and load("res://scripts/tree_art.gd").icon_of(tree.nodes[m]) == "attaque_mod", "icônes attaque_fouet et attaque_mod")
	check(SkillTree.describe(tree.nodes[f])[0].begins_with("Attaque de base : fouet"), "texte de l'infobulle (%s)" % SkillTree.describe(tree.nodes[f])[0])
	var planner = TreePlanner.new(game)
	var path: Array = planner.path_to(m)
	var before: Dictionary = game.attack().duplicate(true)
	var sim: Dictionary = planner.simulate(path)
	var changes: Array = planner.preview(path)
	var texts: Array = changes.map(func(c): return c["text"])
	check(sim["attack"]["form"] == "fouet" and sim["attack"]["mods"].get("fourche", 0.0) == 2.0, "la simulation donne le fouet et la fourche")
	check(texts.has("Attaque : Graines → Fouet"), "l'aperçu montre la forme avant → après (%s)" % ", ".join(texts))
	check(texts.any(func(t): return t.begins_with("Attaque : + fourche") and not t.ends_with("(sans effet sur cette forme)")), "et le modificateur, qui agit aussi sur le fouet")
	check(game.attack() == before, "la simulation ne touche pas l'attaque de la partie")
	game.points = path.size()
	check(planner.learn_path(path), "le chemin s'apprend")
	check(game.attack()["form"] == "fouet" and game.attack() == sim["attack"], "l'attaque réelle est celle que l'aperçu annonçait")
	check(planner.preview([]).is_empty(), "aucune différence quand on ne change rien")
	# Le nœud se recalcule depuis les nœuds appris : une sauvegarde n'a rien de plus à garder.
	var uids: Array = game.allocated_uids()
	game.reset()
	game.restore_allocation(uids)
	check(game.attack()["form"] == "fouet", "rechargé depuis les nœuds appris, l'attaque revient")
	game.reset()
