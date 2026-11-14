## Test de la sauvegarde : aller-retour complet et tolérance aux changements de l'arbre.
## Lancer : tools/godot.sh --headless -s res://tests/save_test.gd -- --new-game
extends SceneTree

const PATH := "user://tests/partie_test.json"

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


func _run() -> void:
	var game = root.get_node("Game")
	var save = root.get_node("SaveGame")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.autosave_enabled = false
	save.delete_save(PATH)

	print("Aller-retour")
	game.add_xp(400.0)
	var learned := 0
	while game.points > 0 and learned < 6:
		for n in game.tree.nodes:
			if game.can_allocate(n["id"]):
				game.allocate(n["id"])
				learned += 1
				break
	game.flags["rencontre_gardien"] = true
	game.kills = 17
	main.elapsed = 123.5
	main.player.position = Vector2(321, -654)
	main.ground.paint(Vector2(800, 800), 300.0, 0.7)
	main.flora.add_flower(Vector2(10, 20), Color("ff0000"))
	var before := {
		"level": game.level, "xp": game.xp, "points": game.points, "kills": game.kills,
		"uids": game.allocated_uids(), "life": main.ground.export_map(), "flowers": main.flora.flowers.size(),
		"stats": game.stats.duplicate(),
	}
	check(save.save_now(main, PATH), "écriture du fichier")
	check(save.peek(PATH).get("level", 0) == before["level"], "résumé pour le menu (peek)")

	game.reset()
	main.ground.import_map(Image.create(200, 200, false, Image.FORMAT_R8).save_png_to_buffer())
	main.flora.import_flowers([])
	main.elapsed = 0.0
	main.player.position = Vector2.ZERO
	check(save.load_into(main, PATH), "chargement")
	check(game.level == before["level"] and game.points == before["points"] and game.kills == before["kills"], "niveau, points, purifiés")
	check(is_equal_approx(game.xp, before["xp"]), "expérience")
	check(game.allocated_uids() == before["uids"], "nœuds appris (%d)" % before["uids"].size())
	check(_same_stats(game.stats, before["stats"]), "statistiques recalculées")
	check(game.flags.get("rencontre_gardien", false) == true, "drapeaux d'aventure")
	check(main.ground.export_map() == before["life"] and main.ground.total > 100.0, "carte de vie")
	check(main.flora.flowers.size() == before["flowers"], "fleurs")
	check(main.player.position.is_equal_approx(Vector2(321, -654)) and is_equal_approx(main.elapsed, 123.5), "position et temps de jeu")

	print("Arbre qui a changé")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var uids: Array = data["tree"]["allocated"]
	# Un nœud disparu, et un nœud qui n'est plus relié à la graine.
	uids.append("ronce:99:0")
	var far := -1
	for n in game.tree.nodes:
		if n["ring"] == 6 and not game.allocated.has(n["id"]):
			far = n["id"]
			break
	uids.append(game.tree.nodes[far]["uid"])
	var pts: int = data["game"]["points"]
	_write(data)
	check(save.load_into(main, PATH), "chargement malgré des nœuds inconnus")
	check(game.points == pts + 2, "les 2 points des nœuds invalides sont rendus")
	check(game.allocated_uids() == before["uids"], "les nœuds valides sont conservés")

	print("Formats")
	data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	data["version"] = 999
	_write(data)
	var level_before: int = game.level
	check(not save.load_into(main, PATH), "une sauvegarde d'une version plus récente est refusée")
	check(game.level == level_before, "l'état du jeu n'est pas touché après un refus")
	check(not save.has_save(PATH), "le fichier refusé est mis de côté")
	_write({"format": "seve-save", "version": 0, "game": {"level": 3}})
	check(save.load_into(main, PATH), "un ancien format incomplet se charge")
	check(game.level == 3 and game.allocated.size() == 1, "valeurs par défaut pour les champs manquants")
	_write({"autre": true})
	check(not save.load_into(main, PATH), "un fichier étranger est refusé")

	save.delete_save(PATH)
	for f in DirAccess.get_files_at("user://tests"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tests/" + f))
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)


func _same_stats(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or not is_equal_approx(float(a[k]), float(b[k])):
			return false
	return true


func _write(d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
