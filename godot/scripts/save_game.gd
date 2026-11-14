## Sauvegarde et chargement de la partie (autoload « SaveGame »).
##
## Format : un fichier JSON lisible dans user://saves/, versionné.
## {
##   "format": "seve-save", "version": 1, "saved_at": <unix>,
##   "game":  {"level", "xp", "points", "kills", "flags"},
##   "tree":  {"allocated": [uid, …]},          # identifiants stables, pas des index
##   "world": {"elapsed", "player": {"x", "y", "hp"},
##             "life_map": <PNG en base64>, "flowers": [[x, y, couleur, taille, pétales], …]}
## }
##
## Tolérance à l'évolution du jeu :
## - les nœuds sont enregistrés par uid ; un uid disparu ou un nœud qui n'est plus relié
##   à la graine est ignoré et son point est rendu (voir Game.restore_allocation) ;
## - chaque champ manquant prend sa valeur par défaut ;
## - quand le format change, on incrémente VERSION et on ajoute une étape dans _migrate().
##   Un fichier venant d'une version plus récente du jeu est refusé et mis de côté.
## L'écriture passe par un fichier temporaire, et la sauvegarde précédente est gardée en .bak.
extends Node

const FORMAT := "seve-save"
const VERSION := 1
const DEFAULT_PATH := "user://saves/partie.json"

## Dernière erreur de chargement, lisible (vide si tout va bien).
var last_error := ""


func has_save(path := DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


func delete_save(path := DEFAULT_PATH) -> void:
	for p in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Résumé de la sauvegarde pour un menu « Continuer » ({} si absente ou illisible).
func peek(path := DEFAULT_PATH) -> Dictionary:
	var data := _read(path)
	if data.is_empty():
		return {}
	var g: Dictionary = data.get("game", {})
	var t: Dictionary = data.get("tree", {})
	var w: Dictionary = data.get("world", {})
	return {
		"level": int(g.get("level", 1)),
		"nodes": (t.get("allocated", []) as Array).size(),
		"play_time": float(w.get("elapsed", 0.0)),
		"saved_at": int(data.get("saved_at", 0)),
	}


## Construit le dictionnaire de sauvegarde à partir de l'état du jeu.
func capture(main) -> Dictionary:
	var world := {}
	if main != null:
		world = {
			"elapsed": main.elapsed,
			"player": {"x": main.player.position.x, "y": main.player.position.y, "hp": main.player.hp},
			"life_map": Marshalls.raw_to_base64(main.ground.export_map()),
			"flowers": main.flora.export_flowers(),
		}
	return {
		"format": FORMAT,
		"version": VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"game": {
			"level": Game.level,
			"xp": Game.xp,
			"points": Game.points,
			"kills": Game.kills,
			"flags": Game.flags.duplicate(true),
		},
		"tree": {"allocated": Game.allocated_uids()},
		"world": world,
	}


func save_now(main, path := DEFAULT_PATH) -> bool:
	var text := JSON.stringify(capture(main), "\t")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible : %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.close()
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(abs_path, abs_path + ".bak")
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path) == OK


## Charge la sauvegarde dans le jeu en cours. Renvoie false si elle est absente ou refusée ;
## dans ce cas l'état du jeu n'est pas modifié et last_error explique pourquoi.
func load_into(main, path := DEFAULT_PATH) -> bool:
	last_error = ""
	if not has_save(path):
		last_error = "aucune sauvegarde"
		return false
	var data := _read(path)
	if data.is_empty():
		_set_aside(path)
		return false
	apply(data, main)
	return true


## Applique un dictionnaire de sauvegarde (déjà migré) à l'état du jeu.
func apply(data: Dictionary, main) -> void:
	var g: Dictionary = data.get("game", {})
	Game.reset()
	Game.level = maxi(1, int(g.get("level", 1)))
	Game.xp = maxf(0.0, float(g.get("xp", 0.0)))
	Game.points = maxi(0, int(g.get("points", Game.level)))
	Game.kills = maxi(0, int(g.get("kills", 0)))
	var flags = g.get("flags", {})
	Game.flags = flags.duplicate(true) if flags is Dictionary else {}
	var t: Dictionary = data.get("tree", {})
	var uids = t.get("allocated", [])
	var refunded := Game.restore_allocation(uids if uids is Array else [])
	if refunded > 0:
		print("Sauvegarde : %d nœud(s) absent(s) de l'arbre actuel, point(s) rendu(s)." % refunded)

	if main == null:
		return
	var w: Dictionary = data.get("world", {})
	main.elapsed = maxf(0.0, float(w.get("elapsed", 0.0)))
	var map_b64 := str(w.get("life_map", ""))
	if map_b64 != "":
		main.ground.import_map(Marshalls.base64_to_raw(map_b64))
	var flowers = w.get("flowers", [])
	if flowers is Array:
		main.flora.import_flowers(flowers)
	var p: Dictionary = w.get("player", {})
	var h: float = main.world_half
	main.player.position = Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))).clamp(Vector2(-h, -h), Vector2(h, h))
	main.player.hp = clampf(float(p.get("hp", Game.stats["max_hp"])), 1.0, Game.stats["max_hp"])


## Lit, valide et migre un fichier. Renvoie {} en cas d'échec (last_error renseigné).
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		last_error = "aucune sauvegarde"
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or parsed.get("format", "") != FORMAT:
		last_error = "fichier illisible ou d'un autre format"
		return {}
	var version := int(parsed.get("version", 0))
	if version > VERSION:
		last_error = "sauvegarde créée par une version plus récente du jeu (format %d > %d)" % [version, VERSION]
		return {}
	return _migrate(parsed)


## Met à jour une sauvegarde ancienne vers le format courant, une version à la fois.
## Exemple pour un futur format 2 :
##   if int(data["version"]) == 1:
##       data["game"]["grafts"] = []
##       data["version"] = 2
func _migrate(data: Dictionary) -> Dictionary:
	if int(data.get("version", 0)) < 1:
		data["version"] = 1
	return data


## Met de côté un fichier refusé pour ne pas l'écraser à la prochaine sauvegarde automatique.
func _set_aside(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	var dest := "%s.refusee-%d" % [abs_path, int(Time.get_unix_time_from_system())]
	DirAccess.rename_absolute(abs_path, dest)
	push_warning("Sauvegarde refusée (%s), mise de côté : %s" % [last_error, dest])
