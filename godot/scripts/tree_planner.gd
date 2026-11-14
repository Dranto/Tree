## Outils de planification de l'Arbre de vie : logique pure, sans dessin.
##
## - plus court chemin depuis les nœuds appris vers un nœud cible (1 point par nœud) ;
## - apprentissage de tout un chemin d'un coup si les points suffisent ;
## - statistiques « après » un choix, simulées avec le moteur d'effets sans toucher à la partie ;
## - annulation du dernier choix (apprendre, oublier, modifier le plan) ;
## - recherche par mot dans les noms, les statistiques et les textes d'effet ;
## - résumé du build ;
## - plan : un chemin tracé sans dépenser de points, gardé dans Game.flags (donc sauvegardé).
##
## L'objet « game » est l'autoload Game (ou tout objet qui expose tree, allocated, points, flags,
## effects, allocate, refund et can_refund). L'interface est dans tree_panels.gd.
extends RefCounted

signal plan_changed

const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")
const SkillTree = preload("res://scripts/skill_tree.gd")

## Drapeau de Game.flags qui porte le plan : les uid des nœuds prévus, séparés par des virgules.
const FLAG := "plan_arbre"
const UNDO_MAX := 50
const KIND_WORDS := {"root": "origine graine", "small": "noeud", "notable": "notable", "keystone": "cle"}
const ACCENTS := {
	"à": "a", "â": "a", "ä": "a", "ç": "c", "é": "e", "è": "e", "ê": "e", "ë": "e", "î": "i", "ï": "i",
	"ô": "o", "ö": "o", "ù": "u", "û": "u", "ü": "u", "œ": "oe", "’": "'",
}

var game
## Nœuds prévus, dans un ordre où chacun touche un nœud appris ou un nœud prévu avant lui.
var plan: Array = []
var _plan_parent: Dictionary = {}
var _stored := ""
var _undo: Array = []
## Nombre de nœuds appris attendu par la pile d'annulation : s'il a changé sans passer par ici
## (chargement d'une partie, nouvelle partie), la pile ne vaut plus rien et elle est vidée.
var _expected := -1
var _haystacks: PackedStringArray = PackedStringArray()


func _init(g) -> void:
	game = g
	sync()


# --- Chemins ---

## Trajet le plus court (en nœuds, donc en points) depuis l'ensemble « owned » jusqu'à « target ».
## Renvoie [ancre déjà acquise, nœud 1, …, target], ou [] si la cible est acquise ou injoignable.
## À nombre de nœuds égal, le trajet le plus court à l'écran est préféré.
static func route(tree, owned: Dictionary, target: int) -> Array:
	if target < 0 or target >= tree.nodes.size() or owned.has(target):
		return []
	var hops := {}
	var geo := {}
	var parent := {}
	var queue: Array = []
	for id in owned:
		hops[id] = 0
		geo[id] = 0.0
		queue.append(id)
	queue.sort()
	var head := 0
	while head < queue.size():
		var u: int = queue[head]
		head += 1
		if hops.has(target) and hops[u] >= hops[target]:
			break
		var pu: Vector2 = tree.nodes[u]["pos"]
		for v in tree.nodes[u]["neighbors"]:
			var g: float = geo[u] + pu.distance_to(tree.nodes[v]["pos"])
			if not hops.has(v):
				hops[v] = hops[u] + 1
				geo[v] = g
				parent[v] = u
				queue.append(v)
			elif hops[v] == hops[u] + 1 and g < geo[v]:
				geo[v] = g
				parent[v] = u
	if not hops.has(target):
		return []
	var out: Array = [target]
	while parent.has(out[0]):
		out.push_front(parent[out[0]])
	return out


## Nœuds à apprendre, dans l'ordre, pour atteindre « target » : le coût en points est leur nombre.
static func shortest_path(tree, owned: Dictionary, target: int) -> Array:
	var r := route(tree, owned, target)
	return r.slice(1) if r.size() > 1 else []


## Ensemble de départ des chemins : les nœuds appris, plus le plan si « with_plan ».
func owned(with_plan := false) -> Dictionary:
	var set: Dictionary = game.allocated.duplicate()
	if with_plan:
		for id in plan:
			set[id] = true
	return set


func route_to(target: int, with_plan := false) -> Array:
	return route(game.tree, owned(with_plan), target)


func path_to(target: int, with_plan := false) -> Array:
	return shortest_path(game.tree, owned(with_plan), target)


# --- Apprendre, oublier, annuler ---

## Vrai si chaque nœud du chemin touche un nœud appris ou le précédent, et si les points suffisent.
func can_learn_path(path: Array) -> bool:
	if path.is_empty() or game.points < path.size():
		return false
	var set: Dictionary = game.allocated.duplicate()
	for id in path:
		if set.has(id) or not _touches(id, set):
			return false
		set[id] = true
	return true


## Apprend tout le chemin d'un coup. Ne change rien si les points ne suffisent pas.
func learn_path(path: Array) -> bool:
	_check_stack()
	if not can_learn_path(path):
		return false
	for id in path:
		game.allocate(id)
	_push({"type": "learn", "ids": path.duplicate()})
	sync()
	return true


## Apprend un nœud, avec le chemin qui y mène s'il n'est pas voisin d'un nœud appris.
func learn(target: int) -> bool:
	return learn_path(path_to(target))


func forget(id: int) -> bool:
	_check_stack()
	if not game.refund(id):
		return false
	_push({"type": "forget", "ids": [id]})
	sync()
	return true


func can_undo() -> bool:
	_check_stack()
	return not _undo.is_empty()


## Phrase qui décrit ce que l'annulation va défaire ("" s'il n'y a rien à annuler).
func undo_label() -> String:
	if not can_undo():
		return ""
	var e: Dictionary = _undo.back()
	var n: int = e.get("ids", []).size()
	match e["type"]:
		"learn":
			return "%d nœud(s) appris" % n
		"forget":
			return "nœud oublié"
	return "modification du plan"


## Défait le dernier choix : rend les points d'un apprentissage, réapprend un nœud oublié,
## ou remet le plan dans son état précédent. Renvoie false s'il n'y a rien à annuler.
func undo() -> bool:
	if not can_undo():
		return false
	var e: Dictionary = _undo.pop_back()
	match e["type"]:
		"learn":
			var ids: Array = e["ids"].duplicate()
			ids.reverse()
			var done: Array = []
			for id in ids:
				if game.refund(id):
					done.append(id)
				else:
					break
			if done.size() != ids.size():
				# Ne devrait pas arriver : on remet ce qui a été défait et on abandonne.
				done.reverse()
				for id in done:
					game.allocate(id)
				_undo.clear()
				_expected = game.allocated.size()
				return false
			if e.has("plan"):
				_set_plan(e["plan"])
		"forget":
			if not game.allocate(e["ids"][0]):
				_undo.clear()
				_expected = game.allocated.size()
				return false
		"plan":
			_set_plan(e["plan"])
	_expected = game.allocated.size()
	sync()
	return true


func _push(entry: Dictionary) -> void:
	_undo.append(entry)
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()
	_expected = game.allocated.size()


func _check_stack() -> void:
	if game.allocated.size() != _expected:
		_undo.clear()
		_expected = game.allocated.size()


func _touches(id: int, set: Dictionary) -> bool:
	for m in game.tree.nodes[id]["neighbors"]:
		if set.has(m):
			return true
	return false


# --- Simulation ---

## Statistiques, compétences et nœuds clés qu'aurait le personnage en ajoutant les nœuds « add »
## et en retirant « remove ». Le calcul passe par un moteur d'effets à part : la partie
## (Game.allocated, Game.stats, Game.points…) n'est pas touchée.
func simulate(add: Array = [], remove: Array = []) -> Dictionary:
	var set: Dictionary = game.allocated.duplicate()
	for id in add:
		set[id] = true
	for id in remove:
		set.erase(id)
	var nodes: Array = []
	var keys := {}
	for id in set:
		var n: Dictionary = game.tree.nodes[id]
		nodes.append(n)
		if n["key"] != "":
			keys[n["key"]] = true
	var engine = Effects.new()
	engine.states = game.effects.states.duplicate()
	engine.rebuild(nodes)
	for k in engine.skills:
		keys[k] = true
	return {"stats": engine.stats, "skills": engine.skills, "keys": keys, "nodes": set.size()}


## Différences de statistiques (avant → après) si l'on apprenait « add » et oubliait « remove ».
func preview(add: Array = [], remove: Array = []) -> Array:
	return diff(game.effects.stats, simulate(add, remove)["stats"])


## Liste des statistiques qui changent entre deux jeux de valeurs, dans l'ordre de stats.json :
## [{"stat", "label", "before", "after", "text": "Dégâts : 12 → 12,6"}, …]
static func diff(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	var defs := Content.stats()
	for name in defs:
		var a := float(before.get(name, 0.0))
		var b := float(after.get(name, 0.0))
		var ta := format_stat(name, a)
		var tb := format_stat(name, b)
		if ta == tb:
			continue
		out.append({
			"stat": name, "label": defs[name].get("label", name), "before": a, "after": b,
			"text": "%s : %s → %s" % [defs[name].get("label", name), ta, tb],
		})
	return out


## Valeur d'une statistique telle qu'on l'affiche (pourcentage, entier ou décimales utiles).
static func format_stat(name: String, v: float) -> String:
	var def: Dictionary = Content.stats().get(name, {})
	if def.get("percent", false):
		return Effects.number(v * 100.0, 1) + " %"
	if def.get("round", "") == "floor":
		return str(int(v))
	return Effects.number(v, 2 if absf(v) < 10.0 else 1)


# --- Recherche ---

## Texte sans majuscules ni accents, pour comparer « epine » et « Épine ».
static func normalize(s: String) -> String:
	var out := s.to_lower()
	for k in ACCENTS:
		out = out.replace(k, ACCENTS[k])
	return out


## Nœuds dont le nom, le type, la branche, une statistique ou un texte d'effet contient
## tous les mots de la recherche. Triés par anneau puis par position autour de la graine.
func search(query: String) -> Array:
	var words := normalize(query).split(" ", false)
	if words.is_empty():
		return []
	_index()
	var out: Array = []
	for id in _haystacks.size():
		var hay := _haystacks[id]
		var ok := true
		for w in words:
			if not hay.contains(w):
				ok = false
				break
		if ok:
			out.append(id)
	return out


func _index() -> void:
	var nodes: Array = game.tree.nodes
	if _haystacks.size() == nodes.size():
		return
	_haystacks = PackedStringArray()
	var defs := Content.stats()
	for n in nodes:
		var parts: Array = [n["name"], KIND_WORDS.get(n["type"], "")]
		if n["branch"] >= 0:
			parts.append(SkillTree.BRANCHES[n["branch"]]["name"])
		parts.append_array(SkillTree.describe(n))
		for e in n["effects"]:
			if e.has("stat"):
				parts.append(defs.get(e["stat"], {}).get("label", ""))
			elif e.has("skill"):
				parts.append(Content.skills().get(e["skill"], {}).get("name", ""))
		_haystacks.append(normalize(" | ".join(parts)))


# --- Résumé du build ---

## Résumé du personnage, avec les nœuds « extra » en plus si l'on veut voir l'effet d'un plan :
## {"nodes", "total", "points",
##  "stats": [{"stat", "label", "value", "base", "changed"}],
##  "skills": [nom], "keystones": [{"name", "branch"}],
##  "branches": [{"name", "color", "count", "total"}]}
func summary(extra: Array = []) -> Dictionary:
	var sim := simulate(extra)
	var defs := Content.stats()
	var base: Dictionary = Effects.new().compute()
	var stats: Array = []
	for name in defs:
		var v := format_stat(name, float(sim["stats"][name]))
		var b := format_stat(name, float(base[name]))
		stats.append({"stat": name, "label": defs[name].get("label", name), "value": v, "base": b, "changed": v != b})
	var skills: Array = []
	for k in Content.skills():
		if sim["skills"].has(k):
			skills.append(Content.skills()[k].get("name", k))
	var set := owned()
	for id in extra:
		set[id] = true
	var branches: Array = []
	for b in SkillTree.BRANCHES:
		branches.append({"name": b["name"], "color": Color(b["color"]), "count": 0, "total": 0})
	var keystones: Array = []
	for n in game.tree.nodes:
		if n["branch"] < 0:
			continue
		branches[n["branch"]]["total"] += 1
		if set.has(n["id"]):
			branches[n["branch"]]["count"] += 1
			if n["type"] == "keystone":
				keystones.append({"name": n["name"], "branch": n["branch"]})
	return {
		"nodes": set.size() - 1, "total": game.tree.nodes.size() - 1, "points": game.points,
		"stats": stats, "skills": skills, "keystones": keystones, "branches": branches,
	}


# --- Plan ---

func plan_has(id: int) -> bool:
	return _plan_parent.has(id)


## Nœud (appris ou prévu avant lui) auquel un nœud du plan se rattache, pour tracer le plan.
func plan_parent(id: int) -> int:
	return int(_plan_parent.get(id, -1))


## Points que demande le plan.
func plan_cost() -> int:
	return plan.size()


## Points qu'il manque pour valider le plan (0 si on peut le valider).
func plan_missing() -> int:
	return maxi(0, plan.size() - int(game.points))


## Ajoute au plan le chemin le plus court vers « target », en partant des nœuds appris et du
## plan existant. Ne dépense rien. Renvoie le nombre de nœuds ajoutés.
func plan_add(target: int) -> int:
	sync()
	var path := path_to(target, true)
	if path.is_empty():
		return 0
	_check_stack()
	_push({"type": "plan", "plan": plan.duplicate()})
	_set_plan(plan + path)
	return path.size()


## Retire un nœud du plan, avec les nœuds prévus qui ne tiennent plus à rien sans lui.
## Renvoie le nombre de nœuds retirés.
func plan_remove(id: int) -> int:
	sync()
	if not plan_has(id):
		return 0
	_check_stack()
	var before := plan.duplicate()
	_push({"type": "plan", "plan": before})
	var rest := before.duplicate()
	rest.erase(id)
	_set_plan(rest)
	return before.size() - plan.size()


func plan_clear() -> void:
	sync()
	if plan.is_empty():
		return
	_check_stack()
	_push({"type": "plan", "plan": plan.duplicate()})
	_set_plan([])


## Apprend tous les nœuds du plan, si les points suffisent. Le plan est alors vidé.
func plan_commit() -> bool:
	sync()
	var path := plan.duplicate()
	if not learn_path(path):
		return false
	_undo.back()["plan"] = path
	return true


## Remet le plan d'aplomb avec la partie : relit Game.flags s'il a changé (chargement, nouvelle
## partie), retire les nœuds appris entre-temps, ceux qui n'existent plus et ceux qui ne sont
## plus reliés. À appeler quand l'arbre change.
func sync() -> void:
	var stored := str(game.flags.get(FLAG, ""))
	var wanted: Array = plan
	if stored != _stored:
		wanted = []
		for uid in stored.split(",", false):
			var id: int = game.tree.id_for_uid(uid)
			if id >= 0:
				wanted.append(id)
	_set_plan(wanted)


## Ordonne le plan depuis les nœuds appris, écarte ce qui n'est pas relié, et l'écrit dans Game.flags.
func _set_plan(wanted: Array) -> void:
	var todo := {}
	for id in wanted:
		if not game.allocated.has(id):
			todo[id] = true
	var ordered: Array = []
	var parents := {}
	# Parcours en largeur depuis les nœuds appris, limité aux nœuds voulus.
	var queue: Array = game.allocated.keys()
	queue.sort()
	var head := 0
	while head < queue.size() and not todo.is_empty():
		var u: int = queue[head]
		head += 1
		for v in game.tree.nodes[u]["neighbors"]:
			if todo.has(v):
				todo.erase(v)
				parents[v] = u
				ordered.append(v)
				queue.append(v)
	var changed := ordered != plan
	plan = ordered
	_plan_parent = parents
	var uids := PackedStringArray()
	for id in plan:
		uids.append(game.tree.nodes[id]["uid"])
	_stored = ",".join(uids)
	if _stored == "":
		game.flags.erase(FLAG)
	else:
		game.flags[FLAG] = _stored
	if changed:
		plan_changed.emit()
