## Combat calé sur le morceau du boss (musique faite à la main, boss_track.gd) : la grille des mesures
## que le boss et son arène suivent, pour que les moments forts tombent sur la musique :
##   - l'intro du morceau couvre l'arrivée (descente, invocation) : le boss devient touchable et frappe
##     au premier temps de la première boucle (l'entrée de la batterie) ;
##   - à chaque changement de phase, le drop part à la mesure suivante ; le boss se transforme pendant
##     tout le drop, invulnérable, et le combat reprend au premier temps de la boucle qui suit.
##
## Deux horloges, la même grille :
##   - quand le morceau joue (Music.hand), son horloge audio (temps d'affichage sans le ralenti) : le
##     ralenti du jeu ne la décale pas,
##     et le drop effectivement parti (section en cours du lecteur) recale la reprise sur sa mesure ;
##   - sinon (son coupé, tests sans fenêtre, robot), le temps du jeu, avancé par tick() : mêmes durées,
##     mêmes règles, combat déterministe.
## La grille est comptée en mesures depuis le début du morceau (t0 de chaque horloge) ; la reprise
## attendue est une mesure (resume_bar), pas un instant : elle vaut pour les deux horloges.
##
## Un boss sans morceau n'a pas de BossSync (for_region renvoie null) : son combat ne change pas.
extends RefCounted

const BossTrack = preload("res://scripts/boss_track.gd")
## Une demande faite moins de LOOKAHEAD secondes avant une barre part à la barre d'après (le mélangeur
## a déjà préparé ce son) : même règle ici, pour que l'estimation tombe sur la même mesure.
const LOOKAHEAD := 0.06

var region := ""
var data: Dictionary = {}
var bar := 1.3333
var beats := 4
## Clip de départ (« intro » ou « intro_court ») et ses mesures avant la première boucle.
var intro_clip := "intro"
var intro_bars := 16
## Horloge du jeu (s) et son origine ; origine de la grille sur l'horloge audio (s, temps réel).
var game_clock := 0.0
var game_t0 := 0.0
## Mesure (depuis le début du morceau) où le combat (re)prend ; -1 : rien n'est attendu.
var resume_bar := -1
## Ce qui est attendu : "intro" (arrivée), "drop" (changement de phase), "" (combat en cours).
var stage := ""
## Section demandée au lecteur pour le changement de phase en cours, et vrai une fois qu'elle a
## démarré (la reprise est alors recalée sur sa vraie mesure).
var pending_clip := ""
var _confirmed := false
var running := false


## Grille du morceau d'une région (null sans morceau).
static func for_region(id: String, from := BossTrack.DIR):
	var d := BossTrack.track_data(id, from)
	if d.is_empty():
		return null
	var s = load("res://scripts/boss_sync.gd").new()
	s.region = id
	s.data = d
	s.bar = BossTrack.bar_time(d)
	s.beats = int(d.get("bar_beats", 4))
	return s


## Durée (s) des mesures d'avant la première boucle pour un clip d'intro (« intro », « intro_court »).
func intro_length(clip := "intro") -> float:
	return _intro_bars(clip) * bar


func _intro_bars(clip: String) -> int:
	var c: Dictionary = data.get("clips", {}).get(clip, {})
	if c.is_empty():
		c = data["clips"]["intro"]
	return int(c.get("boucle_depuis", c.get("mesures", 16)))


## Le morceau commence (descente, ou entrée dans l'arène) : le combat commencera à la première boucle.
func start(clip := "intro") -> void:
	if not data.get("clips", {}).has(clip):
		clip = "intro"
	intro_clip = clip
	intro_bars = _intro_bars(clip)
	game_t0 = game_clock
	resume_bar = intro_bars
	stage = "intro"
	pending_clip = ""
	_confirmed = true
	running = true


## Le temps du jeu avance (appelé par l'arène à chaque pas).
func tick(delta: float) -> void:
	game_clock += delta
	if not running:
		return
	var h = _hand()
	if h != null and pending_clip != "" and not _confirmed and h.current_clip() == pending_clip:
		# Le drop vient de partir : la reprise suit sa vraie mesure.
		_confirmed = true
		resume_bar = int(round(_now_bars(h))) + _drop_bars(pending_clip)
	if stage != "" and left() <= 0.0:
		stage = ""
		pending_clip = ""


## Le boss passe en phase n : le drop qui y mène part à la mesure suivante, le combat reprend après.
## Renvoie le temps (s) d'ici la reprise (0 si le morceau n'a pas de drop pour cette phase).
func phase(n: int) -> float:
	if not running:
		return 0.0
	var clip := "drop_%d" % (n - 1)
	if not data.get("clips", {}).has(clip):
		return 0.0
	var h = _hand()
	var now := _now_bars(h)
	var start_bar := int(ceil(now + LOOKAHEAD / bar - 0.0001))
	# Pendant l'intro, le drop ne peut pas partir avant la mesure où il est demandé : même règle.
	resume_bar = start_bar + _drop_bars(clip)
	stage = "drop"
	pending_clip = clip
	_confirmed = false
	return left()


## Le combat s'arrête (mort du boss ou du héros).
func stop() -> void:
	running = false
	stage = ""
	resume_bar = -1
	pending_clip = ""


## Vrai tant que le boss attend la musique (arrivée, transformation) : il ne frappe pas et ne prend
## pas de dégâts.
func waiting() -> bool:
	return running and stage != "" and left() > 0.0


## Temps (s) d'ici la reprise du combat (0 si rien n'est attendu).
func left() -> float:
	if not running or resume_bar < 0:
		return 0.0
	return maxf(0.0, (resume_bar - _now_bars(_hand())) * bar)


## Mesures écoulées depuis le début du morceau (fractionnaire).
func bars_now() -> float:
	return _now_bars(_hand())


## Avancée dans le temps en cours (0 → 1), pour les pulsations des animations.
func beat_k() -> float:
	return fposmod(bars_now() * beats, 1.0)


## Avancée de l'attente en cours (0 au début de la transformation ou de l'arrivée, 1 à la reprise),
## « total » étant sa durée d'ensemble (s).
func wait_k(total: float) -> float:
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - left() / total, 0.0, 1.0)


func _drop_bars(clip: String) -> int:
	var c: Dictionary = data["clips"][clip]
	return int(c.get("boucle_depuis", 4))


## Les robots (« -- --autotest… ») suivent le temps du jeu même quand le morceau joue : l'horloge
## audio avance en temps réel, et une machine chargée changerait leur combat d'une partie à l'autre.
static var _robot := -1


static func robot() -> bool:
	if _robot < 0:
		_robot = 0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--autotest"):
				_robot = 1
	return _robot == 1


## Lecteur qui joue ce morceau (null : horloge du jeu).
func _hand():
	if robot():
		return null
	var music = Engine.get_main_loop().root.get_node_or_null("Music") if Engine.get_main_loop() is SceneTree else null
	if music == null or music.get("hand") == null:
		return null
	var h = music.hand
	if h.active() and h.boss_id == region and h.grid_t0 >= 0.0 and h.clip_start == intro_clip:
		return h
	return null


func _now_bars(h) -> float:
	if h != null:
		return (h.audio_time() - h.grid_t0) / bar
	return (game_clock - game_t0) / bar
