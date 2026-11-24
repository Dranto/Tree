## Bruitages : un petit parc de lecteurs, des sons générés par le code (tools/gen-sounds.sh),
## au plus 3 sons identiques par fenêtre de 50 ms, une variante tirée au hasard (« variants » dans
## synth.gd) et une légère variation de hauteur. Les grands sons (« duck ») baissent un instant la musique.
## Un limiteur sur la sortie générale évite la saturation quand tout s'additionne.
## Usage : Sfx.play("impact", position_du_monde). Sans position, le son est joué à plein volume.
extends Node

const Synth = preload("res://scripts/synth.gd")

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
	_ensure_limiter()
	# Tous les sons de synth.gd (Ronce, Spore, Vent…) et leurs variantes : un son ajouté là est chargé
	# sans autre changement.
	for name in Synth.SOUNDS:
		var list: Array = []
		for file in Synth.variant_names(name):
			var s := load_wav("res://assets/sounds/%s.wav" % file)
			if s != null:
				list.append(s)
		if not list.is_empty():
			streams[name] = list
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


## Limiteur sur le bus général : les sons et la musique additionnés ne saturent jamais.
static func _ensure_limiter() -> void:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	lim.pre_gain_db = 0.0
	AudioServer.add_bus_effect(0, lim)


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


## pitch : hauteur de base (1 = normale), pour caler un son sur l'action (ex. enchaînement de ramassages).
func play(name: String, pos := Vector2.INF, pitch := 1.0) -> void:
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
	var st = streams[name]
	p.stream = st[rng.randi() % st.size()] if st is Array else st
	p.volume_db = gain
	p.pitch_scale = pitch * rng.randf_range(0.97, 1.03) if pitch != 1.0 else rng.randf_range(0.94, 1.06)
	p.play()
	played += 1
	var duck := float(Synth.SOUNDS.get(name, {}).get("duck", 0.0))
	if duck > 0.0:
		var music = get_node_or_null("/root/Music")
		if music != null:
			music.duck(duck * (1.0 if gain > -6.0 else 0.5))


func _free_player() -> AudioStreamPlayer:
	for p in players:
		if not p.playing:
			return p
	return null
