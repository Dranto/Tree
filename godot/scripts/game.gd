## État global : arbre de vie, niveau, expérience et statistiques du personnage.
extends Node

signal stats_changed
signal tree_changed
signal leveled_up(level: int)
signal node_allocated(node: Dictionary)

const SkillTree = preload("res://scripts/skill_tree.gd")

var tree = null
var allocated: Dictionary = {}
var points: int = 1
var level: int = 1
var xp: float = 0.0
var kills: int = 0
var stats: Dictionary = {}
var keys: Dictionary = {}
## Drapeaux de l'aventure (quêtes, rencontres, fin…) : sauvegardés tels quels.
## Valeurs simples uniquement (bool, nombre, texte) pour rester sérialisables en JSON.
var flags: Dictionary = {}


func _ready() -> void:
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


func recompute() -> void:
	var s := {
		"damage": 0.0, "attack_speed": 0.0, "pierce": 0.0, "crit": 0.0, "crit_mult": 0.0,
		"max_hp": 0.0, "regen": 0.0, "move_speed": 0.0, "armor": 0.0, "dash_cd": 0.0,
		"pickup": 0.0, "poison": 0.0, "thorns": 0.0, "lifesteal": 0.0, "area": 0.0,
	}
	keys = {}
	for id in allocated:
		var n: Dictionary = tree.nodes[id]
		if n["key"] != "":
			keys[n["key"]] = true
		var effects: Dictionary = n["effects"]
		for k in effects:
			s[k] += effects[k]

	var damage: float = 12.0 * (1.0 + s["damage"])
	var fire_rate: float = 2.2 * (1.0 + s["attack_speed"])
	var projectiles := 1
	var crit: float = 0.05 + s["crit"]
	var max_hp: float = 100.0 + s["max_hp"]
	var move_speed: float = 230.0 * (1.0 + s["move_speed"])
	var armor: float = s["armor"]
	var armor_cap := 0.75
	var poison: float = s["poison"]
	var thorns: float = s["thorns"]
	var lifesteal: float = s["lifesteal"]

	if has_key("sanguinaire"):
		damage *= 1.4
		max_hp *= 0.8
	if has_key("ecorce_vive"):
		thorns = thorns * 3.0 + 15.0
	if has_key("mycose"):
		poison = poison * 2.0 + 0.15
	if has_key("racine_de_vie"):
		lifesteal += 0.03
	if has_key("rafale"):
		projectiles += 2
		damage *= 0.85
	if has_key("tempete"):
		fire_rate *= 1.5
	if has_key("zenith"):
		crit *= 2.0
	if has_key("lumiere_lente"):
		damage *= 1.6
		fire_rate *= 0.8
	if has_key("coeur_pierre"):
		max_hp *= 1.5
		move_speed *= 0.9
	if has_key("bastion"):
		armor += 0.15
		armor_cap = 0.85

	stats = {
		"damage": damage,
		"fire_rate": fire_rate,
		"projectiles": projectiles,
		"pierce": int(floor(s["pierce"])),
		"crit": minf(crit, 1.0),
		"crit_mult": 1.5 + s["crit_mult"],
		"max_hp": max_hp,
		"regen": 0.5 + s["regen"],
		"move_speed": move_speed,
		"armor": minf(armor, armor_cap),
		"dash_cd": 1.6 * (1.0 - minf(0.6, s["dash_cd"])),
		"pickup": 90.0 * (1.0 + s["pickup"]),
		"poison": poison,
		"thorns": thorns,
		"lifesteal": lifesteal,
		"area": 1.0 + s["area"],
	}
	stats_changed.emit()
