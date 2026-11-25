## Changement de nom du jeu (25/11, « Sève » → « Arborescence ») : le nouveau dossier utilisateur
## reprend la partie et les options de l'ancien, une seule fois, sans toucher à l'ancien.
## Lancer : tools/godot.sh --headless -s res://tests/user_dir_test.gd
extends SceneTree

const Migration := preload("res://scripts/user_dir_migration.gd")
var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _initialize() -> void:
	var root := OS.get_user_data_dir().path_join("migration_test")
	var old := root.path_join("Sève")
	var new := root.path_join("Arborescence")
	_write(old.path_join("settings.cfg"), "[general]\nlocale=\"en\"\n")
	_write(old.path_join("saves/partie.json"), "{\"version\": 8}")
	_write(old.path_join("saves/builds/b1.json"), "{}")
	_write(old.path_join("shader_cache/x.bin"), "x")

	check(Migration.migrate(new, ["Sève"]) == old, "le nouveau dossier vide reprend l'ancien")
	check(_read(new.path_join("settings.cfg")).contains("locale"), "options recopiées")
	check(_read(new.path_join("saves/partie.json")) == "{\"version\": 8}", "partie recopiée")
	check(FileAccess.file_exists(new.path_join("saves/builds/b1.json")), "sous-dossiers recopiés")
	check(not DirAccess.dir_exists_absolute(new.path_join("shader_cache")), "cache des shaders laissé de côté")
	check(FileAccess.file_exists(old.path_join("saves/partie.json")), "l'ancien dossier reste intact")

	_write(new.path_join("saves/partie.json"), "{\"version\": 9}")
	check(Migration.migrate(new, ["Sève"]) == "", "une seule fois : un dossier déjà rempli n'est plus touché")
	check(_read(new.path_join("saves/partie.json")) == "{\"version\": 9}", "la partie du nouveau dossier est gardée")

	var empty := root.path_join("Vide")
	check(Migration.migrate(empty, ["Absent"]) == "", "sans ancien dossier, rien ne se passe")
	check(not DirAccess.dir_exists_absolute(empty), "et aucun dossier n'est créé")

	_rm(root)
	print("RÉSULTAT ", "ok" if failures == 0 else "%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


func _rm(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	for s in d.get_directories():
		_rm(dir.path_join(s))
	DirAccess.remove_absolute(dir)
