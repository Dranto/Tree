## État global : arbre de vie, niveau, expérience et statistiques du personnage.
extends Node

signal stats_changed
signal tree_changed
signal leveled_up(level: int)
signal node_allocated(node: Dictionary)

const SkillTree = preload("res://scripts/skill_tree.gd")
const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")

var tree = null
var allocated: Dictionary = {}
var points: int = 1
var level: int = 1
var xp: float = 0.0
var kills: int = 0
var stats: Dictionary = {}
var keys: Dictionary = {}
## Moteur d'effets : statistiques, compétences et réactions des nœuds appris (voir effects.gd).
var effects = Effects.new()


func _ready() -> void:
	for err in Content.validate(int(SkillTree.RINGS / 4.0)):
		push_error("Données : " + err)
	tree = SkillTree.new()
	tree.build()
	allocated[0] = true
	recompute()


func xp_to_next() -> float:
	return 10.0 * pow(float(level), 1.5)


func add_xp(v: float) -> void:
	xp += v
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		points += 1
		leveled_up.emit(level)


func has_key(k: String) -> bool:
	return keys.has(k)


func can_allocate(id: int) -> bool:
	if allocated.has(id) or points <= 0:
		return false
	for m in tree.nodes[id]["neighbors"]:
		if allocated.has(m):
			return true
	return false


func allocate(id: int) -> bool:
	if not can_allocate(id):
		return false
	allocated[id] = true
	points -= 1
	recompute()
	node_allocated.emit(tree.nodes[id])
	tree_changed.emit()
	return true


## Un nœud peut être oublié s'il n'est pas la graine et que l'arbre reste relié sans lui.
func can_refund(id: int) -> bool:
	if id == 0 or not allocated.has(id):
		return false
	var seen := {0: true}
	var stack: Array = [0]
	while stack.size() > 0:
		var n: int = stack.pop_back()
		for m in tree.nodes[n]["neighbors"]:
			if m != id and allocated.has(m) and not seen.has(m):
				seen[m] = true
				stack.append(m)
	return seen.size() == allocated.size() - 1


func refund(id: int) -> bool:
	if not can_refund(id):
		return false
	allocated.erase(id)
	points += 1
	recompute()
	tree_changed.emit()
	return true


func _process(delta: float) -> void:
	effects.tick(delta)


## Signale un évènement du jeu (« kill », « crit », « lethal_hit ») aux effets des nœuds appris.
## Renvoie true si un effet l'a pris en charge.
func fire(event: String, ctx: Dictionary = {}) -> bool:
	return effects.fire(event, ctx)


## Met à jour un état dont dépendent des effets conditionnels (par exemple « immobile »).
func set_state(state: String, value: float) -> void:
	if effects.set_state(state, value):
		stats = effects.stats
		stats_changed.emit()


## Recalcule les statistiques à partir des effets des nœuds appris.
## Les valeurs de base et les formules sont dans res://data/stats.json.
func recompute() -> void:
	var learned: Array = []
	keys = {}
	for id in allocated:
		var n: Dictionary = tree.nodes[id]
		learned.append(n)
		if n["key"] != "":
			keys[n["key"]] = true
	effects.rebuild(learned)
	for k in effects.skills:
		keys[k] = true
	stats = effects.stats
	stats_changed.emit()
