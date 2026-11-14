## Test des outils de planification de l'arbre (tree_planner.gd) : plus court chemin, coût,
## simulation sans effet de bord, annulation, recherche, résumé, plan sauvegardé et rechargé.
## Lancer : tools/godot.sh --headless -s res://tests/planner_test.gd
extends SceneTree

const TreePlanner = preload("res://scripts/tree_planner.gd")
const PATH := "user://tests/plan_test.json"

var failures := 0
var game


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
	var tree = game.tree
	game.reset()
	var planner = TreePlanner.new(game)

	print("Plus court chemin")
	var far := _node_at_ring(6)
	var path: Array = planner.path_to(far)
	check(path.size() == _bfs_distance(far), "le coût vers un nœud de l'anneau 6 est la distance minimale (%d points)" % path.size())
	check(path.back() == far and not game.allocated.has(path[0]), "le chemin finit sur la cible et ne contient que des nœuds à apprendre")
	check(_is_chain(path), "chaque nœud du chemin touche le précédent, le premier touche un nœud appris")
	var worst := 0
	var all_ok := true
	for n in tree.nodes:
		var p: Array = planner.path_to(n["id"])
		if n["id"] != 0 and (p.size() != _bfs_distance(n["id"]) or not _is_chain(p)):
			all_ok = false
		worst = maxi(worst, p.size())
	check(all_ok, "tous les nœuds de l'arbre ont un chemin de longueur minimale (le plus long : %d)" % worst)
	check(planner.path_to(0).is_empty(), "pas de chemin vers un nœud déjà appris")
	var near: int = tree.nodes[0]["neighbors"][0]
	check(planner.path_to(near) == [near], "un nœud voisin coûte 1 point")
	check(planner.route_to(far)[0] == 0, "le trajet complet part d'un nœud appris")

	print("Simulation sans effet de bord")
	var before_stats: Dictionary = game.stats.duplicate()
	var before_alloc: Dictionary = game.allocated.duplicate()
	var before_points: int = game.points
	var sim: Dictionary = planner.simulate(path)
	var changes: Array = planner.preview(path)
	check(sim["nodes"] == 1 + path.size(), "la simulation compte les nœuds du chemin")
	check(changes.size() > 0 and changes[0]["text"].contains("→"), "l'aperçu donne des différences lisibles (%s)" % (changes[0]["text"] if changes.size() > 0 else ""))
	check(game.stats == before_stats and game.allocated == before_alloc and game.points == before_points, "la partie n'a pas bougé (statistiques, nœuds, points)")

	print("Apprendre tout un chemin")
	game.points = path.size() - 1
	check(not planner.learn_path(path) and game.allocated.size() == 1, "refusé s'il manque un point, rien n'est appris")
	game.points = path.size() + 2
	check(planner.learn_path(path), "appris d'un coup quand les points suffisent")
	check(game.points == 2 and game.allocated.has(far), "les points sont dépensés et la cible est apprise")
	check(_same_stats(game.stats, sim["stats"]), "les statistiques réelles sont celles que la simulation annonçait")
	check(planner.preview([]).is_empty(), "aucune différence quand on ne change rien")

	print("Annulation")
	check(planner.can_undo() and planner.undo(), "annuler le chemin")
	check(game.allocated.size() == 1 and game.points == path.size() + 2 and _same_stats(game.stats, before_stats), "retour à l'état d'avant")
	check(not planner.can_undo(), "plus rien à annuler")
	planner.learn(near)
	check(planner.forget(near) and not game.allocated.has(near), "oublier un nœud")
	check(planner.undo() and game.allocated.has(near), "annuler l'oubli le réapprend")
	check(planner.undo() and not game.allocated.has(near), "annuler encore défait l'apprentissage")
	planner.learn(near)
	game.reset()
	check(not planner.can_undo(), "la pile est vidée après une nouvelle partie")

	print("Recherche")
	var hits: Array = planner.search("couronne")
	check(hits.size() == 1 and tree.nodes[hits[0]]["key"] == "nova", "par nom : « couronne » trouve la Couronne d'épines")
	check(planner.search("EPINES").size() > 5, "par statistique, sans tenir compte des accents ni des majuscules")
	check(planner.search("nuage toxique").size() == 1, "par texte d'effet, tous les mots doivent correspondre")
	check(planner.search("zzzz").is_empty() and planner.search("  ").is_empty(), "rien pour un mot inconnu ou une recherche vide")

	print("Plan")
	game.points = 0
	var added: int = planner.plan_add(far)
	check(added == path.size() and planner.plan_cost() == path.size(), "tracer un plan sans point (%d nœuds)" % added)
	check(game.allocated.size() == 1 and game.points == 0, "le plan ne dépense rien")
	check(planner.plan_missing() == path.size() and not planner.plan_commit(), "validation refusée tant que les points manquent")
	var far2 := _node_at_ring(5, tree.nodes[far]["branch"] + 1)
	planner.plan_add(far2)
	check(planner.plan_has(far2) and _is_chain(planner.plan), "un second objectif s'ajoute au plan existant")
	var total: int = planner.plan_cost()
	check(planner.plan_remove(path[0]) >= path.size() and not planner.plan_has(far), "retirer un nœud retire aussi ce qui en dépendait")
	check(planner.undo() and planner.plan_cost() == total, "annuler une modification du plan")
	var summary: Dictionary = planner.summary(planner.plan)
	check(summary["nodes"] == total, "le résumé peut inclure le plan (%d nœuds)" % summary["nodes"])

	print("Plan sauvegardé et rechargé")
	check(game.flags.get(TreePlanner.FLAG, "") is String and game.flags[TreePlanner.FLAG] != "", "le plan est dans Game.flags, sous forme de texte")
	var wanted: Array = planner.plan.duplicate()
	save.delete_save(PATH)
	check(save.save_now(null, PATH), "sauvegarde")
	game.reset()
	planner.sync()
	check(planner.plan.is_empty(), "une nouvelle partie n'a pas de plan")
	check(save.load_into(null, PATH), "chargement")
	var reloaded = TreePlanner.new(game)
	planner.sync()
	check(reloaded.plan == wanted and planner.plan == wanted, "le plan est retrouvé à l'identique")
	save.delete_save(PATH)

	print("Validation du plan")
	game.points = total + 1
	planner.learn(wanted[0])
	check(not planner.plan_has(wanted[0]) and planner.plan_cost() == total - 1, "un nœud appris à la main sort du plan")
	check(planner.plan_commit(), "valider le plan quand les points sont là")
	check(game.points == 1 and game.allocated.has(far) and game.allocated.has(far2) and planner.plan.is_empty(), "tout est appris, le plan est vide")
	check(not game.flags.has(TreePlanner.FLAG), "le drapeau du plan est retiré")
	check(planner.undo() and planner.plan_cost() == total - 1 and game.points == total, "annuler la validation rend les points et le plan")

	print("Résumé du build")
	planner.plan_commit()
	summary = planner.summary()
	var by_branch := 0
	for b in summary["branches"]:
		by_branch += b["count"]
	check(summary["nodes"] == game.allocated.size() - 1 and by_branch == summary["nodes"], "nombre de nœuds, total et par branche")
	check(summary["stats"].size() == game.stats.size(), "une ligne par statistique")
	var ks := _first_keystone()
	game.points = 99
	planner.learn(ks)
	summary = planner.summary()
	check(summary["keystones"].size() >= 1 and summary["skills"].size() >= 1, "nœuds clés et compétences (%s)" % ", ".join(summary["skills"]))

	game.reset()
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)


func _node_at_ring(ring: int, branch := 0) -> int:
	for n in game.tree.nodes:
		if n["ring"] == ring and n["branch"] == branch:
			return n["id"]
	return -1


func _first_keystone() -> int:
	for n in game.tree.nodes:
		if n["key"] == "nova":
			return n["id"]
	return -1


## Distance de référence : parcours en largeur naïf depuis la cible jusqu'au premier nœud appris.
func _bfs_distance(target: int) -> int:
	var dist := {target: 0}
	var queue: Array = [target]
	while queue.size() > 0:
		var u: int = queue.pop_front()
		if game.allocated.has(u):
			return dist[u]
		for v in game.tree.nodes[u]["neighbors"]:
			if not dist.has(v):
				dist[v] = dist[u] + 1
				queue.append(v)
	return -1


func _is_chain(path: Array) -> bool:
	var set: Dictionary = game.allocated.duplicate()
	for id in path:
		var ok := false
		for m in game.tree.nodes[id]["neighbors"]:
			if set.has(m):
				ok = true
		if not ok or set.has(id):
			return false
		set[id] = true
	return true






func _same_stats(a: Dictionary, b: Dictionary) -> bool:
	for k in a:
		if not b.has(k) or not is_equal_approx(float(a[k]), float(b[k])):
			return false
	return a.size() == b.size()
