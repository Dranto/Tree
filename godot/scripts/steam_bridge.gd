## Passerelle Steam (autoload « SteamBridge », jalon 12 D).
##
## Steam est FACULTATIF : la bibliothèque GodotSteam (GDExtension, dans addons/godotsteam, posée par
## tools/steam-fetch.sh et absente du dépôt) et le client Steam peuvent manquer. Dans ce cas, tout
## ce fichier est sans effet et le jeu tourne exactement pareil (tests, CI, éditeur sans Steam).
## Le singleton « Steam » n'est jamais nommé directement : il est pris par Engine.get_singleton, et
## les tests en posent un faux avec attach() (tests/steam_fake.gd).
##
## Ce qu'il fait quand Steam est là :
##   - succès : un par boss (ACHIEVEMENTS), débloqués à la mort du boss (boss_arena.gd,
##     finale_arena.gd) et rattrapés au chargement d'une sauvegarde où le boss est déjà vaincu
##     (save_game.gd › apply → sync_achievements) ;
##   - Steam Cloud : la sauvegarde (user://saves/partie.json) et les options (user://settings.cfg)
##     sont envoyées après chaque écriture ; au lancement, la copie la plus récente gagne (date
##     « saved_at » de la sauvegarde, date du fichier pour les options) ;
##   - présence enrichie : la région où se trouve le héros (set_region, appelé par main.gd) ;
##     les textes sont dans steam/rich_presence.vdf, à déposer sur Steamworks ;
##   - Steam Deck : is_deck() (échelle de texte par défaut, settings.gd) et clavier virtuel pour
##     renommer un build (tree_builds.gd › show_keyboard / ask_text).
##
## App ID : APP_ID ici et godot/steam_appid.txt (même valeur). 480 = « Spacewar », l'App ID de test
## de Valve, en attendant celui du jeu.
extends Node

const APP_ID := 480
## Identifiants des succès, à créer à l'identique sur Steamworks (textes : steam/succes.md).
const ACHIEVEMENTS := ["BOSS_RONCE", "BOSS_SPORE", "BOSS_VENT", "BOSS_SEVE", "BOSS_AUBE", "BOSS_RACINE", "BOSS_FINALE"]
## Drapeau d'aventure de la Flétrissure vaincue (Objectives.FINALE_WON).
const FINALE_FLAG := "finale_vaincue"
## Fichiers suivis par Steam Cloud : chemin local → nom dans le Cloud.
const SAVE_PATH := "user://saves/partie.json"
const SETTINGS_PATH := "user://settings.cfg"
const CLOUD_FILES := {SAVE_PATH: "partie.json", SETTINGS_PATH: "settings.cfg"}
## Mode du clavier flottant du Deck : une seule ligne (EFloatingGamepadTextInputMode).
const FLOATING_SINGLE_LINE := 0

## Le singleton Steam (ou un faux, dans les tests) ; null sans Steam.
var _steam = null
var _region := ""
## Succès déjà envoyés pendant cette session (évite de rappeler Steam à chaque chargement).
var _unlocked := {}
## Saisie en cours au clavier virtuel plein écran : fonction rappelée avec le texte.
var _text_callback := Callable()
## Raison de l'absence de Steam, pour le journal et les tests.
var status := "inactif"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Les tests et la CI ne cherchent pas Steam (--no-steam) ; sinon on tente, sans rien exiger.
	if "--no-steam" in OS.get_cmdline_user_args() or not Engine.has_singleton("Steam"):
		status = "absent"
		set_process(false)
		return
	_start(Engine.get_singleton("Steam"))


func _process(_delta: float) -> void:
	if _steam != null:
		_steam.run_callbacks()


## Branche un objet Steam (le vrai singleton ou un faux) et l'initialise. Renvoie true si Steam répond.
func attach(steam) -> bool:
	_steam = null
	_unlocked = {}
	_region = ""
	if steam == null:
		status = "absent"
		set_process(false)
		return false
	return _start(steam)


func _start(steam) -> bool:
	# Lu par l'API Steam au démarrage, comme steam_appid.txt (lancement hors du client Steam).
	OS.set_environment("SteamAppId", str(APP_ID))  # i18n: non
	OS.set_environment("SteamGameId", str(APP_ID))  # i18n: non
	var res = steam.steamInitEx() if steam.has_method("steamInitEx") else steam.steamInit()  # i18n: non
	var ok := false
	if res is Dictionary:
		ok = int(res.get("status", 1)) == 0
		status = "actif" if ok else "refusé : %s" % str(res.get("verbal", res))  # i18n: non
	else:
		ok = bool(res)
		status = "actif" if ok else "refusé"  # i18n: non
	if not ok:
		print("Steam : %s (le jeu continue sans Steam)." % status)
		set_process(false)
		return false
	_steam = steam
	set_process(true)
	print("Steam : actif (App ID %d)." % APP_ID)
	if _steam.has_signal("gamepad_text_input_dismissed"):
		_steam.connect("gamepad_text_input_dismissed", _on_text_dismissed)
	cloud_pull()
	return true


func active() -> bool:
	return _steam != null


# --- Succès ---

## Succès d'un boss de région (« ronce » → BOSS_RONCE ; « finale » → BOSS_FINALE).
static func boss_achievement(region: String) -> String:
	return "BOSS_" + region.to_upper()


## Débloque un succès. Sans effet sans Steam ou pour un identifiant inconnu.
func unlock(id: String) -> void:
	if _steam == null or not (id in ACHIEVEMENTS) or _unlocked.has(id):
		return
	_unlocked[id] = true
	_steam.setAchievement(id)
	_steam.storeStats()


## Succès mérités d'après les drapeaux d'aventure (boss vaincus), dans l'ordre de ACHIEVEMENTS.
static func earned(flags: Dictionary) -> Array:
	var out: Array = []
	for id in ACHIEVEMENTS:
		var region: String = id.trim_prefix("BOSS_").to_lower()
		var flag: String = FINALE_FLAG if region == "finale" else region + "_boss_vaincu"
		if bool(flags.get(flag, false)):
			out.append(id)
	return out


## Rattrapage : débloque les succès des boss déjà vaincus (sauvegarde d'avant Steam, autre machine).
func sync_achievements(flags: Dictionary) -> void:
	for id in earned(flags):
		unlock(id)


# --- Présence enrichie ---

## Région où se trouve le héros (« ronce »… ou « finale » sous la graine). Envoyé seulement s'il change.
func set_region(region: String) -> void:
	if _steam == null or region == _region:
		return
	_region = region
	if region == "":
		_steam.clearRichPresence()
		return
	# Jetons de steam/rich_presence.vdf : « #Explore » affiche « {#Region_%region%} ».
	_steam.setRichPresence("region", region)
	_steam.setRichPresence("steam_display", "#Explore")  # i18n: non


# --- Steam Cloud ---

func _cloud_on() -> bool:
	return _steam != null and _steam.isCloudEnabledForAccount() and _steam.isCloudEnabledForApp()


## Envoie un fichier suivi (après son écriture). Sans effet sans Steam ou hors CLOUD_FILES.
func cloud_push(path: String) -> void:
	if not CLOUD_FILES.has(path) or not _cloud_on() or not FileAccess.file_exists(path):
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return
	_steam.fileWrite(CLOUD_FILES[path], bytes, bytes.size())


## Au lancement : pour chaque fichier suivi, garde la copie la plus récente (Cloud ou disque).
func cloud_pull() -> void:
	if not _cloud_on():
		return
	for path in CLOUD_FILES:
		var name: String = CLOUD_FILES[path]
		var has_local := FileAccess.file_exists(path)
		if not _steam.fileExists(name):
			if has_local:
				cloud_push(path)
			continue
		var remote: PackedByteArray = _cloud_read(name)
		if remote.is_empty():
			continue
		if not has_local:
			_write_local(path, remote)
			continue
		var local := FileAccess.get_file_as_bytes(path)
		if local == remote:
			continue
		var local_date := _date(path, local, FileAccess.get_modified_time(path))
		var remote_date := _date(path, remote, int(_steam.getFileTimestamp(name)))
		if remote_date > local_date:
			_write_local(path, remote)
			print("Steam Cloud : %s plus récent dans le Cloud, repris." % name)
		elif local_date > remote_date:
			cloud_push(path)


func _cloud_read(name: String) -> PackedByteArray:
	var size := int(_steam.getFileSize(name))
	if size <= 0:
		return PackedByteArray()
	var res = _steam.fileRead(name, size)
	if res is Dictionary:
		var buf = res.get("buf", PackedByteArray())
		return buf if buf is PackedByteArray else PackedByteArray()
	return res if res is PackedByteArray else PackedByteArray()


## Date d'une copie : « saved_at » pour la sauvegarde (la même sur toutes les machines), sinon
## la date du fichier.
static func _date(path: String, bytes: PackedByteArray, fallback: int) -> int:
	if path == SAVE_PATH:
		var parsed = JSON.parse_string(bytes.get_string_from_utf8())
		if parsed is Dictionary and parsed.has("saved_at"):
			return int(parsed["saved_at"])
	return fallback


## Écrit la copie du Cloud sur le disque ; l'ancienne copie locale est gardée en .bak.
static func _write_local(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(abs_path, abs_path + ".bak")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()


# --- Steam Deck et clavier virtuel ---

## Vrai sur un Steam Deck (variable posée par Steam, ou API Steam). Statique : settings.gd s'en sert
## avant que l'autoload soit prêt.
static func detect_deck(steam = null) -> bool:
	if OS.get_environment("SteamDeck") == "1":
		return true
	if steam == null and Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
	return steam != null and steam.has_method("isSteamRunningOnSteamDeck") and bool(steam.isSteamRunningOnSteamDeck())  # i18n: non


func is_deck() -> bool:
	return detect_deck(_steam)


## Le clavier virtuel de Steam est utilisable (Deck, ou Steam en mode Big Picture).
func text_input_available() -> bool:
	if _steam == null:
		return false
	return is_deck() or bool(_steam.isSteamInBigPictureMode())


## Clavier flottant du Deck sous un champ de texte qui vient de prendre le focus (saisie directe
## dans le champ). Renvoie false s'il n'a pas pu s'ouvrir.
func show_keyboard(edit: Control) -> bool:
	if not text_input_available() or not is_instance_valid(edit):
		return false
	var r := edit.get_viewport().get_screen_transform() * edit.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, edit.size)
	return bool(_steam.showFloatingGamepadTextInput(FLOATING_SINGLE_LINE, int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)))


## Saisie au clavier virtuel plein écran de Steam (à la manette) : callback(texte) est rappelée si
## le joueur valide. Renvoie false si le clavier n'a pas pu s'ouvrir.
func ask_text(description: String, current: String, max_length: int, callback: Callable) -> bool:
	if not text_input_available():
		return false
	# 0, 0 : texte normal, une seule ligne (EGamepadTextInputMode, EGamepadTextInputLineMode).
	if not bool(_steam.showGamepadTextInput(0, 0, description, max_length, current)):
		return false
	_text_callback = callback
	return true


## Fin de la saisie plein écran. Selon la version de GodotSteam, le texte vient avec le signal ou
## se lit avec getEnteredGamepadTextInput.
func _on_text_dismissed(submitted = false, text = null, _app_id = null) -> void:
	var cb := _text_callback
	_text_callback = Callable()
	if not bool(submitted) or not cb.is_valid():
		return
	if text == null and _steam != null and _steam.has_method("getEnteredGamepadTextInput"):  # i18n: non
		text = _steam.getEnteredGamepadTextInput()
	if text is Dictionary:
		text = text.get("text", "")
	cb.call(str(text))
