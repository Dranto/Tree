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
## Graine imposée par « -- --seed=N » pour rejouer une partie à l'identique (tests visuels), -1 sinon.
var forced_seed := -1
## Drapeaux de l'aventure (quêtes, rencontres, fin…) : sauvegardés tels quels.
## Valeurs simples uniquement (bool, nombre, texte) pour rester sérialisables en JSON.
var flags: Dictionary = {}
## Moteur d'effets : statistiques, compétences et réactions des nœuds appris (voir effects.gd).
var effects = Effects.new()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			forced_seed = int(arg.get_slice("=", 1))
			seed(forced_seed)
	for err in Content.validate(int(SkillTree.RINGS / 4.0)):
		push_error("Données : " + err)
	tree = SkillTree.new()
	tree.build()
	reset()


## Remet la progression à zéro (nouvelle partie).
func reset() -> void:
	allocated = {0: true}
	points = 1
	level = 1
	xp = 0.0
	kills = 0
	flags = {}
	recompute()
	tree_changed.emit()


## Recharge les nœuds appris à partir de leurs identifiants stables.
## Les nœuds disparus de l'arbre ou qui ne sont plus reliés à la graine sont
## ignorés et leur point est rendu. Renvoie le nombre de points rendus.
func restore_allocation(uids: Array) -> int:
	var wanted := {}
	var refunded := 0
	for uid in uids:
		var id: int = tree.id_for_uid(str(uid))
		if id < 0:
			refunded += 1
		elif id != 0:
			wanted[id] = true
	# On ne garde que ce qui reste relié à la graine.
	var kept := {0: true}
	var stack: Array = [0]
	while stack.size() > 0:
		var n: int = stack.pop_back()
		for m in tree.nodes[n]["neighbors"]:
			if wanted.has(m) and not kept.has(m):
				kept[m] = true
				stack.append(m)
	refunded += wanted.size() - (kept.size() - 1)
	allocated = kept
	points += refunded
	recompute()
	tree_changed.emit()
	return refunded


func allocated_uids() -> Array:
	var out: Array = []
	for id in allocated:
		if id != 0:
			out.append(tree.nodes[id]["uid"])
	out.sort()
	return out


## Initialise un générateur : graine imposée si elle existe (décalée de « salt »), sinon aléatoire.
func seed_rng(rng: RandomNumberGenerator, salt := 0) -> void:
	if forced_seed >= 0:
		rng.seed = forced_seed + salt
	else:
		rng.randomize()


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
