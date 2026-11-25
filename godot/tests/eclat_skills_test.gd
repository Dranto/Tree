## Test du jalon Éclat, tâche D (compétences et esquive plus fortes à l'œil).
##
## 1. Rien ne change dans le jeu : chaque compétence est lancée sur une même scène fixe (mêmes Flétris,
##    même graine), et ce qu'elle fait (vie des Flétris, morts, états, projectiles, vie du héros) est
##    comparé à l'empreinte prise sur develop avant le jalon (tests/fixtures/eclat_skills.json).
##    Les effets sont purement visuels : ils ne doivent ni toucher au hasard du jeu ni à ses valeurs.
## 2. Les effets eux-mêmes : dosage dans data/feel.json › skills, images rémanentes de l'esquive,
##    éclat « compétence prête » (seulement pour les longues recharges), relâche à chaque lancer,
##    plafond des effets, et « réduire les effets » qui divise les quantités par trois.
##
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/eclat_skills_test.gd
## Refaire l'empreinte (seulement sur develop, avant un changement voulu du jeu) : ajouter -- --write.
extends SceneTree

const FIXTURE := "res://tests/fixtures/eclat_skills.json"

var MainScene
var Enemy
var Content
var SFX
var failures := 0
var game
var settings
var main


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _spawn(pos: Vector2, kind := 0, power := 6.0):
	var e = Enemy.new()
	e.main = main
	e.position = pos
	e.setup(kind, power)
	main.enemies_layer.add_child(e)
	main.enemies.append(e)
	return e


func _clear() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	for pr in main.projectiles_layer.get_children():
		pr.queue_free()
	if main.skill_fx != null:
		main.skill_fx.effects.clear()
	# Ce qu'une compétence a laissé derrière elle (nuages, zones, compétences qui durent) ne déborde
	# pas sur la suivante.
	main.fx.clouds.clear()
	main.attack_fx.zones.clear()
	main.player._skill_objects.clear()


## Ce que fait une compétence sur la scène fixe : une empreinte arrondie.
func _footprint(id: String) -> Dictionary:
	var p = main.player
	_clear()
	await _frames(3)
	p.position = Vector2(0, 320)
	p.hp = game.stats["max_hp"]
	for k in p.cds:
		p.cds[k] = 0.0
	seed(4321)
	var pos := [Vector2(120, 0), Vector2(150, 40), Vector2(170, -45), Vector2(90, 90), Vector2(-120, 20), Vector2(40, -130)]
	var foes: Array = []
	for i in pos.size():
		foes.append(_spawn(p.position + pos[i], i % 3))
	for e in foes:
		e.apply_status("saignement", 2.0, 5.0)
		# Flétris figés (ni marche ni séparation) : qui est touché ne dépend que de la compétence,
		# pas du rythme des images sur une machine chargée.
		e.set_physics_process(false)
	await _frames(1)
	p.aim = Vector2.RIGHT
	p.aim_point = p.position + Vector2(140, 0)
	main._rebuild_grid()   # la grille des Flétris est à jour au lancer, quel que soit le rythme des images
	seed(1234)
	main.rng.seed = 1234   # tirage des critiques
	p.cast(id, game.stats)
	# Le héros est figé (pas de pas physique) : ses compétences qui durent avancent ici.
	for i in 75:
		await physics_frame
		p._tick_skills(1.0 / 60.0)
	var out := {"hp": [], "dead": 0, "status": [], "projectiles": main.projectiles_layer.get_child_count(), "player_hp": snappedf(p.hp, 0.01)}
	for e in foes:
		if not is_instance_valid(e) or e.dead:
			out["dead"] += 1
			out["hp"].append(-1.0)
			out["status"].append("")
			continue
		out["hp"].append(snappedf(e.hp, 0.01))
		# Pas de position : la séparation des Flétris dépend du rythme des images (machine chargée).
		out["status"].append("b%d p%.2f r%.2f d%.2f" % [e.bleed_stacks.size(), e.poison_time, e.root_time, e.dazzle_time])
	return out


func _run() -> void:
	MainScene = load("res://scenes/main.tscn")
	Enemy = load("res://scripts/enemy.gd")
	Content = load("res://scripts/content.gd")
	SFX = load("res://scripts/skill_fx.gd")
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	var write := "--write" in OS.get_cmdline_user_args()
	main = MainScene.instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(2)
	main.autotest = false
	main.spawn_timer = 1e9
	var p = main.player
	p.set_physics_process(false)
	p.invuln = 1e9
	game.reset()
	game.test_skills = {}
	for id in Content.skills():
		game.test_skills[id] = true
	game.recompute()
	settings.reduce_effects = false
	# L'arrêt sur image se compte en secondes réelles : il rendrait l'empreinte dépendante de la
	# vitesse de la machine. Coupé pour la mesure.
	settings.hitstop_scale = 0.0

	print("Le jeu ne change pas (empreinte de chaque compétence)")
	var prints := {}
	var ids: Array = Content.skills().keys()
	ids.sort()
	for id in ids:
		prints[id] = await _footprint(id)
	if write:
		var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
		f.store_string(JSON.stringify(prints, "\t", true))
		f.close()
		print("  empreinte écrite : ", FIXTURE)
	else:
		var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
		check(ref is Dictionary and ref.size() == prints.size(), "empreinte de référence présente (%d compétences)" % prints.size())
		if ref is Dictionary:
			for id in ids:
				# Aller-retour en JSON : les nombres sont lus comme dans l'empreinte (tous en flottants).
				var a := JSON.stringify(JSON.parse_string(JSON.stringify(prints[id])), "", true)
				var b := JSON.stringify(ref.get(id, {}), "", true)
				check(a == b, "%s : même effet qu'avant le jalon%s" % [id, "" if a == b else " (avant %s, après %s)" % [b, a]])

	if not write:
		await _effects()
	print("%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


func _effects() -> void:
	var p = main.player
	var sfx = main.skill_fx
	var feel: Dictionary = Content.feel().get("skills", {})
	print("Dosage (data/feel.json › skills)")
	check(not feel.is_empty(), "section « skills » présente")
	for k in ["dash_ghosts", "dash_leaves", "ready_min_cooldown", "ready_time", "release_time", "max_particles"]:
		check(feel.has(k), "skills › %s" % k)

	print("Esquive : images rémanentes et feuilles")
	_clear()
	await _frames(1)
	p.set_physics_process(true)
	p.dash_cd = 0.0
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	var dash = _find(sfx, "esquive")
	check(dash != null, "l'esquive pose sa signature")
	await _frames(14)
	if dash != null:
		var ghosts: Array = dash.get("ghosts", [])
		check(ghosts.size() >= 2 and ghosts.size() <= int(feel.get("dash_ghosts", 3)), "%d images rémanentes (2 à %d)" % [ghosts.size(), int(feel.get("dash_ghosts", 3))])
		check(SFX.leaf_count(false) == int(feel.get("dash_leaves", 8)), "feuilles soulevées : %d" % SFX.leaf_count(false))
	settings.reduce_effects = true
	check(SFX.ghost_count(true) == maxi(1, int(feel.get("dash_ghosts", 3)) / 3), "réduire les effets : images rémanentes divisées par trois")
	check(SFX.leaf_count(true) == maxi(1, int(feel.get("dash_leaves", 8)) / 3), "réduire les effets : feuilles divisées par trois")
	settings.reduce_effects = false
	p.set_physics_process(false)

	print("Relâche et éclat « prête »")
	_clear()
	game.flags["barre"] = "fouet,racines"
	p.sync_bar()
	await _frames(2)
	p.cds["racines"] = 0.0
	p.cast("racines", game.stats)
	await process_frame
	await process_frame
	check(_find(sfx, "relache") != null, "un lancer pose sa relâche")
	sfx.effects.clear()
	# Le héros est figé : la recharge est menée à son terme à la main.
	p.cds["racines"] = 0.02
	await process_frame
	p.cds["racines"] = 0.0
	await process_frame
	check(_find(sfx, "pret") != null, "racines (longue recharge) : éclat « prête » sur le héros")
	sfx.effects.clear()
	p.cds["fouet"] = 0.02
	await process_frame
	p.cds["fouet"] = 0.0
	await process_frame
	check(_find(sfx, "pret") == null, "fouet (recharge de %.1f s) : pas d'éclat à chaque coup" % float(p.skill("fouet")["cooldown"]))

	print("Plafond")
	_clear()
	for i in 200:
		sfx.play("pret", {"pos": Vector2.ZERO, "col": Color.WHITE})
	check(sfx.effects.size() <= SFX.MAX_EFFECTS, "au plus %d signatures à la fois" % SFX.MAX_EFFECTS)
	_clear()


func _find(sfx, id: String):
	for e in sfx.effects:
		if e["id"] == id:
			return e
	return null
