## Film du combat contre la Mère-Ronce sur son morceau (ronce.wav d'Antoine ; tools/ronce-film.sh) :
## le vrai jeu, le héros invulnérable. Il marche vers l'enceinte ouverte (l'approche monte sous la
## musique du monde), entre (la mesure d'avant le drop pendant qu'elle charge), puis le robot de
## l'arène le mène (il esquive comme un joueur) ; des coups forcés font passer les phases : phase 1,
## drop_1, phase 2, drop_2, phase 3 (et au cycle 2, « -- --cycle=2 » : drop_3, phase exaltée), mort.
## Les moments sont imprimés (« FILM »). Rien n'est comparé : c'est un outil. Lancer avec --write-movie.
## « -- --region=spore » : le même film pour l'Amanite-Mère (tools/amanite-film.sh), « -- --region=vent »
## pour le Harfang (tools/harfang-film.sh).
extends Node

const MainScene = preload("res://scenes/main.tscn")
const Regions = preload("res://scripts/regions.gd")

## Départ de la marche (px au-delà du mur) ; durée de chaque phase (s) avant le coup qui la termine.
const START_OUT := 1500.0
const PHASE_TIME := {1: 20.0, 2: 24.0, 3: 20.0, 4: 22.0}
const END_AFTER := 7.0

var main
var arena
var t := 0.0
var step := 0
var _mark := 0.0
var _waited := false
var _seen_phase := 1
var _last_phase := 3


## Marche vers l'arène, puis le robot de l'arène.
class FilmBot:
	var arena

	func input(_m, p) -> Dictionary:
		if arena.in_combat():
			return arena.bot_input(p)
		var to: Vector2 = arena.center - p.position
		return {"move": to.normalized() * 0.55, "aim": p.position + to.normalized() * 50.0, "dash": false}

	func step(_m, _delta: float) -> void:
		pass


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
	main.spawn_timer = 1.0e9
	var region := "ronce"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--region="):
			region = a.substr(9)
	arena = main.arenas[region]
	for h in main.region_hearts[region]:
		Game.flags[h.flag] = true
	Game.level = 8
	var out: Vector2 = (arena.entrance() - arena.center).normalized()
	main.player.position = arena.center + out * (arena.max_radius + START_OUT)
	main.player.reset_physics_interpolation()
	main.camera.reset_smoothing()
	main.hud.glyphs.hide()
	var bot := FilmBot.new()
	bot.arena = arena
	main.zone_bot = bot
	var cyc = get_node_or_null("/root/Cycles")
	if cyc != null and cyc.exalted():
		_last_phase = 4
	step = 1


func _log(what: String) -> void:
	var track = Music.hand
	var clip: String = track.current_clip() if track != null else "?"
	print("FILM vidéo %6.2f s  %s  (section : %s, approche %.2f)" % [Engine.get_process_frames() / 30.0, what, clip, track.approach_gain if track != null else 0.0])


func _physics_process(delta: float) -> void:
	if step == 0:
		return
	t += delta
	var p = main.player
	p.invuln = maxf(p.invuln, 1.0)
	p.hp = Game.stats["max_hp"]
	var b = arena.boss
	var alive: bool = b != null and is_instance_valid(b) and not b.dead
	var ready: bool = alive and not b.music_waiting()
	if alive and b.music_waiting():
		_waited = true
	if alive and step == 4:
		# Le héros frappe de lui-même : la vie reste celle de la phase jusqu'au coup forcé (avant lui,
		# pour que le coup forcé passe bien sous le seuil).
		var lo: float = float(b.phase_limits[b.phase - 1]) if b.phase - 1 < b.phase_limits.size() else 0.0
		b.hp = maxf(b.hp, b.max_hp * (lo + 0.01))
	match step:
		1:
			if Music.hand.state == "approche":
				_log("l'approche se fait entendre")
				step = 2
		2:
			if arena.in_combat():
				_log("entrée : elle charge sur la mesure d'avant le drop")
				step = 3
		3:
			if ready:
				_log("drop : le combat commence")
				_mark = t
				step = 4
		4:
			# En vol (le Harfang), le boss est hors d'atteinte : le coup forcé attend qu'il soit à portée.
			if alive and t - _mark >= float(PHASE_TIME[b.phase]) and not (b.has_method("airborne") and b.airborne()):
				if b.phase >= _last_phase:
					b.take_damage(b.hp + 1.0, false)
					_log("coup fatal")
					_mark = t
					step = 6
				else:
					var lim: float = float(b.phase_limits[b.phase - 1])
					b.take_damage(maxf(0.0, b.hp - b.max_hp * (lim - 0.02)), false)
					_log("coup : la vie passe sous %d %%" % int(lim * 100.0))
					_waited = false
					step = 5
		5:
			if ready and _waited:
				_log("reprise en phase %d" % b.phase)
				_mark = t
				step = 4
		6:
			if t - _mark >= END_AFTER:
				_log("fin du film")
				get_tree().quit(0)
	if OS.get_environment("FILM_DEBUG") != "" and Engine.get_physics_frames() % 60 == 0:
		print("DBG step %d t %.1f enabled %s started %s hand %s level %.2f region %s dist %.0f state %s" % [step, t, Music.enabled, Music.started, Music.hand.state, arena.approach_level(), Regions.region_at(p.position), p.position.distance_to(arena.center), arena.state])
	if alive and step >= 3 and int(b.phase) != _seen_phase:
		_seen_phase = int(b.phase)
		_log("elle entre en phase %d" % _seen_phase)
