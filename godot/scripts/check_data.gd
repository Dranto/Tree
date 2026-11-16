## Vérifie les données de res://data/ sans lancer le jeu :
##   tools/godot.sh --headless -s res://scripts/check_data.gd
## Contrôle le format des fichiers, que tout nœud de l'arbre est relié à la graine,
## et le calcul des statistiques sur quelques cas connus. Code de sortie 1 en cas d'erreur.
extends SceneTree

const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")
const SkillTree = preload("res://scripts/skill_tree.gd")

var errors := PackedStringArray()


class FakeFx:
	var texts := 0
	func text(_pos, _label, _color, _size, _dur) -> void:
		texts += 1


class FakePlayer:
	var hp := 0.0
	var invuln := 0.0
	var dash_cd := 1.0
	var cds := {}
	var position := Vector2.ZERO


class FakeMain:
	var player := FakePlayer.new()
	var fx := FakeFx.new()
	var enemies: Array = []


func _init() -> void:
	errors.append_array(Content.validate(int(SkillTree.RINGS / 4.0)))
	# Sortes d'ennemis et apparitions par région (data/enemies.json).
	errors.append_array(load("res://scripts/enemy.gd").validate_kinds())
	# Menace, apparitions, courbe d'expérience et modes de difficulté (data/difficulty.json).
	errors.append_array(load("res://scripts/difficulty.gd").validate())
	# Objectifs de la tranche (data/objectives.json).
	errors.append_array(load("res://scripts/objective_check.gd").validate())
	if errors.is_empty():
		_check_tree()
		_check_engine()
	for e in errors:
		printerr("ERREUR : " + e)
	if errors.is_empty():
		print("Données valides.")
	quit(0 if errors.is_empty() else 1)


func _check_tree() -> void:
	var tree = SkillTree.new()
	tree.build()
	var seen := {0: true}
	var stack: Array = [0]
	while stack.size() > 0:
		for m in tree.nodes[stack.pop_back()]["neighbors"]:
			if not seen.has(m):
				seen[m] = true
				stack.append(m)
	if seen.size() != tree.nodes.size():
		errors.append("%d nœuds ne sont pas reliés à la graine" % (tree.nodes.size() - seen.size()))
	var kinds := {}
	var keys := {}
	for n in tree.nodes:
		kinds[n["type"]] = int(kinds.get(n["type"], 0)) + 1
		if n["key"] != "":
			keys[n["key"]] = true
		if n["id"] != 0 and SkillTree.describe(n).is_empty():
			errors.append("Le nœud %d (%s) n'a aucun texte à afficher" % [n["id"], n["name"]])
	_check_clusters(tree)
	for b in Content.branches():
		for ks in b["keystones"]:
			if not keys.has(ks["key"]):
				errors.append("Le nœud clé « %s » n'a pas de place dans l'arbre" % ks["key"])
	print("Arbre : %d nœuds, %d liens, %s" % [tree.nodes.size(), tree.edges.size(), str(kinds)])


## Grappes écrites à la main, une fois insérées dans l'arbre : chaque nœud a sa place, aucun ne
## recouvre la graine, un nœud clé ou un autre nœud de grappe, et chaque exclusion vise un nœud qui existe.
func _check_clusters(tree) -> void:
	var gap: float = SkillTree.RING_GAP
	var placed: Array = []
	for bi in SkillTree.BRANCHES.size():
		var b: Dictionary = SkillTree.BRANCHES[bi]
		for c in b.get("clusters", []):
			var where := "branches/%s.json, grappe « %s »" % [b["id"], c["id"]]
			var key := "%s:%s" % [b["id"], c["id"]]
			if not tree.clusters.has(key) or tree.clusters[key]["nodes"].size() != c["nodes"].size():
				errors.append(where + " : tous ses nœuds n'ont pas trouvé place dans l'arbre")
				continue
			for id in tree.clusters[key]["nodes"]:
				var n: Dictionary = tree.nodes[id]
				var p: Vector2 = n["pos"]
				if p.length() > (SkillTree.RINGS + 0.5) * gap or p.length() < 0.6 * gap:
					errors.append("%s : le nœud « %s » sort de l'arbre ou touche la graine" % [where, n["local"]])
				for o in tree.nodes:
					if o["cluster"] == "" and o["type"] == "keystone" and p.distance_to(o["pos"]) < SkillTree.CLEAR_NODE * gap:
						errors.append("%s : le nœud « %s » recouvre le nœud clé « %s » (déplacer la grappe)" % [where, n["local"], o["name"]])
				for q in placed:
					if p.distance_to(q[0]) < 0.45 * gap:
						errors.append("%s : le nœud « %s » est trop près de « %s » (moins de 0,45 anneau)" % [where, n["local"], q[1]])
				placed.append([p, "%s:%s" % [key, n["local"]]])
				if n["excludes"].size() != tree.exclusions.get(id, []).size() and n["excludes"].size() > tree.exclusions.get(id, []).size():
					errors.append("%s : une entrée de « excludes » du nœud « %s » ne désigne aucun nœud" % [where, n["local"]])
				if n["neighbors"].is_empty():
					errors.append("%s : le nœud « %s » est isolé" % [where, n["local"]])


func _check_engine() -> void:
	var fx = Effects.new()
	fx.rebuild([])
	var base: Dictionary = fx.stats.duplicate()
	for name in Content.stats():
		if not base.has(name):
			errors.append("Statistique non calculée : " + name)

	# Ordre du calcul : (base + add) × (1 + inc) × more + flat.
	fx.rebuild([{"id": 1, "effects": [
		{"stat": "max_hp", "op": "add", "value": 50},
		{"stat": "max_hp", "op": "inc", "value": 0.5},
		{"stat": "max_hp", "op": "more", "value": 2},
		{"stat": "max_hp", "op": "flat", "value": 7},
		{"stat": "armor", "op": "add", "value": 5},
		{"stat": "pierce", "op": "add", "value": 1.5},
		{"stat": "dash_cd", "op": "inc", "value": -5},
	]}])
	_expect("ordre du calcul", fx.stats["max_hp"], (base["max_hp"] + 50.0) * 1.5 * 2.0 + 7.0)
	_expect("plafond d'armure", fx.stats["armor"], base["armor_cap"])
	_expect("arrondi de la perforation", fx.stats["pierce"], 1)
	_expect("réduction maximale de la recharge", fx.stats["dash_cd"], base["dash_cd"] * (1.0 + Content.stats()["dash_cd"]["inc_min"]))

	# Effet conditionnel : actif seulement quand l'état dépasse le seuil.
	fx.rebuild([{"id": 1, "effects": [{"stat": "damage", "op": "more", "value": 2, "if": {"state": "immobile", "min": 0.5}}]}])
	_expect("condition inactive", fx.stats["damage"], base["damage"])
	if fx.set_state("immobile", 0.2) or not fx.set_state("immobile", 0.6):
		errors.append("set_state ne signale pas correctement le changement d'un effet conditionnel")
	_expect("condition active", fx.stats["damage"], base["damage"] * 2.0)

	# Effet déclenché, avec temps de recharge.
	var main := FakeMain.new()
	fx.rebuild([{"id": 1, "effects": [
		{"on": "lethal_hit", "do": "survive", "hp": 1, "cooldown": 60, "label": "x", "text": "x"},
		{"on": "kill", "do": "reduce_cooldown", "target": "dash", "value": 0.3, "text": "x"},
		{"skill": "nova"},
	]}])
	if not fx.fire("lethal_hit", {"main": main}) or main.player.hp != 1.0 or main.fx.texts != 1:
		errors.append("L'action « survive » n'a pas sauvé le joueur")
	if fx.fire("lethal_hit", {"main": main}):
		errors.append("Le temps de recharge d'un effet déclenché n'est pas respecté")
	fx.tick(61.0)
	if not fx.fire("lethal_hit", {"main": main}):
		errors.append("Un effet déclenché ne se recharge pas")
	fx.fire("kill", {"main": main})
	_expect("action reduce_cooldown", main.player.dash_cd, 0.7)
	if not fx.skills.has("nova"):
		errors.append("Une compétence donnée par un nœud n'est pas enregistrée")
	if fx.fire("crit", {"main": main}):
		errors.append("Un évènement sans effet ne doit rien déclencher")

	# Mutation d'une compétence : (réglage + add) × (1 + inc) × more, « set » remplace.
	var nova: Dictionary = Content.skills().get("nova", {})
	fx.rebuild([{"id": 1, "effects": [
		{"skill_mod": "nova", "param": "radius", "op": "add", "value": 30, "text": "x"},
		{"skill_mod": "nova", "param": "radius", "op": "inc", "value": 0.5, "text": "x"},
		{"skill_mod": "nova", "param": "radius", "op": "more", "value": 2, "text": "x"},
		{"skill_mod": "nova", "param": "forme", "op": "set", "value": "spirale", "text": "x"},
	]}])
	var mutated: Dictionary = fx.skill_settings("nova")
	_expect("mutation d'un réglage de compétence", mutated.get("radius", 0.0), (float(nova.get("radius", 0.0)) + 30.0) * 1.5 * 2.0)
	if mutated.get("forme", "") != "spirale" or Content.skills()["nova"].has("forme"):
		errors.append("L'opération « set » d'un skill_mod doit poser le réglage sans toucher à skills.json")
	fx.rebuild([])
	_expect("réglage sans mutation", fx.skill_settings("nova").get("radius", 0.0), float(nova.get("radius", 0.0)))


func _expect(what: String, got: float, want: float) -> void:
	if absf(got - want) > 0.0001:
		errors.append("%s : obtenu %s, attendu %s" % [what, got, want])
