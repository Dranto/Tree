## Réglages du joueur (volume, plein écran, aide, déplacement, visée, commandes de la barre de compétences) :
## chargés et enregistrés dans user://settings.cfg.
extends Node

signal changed

const PATH := "user://settings.cfg"

var volume := 0.8
## Réglages séparés de la musique et des bruitages, en plus du volume général.
var music_volume := 0.7
var sfx_volume := 0.9
## Ambiance sonore (vent, eau, oiseaux…), bus « Ambiance ».
var ambience_volume := 0.8
var fullscreen := false
var show_hints := true
## Chiffres de dégâts flottants (infligés et reçus).
var show_damage_numbers := true
## Commandes de la barre de compétences : six emplacements, alignés sur player.bar.
## - 0 et 1 : les deux compétences principales, sur les clics gauche et droit (actions
##   « skill_main_1 » et « skill_main_2 ») ;
## - 2 à 5 : les compétences secondaires (actions « slot_1 » à « slot_4 »), sur A E R F en
##   AZERTY, et sur les chiffres 1 à 4.
## Une liaison est un entier : un bouton de souris est codé en négatif (-MOUSE_BUTTON_LEFT…),
## sinon c'est une touche physique (QWERTY : KEY_Q devient A sur un clavier AZERTY).
const SLOT_COUNT := 6
const MOUSE_SLOTS := 2
const SLOT_ACTIONS := ["skill_main_1", "skill_main_2", "slot_1", "slot_2", "slot_3", "slot_4"]
const SLOT_DIGITS := [KEY_NONE, KEY_NONE, KEY_1, KEY_2, KEY_3, KEY_4]
const BINDING_DEFAULTS := [-MOUSE_BUTTON_LEFT, -MOUSE_BUTTON_RIGHT, KEY_Q, KEY_E, KEY_R, KEY_F]
## Boutons de souris acceptés pour une compétence (la molette n'en fait pas partie).
const MOUSE_BUTTONS := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
var bindings: Array = BINDING_DEFAULTS.duplicate()
## Mode « moba » : le clic droit sert à marcher. La compétence liée au clic droit passe sur
## cette touche (Maj par défaut), et l'esquive ne garde qu'Espace.
const MOBA_MAIN_2_DEFAULT := KEY_SHIFT
var moba_main_2_key: int = MOBA_MAIN_2_DEFAULT
## Visée de l'attaque de base : « auto » (par défaut, l'ennemi à portée le plus proche du
## curseur, voir player.auto_target) ou « curseur » (toujours vers la souris, même sans ennemi).
const AIM_MODES := ["auto", "curseur"]
const AIM_MODE_NAMES := {"auto": "Automatique", "curseur": "Vers le curseur"}
var aim_mode := "auto"
## Secousse d'écran, de 0 (aucune) à 1 (pleine).
var shake := 0.6
## Force des rafales de vent (région de Vent, wind.gd), de 0 (coupées) à 1 (pleine) : elles poussent
## le joueur et dévient les projectiles. Accessibilité : on peut les couper.
var wind := 1.0
## Difficulté : « facile », « normal » (par défaut) ou « difficile ». Multiplie la vie et les
## dégâts des ennemis (réglages dans res://data/difficulty.json, section « modes »).
const DIFFICULTIES := ["facile", "normal", "difficile"]
var difficulty := "normal"
## Déplacement du héros : « clavier » (par défaut, Z Q S D ou flèches), « curseur » (il marche
## vers la souris) ou « moba » (un clic droit fixe une destination). Dans les deux modes à la
## souris, le clavier reste utilisable et prend la main tant qu'une touche de direction est tenue.
## Un choix déjà enregistré dans user://settings.cfg est gardé.
const MOVE_MODES := ["clavier", "curseur", "moba"]
const MOVE_MODE_NAMES := {"clavier": "Clavier (Z Q S D)", "curseur": "Suivre le curseur", "moba": "Clic droit (MOBA)"}
const MOVE_MODE_DEFAULT := "clavier"
var move_mode := MOVE_MODE_DEFAULT
## Réduit les effets de jeu : plus de secousse ni de micro-pause, très peu de particules, ambiance coupée.
var reduce_effects := false


func _ready() -> void:
	load_settings()
	apply_bindings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	ambience_volume = clampf(float(cfg.get_value("audio", "ambience_volume", ambience_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	show_hints = bool(cfg.get_value("gameplay", "show_hints", show_hints))
	show_damage_numbers = bool(cfg.get_value("gameplay", "show_damage_numbers", show_damage_numbers))
	# Section « bindings » (jalon 6) : les anciennes touches « controls/slot_N » visaient une autre
	# disposition de la barre et ne sont plus lues.
	for i in SLOT_COUNT:
		var b := int(cfg.get_value("bindings", SLOT_ACTIONS[i], bindings[i]))
		bindings[i] = b if _valid_binding(b) else BINDING_DEFAULTS[i]
	var mk := int(cfg.get_value("bindings", "moba_main_2", moba_main_2_key))
	moba_main_2_key = mk if mk > 0 else MOBA_MAIN_2_DEFAULT
	var aim := str(cfg.get_value("controls", "aim_mode", aim_mode))
	aim_mode = aim if aim in AIM_MODES else "auto"
	shake = clampf(float(cfg.get_value("gameplay", "shake", shake)), 0.0, 1.0)
	wind = clampf(float(cfg.get_value("gameplay", "wind", wind)), 0.0, 1.0)
	reduce_effects = bool(cfg.get_value("gameplay", "reduce_effects", reduce_effects))
	var diff := str(cfg.get_value("gameplay", "difficulty", difficulty))
	difficulty = diff if diff in DIFFICULTIES else "normal"
	var mode := str(cfg.get_value("controls", "move_mode", move_mode))
	move_mode = mode if mode in MOVE_MODES else MOVE_MODE_DEFAULT
	apply_bindings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "ambience_volume", ambience_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("gameplay", "show_hints", show_hints)
	cfg.set_value("gameplay", "show_damage_numbers", show_damage_numbers)
	for i in SLOT_COUNT:
		cfg.set_value("bindings", SLOT_ACTIONS[i], bindings[i])
	cfg.set_value("bindings", "moba_main_2", moba_main_2_key)
	cfg.set_value("controls", "aim_mode", aim_mode)
	cfg.set_value("gameplay", "shake", shake)
	cfg.set_value("gameplay", "wind", wind)
	cfg.set_value("gameplay", "reduce_effects", reduce_effects)
	cfg.set_value("gameplay", "difficulty", difficulty)
	cfg.set_value("controls", "move_mode", move_mode)
	cfg.save(PATH)


## Crée ou remet à jour les actions de la barre (« skill_main_1 », « skill_main_2 », « slot_1 » à
## « slot_4 ») et l'esquive (Espace, plus Maj hors du mode « moba »).
func apply_bindings() -> void:
	for i in SLOT_COUNT:
		var action: String = SLOT_ACTIONS[i]
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for code in [SLOT_DIGITS[i], effective_binding(i)]:
			var ev := _event(code)
			if ev != null:
				InputMap.action_add_event(action, ev)
	if InputMap.has_action("dash"):
		InputMap.action_erase_events("dash")
	else:
		InputMap.add_action("dash")
	var dash_keys := [KEY_SPACE] if move_mode == "moba" else [KEY_SPACE, KEY_SHIFT]
	for k in dash_keys:
		if not _bound(k):
			InputMap.action_add_event("dash", _event(k))


## Une touche déjà prise par la barre (la touche du clic droit en mode « moba », par exemple).
func _bound(code: int) -> bool:
	for i in SLOT_COUNT:
		if effective_binding(i) == code:
			return true
	return false


static func _event(code: int) -> InputEvent:
	if code < 0:
		var mb := InputEventMouseButton.new()
		mb.button_index = -code
		return mb
	if code == KEY_NONE:
		return null
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


static func _valid_binding(code: int) -> bool:
	return code >= 0 or -code in MOUSE_BUTTONS


## Action de l'emplacement i de la barre (0 = clic gauche, 1 = clic droit, 2 à 5 = secondaires).
static func slot_action(i: int) -> String:
	return SLOT_ACTIONS[i] if i >= 0 and i < SLOT_COUNT else ""


## Liaison réellement en service : en mode « moba », la compétence du clic droit passe sur
## moba_main_2_key, puisque le clic droit y sert à marcher.
func effective_binding(i: int) -> int:
	var b: int = bindings[i]
	if move_mode == "moba" and b == -MOUSE_BUTTON_RIGHT:
		return moba_main_2_key
	return b


func binding_is_mouse(i: int) -> bool:
	return effective_binding(i) < 0


## Nom affiché de la liaison de l'emplacement i (« Clic gauche », « A »…).
func binding_name(i: int) -> String:
	return code_name(effective_binding(i))


## Nom court de la liaison de l'emplacement i, pour la barre (« Clic G », « A »).
func binding_short(i: int) -> String:
	var code := effective_binding(i)
	if code < 0:
		match -code:
			MOUSE_BUTTON_LEFT: return "Clic G"
			MOUSE_BUTTON_RIGHT: return "Clic D"
			MOUSE_BUTTON_MIDDLE: return "Clic M"
			MOUSE_BUTTON_XBUTTON1: return "B4"
			MOUSE_BUTTON_XBUTTON2: return "B5"
	return code_name(code)


## Nom affiché d'une liaison : bouton de souris, ou touche selon la disposition du clavier.
func code_name(code: int) -> String:
	if code < 0:
		match -code:
			MOUSE_BUTTON_LEFT: return "Clic gauche"
			MOUSE_BUTTON_RIGHT: return "Clic droit"
			MOUSE_BUTTON_MIDDLE: return "Clic milieu"
			MOUSE_BUTTON_XBUTTON1: return "Bouton 4"
			MOUSE_BUTTON_XBUTTON2: return "Bouton 5"
		return "Souris %d" % -code
	return key_name(code)


## Réassigne l'emplacement i (KEY_NONE pour l'enlever). Une liaison déjà prise par un autre
## emplacement lui est retirée, pour qu'une touche ne lance jamais deux compétences.
func set_binding(i: int, code: int) -> void:
	if not _valid_binding(code):
		return
	for j in SLOT_COUNT:
		if j != i and bindings[j] == code:
			bindings[j] = KEY_NONE
	bindings[i] = code
	apply_bindings()
	changed.emit()


## Touche de la compétence du clic droit en mode « moba ».
func set_moba_main_2_key(code: int) -> void:
	if code <= 0:
		return
	for j in SLOT_COUNT:
		if bindings[j] == code:
			bindings[j] = KEY_NONE
	moba_main_2_key = code
	apply_bindings()
	changed.emit()


## Nom affiché d'une touche physique selon la disposition du clavier (A sur AZERTY pour KEY_Q).
func key_name(physical_keycode: int) -> String:
	if physical_keycode == KEY_NONE:
		return "—"
	var kc := physical_keycode
	if DisplayServer.get_name() != "headless":
		kc = DisplayServer.keyboard_get_keycode_from_physical(kc)
	return OS.get_keycode_string(kc)


## Action du jeu (hors barre de compétences) qui utilise déjà cette liaison, ou "".
## L'esquive n'est pas comptée pour Maj, que la barre peut reprendre (mode « moba »).
func key_owner(code: int) -> String:
	if code == KEY_SHIFT:
		return ""
	for action in InputMap.get_actions():
		if str(action) in SLOT_ACTIONS or str(action).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(action):
			var k := ev as InputEventKey
			if k and k.physical_keycode == code:
				return str(action)
			var m := ev as InputEventMouseButton
			if m and -m.button_index == code:
				return str(action)
	return ""


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	_set_bus("Musique", music_volume)
	_set_bus("Effets", sfx_volume)
	_set_bus("Ambiance", ambience_volume)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	changed.emit()


## Volume d'un bus (s'il existe : Sfx et Music le créent à leur démarrage et rappellent apply()).
func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply()


func set_ambience_volume(v: float) -> void:
	ambience_volume = clampf(v, 0.0, 1.0)
	apply()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	apply()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()


func set_show_hints(on: bool) -> void:
	show_hints = on
	apply()


func set_shake(v: float) -> void:
	shake = clampf(v, 0.0, 1.0)
	changed.emit()


func set_wind(v: float) -> void:
	wind = clampf(v, 0.0, 1.0)
	changed.emit()


func set_reduce_effects(on: bool) -> void:
	reduce_effects = on
	changed.emit()


## Change la difficulté : vaut pour les ennemis qui naissent ensuite.
func set_difficulty(id: String) -> void:
	difficulty = id if id in DIFFICULTIES else "normal"
	changed.emit()


## Change le mode de déplacement (voir MOVE_MODES).
func set_move_mode(id: String) -> void:
	move_mode = id if id in MOVE_MODES else MOVE_MODE_DEFAULT
	apply_bindings()
	changed.emit()


## Change la visée de l'attaque de base (voir AIM_MODES).
func set_aim_mode(id: String) -> void:
	aim_mode = id if id in AIM_MODES else "auto"
	changed.emit()


## Explication d'une visée, affichée sous le choix dans les options.
static func aim_mode_text(id: String) -> String:
	if id == "curseur":
		return "L'attaque de base part toute seule vers la souris, même sans ennemi."
	return "L'attaque de base part toute seule sur l'ennemi à portée le plus proche du curseur. Sans ennemi à portée, elle ne part pas."


## Explication d'un mode de déplacement, affichée sous le choix dans les options.
func move_mode_text(id: String) -> String:
	match id:
		"moba":
			var key := code_name(moba_main_2_key)
			return "Clic droit : le héros marche jusqu'à l'endroit cliqué (un repère s'affiche au sol) ; clic droit tenu : il suit le curseur. La compétence du clic droit passe sur %s ; Espace reste l'esquive, vers le curseur." % key
		"curseur":
			return "Le héros marche vers la souris et s'arrête quand elle est tout près de lui. L'attaque part toute seule ; clic gauche et clic droit lancent les compétences vers le curseur. L'esquive part vers le curseur."
	return "Z Q S D (W A S D en QWERTY) ou les flèches. L'attaque part toute seule ; clic gauche et clic droit lancent les compétences vers le curseur."


## Force réellement appliquée de la secousse d'écran (0 si les effets sont réduits).
func shake_strength() -> float:
	return 0.0 if reduce_effects else shake
