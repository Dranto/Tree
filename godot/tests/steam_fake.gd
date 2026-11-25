## Faux Steam pour les tests (tests/steam_test.gd) : mêmes noms de méthodes que le singleton
## « Steam » de GodotSteam, avec un Cloud en mémoire et le journal des appels.
extends Object

signal gamepad_text_input_dismissed(submitted: bool, entered_text: String, app_id: int)

var init_ok := true
var deck := false
var big_picture := false
var cloud_enabled := true
var achievements: Array = []
var stores := 0
var presence: Dictionary = {}
## Cloud : nom → {"bytes": PackedByteArray, "time": unix}.
var cloud: Dictionary = {}
var writes: Array = []
var callbacks := 0
var floating_rect := Rect2()
var text_input := {}


func steamInitEx() -> Dictionary:
	return {"status": 0 if init_ok else 2, "verbal": "Steamworks active." if init_ok else "Steam is not running."}


func run_callbacks() -> void:
	callbacks += 1


func setAchievement(id: String) -> bool:
	if not (id in achievements):
		achievements.append(id)
	return true


func storeStats() -> bool:
	stores += 1
	return true


func setRichPresence(key: String, value: String) -> bool:
	presence[key] = value
	return true


func clearRichPresence() -> void:
	presence.clear()


func isCloudEnabledForAccount() -> bool:
	return cloud_enabled


func isCloudEnabledForApp() -> bool:
	return cloud_enabled


func fileExists(name: String) -> bool:
	return cloud.has(name)


func fileWrite(name: String, bytes: PackedByteArray, size: int = 0) -> bool:
	cloud[name] = {"bytes": bytes.slice(0, size if size > 0 else bytes.size()), "time": int(Time.get_unix_time_from_system())}
	writes.append(name)
	return true


func getFileSize(name: String) -> int:
	return (cloud[name]["bytes"] as PackedByteArray).size() if cloud.has(name) else 0


func fileRead(name: String, size: int) -> Dictionary:
	if not cloud.has(name):
		return {"ret": 0, "buf": PackedByteArray()}
	return {"ret": size, "buf": (cloud[name]["bytes"] as PackedByteArray).slice(0, size)}


func getFileTimestamp(name: String) -> int:
	return int(cloud[name]["time"]) if cloud.has(name) else 0


func isSteamRunningOnSteamDeck() -> bool:
	return deck


func isSteamInBigPictureMode() -> bool:
	return big_picture


func showFloatingGamepadTextInput(_mode: int, x: int, y: int, w: int, h: int) -> bool:
	floating_rect = Rect2(x, y, w, h)
	return true


func showGamepadTextInput(mode: int, line_mode: int, description: String, max_length: int, current: String) -> bool:
	text_input = {"mode": mode, "line_mode": line_mode, "description": description, "max": max_length, "current": current}
	return true
