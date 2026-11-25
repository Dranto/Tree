## Test de migration des sauvegardes (jalon 12 G) : un fichier d'exemple par version du format
## (tests/fixtures/saves/sauvegarde_v1.json … v8.json, faits par tools/fixtures-sauvegardes.py avec le
## format que le jeu écrivait alors) se charge sans perte dans le jeu actuel : niveau, expérience,
## drapeaux (renommés ou complétés par les migrations), nœuds (chaque point d'un nœud disparu est
## rendu), choix, inventaire, couronne, builds, monde (carte de vie, fleurs, greffes au sol, joueur).
## Chaque fichier est ensuite réécrit (format courant) et rechargé : l'état doit être identique.
## Lancer : tools/godot.sh --headless -s res://tests/migration_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
const DIR := "res://tests/fixtures/saves/"
const PATH := "user://tests/migration.json"

var failures := 0
var game
var save
var main


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _fixture(v: int) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DIR + "sauvegarde_v%d.json" % v))


func _run() -> void:
	game = root.get_node("Game")
	save = root.get_node("SaveGame")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.autosave_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))

	check(save.VERSION == 8, "le format courant est la version 8 (ajouter un fichier d'exemple et une étape ici s'il change)")
	for v in range(1, save.VERSION + 1):
		await _version(v)
	await _version_zero_and_gaps()

	save.delete_save(PATH)
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)


func _version(v: int) -> void:
	print("Version %d" % v)
	var src := _fixture(v)
	check(int(src["version"]) == v, "le fichier d'exemple est bien une sauvegarde du format %d" % v)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(DIR + "sauvegarde_v%d.json" % v))
	f.close()
	var migrated: Dictionary = save._read(PATH)
	check(int(migrated.get("version", 0)) == save.VERSION, "migrée jusqu'au format %d" % save.VERSION)
	check(save.peek(PATH).get("level", 0) == int(src["game"]["level"]), "le menu « Continuer » lit le niveau")

	game.reset()
	main.ground.import_map(Image.create(200, 200, false, Image.FORMAT_R8).save_png_to_buffer())
	main.flora.import_flowers([])
	check(save.load_into(main, PATH) and save.last_error == "", "chargement sans erreur")
	await process_frame
	var g: Dictionary = src["game"]
	var flags: Dictionary = g["flags"]

	# Partie : niveau, expérience, éliminations.
	check(game.level == int(g["level"]) and is_equal_approx(game.xp, float(g["xp"])) and game.kills == int(g["kills"]), "niveau, expérience, éliminations")

	# Nœuds : tout point est compté, rendu ou dépensé (les nœuds d'un ancien arbre disparus sont rendus).
	var saved_uids: Array = src["tree"]["allocated"]
	var now: Array = game.allocated_uids()
	check(game.points + now.size() == int(g["points"]) + saved_uids.size(), "aucun point perdu (%d appris, %d points, %d à l'origine)" % [now.size(), game.points, int(g["points"]) + saved_uids.size()])
	for uid in ["ronce:1:1", "ronce:2:2"]:
		check(now.has(uid), "le nœud %s est resté appris" % uid)
	if v >= 2:
		for uid in ["spore:1:0", "c:spore:graines:a4", "key:cloud"]:
			check(now.has(uid), "le nœud %s est resté appris" % uid)
	check(not now.has("ronce:99:0"), "un nœud inconnu n'est pas appris") 
	check(now.size() == _connected(now).size(), "tous les nœuds appris sont reliés à la graine")

	# Drapeaux : renommés ou complétés par les migrations, jamais perdus.
	for k in ["rencontre_gardien", "ronce_boss_vaincu", "spore_boss_vaincu", "finale_vaincue", "plan_arbre", "points_ronce_boss", "points_ronce_coeur", "obj_boss"]:
		if flags.has(k):
			check(game.flags.get(k) == flags[k], "drapeau « %s » conservé" % k)
	if flags.has("fin_ronce_vue"):
		check(game.flags.get("ronce_fin_vue", false) and not game.flags.has("fin_ronce_vue"), "« fin_ronce_vue » devient « ronce_fin_vue »")
	if flags.has("ronce_fin_vue"):
		check(game.flags.get("ronce_fin_vue", false), "« ronce_fin_vue » conservé")
	if flags.has("fin_aventure_vue"):
		var kept: bool = v >= 5 and bool(flags.get("finale_vaincue", false))
		check(game.flags.get("fin_aventure_vue", false) == kept, "« fin_aventure_vue » : %s" % ("épilogue vu, conservé" if kept else "ancienne fin, à revoir après la finale"))
	if v <= 5 and flags.get("ronce_coeur_purifie", false):
		var all3 := true
		for i in Regions.heart_count("ronce"):
			all3 = all3 and game.flags.get(Regions.heart_part_flag("ronce", i), false)
		check(all3, "Cœur de Ronce purifié : ses Cœurs le sont tous")
	if v <= 5 and flags.get("spore_coeur_purifie", false):
		var all3 := true
		for i in Regions.heart_count("spore"):
			all3 = all3 and game.flags.get(Regions.heart_part_flag("spore", i), false)
		check(all3, "Cœur de Spore purifié : ses Cœurs le sont tous")
	if v == 6:
		check(not game.flags.get(Regions.heart_part_flag("spore", 1), false), "un seul Cœur de Spore purifié reste un seul")
	check(game.flags.size() >= flags.size(), "aucun drapeau perdu (%d → %d)" % [flags.size(), game.flags.size()])

	# Choix, inventaire, couronne.
	var choices: Dictionary = src["tree"].get("choices", {})
	for uid in choices:
		check(game.choices.get(uid, "") == choices[uid], "choix %s = %s" % [uid, choices[uid]])
	if v >= 2 and v <= 6:
		for gid in src["tree"].get("grafts", {}).values():
			check(game.graft_inventory.has(gid) and game.crown.has(gid), "greffe « %s » posée sur l'arbre : dans l'inventaire et la couronne" % gid)
	if v >= 3:
		for gid in src["tree"].get("inventory", []):
			if Content_has_graft(gid):
				check(game.graft_inventory.has(gid), "greffe « %s » gardée dans l'inventaire" % gid)
		check(not game.graft_inventory.has("greffe_inconnue"), "une greffe inconnue n'entre pas dans l'inventaire")
	check(game.crown.size() == game.crown_size(), "couronne de %d emplacements ouverts" % game.crown_size())
	if v >= 7:
		var saved_crown: Array = src["tree"]["crown"] if v == 7 else src["tree"]["crown"]
		var same := true
		for i in mini(saved_crown.size(), game.crown.size()):
			same = same and game.crown[i] == saved_crown[i]
		check(same, "la couronne est reprise telle quelle")
	check(game.builds.size() == game.build_slots(), "%d emplacements de build" % game.build_slots())
	if v == 8:
		check(game.active_build == 1 and str(game.builds[0].get("name", "")) == "Épines" and (game.builds[0]["allocated"] as Array) == ["ronce:1:1"], "builds : l'actif et le premier emplacement (nom, nœuds) sont gardés")
		check(game.builds[0]["crown"][0] == "greffe_mere", "builds : la couronne du premier emplacement est gardée")
		check(game.builds[1]["allocated"] == game.allocated_uids(), "builds : l'emplacement actif suit la partie")
	else:
		check(game.active_build == 0 and game.builds[0]["allocated"] == game.allocated_uids(), "build unique : le premier emplacement reçoit la partie")

	# Monde.
	var w: Dictionary = src["world"]
	check(absf(main.elapsed - float(w["elapsed"])) < 5.0, "temps de jeu")
	var pp: Dictionary = w["player"]
	check(main.player.position.is_equal_approx(Vector2(float(pp["x"]), float(pp["y"]))), "position du joueur")
	check(main.player.hp >= 1.0 and main.player.hp <= game.stats["max_hp"], "vie du joueur dans les bornes")
	check(main.ground.total > 100.0, "carte de vie reprise (%.0f)" % main.ground.total)
	check(main.flora.flowers.size() == (w["flowers"] as Array).size(), "%d fleurs" % (w["flowers"] as Array).size())
	var dropped: Array = w.get("ground_grafts", []) if v >= 3 else []
	check(main.export_ground_grafts().size() == dropped.size(), "%d greffe(s) au sol" % dropped.size())

	# Aller-retour au format courant : l'état ne bouge plus.
	var before := _snapshot()
	check(save.save_now(main, PATH), "réécriture au format courant")
	check(int(JSON.parse_string(FileAccess.get_file_as_string(PATH))["version"]) == save.VERSION, "le fichier réécrit est au format %d" % save.VERSION)
	game.reset()
	check(save.load_into(main, PATH), "rechargement")
	await process_frame
	check(_snapshot() == before, "état identique après réécriture et rechargement")


## Version 0 (champ absent), fichiers à trous : valeurs par défaut, pas de plantage.
func _version_zero_and_gaps() -> void:
	print("Fichiers incomplets")
	for case in [
		{"format": "seve-save"},
		{"format": "seve-save", "version": 1, "game": {"level": 5}},
		{"format": "seve-save", "version": 4, "game": {"level": 5, "flags": []}, "tree": {"allocated": "x"}},
		{"format": "seve-save", "version": 7, "tree": {"crown": "x", "inventory": 3, "choices": []}, "world": {"flowers": "x"}},
		{"format": "seve-save", "version": 8, "tree": {"builds": [3, "x", {"allocated": 5}], "active_build": 99}},
	]:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(case))
		f.close()
		game.reset()
		check(save.load_into(main, PATH) and game.level >= 1 and game.builds.size() == game.build_slots(), "chargé malgré des champs absents ou mal formés : %s" % JSON.stringify(case).left(60))
		await process_frame


func Content_has_graft(gid: String) -> bool:
	return load("res://scripts/content.gd").grafts().has(gid)


## Nœuds appris qui restent reliés à la graine (par uid).
func _connected(uids: Array) -> Array:
	var wanted := {}
	for u in uids:
		wanted[game.tree.id_for_uid(u)] = true
	var kept := {0: true}
	var stack: Array = [0]
	while stack.size() > 0:
		var n: int = stack.pop_back()
		for m in game.tree.nodes[n]["neighbors"]:
			if wanted.has(m) and not kept.has(m):
				kept[m] = true
				stack.append(m)
	var out: Array = []
	for k in kept:
		if k != 0:
			out.append(game.tree.nodes[k]["uid"])
	return out


func _snapshot() -> Dictionary:
	game.store_active_build()
	return {
		"level": game.level, "xp": snappedf(game.xp, 0.001), "points": game.points, "kills": game.kills,
		"flags": game.flags.duplicate(true), "uids": game.allocated_uids(), "choices": game.choices.duplicate(),
		"crown": game.crown.duplicate(), "inventory": game.graft_inventory.duplicate(), "builds": game.builds.duplicate(true),
		"active": game.active_build, "flowers": main.flora.flowers.size(), "grafts": main.export_ground_grafts().size(),
		"elapsed": snappedf(main.elapsed, 10.0), "pos": main.player.position,
	}
