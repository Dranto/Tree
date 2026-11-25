## Nœuds originaux (jalon 11, skill_tree.gd › _enliven) : proportion de petits nœuds, jamais plus de
## deux petits nœuds d'affilée, mutations générées qui ne coupent aucun chemin, chaque original de
## chaque branche posé au moins une fois, petits nœuds variés, nouveaux états des conditions, et
## sauvegarde : une mutation reprise sans sa compétence est rendue.
## Lancer : tools/godot.sh --headless -s res://tests/tree_originals_test.gd
extends SceneTree

const SkillTree = preload("res://scripts/skill_tree.gd")
const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")
const TreePlanner = preload("res://scripts/tree_planner.gd")

## Part des petits nœuds à ne pas dépasser (cible du jalon 11 : environ 35 %).
const SMALL_MAX := 0.37

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t = SkillTree.new()
	t.build()
	var nodes: Array = t.nodes
	var count := {}
	for n in nodes:
		count[n["type"]] = int(count.get(n["type"], 0)) + 1
	var share := float(count.get("small", 0)) / nodes.size()
	print("Arbre : %d nœuds, %s, petits nœuds %.1f %%" % [nodes.size(), count, share * 100.0])
	check(nodes.size() >= 880 and nodes.size() <= 930, "taille de l'arbre inchangée (environ 900 nœuds)")
	check(share <= SMALL_MAX, "petits nœuds sous %d %% (%.1f %%)" % [int(SMALL_MAX * 100.0), share * 100.0])
	check(not count.has("graft"), "aucun nœud de type greffe")

	# Jamais plus de deux petits nœuds d'affilée : un groupe de petits nœuds reliés entre eux en a
	# au plus deux, et un petit nœud généré ne touche aucun autre petit nœud.
	var worst := 0
	var seen := {}
	var touching := 0
	for n in nodes:
		if n["type"] != "small":
			continue
		if n["cluster"] == "":
			for m in n["neighbors"]:
				if nodes[m]["type"] == "small":
					touching += 1
		if seen.has(n["id"]):
			continue
		var size := 0
		var stack: Array = [n["id"]]
		seen[n["id"]] = true
		while stack.size() > 0:
			var u: int = stack.pop_back()
			size += 1
			for m in nodes[u]["neighbors"]:
				if nodes[m]["type"] == "small" and not seen.has(m):
					seen[m] = true
					stack.append(m)
		worst = maxi(worst, size)
	print("Plus long groupe de petits nœuds : %d" % worst)
	check(worst <= 2, "jamais plus de deux petits nœuds d'affilée (%d au plus)" % worst)
	check(touching == 0, "un petit nœud généré ne touche aucun autre petit nœud")

	# Mutations générées : fermées tant que la compétence manque, elles ne coupent aucun chemin.
	var locked := {}
	var generated := {}
	for n in nodes:
		if n["type"] == "withered" or n["type"] == "mutation":
			locked[n["id"]] = true
		if n["type"] == "mutation" and n["cluster"] == "":
			generated[n["id"]] = true
	var without := locked.duplicate()
	for id in generated:
		without.erase(id)
	check(generated.size() >= 24, "mutations générées : %d" % generated.size())
	check(_reach(nodes, locked) == _reach(nodes, without) - generated.size(), "fermer toutes les mutations générées ne coupe aucun autre nœud de la graine")
	for id in generated:
		var n: Dictionary = nodes[id]
		var ok: bool = t.skill_sources.has(n["mutates"]) and n["choices"].size() >= 2
		if not ok:
			check(false, "mutation %s : compétence « %s » donnée dans l'arbre, deux choix" % [n["uid"], n["mutates"]])
			break

	# Chaque original de chaque branche est posé au moins une fois, chacun change le jeu (pas une
	# simple statistique sans condition) et garde la statistique de son petit nœud.
	for bi in SkillTree.BRANCHES.size():
		var b: Dictionary = SkillTree.BRANCHES[bi]
		var names := {}
		var stats := {}
		var plain := 0
		for n in nodes:
			if n["branch"] != bi or n["cluster"] != "" or n["border"] >= 0:
				continue
			if n["type"] == "small":
				stats[n["effects"][0]["stat"]] = true
			if (n["type"] == "notable" or n["type"] == "attack") and n["name"] != "":
				names[n["name"]] = true
		var missing: Array = []
		for o in b.get("originals", []):
			var found := false
			for nm in o.get("names", []):
				if names.has(nm):
					found = true
			if not found:
				missing.append(o["names"][0])
			if not _changes_play(o.get("effects", [])):
				plain += 1
		check(missing.is_empty(), "%s : chaque original est posé dans l'arbre %s" % [b["id"], missing])
		check(plain == 0, "%s : chaque original change le jeu (condition, déclencheur, attaque ou compétence)" % b["id"])
		check(stats.size() >= 3, "%s : petits nœuds variés (%d statistiques)" % [b["id"], stats.size()])
		check(b.get("mutations", []).size() >= 5, "%s : au moins cinq mutations générées écrites" % b["id"])

	# Nouveaux états des conditions.
	var fx := Effects.new()
	fx.rebuild([{"id": 1, "effects": [{"stat": "damage", "op": "more", "value": 2, "if": {"state": "terre_vive"}},
		{"stat": "armor", "op": "add", "value": 0.1, "if": {"state": "greffes", "min": 3}}]}])
	var base: float = fx.stats["damage"]
	fx.set_state("terre_vive", 1.0)
	check(is_equal_approx(fx.stats["damage"], base * 2.0), "condition « terre_vive »")
	fx.set_state("greffes", 2.0)
	var armor: float = fx.stats["armor"]
	fx.set_state("greffes", 3.0)
	check(fx.stats["armor"] > armor, "condition « greffes » à partir de 3")
	for st in ["vie_basse", "terre_vive", "terre_fletrie", "greffes", "coeurs_purifies"]:
		check(Content.conditions().has(st), "conditions.json décrit « %s »" % st)
	check(Effects.describe({"stat": "damage", "op": "inc", "value": 0.1, "if": {"state": "terre_vive"}}).contains("terre vivante"), "texte d'une condition de terrain")

	# Sauvegarde : un ancien petit nœud devenu mutation, repris sans sa compétence, est rendu.
	var game = root.get_node("Game")
	var target := -1
	for id in generated:
		target = id
		break
	if target >= 0:
		var path: Array = TreePlanner.shortest_path(game.tree, {0: true}, target)
		var uids: Array = []
		var skill_on_path := false
		for id in path:
			uids.append(game.tree.nodes[id]["uid"])
			if id in game.tree.skill_sources.get(game.tree.nodes[target]["mutates"], []):
				skill_on_path = true
		var points: int = game.points
		var refunded: int = game.restore_allocation(uids)
		if skill_on_path:
			check(game.allocated.has(target), "mutation gardée avec sa compétence")
		else:
			check(not game.allocated.has(target) and refunded >= 1 and game.points == points + refunded, "mutation reprise sans sa compétence : rendue (%d point(s))" % refunded)

	print("RÉSULTAT ", "OK" if failures == 0 else "%d échec(s)" % failures)
	quit(0 if failures == 0 else 1)


## Vrai si la liste porte au moins un effet qui change la façon de jouer : condition, évènement,
## compétence, mutation ou attaque.
static func _changes_play(effects: Array) -> bool:
	for e in effects:
		if e is Dictionary and (e.has("if") or e.has("on") or e.has("skill") or e.has("skill_mod") or e.has("attack_mod") or e.has("attack_form")):
			return true
	return false


static func _reach(nodes: Array, blocked: Dictionary) -> int:
	var seen := {0: true}
	var stack: Array = [0]
	while stack.size() > 0:
		var u: int = stack.pop_back()
		for m in nodes[u]["neighbors"]:
			if not seen.has(m) and not blocked.has(m):
				seen[m] = true
				stack.append(m)
	return seen.size()
