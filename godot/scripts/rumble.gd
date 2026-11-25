## Vibration de la manette (autoload « Rumble », jalon Éclat H).
##
## `Rumble.pulse(faible, fort, duree)` fait vibrer la dernière manette utilisée : `faible` et `fort`
## (0 à 1) sont les deux moteurs, `duree` est en secondes. Rien ne vibre si :
##   - `Settings.rumble_scale` vaut 0 (réglage à part : « Réduire les effets » ne le coupe pas) ;
##   - l'entrée active est le clavier ou la souris (`Settings.pad_active()`), ou aucune manette n'est
##     branchée (un Steam Deck compte comme une manette : même API) ;
##   - le jeu est en pause.
## Plafond contre la vibration continue dans les mêlées : au plus `max_duty` secondes de vibration
## par fenêtre de `window` secondes, un écart minimal entre deux impulsions, et une impulsion plus
## faible que celle en cours est ignorée. Une impulsion nettement plus forte (`bypass`) passe toujours
## et remplace l'autre : un boss qui meurt vibre même après une mêlée.
##
## Dosage : data/feel.json › rumble (une entrée par événement : faible, fort, duree). Les accroches
## (une ligne chacune) : fx.gd (coup lourd et critique, coup reçu), moments.gd (mort d'élite, phase
## et mort de boss, Cœur purifié), player.gd (esquive) ; la montée de niveau est écoutée ici.
extends Node

const Content = preload("res://scripts/content.gd")

## Appelé à la place de Input.start_joy_vibration (tests) : (appareil, faible, fort, duree).
var sink := Callable()
## Horloge des tests (secondes) ; négative : temps réel.
var clock := -1.0
## Dernière impulsion réellement envoyée (faible, fort, duree après réglage), et leur nombre.
var last := {}
var count := 0

var _device := -1
var _history: Array = []   # [début, durée] des impulsions de la fenêtre
var _until := 0.0
var _mag := 0.0
var _last_at := -100.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.device_changed.connect(func(): if not Settings.pad_active(): stop())
	Game.leveled_up.connect(func(_lvl): play("level_up"))


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_device = event.device


func _process(_delta: float) -> void:
	if _mag > 0.0 and (get_tree().paused or _now() > _until):
		if get_tree().paused:
			stop()
		_mag = 0.0


func _now() -> float:
	return clock if clock >= 0.0 else Time.get_ticks_msec() / 1000.0


## Réglage de data/feel.json › rumble.
static func feel(key: String, default := 0.0) -> float:
	return float(Content.feel().get("rumble", {}).get(key, default))


## L'appareil qui vibrerait maintenant (-1 : aucun).
func target() -> int:
	if not Settings.pad_active():
		return -1
	var pads := Input.get_connected_joypads()
	if _device in pads:
		return _device
	return pads[0] if not pads.is_empty() else -1


## Impulsion de vibration. Renvoie vrai si elle part.
func pulse(faible: float, fort: float, duree: float) -> bool:
	if Settings.rumble_scale <= 0.001 or get_tree() == null or get_tree().paused:
		return false
	if not Settings.pad_active():
		return false
	var dev := target()
	if dev < 0 and not sink.is_valid():
		return false
	var k := Settings.rumble_scale
	var w := clampf(faible * k, 0.0, 1.0)
	var s := clampf(fort * k, 0.0, 1.0)
	var mag := maxf(w, s)
	var dur := clampf(duree, 0.02, feel("max_duration", 0.9))
	if mag < 0.01:
		return false
	var now := _now()
	var running := now < _until
	var bypass := mag >= _mag + feel("bypass", 0.25)
	if not bypass:
		if running and mag <= _mag:
			return false
		if now - _last_at < feel("min_gap", 0.07):
			return false
		var used := dur
		_history = _history.filter(func(h): return now - h[0] < feel("window", 1.0))
		for h in _history:
			used += h[1]
		if used > feel("max_duty", 0.5):
			return false
	_history.append([now, dur])
	_last_at = now
	_until = now + dur
	_mag = mag
	last = {"faible": w, "fort": s, "duree": dur, "device": dev}
	count += 1
	if sink.is_valid():
		sink.call(dev, w, s, dur)
	else:
		Input.start_joy_vibration(dev, w, s, dur)
	return true


## Impulsion nommée de data/feel.json › rumble › <nom> (faible, fort, duree).
func play(nom: String, k := 1.0) -> bool:
	var e: Dictionary = Content.feel().get("rumble", {}).get(nom, {})
	if e.is_empty():
		return false
	return pulse(float(e.get("faible", 0.0)) * k, float(e.get("fort", 0.0)) * k, float(e.get("duree", 0.1)))


## Coup reçu : plus la part de vie perdue est grande, plus l'impulsion est forte et longue.
func hurt(frac: float) -> bool:
	var t := clampf(frac / maxf(feel("hurt_full_frac", 0.3), 0.01), 0.0, 1.0)
	var e: Dictionary = Content.feel().get("rumble", {}).get("hurt", {})
	var lo: Dictionary = e.get("min", {})
	var hi: Dictionary = e.get("max", {})
	return pulse(lerpf(float(lo.get("faible", 0.2)), float(hi.get("faible", 0.7)), t),
		lerpf(float(lo.get("fort", 0.1)), float(hi.get("fort", 0.9)), t),
		lerpf(float(lo.get("duree", 0.1)), float(hi.get("duree", 0.35)), t))


## Essai à la main du curseur des options.
func preview() -> bool:
	return play("preview")


func stop() -> void:
	if _mag <= 0.0:
		return
	_mag = 0.0
	_until = 0.0
	var dev := target()
	if sink.is_valid():
		sink.call(dev, 0.0, 0.0, 0.0)
	elif dev >= 0:
		Input.stop_joy_vibration(dev)
