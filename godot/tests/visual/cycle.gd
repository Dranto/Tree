## Scénario « cycle » du banc visuel (runner.gd ; New Game+, jalon 14 W) : le monde fané du cycle.
## Quatre lieux (l'oasis de la graine, le cœur des régions Ronce et Spore, le bord du monde), chacun
## au cycle 1 (inchangé), 2 et 3 ; puis la vague de flétrissure du début du cycle 2, le front à l'écran
## (terre encore ravivée devant, fanée derrière, liseré d'encre et cendre). Jeu figé.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const CycleTint = preload("res://scripts/cycle_tint.gd")

var r
var main


func run(runner) -> void:
	r = runner
	main = r.main
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.spawn_paused = true
	main.player.set_physics_process(false)
	main.hud.glyphs.hide()
	var spots := {
		"graine": Vector2(0, 340),
		# À l'écart des Cœurs (ils s'éveillent quand le héros entre dans leur zone).
		"ronce": Regions.center("ronce") * 0.62,
		"spore": Regions.center("spore") * 0.62,
		"bord": Regions.center("ronce").normalized() * (Regions.WORLD_HALF - 260.0),
	}
	for key in spots:
		# Tout est cuit (décor, bord, lieux) avant la première capture du lieu.
		await r._place_player(spots[key])
		await r._frames(150)
		for n in [1, 2, 3]:
			CycleTint.apply(n)
			await _look("cycle%d_%s" % [n, key], spots[key])
	CycleTint.apply(1)
	# Vague du cycle 2 : le monde d'abord tel que la fin l'a laissé, puis le front passe le héros.
	var at: Vector2 = Regions.center("ronce").normalized() * 1500.0
	await r._place_player(at)
	for e in main.enemies_layer.get_children():
		e.queue_free()
	var wave = main.cycle_wave
	wave.prepare(2)
	wave.start()
	await r._frames(30)
	await _look("cycle_vague_avant", at)
	# Pas fixes : le front arrive juste derrière le héros (≈ 1 500 px).
	while wave.radius < at.length() - 120.0:
		wave.step(1.0 / 30.0)
	await r._frames(30)
	await _look("cycle_vague_front", at)
	wave.finish()
	await r._frames(60)
	await _look("cycle_vague_apres", at)


func _look(shot: String, pos: Vector2) -> void:
	# Ni Flétris ni coups : seulement le monde.
	for e in main.enemies_layer.get_children():
		e.queue_free()
	await r._place_player(pos)
	main.hud.banner_time = 0.0
	await r._frames(40)
	await r._shot(shot, "jeu")
