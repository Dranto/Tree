## Test de la branche Aube : forme « rayon » (rayon d'aube, réfraction, incandescence, éblouissement),
## état « ebloui » des ennemis, compétences (aurore, prisme, lance d'aube), action « ray »,
## grappes et builds de la branche.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/aube_test.gd
extends SceneTree

const AttackScript = preload("res://scripts/attack.gd")
const Planner = preload("res://scripts/tree_planner.gd")
const Content = preload("res://scripts/content.gd")
const DT := 1.0 / 60.0
const GRAFTS := ["greffe_eclat_verre", "greffe_prisme", "greffe_rosee", "greffe_lueur", "greffe_aile_de_verre", "greffe_lumiere_premiere"]
const ELITE_GRAFTS := ["greffe_halo", "greffe_soleil_bas", "greffe_vitrail", "greffe_aube_lente"]

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


## Effets appris pour le test ; « crit » : chance de critique (−1 : jamais, même ébloui ou au rayon).
func _with(effects: Array, crit := -1.0) -> void:
	game.effects.rebuild([{"id": "test", "ring": 1, "effects": effects}])
	game.stats = game.effects.stats
	game.stats["crit"] = crit


func _lost(e) -> float:
	return e.max_hp - e.hp


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
	_test_rayon()
	_test_eblouir()
	await _test_aurore()
	await _test_prisme()
	await _test_lance()
	_test_actions()
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
	for id in ["aurore", "prisme", "lance_aube"]:
		check(skills.has(id) and skills[id]["branch"] == "aube", "compétence « %s » de la branche Aube" % id)
		check(ResourceLoader.exists("res://scripts/skills/%s.gd" % id), "compétence « %s » a son fichier" % id)
		check(Art.ELEMENT_DE_COMPETENCE.get(id) == "lumiere", "compétence « %s » : élément lumière" % id)
		check(Art.icon_ids().has(id), "compétence « %s » a son icône" % id)
	check(AttackScript.forms().get("rayon", {}).get("branch") == "aube", "forme « rayon » de la branche Aube")
	check(AttackScript.forms().get("rayon", {}).get("kind") == "beam", "le rayon est une forme « beam »")
	check(Art.icon_ids().has("attaque_rayon"), "forme « rayon » a son icône")
	for m in ["eblouit", "refraction", "incandescence"]:
		check(AttackScript.mods().has(m), "modificateur « %s »" % m)
	check(Art.ELEMENTS.has("lumiere"), "élément « lumiere » dans la charte")
	check(Content.conditions().has("cible_eblouie"), "condition « cible_eblouie »")
	var grafts: Dictionary = Content._load("grafts")
	for g in GRAFTS:
		check(grafts.has(g), "greffe « %s » (citée par la région d'Aube)" % g)
	var n := 0
	for g in GRAFTS + ELITE_GRAFTS:
		if grafts.has(g):
			n += 1
	check(n == 10, "10 greffes d'Aube (%d)" % n)
	for g in ELITE_GRAFTS:
		check(grafts.get(g, {}).get("sources", []) == ["elite"], "greffe « %s » tombe des élites" % g)


func _test_rayon() -> void:
	print("Rayon d'aube")
	_clear()
	p.position = Vector2.ZERO
	_with([{"attack_form": "rayon"}])
	check(game.attack()["form"] == "rayon", "la forme « rayon » s'active")
	var near = _spawn(Vector2(120, 0))
	var far = _spawn(Vector2(420, 6))
	var off = _spawn(Vector2(200, 120))
	var out = _spawn(Vector2(700, 0))
	var behind = _spawn(Vector2(-150, 0))
	game.stats["projectiles"] = 1
	AttackScript.fire(p, near)
	var dmg: float = AttackScript.hit_damage(p, game.attack()) * main.branch_factor(near, "aube")
	check(absf(_lost(near) - dmg) < 0.01 and absf(_lost(far) - dmg) < 0.01, "il traverse tout ce qui est sur sa ligne, d'un coup (%.2f, %.2f)" % [_lost(near), _lost(far)])
	check(_lost(off) == 0.0 and _lost(behind) == 0.0, "rien à côté ni derrière")
	check(_lost(out) == 0.0, "rien au-delà de la portée (%d px)" % int(AttackScript.reach(game.attack())))
	check(main.projectiles_layer.get_children().filter(func(c): return not c.is_queued_for_deletion()).is_empty(), "aucun projectile : le rayon est instantané")
	# Réfraction : le rayon se brise au premier ennemi en deux rayons obliques.
	_clear()
	_with([{"attack_form": "rayon"}, {"attack_mod": "refraction", "value": 2}])
	game.stats["projectiles"] = 1
	var first = _spawn(Vector2(150, 0))
	var ang := 0.55
	var up = _spawn(Vector2(150, 0) + Vector2.from_angle(-ang) * 150.0)
	var down = _spawn(Vector2(150, 0) + Vector2.from_angle(ang) * 150.0)
	AttackScript.fire(p, first)
	var one: float = AttackScript.hit_damage(p, game.attack())
	check(_lost(first) > 0.0 and _lost(up) > 0.0 and _lost(down) > 0.0, "réfraction : deux rayons obliques partent du premier ennemi")
	check(absf(_lost(up) - one * 0.6) < 0.01, "les rayons brisés font 60 % des dégâts")
	check(absf(_lost(first) - one) < 0.01, "le premier ennemi n'est touché qu'une fois")
	# Incandescence : critique sûr (crit 1), dégâts × multiplicateur × (1 + 0,4).
	_clear()
	_with([{"attack_form": "rayon"}, {"attack_mod": "incandescence", "value": 0.4}], 1.0)
	game.stats["projectiles"] = 1
	var e = _spawn(Vector2(150, 0))
	AttackScript.fire(p, e)
	var crit_dmg: float = AttackScript.hit_damage(p, game.attack()) * game.stats["crit_mult"] * 1.4
	check(absf(_lost(e) - crit_dmg) < 0.01, "incandescence : critique +40 %% (%.2f, attendu %.2f)" % [_lost(e), crit_dmg])
	check(main.hit_crit_bonus == 0.0 and main.hit_crit_extra == 0.0, "les réglages du coup sont remis à zéro")
	_clear()


func _test_eblouir() -> void:
	print("Éblouissement")
	_clear()
	_with([{"attack_mod": "eblouit", "value": 1.0}])
	var e = _spawn(Vector2(100, 0))
	AttackScript.apply_on_hit(main, {"form": "graine", "eblouit": 1.0}, e, 1.0, e.position)
	check(e.dazzle_time > 2.0 and absf(main.dazzle_of(e) - 0.2) < 0.001, "eblouit : l'ennemi touché est ébloui (+20 % de critique contre lui)")
	check(main.enemy_ctx(e, 1.0)["cible_eblouie"] == 1.0, "condition « cible_eblouie »")
	# Ébloui à 100 % : même sans chance de critique, chaque coup est critique.
	_with([], 0.0)
	e.apply_status("ebloui", 1.0, 3.0)
	var hp0: float = e.hp
	main.player_hit_enemy(e, 10.0, false, "")
	check(absf((hp0 - e.hp) - 10.0 * game.stats["crit_mult"]) < 0.01, "un ennemi ébloui à 100 % est toujours frappé en critique")
	e.dazzle_time = 0.0
	hp0 = e.hp
	main.player_hit_enemy(e, 10.0, false, "")
	check(absf((hp0 - e.hp) - 10.0) < 0.01, "l'éblouissement passé, plus de bonus")
	check(main.dazzle_of(e) == 0.0, "dazzle_of vaut 0 hors éblouissement")
	_clear()


func _test_aurore() -> void:
	print("Aurore")
	_clear()
	_with([{"skill": "aurore"}])
	var a = _spawn(Vector2(120, 0))
	var b = _spawn(Vector2(-60, 150))
	var far = _spawn(Vector2(500, 0))
	p.position = Vector2.ZERO
	p.cast("aurore", game.stats)
	check(_lost(a) > 0.0 and _lost(b) > 0.0, "l'onde blesse tout autour du joueur")
	check(a.dazzle_time > 2.0 and b.dazzle_time > 2.0, "et éblouit")
	check(_lost(far) == 0.0 and far.dazzle_time <= 0.0, "rien hors du rayon")
	# Double aurore : une seconde onde, plus faible, un peu après.
	_with([{"skill": "aurore"}, {"skill_mod": "aurore", "param": "waves", "op": "set", "value": 2, "text": "x"}])
	var hp0: float = a.hp
	p.cast("aurore", game.stats)
	var first: float = hp0 - a.hp
	await _ticks(40)
	var second: float = hp0 - a.hp - first
	check(second > 0.0 and absf(second - first * 0.6) < 0.01, "Double aurore : seconde onde à 60 %% (%.2f / %.2f)" % [second, first])
	_clear()


func _test_prisme() -> void:
	print("Prisme")
	_clear()
	_with([{"skill": "prisme"}])
	p.position = Vector2.ZERO
	p.aim_point = Vector2(1000, 0)
	var e = _spawn(Vector2(520, 100))
	var far = _spawn(Vector2(-600, 0))
	p.cast("prisme", game.stats)
	var pr = p.skill_object("prisme")
	var k: Dictionary = p.skill("prisme")
	check(pr.live.size() == 1 and absf(pr.live[0]["pos"].x - float(k["range"])) < 0.5, "le cristal se pose au plus à %d px" % int(k["range"]))
	await _ticks(20)
	check(_lost(e) > 0.0, "il tire sur l'ennemi proche")
	check(_lost(far) == 0.0, "pas sur un ennemi hors de portée")
	p.cast("prisme", game.stats)
	p.cast("prisme", game.stats)
	check(pr.live.size() == int(k["max"]), "au plus %d prismes à la fois" % int(k["max"]))
	await _ticks(int(float(k["life"]) * 60.0) + 10)
	check(pr.live.is_empty(), "les prismes s'éteignent au bout de leur durée")
	p.aim_point = Vector2(300, 0)
	_clear()


func _test_lance() -> void:
	print("Lance d'aube")
	_clear()
	_with([{"skill": "lance_aube"}], 0.0)
	p.position = Vector2.ZERO
	p.aim_point = Vector2(300, 0)
	var a = _spawn(Vector2(200, 0))
	var b = _spawn(Vector2(800, 10))
	var side = _spawn(Vector2(300, 200))
	b.apply_status("ebloui", 0.01, 10.0)
	p.cast("lance_aube", game.stats)
	await _ticks(5)
	check(_lost(a) == 0.0, "rien pendant que la lumière se concentre")
	await _ticks(20)
	var dmg: float = p.skill_damage("lance_aube")
	check(absf(_lost(a) - dmg) < 0.01, "la lance frappe sur toute sa longueur (sans critique : %.1f)" % _lost(a))
	check(absf(_lost(b) - dmg * game.stats["crit_mult"]) < 0.01, "un ennemi ébloui est toujours frappé en critique")
	check(_lost(side) == 0.0, "rien à côté")
	_clear()


func _test_actions() -> void:
	print("Action « ray »")
	_clear()
	_with([])
	var src = _spawn(Vector2(100, 0))
	var nb = _spawn(Vector2(260, 40))
	var EffectActions = load("res://scripts/effect_actions.gd")
	var ok: bool = EffectActions.run("ray", {"factor": 0.8, "reach": 320}, {"main": main, "stats": game.stats, "enemy": src})
	check(ok and _lost(nb) > 0.0, "un rayon part de l'ennemi vers son voisin")
	check(_lost(src) == 0.0, "pas sur l'ennemi d'origine")
	_clear()


func _test_tree() -> void:
	print("Arbre")
	var t = game.tree
	var owned := {0: true}
	# Œil d'or : 11 depuis les grappes de Racine (jalon 9 D) ; le chemin à 9 passait par le tronc générique de
	# Racine (racine:5:1), que couvre maintenant la grappe du bouclier d'écorce.
	var want := {"c:aube:eclats:a1": 4, "c:aube:rayon:l1": 4, "c:aube:levant:r6": 6, "c:aube:prisme:t1": 7, "c:aube:oeil:v1": 11, "c:aube:lance:p1": 12}
	for uid in want:
		check(t.by_uid.has(uid), "nœud %s présent" % uid)
		if t.by_uid.has(uid):
			var d: int = Planner.shortest_path(t, owned, t.by_uid[uid]).size()
			check(d <= want[uid], "%s à %d points de la graine (au plus %d)" % [uid, d, want[uid]])
	var builds: Dictionary = Content._load("builds")
	var aube := 0
	for b in builds:
		if not b.begins_with("_") and builds[b].get("branch") == "aube":
			aube += 1
			for uid in builds[b]["targets"]:
				check(t.by_uid.has(uid), "build %s : cible %s présente" % [b, uid])
	check(aube >= 3, "trois builds d'Aube (%d)" % aube)
