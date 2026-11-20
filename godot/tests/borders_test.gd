## Test des frontières hybrides (jalon 9, tâche A) : chargement de data/borders/, contrôles du format
## (branches voisines seulement, une frontière par paire, côté et angle), placement à cheval sur la
## limite, accès depuis les deux branches, grappes de branche voisines laissées en place, résonance
## comptée dans les deux branches, conditions multiples (« la cible saigne et elle est empoisonnée »),
## états en_mouvement et sous_cocon, couleurs et couture du dessin, sauvegarde aller-retour, et
## chargement d'une sauvegarde du jalon 8 (tests/fixtures/sauvegarde_jalon8.json, faite sur develop
## avant les frontières) : les nœuds générés remplacés par une frontière rendent leur point.
## Lancer : tools/godot.sh --headless -s res://tests/borders_test.gd
extends SceneTree

const SkillTree = preload("res://scripts/skill_tree.gd")
const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")
const TreePlanner = preload("res://scripts/tree_planner.gd")
const PATH := "user://tests/borders_test.json"
const JALON8 := "res://tests/fixtures/sauvegarde_jalon8.json"

var failures := 0
var game
var tree


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	var save = root.get_node("SaveGame")
	tree = game.tree
	game.reset()
	var ids: Array = Content.tree().get("branches", [])

	print("Données")
	var borders: Array = SkillTree.BORDERS
	var names: Array = borders.map(func(b): return b["id"])
	check(names.has("ronce-spore") and names.has("spore-seve") and names.has("seve-vent") and names.has("vent-aube")
		and names.has("aube-racine") and names.has("racine-ronce"),
		"les six frontières sont chargées (%s)" % ", ".join(names))
	var sizes_ok := true
	for bd in borders:
		check((bd["a"] + 1) % ids.size() == bd["b"], "%s : la seconde branche suit la première autour de la graine" % bd["id"])
		var count := 0
		for c in bd["clusters"]:
			count += c["nodes"].size()
		if count < 20 or count > 30:
			sizes_ok = false
	check(sizes_ok, "chaque frontière compte environ 25 nœuds")
	check(Content.border_pair(["spore", "ronce"], ids) == [0, 1] and Content.border_pair(["racine", "ronce"], ids) == [5, 0],
		"l'ordre de « between » n'importe pas, et Racine touche Ronce (le cercle se referme)")
	check(Content.border_pair(["ronce", "seve"], ids).is_empty() and Content.border_pair(["ronce"], ids).is_empty(),
		"deux branches qui ne se touchent pas ne font pas une frontière")

	print("Contrôles du format")
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/borders/ronce-spore.json"))
	var errors := PackedStringArray()
	Content.check_border(good, "ronce-spore.json", ids, {}, {}, errors)
	check(errors.is_empty(), "la frontière Ronce–Spore est valide (%s)" % ", ".join(errors))
	var far: Dictionary = good.duplicate(true)
	far["between"] = ["ronce", "seve"]
	far["id"] = "ronce-seve"
	errors = PackedStringArray()
	Content.check_border(far, "ronce-seve.json", ids, {}, {}, errors)
	check(errors.size() == 1 and errors[0].contains("voisines"), "refusée entre deux secteurs qui ne se touchent pas")
	errors = PackedStringArray()
	var pairs := {}
	Content.check_border(good, "ronce-spore.json", ids, {}, pairs, errors)
	Content.check_border(good, "ronce-spore.json", ids, {}, pairs, errors)
	check(_has(errors, "déjà décrite"), "refusée si la même paire est décrite deux fois")
	var bad: Dictionary = good.duplicate(true)
	bad["id"] = "spore-ronce"
	bad["clusters"][0]["angle"] = 0.8
	bad["clusters"][0]["nodes"][0]["side"] = "seve"
	errors = PackedStringArray()
	Content.check_border(bad, "spore-ronce.json", ids, {}, {}, errors)
	check(_has(errors, "ronce-spore") and _has(errors, "« angle »") and _has(errors, "« side »"),
		"identifiant dans le mauvais ordre, angle trop loin de la limite et côté inconnu sont signalés")
	errors = PackedStringArray()
	Content._check_effects([{"stat": "damage", "op": "inc", "value": 0.1, "if": [{"state": "cible_saignante"}, {"state": "inconnu"}]}], "test", errors)
	check(errors.size() == 1, "une condition inconnue dans une liste « if » est signalée")

	print("Placement")
	var sector: float = TAU / ids.size()
	for bd in borders:
		var limit: float = (bd["a"] + 1) * sector - PI / 2.0
		var both := true
		var sides := {}
		var under := 0
		var reached := {}
		for c in bd["clusters"]:
			var key := "%s:%s" % [bd["id"], c["id"]]
			for id in tree.clusters[key]["nodes"]:
				var n: Dictionary = tree.nodes[id]
				both = both and SkillTree.in_branch(n, bd["a"]) and SkillTree.in_branch(n, bd["b"]) and (n["uid"].begins_with("c:%s:" % bd["id"]) or n["type"] == "keystone")
				# Le secteur où le nœud tombe est bien sa branche.
				var off := wrapf(n["pos"].angle() - limit, -PI, PI)
				sides[n["branch"]] = true
				if (off > 0.001 and n["branch"] != bd["b"]) or (off < -0.001 and n["branch"] != bd["a"]):
					both = false
				for m in n["neighbors"]:
					var o: Dictionary = tree.nodes[m]
					if o["cluster"] != key and o["border"] < 0:
						reached[o["branch"]] = true
				for o in tree.nodes:
					if o["cluster"] == "" and o["id"] != 0 and o["pos"].distance_to(n["pos"]) < SkillTree.CLEAR_NODE * SkillTree.RING_GAP:
						under += 1
		check(both, "%s : chaque nœud appartient aux deux branches, à la branche du secteur où il tombe" % bd["id"])
		check(sides.has(bd["a"]) and sides.has(bd["b"]), "%s : des nœuds des deux côtés de la limite" % bd["id"])
		check(reached.has(bd["a"]) and reached.has(bd["b"]), "%s : relié aux nœuds des deux branches" % bd["id"])
		check(under == 0, "%s : aucun nœud généré ne reste sous la frontière" % bd["id"])
	var planner = TreePlanner.new(game)
	var all_paths := true
	for bd in borders:
		for c in bd["clusters"]:
			for id in tree.clusters["%s:%s" % [bd["id"], c["id"]]]["nodes"]:
				if planner.path_to(id).is_empty():
					all_paths = false
	check(all_paths, "chaque nœud de frontière a un chemin depuis la graine")

	# Les grappes de branche restent où elles étaient sans frontière (à quelques pixels près).
	var real: Array = SkillTree.BORDERS
	SkillTree.BORDERS = []
	var plain = SkillTree.new()
	plain.build()
	SkillTree.BORDERS = real
	var worst := 0.0
	var same := 0
	for n in plain.nodes:
		if n["cluster"] == "":
			continue
		var id: int = tree.id_for_uid(n["uid"])
		if id >= 0:
			same += 1
			worst = maxf(worst, n["pos"].distance_to(tree.nodes[id]["pos"]))
	check(same > 200 and worst < 0.4 * SkillTree.RING_GAP, "les grappes de branche gardent leur place (écart maximal %d px)" % worst)
	check(tree.nodes.size() > plain.nodes.size(), "l'arbre grandit : %d nœuds au lieu de %d" % [tree.nodes.size(), plain.nodes.size()])

	print("Résonance des deux branches")
	game.reset()
	var path: Array = planner.path_to(tree.id_for_uid("c:ronce-spore:dard:d5"))
	game.points = path.size()
	for id in path:
		game.allocate(id)
	var border_owned := 0
	for id in game.allocated:
		if tree.nodes[id]["border"] >= 0:
			border_owned += 1
	var ronce: int = game.branch_count(0)
	var spore: int = game.branch_count(1)
	var plain_ronce := 0
	var plain_spore := 0
	for id in game.allocated:
		if tree.nodes[id]["border"] < 0:
			plain_ronce += 1 if tree.nodes[id]["branch"] == 0 else 0
			plain_spore += 1 if tree.nodes[id]["branch"] == 1 else 0
	check(border_owned >= 3 and ronce == plain_ronce + border_owned and spore == plain_spore + border_owned,
		"un nœud de frontière compte pour Ronce et pour Spore (%d nœuds de frontière, %d Ronce, %d Spore)" % [border_owned, ronce, spore])
	var b0: Dictionary = SkillTree.BRANCHES[0]
	var b1: Dictionary = SkillTree.BRANCHES[1]
	var saved0 = b0.get("resonance")
	var saved1 = b1.get("resonance")
	b0["resonance"] = [{"count": border_owned, "effects": [{"stat": "pickup", "op": "add", "value": 3}]}]
	b1["resonance"] = [{"count": border_owned, "effects": [{"stat": "pickup", "op": "add", "value": 5}]}]
	var only_border := {0: true}
	for id in game.allocated:
		if tree.nodes[id]["border"] >= 0:
			only_border[id] = true
	var tiers := 0
	for src in game.effect_sources(only_border):
		if str(src["id"]).begins_with("resonance:"):
			tiers += 1
	check(tiers == 2, "avec seulement des nœuds de frontière, les paliers des deux branches sont atteints")
	b0["resonance"] = saved0
	b1["resonance"] = saved1

	print("Conditions des deux branches")
	var fx = Effects.new()
	var both_cond := {"on": "kill", "if": [{"state": "cible_saignante", "min": 1}, {"state": "cible_empoisonnee"}], "do": "heal", "value": 0.5, "text": "x"}
	fx.rebuild([{"id": 1, "effects": [both_cond]}])
	var main := FakeMain.new()
	check(not fx.fire("kill", {"main": main, "cible_saignante": 2.0, "cible_empoisonnee": 0.0}), "saigne sans poison : rien")
	check(not fx.fire("kill", {"main": main, "cible_saignante": 0.0, "cible_empoisonnee": 1.5}), "empoisonné sans saigner : rien")
	check(fx.fire("kill", {"main": main, "cible_saignante": 1.0, "cible_empoisonnee": 1.5}), "saigne et empoisonné : l'effet part")
	var line := Effects.describe({"stat": "damage", "op": "inc", "value": 0.1, "if": [{"state": "cible_saignante", "min": 1}, {"state": "cible_empoisonnee"}]})
	check(line.contains(" et ") and line.contains("saigne") and line.contains("empoisonnée"), "l'infobulle relie les conditions par « et » (%s)" % line)
	fx.rebuild([{"id": 1, "effects": [{"stat": "damage", "op": "more", "value": 2, "if": {"state": "en_mouvement", "min": 0.5}},
		{"stat": "armor", "op": "add", "value": 0.1, "if": {"state": "sous_cocon"}}]}])
	var base_dmg: float = fx.stats["damage"]
	fx.set_state("en_mouvement", 1.0)
	fx.set_state("sous_cocon", 1.0)
	check(is_equal_approx(fx.stats["damage"], base_dmg * 2.0) and fx.stats["armor"] > 0.09, "états en_mouvement et sous_cocon lus par les conditions")
	check(Content.conditions().has("en_mouvement") and Content.conditions().has("sous_cocon"), "les deux états sont décrits dans conditions.json")

	print("Dessin")
	var d5: Dictionary = tree.nodes[tree.id_for_uid("c:ronce-spore:dard:d5")]
	var col: Color = tree.node_color(d5)
	check(col != tree.branch_color(0) and col != tree.branch_color(1), "un nœud de frontière mêle les couleurs des deux branches")
	var d1: Dictionary = tree.nodes[tree.id_for_uid("c:ronce-spore:dard:d1")]
	var d2: Dictionary = tree.nodes[tree.id_for_uid("c:ronce-spore:dard:d2")]
	var to_b: Vector2 = SkillTree.border_dir(d1)
	check(d1["branch"] == 0 and d2["branch"] == 1 and to_b.dot(d2["pos"] - d1["pos"]) > 0.0, "la couture de « d1 » (Ronce) regarde vers Spore")
	check(SkillTree.border_dir(d2).dot(d1["pos"] - d2["pos"]) > 0.0, "la couture de « d2 » (Spore) regarde vers Ronce")

	print("Sauvegarde")
	save.delete_save(PATH)
	var want: Array = game.allocated_uids()
	check(save.save_now(null, PATH), "sauvegarde avec des nœuds de frontière")
	game.reset()
	check(save.load_into(null, PATH) and game.allocated_uids() == want, "nœuds de frontière retrouvés par identifiant stable")
	save.delete_save(PATH)

	print("Sauvegarde du jalon 8")
	check(FileAccess.file_exists(JALON8), "la sauvegarde du jalon 8 est là")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(JALON8))
	var old_uids: Array = old["tree"]["allocated"]
	var gone := 0
	for uid in old_uids:
		if tree.id_for_uid(str(uid)) < 0:
			gone += 1
	var spent: int = old_uids.size() + int(old["game"]["points"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	game.reset()
	check(save.load_into(null, PATH), "elle se charge")
	var now: int = game.allocated.size() - 1 + game.points
	check(gone > 0, "des nœuds générés de la sauvegarde ont laissé place aux frontières (%d)" % gone)
	check(now == spent, "aucun point perdu : %d nœuds appris et %d points à placer (%d avant)" % [game.allocated.size() - 1, game.points, spent])
	check(game.level == int(old["game"]["level"]) and game.choices.size() > 0, "niveau et choix repris")
	var seen := {0: true}
	var stack: Array = [0]
	while not stack.is_empty():
		for m in tree.nodes[stack.pop_back()]["neighbors"]:
			if game.allocated.has(m) and not seen.has(m):
				seen[m] = true
				stack.append(m)
	check(seen.size() == game.allocated.size(), "tout ce qui reste appris est relié à la graine")
	save.delete_save(PATH)

	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)


func _has(errors: PackedStringArray, part: String) -> bool:
	for e in errors:
		if e.contains(part):
			return true
	return false


class FakePlayer:
	var hp := 0.0
	var position := Vector2.ZERO
	func heal(v: float) -> void:
		hp += v


class FakeMain:
	var player := FakePlayer.new()
