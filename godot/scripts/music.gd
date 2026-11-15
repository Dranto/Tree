## Musique dynamique : deux couches jouées ensemble en boucle, mélangées selon la vie du sol.
## La couche sombre (accords mineurs, vent) domine en terre morte ; la lumineuse (accords majeurs,
## arpèges) monte quand la terre revit. Music.set_mood(vie) avec vie entre 0 (cendre) et 1 (prairie).
extends Node

const BUS := "Musique"
const SfxScript = preload("res://scripts/sfx.gd")
## Vitesse du fondu (part du mélange par seconde) : le changement de couche prend ~2 s.
const FADE := 0.5
const SILENT_DB := -60.0

var enabled := true
var dark: AudioStreamPlayer
var bright: AudioStreamPlayer
## Mélange visé et mélange actuel (0 = tout sombre, 1 = tout lumineux).
var target := 0.0
var mix := 0.0
var started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = not SfxScript.is_silent_run()
	SfxScript.ensure_bus(BUS)
	if not enabled:
		return
	dark = _layer("res://assets/music/sombre.wav")
	bright = _layer("res://assets/music/lumineux.wav")
	_apply()


func _layer(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS
	var s := SfxScript.load_wav(path)
	if s != null:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
		p.stream = s
	add_child(p)
	return p


## Lance les deux couches (sans effet si elles jouent déjà).
func start() -> void:
	if not enabled or started:
		return
	started = true
	for p in [dark, bright]:
		if p.stream != null:
			p.play()
	_apply()


func stop() -> void:
	started = false
	if enabled:
		for p in [dark, bright]:
			p.stop()


## vie : vie du sol sous le joueur, de 0 à 1. En dessous de 0,15 c'est la terre morte, au-dessus de 0,6 la prairie.
func set_mood(vie: float) -> void:
	target = smoothstep(0.15, 0.6, clampf(vie, 0.0, 1.0))


func _process(delta: float) -> void:
	mix = move_toward(mix, target, FADE * delta)
	_apply()


## Mélange à puissance constante : le volume total reste stable pendant le fondu.
func _apply() -> void:
	if not enabled or dark == null:
		return
	dark.volume_db = _db(cos(mix * PI / 2.0))
	bright.volume_db = _db(sin(mix * PI / 2.0))


static func _db(lin: float) -> float:
	return SILENT_DB if lin < 0.001 else maxf(SILENT_DB, linear_to_db(lin))
