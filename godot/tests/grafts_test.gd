## Test des points et greffes gagnés dans le monde (jalon 4, tâche B) : données des greffes et des
## récompenses, points donnés une seule fois par source, inventaire, tirage des élites, pose et
## retrait dans les emplacements, autels et secret ravivés en jeu, ramassage au sol, Cœur et boss,
## effets des nouvelles greffes (évènements « hurt » et « dash », actions « burst » et
## « status_area »), inventaire de l'écran de l'arbre, sauvegarde aller-retour et migration d'une
## sauvegarde du jalon 3 (version 2).
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/grafts_test.gd
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree

const Content = preload("res://scripts/content.gd")
const PATH := "user://tests/greffes_test.json"

var failures := 0
var main
var game


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


func _place(pos: Vector2) -> void:
	main.player.position = pos
	main.player.hp = 1.0e6
	main.player.invuln = 1000.0


func _clear_enemies() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()


func _pickups() -> Array:
	return main.orbs_layer.get_children().filter(func(g): return "graft_id" in g and not g.is_queued_for_deletion())


## Un emplacement de greffe de Ronce, et le chemin pour l'apprendre (nœuds ajoutés directement).
func _own_slot(local: String) -> int:
	var id: int = game.tree.id_for_uid("c:ronce:" + local)
	for step in main.tree_ui.panels.planner.path_to(id):
		game.allocated[step] = true
	game.recompute()
	return id


func _run() -> void:
	game = root.get_node("Game")
	var save = root.get_node("SaveGame")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)
	save.delete_save(PATH)

	print("Données")
	var grafts := Content.grafts()
	check(grafts.size() >= 10 and grafts.size() <= 60 and not grafts.has("greffe_test") and not grafts.has("_doc"), "%d greffes (Ronce, Vent…), plus de greffe d'essai" % grafts.size())
	var with_play := 0
	for id in grafts:
		for e in grafts[id]["effects"]:
			if e.has("on") or e.has("skill_mod") or e.has("attack_mod") or e.has("attack_form"):
				with_play += 1
				break
	check(with_play >= 8, "%d greffes changent la façon de jouer (réaction, transformation de compétence ou de l'attaque)" % with_play)
	var r := Content.rewards()
	var world_points: int = int(r["boss"]["ronce"]["points"]) + int(r["coeur"]["ronce"]["points"])
	var world_grafts := {r["boss"]["ronce"]["graft"]: true}
	for a in r["altars"] + r["secrets"]:
		world_points += int(a["points"])
		if a["graft"] != "":
			world_grafts[a["graft"]] = true
	check(r["altars"].size() >= 3 and r["altars"].size() <= 4 and r["secrets"].size() >= 1, "%d autels et %d secret dans la région" % [r["altars"].size(), r["secrets"].size()])
	check(world_points >= 6 and world_grafts.size() >= 4, "la région donne %d points et %d greffes hors niveaux (sans compter les élites)" % [world_points, world_grafts.size()])
	check(int(r["boss"]["ronce"]["points"]) == 2 and int(r["coeur"]["ronce"]["points"]) == 1, "boss : 2 points, Cœur : 1 point")
	var slots := 0
	for n in game.tree.nodes:
		if n["type"] == "graft" and SkillTree_branch_id(n) == "ronce":
			slots += 1
	check(slots >= 4, "%d emplacements de greffe dans Ronce" % slots)

	print("Points hors niveau")
	var got: Array = []
	game.points_granted.connect(func(n, src): got.append([n, src]))
	var p0: int = game.points
	check(game.grant_points(1, "quete", "essai"), "un point donné")
	check(not game.grant_points(1, "quete", "essai"), "la même source ne donne qu'une fois")
	check(game.grant_points(1, "quete"), "sans clé, un don n'est pas limité")
	check(game.points == p0 + 2 and got == [[1, "quete"], [1, "quete"]], "signal points_granted (nombre, source)")
	check(int(game.flags.get("points_hors_niveau", 0)) == 2, "total des points hors niveau tenu à jour")

	print("Inventaire")
	var found: Array = []
	game.graft_found.connect(func(id): found.append(id))
	check(game.give_graft("greffe_soeurs") and found == ["greffe_soeurs"], "greffe ajoutée, signal graft_found")
	check(not game.give_graft("greffe_soeurs") and not game.give_graft("inconnue"), "doublon ou greffe inconnue refusés")
	check(game.free_grafts() == ["greffe_soeurs"], "la greffe attend un emplacement")
	var elite: Array = []
	for i in 20:
		var g: String = game.roll_graft("elite")
		if g == "":
			break
		if not ("elite" in grafts[g]["sources"]) or elite.has(g):
			check(false, "tirage d'élite inattendu : « %s »" % g)
		elite.append(g)
		game.give_graft(g)
	check(elite.size() >= 4 and game.roll_graft("elite") == "", "les %d greffes d'élite sortent chacune une fois, puis plus rien" % elite.size())
	for g in elite:
		game.graft_inventory.erase(g)

	print("Pose dans l'arbre")
	var slot := _own_slot("fouet:f8")
	var other: int = game.tree.id_for_uid("c:ronce:souche:o5")
	var shots: int = game.stats["projectiles"]
	check(not game.place_graft(slot, "greffe_ecorce"), "une greffe non possédée ne se pose pas")
	check(game.place_graft(slot, "greffe_soeurs") and game.stats["projectiles"] == shots + 2, "greffe posée dans un emplacement appris : +2 projectiles")
	check(game.place_graft(other, "greffe_soeurs") and game.graft_of(slot) == "" and game.stats["projectiles"] == shots, "déplacée vers un emplacement pas appris : elle n'agit plus")
	game.give_graft("greffe_ecorce")
	game.place_graft(slot, "greffe_soeurs")
	check(game.place_graft(slot, "greffe_ecorce") and game.free_grafts() == ["greffe_soeurs"], "une greffe remplacée revient dans l'inventaire")

	print("Écran de l'arbre")
	var gp = main.tree_ui.grafts_panel
	gp.refresh()
	check(gp.visible and gp._list.get_child_count() == 2, "l'inventaire montre les deux greffes")
	gp.held = "greffe_soeurs"
	var tip: Array = gp.tooltip_lines(game.tree.nodes[slot])
	var tip_text := " ".join(tip.map(func(l): return l[0]))
	check("Projectiles" in tip_text and "Écorce de mûrier" in tip_text, "aperçu de la greffe tenue (statistiques et greffe remplacée)")
	check(gp.drop_on(slot, "greffe_soeurs") and game.graft_of(slot) == "greffe_soeurs", "glisser-déposer : greffe posée")
	check(not gp.drop_on(game.tree.id_for_uid("c:ronce:fouet:f6"), "greffe_ecorce") and game.graft_of(slot) == "greffe_soeurs", "déposée hors d'un emplacement : rien ne change")
	check(gp.click_slot(slot) and game.graft_of(slot) == "" and game.free_grafts().size() == 2, "clic sur un emplacement occupé : greffe retirée")
	game.place_graft(slot, "greffe_ecorce")

	print("Effets des greffes")
	_clear_enemies()
	_place(Vector2(0, 600))
	var foe = main.spawn_enemy_kind(0, main.player.position + Vector2(60, 0), 1.0)
	foe.hp = 1.0e5
	await _steps(1)
	main._rebuild_grid()
	var hp0: float = foe.hp
	game.fire("hurt", {"main": main, "base": 5.0})
	check(foe.hp < hp0, "Écorce de mûrier : être touché blesse les ennemis proches")
	game.give_graft("greffe_tracante")
	game.place_graft(slot, "greffe_tracante")
	main._rebuild_grid()
	game.fire("dash", {"main": main})
	check(foe.root_time > 0.0, "Racine traçante : l'esquive enracine les ennemis proches")
	game.give_graft("greffe_tournoyante")
	game.place_graft(slot, "greffe_tournoyante")
	check(game.skill("fouet")["arc"] > 6.0, "Tourbillon de ronce : le fouet frappe tout autour")
	game.give_graft("greffe_rampante")
	game.place_graft(slot, "greffe_rampante")
	check(float(game.skill("racines")["range"]) == 0.0, "Racines rampantes : les racines naissent sous le joueur")
	game.set_graft(slot, "")
	foe.queue_free()
	_clear_enemies()
	# Les autels donnent leurs propres greffes : on repart d'un inventaire vide.
	game.graft_inventory.clear()
	game.grafts.clear()
	game.recompute()

	print("Autels et secret")
	check(main.altars.size() == r["altars"].size() + r["secrets"].size(), "autels et secret placés dans le monde")
	for a in main.altars:
		check(main.region_at(a.position) == "ronce", "« %s » est dans le roncier" % a.data["name"])
	var altar = main.altars[0]
	var before: int = game.points
	_place(altar.position + Vector2(0, -400))
	await _steps(2)
	check(not game.flags.get(altar.flag() + "_vu", false), "pas encore aperçu de loin")
	_place(altar.position)
	await _steps(int(altar.HOLD["autel"] * 60.0) + 5)
	check(altar.active and game.flags.get(altar.flag(), false) and game.flags.get(altar.flag() + "_vu", false), "autel ravivé en s'y tenant (drapeaux posés)")
	check(game.points == before + 1, "autel : +1 point")
	await _steps(2)
	var drops := _pickups()
	check(drops.size() == 1 and drops[0].graft_id == altar.data["graft"], "la greffe de l'autel tombe au sol")
	_place(drops[0].position)
	await _steps(30)
	check(game.has_graft(altar.data["graft"]) and _pickups().is_empty(), "greffe ramassée au contact")
	altar.active = false
	altar.activate()
	check(game.points == before + 1, "raviver deux fois ne redonne pas de point")
	var secret = main.altars[main.altars.size() - 1]
	check(secret.kind == "secret", "le secret est placé")
	_place(secret.position)
	await _steps(int(secret.HOLD["secret"] * 60.0) + 40)
	check(secret.active and game.points == before + 2 and game.has_graft(secret.data["graft"]), "secret découvert : +1 point et sa greffe ramassée")

	print("Cœur et boss")
	before = game.points
	main.heart.purify()
	check(game.points == before + 1, "Cœur purifié : +1 point")
	main.heart.state = "fletri"
	main.heart.purify()
	check(game.points == before + 1, "une seconde purification ne redonne rien")
	_place(Vector2(0, 700))
	main.arena.boss_defeated()
	await _steps(2)
	check(game.points == before + 3, "Mère-Ronce vaincue : +2 points")
	var boss_drop := _pickups().filter(func(g): return g.graft_id == r["boss"]["ronce"]["graft"])
	check(boss_drop.size() == 1, "le boss laisse sa greffe au sol")
	main.arena.boss_defeated()
	await _steps(2)
	check(game.points == before + 3 and _pickups().size() == 1, "vaincu deux fois : ni point ni greffe en plus")
	check(main.drop_graft(Vector2(0, 760)) != null, "drop_graft sans greffe nommée : une greffe d'élite tombe")
	await _steps(2)

	print("Sauvegarde")
	game.place_graft(slot, "greffe_soeurs")
	var inv: Array = game.graft_inventory.duplicate()
	var ground: Array = main.export_ground_grafts()
	var pts: int = game.points
	check(ground.size() == 2, "deux greffes au sol à sauvegarder")
	check(save.save_now(main, PATH), "sauvegarde écrite")
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(int(data["version"]) == 4 and data["tree"]["inventory"].size() == inv.size() and data["world"]["ground_grafts"].size() == 2, "format 4 : inventaire et greffes au sol")
	game.reset()
	main.import_ground_grafts([])
	await _steps(2)
	check(game.graft_inventory.is_empty() and _pickups().is_empty(), "nouvelle partie : inventaire vide")
	check(save.load_into(main, PATH), "sauvegarde relue")
	await _steps(2)
	check(game.graft_inventory == inv and game.graft_of(slot) == "greffe_soeurs" and game.points == pts, "inventaire, greffe posée et points retrouvés")
	check(_pickups().size() == 2 and game.grafts_on_ground.size() == 2, "greffes au sol retrouvées")
	check(game.flags.get(altar.flag(), false) and game.flags.get("points_ronce_boss", false), "autels et dons déjà faits retrouvés")

	print("Migration d'une sauvegarde du jalon 3 (version 2)")
	var v2 := {"format": "seve-save", "version": 2, "game": {"level": 9, "points": 1, "flags": {"ronce_boss_vaincu": true, "ronce_coeur_purifie": true}},
		"tree": {"allocated": [], "choices": {}, "grafts": {"c:ronce:coeur:h4": "greffe_soeurs", "c:ronce:fouet:f8": "greffe_test"}},
		"world": {}}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(v2))
	f.close()
	check(save.load_into(null, PATH), "une sauvegarde de la version 2 se charge")
	check(game.graft_inventory == ["greffe_soeurs"] and game.graft_of(game.tree.id_for_uid("c:ronce:coeur:h4")) == "greffe_soeurs", "la greffe posée entre dans l'inventaire ; la greffe d'essai disparue est ignorée")
	check(game.flags.get("points_ronce_boss", false) and game.flags.get("points_ronce_coeur", false), "boss et Cœur déjà vaincus : leurs points ne seront pas redonnés")
	var mig: int = game.points
	check(not game.grant_points(2, "boss", "ronce_boss") and game.points == mig, "pas de second don pour le boss")

	save.delete_save(PATH)
	print("ÉCHECS : %d" % failures if failures > 0 else "Tous les tests des greffes passent.")
	quit(1 if failures > 0 else 0)


func SkillTree_branch_id(n: Dictionary) -> String:
	if n["branch"] < 0:
		return ""
	return str(game.tree.BRANCHES[n["branch"]]["id"])
