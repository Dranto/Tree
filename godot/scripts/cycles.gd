## Cycles du New Game+ (autoload « Cycles », jalon 14) : une aventure entière par cycle, le premier
## étant la première aventure. Le numéro vit dans Game.cycle (sauvegardé) ; ce qui change d'un
## cycle à l'autre est décrit dans res://data/cycles.json (format dans data/README.md).
##
## Lecture, pour tous les systèmes (monstres, boss, monde, greffes…) :
## - Cycles.current() : le cycle en cours (1 = première aventure) ;
## - Cycles.value("clé", défaut) : la valeur de « clé » pour le cycle en cours, lue dans
##   cycles.json › cycles › "<n>". Au-delà du dernier cycle décrit, on retombe sur le dernier cycle
##   qui donne la clé ; seules les clés de « per_cycle_after » continuent de monter (d'autant par
##   cycle en plus), jusqu'à leur plafond dans « caps ». Cycles.value(clé, défaut, n) lit le cycle n.
## - Cycles.exalted() : vrai à partir du cycle 2 (boss exaltés, monde fané…).
## Pour essayer un cycle sans sauvegarde : « -- --cycle=2 » (impose le cycle pour toute la partie).
extends Node

const PATH := "res://data/cycles.json"
## Premier cycle « exalté » (NG+).
const EXALTED_FROM := 2

## Cycle imposé par « -- --cycle=N » (tests, essais), -1 sinon.
var forced := -1
var _data: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cycle="):
			forced = maxi(1, int(arg.get_slice("=", 1)))
	_data = load_data()


## Lit data/cycles.json (sans cache : les tests peuvent relire après une modification).
static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		push_error("Fichier de données introuvable : " + PATH)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(PATH)) != OK:
		push_error("%s, ligne %d : %s" % [PATH, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data if json.data is Dictionary else {}


## Le cycle en cours (1 = première aventure).
func current() -> int:
	if forced >= 1:
		return forced
	return maxi(1, int(Game.cycle))


## Vrai à partir du cycle 2.
func exalted() -> bool:
	return current() >= EXALTED_FROM


## Valeur de « key » pour le cycle « cycle » (le cycle en cours par défaut), « default » si aucun
## cycle décrit ne la donne. Les dictionnaires et tableaux renvoyés sont des copies.
func value(key: String, default = null, cycle := -1):
	return resolve(_data, key, default, current() if cycle < 1 else cycle)


## Règle de lecture, sans état (testable sur des données à part).
static func resolve(data: Dictionary, key: String, default, n: int):
	var cycles: Dictionary = data.get("cycles", {})
	var best := -1
	var last := 1
	for k in cycles:
		var c := int(k)
		last = maxi(last, c)
		if c <= n and c > best and cycles[k] is Dictionary and (cycles[k] as Dictionary).has(key):
			best = c
	if best < 1:
		return default
	var v = cycles[str(best)][key]
	var step = data.get("per_cycle_after", {}).get(key, null)
	if n > last and step != null and (v is float or v is int):
		v = float(v) + float(step) * (n - last)
		var cap = data.get("caps", {}).get(key, null)
		if cap != null:
			v = minf(v, float(cap))
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v


## Dernier cycle décrit dans cycles.json (contenu nouveau jusque-là, ensuite seule la menace monte).
func last_described() -> int:
	var best := 1
	for k in _data.get("cycles", {}):
		best = maxi(best, int(k))
	return best


# --- Vague de flétrissure du début de cycle (monde fané) ---

## Drapeau de l'aventure posé au toucher du fruit : le numéro du cycle dont la vague de
## flétrissure n'est pas encore passée (sauvegardé, pour la rejouer après un chargement).
const WAVE_FLAG := "cycle_wave"


## Cycle dont la vague de flétrissure est en attente (0 si aucune) : lisible dès le _ready des
## nœuds de la scène de jeu, avant Game.cycle_started.
func wave_pending() -> int:
	return int(Game.flags.get(WAVE_FLAG, 0))


## La vague de flétrissure est passée : le drapeau tombe.
func end_wave() -> void:
	Game.flags.erase(WAVE_FLAG)


# --- Passage au cycle suivant (le fruit de la graine, cycle_fruit.gd) ---

## Drapeaux de l'aventure gardés d'un cycle à l'autre (le reste revient à zéro : Cœurs, boss,
## sanctuaires, autels, purification, objectifs, sève perdue, fin vue, points des boss et des Cœurs,
## statistiques de la partie). Clés exactes, puis préfixes.
const KEEP_FLAGS := ["plan_arbre", "barre", "couronne_vue", "demo_sceau_vu", "points_hors_niveau"]
const KEEP_PREFIXES := ["tuto_"]

## Cycle qui vient de commencer par le fruit, en attente de la scène de jeu rechargée (0 sinon) :
## Game.cycle_started part quand elle est prête (main_ready).
var _just_started := 0


## Drapeaux gardés pour le cycle suivant.
static func kept_flags(flags: Dictionary) -> Dictionary:
	var out := {}
	for k in flags:
		var key := str(k)
		var keep := KEEP_FLAGS.has(key)
		for p in KEEP_PREFIXES:
			keep = keep or key.begins_with(p)
		if keep:
			out[k] = flags[k]
	return out


## Passe l'état du jeu (Game) au cycle suivant, sans toucher à la scène : on garde niveau, expérience,
## points, arbre, builds, greffes et couronne (ses emplacements ouverts restent ouverts, Game.crown_kept),
## on remet à zéro les drapeaux de l'aventure (voir KEEP_FLAGS) et on note la vague de flétrissure.
## Renvoie le nouveau cycle.
func advance_state() -> int:
	Game.store_active_build()
	Game.crown_kept = maxi(Game.crown_kept, Game.crown_size(Game.flags))
	var n := maxi(1, int(Game.cycle)) + 1
	Game.cycle = n
	if forced >= 1:
		forced = n
	Game.flags = kept_flags(Game.flags)
	Game.flags[WAVE_FLAG] = n
	Game.at_sanctuary = false
	Game.recompute()
	Game.tree_changed.emit()
	return n


## Le joueur a touché le fruit de la graine : le cycle suivant commence. L'état passe au cycle
## suivant, la partie est sauvegardée avec un monde remis à neuf (sol non purifié, fleurs et greffes au
## sol effacées, le héros au pied de la graine, toute sa vie), puis la scène de jeu est rechargée
## comme pour « Continuer ». Game.cycle_started part quand elle est prête (main_ready).
func start_next(main) -> int:
	var n := advance_state()
	var data: Dictionary = SaveGame.capture(main)
	data["world"] = {
		"elapsed": float(main.elapsed) if main != null else 0.0,
		"player": {"x": 0.0, "y": 0.0, "hp": float(Game.stats.get("max_hp", 100.0))},
		"ground_grafts": [],
	}
	Game.grafts_on_ground = {}
	if main == null or not main.get("autosave_enabled") or not SaveGame.write(data):
		# Pas de sauvegarde (tests, robot) : rien n'est rechargé, le signal part tout de suite.
		(func(): Game.cycle_started.emit(n)).call_deferred()
		return n
	_just_started = n
	# La scène sauvegarde en partant (main._exit_tree) : elle écraserait le monde remis à neuf.
	main.autosave_enabled = false
	Flow.continue_requested = true
	Flow.reload_game()
	return n


## Appelé à la fin du _ready de la scène de jeu (main.gd) : si un cycle vient de commencer par le
## fruit, Game.cycle_started part à l'image suivante, main prêt et Game.cycle au nouveau numéro.
func main_ready(_main) -> void:
	if _just_started <= 0:
		return
	var n := _just_started
	_just_started = 0
	(func(): Game.cycle_started.emit(n)).call_deferred()
