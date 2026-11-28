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
## App ID : un seul endroit, res://data/steam.json (« app_id » pour le jeu, « demo_app_id » pour la
## démo). 480 = « Spacewar », l'App ID de test de Valve, en attendant ceux du jeu. Il est transmis à
## l'API Steam par la variable SteamAppId : pas besoin de steam_appid.txt à côté de l'exécutable.
##
## Vérification d'un build exporté : « -- --steam-probe » écrit l'état de Steam et la liste des
## fonctions GodotSteam utilisées ici qui manqueraient, puis quitte (tools/export-smoke.sh, CI).
extends Node

const Content = preload("res://scripts/content.gd")
const Demo = preload("res://scripts/demo.gd")

## App ID de test de Valve, si data/steam.json manque.
const TEST_APP_ID := 480
## Identifiants des succès, à créer à l'identique sur Steamworks (textes : steam/succes.md).
const ACHIEVEMENTS := ["BOSS_RONCE", "BOSS_SPORE", "BOSS_VENT", "BOSS_SEVE", "BOSS_AUBE", "BOSS_RACINE", "BOSS_FINALE"]
## Drapeau d'aventure de la Flétrissure vaincue (Objectives.FINALE_WON).
const FINALE_FLAG := "finale_vaincue"
## Fichiers suivis par Steam Cloud : chemin local → nom dans le Cloud.
const SAVE_PATH := "user://saves/partie.json"
const SETTINGS_PATH := "user://settings.cfg"
const CLOUD_FILES := {SAVE_PATH: "partie.json", SETTINGS_PATH: "settings.cfg"}
## Fonctions du singleton GodotSteam appelées par ce fichier (vérifiées par --steam-probe).
## isSteamRunningOnSteamDeck n'y est pas : GodotSteam 4.24 ne l'a plus ; le Deck se reconnaît alors
## à la variable SteamDeck=1 que Steam pose sur la console (detect_deck).
## Nombre d'arguments passés par ce fichier à chaque fonction (la sonde vérifie que GodotSteam les accepte).
const API := {"steamInitEx": 0, "run_callbacks": 0, "setAchievement": 1, "storeStats": 0,  # i18n: non
	"setRichPresence": 2, "clearRichPresence": 0, "isCloudEnabledForAccount": 0,  # i18n: non
	"isCloudEnabledForApp": 0, "fileExists": 1, "fileWrite": 3, "fileRead": 2, "getFileSize": 1,  # i18n: non
	"getFileTimestamp": 1, "isSteamInBigPictureMode": 0, "showFloatingGamepadTextInput": 5,  # i18n: non
	"showGamepadTextInput": 5}  # i18n: non  # i18n: non
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
	var args := OS.get_cmdline_user_args()
	# « --no-steam » ignore Steam ; sinon on tente, sans rien exiger.
	if "--no-steam" in args or not Engine.has_singleton("Steam"):
		status = "absent"
		set_process(false)
	else:
		_start(Engine.get_singleton("Steam"))
	if "--steam-probe" in args:
		_probe.call_deferred()


## Identifiant Steam de ce build : celui de la démo dans un build démo, sinon celui du jeu.
static func app_id() -> int:
	var d := Content._load("steam")
	var id = d.get("demo_app_id" if Demo.active() else "app_id", d.get("app_id", TEST_APP_ID))
	return int(id) if int(id) > 0 else TEST_APP_ID


## Succès de ce build : un par boss, seulement celui de la Mère-Ronce dans la démo.
static func achievements() -> Array:
	if not Demo.active():
		return ACHIEVEMENTS
	var demo = Content._load("steam").get("demo_achievements", ["BOSS_RONCE"])
	return ACHIEVEMENTS.filter(func(id): return id in demo)


## Fonctions de API absentes d'un objet Steam, ou qui n'acceptent pas ce nombre d'arguments
## (version de GodotSteam incompatible).
static func missing_api(steam) -> Array:
	if steam == null:
		return API.keys()
	var sig := {}
	for m in steam.get_method_list():
		sig[m["name"]] = m
	var out: Array = []
	for name in API:
		if not steam.has_method(name):
			out.append(name)
		elif sig.has(name):
			var total: int = (sig[name]["args"] as Array).size()
			var optional: int = (sig[name]["default_args"] as Array).size()
			var vararg: bool = int(sig[name].get("flags", 0)) & METHOD_FLAG_VARARG != 0
			if API[name] < total - optional or (API[name] > total and not vararg):
				out.append("%s (%d arguments, attend %d à %d)" % [name, API[name], total - optional, total])  # i18n: non
	return out


## « --steam-probe » : bilan pour la CI et pour Antoine, puis sortie.
func _probe() -> void:
	var lib := Engine.has_singleton("Steam")
	print("STEAM-PROBE bibliotheque=%s statut=%s app_id=%d demo=%s" % ["oui" if lib else "non", status, app_id(), Demo.active()])  # i18n: non
	if lib:
		var steam = Engine.get_singleton("Steam")
		if steam.has_method("get_godotsteam_version"):
			print("STEAM-PROBE GodotSteam %s" % str(steam.get_godotsteam_version()))  # i18n: non
		var miss := missing_api(steam)
		print("STEAM-PROBE fonctions manquantes : %s" % (", ".join(miss) if not miss.is_empty() else "aucune"))  # i18n: non
		if not miss.is_empty():
			# Noms voisins, pour retrouver une fonction renommée par GodotSteam.
			var names: Array = []
			for m in steam.get_method_list():
				var n: String = m["name"]
				if n.containsn("deck") or n.containsn("version") or n.containsn("bigpicture"):  # i18n: non
					names.append(n)
			print("STEAM-PROBE fonctions voisines : %s" % ", ".join(names))  # i18n: non
	get_tree().quit(0)


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
	var id := app_id()
	OS.set_environment("SteamAppId", str(id))  # i18n: non
	OS.set_environment("SteamGameId", str(id))  # i18n: non
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
	print("Steam : actif (App ID %d)." % id)
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
	if _steam == null or not (id in achievements()) or _unlocked.has(id):
		return
	_unlocked[id] = true
	_steam.setAchievement(id)
	_steam.storeStats()


## Succès mérités d'après les drapeaux d'aventure (boss vaincus), dans l'ordre de achievements().
static func earned(flags: Dictionary) -> Array:
	var out: Array = []
	for id in achievements():
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
