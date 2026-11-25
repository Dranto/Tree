## Musiques de boss faites à la main : un morceau par boss, découpé aux mesures par tools/boss-track.sh
## (assets/music/hand/<boss>.json et assets/music/hand/<boss>/<clip>.ogg, format dans data/README.md › Son).
## Clips : intro (intro puis boucle_1), drop_<n> (drop_n puis boucle_<n+1>), fin, defaite ; chaque ogg
## boucle de lui-même sur sa dernière section (loop_offset), à l'échantillon près.
##
## Le morceau suit le combat, sur l'horloge audio (AudioStreamInteractive : les changements tombent au
## début d'une mesure, à l'échantillon près, et le ralenti d'Éclat — Engine.time_scale — ne le touche pas) :
##   éveil du boss      → intro (une fois) → boucle_1 ;
##   phase n            → drop_<n-1> au début de la mesure suivante → boucle_<n> ;
##                        (sans drop, la boucle_<n> part directement à la mesure suivante) ;
##   mort du boss       → fin, à la mesure suivante, puis silence ;
##   mort du héros, fuite, retour au menu → defaite à la mesure suivante s'il y en a une,
##                        sinon fondu de sortie d'une seconde.
## Un boss sans fichier ne change rien : la musique du code (music.gd, couche « boss ») joue comme avant.
##
## Le lecteur ne touche à aucun fichier de boss : il lit de l'extérieur l'arène en combat que main.gd lui
## passe à chaque pas (follow), son boss (phase, dead) et son état à la fin du combat (« vaincue » ou non).
extends Node

const DIR := "res://assets/music/hand/"
const BUS := "Musique" # i18n: non (bus audio)
## Le morceau quitté à une mesure s'éteint en un huitième de temps (~40 ms à 180 BPM) : pas de clic.
const SWITCH_FADE_BEATS := 0.125
## Fondu de sortie (s) quand il n'y a pas de section « defaite ».
const DEFEAT_FADE := 1.0
const SILENT_DB := -60.0

## Boss suivi ("" : aucun morceau ne joue) et état : "combat", "fin", "defaite", "fondu".
var boss_id := ""
var state := ""
## Phase dont la musique est partie (1 : intro et boucle_1).
var phase := 1
var player: AudioStreamPlayer
var stream: AudioStreamInteractive
## Durée (s) de chaque section du morceau joué, et sections présentes.
var lengths: Dictionary = {}
## Après « fin » ou « defaite » : temps (s, horloge audio) restant avant l'arrêt.
var _end_left := -1.0
var _fade_left := 0.0
var _arena = null
## Vrai tant qu'une arène est suivie (une arène libérée ne se compare plus à null).
var _following := false
var dir := DIR
## Journal des demandes (tests) : [{"clip": nom, "at": temps audio de la demande}].
var requests: Array = []
static var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else "Master"
	add_child(player)


## Données du morceau d'un boss ({} sans fichier).
static func track_data(id: String, from := DIR) -> Dictionary:
	var key := from + id
	if _cache.has(key):
		return _cache[key]
	var out := {}
	var path := from + id + ".json"
	if id != "" and FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and d.get("clips", {}).has("intro"):
			out = d
	_cache[key] = out
	return out


static func has_track(id: String, from := DIR) -> bool:
	return not track_data(id, from).is_empty()


## Clips du morceau, dans l'ordre du fichier .json (intro, drop_1, drop_2, …, fin, defaite).
static func clip_names(data: Dictionary) -> Array:
	return data.get("clips", {}).keys()


## Construit le flux interactif d'un morceau (null si un fichier manque).
static func build_stream(data: Dictionary, from := DIR) -> AudioStreamInteractive:
	var bpm := float(data.get("bpm", 120.0))
	var beats := int(data.get("bar_beats", 4))
	var clips: Dictionary = data["clips"]
	var names := clip_names(data)
	var bar := bar_time(data)
	var s := AudioStreamInteractive.new()
	s.clip_count = names.size()
	for i in names.size():
		var name: String = names[i]
		var info: Dictionary = clips[name]
		var path: String = from + str(info["fichier"])
		var ogg: AudioStreamOggVorbis = null
		if ResourceLoader.exists(path):
			ogg = load(path) as AudioStreamOggVorbis
		elif FileAccess.file_exists(path):
			ogg = AudioStreamOggVorbis.load_from_file(path)
		if ogg == null:
			push_warning("Musique de boss : %s manquant" % path)
			return null
		ogg = ogg.duplicate()
		ogg.bpm = bpm
		ogg.bar_beats = beats
		ogg.loop = bool(info.get("boucle", false))
		# beat_count donne la fin de la boucle en temps (mesures entières) ; sans boucle, l'ogg va au bout
		# (la fin garde son écho).
		ogg.beat_count = int(info["mesures"]) * beats if ogg.loop else 0
		ogg.loop_offset = float(info.get("boucle_depuis", 0)) * bar
		s.set_clip_name(i, name)
		s.set_clip_stream(i, ogg)
	# Changements demandés (phase, mort) : au début de la mesure suivante.
	for i in names.size():
		if names[i] != "intro":
			s.add_transition(AudioStreamInteractive.CLIP_ANY, i,
				AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR, AudioStreamInteractive.TRANSITION_TO_TIME_START,
				AudioStreamInteractive.FADE_OUT, SWITCH_FADE_BEATS)
	s.initial_clip = 0
	return s


## Durée (s) d'une section, d'après ses mesures (la fin peut durer un peu plus : son dernier écho).
static func section_length(data: Dictionary, name: String) -> float:
	var info: Dictionary = data["sections"][name]
	var bars: int = int(info["mesures"][1]) - int(info["mesures"][0]) + 1
	return bars * bar_time(data)


## Durée (s) d'un clip sans bouclage (la fin, la défaite), écho compris.
static func clip_length(data: Dictionary, name: String) -> float:
	return float(data["clips"][name].get("echantillons", 0)) / 44100.0


static func bar_time(data: Dictionary) -> float:
	return float(data.get("bar_beats", 4)) * 60.0 / float(data.get("bpm", 120.0))


## Vrai pendant que le morceau d'un boss tient la musique (la couche « boss » du code se tait).
func active() -> bool:
	return state != ""


## Éveil du boss : intro puis boucle_1. Faux (et rien ne change) si le boss n'a pas de morceau.
func begin(id: String) -> bool:
	var data := track_data(id, dir)
	if data.is_empty():
		return false
	if boss_id != id or stream == null:
		stream = build_stream(data, dir)
		if stream == null:
			return false
	boss_id = id
	state = "combat"
	phase = 1
	_end_left = -1.0
	_fade_left = 0.0
	requests.clear()
	player.stream = stream
	player.volume_db = 0.0
	player.play()
	requests.append({"clip": "intro", "at": audio_time()})
	return true


## Le boss passe en phase n : le drop qui y mène, puis sa boucle.
func set_phase(n: int) -> void:
	if state != "combat" or n <= phase:
		return
	phase = n
	var names := clip_names(track_data(boss_id, dir))
	if ("drop_%d" % (n - 1)) in names:
		_switch("drop_%d" % (n - 1))
	elif ("boucle_%d" % n) in names:
		_switch("boucle_%d" % n)


## Le boss meurt : la fin à la mesure suivante (sans fin : fondu de sortie).
func win() -> void:
	if state != "combat":
		return
	var data := track_data(boss_id, dir)
	if data["clips"].has("fin"):
		state = "fin"
		_switch("fin")
		# Une mesure au plus avant qu'elle parte, puis sa durée et son écho.
		_end_left = bar_time(data) + clip_length(data, "fin") + 0.5
	else:
		_fade_out()


## Le héros meurt, fuit ou quitte la partie : la défaite s'il y en a une, sinon un fondu d'une seconde.
func lose() -> void:
	if state != "combat" and state != "fin":
		return
	var data := track_data(boss_id, dir)
	if state == "combat" and data["clips"].has("defaite"):
		state = "defaite"
		_switch("defaite")
		_end_left = bar_time(data) + clip_length(data, "defaite") + 0.5
	else:
		_fade_out()


## Arrêt immédiat (tests, nouvelle partie).
func stop() -> void:
	if player != null:
		player.stop()
	state = ""
	boss_id = ""
	_arena = null
	_following = false
	_end_left = -1.0
	_fade_left = 0.0


## Suit l'arène en combat que main.gd voit à ce pas (null : aucun combat).
func follow(arena) -> void:
	if arena != null and arena.in_combat():
		if arena != _arena or not _following:
			_arena = arena
			_following = true
			if state == "" or state == "fondu" or state == "fin" or state == "defaite":
				begin(str(arena.region))
		if state == "combat" and arena.boss != null and is_instance_valid(arena.boss):
			if arena.boss.dead:
				win()
			elif int(arena.boss.phase) > phase:
				set_phase(int(arena.boss.phase))
		return
	_end_fight()


func _end_fight() -> void:
	if not _following:
		return
	var won: bool = is_instance_valid(_arena) and str(_arena.state) == "vaincue"
	_arena = null
	_following = false
	if won:
		win()
	else:
		lose()


func _switch(clip: String) -> void:
	requests.append({"clip": clip, "at": audio_time()})
	var pb = player.get_stream_playback()
	if pb is AudioStreamPlaybackInteractive:
		pb.switch_to_clip_by_name(clip)


func _fade_out() -> void:
	state = "fondu"
	_fade_left = DEFEAT_FADE


## Section qui joue en ce moment ("" : rien).
func current_clip() -> String:
	if not player.playing or stream == null:
		return ""
	var pb = player.get_stream_playback()
	if pb is AudioStreamPlaybackInteractive:
		var i: int = pb.get_current_clip_index()
		if i >= 0 and i < stream.clip_count:
			return str(stream.get_clip_name(i))
	return ""


## Instant (s, horloge réelle) d'une demande, pour le journal des tests.
func audio_time() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _process(_delta: float) -> void:
	# Les durées suivent l'horloge réelle, pas le temps du jeu (ralenti d'Éclat, pause).
	var dt := _real_delta()
	if _following and not is_instance_valid(_arena):
		# Retour au menu : l'arène est partie avec la scène du jeu.
		_arena = null
		_following = false
		lose()
	if state == "fondu":
		_fade_left -= dt
		player.volume_db = maxf(SILENT_DB, linear_to_db(maxf(0.0, _fade_left / DEFEAT_FADE)))
		if _fade_left <= 0.0:
			stop()
	elif _end_left >= 0.0:
		_end_left -= dt
		if _end_left <= 0.0 or not player.playing:
			stop()


var _last_usec := -1


func _real_delta() -> float:
	var now := Time.get_ticks_usec()
	var d := 0.0 if _last_usec < 0 else (now - _last_usec) / 1000000.0
	_last_usec = now
	return clampf(d, 0.0, 0.25)
