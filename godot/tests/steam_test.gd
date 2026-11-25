## Test de la passerelle Steam (jalon 12 D), sans Steam : le jeu tourne pareil sans la bibliothèque,
## puis un faux Steam (tests/steam_fake.gd) vérifie les succès (un par boss, rattrapage au
## chargement), Steam Cloud (la copie la plus récente gagne), la présence enrichie, le Steam Deck
## (échelle de texte par défaut, clavier virtuel) et les crochets des arènes de boss.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/steam_test.gd
## Écrit dans user:// (sauvegarde et options) : tools/unit-tests.sh l'isole dans son propre dossier.
extends SceneTree

const SteamFake = preload("res://tests/steam_fake.gd")

var failures := 0
var bridge
var fakes: Array = []


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _fake():
	var f = SteamFake.new()
	fakes.append(f)
	return f


func _save_bytes(saved_at: int) -> PackedByteArray:
	return JSON.stringify({"format": "seve-save", "version": 8, "saved_at": saved_at, "game": {"level": 3}}).to_utf8_buffer()


func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _saved_at(path: String) -> int:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int(d.get("saved_at", -1)) if d is Dictionary else -1


func _run() -> void:
	bridge = root.get_node("SteamBridge")
	var save = root.get_node("SaveGame")
	var settings = root.get_node("Settings")
	var game = root.get_node("Game")
	var SAVE: String = bridge.SAVE_PATH
	var CFG: String = bridge.SETTINGS_PATH

	print("Sans Steam")
	check(not bridge.active() and bridge.status == "absent", "pas de bibliothèque GodotSteam : la passerelle est inactive (%s)" % bridge.status)
	bridge.unlock("BOSS_RONCE")
	bridge.set_region("ronce")
	bridge.sync_achievements({"ronce_boss_vaincu": true})
	bridge.cloud_push(SAVE)
	check(not bridge.text_input_available() and not bridge.ask_text("x", "y", 24, func(_t): pass), "pas de clavier virtuel sans Steam")
	check(save.save_now(null) and save.has_save(), "la sauvegarde s'écrit comme avant")
	check(not bridge.attach(null) and not bridge.active(), "attach(null) laisse le jeu sans Steam")

	print("App ID et succès")
	var appid := FileAccess.get_file_as_string("res://steam_appid.txt").strip_edges()
	check(bridge.APP_ID == 480 and appid == str(bridge.APP_ID), "App ID de test 480, le même dans steam_appid.txt (%s)" % appid)
	check(bridge.ACHIEVEMENTS == ["BOSS_RONCE", "BOSS_SPORE", "BOSS_VENT", "BOSS_SEVE", "BOSS_AUBE", "BOSS_RACINE", "BOSS_FINALE"], "un succès par boss, noms convenus")
	var Regions = load("res://scripts/regions.gd")
	var all_flags := {"finale_vaincue": true}
	for id in ["ronce", "spore", "vent", "seve", "aube", "racine"]:
		all_flags[Regions.boss_flag(id)] = true
		check(bridge.boss_achievement(id) in bridge.ACHIEVEMENTS, "région %s : succès %s" % [id, bridge.boss_achievement(id)])
	check(bridge.earned(all_flags).size() == 7, "tous les boss vaincus : 7 succès")
	check(bridge.earned({"ronce_coeur_purifie": true, "spore_boss_vaincu": false}).is_empty(), "un Cœur purifié ou un drapeau faux ne débloque rien")

	var f = _fake()
	check(bridge.attach(f) and bridge.active() and bridge.status == "actif", "un Steam qui répond est branché")
	check(OS.get_environment("SteamAppId") == "480", "App ID transmis à l'API Steam")
	bridge.unlock("BOSS_RONCE")
	bridge.unlock("BOSS_RONCE")
	bridge.unlock("PAS_UN_SUCCES")
	check(f.achievements == ["BOSS_RONCE"] and f.stores == 1, "succès envoyé une fois, identifiant inconnu ignoré")
	save.apply({"game": {"level": 9, "flags": {"vent_boss_vaincu": true, "finale_vaincue": true, "aube_coeur_purifie": true}}}, null)
	check("BOSS_VENT" in f.achievements and "BOSS_FINALE" in f.achievements and not ("BOSS_AUBE" in f.achievements), "rattrapage au chargement : boss déjà vaincus débloqués")
	var g = _fake()
	g.init_ok = false
	check(not bridge.attach(g) and not bridge.active(), "Steam qui refuse l'initialisation : le jeu continue sans")

	print("Présence enrichie")
	f = _fake()
	bridge.attach(f)
	bridge.set_region("spore")
	check(f.presence.get("region") == "spore" and f.presence.get("steam_display") == "#Explore", "région en cours envoyée")
	f.presence["region"] = "touché"
	bridge.set_region("spore")
	check(f.presence["region"] == "touché", "même région : pas de nouvel envoi")
	bridge.set_region("")
	check(f.presence.is_empty(), "hors région : présence effacée")
	# Hors du projet Godot (non exporté) : steam/ à la racine du dépôt.
	var vdf := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../steam/rich_presence.vdf"))
	for id in ["graine", "ronce", "spore", "vent", "seve", "aube", "racine", "finale"]:
		check(vdf.contains("\"#Region_%s\"" % id), "jeton de présence #Region_%s (steam/rich_presence.vdf)" % id)

	print("Steam Cloud")
	# Cloud plus récent que le disque : la copie du Cloud est reprise, l'ancienne gardée en .bak.
	_write(SAVE, _save_bytes(100))
	f = _fake()
	f.cloud["partie.json"] = {"bytes": _save_bytes(200), "time": 1}
	bridge.attach(f)
	check(_saved_at(SAVE) == 200 and _saved_at(SAVE + ".bak") == 100, "sauvegarde plus récente dans le Cloud : reprise (date saved_at)")
	check(f.writes.has("settings.cfg") or not FileAccess.file_exists(CFG), "options locales absentes du Cloud : envoyées")
	# Disque plus récent : il est envoyé.
	_write(SAVE, _save_bytes(300))
	f = _fake()
	f.cloud["partie.json"] = {"bytes": _save_bytes(200), "time": 2000000000}
	bridge.attach(f)
	check(_saved_at(SAVE) == 300 and f.writes.has("partie.json"), "sauvegarde locale plus récente : envoyée au Cloud")
	var sent = JSON.parse_string((f.cloud["partie.json"]["bytes"] as PackedByteArray).get_string_from_utf8())
	check(sent is Dictionary and int(sent["saved_at"]) == 300, "le Cloud contient la sauvegarde locale")
	# Rien sur le disque : le Cloud est repris (nouvelle machine).
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	f = _fake()
	f.cloud["partie.json"] = {"bytes": _save_bytes(400), "time": 1}
	bridge.attach(f)
	check(_saved_at(SAVE) == 400, "nouvelle machine : la sauvegarde du Cloud est posée")
	# Écritures du jeu → Cloud.
	f.writes.clear()
	save.save_now(null)
	settings.save_settings()
	check(f.writes.has("partie.json") and f.writes.has("settings.cfg"), "chaque écriture de la sauvegarde et des options part dans le Cloud")
	f.writes.clear()
	save.save_now(null, "user://saves/autre.json")
	check(f.writes.is_empty(), "un autre fichier (tests, essais) n'est pas envoyé")
	# Options : la date du fichier départage.
	var cfg_local := FileAccess.get_file_as_bytes(CFG)
	var cfg_cloud := ("[access]\n\ntext_scale=1.3\n").to_utf8_buffer()
	f = _fake()
	f.cloud["settings.cfg"] = {"bytes": cfg_cloud, "time": 4000000000}
	f.cloud["partie.json"] = {"bytes": FileAccess.get_file_as_bytes(SAVE), "time": 1}
	bridge.attach(f)
	check(FileAccess.get_file_as_bytes(CFG) == cfg_cloud, "options plus récentes dans le Cloud : reprises")
	_write(CFG, cfg_local)
	f = _fake()
	f.cloud_enabled = false
	f.cloud["settings.cfg"] = {"bytes": cfg_cloud, "time": 4000000000}
	bridge.attach(f)
	save.save_now(null)
	check(FileAccess.get_file_as_bytes(CFG) == cfg_local and f.writes.is_empty(), "Cloud désactivé par le joueur : rien n'est lu ni écrit")

	print("Steam Deck")
	bridge.attach(null)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	OS.set_environment("SteamDeck", "1")
	settings.text_scale = 1.0
	settings.load_settings()
	check(is_equal_approx(settings.text_scale, settings.DECK_TEXT_SCALE) and settings.DECK_TEXT_SCALE in settings.TEXT_SCALES, "sur le Deck, texte plus grand par défaut (%.2f)" % settings.text_scale)
	settings.text_scale = 1.0
	settings.save_settings()
	settings.text_scale = 1.3
	settings.load_settings()
	check(is_equal_approx(settings.text_scale, 1.0), "un choix enregistré l'emporte sur le défaut du Deck")
	OS.set_environment("SteamDeck", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	settings.text_scale = 1.0
	settings.load_settings()
	check(is_equal_approx(settings.text_scale, 1.0), "hors Deck, taille normale par défaut")

	f = _fake()
	bridge.attach(f)
	check(not bridge.is_deck() and not bridge.text_input_available(), "PC sans Big Picture : pas de clavier virtuel")
	f.deck = true
	check(bridge.is_deck() and bridge.text_input_available(), "Deck détecté par l'API Steam : clavier virtuel disponible")
	var got := [""]
	check(bridge.ask_text("Nom du build", "Build 1", 24, func(t: String): got[0] = t), "clavier plein écran ouvert")
	check(f.text_input.get("current") == "Build 1" and f.text_input.get("max") == 24, "le nom actuel et la longueur maximale sont transmis")
	f.gamepad_text_input_dismissed.emit(true, "Fouet sanglant", 480)
	check(got[0] == "Fouet sanglant", "le texte validé revient au jeu")
	bridge.ask_text("Nom du build", "x", 24, func(t: String): got[0] = t)
	f.gamepad_text_input_dismissed.emit(false, "", 480)
	check(got[0] == "Fouet sanglant", "saisie annulée : rien ne change")

	# Crochets du jeu : arènes de boss (succès), boucle de main (présence), panneau des builds.
	print("Dans le jeu")
	game.reset()
	f = _fake()
	f.deck = true
	bridge.attach(f)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 90:
		await physics_frame
	check(f.presence.get("region", "") != "", "la boucle du jeu envoie la région du héros (%s)" % f.presence.get("region", ""))
	main.arena.boss_defeated()
	check("BOSS_" + main.arena.region.to_upper() in f.achievements, "mort de la Mère-Ronce : succès %s" % ("BOSS_" + main.arena.region.to_upper()))
	if main.get("finale") != null:
		main.finale.boss_defeated()
		check("BOSS_FINALE" in f.achievements, "mort de la Flétrissure : succès BOSS_FINALE")
	var TreeBuilds = load("res://scripts/tree_builds.gd")
	var panel = TreeBuilds.new()
	root.add_child(panel)
	await process_frame
	var renames: Array = []
	for b in panel.find_children("*", "Button", true, false):
		if b.text == "Renommer":
			renames.append(b)
	check(renames.size() == game.build_slots(), "Deck : un bouton « Renommer » par build, joignable à la manette (%d)" % renames.size())
	check(panel.ask_name(0) and f.text_input.get("description") == "Nom du build", "« Renommer » ouvre le clavier de Steam")
	f.gamepad_text_input_dismissed.emit(true, "Racines", 480)
	check(game.build_name(0) == "Racines", "le build est renommé")
	panel.queue_free()
	main.queue_free()
	await process_frame

	bridge.attach(null)
	for x in fakes:
		x.free()
	print("RÉSULTAT : ", "OK" if failures == 0 else "%d échec(s)" % failures)
	quit(0 if failures == 0 else 1)
