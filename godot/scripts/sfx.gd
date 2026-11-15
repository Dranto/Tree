## Bruitages : un petit parc de lecteurs, des sons générés par le code (tools/gen-sounds.sh),
## au plus 3 sons identiques par fenêtre de 50 ms et une légère variation de hauteur.
## Usage : Sfx.play("impact", position_du_monde). Sans position, le son est joué à plein volume.
extends Node

const BUS := "Effets"
const POOL := 16
const WINDOW_MSEC := 50
const MAX_SAME := 3
## Au-delà de cette distance au joueur (en pixels du monde), un son localisé n'est pas joué.
const HEARING := 1500.0

## Faux en test (sans écran, banc visuel, option --silent) : plus aucun son n'est joué.
var enabled := true
## Le joueur : sert à atténuer les sons selon la distance.
var listener: Node2D
var streams: Dictionary = {}
var players: Array = []
var recent: Dictionary = {}
var rng := RandomNumberGenerator.new()
## Nombre de sons réellement lancés (lu par les tests).
var played := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	enabled = not is_silent_run()
	ensure_bus(BUS)
	if not enabled:
		return
	for name in ["tir", "impact", "critique", "mort", "noeud", "niveau", "esquive", "degats", "nova", "nuage",
			"floraison", "fouet", "racines", "volee", "saignee", "annonce", "coeur", "clic", "survol"]:
		var s := load_wav("res://assets/sounds/%s.wav" % name)
		if s != null:
			streams[name] = s
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		players.append(p)
	Game.node_allocated.connect(func(n: Dictionary): if n["id"] != 0: play("noeud"))
	Game.leveled_up.connect(func(_l: int): play("niveau"))


static func is_silent_run() -> bool:
	return DisplayServer.get_name() == "headless" or "--silent" in OS.get_cmdline_user_args() \
		or Game.forced_seed >= 0


## Crée un bus audio qui sort vers « Master », s'il n'existe pas encore.
static func ensure_bus(bus: String) -> int:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
		Settings.apply()
	return i


## Charge un .wav : par l'import de Godot, ou à défaut en lisant le fichier (projet jamais ouvert dans l'éditeur).
static func load_wav(path: String) -> AudioStreamWAV:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStreamWAV:
			return res
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Son introuvable : " + path)
		return null
	var bytes := f.get_buffer(f.get_length())
	# En-tête de 44 octets écrit par synth.gd : mono, 16 bits.
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = bytes.decode_u32(24)
	s.stereo = false
	s.data = bytes.slice(44)
	return s


func has_sound(name: String) -> bool:
	return streams.has(name)


func play(name: String, pos := Vector2.INF) -> void:
	if not enabled or not streams.has(name):
		return
	var now := Time.get_ticks_msec()
	var list: Array = recent.get(name, [])
	list = list.filter(func(t): return now - t < WINDOW_MSEC)
	if list.size() >= MAX_SAME:
		recent[name] = list
		return
	var gain := 0.0
	if pos != Vector2.INF and is_instance_valid(listener):
		var d := listener.global_position.distance_to(pos)
		if d > HEARING:
			return
		gain = -14.0 * d / HEARING
	var p := _free_player()
	if p == null:
		return
	list.append(now)
	recent[name] = list
	p.stream = streams[name]
	p.volume_db = gain
	p.pitch_scale = rng.randf_range(0.94, 1.06)
	p.play()
	played += 1


func _free_player() -> AudioStreamPlayer:
	for p in players:
		if not p.playing:
			return p
	return null
