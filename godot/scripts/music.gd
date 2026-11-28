## Musique dynamique en couches et ambiance sonore.
##
## Chaque région (et le monde, « ») a jusqu'à cinq couches de 24 s générées par le code (music_synth.gd) :
## sombre et lumineux (exploration, mélangées selon la vie du sol), combat (percussions et basse, ajoutées
## quand des Flétris sont proches), coeur (pendant le siège d'un Cœur) et boss (thème du boss, seul).
## Toutes les couches ont la même boucle et partent toujours au même point de l'horloge musicale : elles
## restent en phase, et passer de l'une à l'autre n'est qu'un fondu de volume, sans coupure ni silence.
## Une couche inaudible est arrêtée (rien à mixer) et relancée en phase quand elle remonte.
##
## L'ambiance sonore (vent, eau, oiseaux…) suit la même logique sur le bus « Ambiance » : une nappe de
## terre morte et une de terre vivante par région (assets/ambience/).
##
## Appels du jeu : set_mood(vie, région), set_combat(0 à 1), set_heart(0 à 1), set_boss(vrai/faux),
## duck(part) pour baisser un instant la musique sous un grand bruitage, follow_boss(arène) à chaque pas.
##
## Musiques de boss faites à la main (boss_track.gd, assets/music/hand/) : quand le boss du combat en a
## une, elle joue à la place des couches du code, qui se taisent (HAND_FADE) ; l'ambiance reste baissée
## comme pour tout boss. Un boss sans morceau garde la couche « boss » du code.
extends Node

const BUS := "Musique" # i18n: non (bus audio)
const AMB_BUS := "Ambiance" # i18n: non (bus audio)
const SfxScript = preload("res://scripts/sfx.gd")
const BossTrack = preload("res://scripts/boss_track.gd")
const RegionAudio = preload("res://scripts/region_audio.gd")
## Durée des couches de musique (music_synth.gd › LOOP) ; les nappes d'ambiance bouclent sur 12 s.
const LOOP := 24.0
## Vitesses des fondus (part du mélange par seconde).
const REGION_FADE := 0.5
const MIX_FADE := 0.5
const COMBAT_IN := 1.2
const COMBAT_OUT := 0.25
## Le combat reste dans la musique quelques secondes après le dernier Flétri proche (pas de va-et-vient).
const COMBAT_HOLD := 4.0
const HEART_FADE := 0.6
const BOSS_FADE := 0.8
## Fondu croisé (s) entre la musique du monde (couches du code) et un morceau de boss fait à la main :
## le monde s'efface pendant que le morceau monte (boss_track.gd › FADE_IN), sans rupture.
const HAND_FADE := 3.0
const DUCK_RECOVER := 0.7
const SILENT_DB := -60.0
## L'ambiance sonore baisse pendant un combat de boss.
const BED_BOSS := 0.55

var enabled := true
var started := false
## Mélange visé et actuel entre sombre (0) et lumineux (1).
var target := 0.0
var mix := 0.0
var combat_target := 0.0
var combat := 0.0
var heart_target := 0.0
var heart := 0.0
var boss_target := 0.0
var boss := 0.0
var duck_gain := 1.0
var _combat_hold := 0.0
## Région dont on entend la musique ("" : le monde) et région de l'ambiance.
var region := ""
var bed_region := ""
## Groupes de couches : id ("" : le monde) -> {"players": {couche: AudioStreamPlayer}, "gain": 0 à 1}.
var groups: Dictionary = {}
## Nappes d'ambiance : id -> {"players": {"mort": …, "vif": …}, "gain": 0 à 1}.
var beds: Dictionary = {}
## Position dans la boucle (s), recalée sur une couche qui joue.
var clock := 0.0
var _missing: Dictionary = {}
## Lecteur des morceaux de boss faits à la main, et part (0 à 1) dont ils remplacent les couches du code.
var hand: Node
var hand_k := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = not SfxScript.is_silent_run()
	SfxScript.ensure_bus(BUS)
	SfxScript.ensure_bus(AMB_BUS)
	if not enabled:
		return
	hand = BossTrack.new()
	add_child(hand)
	_ensure_group("")
	_ensure_bed("")
	groups[""]["gain"] = 1.0
	beds[""]["gain"] = 1.0


## Garde la compatibilité avec les tests qui ajoutent des régions : rien à précharger, tout se crée à la demande.
func refresh_regions() -> void:
	_missing.clear()


func _ensure_group(id: String) -> bool:
	if groups.has(id):
		return true
	if _missing.has("m" + id):
		return false
	var style := {} if id == "" else RegionAudio.music_style(id)
	if id != "" and style.is_empty():
		_missing["m" + id] = true
		return false
	var players := {}
	for layer in RegionAudio.music_layers(style):
		var p := _layer(RegionAudio.music_path(id, layer), BUS)
		if p != null:
			players[layer] = p
	if players.is_empty():
		_missing["m" + id] = true
		return false
	groups[id] = {"players": players, "gain": 0.0}
	return true


func _ensure_bed(id: String) -> bool:
	if beds.has(id):
		return true
	if _missing.has("b" + id):
		return false
	if id != "" and RegionAudio.bed(id).is_empty():
		_missing["b" + id] = true
		return false
	var players := {}
	for file in RegionAudio.BED_STATES:
		var p := _layer(RegionAudio.bed_path(id, file), AMB_BUS)
		if p != null:
			players[file] = p
	if players.is_empty():
		_missing["b" + id] = true
		return false
	beds[id] = {"players": players, "gain": 0.0}
	return true


## Lecteur d'une piste en boucle (null si le fichier manque).
func _layer(path: String, bus: String) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	var s := SfxScript.load_wav(path)
	if s == null:
		return null
	s = s.duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(round(s.get_length() * s.mix_rate))
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = s
	p.volume_db = SILENT_DB
	add_child(p)
	return p


## Lance la musique (sans effet si elle joue déjà).
func start() -> void:
	if not enabled or started:
		return
	started = true
	_apply()


func stop() -> void:
	started = false
	if hand != null:
		hand.stop()
	if enabled:
		for p in _all_players():
			p.stop()


func _all_players() -> Array:
	var out: Array = []
	for d in [groups, beds]:
		for id in d:
			out.append_array(d[id]["players"].values())
	return out


## vie : vie du sol sous le joueur, de 0 à 1. En dessous de 0,15 c'est la terre morte, au-dessus de 0,6 la prairie.
## reg : région où se trouve le joueur ("" : hors région, musique du monde).
func set_mood(vie: float, reg := "") -> void:
	target = smoothstep(0.15, 0.6, clampf(vie, 0.0, 1.0))
	region = reg if reg != "" and enabled and _ensure_group(reg) else ""
	bed_region = reg if reg != "" and enabled and _ensure_bed(reg) else ""


## Intensité du combat autour du joueur (0 : calme, 1 : mêlée). Retombe après COMBAT_HOLD secondes.
func set_combat(level: float) -> void:
	level = clampf(level, 0.0, 1.0)
	if level > 0.0:
		_combat_hold = COMBAT_HOLD
		combat_target = level


## Siège d'un Cœur en cours (1) ou non (0).
func set_heart(level: float) -> void:
	heart_target = clampf(level, 0.0, 1.0)


## Combat de boss en cours : le thème du boss de la région remplace les autres couches.
func set_boss(on: bool) -> void:
	boss_target = 1.0 if on else 0.0


## Arène en combat à ce pas (null : aucune) : le morceau du boss, s'il en a un, suit ses phases et sa fin.
func follow_boss(arena) -> void:
	if hand != null and started:
		hand.follow(arena)


## Approche d'une arène ouverte (null : aucune) : son morceau, s'il a une approche, monte avec
## « level » (0 → 1) sous la musique du monde, qui s'efface d'autant (boss_track.gd › approach).
func approach_boss(arena, level: float) -> void:
	if hand != null and started:
		hand.approach(arena, level)


## Vrai pendant qu'un morceau de boss fait à la main tient la musique.
func hand_playing() -> bool:
	return hand != null and hand.active()


## Baisse brève de la musique (part de 0 à 1) sous un grand bruitage (mort d'un boss, Cœur purifié…).
func duck(amount: float) -> void:
	duck_gain = minf(duck_gain, 1.0 - clampf(amount, 0.0, 1.0) * 0.7)


func _process(delta: float) -> void:
	_combat_hold -= delta
	if _combat_hold <= 0.0:
		combat_target = 0.0
	mix = move_toward(mix, target, MIX_FADE * delta)
	combat = move_toward(combat, combat_target, (COMBAT_IN if combat_target > combat else COMBAT_OUT) * delta)
	heart = move_toward(heart, heart_target, HEART_FADE * delta)
	boss = move_toward(boss, boss_target, BOSS_FADE * delta)
	# L'approche d'une arène (boss_track.gd) ne prend que sa part : la musique du monde s'efface avec elle.
	var hand_want: float = hand.level() if hand != null else 0.0
	hand_k = move_toward(hand_k, hand_want, delta / (HAND_FADE if hand_want >= 1.0 or hand_k > hand_want else 1.0))
	duck_gain = move_toward(duck_gain, 1.0, DUCK_RECOVER * delta)
	for id in groups:
		groups[id]["gain"] = move_toward(groups[id]["gain"], 1.0 if id == region else 0.0, REGION_FADE * delta)
	for id in beds:
		beds[id]["gain"] = move_toward(beds[id]["gain"], 1.0 if id == bed_region else 0.0, REGION_FADE * delta)
	_tick_clock(delta)
	_apply()


## Horloge musicale : recalée sur une couche qui joue, sinon avancée à la main.
func _tick_clock(delta: float) -> void:
	for id in groups:
		for p in groups[id]["players"].values():
			if p.playing:
				clock = fposmod(p.get_playback_position() + AudioServer.get_time_since_last_mix(), LOOP)
				return
	clock = fposmod(clock + delta, LOOP)


## Volume de chaque couche d'un groupe (0 à 1), selon l'exploration, le combat, le Cœur et le boss.
func layer_gains(players: Dictionary) -> Dictionary:
	var has_boss := players.has("boss")
	var b := boss if has_boss else 0.0
	# Sans thème de boss, le combat en tient lieu.
	var c := maxf(combat, 0.0 if has_boss else boss)
	var explore := (1.0 - b) * (1.0 - 0.35 * c) * (1.0 - 0.5 * heart)
	return {
		"sombre": cos(mix * PI / 2.0) * explore,
		"lumineux": sin(mix * PI / 2.0) * explore,
		"combat": sin(c * PI / 2.0) * (1.0 - b),
		"coeur": sin(heart * PI / 2.0) * (1.0 - b),
		"boss": sin(b * PI / 2.0),
	}


## Mélange à puissance constante : le volume total reste stable pendant les fondus.
func _apply() -> void:
	if not enabled:
		return
	for id in groups:
		var g: Dictionary = groups[id]
		var gains := layer_gains(g["players"])
		var reg_g := sin(float(g["gain"]) * PI / 2.0) * duck_gain * cos(hand_k * PI / 2.0)
		for layer in g["players"]:
			_set_volume(g["players"][layer], float(gains.get(layer, 0.0)) * reg_g)
	for id in beds:
		var g: Dictionary = beds[id]
		var reg_g := sin(float(g["gain"]) * PI / 2.0) * (1.0 - (1.0 - BED_BOSS) * boss)
		_set_volume(g["players"].get("mort"), cos(mix * PI / 2.0) * reg_g)
		_set_volume(g["players"].get("vif"), sin(mix * PI / 2.0) * reg_g)


func _set_volume(p: AudioStreamPlayer, lin: float) -> void:
	if p == null:
		return
	p.volume_db = _db(lin)
	if not started:
		return
	if lin >= 0.001 and not p.playing and p.stream != null:
		p.play(fposmod(clock, p.stream.get_length()))
	elif lin < 0.001 and p.playing:
		p.stop()


static func _db(lin: float) -> float:
	return SILENT_DB if lin < 0.001 else maxf(SILENT_DB, linear_to_db(lin))
