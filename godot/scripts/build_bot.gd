## Robot d'équilibrage : apprend les nœuds d'un build type décrit dans res://data/builds.json.
##   tools/godot.sh --xvfb -- --autotest=build:fouet [--build-time=180] [--build-level=20] [--seed=N]
## À chaque point gagné, le robot apprend le prochain nœud du plus court chemin vers la
## première cible pas encore acquise. Quand les cibles sont épuisées (ou absentes de l'arbre),
## il complète avec le nœud de Ronce disponible le plus proche de la graine. À la fin, il affiche
## les ennemis vaincus par minute, que tools/balance.sh compare entre les builds.
extends RefCounted

const TreePlanner = preload("res://scripts/tree_planner.gd")
const BUILDS_PATH := "res://data/builds.json"
const DEFAULT_TIME := 180.0
## Niveau de départ : le build est mesuré en milieu de partie (assez de points pour ses grappes),
## avec la difficulté qui va avec ce niveau.
const DEFAULT_LEVEL := 20
## Secondes comptées en plus pour chaque mort dans le score (ennemis vaincus par minute).
const DEATH_PENALTY := 10.0

var name := ""
var targets: Array = []
var choices: Dictionary = {}
## Façon de jouer du robot : « distance » (tourne autour de la graine en tirant, par défaut),
## « melee » (va au contact pour le fouet), « tank » (reste au milieu des ennemis pour les épines).
var style := "distance"
var duration := DEFAULT_TIME
var start_level := DEFAULT_LEVEL
var _started := false
var missing: Array = []


## Lit le build demandé sur la ligne de commande, ou renvoie null s'il n'y en a pas.
static func from_cmdline():
	var wanted := ""
	var time := DEFAULT_TIME
	var level := DEFAULT_LEVEL
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest=build:"):
			wanted = a.trim_prefix("--autotest=build:")
		elif a.begins_with("--build-time="):
			time = float(a.trim_prefix("--build-time="))
		elif a.begins_with("--build-level="):
			level = int(a.trim_prefix("--build-level="))
	if wanted == "":
		return null
	var all := load_all()
	if not all.has(wanted):
		push_error("Build inconnu « %s » (dans %s : %s)" % [wanted, BUILDS_PATH, ", ".join(all.keys())])
		return null
	var bot = new()
	bot.name = wanted
	bot.targets = all[wanted].get("targets", [])
	bot.choices = all[wanted].get("choices", {})
	bot.style = all[wanted].get("style", "distance")
	bot.duration = time
	bot.start_level = level
	return bot


static func load_all() -> Dictionary:
	var out := {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(BUILDS_PATH))
	if data is Dictionary:
		for k in data:
			if not str(k).begins_with("_"):
				out[k] = data[k]
	return out


## Dépense les points disponibles selon le build (au premier appel : passe au niveau de départ).
func spend(game) -> void:
	if not _started:
		_started = true
		game.points += maxi(0, start_level - game.level)
		game.level = maxi(game.level, start_level)
	var guard := 0
	while game.points > 0 and guard < 50:
		guard += 1
		var id := _next(game)
		if id < 0 or not game.allocate(id):
			return
		_choose(game, id)


func _next(game) -> int:
	var tree = game.tree
	for uid in targets:
		var target: int = tree.id_for_uid(uid)
		if target < 0:
			if not uid in missing:
				missing.append(uid)
			continue
		if game.allocated.has(target):
			continue
		for id in TreePlanner.shortest_path(tree, game.allocated, target):
			if game.can_allocate(id):
				return id
			break  # chemin bloqué (exclusion, nœud verrouillé) : cible suivante
	# Cibles épuisées : le nœud de Ronce disponible le plus proche de la graine.
	var best := -1
	var best_ring := 999
	for n in tree.nodes:
		if n["branch"] == 0 and n["ring"] < best_ring and game.can_allocate(n["id"]):
			best = n["id"]
			best_ring = n["ring"]
	if best < 0:
		for n in tree.nodes:
			if game.can_allocate(n["id"]):
				return n["id"]
	return best


## Choix des maîtrises et mutations (interface de la tâche A, si elle est présente).
func _choose(game, id: int) -> void:
	var uid: String = game.tree.nodes[id]["uid"]
	var list: Array = game.tree.nodes[id].get("choices", [])
	if list.is_empty() or not game.has_method("set_choice"):
		return
	if not choices.has(uid):
		game.set_choice(id, 0)  # choix non prévu par le build : le premier
		return
	for i in list.size():
		if str(list[i].get("id", i)) == str(choices[uid]):
			game.set_choice(id, i)
			return
	push_warning("Build %s : choix « %s » introuvable sur %s" % [name, choices[uid], uid])


## Déplacement du robot selon le style du build. Renvoie {} pour garder le jeu « à distance » par défaut.
func steer(player, target: Vector2, best_d2: float, max_hp: float) -> Dictionary:
	if style == "distance" or best_d2 == INF:
		return {}
	var d := sqrt(best_d2)
	var low: bool = player.hp < max_hp * 0.35
	var keep := 90.0 if style == "melee" else 35.0
	var mv := Vector2.ZERO
	if low:
		mv = (player.position - target).normalized()
	elif d > keep:
		mv = (target - player.position).normalized()
	return {"move": mv, "aim": target, "dash": low and d < 60.0}


func report(game, elapsed: float, deaths: int) -> String:
	# Une mort coûte DEATH_PENALTY secondes : le robot repart sur place avec toute sa vie
	# (voir main.player_died), donc un build qui meurt souvent ne doit pas en tirer avantage.
	var per_min: float = game.kills / maxf((elapsed + deaths * DEATH_PENALTY) / 60.0, 0.001)
	var line := "BUILD %s : %.0f s, niveau %d, %d nœuds, %d tués, %d morts, %.1f tués/min (mort = 10 s perdues)" % [
		name, elapsed, game.level, game.allocated.size(), game.kills, deaths, per_min]
	if not missing.is_empty():
		line += "\nBUILD %s : %d cibles absentes de l'arbre (%s)" % [name, missing.size(), ", ".join(missing)]
	return line
