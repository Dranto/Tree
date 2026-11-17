## État global : arbre de vie, niveau, expérience et statistiques du personnage.
extends Node

signal stats_changed
signal tree_changed
signal leveled_up(level: int)
signal node_allocated(node: Dictionary)
## Points d'arbre gagnés hors des niveaux (boss, Cœur, autel, secret, quête) : voir grant_points.
signal points_granted(n: int, source: String)
## Une greffe vient d'entrer dans l'inventaire (voir give_graft).
signal graft_found(id: String)

const SkillTree = preload("res://scripts/skill_tree.gd")
const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")
const Difficulty = preload("res://scripts/difficulty.gd")

var tree = null
var allocated: Dictionary = {}
var points: int = 1
var level: int = 1
var xp: float = 0.0
var kills: int = 0
var stats: Dictionary = {}
var keys: Dictionary = {}
## Choix faits sur les maîtrises et les mutations : uid du nœud -> identifiant du choix.
var choices: Dictionary = {}
## Greffes posées : uid de l'emplacement -> identifiant de la greffe (data/grafts.json).
var grafts: Dictionary = {}
## Inventaire des greffes possédées (identifiants de data/grafts.json, chacune en un exemplaire),
## qu'elles soient posées dans un emplacement ou non. Sauvegardé depuis la version 3.
var graft_inventory: Array = []
## Greffes tombées au sol et pas encore ramassées (identifiant -> true) : elles ne sont plus tirées.
var grafts_on_ground: Dictionary = {}
## Libellés des sources de points hors niveau (annonce du HUD).
const POINT_SOURCES := {
	"boss": "Boss vaincu", "coeur": "Cœur purifié", "autel": "Autel ravivé",
	"secret": "Secret découvert", "quete": "Objectif accompli",
}
## Tirages des greffes (élites, autels sans greffe fixée) : rejouables avec « --seed ».
var graft_rng := RandomNumberGenerator.new()
## Graine imposée par « -- --seed=N » pour rejouer une partie à l'identique (tests visuels), -1 sinon.
var forced_seed := -1
## Drapeaux de l'aventure (quêtes, rencontres, fin…) : sauvegardés tels quels.
## Valeurs simples uniquement (bool, nombre, texte) pour rester sérialisables en JSON.
var flags: Dictionary = {}
## Moteur d'effets : statistiques, compétences et réactions des nœuds appris (voir effects.gd).
var effects = Effects.new()
## Compétences données sans nœud, pour les essayer (« -- --skills=fouet,racines » ou « --skills=all »).
var test_skills: Dictionary = {}
## Attaque de base imposée sans nœud, pour l'essayer (« -- --attack=fouet,fourche:2,saignement:0.3 ») :
## une forme et des modificateurs (nom:valeur, 1 par défaut). Voir attack.gd.
var test_attack: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			forced_seed = int(arg.get_slice("=", 1))
			seed(forced_seed)
		elif arg.begins_with("--skills="):
			var list := arg.get_slice("=", 1)
			for id in (Content.skills().keys() if list == "all" else Array(list.split(","))):
				test_skills[id] = true
		elif arg.begins_with("--attack="):
			for part in arg.get_slice("=", 1).split(","):
				var name := part.get_slice(":", 0)
				if Content.attack().get("forms", {}).has(name):
					test_attack.append({"attack_form": name, "priority": 99})
				elif Content.attack().get("mods", {}).has(name):
					test_attack.append({"attack_mod": name, "value": float(part.get_slice(":", 1)) if part.contains(":") else 1.0})
	for err in Content.validate(int(SkillTree.RINGS / 4.0)):
		push_error("Données : " + err)
	tree = SkillTree.new()
	tree.build()
	seed_rng(graft_rng, 3)
	reset()


## Remet la progression à zéro (nouvelle partie).
func reset() -> void:
	allocated = {0: true}
	points = 1
	level = 1
	xp = 0.0
	kills = 0
	flags = {}
	choices = {}
	grafts = {}
	graft_inventory = []
	grafts_on_ground = {}
	recompute()
	tree_changed.emit()


# --- Points et greffes gagnés dans le monde ---

## Donne n points d'arbre hors des niveaux. « source » : "boss", "coeur", "autel", "secret" ou
## "quete" (pour l'annonce). « key » (facultatif) rend le don unique : une même clé ne donne
## qu'une fois par partie (drapeau « points_<key> », sauvegardé). Renvoie false si déjà donné.
func grant_points(n: int, source: String, key := "") -> bool:
	if n <= 0:
		return false
	if key != "":
		if flags.get("points_" + key, false):
			return false
		flags["points_" + key] = true
	points += n
	flags["points_hors_niveau"] = int(flags.get("points_hors_niveau", 0)) + n
	points_granted.emit(n, source)
	tree_changed.emit()
	return true


## Libellé d'une source de points (« autel ravivé »…), la source telle quelle si elle est inconnue.
func point_source_label(source: String) -> String:
	return str(POINT_SOURCES.get(source, source))


## Ajoute une greffe à l'inventaire. Renvoie false si elle n'existe pas ou si elle est déjà possédée.
func give_graft(id: String) -> bool:
	grafts_on_ground.erase(id)
	if not Content.grafts().has(id) or graft_inventory.has(id):
		return false
	graft_inventory.append(id)
	graft_found.emit(id)
	tree_changed.emit()
	return true


func has_graft(id: String) -> bool:
	return graft_inventory.has(id)


## Greffes possédées qui ne sont posées dans aucun emplacement, dans l'ordre où elles ont été trouvées.
func free_grafts() -> Array:
	var placed := {}
	for uid in grafts:
		placed[grafts[uid]] = true
	return graft_inventory.filter(func(g): return not placed.has(g))


## Emplacement où une greffe est posée (-1 si elle n'est posée nulle part).
func graft_slot(graft_id: String) -> int:
	for uid in grafts:
		if grafts[uid] == graft_id:
			return tree.id_for_uid(str(uid))
	return -1


## Tire une greffe à donner pour une source (« elite », « autel »…) : une greffe dont « sources »
## contient la source, ni possédée ni déjà tombée au sol. "" s'il ne reste rien à donner.
func roll_graft(source: String) -> String:
	var pool: Array = []
	var all := Content.grafts()
	for id in all:
		var g = all[id]
		if g is Dictionary and source in g.get("sources", []) and not graft_inventory.has(id) and not grafts_on_ground.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	pool.sort()
	return pool[graft_rng.randi() % pool.size()]


## Pose une greffe possédée dans un emplacement (appris ou non). Si elle était déjà posée ailleurs,
## elle y est retirée ; si l'emplacement portait une autre greffe, celle-ci revient dans l'inventaire.
func place_graft(node_id: int, graft_id: String) -> bool:
	if not graft_inventory.has(graft_id):
		return false
	var from := graft_slot(graft_id)
	if from == node_id:
		return true
	if node_id < 0 or node_id >= tree.nodes.size() or tree.nodes[node_id]["type"] != "graft":
		return false
	if from >= 0:
		grafts.erase(tree.nodes[from]["uid"])
	return set_graft(node_id, graft_id)


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


## Expérience pour passer au niveau suivant (courbe dans res://data/difficulty.json, réglée pour
## qu'un niveau prenne à peu près le même temps tout au long de la partie).
func xp_to_next() -> float:
	return Difficulty.xp_to_next(level)


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
	if allocated.has(id) or points <= 0 or lock_reason(id) != "":
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
	# Une mutation oubliée se rechoisit ; une maîtrise garde son dernier choix.
	if tree.nodes[id]["type"] == "mutation":
		choices.erase(tree.nodes[id]["uid"])
	recompute()
	tree_changed.emit()
	return true


# --- Nœuds à règles : flétris, mutations, exclusions, maîtrises, greffes ---

## Raison pour laquelle un nœud ne peut pas être appris, même voisin d'un nœud appris ("" s'il est libre) :
## nœud flétri dont le drapeau n'est pas levé, mutation d'une compétence pas encore acquise,
## nœud incompatible avec un nœud appris. « owned » permet de tester un autre ensemble que la partie.
func lock_reason(id: int, owned = null) -> String:
	var n: Dictionary = tree.nodes[id]
	var flag: String = n["requires_flag"]
	if flag != "" and not flags.get(flag, false):
		var why: String = n["requires_text"]
		return "Couvert de cendre : " + (why if why != "" else "un évènement du monde doit le libérer.")
	if n["mutates"] == "" and not tree.exclusions.has(id):
		return ""
	var set: Dictionary = allocated if owned == null else owned
	if n["mutates"] != "":
		var has := false
		for sid in tree.skill_sources.get(n["mutates"], []):
			if set.has(sid):
				has = true
				break
		if not has:
			return "Demande la compétence « %s »." % Content.skills().get(n["mutates"], {}).get("name", n["mutates"])
	for other in tree.exclusions.get(id, []):
		if set.has(other):
			return "Incompatible avec « %s »." % tree.nodes[other]["name"]
	return ""


## Index du choix fait sur une maîtrise ou une mutation, ou -1 s'il reste à faire.
func choice_index(id: int) -> int:
	var n: Dictionary = tree.nodes[id]
	var list: Array = n["choices"]
	if list.is_empty() or not choices.has(n["uid"]):
		return -1
	var chosen := str(choices[n["uid"]])
	for i in list.size():
		if str(list[i].get("id", i)) == chosen:
			return i
	return -1


## Vrai si le nœud est appris et attend encore son choix.
func needs_choice(id: int) -> bool:
	return allocated.has(id) and not tree.nodes[id]["choices"].is_empty() and choice_index(id) < 0


## Fait (ou change) le choix d'un nœud appris. Une maîtrise se change librement ; une mutation
## est définitive tant que le nœud reste appris.
func set_choice(id: int, index: int) -> bool:
	var n: Dictionary = tree.nodes[id]
	var list: Array = n["choices"]
	if not allocated.has(id) or index < 0 or index >= list.size():
		return false
	var current := choice_index(id)
	if current == index:
		return true
	if n["type"] == "mutation" and current >= 0:
		return false
	choices[n["uid"]] = str(list[index].get("id", index))
	recompute()
	tree_changed.emit()
	return true


## Pose une greffe dans un emplacement de greffe ("" pour la retirer). La greffe n'agit que si
## l'emplacement est appris. Renvoie false si le nœud n'est pas un emplacement ou si la greffe n'existe pas.
func set_graft(node_id: int, graft_id: String) -> bool:
	if node_id < 0 or node_id >= tree.nodes.size():
		return false
	var n: Dictionary = tree.nodes[node_id]
	if n["type"] != "graft":
		return false
	if graft_id == "":
		grafts.erase(n["uid"])
	elif Content.grafts().has(graft_id):
		# Outil bas niveau (tests, galerie) : poser une greffe la fait entrer dans l'inventaire,
		# et une greffe n'est jamais posée à deux endroits.
		for uid in grafts.keys():
			if grafts[uid] == graft_id:
				grafts.erase(uid)
		grafts[n["uid"]] = graft_id
		if not graft_inventory.has(graft_id):
			graft_inventory.append(graft_id)
	else:
		return false
	recompute()
	tree_changed.emit()
	return true


## Identifiant de la greffe posée dans un emplacement ("" s'il est vide).
func graft_of(id: int) -> String:
	return str(grafts.get(tree.nodes[id]["uid"], ""))


## Recharge les choix, les greffes posées et l'inventaire d'une sauvegarde ; ce qui ne correspond
## plus à l'arbre ou aux données est ignoré (une greffe posée reste toujours dans l'inventaire).
func restore_extras(saved_choices, saved_grafts, saved_inventory = []) -> void:
	choices = {}
	grafts = {}
	graft_inventory = []
	if saved_inventory is Array:
		for g in saved_inventory:
			if Content.grafts().has(str(g)) and not graft_inventory.has(str(g)):
				graft_inventory.append(str(g))
	if saved_choices is Dictionary:
		for uid in saved_choices:
			var id: int = tree.id_for_uid(str(uid))
			if id < 0:
				continue
			for i in tree.nodes[id]["choices"].size():
				if str(tree.nodes[id]["choices"][i].get("id", i)) == str(saved_choices[uid]):
					choices[str(uid)] = str(saved_choices[uid])
	if saved_grafts is Dictionary:
		for uid in saved_grafts:
			var id: int = tree.id_for_uid(str(uid))
			var gid := str(saved_grafts[uid])
			if id >= 0 and tree.nodes[id]["type"] == "graft" and Content.grafts().has(gid) and not grafts.values().has(gid):
				grafts[str(uid)] = gid
				if not graft_inventory.has(gid):
					graft_inventory.append(gid)
	recompute()
	tree_changed.emit()


## [nœuds appris, nœuds en tout] d'une grappe, pour l'ensemble « owned » (la partie par défaut).
func cluster_progress(cluster: String, owned = null) -> Array:
	var set: Dictionary = allocated if owned == null else owned
	var ids: Array = tree.clusters.get(cluster, {}).get("nodes", [])
	var have := 0
	for id in ids:
		if set.has(id):
			have += 1
	return [have, ids.size()]


## Nombre de nœuds appris dans une branche (la graine ne compte pas).
func branch_count(bi: int, owned = null) -> int:
	var set: Dictionary = allocated if owned == null else owned
	var count := 0
	for id in set:
		if tree.nodes[id]["branch"] == bi:
			count += 1
	return count


## Tout ce qui donne des effets pour un ensemble de nœuds appris : les nœuds eux-mêmes, le choix
## fait sur chaque maîtrise ou mutation, les greffes posées, les bonus de grappe complète et les
## paliers de résonance de branche. Chaque entrée a la forme {"id", "effects"} attendue par le moteur.
## « graft_override » (uid de l'emplacement -> greffe) remplace les greffes posées, pour un aperçu.
func effect_sources(owned: Dictionary, graft_override = null) -> Array:
	var placed: Dictionary = grafts if graft_override == null else graft_override
	var out: Array = []
	var per_branch := {}
	for id in owned:
		var n: Dictionary = tree.nodes[id]
		out.append(n)
		if n["branch"] >= 0:
			per_branch[n["branch"]] = int(per_branch.get(n["branch"], 0)) + 1
		var i := choice_index(id)
		if i >= 0:
			out.append({"id": "%d:choix" % id, "ring": n["ring"], "effects": n["choices"][i].get("effects", [])})
		if n["type"] == "graft":
			var g = Content.grafts().get(placed.get(n["uid"], ""))
			if g is Dictionary:
				out.append({"id": "%d:greffe:%s" % [id, placed.get(n["uid"], "")], "ring": n["ring"], "effects": g.get("effects", [])})
	for key in tree.clusters:
		var c: Dictionary = tree.clusters[key]
		if c["effects"].is_empty():
			continue
		var complete := true
		for id in c["nodes"]:
			if not owned.has(id):
				complete = false
				break
		if complete:
			out.append({"id": "grappe:" + key, "effects": c["effects"]})
	for bi in per_branch:
		var tiers = SkillTree.BRANCHES[bi].get("resonance", [])
		if not tiers is Array:
			continue
		for t in tiers.size():
			if per_branch[bi] >= int(tiers[t].get("count", 0)):
				out.append({"id": "resonance:%d:%d" % [bi, t], "effects": tiers[t].get("effects", [])})
	return out


## Réglages d'une compétence (data/skills.json) avec les mutations apprises appliquées.
## À lire au moment du lancer : ils changent quand l'arbre change.
func skill(id: String) -> Dictionary:
	return effects.skill_settings(id)


## Forme et modificateurs de l'attaque de base (attack.gd), selon les nœuds appris.
func attack() -> Dictionary:
	return effects.attack_state()


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


## Recalcule les statistiques à partir des effets des nœuds appris, des choix, des greffes,
## des grappes complètes et de la résonance des branches.
## Les valeurs de base et les formules sont dans res://data/stats.json.
func recompute() -> void:
	keys = {}
	for id in allocated:
		var n: Dictionary = tree.nodes[id]
		if n["key"] != "":
			keys[n["key"]] = true
	var sources := effect_sources(allocated)
	if not test_attack.is_empty():
		sources.append({"id": "test_attack", "ring": 99, "effects": test_attack})
	effects.rebuild(sources)
	for k in effects.skills:
		keys[k] = true
	for k in test_skills:
		keys[k] = true
	stats = effects.stats
	stats_changed.emit()
