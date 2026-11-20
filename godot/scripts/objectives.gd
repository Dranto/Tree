## Objectifs de l'aventure (autoload « Objectives ») : une suite d'objectifs principaux qui mène
## du premier nœud au boss de chaque région, et quelques objectifs facultatifs. La liste est dans
## res://data/objectives.json (format décrit dans data/README.md) ; un objectif propre à une région
## porte son identifiant (« region »).
##
## Les objectifs ne gardent aucun état propre : tout vit dans Game.flags, donc dans la sauvegarde.
## - Game.flags["obj_<id>"] = true : l'objectif est accompli (posé une seule fois, voir complete) ;
## - les conditions lisent des drapeaux que les autres systèmes posent déjà : « <région>_coeur_purifie »,
##   « <région>_boss_vaincu », « sanctuaire_<id> » (sanctuaires ravivés), « autel_<id> » (autels
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
## Épilogue de l'aventure déjà montré (après la finale, voir epilogue.gd). La séquence « région
## purifiée » de chaque région a son drapeau : Regions.ending_flag(id) (« <région>_fin_vue »).
const ENDING_SEEN := "fin_aventure_vue"
## Finale (data/finale.json, finale_arena.gd) : ouverte quand toutes les régions sont purifiées,
## vaincue quand la Flétrissure tombe.
const FINALE_OPEN := "finale_ouverte"
const FINALE_WON := "finale_vaincue"

var main = null
var _timer := 0.0
## Vrai juste après un rattachement : la première vérification rattrape l'état de la partie
## (sauvegarde chargée, drapeaux déjà posés) sans annoncer chaque objectif.
var _catch_up := true
var _last_deaths := 0
## Dernière région suivie (followed_region), pour prévenir le cadre quand elle change.
var _followed := ""
var _here := "?"


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


## Une mort du joueur, notée tout de suite dans les drapeaux : une partie quittée juste après
## la garde dans ses statistiques.
func note_death() -> void:
	Game.flags[STAT_DEATHS] = int(Game.flags.get(STAT_DEATHS, 0)) + 1
	if main != null and is_instance_valid(main):
		_last_deaths = int(main.deaths)


func _on_elite_killed(_enemy = null) -> void:
	Game.flags[ELITES] = int(Game.flags.get(ELITES, 0)) + 1
	check()


func _process(delta: float) -> void:
	# Le joueur passe d'une région à l'autre : le cadre et le journal changent tout de suite
	# (la région sous le joueur est lue à chaque image, la suite seulement quand elle change).
	if main != null and is_instance_valid(main) and main.player != null:
		var here := Regions.region_at(main.player.position)
		if here != _here:
			_here = here
			var r := followed_region()
			if r != _followed:
				_followed = r
				changed.emit()
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
	# « needs_flag » : l'objectif n'existe pas tant que ce drapeau n'est pas posé (la finale).
	var nf := str(o.get("needs_flag", ""))
	if nf != "" and not is_done(o["id"]) and not bool(Game.flags.get(nf, false)):
		return false
	var g: String = o.get("needs_group", "")
	if g == "" or is_done(o["id"]) or main == null or not is_instance_valid(main):
		return true
	return not main.get_tree().get_nodes_in_group(g).is_empty()


## Objectif principal à suivre : le premier qui n'est pas accompli ni sauté (voir skipped). Les
## petites étapes du début se font dans n'importe quel ordre ; mais un joueur qui purifie le Cœur
## avant d'avoir ravivé un sanctuaire n'est pas renvoyé en arrière : les étapes sautées restent
## ouvertes dans le journal et s'accomplissent encore si leur condition se remplit. Les régions se
## suivent dans l'ordre de la liste. {} quand l'aventure est finie.
## « region » : seulement les objectifs de cette région et les objectifs communs (robots).
func current(region := "") -> Dictionary:
	var mains := main_list()
	for i in mains.size():
		var o: Dictionary = mains[i]
		if region != "" and not str(o.get("region", "")) in ["", region]:
			continue
		if not is_done(o["id"]) and available(o) and not _skipped_at(mains, i):
			return o
	return {}


## Région dont le joueur suit les objectifs : celle où il se tient, si elle a encore un objectif
## principal ouvert ; sinon celle de l'objectif en cours de la suite. "" quand tout est fait.
func followed_region() -> String:
	if main != null and is_instance_valid(main) and main.player != null:
		var here := Regions.region_at(main.player.position)
		if here != "" and not current(here).is_empty() and str(current(here).get("region", "")) == here:
			return here
	var o := current()
	if not o.is_empty() and str(o.get("region", "")) != "":
		return str(o["region"])
	return Regions.ids()[0] if not Regions.ids().is_empty() and not o.is_empty() else ""


## Objectif affiché (cadre, flèche, carte, journal) : celui de la région suivie (followed_region).
## Dans le roncier, celui de Ronce ; sur les plateaux, celui de Vent, même si Ronce n'est pas finie.
func followed() -> Dictionary:
	var r := followed_region()
	return current(r) if r != "" else current()


## Objectifs principaux, dans l'ordre de la suite.
func main_list() -> Array:
	return list().filter(func(o): return o.get("main", false))


## Indice de la dernière grande étape accomplie dans la suite, -1 s'il n'y en a pas.
func _last_main_done(mains: Array) -> int:
	var last := -1
	for i in mains.size():
		if mains[i].get("milestone", false) and is_done(mains[i]["id"]):
			last = i
	return last


## Objectif principal pas accompli alors qu'une grande étape plus loin dans la suite l'est déjà :
## une étape de la même région, ou de n'importe quelle région pour un objectif commun.
func skipped(o: Dictionary) -> bool:
	if not o.get("main", false) or is_done(o["id"]):
		return false
	var mains := main_list()
	var i := mains.find(o)
	return i >= 0 and _skipped_at(mains, i)


func _skipped_at(mains: Array, i: int) -> bool:
	var reg := str(mains[i].get("region", ""))
	for j in range(i + 1, mains.size()):
		var m: Dictionary = mains[j]
		if m.get("milestone", false) and is_done(m["id"]) and (reg == "" or str(m.get("region", "")) == reg):
			return true
	return false


## Objectifs d'une région (ou communs, avec ""), dans l'ordre de la liste.
func for_region(region: String) -> Array:
	return list().filter(func(o): return str(o.get("region", "")) == region)


## Rang (à partir de 1) de l'objectif principal en cours dans la suite, 0 quand tout est fait.
## « region » : rang dans la suite de cette région (ses objectifs et les communs).
func current_rank(region := "") -> int:
	var o := current(region)
	return 0 if o.is_empty() else _mains_of(region).find(o) + 1


## Objectifs principaux d'une région et communs ("" : tous).
func _mains_of(region: String) -> Array:
	if region == "":
		return main_list()
	return main_list().filter(func(o): return str(o.get("region", "")) in ["", region])


func main_done_count(region := "") -> int:
	return _mains_of(region).filter(func(o): return is_done(o["id"])).size()


func main_total(region := "") -> int:
	return _mains_of(region).size()


# --- Conditions ---

## [obtenu, demandé] pour un objectif à compteur, [] sinon.
func progress(o: Dictionary) -> Array:
	var c: Dictionary = o.get("condition", {})
	match c.get("type", ""):
		"flag_count":
			return [mini(_count_flags(c, o), int(c["count"])), int(c["count"])]
		"counter":
			return [mini(int(Game.flags.get(c["flag"], 0)), int(c["count"])), int(c["count"])]
	return []


func _count_flags(c: Dictionary, o := {}) -> int:
	var n := 0
	var skip: Array = c.get("exclude", [])
	# « region_only » : sans les lieux (sanctuaires, autels, secrets) des autres régions.
	var others = _other_places(str(o.get("region", ""))) if c.get("region_only", false) else null
	for k in Game.flags:
		var key := str(k)
		# « autel_<id>_vu », « secret_<id>_vu » : aperçu seulement, pas encore ravivé ni trouvé.
		if key.ends_with("_vu"):
			continue
		if key.begins_with(str(c["prefix"])) and not key in skip and bool(Game.flags[k]):
			if others != null and key.substr(str(c["prefix"]).length()) in others:
				continue
			n += 1
	return n


## Identifiants des lieux (sanctuaires, autels, secrets) des régions autres que celle-ci.
func _other_places(region: String) -> Dictionary:
	var out := {}
	for reg in Regions.ids():
		if reg == region:
			continue
		var d := Regions.def(reg)
		for kind in ["sanctuaries", "altars", "secrets"]:
			for p in d.get(kind, []):
				out[str(p.get("id", ""))] = true
	return out


func condition_met(o: Dictionary) -> bool:
	var c: Dictionary = o.get("condition", {})
	match c.get("type", ""):
		"nodes":
			return Game.allocated.size() - 1 >= int(c["count"])
		"flag":
			return bool(Game.flags.get(c["flag"], false))
		"flag_count":
			return _count_flags(c, o) >= int(c["count"])
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
		"finale":
			# La brèche au pied de la graine ; une fois descendu, le boss au centre de l'arène.
			var f = main.get("finale")
			if f == null:
				return Vector2.ZERO
			return f.center if f.holds(main.player.position) else f.descent_point()
		"heart":
			var h = main.hearts.get(str(o.get("region", "")), main.heart) if "hearts" in main else main.heart
			return h.center if h != null else null
		"arena":
			var a = main.arenas.get(str(o.get("region", "")), main.arena) if "arenas" in main else main.arena
			return a.center if a != null else null
		"group":
			# Le plus proche des sanctuaires (ou autels) pas encore trouvés, dans la région de
			# l'objectif s'il en a une.
			var best = null
			var best_d := INF
			var reg := str(o.get("region", ""))
			for n in main.get_tree().get_nodes_in_group(t["group"]):
				if Game.flags.get(str(t.get("done_prefix", "")) + str(n.get("id")), false):
					continue
				var nr = n.get("region")
				if reg != "" and nr != null and str(nr) != "" and str(nr) != reg:
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


## Vrai quand le boss d'une région est vaincu et que sa séquence « région purifiée » n'a pas encore
## été montrée (voir ending_region).
func ending_due() -> bool:
	return ending_region() != ""


## Région dont la séquence « région purifiée » est due, "" sinon.
func ending_region() -> String:
	for id in Regions.ids():
		if bool(Game.flags.get(Regions.boss_flag(id), false)) and not bool(Game.flags.get(Regions.ending_flag(id), false)):
			return id
	return ""


## Textes de la séquence de fin pour cette région : ceux de la région (« ending » de son fichier),
## ou, quand toutes les régions sont purifiées, l'annonce de la finale (« adventure_ending » de
## objectives.json : la Flétrissure se retire sous la graine). {sub, title, body}.
func ending_texts(region: String) -> Dictionary:
	if Regions.all_purified(Game.flags):
		return Content._load("objectives").get("adventure_ending", {})
	return Regions.section(region, "ending")


## Note la séquence de fin de cette région comme vue. La fin de l'aventure (ENDING_SEEN) n'est
## posée que par l'épilogue, après la finale.
func mark_ending_seen(region: String) -> void:
	Game.flags[Regions.ending_flag(region)] = true


## L'épilogue est dû : la Flétrissure est vaincue et l'épilogue pas encore montré.
func epilogue_due() -> bool:
	return bool(Game.flags.get(FINALE_WON, false)) and not bool(Game.flags.get(ENDING_SEEN, false))
