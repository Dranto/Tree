## Sauvegarde et chargement de la partie (autoload « SaveGame »).
##
## Format : un fichier JSON lisible dans user://saves/, versionné.
## {
##   "format": "seve-save", "version": 8, "saved_at": <unix>,
##   "game":  {"level", "xp", "points", "kills", "flags"},
##   "tree":  {"allocated": [uid, …],            # identifiants stables, pas des index
##             "choices": {uid: choix},          # maîtrises et mutations (depuis la version 2)
##             "crown": [greffe ou "", …],       # couronne de greffes, un élément par emplacement (version 7)
##             "inventory": [greffe, …],         # greffes possédées, posées ou non (depuis la version 3)
##             "builds": [{} ou {"name", "allocated", "choices", "crown", "plan"}, …],  # builds enregistrés (version 8)
##             "active_build": index},           # emplacement du build actif (ses champs = ceux du dessus)
##   "world": {"elapsed", "player": {"x", "y", "hp"},
##             "ground_grafts": [[x, y, greffe], …],   # greffes tombées, pas encore ramassées (version 3)
##             "life_map": <PNG en base64>, "flowers": [[x, y, couleur, taille, pétales], …]}
## }
##
## L'attaque de base (forme et modificateurs, attack.gd) n'est pas sauvegardée : elle se recalcule
## depuis les nœuds appris, les choix et la couronne de greffes.
##
## Tolérance à l'évolution du jeu :
## - les nœuds sont enregistrés par uid ; un uid disparu ou un nœud qui n'est plus relié
##   à la graine est ignoré et son point est rendu (voir Game.restore_allocation) ;
## - chaque champ manquant prend sa valeur par défaut ;
## - quand le format change, on incrémente VERSION et on ajoute une étape dans _migrate().
##   Un fichier venant d'une version plus récente du jeu est refusé et mis de côté.
## L'écriture passe par un fichier temporaire, et la sauvegarde précédente est gardée en .bak.
extends Node

const Regions = preload("res://scripts/regions.gd")

const FORMAT := "seve-save"
const VERSION := 8
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
		# L'aventure est finie (la Flétrissure vaincue sous la graine) : l'écran titre le dit.
		"ended": bool(g.get("flags", {}).get("finale_vaincue", false)) if g.get("flags") is Dictionary else false,
	}


## Construit le dictionnaire de sauvegarde à partir de l'état du jeu.
func capture(main) -> Dictionary:
	var world := {}
	if main != null:
		world = {
			"elapsed": main.elapsed,
			"player": _player_entry(main),
			"life_map": Marshalls.raw_to_base64(main.ground.export_map()),
			"flowers": main.flora.export_flowers(),
			"ground_grafts": main.export_ground_grafts() if main.has_method("export_ground_grafts") else [],
		}
	Game.store_active_build()
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
		"tree": {"allocated": Game.allocated_uids(), "choices": Game.choices.duplicate(), "crown": Game.crown.duplicate(), "inventory": Game.graft_inventory.duplicate(),
			"builds": Game.builds.duplicate(true), "active_build": Game.active_build},
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
	var ok := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path) == OK
	if ok:
		SteamBridge.cloud_push(path)
	return ok


## Position et vie du joueur à sauvegarder. Pendant le combat de boss, le joueur est noté devant
## l'arène, avec toute sa vie : reprendre la partie ne le pose pas contre la Mère-Ronce, et le
## combat recommence quand il y entre (elle se rendort, comme après une mort). Sous la graine
## (finale), il est noté au pied de la graine, à côté de la brèche.
func _player_entry(main) -> Dictionary:
	var pos: Vector2 = main.player.position
	var hp: float = main.player.hp
	if main.get("arena") != null and main.active_arena() != null:
		pos = main.active_arena().entrance()
		hp = Game.stats["max_hp"]
	elif main.get("finale") != null and main.finale.holds(pos):
		pos = main.finale.entrance()
	return {"x": pos.x, "y": pos.y, "hp": hp}


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
	Game.restore_extras(t.get("choices", {}), t.get("crown", []), t.get("inventory", []))
	Game.restore_builds(t.get("builds", []), t.get("active_build", 0))
	# Succès Steam des boss déjà vaincus (sauvegarde d'avant Steam ou d'une autre machine).
	SteamBridge.sync_achievements(Game.flags)
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
	var dropped = w.get("ground_grafts", [])
	if dropped is Array and main.has_method("import_ground_grafts"):
		main.import_ground_grafts(dropped)
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
func _migrate(data: Dictionary) -> Dictionary:
	if int(data.get("version", 0)) < 1:
		data["version"] = 1
	# Version 2 : choix des maîtrises et mutations, greffes posées. Une partie de la version 1
	# n'en a aucun ; les nœuds appris que les grappes ont remplacés sont rendus au chargement.
	if int(data["version"]) == 1:
		if not data.get("tree") is Dictionary:
			data["tree"] = {}
		data["tree"]["choices"] = {}
		data["tree"]["grafts"] = {}
		data["version"] = 2
	# Version 3 : inventaire des greffes et greffes tombées au sol. Les greffes déjà posées entrent
	# dans l'inventaire ; les points du boss et du Cœur, donnés par l'ancienne version, sont notés
	# comme donnés pour ne pas l'être une seconde fois (Game.grant_points).
	if int(data["version"]) == 2:
		if not data.get("tree") is Dictionary:
			data["tree"] = {}
		var inv: Array = []
		var placed = data["tree"].get("grafts", {})
		if placed is Dictionary:
			for uid in placed:
				if not inv.has(str(placed[uid])):
					inv.append(str(placed[uid]))
		data["tree"]["inventory"] = inv
		if not data.get("game") is Dictionary:
			data["game"] = {}
		if not data["game"].get("flags") is Dictionary:
			data["game"]["flags"] = {}
		var f: Dictionary = data["game"]["flags"]
		if f.get("ronce_boss_vaincu", false):
			f["points_ronce_boss"] = true
		if f.get("ronce_coeur_purifie", false):
			f["points_ronce_coeur"] = true
		if data.get("world") is Dictionary:
			data["world"]["ground_grafts"] = []
		data["version"] = 3
	# Version 4 (jalon 7, plusieurs régions) : la fin de la tranche de Ronce devient la séquence
	# « région purifiée » de Ronce (« fin_ronce_vue » -> « ronce_fin_vue »). La fin de l'aventure
	# (« fin_aventure_vue ») n'est pas notée : d'autres régions attendent maintenant le joueur.
	if int(data["version"]) == 3:
		if not data.get("game") is Dictionary:
			data["game"] = {}
		if not data["game"].get("flags") is Dictionary:
			data["game"]["flags"] = {}
		var f: Dictionary = data["game"]["flags"]
		for old in f.keys():
			var key := str(old)
			if key.begins_with("fin_") and key.ends_with("_vue") and key != "fin_aventure_vue":
				var reg := key.substr(4, key.length() - 8)
				f[reg + "_fin_vue"] = f[old]
				f.erase(old)
		data["version"] = 4
	# Version 5 (jalon 9, la finale sous la graine) : « fin_aventure_vue » veut dire maintenant
	# « épilogue vu, après la finale ». Une partie qui avait vu l'ancienne fin (le texte de fin
	# après le dernier boss de région) ne l'a pas vue : la finale s'ouvre au chargement, puisque
	# toutes ses régions sont purifiées. Les drapeaux de la finale sont faux par défaut.
	if int(data["version"]) == 4:
		if not data.get("game") is Dictionary:
			data["game"] = {}
		if not data["game"].get("flags") is Dictionary:
			data["game"]["flags"] = {}
		var f: Dictionary = data["game"]["flags"]
		if not f.get("finale_vaincue", false):
			f.erase("fin_aventure_vue")
		data["version"] = 5
	# Version 6 (jalon 10, trois Cœurs par région) : chaque Cœur a son drapeau
	# (« <région>_coeur<n>_purifie »). Une région dont le Cœur était purifié en version 5 a tous ses
	# Cœurs purifiés : son arène était ouverte (ou son boss vaincu), elle le reste, et sa récompense
	# déjà donnée ne l'est pas une seconde fois (« points_<région>_coeur » est gardé).
	if int(data["version"]) == 5:
		if not data.get("game") is Dictionary:
			data["game"] = {}
		if not data["game"].get("flags") is Dictionary:
			data["game"]["flags"] = {}
		var f: Dictionary = data["game"]["flags"]
		for key in f.keys():
			var k := str(key)
			if k.ends_with("_coeur_purifie") and bool(f[key]):
				var reg := k.trim_suffix("_coeur_purifie")
				var n := Regions.heart_count(reg) if Regions.exists(reg) else 1
				for i in n:
					f[Regions.heart_part_flag(reg, i)] = true
		data["version"] = 6
	# Version 7 (jalon 11, greffes indépendantes de l'arbre) : les emplacements de greffe de l'arbre
	# deviennent des nœuds ordinaires (d'autres uid) ; les greffes posées passent dans la couronne,
	# celles des emplacements appris d'abord, tant qu'elle a des emplacements ouverts (les autres
	# restent dans l'inventaire). Les points des emplacements appris sont rendus au chargement
	# (uid disparus : Game.restore_allocation).
	if int(data["version"]) == 6:
		if not data.get("tree") is Dictionary:
			data["tree"] = {}
		var tr: Dictionary = data["tree"]
		var placed = tr.get("grafts", {})
		var learned := {}
		if tr.get("allocated") is Array:
			for uid in tr["allocated"]:
				learned[str(uid)] = true
		var first: Array = []
		var later: Array = []
		if placed is Dictionary:
			var uids: Array = placed.keys()
			uids.sort()
			for uid in uids:
				var gid := str(placed[uid])
				if first.has(gid) or later.has(gid):
					continue
				(first if learned.has(str(uid)) else later).append(gid)
		var flags = data.get("game", {}).get("flags", {}) if data.get("game") is Dictionary else {}
		var open: int = Game.crown_size(flags if flags is Dictionary else {})
		var crown: Array = (first + later).slice(0, open)
		var inv: Array = tr.get("inventory", []) if tr.get("inventory") is Array else []
		for gid in first + later:
			if not inv.has(gid):
				inv.append(gid)
		tr["inventory"] = inv
		tr["crown"] = crown
		tr.erase("grafts")
		data["version"] = 7
	# Version 8 (jalon 11, builds multiples) : plusieurs builds enregistrés. Le build de la partie
	# devient le premier emplacement (Game.restore_builds le remplit), les autres sont vides.
	if int(data["version"]) == 7:
		if not data.get("tree") is Dictionary:
			data["tree"] = {}
		data["tree"]["builds"] = []
		data["tree"]["active_build"] = 0
		data["version"] = 8
	return data


## Met de côté un fichier refusé pour ne pas l'écraser à la prochaine sauvegarde automatique.
func _set_aside(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	var dest := "%s.refusee-%d" % [abs_path, int(Time.get_unix_time_from_system())]
	DirAccess.rename_absolute(abs_path, dest)
	push_warning("Sauvegarde refusée (%s), mise de côté : %s" % [last_error, dest])
