## Test du ressenti du combat (jalon 11, tâche G) : réglages de data/feel.json, arrêt sur image
## dosé (critique, mort d'élite, boss) et options (settings.hitstop_strength, shake_strength,
## flash_strength), recul à l'opposé du Porte-Graine, étoile des critiques, formes des annonces
## (tirets qui se resserrent, chevrons) et temps de réaction minimal des attaques annoncées.
## Lancer : tools/godot.sh --headless -s res://tests/feel_test.gd
extends SceneTree

const Content = preload("res://scripts/content.gd")

var failures := 0
var main
## Autoload Settings (pas d'identifiant global dans un script lancé par -s).
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


## Laisse finir l'arrêt en cours et son délai (le temps compte en secondes réelles).
func _settle(fx) -> void:
	fx._hitstop_left = 0.0
	fx._hitstop_cd = 0.0
	Engine.time_scale = 1.0


func _run() -> void:
	settings = root.get_node("Settings")
	var saved := [settings.reduce_effects, settings.hitstop_scale, settings.flash_scale, settings.damage_numbers]
	settings.reduce_effects = false
	settings.hitstop_scale = 1.0
	settings.flash_scale = 1.0

	print("Données")
	var feel := Content.feel()
	for section in ["hitstop", "shake", "heavy", "recoil", "sparks", "death"]:
		check(feel.get(section) is Dictionary, "feel.json › %s présent" % section)
	var hs: Dictionary = feel.get("hitstop", {})
	check(float(hs.get("boss_kill", 0)) > float(hs.get("elite_kill", 0)) and float(hs.get("elite_kill", 0)) > float(hs.get("crit", 0)) \
		and float(hs.get("crit", 0)) > float(hs.get("heavy", 0)), "arrêt dosé : boss > élite > critique > coup lourd")
	check(float(hs.get("boss_kill", 1)) <= 0.4, "même la mort d'un boss ne fige pas le jeu plus de 0,4 s")

	print("Temps de réaction")
	var min_windup: float = Anim.DUREE["annonce_min"]
	for k in Content._load("enemies").get("kinds", []):
		if k.has("windup"):
			check(float(k["windup"]) >= min_windup, "%s : annonce de %.2f s (au moins %.2f s)" % [k.get("id", "?"), float(k["windup"]), min_windup])
	var affixes: Dictionary = Content._load("difficulty").get("elites", {}).get("affixes", {})
	for a in affixes:
		if affixes[a].has("windup"):
			check(float(affixes[a]["windup"]) >= min_windup, "élite « %s » : annonce d'au moins %.2f s" % [a, min_windup])

	print("Formes des annonces")
	var formes := [
		{"type": "cercle", "centre": Vector2.ZERO, "rayon": 100.0},
		{"type": "cone", "centre": Vector2.ZERO, "direction": 0.0, "ouverture": 1.2, "rayon": 160.0},
		{"type": "ligne", "de": Vector2.ZERO, "a": Vector2(300, 0), "largeur": 40.0},
	]
	for f in formes:
		var full := Art.telegraph_polygon(f, 1.0)
		var early := PackedVector2Array()
		Art._telegraph_marks(early, f, full, 0.0, 0.3)
		var late := PackedVector2Array()
		Art._telegraph_marks(late, f, full, 1.0, 0.3)
		check(early.size() >= 8 and early.size() % 2 == 0, "%s : tirets et chevrons dessinés (%d segments)" % [f["type"], early.size() / 2])
		check(_reach(early) > _reach(late) * 1.2, "%s : le contour en tirets se resserre jusqu'au coup" % f["type"])
		check(absf(_reach(late) - _reach(full)) < 1.0, "%s : au coup, les tirets sont posés sur la zone" % f["type"])

	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _steps(2)
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	main.player.invuln = 1.0e9
	var at := Vector2(-1500, 600)
	main.player.position = at
	var fx = main.fx

	print("Arrêt sur image")
	_settle(fx)
	var n0: int = fx.hitstops
	fx.impact(at, 10.0, false, 14.0)
	check(fx.hitstops == n0, "un coup ordinaire ne fige pas le jeu")
	fx.impact(at, 10.0, true, 14.0)
	check(fx.hitstops == n0 + 1 and is_equal_approx(fx.last_hitstop, float(hs["crit"])), "un critique fige le jeu %.3f s" % float(hs["crit"]))
	check(Engine.time_scale < 0.5, "le jeu ralentit pendant l'arrêt")
	fx.impact(at, 10.0, true, 14.0)
	check(fx.hitstops == n0 + 1, "deux critiques d'affilée : un seul arrêt (délai)")
	fx.death(at, 18.0, Color.GRAY, false, true)
	check(is_equal_approx(fx.last_hitstop, float(hs["elite_kill"])), "la mort d'une élite prolonge l'arrêt en cours (%.2f s)" % float(hs["elite_kill"]))
	_settle(fx)
	fx._hitstop_cd = 1.0
	var n1: int = fx.hitstops
	fx.boss_kill(at, 70.0)
	check(fx.hitstops == n1 + 1, "la mort d'un boss passe outre le délai")
	_settle(fx)
	settings.hitstop_scale = 0.5
	fx.impact(at, 10.0, true, 14.0)
	check(is_equal_approx(fx.last_hitstop, float(hs["crit"]) * 0.5), "option : arrêt raccourci de moitié")
	_settle(fx)
	settings.hitstop_scale = 0.0
	var n2: int = fx.hitstops
	fx.boss_kill(at, 70.0)
	check(fx.hitstops == n2, "option à 0 : plus aucun arrêt")
	settings.hitstop_scale = 1.0
	settings.reduce_effects = true
	fx.impact(at, 10.0, true, 14.0)
	check(fx.hitstops == n2, "« Réduire les effets » : plus aucun arrêt")
	settings.reduce_effects = false
	_settle(fx)

	print("Chiffres de dégâts")
	check(settings.damage_numbers == "aucun" or saved[3] != "aucun", "masqués par défaut")
	fx.texts.clear()
	settings.damage_numbers = "aucun"
	fx.impact(at, 10.0, true, 14.0)
	fx.player_hurt(0.1, 12.0, at)
	check(fx.texts.is_empty(), "« aucun » : ni coup infligé ni dégât reçu chiffré")
	settings.damage_numbers = "critiques"
	fx.impact(at, 10.0, false, 14.0)
	check(fx.texts.is_empty(), "« critiques » : un coup ordinaire n'a pas de chiffre")
	fx.impact(at, 10.0, true, 14.0)
	fx.player_hurt(0.1, 12.0, at)
	check(fx.texts.size() == 2, "« critiques » : le critique et le dégât reçu sont chiffrés")
	settings.damage_numbers = "tous"
	fx.impact(at, 10.0, false, 14.0)
	check(fx.texts.size() == 3, "« tous » : le coup ordinaire aussi")
	settings.damage_numbers = "aucun"
	fx.texts.clear()
	_settle(fx)

	print("Critique visible")
	fx.stars.clear()
	fx.impact(at, 10.0, false, 14.0)
	check(fx.stars.is_empty(), "un coup ordinaire n'a pas d'étoile")
	fx.impact(at, 10.0, true, 14.0)
	check(fx.stars.size() == 1 and int(fx.stars[0]["n"]) >= 6, "un critique a son étoile de rayons (une forme, pas seulement une couleur)")
	_settle(fx)

	print("Recul et éclats")
	var e = main.spawn_enemy_kind("fletri", at + Vector2(100, 0), 1.0)
	await _steps(1)
	e.hp = 1.0e6
	e.max_hp = 1.0e6
	var p0: int = fx.particles.size()
	e.take_damage(5.0, false)
	check(e.hit_dir.dot(Vector2.RIGHT) > 0.9, "le Flétri recule à l'opposé du Porte-Graine")
	check(fx.particles.size() > p0, "des éclats jaillissent à l'impact")
	var kick_normal: float = e.hit_kick
	_settle(fx)
	e.take_damage(5.0, true)
	check(e.hit_kick > kick_normal and e.hit_flash_dur > 0.08, "un critique fait reculer plus fort et éclaire plus longtemps")
	_settle(fx)
	e.max_hp = 10.0
	e.hp = 1.0e6
	e.take_damage(5.0, false)
	check(e.hit_kick > kick_normal, "un coup lourd (%.0f %% de la vie) fait reculer plus fort" % (100.0 * float(feel["heavy"]["enemy_frac"])))
	_settle(fx)

	print("Morts marquées")
	fx.particles.clear()
	fx.death(at, 14.0, Color.GRAY, false)
	var ordinary: int = fx.particles.size()
	fx.particles.clear()
	_settle(fx)
	fx.death(at, 14.0, Color.GRAY, false, true)
	check(fx.particles.size() > ordinary, "une élite meurt avec plus d'éclats (%d contre %d)" % [fx.particles.size(), ordinary])
	_settle(fx)

	print("Boss")
	var hits0: int = fx.particles.size()
	var boss = load("res://scripts/boss_ronce.gd").new()
	boss.main = main
	boss.arena = null
	boss.position = at + Vector2(0, -200)
	boss.max_hp = 1000.0
	boss.hp = 1000.0
	boss.take_damage(10.0, true)
	check(fx.particles.size() > hits0 and fx.stars.size() > 0, "un critique sur un boss : éclats et étoile")
	boss.free()
	_settle(fx)

	settings.reduce_effects = saved[0]
	settings.hitstop_scale = saved[1]
	settings.flash_scale = saved[2]
	settings.damage_numbers = saved[3]
	Engine.time_scale = 1.0
	print("Résultat : %s" % ("OK" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)


## Distance maximale à l'origine (0, 0) d'un ensemble de points.
func _reach(pts: PackedVector2Array) -> float:
	var m := 0.0
	for p in pts:
		m = maxf(m, p.length())
	return m
