extends Node
## Dossier utilisateur après un changement de nom du jeu (25/11 : « Sève » → « Arborescence »).
##
## Godot range user:// sous le nom du projet (app_userdata/<nom> en développement, <données>/<nom>
## pour un export) : renommer le jeu donnerait un dossier vide et ferait perdre partie et options.
## Premier autoload : avant que SteamBridge, SaveGame ou Settings ne lisent quoi que ce soit, si le
## nouveau dossier n'a ni partie ni options, on recopie l'ancien (copie, jamais déplacement : l'ancien
## dossier reste intact). Une fois le nouveau dossier rempli, plus rien ne se passe.

## Anciens noms du projet, du plus récent au plus ancien. Ajouter ici l'ancien nom à chaque renommage.
const OLD_NAMES := ["Sève"] # i18n: non
## Fichiers qui disent qu'un dossier contient déjà une partie ou des options.
const MARKERS := ["settings.cfg", "saves/partie.json"] # i18n: non

## Dossier recopié lors de ce lancement ("" sinon), pour les tests et le journal.
var migrated_from := ""


func _ready() -> void:
	migrated_from = migrate(OS.get_user_data_dir())


## Recopie dans `new_dir` le premier ancien dossier voisin qui contient une partie ou des options,
## si `new_dir` n'en contient pas. Renvoie le dossier recopié, ou "".
static func migrate(new_dir: String, old_names: Array = OLD_NAMES) -> String:
	if _has_marker(new_dir):
		return ""
	var parent := new_dir.get_base_dir()
	for old_name in old_names:
		var old_dir: String = parent.path_join(old_name)
		if old_dir == new_dir or not _has_marker(old_dir):
			continue
		if _copy_dir(old_dir, new_dir):
			print("Dossier utilisateur repris de %s" % old_dir) # i18n: non
			return old_dir
	return ""


static func _has_marker(dir: String) -> bool:
	for m in MARKERS:
		if FileAccess.file_exists(dir.path_join(m)):
			return true
	return false


static func _copy_dir(from: String, to: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(to) != OK:
		return false
	var d := DirAccess.open(from)
	if d == null:
		return false
	var ok := true
	for f in d.get_files():
		ok = DirAccess.copy_absolute(from.path_join(f), to.path_join(f)) == OK and ok
	for sub in d.get_directories():
		# Le cache des shaders se reconstruit seul : inutile de le recopier.
		if sub in ["shader_cache", "vulkan"]: # i18n: non
			continue
		ok = _copy_dir(from.path_join(sub), to.path_join(sub)) and ok
	return ok
