## Enchaînement des écrans : titre, nouvelle partie, reprise, retour au titre.
## Points d'entrée « Continuer » et « Nouvelle partie » : la sauvegarde viendra se brancher
## sur has_save() et load_save() sans toucher aux menus.
extends Node

const TITLE_SCENE := "res://scenes/title.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

## Mis à vrai par le mode de test automatique pour passer l'écran titre.
var skip_title := false


func _ready() -> void:
	skip_title = "--autotest" in OS.get_cmdline_user_args()


## Vrai quand la partie qui démarre doit reprendre la sauvegarde (lu par la scène de jeu).
var continue_requested := false


## Autoload de sauvegarde, s'il existe : les menus n'en dépendent pas.
func _save_node() -> Node:
	return get_node_or_null("/root/SaveGame")


## Vrai s'il existe une partie à reprendre.
func has_save() -> bool:
	var s := _save_node()
	return s != null and s.has_method("has_save") and s.has_save()


## Résumé de la sauvegarde pour le bouton « Continuer » ({} si aucun).
func save_summary() -> Dictionary:
	var s := _save_node()
	if s != null and s.has_method("peek") and has_save():
		return s.peek()
	return {}


func new_game() -> void:
	continue_requested = false
	Game.reset()
	_open(GAME_SCENE)


func continue_game() -> void:
	if not has_save():
		return
	continue_requested = true
	Game.reset()
	_open(GAME_SCENE)


func go_title() -> void:
	_open(TITLE_SCENE)


func quit() -> void:
	get_tree().quit()


func _open(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
