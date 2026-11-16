## Objectifs de la tranche (autoload « Objectives ») : une suite d'objectifs principaux qui mène
## du premier nœud à la Mère-Ronce, et quelques objectifs facultatifs. La liste est dans
## res://data/objectives.json (format décrit dans data/README.md).
##
## Les objectifs ne gardent aucun état propre : tout vit dans Game.flags, donc dans la sauvegarde.
## - Game.flags["obj_<id>"] = true : l'objectif est accompli (posé une seule fois, voir complete) ;
## - les conditions lisent des drapeaux que les autres systèmes posent déjà : « ronce_coeur_purifie »,
##   « ronce_boss_vaincu », « sanctuaire_<id> » (sanctuaires ravivés), « autel_<id> » (autels
##   découverts), « secret_<id> », et le compteur « elites_tuees » (tenu ici, voir attach).
## Un système qui préfère annoncer lui-même l'évènement appelle Objectives.complete("<id>").
##
## Pour la carte et la flèche, les sanctuaires et les autels du monde se rangent dans les groupes
## « sanctuaire » et « autel » (nœuds Node2D avec une propriété `id`) ; sans eux, rien n'est dessiné
## et les objectifs qui en dépendent (« needs_group ») sont passés sous silence.
extends Node

## Un objectif vient d'être accompli (identifiant).
signal completed(id: String)
## La liste ou l'état des objectifs a changé (journal, suivi à l'écran).
signal changed

const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")

const CHECK_EVERY := 0.25
const FLAG_PREFIX := "obj_"
## Drapeaux de statistiques de partie gardés pour l'écran de fin.
const STAT_DEATHS := "stat_morts"
const ELITES := "elites_tuees"
const ENDING_SEEN := "fin_ronce_vue"

var main = null
var _timer := 0.0
## Vrai juste après un rattachement : la première vérification rattrape l'état de la partie
## (sauvegarde chargée, drapeaux déjà posés) sans annoncer chaque objectif.
var _catch_up := true
var _last_deaths := 0


func _ready() -> void:
	Game.tree_changed.connect(check)


## Rattache la scène de jeu : sert aux positions des objectifs, aux annonces et aux statistiques.
func attach(m) -> void:
	main = m
	_catch_up = true
	_last_deaths = int(m.deaths)
	if m.has_signal("elite_killed") and not m.elite_killed.is_connected(_on_elite_killed):
		m.elite_killed.connect(_on_elite_killed)
	check()


func detach(m) -> void:
	if main == m:
		main = null


func _on_elite_killed(_enemy = null) -> void:
	Game.flags[ELITES] = int(Game.flags.get(ELITES, 0)) + 1
	check()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_EVERY
	if main != null and is_instance_valid(main):
		# Les morts de cette session s'ajoutent à celles déjà sauvegardées.
		var d := int(main.deaths)
		if d > _last_deaths:
			Game.flags[STAT_DEATHS] = int(Game.flags.get(STAT_DEATHS, 0)) + d - _last_deaths
		_last_deaths = d
	check()


# --- Données ---

func list() -> Array:
	return Content._load("objectives").get("objectives", [])


func get_def(id: String) -> Dictionary:
	for o in list():
		if o["id"] == id:
			return o
	return {}


func is_done(id: String) -> bool:
	return bool(Game.flags.get(FLAG_PREFIX + id, false))


## Un objectif dont le monde n'a pas (encore) le support, comme un sanctuaire, ne s'affiche pas
## comme objectif en cours. Un objectif déjà accompli reste visible.
func available(o: Dictionary) -> bool:
	var g: String = o.get("needs_group", "")
	if g == "" or is_done(o["id"]) or main == null or not is_instance_valid(main):
		return true
	return not main.get_tree().get_nodes_in_group(g).is_empty()


## Objectif principal à suivre : le premier qui n'est pas accompli. {} quand la tranche est finie.
func current() -> Dictionary:
	for o in list():
		if o.get("main", false) and not is_done(o["id"]) and available(o):
			return o
	return {}


func main_done_count() -> int:
	var n := 0
	for o in list():
		if o.get("main", false) and is_done(o["id"]):
			n += 1
	return n


func main_total() -> int:
	var n := 0
	for o in list():
		if o.get("main", false):
			n += 1
	return n


# --- Conditions ---

## [obtenu, demandé] pour un objectif à compteur, [] sinon.
func progress(o: Dictionary) -> Array:
	var c: Dictionary = o.get("condition", {})
	match c.get("type", ""):
		"flag_count":
			return [mini(_count_flags(c), int(c["count"])), int(c["count"])]
		"counter":
			return [mini(int(Game.flags.get(c["flag"], 0)), int(c["count"])), int(c["count"])]
	return []


func _count_flags(c: Dictionary) -> int:
	var n := 0
	var skip: Array = c.get("exclude", [])
	for k in Game.flags:
		var key := str(k)
		if key.begins_with(str(c["prefix"])) and not key in skip and bool(Game.flags[k]):
			n += 1
	return n


func condition_met(o: Dictionary) -> bool:
	var c: Dictionary = o.get("condition", {})
	match c.get("type", ""):
		"nodes":
			return Game.allocated.size() - 1 >= int(c["count"])
		"flag":
			return bool(Game.flags.get(c["flag"], false))
		"flag_count":
			return _count_flags(c) >= int(c["count"])
		"counter":
			return int(Game.flags.get(c["flag"], 0)) >= int(c["count"])
		"keystone":
			var bi: int = Content.tree().get("branches", []).find(c["branch"])
			for id in Game.allocated:
				var n: Dictionary = Game.tree.nodes[id]
				if n["branch"] == bi and n["type"] == "keystone":
					return true
	return false


## Accomplit tous les objectifs dont la condition est remplie. Appelé à intervalle régulier et à
## chaque changement de l'arbre.
func check() -> void:
	# Rattrapage d'une partie chargée, ou aucune scène de jeu rattachée : on pose les drapeaux sans bruit.
	var catch_up := _catch_up or main == null or not is_instance_valid(main)
	_catch_up = false
	var any := false
	for o in list():
		if not is_done(o["id"]) and condition_met(o):
			any = complete(o["id"], catch_up) or any
	if any:
		changed.emit()


## Accomplit un objectif (une seule fois). « silent » : pas d'annonce ni de récompense (rattrapage
## d'une partie chargée). Renvoie vrai si l'objectif vient d'être accompli.
func complete(id: String, silent := false) -> bool:
	var o := get_def(id)
	if o.is_empty() or is_done(id):
		return false
	Game.flags[FLAG_PREFIX + id] = true
	var pts := int(o.get("reward", {}).get("points", 0))
	if not silent:
		if pts > 0:
			if Game.has_method("grant_points"):
				Game.grant_points(pts, "quete")
			else:
				Game.points += pts
				Game.tree_changed.emit()
		if main != null and is_instance_valid(main) and main.get("hud") != null:
			var more: String = ("  (" + o["reward"]["text"] + ")") if pts > 0 else ""
			main.hud.banner("Objectif accompli : %s%s" % [o["title"], more])
			Sfx.play("niveau")
	completed.emit(id)
	changed.emit()
	return true


# --- Position à l'écran et fin ---

## Position dans le monde de la cible d'un objectif, ou null s'il n'en a pas (ou plus).
func target_pos(o: Dictionary):
	if o.is_empty() or main == null or not is_instance_valid(main):
		return null
	var t: Dictionary = o.get("target", {})
	match t.get("type", "none"):
		"seed":
			return Vector2.ZERO
		"heart":
			return main.heart.center if main.heart != null else null
		"arena":
			return main.arena.center if main.arena != null else null
		"group":
			# Le plus proche des sanctuaires (ou autels) pas encore trouvés.
			var best = null
			var best_d := INF
			for n in main.get_tree().get_nodes_in_group(t["group"]):
				if Game.flags.get(str(t.get("done_prefix", "")) + str(n.get("id")), false):
					continue
				var d: float = n.position.distance_squared_to(main.player.position)
				if d < best_d:
					best_d = d
					best = n.position
			return best
	return null


## Morts de toute la partie : celles déjà sauvegardées et celles de cette session pas encore reportées.
func deaths_total() -> int:
	var extra := 0
	if main != null and is_instance_valid(main):
		extra = maxi(0, int(main.deaths) - _last_deaths)
	return int(Game.flags.get(STAT_DEATHS, 0)) + extra


## Vrai quand le boss est vaincu et que la fin n'a pas encore été montrée.
func ending_due() -> bool:
	var flag: String = Content._load("objectives").get("ending_flag", "")
	return flag != "" and bool(Game.flags.get(flag, false)) and not bool(Game.flags.get(ENDING_SEEN, false))
