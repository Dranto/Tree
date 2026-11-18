## Musique dynamique : deux couches jouées ensemble en boucle, mélangées selon la vie du sol.
## La couche sombre (accords mineurs, vent) domine en terre morte ; la lumineuse (accords majeurs,
## arpèges) monte quand la terre revit. Music.set_mood(vie) avec vie entre 0 (cendre) et 1 (prairie).
##
## Chaque région qui règle sa musique (data/audio.json, voir region_audio.gd) a sa propre paire de couches,
## « <région>_sombre » et « <région>_lumineux » (tools/gen-sounds.sh). Toutes les paires tournent ensemble
## (même boucle de 12 s, donc toujours en phase) ; on n'entend que celle de la région où se trouve le joueur,
## par un fondu de ~2 s. Hors région (l'oasis) et pour une région sans réglage, c'est la musique du monde.
extends Node

const BUS := "Musique"
const SfxScript = preload("res://scripts/sfx.gd")
const RegionAudio = preload("res://scripts/region_audio.gd")
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
## Paires de couches des régions : id -> {"dark", "bright", "gain"}. Le monde (dark, bright) a toujours le sien.
var pairs: Dictionary = {}
var world_gain := 1.0
## Régions dont les pistes n'existent pas (pas encore générées) : on ne les cherche qu'une fois.
var _missing: Dictionary = {}
## Région dont on entend la musique ("" : le monde).
var region := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = not SfxScript.is_silent_run()
	SfxScript.ensure_bus(BUS)
	if not enabled:
		return
	dark = _layer("res://assets/music/sombre.wav")
	bright = _layer("res://assets/music/lumineux.wav")
	refresh_regions()
	_apply()


## Crée les couches des régions qui ont une musique propre et dont les fichiers existent (à rappeler
## quand la liste des régions change, dans les tests).
func refresh_regions() -> void:
	if not enabled:
		return
	_missing.clear()
	for id in RegionAudio.music_regions():
		_ensure_pair(id)


func _ensure_pair(id: String) -> bool:
	if pairs.has(id):
		return true
	if _missing.has(id):
		return false
	if not ResourceLoader.exists(RegionAudio.music_path(id, "sombre")) and not FileAccess.file_exists(RegionAudio.music_path(id, "sombre")):
		_missing[id] = true
		return false
	var pair := {"dark": _layer(RegionAudio.music_path(id, "sombre")), "bright": _layer(RegionAudio.music_path(id, "lumineux")), "gain": 0.0}
	pairs[id] = pair
	if started:
		# Rejoint la boucle en cours, à la même position que le monde, pour rester en phase.
		var at: float = dark.get_playback_position() if dark != null and dark.playing else 0.0
		for p in [pair["dark"], pair["bright"]]:
			if p.stream != null:
				p.play(at)
	return true


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
	for p in _all_players():
		if p.stream != null:
			p.play()
	_apply()


func _all_players() -> Array:
	var out: Array = [dark, bright]
	for id in pairs:
		out.append(pairs[id]["dark"])
		out.append(pairs[id]["bright"])
	return out


func stop() -> void:
	started = false
	if enabled:
		for p in _all_players():
			p.stop()


## vie : vie du sol sous le joueur, de 0 à 1. En dessous de 0,15 c'est la terre morte, au-dessus de 0,6 la prairie.
## reg : région où se trouve le joueur ("" : hors région, musique du monde).
func set_mood(vie: float, reg := "") -> void:
	target = smoothstep(0.15, 0.6, clampf(vie, 0.0, 1.0))
	region = reg if reg != "" and enabled and _ensure_pair(reg) else ""


func _process(delta: float) -> void:
	mix = move_toward(mix, target, FADE * delta)
	world_gain = move_toward(world_gain, 1.0 if region == "" else 0.0, FADE * delta)
	for id in pairs:
		pairs[id]["gain"] = move_toward(pairs[id]["gain"], 1.0 if id == region else 0.0, FADE * delta)
	_apply()


## Mélange à puissance constante : le volume total reste stable pendant le fondu, entre les deux
## couches d'une paire comme entre les régions.
func _apply() -> void:
	if not enabled or dark == null:
		return
	_apply_pair(dark, bright, world_gain)
	for id in pairs:
		_apply_pair(pairs[id]["dark"], pairs[id]["bright"], pairs[id]["gain"])


func _apply_pair(d: AudioStreamPlayer, b: AudioStreamPlayer, gain: float) -> void:
	var g := sin(gain * PI / 2.0)
	d.volume_db = _db(cos(mix * PI / 2.0) * g)
	b.volume_db = _db(sin(mix * PI / 2.0) * g)


static func _db(lin: float) -> float:
	return SILENT_DB if lin < 0.001 else maxf(SILENT_DB, linear_to_db(lin))
