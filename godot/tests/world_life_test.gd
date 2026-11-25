## Test du monde vivant (refonte du monde, vague 1 V, scripts/world_life.gd) : réglages de
## data/feel.json › world › life et couleurs d'Art.MONDE › vivant, atlas cuit de la petite vie,
## matériau balancé posé sur le décor (et pas sur ce qui est rigide), react() (impulsions, débris, faune
## qui fuit), rafales, réactions aux Flétris (charge, cendre) et au héros (pas fleuris, faune qui
## s'envole), plafonds et « Réduire les effets » (un tiers), crochet de région, mode figé des tests
## visuels, le hasard du jeu jamais tiré, et le coût par image.
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 -s res://tests/world_life_test.gd
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree

const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")
# Chargés à l'exécution (load) : ces scripts nomment Game et Settings, inconnus d'un script -s à sa
# compilation.
var WorldLife
var Atlas
var DecorMarais

var failures := 0
var main
var settings


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


func _run() -> void:
	WorldLife = load("res://scripts/world_life.gd")
	Atlas = load("res://scripts/world_life_atlas.gd")
	DecorMarais = load("res://scripts/decor_marais.gd")
	settings = root.get_node("Settings")
	var saved_reduce: bool = settings.reduce_effects
	settings.reduce_effects = false
	WorldLife.still = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)
	var life = main.world_fx.life
	var player = main.player
	player.invuln = 1.0e6

	print("Données et couleurs")
	var cfg: Dictionary = Content.feel().get("world", {}).get("life", {})
	for section in ["near", "caps", "sway", "gust", "lantern", "hero", "enemies", "projectiles", "combat", "bits", "water", "fauna", "regions"]:
		check(cfg.get(section) is Dictionary, "feel.json › world › life › %s présent" % section)
	var viv: Dictionary = Art.MONDE.get("vivant", {})
	for reg in Regions.ids():
		var rc: Dictionary = cfg.get("regions", {}).get(reg, {})
		check(not rc.is_empty(), "réglages de la région %s" % reg)
		check(viv.has(reg), "Art.MONDE › vivant › %s" % reg)
		for key in ["bris_vif", "bris_mort", "pas", "cendre", "eau", "spore"]:
			check(life.col(reg, key) != Color.MAGENTA, "couleur %s/%s" % [reg, key])
		for sp in rc.get("fauna", []):
			check(cfg.get("fauna", {}).has(sp), "faune %s réglée (%s)" % [sp, reg])
			check(life.col(reg, sp) != Color.MAGENTA and life.col(reg, sp + "_mort") != Color.MAGENTA, "couleurs de %s (%s)" % [sp, reg])
	check(life.get_parent() == main.world_fx, "le calque du sol est un enfant de world_fx (sous les acteurs)")
	check(life.air.get_parent() == main.world_fx.over, "le calque du dessus est un enfant de world_fx.over")

	print("Atlas cuit")
	await _steps(4)
	check(Atlas.ready(), "atlas de la petite vie cuit")
	if Atlas.ready():
		check(Atlas.tex.get_width() == Atlas.COLS * Atlas.CELL * Atlas.SCALE, "largeur de l'atlas")
		check(Atlas.bytes < 2 * 1024 * 1024, "atlas sous 2 Mo (%d Ko)" % (Atlas.bytes / 1024))
		var img: Image = Atlas.tex.get_image()
		for f in ["feuille", "papillon_0", "oiseau_vol_1", "grenouille_0", "fleur_pas", "cendre"]:
			var r: Rect2 = Atlas.rect(f)
			var c: Color = img.get_pixelv(Vector2i(r.get_center()))
			var any := false
			for dy in range(-6, 7, 3):
				for dx in range(-6, 7, 3):
					if img.get_pixelv(Vector2i(r.get_center()) + Vector2i(dx, dy)).a > 0.2:
						any = true
			check(any, "image « %s » dessinée" % f)

	print("Balancement du décor")
	var c: Vector2 = Regions.center("ronce")
	player.position = c + Vector2(500, 200)
	player.reset_physics_interpolation()
	await _steps(140)
	var trees: Array = main.flora.trees
	var swayed := 0
	var rigid_ok := true
	var soft_ok := 0
	for t in trees:
		var s: float = WorldLife.sway_of(t)
		var m = t.material
		if m != null and m.has_meta("vivant"):
			swayed += 1
			if absf(float(m.get_shader_parameter("sway")) - s) > 0.2:
				rigid_ok = false
		if s <= 0.0 and m != null and m.has_meta("vivant"):
			rigid_ok = false
	check(swayed > trees.size() / 2, "le matériau balancé est posé sur le décor souple (%d / %d)" % [swayed, trees.size()])
	check(rigid_ok, "rien de rigide ne balance, et chaque palier suit la souplesse de sa sorte")
	var reeds = DecorMarais.DecorReeds.new()
	var pool = DecorMarais.DecorPool.new()
	check(WorldLife.sway_of(reeds) > 1.0 and WorldLife.sway_of(pool) == 0.0, "roseaux souples, mare rigide")
	reeds.free()
	pool.free()
	check(life._variants.size() <= WorldLife.SWAY_STEPS.size() * 2, "au plus un matériau par palier et par base (%d)" % life._variants.size())

	print("Réactions")
	var rng_state: int = main.rng.state
	life.bits.clear()
	life._push.clear()
	var near: Array = life.decor_near(player.position, 400.0)
	var at: Vector2 = near[0].position if not near.is_empty() else player.position
	life.react("heavy", at, 1.0)
	check(not life._push.is_empty(), "coup lourd : le décor proche tremble (impulsion)")
	check(life.bits.size() > 0 or near.is_empty(), "coup lourd : le décor lâche des débris (%d)" % life.bits.size())
	for i in 20:
		life.push(player.position + Vector2(i * 30, 0), 60.0, 1.0)
	check(life._push.size() <= WorldLife.PUSH_SLOTS, "au plus %d impulsions" % WorldLife.PUSH_SLOTS)
	for i in 500:
		life.add_bit("feuille", player.position, 10.0, Vector2.ZERO, 0.0, Color.WHITE)
		life.add_mark("cendre", player.position, 1.0, Color.WHITE)
	var bits_cap := int(cfg["caps"]["bits"])
	var marks_cap := int(cfg["caps"]["marks"])
	check(life.bits.size() <= bits_cap and life.marks.size() <= marks_cap, "débris et marques plafonnés (%d, %d)" % [life.bits.size(), life.marks.size()])
	settings.reduce_effects = true
	for i in 500:
		life.add_bit("feuille", player.position, 10.0, Vector2.ZERO, 0.0, Color.WHITE)
	check(life.bits.size() <= int(round(bits_cap / 3.0)), "Réduire les effets : un tiers des débris (%d)" % life.bits.size())
	settings.reduce_effects = false
	check(main.rng.state == rng_state, "le hasard du jeu n'est pas tiré")

	print("Rafale")
	life.start_gust(1.0, Vector2.RIGHT)
	var front: float = life.gust["front"]
	check(life.gust_at(Vector2(front, player.position.y)).length() > 0.3, "la rafale couche l'herbe à son front")
	check(life.gust_at(Vector2(front + 2000.0, player.position.y)).length() < 0.01, "et pas loin devant")
	await _steps(20)
	check(life.gust["front"] > front, "le front avance")

	print("Faune")
	main.ground.paint(player.position, 800.0, 1.0)
	main.flora.finish_pending()
	life.fauna.clear()
	await _steps(200)
	var fcap := int(cfg["caps"]["fauna"])
	check(life.fauna.size() > 0, "la faune apparaît autour du héros (%d)" % life.fauna.size())
	check(life.fauna.size() <= fcap, "faune plafonnée")
	if not life.fauna.is_empty():
		var a: Dictionary = life.fauna[0]
		life.scare(a["pos"], 50.0)
		check(a["state"] == "fuite", "la faune proche d'un coup s'enfuit")
		a["state"] = "repos"
		player.position = a["pos"] + Vector2(10, 0)
		player.reset_physics_interpolation()
		player.walk = 1.0
		player.move_dir = Vector2.RIGHT
		life._hero_step(player)
		check(a["state"] == "fuite", "la faune s'envole à l'approche du héros")

	print("Pas fleuris et Flétris")
	life.marks.clear()
	main.ground.paint(player.position, 300.0, 1.0)
	player.walk = 1.0
	player.move_dir = Vector2.RIGHT
	for i in 6:
		life._hero_step(player)
	var flowers: Array = life.marks.filter(func(m): return m["f"] == "fleur_pas")
	check(not flowers.is_empty(), "le héros laisse des fleurs sur la terre ravivée")
	life.marks.clear()
	life._push.clear()
	var e = main.spawn_enemy_at(player.position + Vector2(-200, 40), 0)
	e.set_physics_process(false)
	e.hp = 1.0e9
	e.max_hp = 1.0e9
	main._rebuild_grid()
	life._enemies(player)
	for i in 6:
		e.position += Vector2(60, 0)
		main._rebuild_grid()
		life._enemies(player)
	check(life._push.any(func(q): return q["f"] > 0.0), "un Flétri qui charge secoue le décor")
	check(life.marks.any(func(m): return m["f"] == "cendre"), "un Flétri laisse de la cendre sur la terre vivante")
	e.elite = true
	life._push.clear()
	life._enemies(player)
	check(life._push.any(func(q): return q["f"] < 0.0), "les plantes se tordent près d'un élite")
	e.queue_free()

	print("Région")
	check(life._hook("spore") != null, "réactions propres du Marais (world_art/spore_vivant.gd)")
	check(life._hook("ronce") == null, "pas de crochet pour une région qui n'en a pas")

	print("Tests visuels figés")
	WorldLife.still = true
	life.bits.clear()
	life._push.clear()
	life.react("heavy", player.position, 1.0)
	check(life.bits.is_empty() and life._push.is_empty(), "figé : react ne pose rien")
	WorldLife.still = false

	print("Coût")
	life.fauna.clear()
	await _steps(120)
	for i in 60:
		life.add_bit("feuille", player.position + Vector2(i, 0), 30.0, Vector2(10, 0), 0.0, Color.WHITE, 1.0, 9.0, 1.0)
		life.add_mark("ride", player.position + Vector2(0, i), 9.0, Color.WHITE)
	var t0 := Time.get_ticks_usec()
	for i in 60:
		life._process(1.0 / 60.0)
	var per := (Time.get_ticks_usec() - t0) / 60.0
	print("  logique : %.0f µs par image (%d débris, %d marques, %d bêtes)" % [per, life.bits.size(), life.marks.size(), life.fauna.size()])
	check(per < 1500.0, "logique du monde vivant sous 1,5 ms par image")

	settings.reduce_effects = saved_reduce
	print("Monde vivant : %s" % ("OK" if failures == 0 else "%d ÉCHEC(S)" % failures))
	quit(1 if failures > 0 else 0)
