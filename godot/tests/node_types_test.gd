## Test des grappes écrites à la main et des nouveaux types de nœuds : grappe insérée dans l'arbre,
## compétence, maîtrise choisie puis changée, mutation verrouillée puis disponible, nœud flétri libéré
## par son drapeau, greffe, exclusion, bonus de grappe complète, résonance de branche, sauvegarde
## aller-retour et migration d'une sauvegarde de la version 1.
## Le test pose sa propre grappe dans la première branche : il ne dépend pas du contenu de data/.
## Lancer : tools/godot.sh --headless -s res://tests/node_types_test.gd
extends SceneTree

const SkillTree = preload("res://scripts/skill_tree.gd")
const Content = preload("res://scripts/content.gd")
const TreePlanner = preload("res://scripts/tree_planner.gd")
const PATH := "user://tests/types_test.json"

var failures := 0
var game
var tree
var bid := ""


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _cluster() -> Dictionary:
	return {
		"id": "t", "name": "Grappe de test", "ring": 5, "angle": 0.2, "entry": ["a"],
		"nodes": [
			{"id": "a", "type": "skill", "skill": "nova", "at": [0, 0]},
			{"id": "b", "type": "mastery", "name": "Maîtrise de test", "at": [0.7, -0.4], "links": ["a"], "choices": [
				{"id": "un", "name": "Un", "effects": [{"stat": "max_hp", "op": "add", "value": 10}]},
				{"id": "deux", "name": "Deux", "effects": [{"stat": "max_hp", "op": "add", "value": 20}]},
				{"id": "trois", "name": "Trois", "effects": [{"stat": "max_hp", "op": "add", "value": 30}]},
			]},
			{"id": "c", "type": "mutation", "mutates": "nova", "at": [0.7, 0.4], "links": ["a"], "choices": [
				{"name": "Large", "effects": [{"skill_mod": "nova", "param": "radius", "op": "more", "value": 2, "text": "Rayon doublé."}]},
				{"name": "Vive", "effects": [{"skill_mod": "nova", "param": "cooldown", "op": "more", "value": 0.5, "text": "Recharge divisée par deux."}]},
			]},
			{"id": "d", "type": "withered", "name": "Flétri de test", "requires_flag": "drapeau_test", "at": [1.4, -0.4], "links": ["b"],
				"effects": [{"stat": "max_hp", "op": "add", "value": 100}]},
			{"id": "e", "type": "graft", "at": [1.4, 0.4], "links": ["c"]},
			{"id": "k1", "type": "keystone", "key": "test_k1", "name": "Clé un", "at": [2.1, -0.4], "links": ["d"], "excludes": ["k2"],
				"effects": [{"stat": "max_hp", "op": "add", "value": 1}]},
			{"id": "k2", "type": "keystone", "key": "test_k2", "name": "Clé deux", "at": [2.1, 0.4], "links": ["e", "k1"],
				"effects": [{"stat": "max_hp", "op": "add", "value": 2}]},
		],
		"complete": {"effects": [{"stat": "max_hp", "op": "add", "value": 1000}]},
	}


func _id(local: String) -> int:
	var uid := "c:%s:t:%s" % [bid, local]
	if local.begins_with("k"):
		uid = "key:test_" + local
	return tree.id_for_uid(uid)


func _run() -> void:
	game = root.get_node("Game")
	var save = root.get_node("SaveGame")
	tree = game.tree
	var plain = SkillTree.new()
	var b: Dictionary = SkillTree.BRANCHES[0]
	bid = b["id"]
	var real_clusters = b.get("clusters", [])
	var real_resonance = b.get("resonance", [])

	# Arbre sans grappe, pour comparer.
	b["clusters"] = []
	plain.build()
	b["clusters"] = [_cluster()]
	b["resonance"] = [{"count": 3, "effects": [{"stat": "pickup", "op": "add", "value": 7}]}, {"count": 6, "effects": [{"stat": "pickup", "op": "add", "value": 70}]}]
	check(Content.validate().size() >= 0, "les données de test se lisent")
	var errors := PackedStringArray()
	Content._check_clusters(b["clusters"], "test", {}, errors)
	Content._check_resonance(b["resonance"], "test", errors)
	check(errors.is_empty(), "la grappe de test est valide (%s)" % ", ".join(errors))
	tree.build()
	game.reset()

	print("Grappe insérée")
	var a := _id("a")
	check(a > 0 and _id("b") > 0 and _id("c") > 0 and _id("d") > 0 and _id("e") > 0 and _id("k1") > 0 and _id("k2") > 0, "les 7 nœuds de la grappe sont dans l'arbre, par identifiant stable")
	check(tree.nodes[a]["type"] == "skill" and tree.nodes[_id("b")]["type"] == "mastery" and tree.nodes[_id("c")]["type"] == "mutation"
		and tree.nodes[_id("d")]["type"] == "withered" and tree.nodes[_id("e")]["type"] == "graft", "chaque nœud garde son type")
	var anchor: Vector2 = SkillTree.cluster_layout(0, b["clusters"][0])["a"]
	check(tree.nodes[a]["pos"].is_equal_approx(anchor) and absf(anchor.length() - 5 * SkillTree.RING_GAP) < 0.01, "le nœud d'entrée est à l'anneau et à l'angle demandés")
	check(tree.nodes.size() < plain.nodes.size() + 7, "des petits nœuds générés ont été écartés (%d)" % (plain.nodes.size() + 7 - tree.nodes.size()))
	var too_close := 0
	var keystones_before := 0
	var keystones_after := 0
	for n in tree.nodes:
		if n["cluster"] == "":
			if n["type"] == "keystone":
				keystones_after += 1
			for id in tree.clusters[bid + ":t"]["nodes"]:
				if n["pos"].distance_to(tree.nodes[id]["pos"]) < SkillTree.CLEAR_NODE * SkillTree.RING_GAP:
					too_close += 1
	for n in plain.nodes:
		if n["type"] == "keystone":
			keystones_before += 1
	check(too_close == 0, "aucun nœud généré ne reste sous la grappe")
	check(keystones_after == keystones_before, "aucun nœud clé généré n'a été écarté")
	var seen := {0: true}
	var stack: Array = [0]
	while stack.size() > 0:
		for m in tree.nodes[stack.pop_back()]["neighbors"]:
			if not seen.has(m):
				seen[m] = true
				stack.append(m)
	check(seen.size() == tree.nodes.size(), "tout l'arbre reste relié à la graine")
	var outside := false
	for m in tree.nodes[a]["neighbors"]:
		if tree.nodes[m]["cluster"] == "":
			outside = true
	check(outside, "l'entrée de la grappe est reliée à un nœud généré")
	var same := true
	for n in plain.nodes:
		var id: int = tree.id_for_uid(n["uid"])
		if id >= 0 and not tree.nodes[id]["pos"].is_equal_approx(n["pos"]):
			same = false
	check(same, "les nœuds générés gardés n'ont pas bougé")
	var ids_ok := true
	for i in tree.nodes.size():
		if tree.nodes[i]["id"] != i:
			ids_ok = false
	for e in tree.edges:
		if not (e.y in tree.nodes[e.x]["neighbors"] and e.x in tree.nodes[e.y]["neighbors"]):
			ids_ok = false
	check(ids_ok, "index et liens cohérents après la renumérotation")

	print("Compétence et mutation")
	var planner = TreePlanner.new(game)
	var c := _id("c")
	check(game.lock_reason(c) != "", "la mutation est verrouillée tant que la compétence n'est pas acquise (%s)" % game.lock_reason(c))
	game.points = 100
	var path: Array = planner.path_to(a)
	check(planner.learn_path(path) and game.allocated.has(a), "apprendre le chemin jusqu'au nœud de compétence")
	check(game.has_key("nova"), "le nœud de compétence donne la compétence")
	check(game.lock_reason(c) == "" and game.can_allocate(c), "la mutation devient disponible")
	var radius: float = game.skill("nova")["radius"]
	check(game.allocate(c) and game.needs_choice(c), "la mutation apprise attend son choix")
	check(is_equal_approx(game.skill("nova")["radius"], radius), "sans choix, la compétence ne change pas")
	check(game.set_choice(c, 0) and is_equal_approx(game.skill("nova")["radius"], radius * 2.0), "le choix transforme la compétence (rayon ×2)")
	check(not game.set_choice(c, 1) and game.choice_index(c) == 0, "une mutation choisie ne se change pas")
	check(game.refund(c) and game.choice_index(c) < 0 and is_equal_approx(game.skill("nova")["radius"], radius), "oublier la mutation annule son choix")
	game.allocate(c)
	check(game.set_choice(c, 1) and is_equal_approx(game.skill("nova")["cooldown"], Content.skills()["nova"]["cooldown"] * 0.5), "après l'avoir oubliée, on peut choisir l'autre mutation")

	print("Maîtrise")
	var m := _id("b")
	var hp: float = game.stats["max_hp"]
	check(game.allocate(m) and is_equal_approx(game.stats["max_hp"], hp), "une maîtrise sans choix ne donne rien")
	check(game.set_choice(m, 1) and is_equal_approx(game.stats["max_hp"], hp + 20.0), "maîtrise choisie (+20)")
	var pts: int = game.points
	check(game.set_choice(m, 2) and is_equal_approx(game.stats["max_hp"], hp + 30.0) and game.points == pts, "maîtrise changée gratuitement (+30)")
	check(not game.set_choice(m, 3) and not game.set_choice(_id("d"), 0), "choix hors liste ou sur un nœud non appris refusé")
	var sim: Dictionary = planner.simulate()
	check(is_equal_approx(sim["stats"]["max_hp"], game.stats["max_hp"]), "la simulation des outils tient compte du choix")

	print("Nœud flétri")
	var w := _id("d")
	check(game.lock_reason(w) != "" and not game.can_allocate(w), "verrouillé tant que le drapeau n'est pas levé")
	check(planner.path_to(_id("k1")).has(w) == false, "les chemins contournent un nœud flétri")
	game.flags["drapeau_test"] = true
	check(game.lock_reason(w) == "" and game.allocate(w), "déverrouillé par le drapeau, puis appris")
	check(is_equal_approx(game.stats["max_hp"], hp + 130.0), "le nœud flétri donne son effet (+100)")

	print("Greffe")
	var g := _id("e")
	check(not game.set_graft(m, "greffe_soeurs") and not game.set_graft(g, "inconnue"), "greffe refusée ailleurs que dans un emplacement, ou si elle n'existe pas")
	var shots: int = game.stats["projectiles"]
	check(game.set_graft(g, "greffe_soeurs") and game.stats["projectiles"] == shots, "une greffe posée dans un emplacement non appris n'agit pas")
	game.allocate(g)
	check(game.stats["projectiles"] == shots + 2, "la greffe agit une fois l'emplacement appris (+2 projectiles)")
	check(game.set_graft(g, "") and game.stats["projectiles"] == shots, "greffe retirée")
	game.set_graft(g, "greffe_soeurs")

	print("Exclusion, grappe complète, résonance")
	var k1 := _id("k1")
	var k2 := _id("k2")
	check(game.allocate(k1) and game.lock_reason(k2) != "" and not game.can_allocate(k2), "un nœud clé appris verrouille celui qu'il exclut (%s)" % game.lock_reason(k2))
	check(not planner.can_learn_path([k2]), "les outils refusent aussi le nœud exclu")
	var before_complete: float = game.stats["max_hp"]
	var prog: Array = game.cluster_progress(bid + ":t")
	check(prog[0] == 6 and prog[1] == 7, "avancement de la grappe : 6 / 7")
	game.refund(k1)
	check(game.lock_reason(k1) == "" and game.allocate(k2) and game.lock_reason(k1) != "", "l'exclusion marche dans les deux sens")
	check(is_equal_approx(game.stats["max_hp"], before_complete + 1.0), "pas de bonus tant que la grappe est incomplète")
	# La grappe de test ne peut pas être complète (k1 et k2 s'excluent) : on vérifie le bonus par la simulation.
	var all := {}
	for id in tree.clusters[bid + ":t"]["nodes"]:
		all[id] = true
	var has_bonus := false
	for src in game.effect_sources(all):
		if str(src["id"]) == "grappe:%s:t" % bid:
			has_bonus = true
	check(has_bonus, "tous les nœuds d'une grappe appris : le bonus de grappe complète s'ajoute")
	var count: int = game.branch_count(0)
	check(count >= 6 and is_equal_approx(game.stats["pickup"], Content.stats()["pickup"]["base"] + 77.0), "résonance : %d nœuds dans la branche, paliers 3 et 6 atteints" % count)
	var few := {0: true}
	few[path[0]] = true
	var tiers := 0
	for src in game.effect_sources(few):
		if str(src["id"]).begins_with("resonance:"):
			tiers += 1
	check(tiers == 0, "résonance : aucun palier avec un seul nœud")

	print("Sauvegarde")
	save.delete_save(PATH)
	var want_stats: Dictionary = game.stats.duplicate()
	var want_uids: Array = game.allocated_uids()
	var data: Dictionary = save.capture(null)
	check(data["version"] == 3 and data["tree"]["choices"].size() == 2 and data["tree"]["grafts"].size() == 1, "format 3 : choix et greffes enregistrés")
	_write(data)
	game.reset()
	check(game.choices.is_empty() and game.grafts.is_empty(), "une nouvelle partie n'a ni choix ni greffe")
	check(save.load_into(null, PATH), "chargement")
	check(game.allocated_uids() == want_uids and game.choice_index(m) == 2 and game.choice_index(c) == 1 and game.graft_of(g) == "greffe_soeurs", "nœuds, choix et greffe retrouvés")
	var same_stats := true
	for k in want_stats:
		if not is_equal_approx(float(want_stats[k]), float(game.stats[k])):
			same_stats = false
	check(same_stats and is_equal_approx(game.skill("nova")["cooldown"], Content.skills()["nova"]["cooldown"] * 0.5), "statistiques et mutation recalculées")
	data["tree"]["choices"]["c:%s:t:b" % bid] = "disparu"
	data["tree"]["choices"]["c:%s:t:zz" % bid] = "un"
	data["tree"]["grafts"]["c:%s:t:e" % bid] = "greffe_disparue"
	_write(data)
	check(save.load_into(null, PATH) and game.choice_index(m) < 0 and game.needs_choice(m) and game.graft_of(g) == "", "un choix ou une greffe qui n'existe plus est ignoré, le nœud reste appris")

	print("Migration de la version 1")
	var old_uid: String = ""
	for n in plain.nodes:
		if tree.id_for_uid(n["uid"]) < 0:
			old_uid = n["uid"]
			break
	var v1 := {"format": "seve-save", "version": 1, "game": {"level": 4, "points": 2, "flags": {}},
		"tree": {"allocated": [tree.nodes[path[0]]["uid"], old_uid]}}
	_write(v1)
	check(save.load_into(null, PATH), "une sauvegarde de la version 1 se charge")
	check(game.level == 4 and game.allocated.has(path[0]) and game.choices.is_empty() and game.grafts.is_empty(), "niveau et nœuds repris, sans choix ni greffe")
	check(game.points == 3, "le point d'un nœud remplacé par la grappe est rendu")
	check(save._migrate({"format": "seve-save", "version": 1})["tree"].has("choices"), "la migration crée les champs manquants")

	# Remet les données d'origine pour ne rien laisser derrière soi.
	b["clusters"] = real_clusters
	b["resonance"] = real_resonance
	save.delete_save(PATH)
	for f in DirAccess.get_files_at("user://tests"):
		if f.begins_with("types_test"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tests/" + f))
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)


func _write(d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
