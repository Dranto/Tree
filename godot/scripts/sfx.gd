## Bruitages : un petit parc de lecteurs, des sons générés par le code (tools/gen-sounds.sh). Un son qui a des notes
## (pizz, marimba, cloche…) est transposé dans la gamme de la zone où est le héros, sur l'accord qui sonne
## (harmony.gd) : rien ne sonne faux. Les grands sons (« duck ») baissent un instant la musique.
## Un limiteur sur la sortie générale évite la saturation quand tout s'additionne.
##
## Contre la lassitude des sons répétés (attaques cumulées, impacts en rafale ; retour du premier testeur) :
## - au plus MAX_SAME sons identiques par fenêtre de WINDOW_MSEC, et au moins MIN_GAP_MSEC entre deux départs ;
## - au plus MAX_VOICES voix d'un même son à la fois ;
## - un son qui revient très souvent baisse (DENSITY_* : fenêtre glissante d'une seconde), de même que les
##   attaques cumulées ensemble (GROUP_*, groupe « attaque ») et tout le combat quand les bruitages s'empilent
##   (CROWD_*) ;
## - variantes rendues (« variants » dans synth.gd) tirées sans jamais rejouer la même deux fois de suite ;
## - un son à notes répété en rafale passe d'une note de l'accord à l'autre (Harmony.shifts_in_key), toujours
##   dans la gamme de la zone ; seul, il garde sa note.
## Les signaux (« annonce », sons des boss, sons qui baissent la musique) et l'interface n'ont que la première limite.
## Usage : Sfx.play("impact", position_du_monde). Sans position, le son est joué à plein volume.
extends Node

const Synth = preload("res://scripts/synth.gd")
const Regions = preload("res://scripts/regions.gd")
const Harmony = preload("res://scripts/harmony.gd")

const BUS := "Effets" # i18n: non (bus audio)
const POOL := 16
const WINDOW_MSEC := 50
const MAX_SAME := 3
## Écart minimal entre deux départs d'un même son : deux coups dans la même image ne font qu'un son.
const MIN_GAP_MSEC := 14
## Voix d'un même son jouées à la fois, au plus ; une voix compte pendant au plus VOICE_MSEC (le reste du
## fichier n'est que la queue de réverbération).
const MAX_VOICES := 4
const VOICE_MSEC := 500.0
## Au-delà de DENSITY_FREE départs par seconde d'un même son, il baisse de DENSITY_DB par doublement (au plus
## DENSITY_MAX_DB).
const DENSITY_FREE := 3.0
const DENSITY_DB := 3.5
const DENSITY_MAX_DB := 10.0
## Tous bruitages de combat confondus : au-delà de CROWD_FREE départs par seconde, chacun baisse de CROWD_DB par
## doublement (au plus CROWD_MAX_DB).
const CROWD_FREE := 10.0
const CROWD_DB := 1.5
const CROWD_MAX_DB := 4.5
## Groupe de sons (« attaque » : toutes les formes d'attaque, qui se cumulent et partent sans cesse) : au-delà
## de GROUP_FREE départs par seconde dans le groupe, chacun baisse de GROUP_DB par doublement (au plus GROUP_MAX_DB).
const GROUP_FREE := 2.5
const GROUP_DB := 3.0
const GROUP_MAX_DB := 8.0
const DENSITY_WINDOW_MSEC := 1000
## Un son à notes rejoué moins de STREAK_MSEC après le précédent continue sa marche sur l'accord.
const STREAK_MSEC := 900
## Sons exclus des limites de lassitude (signaux, interface) : seule la fenêtre WINDOW_MSEC les touche.
const CALM_EXEMPT := ["annonce", "clic", "survol"]
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
## Dernier son lancé et sa hauteur (lus par les tests).
var last_name := ""
var last_pitch := 1.0
## Variation de hauteur d'un son qui a des notes (±0,3 % : quelques cents, il reste juste).
const TONAL_WOBBLE := 0.003

## Faux : l'ancien comportement (limite de 50 ms seule, variantes au hasard, note fixe) ; « -- --sfx-calm=0 »
## (mesure avant/après, tools/sons-fatigue.sh).
var calm := true
## Horloge des limites (ms) : avance avec le jeu (_process), donc aussi en --fixed-fps sans écran.
var clock_msec := 0.0
## Fin (ms) des voix en cours de chaque son, départs récents (fenêtre glissante) par son et pour le combat.
var voices: Dictionary = {}
var starts: Dictionary = {}
var crowd: Array = []
## Dernière variante et marche sur l'accord de chaque son : {"at", "step", "variant"}.
var memo: Dictionary = {}
## Demandes reçues (jouées ou non), lues par les tests et la mesure.
var requested := 0
var last_gain := 0.0
## « -- --sfx-log=<fichier> » : chaque demande y est écrite (ms ; son ; jouée ou raison ; hauteur ; gain dB ;
## variante ; durée ms), même sans écran (rien n'est alors entendu) : mesure de tools/sons-fatigue.sh.
var _log: FileAccess


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	enabled = not is_silent_run()
	ensure_bus(BUS)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sfx-log="):
			_log = FileAccess.open(a.trim_prefix("--sfx-log="), FileAccess.WRITE)
		elif a == "--sfx-calm=0":
			calm = false
	if _log != null:
		_log.store_line("ms;son;etat;hauteur;gain_db;variante;duree_ms")
		rng.seed = 1
	if not enabled and _log == null:
		return
	if enabled:
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


## Nom du son à jouer : sa version régionale « <nom>@<région> » s'il en a une (synth.gd), pour la région
## de la position (ou, sans position, la région où joue la musique), sinon le son commun.
func regional(name: String, pos := Vector2.INF) -> String:
	var reg := Regions.region_at(pos) if pos != Vector2.INF else _music_region()
	var key := name + "@" + reg
	return key if reg != "" and streams.has(key) else name


func _music_region() -> String:
	var music = get_node_or_null("/root/Music")
	return str(music.region) if music != null else ""


func _process(delta: float) -> void:
	clock_msec += delta * 1000.0


func _exit_tree() -> void:
	if _log != null:
		_log.close()
		_log = null


## pitch : hauteur de base (1 = normale), pour caler un son sur l'action (ex. enchaînement de ramassages).
## Un son qui a des versions régionales (impact@spore…) prend celle de la région où il se produit.
## group : groupe de sons qui baissent ensemble quand ils reviennent souvent (« attaque », attack.gd).
func play(name: String, pos := Vector2.INF, pitch := 1.0, group := "") -> void:
	if (not enabled and _log == null) or not streams.has(name):
		return
	name = regional(name, pos)
	requested += 1
	var now := clock_msec
	var list: Array = recent.get(name, [])
	list = list.filter(func(t): return now - t < WINDOW_MSEC)
	recent[name] = list
	if list.size() >= MAX_SAME:
		_note(name, "fenetre")
		return
	var gain := 0.0
	if pos != Vector2.INF and is_instance_valid(listener):
		var d := listener.global_position.distance_to(pos)
		if d > HEARING:
			_note(name, "loin")
			return
		gain = -14.0 * d / HEARING
	var tame := calm and is_tamed(name)
	var live: Array = (voices.get(name, []) as Array).filter(func(t): return t > now)
	voices[name] = live
	if tame:
		if not list.is_empty() and now - float(list[-1]) < MIN_GAP_MSEC:
			_note(name, "ecart")
			return
		if live.size() >= MAX_VOICES:
			_note(name, "voix")
			return
		gain += density_db(name, now, group)
	var p: AudioStreamPlayer = _free_player() if enabled else null
	if enabled and p == null:
		_note(name, "parc")
		return
	list.append(now)
	recent[name] = list
	var st = streams[name]
	var variant := pick_variant(name, st.size() if st is Array else 1)
	var stream: AudioStream = st[variant] if st is Array else st
	var ps := pitch_of(name, variant, pitch, now)
	_remember(name, now, variant)
	var length := 1000.0 * stream.get_length() / maxf(ps, 0.01)
	live.append(now + minf(length, VOICE_MSEC))
	if tame:
		_count_start(name, now, group)
	if p != null:
		p.stream = stream
		p.volume_db = gain
		p.pitch_scale = ps
		p.play()
	played += 1
	last_name = name
	last_pitch = ps
	last_gain = gain
	if _log != null:
		_log.store_line("%d;%s;joue;%.4f;%.2f;%d;%d" % [roundi(now), name, ps, gain, variant, roundi(length)])
	var duck := float(Synth.SOUNDS.get(name, {}).get("duck", 0.0))
	if duck > 0.0:
		var music = get_node_or_null("/root/Music")
		if music != null:
			music.duck(duck * (1.0 if gain > -6.0 else 0.5))


func _note(name: String, why: String) -> void:
	if _log != null:
		_log.store_line("%d;%s;%s;;;;" % [roundi(clock_msec), name, why])


## Vrai si les limites de lassitude s'appliquent à ce son (pas un signal, pas l'interface).
static func is_tamed(name: String) -> bool:
	var base := name.get_slice("@", 0)
	if base in CALM_EXEMPT or "_boss_" in base:
		return false
	return float(Synth.SOUNDS.get(name, {}).get("duck", 0.0)) <= 0.0


## Baisse (dB, négative) d'un son selon combien de fois il est parti dans la dernière seconde, et selon la
## foule de tous les bruitages de combat.
func density_db(name: String, now: float, group := "") -> float:
	var mine := _recent_starts(name, now)
	crowd = crowd.filter(func(t): return now - t < DENSITY_WINDOW_MSEC)
	var db := -_over(mine.size() + 1, DENSITY_FREE, DENSITY_DB, DENSITY_MAX_DB) \
		- _over(crowd.size() + 1, CROWD_FREE, CROWD_DB, CROWD_MAX_DB)
	if group != "":
		db -= _over(_recent_starts("#" + group, now).size() + 1, GROUP_FREE, GROUP_DB, GROUP_MAX_DB)
	return db


func _recent_starts(key: String, now: float) -> Array:
	var list: Array = (starts.get(key, []) as Array).filter(func(t): return now - t < DENSITY_WINDOW_MSEC)
	starts[key] = list
	return list


static func _over(rate: float, free: float, db: float, cap: float) -> float:
	return 0.0 if rate <= free else minf(cap, db * log(rate / free) / log(2.0))


func _count_start(name: String, now: float, group := "") -> void:
	for key in ([name] if group == "" else [name, "#" + group]):
		var list: Array = starts.get(key, [])
		list.append(now)
		starts[key] = list
	crowd.append(now)


## Variante à jouer : au hasard, mais jamais celle de la fois précédente (sons à plusieurs variantes).
func pick_variant(name: String, count: int) -> int:
	if count <= 1:
		return 0
	if not calm:
		return rng.randi() % count
	var last := int(memo.get(name, {}).get("variant", -1))
	var v := rng.randi() % (count - 1 if last >= 0 else count)
	return v + 1 if last >= 0 and v >= last else v


func _remember(name: String, now: float, variant: int) -> void:
	var m: Dictionary = memo.get(name, {})
	m["variant"] = variant
	m["at"] = now
	memo[name] = m


## Hauteur de lecture : un son qui a des notes est accordé sur ce qui sonne (gamme de la zone, accord du
## moment) ; répété en rafale, il passe d'une note de l'accord à l'autre (toujours dans la gamme), sauf si le
## jeu demande sa hauteur. Les autres
## gardent une variation au hasard.
func pitch_of(name: String, variant := 0, pitch := 1.0, now := -1.0) -> float:
	if Harmony.is_tonal(name):
		var step := 0
		# Une hauteur demandée par le jeu (ramassages qui montent) garde son sens : pas de marche.
		if calm and now >= 0.0 and pitch == 1.0 and is_tamed(name):
			var m: Dictionary = memo.get(name, {})
			if m.has("at") and now - float(m["at"]) < STREAK_MSEC:
				step = int(m.get("step", 0)) + 1
			m["step"] = step
			memo[name] = m
		return Harmony.pitch_for(name, harmony(), variant, pitch, step) * rng.randf_range(1.0 - TONAL_WOBBLE, 1.0 + TONAL_WOBBLE)
	return pitch * rng.randf_range(0.97, 1.03) if pitch != 1.0 else rng.randf_range(0.94, 1.06)


## Ce qui sonne : celui de la musique, ou à défaut la gamme du monde (Ronce).
func harmony() -> Dictionary:
	var music = get_node_or_null("/root/Music")
	if music != null and music.has_method("harmony"):
		return music.harmony()
	return Harmony.context(Harmony.region(""))


func _free_player() -> AudioStreamPlayer:
	for p in players:
		if not p.playing:
			return p
	return null
