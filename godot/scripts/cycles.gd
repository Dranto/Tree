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
