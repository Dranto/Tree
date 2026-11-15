## Réglages du joueur (volume, plein écran, aide) : chargés et enregistrés dans user://settings.cfg.
extends Node

signal changed

const PATH := "user://settings.cfg"

var volume := 0.8
var fullscreen := false
var show_hints := true
## Secousse d'écran, de 0 (aucune) à 1 (pleine).
var shake := 0.6
## Réduit les effets de jeu : plus de secousse ni de micro-pause, très peu de particules, ambiance coupée.
var reduce_effects := false


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	show_hints = bool(cfg.get_value("gameplay", "show_hints", show_hints))
	shake = clampf(float(cfg.get_value("gameplay", "shake", shake)), 0.0, 1.0)
	reduce_effects = bool(cfg.get_value("gameplay", "reduce_effects", reduce_effects))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("gameplay", "show_hints", show_hints)
	cfg.set_value("gameplay", "shake", shake)
	cfg.set_value("gameplay", "reduce_effects", reduce_effects)
	cfg.save(PATH)


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	changed.emit()


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


## Force réellement appliquée de la secousse d'écran (0 si les effets sont réduits).
func shake_strength() -> float:
	return 0.0 if reduce_effects else shake
