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
## Le build actif vient de changer (switch_build) : index de l'emplacement chargé.
signal build_switched(index: int)
## Un nouveau cycle du New Game+ commence (jalon 14) : le joueur a touché le fruit de la graine.
## Émis une fois la scène de jeu rechargée et prête, Game.cycle déjà au nouveau numéro (voir cycles.gd).
signal cycle_started(cycle: int)

const SkillTree = preload("res://scripts/skill_tree.gd")
const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")
const Difficulty = preload("res://scripts/difficulty.gd")
const Regions = preload("res://scripts/regions.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Demo = preload("res://scripts/demo.gd")

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
## Couronne de greffes, indépendante de l'arbre : une case par emplacement ouvert, l'identifiant de
## la greffe posée (data/grafts.json) ou "" si l'emplacement est vide. Une greffe posée agit tout de
## suite. Le nombre d'emplacements grandit avec l'aventure (crown_size, data/crown.json).
var crown: Array = []
## Inventaire des greffes possédées (identifiants de data/grafts.json, chacune en un exemplaire),
## qu'elles soient posées dans la couronne ou non. Sauvegardé depuis la version 3.
var graft_inventory: Array = []
## Greffes tombées au sol et pas encore ramassées (identifiant -> true) : elles ne sont plus tirées.
var grafts_on_ground: Dictionary = {}
## Builds enregistrés (jalon 11 I) : Content.respec()["slots"] emplacements. Chacun est vide ({})
## ou {"name", "allocated": [uid], "choices": {uid: choix}, "crown": [greffe ou ""], "plan": "uid,uid"}.
## Le build actif est l'état vivant (allocated, choices, crown, plan) : son emplacement n'est mis à
## jour qu'au moment de basculer ou de sauvegarder (store_active_build). Les points, l'inventaire de
## greffes et les drapeaux sont communs à tous les builds.
var builds: Array = []
var active_build := 0
## Le joueur se tient dans le cercle d'un sanctuaire ravivé (posé par sanctuary.gd) : oublier et
## changer de build y sont gratuits (data/respec.json, « free_at_sanctuary »).
var at_sanctuary := false
## Cycle du New Game+ (jalon 14) : 1 = première aventure. Sauvegardé ; reset() le remet à 1
## (nouvelle partie). Lire plutôt Cycles.current(), qui suit aussi « -- --cycle=N ».
var cycle := 1
## Emplacements de couronne gagnés aux cycles précédents (jalon 14) : la couronne est gardée d'un
## cycle à l'autre alors que les drapeaux qui l'ont ouverte (Cœurs, boss, finale) sont remis à zéro.
## Sauvegardé depuis la version 9.
var crown_kept := 0
## Libellés des sources de points hors niveau (annonce du HUD).
const POINT_SOURCES := {
	"boss": "Boss vaincu", "coeur": "Cœur purifié", "autel": "Autel ravivé", # i18n
	"secret": "Secret découvert", "quete": "Objectif accompli", # i18n
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
	# Police du jeu pour tous les textes, même ceux dessinés sans thème (voir ui_theme.gd).
	UiTheme.install()
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
	for err in Content.validate(SkillTree.KEYSTONES):
		push_error("Données : " + err)
	tree = SkillTree.new()
	tree.build()
	seed_rng(graft_rng, 3)
	reset()


## Vrai dans la démo : preset d'export avec la fonctionnalité « demo » (tools/export.sh démo-*),
## ou « -- --demo » pour la tester depuis l'éditeur et dans les tests. Seul accès à connaître ;
## ce que la démo ouvre est dans demo.gd et data/demo.json.
func is_demo() -> bool:
	return Demo.active()


## Remet la progression à zéro (nouvelle partie).
func reset() -> void:
	allocated = {0: true}
	points = 1
	level = 1
	xp = 0.0
	kills = 0
	flags = {}
	choices = {}
	crown = []
	graft_inventory = []
	grafts_on_ground = {}
	builds = []
	active_build = 0
	at_sanctuary = false
	cycle = 1
	crown_kept = 0
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
	return Loc.t(str(POINT_SOURCES.get(source, source)))


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


## Greffes possédées qui ne sont pas posées dans la couronne, dans l'ordre où elles ont été trouvées.
func free_grafts() -> Array:
	return graft_inventory.filter(func(g): return not crown.has(g))


## Greffes posées dans la couronne, dans l'ordre des emplacements.
func placed_grafts() -> Array:
	return crown.filter(func(g): return g != "")


## Emplacement de la couronne où une greffe est posée (-1 si elle n'est posée nulle part).
func graft_slot(graft_id: String) -> int:
	return crown.find(graft_id) if graft_id != "" else -1


## Nombre d'emplacements ouverts de la couronne : ceux du départ, plus un par région dont tous les
## Cœurs sont purifiés, un par boss vaincu et un pour la finale (réglages : data/crown.json).
## Se lit dans les drapeaux de l'aventure : rien de plus à sauvegarder.
func crown_size(f = null) -> int:
	var fl: Dictionary = flags if f == null else f
	var c := Content.crown()
	var n := int(c.get("start", 2))
	for id in Regions.ids():
		if fl.get(Regions.heart_flag(id), false):
			n += int(c.get("per_region_hearts", 1))
		if fl.get(Regions.boss_flag(id), false):
			n += int(c.get("per_boss", 1))
	if fl.get("finale_vaincue", false):
		n += int(c.get("finale", 0))
	# New Game+ : la couronne gagnée aux cycles d'avant reste ouverte (jalon 14), plus les
	# emplacements que le cycle donne (data/cycles.json › crown, greffes de cycle).
	if f == null:
		n = maxi(n, crown_kept) + int(Cycles.value("crown", 0))
	return clampi(n, 0, int(c.get("max", 16)))


## Nombre d'emplacements que la couronne peut avoir en fin d'aventure (les autres sont encore fermés).
func crown_max() -> int:
	var c := Content.crown()
	var n := int(c.get("start", 2)) + Regions.ids().size() * (int(c.get("per_region_hearts", 1)) + int(c.get("per_boss", 1))) + int(c.get("finale", 0))
	return clampi(n, 0, int(c.get("max", 16)))


## Ajuste la couronne au nombre d'emplacements ouverts (elle ne fait que grandir en jeu).
func _fit_crown() -> void:
	var n := crown_size()
	while crown.size() < n:
		crown.append("")
	# Moins d'emplacements que de cases (outils de test) : les greffes en trop reviennent dans l'inventaire.
	if crown.size() > n:
		crown.resize(n)


## Premier emplacement ouvert et vide de la couronne (-1 s'il n'y en a pas).
func first_free_slot() -> int:
	_fit_crown()
	return crown.find("")


## Identifiant de la greffe posée dans un emplacement de la couronne ("" s'il est vide ou fermé).
func graft_of(slot: int) -> String:
	_fit_crown()
	return str(crown[slot]) if slot >= 0 and slot < crown.size() else ""


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


## Pose une greffe possédée dans un emplacement ouvert de la couronne. Si elle était déjà posée
## ailleurs, elle change de place ; si l'emplacement portait une autre greffe, celle-ci revient dans
## l'inventaire. Renvoie false si la greffe n'est pas possédée ou si l'emplacement n'est pas ouvert.
func place_graft(slot: int, graft_id: String) -> bool:
	if not graft_inventory.has(graft_id):
		return false
	return set_graft(slot, graft_id)


## Retire une greffe de la couronne (elle reste dans l'inventaire). Renvoie false si elle n'était pas posée.
func unplace_graft(graft_id: String) -> bool:
	var slot := graft_slot(graft_id)
	return slot >= 0 and set_graft(slot, "")


# --- Builds enregistrés ---

## Nombre d'emplacements de build (3 à 5, data/respec.json).
func build_slots() -> int:
	return clampi(int(Content.respec().get("slots", 4)), 1, 8)


func _fit_builds() -> void:
	while builds.size() < build_slots():
		builds.append({})
	if builds.size() > build_slots():
		builds.resize(build_slots())
	active_build = clampi(active_build, 0, builds.size() - 1)


## Nom affiché d'un emplacement (« Build 2 » tant qu'on ne l'a pas renommé).
func build_name(i: int) -> String:
	_fit_builds()
	if i < 0 or i >= builds.size():
		return ""
	var nm := str(builds[i].get("name", "")).strip_edges()
	return nm if nm != "" else Loc.t("Build %d") % (i + 1)


## L'état vivant, sous la forme d'un emplacement de build.
func capture_build() -> Dictionary:
	_fit_builds()
	var out := {
		"allocated": allocated_uids(), "choices": choices.duplicate(), "crown": crown.duplicate(),
		"plan": str(flags.get("plan_arbre", "")),
	}
	var nm := str(builds[active_build].get("name", ""))
	if nm != "":
		out["name"] = nm
	return out


## Recopie l'état vivant dans l'emplacement du build actif (avant de basculer ou de sauvegarder).
func store_active_build() -> void:
	_fit_builds()
	builds[active_build] = capture_build()


## Vrai si l'emplacement n'a jamais reçu de build.
func build_empty(i: int) -> bool:
	_fit_builds()
	return i != active_build and (i < 0 or i >= builds.size() or not builds[i].has("allocated"))


## Résumé d'un emplacement pour le panneau : {"name", "active", "empty", "nodes", "planned", "grafts"}.
func build_info(i: int) -> Dictionary:
	_fit_builds()
	var b: Dictionary = capture_build() if i == active_build else builds[i]
	var planned: int = str(b.get("plan", "")).split(",", false).size()
	return {
		"name": build_name(i), "active": i == active_build, "empty": build_empty(i),
		"nodes": (b.get("allocated", []) as Array).size(), "planned": planned,
		"grafts": (b.get("crown", []) as Array).filter(func(g): return str(g) != "").size(),
	}


func rename_build(i: int, nm: String) -> void:
	_fit_builds()
	if i < 0 or i >= builds.size():
		return
	nm = nm.strip_edges().left(24)
	if i == active_build and not builds[i].has("allocated"):
		builds[i] = capture_build()
	if nm == "" or nm == Loc.t("Build %d") % (i + 1) or nm == "Build %d" % (i + 1): # i18n: non (nom par défaut en français)
		builds[i].erase("name")
	else:
		builds[i]["name"] = nm
	tree_changed.emit()


## Enregistre le build actif (avec son plan) dans un autre emplacement, sous le nom de celui-ci.
func copy_build_to(i: int) -> bool:
	_fit_builds()
	if i < 0 or i >= builds.size() or i == active_build:
		return false
	var b := capture_build()
	b.erase("name")
	if builds[i].has("name"):
		b["name"] = builds[i]["name"]
	builds[i] = b
	tree_changed.emit()
	return true


## Vide un emplacement qui n'est pas le build actif.
func clear_build(i: int) -> bool:
	_fit_builds()
	if i < 0 or i >= builds.size() or i == active_build:
		return false
	builds[i] = {"name": builds[i]["name"]} if builds[i].has("name") else {}
	tree_changed.emit()
	return true


## Essence que coûte la bascule vers l'emplacement i : rien au sanctuaire ; ailleurs, ce que
## coûterait l'oubli des nœuds appris qui ne sont pas dans ce build.
func switch_cost(i: int) -> int:
	_fit_builds()
	if i == active_build or i < 0 or i >= builds.size():
		return 0
	var keep := {}
	for uid in builds[i].get("allocated", []):
		keep[str(uid)] = true
	var cost := 0
	for id in allocated:
		if id != 0 and not keep.has(tree.nodes[id]["uid"]):
			cost += refund_cost(id)
	return cost


## Bascule vers le build de l'emplacement i (un emplacement vide : un build neuf, sans nœud appris,
## qui garde la couronne). Les points sont communs : si le build en demande plus que la partie n'en a,
## les nœuds en trop (les plus loin de la graine) passent dans son plan. Renvoie false si l'essence
## ne suffit pas (switch_cost).
func switch_build(i: int) -> bool:
	_fit_builds()
	if i < 0 or i >= builds.size() or i == active_build:
		return false
	var cost := switch_cost(i)
	if cost > essence():
		return false
	store_active_build()
	xp = maxf(0.0, xp - cost)
	var total := points + allocated.size() - 1
	var target: Dictionary = builds[i]
	var fresh := not target.has("allocated")
	var wanted := {}
	for uid in target.get("allocated", []):
		var id: int = tree.id_for_uid(str(uid))
		if id > 0:
			wanted[id] = true
	var planned: Array = []
	for uid in str(target.get("plan", "")).split(",", false):
		var id: int = tree.id_for_uid(uid)
		if id > 0 and not wanted.has(id):
			planned.append(id)
	# Parcours depuis la graine, limité au build : les nœuds proches d'abord, tant qu'il reste des points.
	var kept := {0: true}
	var over: Array = []
	var queue: Array = [0]
	var head := 0
	while head < queue.size():
		var u: int = queue[head]
		head += 1
		var next: Array = tree.nodes[u]["neighbors"].duplicate()
		next.sort()
		for v in next:
			if wanted.has(v) and not kept.has(v) and not over.has(v):
				if kept.size() - 1 < total:
					kept[v] = true
				else:
					over.append(v)
				queue.append(v)
	allocated = kept
	points = total - (kept.size() - 1)
	active_build = i
	var plan_uids := PackedStringArray()
	for id in over + planned:
		plan_uids.append(tree.nodes[id]["uid"])
	if plan_uids.is_empty():
		flags.erase("plan_arbre")
	else:
		flags["plan_arbre"] = ",".join(plan_uids)
	var keep_crown: Array = crown.duplicate()
	restore_extras(target.get("choices", {}), keep_crown if fresh else target.get("crown", []), graft_inventory.duplicate())
	builds[i] = capture_build()
	build_switched.emit(i)
	return true


## Recharge les builds d'une sauvegarde (après les nœuds, les choix et la couronne du build actif).
func restore_builds(saved, active) -> void:
	builds = []
	if saved is Array:
		for b in saved:
			builds.append(b.duplicate(true) if b is Dictionary else {})
	active_build = int(active) if (active is int or active is float) else 0
	_fit_builds()
	builds[active_build] = capture_build()


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
	# Une mutation dont la compétence n'est plus apprise (petit nœud d'une ancienne sauvegarde devenu
	# mutation au jalon 11) est rendue : elle se reprendra avec sa compétence.
	for id in wanted.keys():
		var sid: String = tree.nodes[id]["mutates"]
		if sid != "" and not tree.skill_sources.get(sid, []).any(func(s): return wanted.has(s)):
			wanted.erase(id)
			refunded += 1
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


## Essence (expérience du niveau en cours) que coûte l'oubli d'un nœud : 0 près de la graine
## (anneaux 0 à « free_rings ») et au sanctuaire, puis une part de la barre du niveau qui grandit
## avec l'anneau (data/respec.json). « anywhere » : le coût hors sanctuaire, même au sanctuaire.
func refund_cost(id: int, anywhere := false) -> int:
	if id <= 0 or id >= tree.nodes.size():
		return 0
	var r := Content.respec()
	if not anywhere and at_sanctuary and bool(r.get("free_at_sanctuary", true)):
		return 0
	var beyond := int(tree.nodes[id]["ring"]) - int(r.get("free_rings", 3))
	if beyond <= 0:
		return 0
	var part := minf(float(r.get("cost_per_ring", 0.04)) * beyond, float(r.get("cost_max", 0.5)))
	return ceili(part * xp_to_next())


## Essence disponible pour oublier : l'expérience du niveau en cours (on ne perd jamais un niveau).
func essence() -> int:
	return int(floor(xp))


## Oublie un nœud et rend son point. Hors de la graine et du sanctuaire, il faut payer refund_cost en
## essence (refusé s'il n'y en a pas assez). « free » : sans payer (annulation d'un apprentissage).
func refund(id: int, free := false) -> bool:
	if not can_refund(id):
		return false
	var cost := 0 if free else refund_cost(id)
	if cost > essence():
		return false
	xp = maxf(0.0, xp - cost)
	allocated.erase(id)
	points += 1
	# Une mutation oubliée se rechoisit ; une maîtrise garde son dernier choix.
	if tree.nodes[id]["type"] == "mutation":
		choices.erase(tree.nodes[id]["uid"])
	recompute()
	tree_changed.emit()
	return true


# --- Nœuds à règles : flétris, mutations, exclusions, maîtrises, greffes ---

## Raison donnée en démo pour un nœud que seul le jeu complet ouvre (une ligne, voir demo.gd).
const DEMO_LOCK := "Dans le jeu complet." # i18n

## Raison pour laquelle un nœud ne peut pas être appris, même voisin d'un nœud appris ("" s'il est libre) :
## nœud flétri dont le drapeau n'est pas levé, mutation d'une compétence pas encore acquise,
## nœud incompatible avec un nœud appris. « owned » permet de tester un autre ensemble que la partie.
func lock_reason(id: int, owned = null) -> String:
	var n: Dictionary = tree.nodes[id]
	if Demo.node_closed(n) and not allocated.has(id):
		return Loc.t(DEMO_LOCK)
	var flag: String = n["requires_flag"]
	if flag != "" and not flags.get(flag, false):
		var why: String = n["requires_text"]
		return Loc.t("Couvert de cendre : %s") % (Loc.data(why) if why != "" else Loc.t("un évènement du monde doit le libérer."))
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
			return Loc.t("Demande la compétence « %s ».") % Loc.data(str(Content.skills().get(n["mutates"], {}).get("name", n["mutates"])))
	for other in tree.exclusions.get(id, []):
		if set.has(other):
			return Loc.t("Incompatible avec « %s ».") % SkillTree.node_name(tree.nodes[other])
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


## Pose une greffe dans un emplacement ouvert de la couronne ("" pour le vider). Outil bas niveau
## (tests, galerie) : une greffe posée entre dans l'inventaire si besoin, et n'est jamais posée à
## deux endroits. Renvoie false si l'emplacement n'est pas ouvert ou si la greffe n'existe pas.
func set_graft(slot: int, graft_id: String) -> bool:
	_fit_crown()
	if slot < 0 or slot >= crown.size():
		return false
	if graft_id != "" and not Content.grafts().has(graft_id):
		return false
	if graft_id != "":
		var from := crown.find(graft_id)
		if from == slot:
			return true
		if from >= 0:
			crown[from] = ""
		if not graft_inventory.has(graft_id):
			graft_inventory.append(graft_id)
	crown[slot] = graft_id
	recompute()
	tree_changed.emit()
	return true


## Recharge les choix, la couronne et l'inventaire d'une sauvegarde ; ce qui ne correspond plus à
## l'arbre ou aux données est ignoré (une greffe posée reste toujours dans l'inventaire). Les drapeaux
## doivent être déjà rechargés : ils disent combien d'emplacements la couronne a.
func restore_extras(saved_choices, saved_crown, saved_inventory = []) -> void:
	choices = {}
	crown = []
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
	_fit_crown()
	if saved_crown is Array:
		for i in mini(saved_crown.size(), crown.size()):
			var gid := str(saved_crown[i])
			if Content.grafts().has(gid) and not crown.has(gid):
				crown[i] = gid
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


## Nombre de nœuds appris dans une branche (la graine ne compte pas). Un nœud de frontière hybride
## compte pour ses deux branches.
func branch_count(bi: int, owned = null) -> int:
	var set: Dictionary = allocated if owned == null else owned
	var count := 0
	for id in set:
		if SkillTree.in_branch(tree.nodes[id], bi):
			count += 1
	return count


## Tout ce qui donne des effets pour un ensemble de nœuds appris : les nœuds eux-mêmes, le choix
## fait sur chaque maîtrise ou mutation, les greffes de la couronne, les bonus de grappe complète et
## les paliers de résonance de branche. Chaque entrée a la forme {"id", "effects"} attendue par le moteur.
## « crown_override » (liste de greffes) remplace la couronne, pour un aperçu.
func effect_sources(owned: Dictionary, crown_override = null) -> Array:
	var placed: Array = crown if crown_override == null else crown_override
	var out: Array = []
	for i in placed.size():
		var g = Content.grafts().get(str(placed[i]))
		if g is Dictionary:
			out.append({"id": "greffe:%d:%s" % [i, placed[i]], "ring": 0, "effects": g.get("effects", [])})
	var per_branch := {}
	for id in owned:
		var n: Dictionary = tree.nodes[id]
		out.append(n)
		if n["branch"] >= 0:
			per_branch[n["branch"]] = int(per_branch.get(n["branch"], 0)) + 1
		# Frontière hybride : le nœud compte aussi pour l'autre branche.
		if int(n.get("border", -1)) >= 0:
			per_branch[n["border"]] = int(per_branch.get(n["border"], 0)) + 1
		var i := choice_index(id)
		if i >= 0:
			out.append({"id": "%d:choix" % id, "ring": n["ring"], "effects": n["choices"][i].get("effects", [])})
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
