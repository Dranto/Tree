## Musiques de boss faites à la main : un morceau par boss, découpé aux mesures par tools/boss-track.sh
## (assets/music/hand/<boss>.json et assets/music/hand/<boss>/<clip>.ogg, format dans data/README.md › Son).
## Clips : intro (intro puis boucle_1), drop_<n> (drop_n puis boucle_<n+1>), fin, defaite ; chaque ogg
## boucle de lui-même sur sa dernière section (loop_offset), à l'échantillon près.
##
## Le morceau suit le combat, sur l'horloge audio (AudioStreamInteractive : les changements tombent au
## début d'une mesure, à l'échantillon près, et le ralenti d'Éclat — Engine.time_scale — ne le touche pas) :
##   approche (facultatif, clip « approche ») : à l'approche d'une arène ouverte, le début du morceau
##                        monte sous la musique du monde avec la distance (approach), puis à l'entrée
##                        l'intro part à la mesure suivante (enter) : la grille reste celle de l'approche ;
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

## Boss suivi ("" : aucun morceau ne joue) et état : "approche", "combat", "fin", "defaite", "fondu".
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
## Horloge audio (s) : le temps réel en jeu (le ralenti du jeu ne la touche pas) ; dans le Movie Maker,
## qui mélange le son image par image, le nombre d'images sur leur cadence.
var clock := 0.0
var _movie_fps := 0.0
## Origine de la grille des mesures sur cette horloge : l'instant où le premier échantillon du morceau
## sort (lu par boss_sync.gd) ; -1 sans morceau. Et le clip de départ.
var grid_t0 := -1.0
var clip_start := "intro"
## Mesure (comptée depuis grid_t0) où l'intro a commencé : 0, sauf après une approche.
var intro_bar := 0
## Approche : niveau visé (0 → 1, selon la distance à l'arène) et volume actuel (linéaire), temps passé
## à zéro, et arène approchée.
var approach_target := 0.0
var approach_gain := 0.0
var _approach_quiet := 0.0
var _approach_arena = null
## Journal des demandes (tests) : [{"clip": nom, "at": temps audio de la demande}].
var requests: Array = []
static var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Movie Maker : sa cadence est celle de --fixed-fps, que Godot ne rend pas lisible ; l'outil de film
	# la redonne après « -- » (--movie-fps=30). Sans elle, la cadence du réglage editor/movie_writer/fps.
	if OS.has_feature("movie"):
		_movie_fps = float(ProjectSettings.get_setting("editor/movie_writer/fps", 60))
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--movie-fps="):
				_movie_fps = float(arg.get_slice("=", 1))
	clock = _clock_now()
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
	# L'intro elle-même ne se demande qu'après l'approche (enter), à la mesure suivante aussi.
	var approach := names.has("approche")
	for i in names.size():
		if names[i] != "intro" or approach:
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


## Part du morceau dans le mélange (0 → 1) : la musique du monde s'efface d'autant (music.gd).
## Pendant l'approche, le volume de l'approche ; sinon 1 tant qu'il joue.
func level() -> float:
	if state == "approche":
		return approach_gain
	return 1.0 if active() else 0.0


# --- Approche ---
## Volume de l'approche : il suit la distance en APPROACH_RISE s (monte) ou APPROACH_FALL s (baisse).
const APPROACH_RISE := 1.2
const APPROACH_FALL := 2.5
## Rien à entendre pendant APPROACH_LINGER s : l'approche s'arrête (elle repartira du début).
const APPROACH_LINGER := 1.5
## Volume de l'approche au plus près de l'arène, avant l'entrée (l'intro monte au plein volume).
const APPROACH_MAX := 0.85


## Le héros approche l'arène ouverte d'un boss qui a un clip « approche » : level (0 → 1) selon la
## distance. Lance l'approche au premier niveau non nul ; ne change rien pendant un combat.
func approach(arena, lvl: float) -> void:
	if state != "" and state != "approche":
		return
	approach_target = clampf(lvl, 0.0, 1.0)
	if state == "approche":
		if arena != _approach_arena and arena != null:
			_approach_arena = arena
		return
	if approach_target <= 0.0 or arena == null:
		return
	var id := str(arena.region)
	var data := track_data(id, dir)
	if data.is_empty() or not data["clips"].has("approche"):
		return
	if begin(id, "approche"):
		state = "approche"
		_in_t = -1.0
		approach_gain = 0.0
		_approach_quiet = 0.0
		_approach_arena = arena
		player.volume_db = SILENT_DB


## Vrai pendant l'approche du morceau de ce boss.
func approaching(id: String) -> bool:
	return state == "approche" and boss_id == id


## Entrée dans l'arène pendant l'approche : l'intro part au début de la mesure suivante (la dernière
## mesure avant le drop, pendant que le boss charge), puis la première boucle. Renvoie la mesure (depuis
## grid_t0) où l'intro commence ; -1 sans approche.
func enter() -> int:
	if state != "approche":
		return -1
	var data := track_data(boss_id, dir)
	var bar := bar_time(data)
	var now := (audio_time() - grid_t0) / bar
	# Même règle que boss_sync.gd › LOOKAHEAD : une demande trop près d'une barre part à la suivante.
	intro_bar = int(ceil(now + 0.06 / bar - 0.0001))
	state = "combat"
	phase = 1
	clip_start = "intro"
	_approach_arena = null
	# Le volume rejoint le plein pendant le temps qui reste avant l'intro.
	_in_from = approach_gain
	_in_len = maxf(0.05, (intro_bar - now) * bar)
	_in_t = 0.0
	_switch("intro")
	return intro_bar


## Éveil du boss : intro puis boucle_1. Faux (et rien ne change) si le boss n'a pas de morceau.
## Le morceau monte en douceur depuis le silence (s), pendant que la musique du monde s'efface
## (music.gd › HAND_FADE) : pas de rupture à l'entrée du combat.
const FADE_IN := 2.5
var _in_t := -1.0
## Fondu d'entrée en cours : volume de départ (linéaire) et durée (s).
var _in_from := 0.0
var _in_len := FADE_IN


func begin(id: String, clip := "intro") -> bool:
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
	if not data["clips"].has(clip):
		clip = "intro"
	clip_start = clip
	intro_bar = 0
	stream.initial_clip = clip_names(data).find(clip)
	player.stream = stream
	_in_t = 0.0
	_in_from = 0.0
	# Une intro courte (la Mère-Ronce : une mesure) ne doit pas se perdre dans le fondu.
	var intro_len := float(data["clips"][clip].get("boucle_depuis", 0)) * bar_time(data)
	_in_len = clampf(intro_len * 0.25, 0.2, FADE_IN)
	player.volume_db = SILENT_DB
	player.play()
	# Le premier échantillon sort au prochain mélange, après la latence de sortie.
	grid_t0 = audio_time() + AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	requests.append({"clip": clip, "at": audio_time()})
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
	if state == "approche":
		_fade_out()
		return
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
	_in_t = -1.0
	boss_id = ""
	grid_t0 = -1.0
	_arena = null
	_following = false
	_end_left = -1.0
	_fade_left = 0.0
	approach_gain = 0.0
	approach_target = 0.0
	_approach_arena = null
	intro_bar = 0


## Suit l'arène dont le morceau joue à ce pas (null : aucune) : en combat, ou pendant l'arrivée
## (music_on : la descente de la finale). Son « sync » (boss_sync.gd) dit par quel clip commencer.
func follow(arena) -> void:
	if arena != null and (arena.in_combat() or (arena.has_method("music_on") and arena.music_on())):
		if arena != _arena or not _following:
			_arena = arena
			_following = true
			if state == "approche" and boss_id == str(arena.region):
				# L'arène l'a peut-être déjà fait (boss_sync.gd › start) : l'intro part à la mesure suivante.
				enter()
			elif state == "" or state == "fondu" or state == "fin" or state == "defaite" or state == "approche":
				var sync = arena.get("sync")
				begin(str(arena.region), sync.intro_clip if sync != null else "intro")
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
	_fade_from = approach_gain if state == "approche" else 1.0
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


## Instant (s, horloge audio) d'une demande.
func audio_time() -> float:
	return _clock_now()


func _process(_delta: float) -> void:
	# Les durées suivent l'horloge audio, pas le temps du jeu (ralenti d'Éclat, pause).
	var now := _clock_now()
	var dt := clampf(now - clock, 0.0, 0.25)
	clock = now
	if _following and not is_instance_valid(_arena):
		# Retour au menu : l'arène est partie avec la scène du jeu.
		_arena = null
		_following = false
		lose()
	if state == "approche":
		_approach_step(dt)
	elif _in_t >= 0.0 and state != "fondu":
		_in_t += dt
		var k := clampf(_in_t / _in_len, 0.0, 1.0)
		player.volume_db = maxf(SILENT_DB, linear_to_db(lerpf(_in_from, 1.0, sin(k * PI / 2.0))))
		if k >= 1.0:
			_in_t = -1.0
	if state == "fondu":
		_fade_left -= dt
		player.volume_db = maxf(SILENT_DB, linear_to_db(maxf(0.0, _fade_left / DEFEAT_FADE) * _fade_from))
		if _fade_left <= 0.0:
			stop()
	elif _end_left >= 0.0:
		_end_left -= dt
		if _end_left <= 0.0 or not player.playing:
			stop()


var _fade_from := 1.0


## Approche : le volume suit la distance ; plus rien à entendre un moment, elle s'arrête.
func _approach_step(dt: float) -> void:
	var want := approach_target * APPROACH_MAX
	var rate := (1.0 / APPROACH_RISE) if want > approach_gain else (1.0 / APPROACH_FALL)
	approach_gain = move_toward(approach_gain, want, rate * dt)
	player.volume_db = maxf(SILENT_DB, linear_to_db(approach_gain)) if approach_gain > 0.001 else SILENT_DB
	if approach_target <= 0.0 and approach_gain <= 0.001:
		_approach_quiet += dt
		if _approach_quiet >= APPROACH_LINGER:
			stop()
	else:
		_approach_quiet = 0.0


func _clock_now() -> float:
	if _movie_fps > 0.0:
		return Engine.get_process_frames() / _movie_fps
	return Time.get_ticks_usec() / 1000000.0
