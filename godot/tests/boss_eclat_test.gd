## Test des moments signatures des boss (jalon Éclat C, boss_eclat.gd) sur les 7 boss : arrivée (mur,
## fissures, émergence sans attaque avant la fin de l'entrée en scène), changement de phase (onde et
## décors dans l'arène), mort signature, succès Steam débloqué une seule fois, plafond des particules
## (et un tiers avec « Réduire les effets »), tout s'efface ensuite, combat perdu qui nettoie tout.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/boss_eclat_test.gd
extends SceneTree

const SteamFake = preload("res://tests/steam_fake.gd")
const Regions = preload("res://scripts/regions.gd")
var BossEclat

var failures := 0
var main


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _steps(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, limit := 900) -> bool:
	for i in limit:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _run() -> void:
	var game = root.get_node("Game")
	var settings = root.get_node("Settings")
	var bridge = root.get_node("SteamBridge")
	var fake = SteamFake.new()
	BossEclat = load("res://scripts/boss_eclat.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	await _steps(3)
	bridge.attach(fake)
	var regions: Array = []
	for id in ["ronce", "spore", "vent", "seve", "aube", "racine"]:
		if main.arenas.has(id):
			regions.append(id)
	check(regions.size() == 6, "les six régions ont leur arène")
	regions.append("finale")
	var expected := {"ronce": "ronce", "spore": "spore", "vent": "vent", "seve": "seve", "aube": "aube", "racine": "racine", "finale": "finale"}
	for id in regions:
		var arena = main.finale if id == "finale" else main.arenas[id]
		print("Boss de « %s »" % id)
		settings.reduce_effects = id == "seve"
		check(BossEclat.material_of(id) == expected[id], "matière de la région : %s" % expected[id])
		main.player.hp = 1.0e6
		main.player.position = arena.center + Vector2(0, 220)
		main.player.reset_physics_interpolation()
		arena._start_fight()
		var boss = arena.boss
		var eclat = arena.eclat
		check(is_instance_valid(boss) and eclat != null and eclat.active, "le combat commence, l'arrivée se prépare")
		await _steps(4)
		check(eclat.arrive_t > 0.0 and not eclat.cracks.is_empty(), "le sol se fend sous le boss")
		check(boss.scale.y < 0.9 and boss.modulate.r < 0.9, "le boss sort du sol (écrasé, sombre)")
		var struck := false
		var max_parts := 0
		while is_instance_valid(boss) and boss.intro > 0.0:
			if boss.attack != "":
				struck = true
			max_parts = maxi(max_parts, eclat.parts.size())
			await physics_frame
		check(not struck, "aucune attaque avant la fin de son émergence")
		check(eclat.spawned > 0, "des mottes de terre jaillissent")
		await _steps(2)
		check(boss.scale == Vector2.ONE and is_equal_approx(boss.modulate.r, 1.0), "émergence finie : taille et teinte normales")
		# Changement de phase.
		var limit: float = float(boss.phase_limits[0])
		boss.take_damage(boss.max_hp * (1.0 - limit) + 1.0, false)
		check(await _until(func(): return boss.phase == 2, 240), "sous %d %% de vie : phase 2" % roundi(limit * 100.0))
		await _steps(2)
		check(not eclat.waves.is_empty(), "une onde de sa matière part du boss")
		await _steps(60)
		var inside := true
		for d in eclat.decor:
			if d["pos"].distance_to(arena.center) > arena.radius:
				inside = false
		check(eclat.decor.size() >= 3 and inside, "une partie de l'arène se transforme (%d décors, tous dans l'arène)" % eclat.decor.size())
		# Mort (un boss calé sur son morceau ne prend pas de coups pendant le drop : on attend la reprise).
		await _until(func(): return not boss.music_waiting(), 900)
		var stores: int = fake.stores
		boss.take_damage(boss.hp + 1.0, false)
		check(boss.dead and eclat.death_t >= 0.0, "le boss meurt : mort signature")
		match id:
			"ronce":
				check(not eclat.vines.is_empty(), "la Mère-Ronce se dénoue en lianes")
			"finale":
				check(not eclat.rays.is_empty(), "la Flétrissure se déchire en lumière")
			_:
				check(eclat.parts.size() > 3, "sa matière se disperse (%d morceaux)" % eclat.parts.size())
		var cap: int = eclat._cap()
		# Les lambdas copient les variables : le pic et le boss passent par un dictionnaire et une
		# référence faible (le boss est libéré pendant l'attente).
		var seen := {"peak": 0}
		var ref: WeakRef = weakref(boss)
		boss = null
		var ok: bool = await _until(func():
			seen["peak"] = maxi(int(seen["peak"]), eclat.parts.size())
			return ref.get_ref() == null, 1200)
		var peak: int = seen["peak"]
		check(ok, "le boss disparaît après sa mort")
		check(fake.stores == stores + 1 and ("BOSS_" + id.to_upper()) in fake.achievements, "succès Steam débloqué une seule fois")
		check(maxi(peak, max_parts) <= cap, "plafond des particules tenu (%d sur %d)" % [maxi(peak, max_parts), cap])
		if id == "seve":
			check(cap <= int(BossEclat.cfg("max_particles", 150)) / 3, "Réduire les effets : un tiers des particules")
			check(eclat.decor.any(func(d): return d["kind"] == "sprout" or d["kind"] == "pool"), "la sève retombe et reverdit le sol")
		check(await _until(func(): return not eclat.active, 900), "tout s'efface ensuite")
		check(is_equal_approx(Engine.time_scale, 1.0), "le jeu reprend sa vitesse normale")
		await _steps(5)
	settings.reduce_effects = false

	print("Combat perdu")
	var arena = main.arenas["ronce"]
	game.flags.erase(Regions.boss_flag("ronce"))
	arena.state = "ouverte"
	main.player.position = arena.center + Vector2(0, 220)
	main.player.reset_physics_interpolation()
	arena._start_fight()
	await _steps(4)
	var boss = arena.boss
	# La Mère-Ronce charge jusqu'au drop de son morceau, invulnérable.
	await _until(func(): return not boss.music_waiting(), 300)
	boss.take_damage(boss.max_hp * 0.5, false)
	await _until(func(): return boss.intro <= 0.0 and boss.phase == 2, 300)
	await _steps(30)
	check(arena.eclat.active and not arena.eclat.decor.is_empty(), "pendant le combat, l'arène garde ses décors")
	main.player_died()
	await _steps(5)
	check(not arena.eclat.active and arena.eclat.decor.is_empty() and arena.eclat.parts.is_empty(), "le joueur meurt : tout s'efface")

	print("Boss figé (tests visuels)")
	main.player.position = arena.center + Vector2(0, 220)
	arena._start_fight()
	boss = arena.boss
	boss.frozen = true
	boss.intro = 0.0
	await _steps(10)
	check(arena.eclat.cracks.is_empty() and arena.eclat.parts.is_empty() and boss.scale == Vector2.ONE, "un boss figé ne déclenche rien (références visuelles inchangées)")

	bridge.attach(null)
	fake.free()
	print("RÉSULTAT : %s (%d échec(s))" % ["OK" if failures == 0 else "ÉCHEC", failures])
	quit(1 if failures > 0 else 0)
