## Test de la branche Racine : compétences (bouclier d'écorce, ancrage, pieux), état « enracine »,
## forme de l'attaque (massue de bois), modificateurs (secousse, aubier), « no_root », greffes,
## grappes et builds de la branche.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/racine_test.gd
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
	await _test_ecorce()
	await _test_ancrage()
	await _test_pieux()
	await _test_massue()
	await _test_mods()
	_test_tree()
	_test_save()

	game.test_skills = {}
	game.reset()
	main.queue_free()
	await process_frame
	print("RÉSULTAT : ", "tout est bon" if failures == 0 else "%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


const RACINE_GRAFTS := ["greffe_cerne", "greffe_gland", "greffe_ambre", "greffe_silex", "greffe_racine_profonde", "greffe_coeur_de_chene",
	"greffe_pieu_double", "greffe_ecorce_dure"]


func _test_data() -> void:
	print("Données")
	var skills := Content.skills()
	for id in ["ecorce", "ancrage", "pieux"]:
		check(skills.has(id) and skills[id]["branch"] == "racine", "compétence « %s » de la branche Racine" % id)
		check(ResourceLoader.exists("res://scripts/skills/%s.gd" % id), "compétence « %s » a son fichier" % id)
		check(Art.ELEMENT_DE_COMPETENCE.get(id) == "racine", "compétence « %s » : élément racine" % id)
		check(Art.icon_ids().has(id), "compétence « %s » a son icône" % id)
	check(AttackScript.forms().get("massue", {}).get("branch") == "racine", "forme « massue » de la branche Racine")
	check(Art.icon_ids().has("attaque_massue"), "forme « massue » a son icône")
	for m in ["secousse", "aubier"]:
		check(AttackScript.mods().has(m), "modificateur « %s »" % m)
	check(Content._load("conditions").has("enracine"), "condition « enracine »")
	var grafts: Dictionary = Content._load("grafts")
	for g in RACINE_GRAFTS:
		check(grafts.has(g), "greffe « %s »" % g)
	# Greffes citées par la région Racine (thread « Créer la région Racine ») : une de chaque source.
	for pair in [["greffe_cerne", "autel"], ["greffe_gland", "autel"], ["greffe_ambre", "autel"], ["greffe_silex", "autel"],
			["greffe_racine_profonde", "secret"], ["greffe_coeur_de_chene", "boss"]]:
		check(grafts.get(pair[0], {}).get("sources", []).has(pair[1]), "greffe « %s » : source %s" % pair)


func _test_ecorce() -> void:
	print("Bouclier d'écorce")
	_clear()
	_with([{"skill": "ecorce"}])
	p.position = Vector2.ZERO
	p.invuln = 0.0
	p.hp = game.stats["max_hp"]
	p.cast("ecorce", game.stats)
	var obj = p.skill_object("ecorce")
	var full: float = game.stats["max_hp"] * float(p.skill("ecorce")["shield"])
	check(absf(obj.shield - full) < 0.01, "bouclier de %.0f" % full)
	game.set_state("sous_ecorce", 1.0)
	var foe = _spawn(Vector2(30, 0))
	p.take_hit(10.0, foe)
	check(p.hp == game.stats["max_hp"] and absf(obj.shield - (full - 10.0)) < 0.01, "l'écorce boit le coup")
	var want: float = p.skill_damage("ecorce") * float(p.skill("ecorce")["riposte"]) * main.branch_factor(foe, "racine")
	check(absf((foe.max_hp - foe.hp) - want) < 0.5, "elle renvoie des échardes à l'agresseur (%.1f, attendu %.1f)" % [foe.max_hp - foe.hp, want])
	p.invuln = 0.0
	p.take_hit(full * 2.0, null)
	check(obj.shield == 0.0 and p.hp < game.stats["max_hp"], "percée, le reste du coup passe")
	# Fin du bouclier : l'écorce éclate et blesse autour.
	p.invuln = 1e9
	_clear()
	var e = _spawn(Vector2(80, 0))
	p.cast("ecorce", game.stats)
	await _ticks(int(float(p.skill("ecorce")["duration"]) * 60.0) + 5)
	check(obj.shield == 0.0, "l'écorce tombe à la fin")
	check(e.hp < e.max_hp, "l'éclatement blesse autour")
	# Mutation « regrow » : le bouclier repousse.
	_with([{"skill": "ecorce"}, {"skill_mod": "ecorce", "param": "regrow", "op": "set", "value": 0.04, "text": "x"}])
	p.invuln = 0.0
	p.cast("ecorce", game.stats)
	p.take_hit(20.0, null)
	var low: float = obj.shield
	await _ticks(60)
	check(obj.shield > low, "Cernes : le bouclier repousse (%.1f → %.1f)" % [low, obj.shield])
	p.invuln = 1e9
	await _ticks(400)
	p.hp = game.stats["max_hp"]


func _test_ancrage() -> void:
	print("Ancrage")
	_clear()
	_with([{"skill": "ancrage"}, {"stat": "armor", "op": "add", "value": 0.15, "if": {"state": "enracine"}}])
	p.position = Vector2.ZERO
	var near = _spawn(Vector2(100, 0))
	var far = _spawn(Vector2(600, 0))
	var armor0: float = game.stats["armor"]
	p.cast("ancrage", game.stats)
	check(p.rooted > 0.0, "le joueur prend racine")
	game.set_state("enracine", 1.0 if p.rooted > 0.0 else 0.0)
	check(game.stats["armor"] > armor0 + 0.1, "enraciné, l'armure monte (%.2f → %.2f)" % [armor0, game.stats["armor"]])
	await _ticks(40)
	check(near.hp < near.max_hp and near.root_time > 0.0, "les racines blessent et immobilisent autour")
	check(far.hp == far.max_hp, "pas au loin")
	# « no_root » : blessé sans être retenu.
	var big = _spawn(Vector2(-100, 0))
	big.data = big.data.duplicate()
	big.data["no_root"] = true
	await _ticks(40)
	check(big.hp < big.max_hp and big.root_time <= 0.0, "un ennemi « no_root » n'est pas retenu")
	# Fin : l'esquive arrache les racines.
	p.uproot()
	check(p.rooted <= 0.0 and not p.skill_object("ancrage").active, "l'esquive arrache les racines")
	game.set_state("enracine", 0.0)
	check(absf(game.stats["armor"] - armor0) < 0.001, "déraciné, l'armure redescend")
	# Mutation « uproot » : à la fin, les racines s'arrachent.
	_clear()
	_with([{"skill": "ancrage"}, {"skill_mod": "ancrage", "param": "uproot", "op": "set", "value": 3.0, "text": "x"}])
	var u = _spawn(Vector2(80, 0))
	p.cast("ancrage", game.stats)
	var before: float = u.hp
	p.rooted = 0.0
	await _ticks(2)
	var burst: float = 3.0 * p.skill_damage("ancrage") * main.branch_factor(u, "racine")
	check(before - u.hp >= burst * 0.95, "Arrachement : ×3 dégâts à la fin (%.1f, attendu %.1f)" % [before - u.hp, burst])
	# Mutation « heal » : chaque ennemi tenu soigne.
	_clear()
	_with([{"skill": "ancrage"}, {"skill_mod": "ancrage", "param": "heal", "op": "set", "value": 0.01, "text": "x"}])
	_spawn(Vector2(80, 0))
	_spawn(Vector2(-80, 0))
	p.hp = 10.0
	p.cast("ancrage", game.stats)
	await _ticks(2)
	check(absf(p.hp - (10.0 + game.stats["max_hp"] * 0.02)) < 0.5, "Racines nourricières : 1 %% par ennemi tenu (%.1f)" % p.hp)
	p.uproot()
	p.hp = game.stats["max_hp"]


func _test_pieux() -> void:
	print("Pieux")
	_clear()
	_with([{"skill": "pieux"}])
	p.position = Vector2.ZERO
	p.aim_point = Vector2(400, 0)
	var k: Dictionary = p.skill("pieux")
	var line = _spawn(Vector2(250, 0))
	var side = _spawn(Vector2(250, 200))
	p.cast("pieux", game.stats)
	var obj = p.skill_object("pieux")
	check(obj.queue.size() == int(k["count"]), "%d pieux en file" % int(k["count"]))
	await _ticks(30)
	check(obj.queue.is_empty(), "tous les pieux ont jailli")
	check(line.hp < line.max_hp and line.root_time > 0.0, "un pieu blesse et cloue l'ennemi sur la ligne")
	check(side.hp == side.max_hp, "pas l'ennemi à côté")
	# Mutation « ring » : un cercle autour du joueur.
	_clear()
	_with([{"skill": "pieux"}, {"skill_mod": "pieux", "param": "ring", "op": "set", "value": true, "text": "x"}])
	var spots: Array = obj.spots(Vector2.ZERO, Vector2(400, 0), p.skill("pieux"), 6, 46.0)
	var ok := true
	for s in spots:
		ok = ok and absf(s.length() - spots[0].length()) < 0.1
	check(spots.size() == 6 and ok, "Cercle de pieux : les pieux entourent le joueur")
	# Mutation « stay » : les pieux restent et blessent.
	_clear()
	_with([{"skill": "pieux"}, {"skill_mod": "pieux", "param": "stay", "op": "set", "value": 3.0, "text": "x"}])
	p.cast("pieux", game.stats)
	await _ticks(30)
	check(obj.standing.size() == int(k["count"]), "Palissade : les pieux restent plantés")
	var late = _spawn(Vector2(p.aim_point.x * 0.5, 0))
	await _ticks(70)
	check(late.hp < late.max_hp, "Palissade : un ennemi qui frôle un pieu est blessé")
	await _ticks(200)
	check(obj.standing.is_empty(), "les pieux tombent au bout de leur durée")


func _test_massue() -> void:
	print("Massue de bois")
	_clear()
	p.position = Vector2.ZERO
	_with([{"attack_form": "massue"}])
	check(game.attack()["form"] == "massue", "la forme « massue » s'active")
	var front = _spawn(Vector2(100, 0))
	var back = _spawn(Vector2(-100, 0))
	AttackScript.fire(p, front)
	check(front.hp < front.max_hp, "la massue frappe devant")
	check(back.hp == back.max_hp, "pas derrière")
	# Secousse : le sol tremble autour du point d'impact, une fois par coup.
	_clear()
	_with([{"attack_form": "massue"}, {"attack_mod": "secousse", "value": 0.5}])
	var a = _spawn(Vector2(100, 0))
	var b = _spawn(Vector2(150, 40))
	var c = _spawn(Vector2(-200, 0))
	AttackScript.fire(p, a)
	check(b.hp < b.max_hp, "secousse : les ennemis autour de l'impact sont touchés")
	check(c.hp == c.max_hp, "secousse : pas au loin")
	_clear()
	p.hp = game.stats["max_hp"]


func _test_mods() -> void:
	print("Aubier")
	_clear()
	_with([{"attack_mod": "aubier", "value": 0.5}])
	var e = _spawn(Vector2(100, 0))
	p.bark = 0.0
	AttackScript.apply_on_hit(main, {"form": "massue", "aubier": 0.5}, e, 10.0, e.position)
	check(absf(p.bark - 5.0) < 0.01, "aubier : 50 %% des dégâts en écorce (%.1f)" % p.bark)
	for i in 50:
		AttackScript.apply_on_hit(main, {"form": "massue", "aubier": 0.5}, e, 10.0, e.position)
	var cap: float = game.stats["max_hp"] * float(AttackScript.mods()["aubier"]["cap"])
	check(absf(p.bark - cap) < 0.01, "aubier : plafonné à %.0f" % cap)
	p.invuln = 0.0
	p.hp = game.stats["max_hp"]
	p.take_hit(5.0, null)
	check(p.hp == game.stats["max_hp"] and absf(p.bark - (cap - 5.0 * (1.0 - game.stats["armor"]))) < 0.01, "l'écorce de l'aubier boit le coup")
	p.invuln = 1e9
	p.bark = 0.0
	_clear()


func _test_tree() -> void:
	print("Arbre")
	var t = game.tree
	var owned := {0: true}
	var want := {"c:racine:massue:m1": 4, "c:racine:ecorce:e1": 6, "c:racine:ancrage:a1": 7, "c:racine:aubier:c1": 9,
		"c:racine:pieux:p1": 10, "c:racine:epines:t1": 12, "c:racine:coeur:h1": 13, "key:enracine": 5, "key:coeur_pierre": 10}
	for uid in want:
		check(t.by_uid.has(uid), "nœud %s présent" % uid)
		if t.by_uid.has(uid):
			var d: int = Planner.shortest_path(t, owned, t.by_uid[uid]).size()
			check(d <= want[uid], "%s à %d points de la graine (au plus %d)" % [uid, d, want[uid]])
	for flag in ["racine_coeur_purifie", "racine_boss_vaincu"]:
		var found := false
		for n in t.nodes:
			if str(n.get("requires_flag", "")) == flag:
				found = true
		check(found, "un nœud flétri attend « %s »" % flag)
	var graft_slots := 0
	for c in t.clusters:
		if c.begins_with("racine:"):
			for id in t.clusters[c]["nodes"]:
				if t.nodes[id]["type"] == "graft":
					graft_slots += 1
	check(graft_slots >= 4, "au moins quatre emplacements de greffe dans les grappes de Racine (%d)" % graft_slots)
	var builds: Dictionary = Content._load("builds")
	var racine := 0
	for b in builds:
		if not b.begins_with("_") and builds[b].get("branch") == "racine":
			racine += 1
			for uid in builds[b]["targets"]:
				check(t.by_uid.has(uid), "build %s : cible %s présente" % [b, uid])
	check(racine >= 3, "au moins trois builds de Racine (%d)" % racine)


## Une sauvegarde v5 (avant les grappes de Racine) qui avait appris des nœuds génériques de Racine
## disparus (écartés par les grappes) se charge, et ses points sont rendus.
func _test_save() -> void:
	print("Sauvegarde")
	var save_game = root.get_node("SaveGame")
	# Chemin du jalon 9 : graine → racine:1:0 → racine:2:1 → racine:3:1, puis racine:3:3 et racine:5:1
	# (nœuds génériques de Racine qui n'existent plus).
	var data := {"format": "seve-save", "version": 5, "game": {"level": 6, "xp": 0, "points": 1, "kills": 0, "flags": {}},
		"tree": {"allocated": ["racine:1:0", "racine:2:1", "racine:3:1", "racine:3:3", "racine:5:1"], "choices": {}, "grafts": {}, "inventory": []}}
	save_game.apply(data, null)
	check(not game.tree.by_uid.has("racine:3:3") and not game.tree.by_uid.has("racine:5:1"), "les nœuds génériques écartés ont disparu")
	check(game.allocated.size() - 1 == 3, "les nœuds encore là restent appris (%d)" % (game.allocated.size() - 1))
	check(game.points == 3, "les points des nœuds disparus sont rendus (%d)" % game.points)
