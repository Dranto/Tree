## Réglages du joueur (volume, plein écran, aide, touches de la barre de compétences) :
## chargés et enregistrés dans user://settings.cfg.
extends Node

signal changed

const PATH := "user://settings.cfg"

var volume := 0.8
## Réglages séparés de la musique et des bruitages, en plus du volume général.
var music_volume := 0.7
var sfx_volume := 0.9
var fullscreen := false
var show_hints := true
## Touches des emplacements de la barre de compétences (actions « slot_1 » à « slot_6 »).
## Chaque emplacement répond à son chiffre (fixe) et à une touche réassignable dans les options.
## Ce sont des positions physiques (QWERTY) : Q E R deviennent A E R sur un clavier AZERTY.
const SLOT_COUNT := 6
const SLOT_DIGITS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
const SLOT_DEFAULTS := [KEY_Q, KEY_E, KEY_R, KEY_NONE, KEY_NONE, KEY_NONE]
var slot_keys: Array = SLOT_DEFAULTS.duplicate()
## Secousse d'écran, de 0 (aucune) à 1 (pleine).
var shake := 0.6
## Difficulté : « facile », « normal » (par défaut) ou « difficile ». Multiplie la vie et les
## dégâts des ennemis (réglages dans res://data/difficulty.json, section « modes »).
const DIFFICULTIES := ["facile", "normal", "difficile"]
var difficulty := "normal"
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
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	show_hints = bool(cfg.get_value("gameplay", "show_hints", show_hints))
	for i in SLOT_COUNT:
		slot_keys[i] = int(cfg.get_value("controls", "slot_%d" % (i + 1), slot_keys[i]))
	shake = clampf(float(cfg.get_value("gameplay", "shake", shake)), 0.0, 1.0)
	reduce_effects = bool(cfg.get_value("gameplay", "reduce_effects", reduce_effects))
	var diff := str(cfg.get_value("gameplay", "difficulty", difficulty))
	difficulty = diff if diff in DIFFICULTIES else "normal"


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("gameplay", "show_hints", show_hints)
	for i in SLOT_COUNT:
		cfg.set_value("controls", "slot_%d" % (i + 1), slot_keys[i])
	cfg.set_value("gameplay", "shake", shake)
	cfg.set_value("gameplay", "reduce_effects", reduce_effects)
	cfg.set_value("gameplay", "difficulty", difficulty)
	cfg.save(PATH)


## Crée ou remet à jour les actions « slot_N » : le chiffre N plus la touche choisie.
func apply_bindings() -> void:
	for i in SLOT_COUNT:
		var action := "slot_%d" % (i + 1)
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for k in [SLOT_DIGITS[i], slot_keys[i]]:
			if k != KEY_NONE:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)


## Réassigne la touche d'un emplacement (KEY_NONE pour l'enlever). Une touche déjà prise par
## un autre emplacement lui est retirée, pour qu'une touche ne lance jamais deux compétences.
func set_slot_key(i: int, physical_keycode: int) -> void:
	for j in SLOT_COUNT:
		if j != i and slot_keys[j] == physical_keycode:
			slot_keys[j] = KEY_NONE
	slot_keys[i] = physical_keycode
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


## Action du jeu (hors barre de compétences) qui utilise déjà cette touche physique, ou "".
func key_owner(physical_keycode: int) -> String:
	for action in InputMap.get_actions():
		if str(action).begins_with("slot_") or str(action).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(action):
			var k := ev as InputEventKey
			if k and k.physical_keycode == physical_keycode:
				return str(action)
	return ""


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	_set_bus("Musique", music_volume)
	_set_bus("Effets", sfx_volume)
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


func set_reduce_effects(on: bool) -> void:
	reduce_effects = on
	changed.emit()


## Change la difficulté : vaut pour les ennemis qui naissent ensuite.
func set_difficulty(id: String) -> void:
	difficulty = id if id in DIFFICULTIES else "normal"
	changed.emit()


## Force réellement appliquée de la secousse d'écran (0 si les effets sont réduits).
func shake_strength() -> float:
	return 0.0 if reduce_effects else shake
