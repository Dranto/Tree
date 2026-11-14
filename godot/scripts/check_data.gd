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
	for b in Content.branches():
		for ks in b["keystones"]:
			if not keys.has(ks["key"]):
				errors.append("Le nœud clé « %s » n'a pas de place dans l'arbre" % ks["key"])
	print("Arbre : %d nœuds, %d liens, %s" % [tree.nodes.size(), tree.edges.size(), str(kinds)])


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


func _expect(what: String, got: float, want: float) -> void:
	if absf(got - want) > 0.0001:
		errors.append("%s : obtenu %s, attendu %s" % [what, got, want])
