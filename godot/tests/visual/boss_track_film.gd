## Film du combat contre la Flétrissure avec sa musique faite à la main (tools/boss-track-film.sh) :
## le vrai jeu, le héros invulnérable, et des coups forcés pour tenir en ~1 min 40 : descente par la
## brèche et invocation (intro), combat à l'entrée de la batterie (boucle_1), mue de la phase 2 sur
## drop_1, transformation sur drop_2, mort (fin). Les moments sont imprimés (« FILM »).
## Rien n'est comparé : c'est un outil. Lancer avec --write-movie (Movie Maker : image et son calés).
extends Node

const MainScene = preload("res://scenes/main.tscn")
const Regions = preload("res://scripts/regions.gd")

## Après la reprise du combat (s) : le coup qui fait passer en phase 2, puis en phase 3, puis la mort.
const HIT2_AFTER := 8.0
const HIT3_AFTER := 10.0
const KILL_AFTER := 12.0
## Temps laissé à la fin du morceau après la mort (s).
const END_AFTER := 13.0

var main
var t := 0.0
var step := 0
var _seen_phase := 1
var _mark := 0.0
var _waited := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = MainScene.instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	add_child(main)
	main.tree_ui.play_intro = false
	await get_tree().process_frame
	await get_tree().process_frame
	main.autotest = false
	main.spawn_timer = 1.0e9
	for id in Regions.ids():
		Game.flags[Regions.heart_flag(id)] = true
		Game.flags[Regions.boss_flag(id)] = true
		Game.flags[Regions.ending_flag(id)] = true
	Game.level = 20
	var finale = main.finale
	finale._open()
	# Le héros se tient dans la brèche : la descente commence au bout d'une seconde, avec le morceau.
	main.player.position = finale.descent_point()
	main.player.reset_physics_interpolation()
	main.camera.reset_smoothing()
	main.hud.glyphs.hide()
	step = 1


func _log(what: String) -> void:
	var track = Music.hand
	var clip: String = track.current_clip() if track != null else "?"
	# Temps du film (images × 1/30 s, comme la vidéo) : le temps du jeu, lui, suit le ralenti.
	var video := Engine.get_process_frames() / 30.0
	print("FILM %6.2f s (vidéo %6.2f s)  %s  (section qui joue : %s)" % [t, video, what, clip])


func _physics_process(delta: float) -> void:
	if step == 0:
		return
	t += delta
	var p = main.player
	p.invuln = maxf(p.invuln, 1.0)
	p.hp = Game.stats["max_hp"]
	var finale = main.finale
	var b = finale.boss
	var ready: bool = b != null and is_instance_valid(b) and not b.dead and not b.music_waiting()
	if b != null and is_instance_valid(b) and b.music_waiting():
		_waited = true
	match step:
		1:
			if finale.descending:
				_log("descente (début du morceau)")
				step = 2
		2:
			if finale.in_combat():
				_log("au fond du puits : invocation")
				step = 3
		3:
			if ready:
				_log("batterie : le combat commence")
				_mark = t
				step = 4
		4:
			if t - _mark >= HIT2_AFTER:
				b.take_damage(b.hp - b.max_hp * 0.6, false)
				_log("coup : la vie passe sous 66 %")
				_waited = false
				step = 5
		5:
			if ready and _waited and b.phase == 2:
				_log("batterie : reprise en phase 2")
				_mark = t
				step = 6
		6:
			if t - _mark >= HIT3_AFTER:
				b.take_damage(b.hp - b.max_hp * 0.3, false)
				_log("coup : la vie passe sous 33 %")
				_waited = false
				step = 7
		7:
			if ready and _waited and b.phase == 3:
				_log("batterie : reprise en seconde forme")
				_mark = t
				step = 8
		8:
			if t - _mark >= KILL_AFTER:
				b.take_damage(b.hp + 1.0, false)
				_log("coup fatal")
				_mark = t
				step = 9
		9:
			if t - _mark >= END_AFTER:
				_log("fin du film")
				get_tree().quit(0)
	if OS.get_environment("FILM_DEBUG") != "" and finale.sync != null and Engine.get_physics_frames() % 20 == 0:
		var h = finale.sync._hand()
		print("DBG video %.3f bars %.3f mode %s clock %.3f t0 %.3f resume %d stage %s ts %.2f" % [Engine.get_process_frames() / 30.0, finale.sync.bars_now(), "audio" if h != null else "jeu", Music.hand.clock, Music.hand.grid_t0, finale.sync.resume_bar, finale.sync.stage, Engine.time_scale])
	# Le boss change de phase entre deux attaques (boss_finale.gd) : c'est ce moment que suit la musique.
	var bb = finale.boss
	if step >= 3 and bb != null and is_instance_valid(bb) and int(bb.phase) != _seen_phase:
		_seen_phase = int(bb.phase)
		_log("le boss entre en phase %d" % _seen_phase)
