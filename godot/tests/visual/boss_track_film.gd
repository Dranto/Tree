## Film du combat contre la Flétrissure avec sa musique faite à la main (tools/boss-track-film.sh) :
## le vrai jeu, le héros invulnérable au sud du boss, et des coups forcés pour tenir en ~1 min 35 :
## éveil (intro puis boucle_1), phase 2 (drop_1 puis boucle_2), transformation (drop_2 puis boucle_3),
## mort (fin). Les instants des changements de phase et des sections demandées sont imprimés (« FILM »).
## Rien n'est comparé : c'est un outil. Lancer avec --write-movie (Movie Maker : image et son calés).
extends Node

const MainScene = preload("res://scenes/main.tscn")
const Regions = preload("res://scripts/regions.gd")

## Instants (s, temps du film) des coups qui font changer le boss de phase, puis de sa mort.
const PHASE2_AT := 30.0
const PHASE3_AT := 52.0
const KILL_AT := 80.0
const END_AT := 95.0

var main
var t := 0.0
var step := 0


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
	finale.descend()
	main.player.position = finale.center + Vector2(0, 260)
	main.player.reset_physics_interpolation()
	main.camera.reset_smoothing()
	main.hud.glyphs.hide()
	step = 1


func _log(what: String) -> void:
	var track = Music.hand
	var clip: String = track.current_clip() if track != null else "?"
	print("FILM %6.2f s  %s  (section qui joue : %s)" % [t, what, clip])


func _physics_process(delta: float) -> void:
	if step == 0:
		return
	t += delta
	var p = main.player
	p.invuln = maxf(p.invuln, 1.0)
	p.hp = Game.stats["max_hp"]
	var finale = main.finale
	match step:
		1:
			if t > 1.0:
				# Le héros entre dans l'arène : le combat commence (comme en jeu).
				finale._start_fight()
				_log("éveil")
				step = 2
		2:
			if t >= PHASE2_AT:
				var b = finale.boss
				b.take_damage(b.hp - b.max_hp * 0.6, false)
				_log("coup : phase %d" % b.phase)
				step = 3
		3:
			if t >= PHASE3_AT:
				var b = finale.boss
				b.take_damage(b.hp - b.max_hp * 0.3, false)
				_log("coup : phase %d (transformation)" % b.phase)
				step = 4
		4:
			if t >= KILL_AT:
				var b = finale.boss
				b.take_damage(b.hp + 1.0, false)
				_log("coup fatal")
				step = 5
		5:
			if t >= END_AT:
				_log("fin du film")
				get_tree().quit(0)
	if int(t * 60.0) % 120 == 0:
		_log("…")
